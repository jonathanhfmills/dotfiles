#!/usr/bin/env python3
"""Trajectory logging proxy — sits between clients and SGLang.

Forwards all OpenAI-compatible API requests to the upstream SGLang server,
logs complete request/response pairs as JSONL for nightly GSPO training.

Only logs /v1/chat/completions (the training-relevant endpoint).
All other endpoints are passed through without logging.

Usage:
    python logger.py \
        --upstream http://localhost:11434 \
        --port 11433 \
        --output-dir /var/lib/vllm/models/trajectories/raw \
        --source wanda
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import aiohttp
import aiohttp.web


class TrajectoryLogger:
    def __init__(self, upstream: str, output_dir: str, source: str):
        self.upstream = upstream.rstrip("/")
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.source = source
        self._session = None

    async def get_session(self):
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession()
        return self._session

    def _output_file(self) -> Path:
        """One file per day, named by source."""
        date = datetime.now(timezone.utc).strftime("%Y%m%d")
        return self.output_dir / f"raw_{self.source}_{date}.jsonl"

    def _log_trajectory(self, request_body: dict, response_body: dict):
        """Append a trajectory record to today's JSONL file."""
        messages = request_body.get("messages", [])
        if not messages:
            return

        # Extract the assistant response
        choices = response_body.get("choices", [])
        if not choices:
            return

        assistant_msg = choices[0].get("message", {})
        if not assistant_msg.get("content"):
            return

        record = {
            "messages": messages + [assistant_msg],
            "model": response_body.get("model", "unknown"),
            "source": self.source,
            "timestamp": time.time(),
            "usage": response_body.get("usage", {}),
            "temperature": request_body.get("temperature"),
            "finish_reason": choices[0].get("finish_reason"),
        }

        path = self._output_file()
        with open(path, "a") as f:
            f.write(json.dumps(record) + "\n")

    async def handle_chat_completions(self, request: aiohttp.web.Request):
        """Proxy /v1/chat/completions with logging."""
        session = await self.get_session()

        body = await request.read()
        request_body = json.loads(body)

        # Check if streaming — pass through without logging (too complex to reassemble)
        if request_body.get("stream", False):
            return await self._proxy_stream(request, session)

        # Forward to upstream
        headers = {
            k: v for k, v in request.headers.items()
            if k.lower() not in ("host", "content-length", "transfer-encoding")
        }

        try:
            async with session.post(
                f"{self.upstream}/v1/chat/completions",
                data=body,
                headers=headers,
            ) as resp:
                response_body_raw = await resp.read()
                response_body = json.loads(response_body_raw)

                # Log the trajectory (fire-and-forget, don't block response)
                try:
                    self._log_trajectory(request_body, response_body)
                except Exception as e:
                    print(f"Logging error (non-fatal): {e}", file=sys.stderr)

                return aiohttp.web.Response(
                    body=response_body_raw,
                    status=resp.status,
                    content_type="application/json",
                )
        except aiohttp.ClientError as e:
            return aiohttp.web.json_response(
                {"error": {"message": f"Upstream error: {e}", "type": "proxy_error"}},
                status=502,
            )

    async def _proxy_stream(self, request: aiohttp.web.Request, session: aiohttp.ClientSession):
        """Pass through streaming requests without logging."""
        body = await request.read()
        headers = {
            k: v for k, v in request.headers.items()
            if k.lower() not in ("host", "content-length", "transfer-encoding")
        }

        async with session.post(
            f"{self.upstream}/v1/chat/completions",
            data=body,
            headers=headers,
        ) as resp:
            response = aiohttp.web.StreamResponse(
                status=resp.status,
                headers={"Content-Type": resp.content_type or "text/event-stream"},
            )
            await response.prepare(request)

            async for chunk in resp.content.iter_any():
                await response.write(chunk)

            await response.write_eof()
            return response

    async def handle_passthrough(self, request: aiohttp.web.Request):
        """Proxy all other endpoints without logging."""
        session = await self.get_session()

        body = await request.read()
        headers = {
            k: v for k, v in request.headers.items()
            if k.lower() not in ("host", "content-length", "transfer-encoding")
        }

        path = request.path_qs
        method = request.method.lower()

        try:
            async with session.request(
                method,
                f"{self.upstream}{path}",
                data=body if body else None,
                headers=headers,
            ) as resp:
                response_body = await resp.read()
                return aiohttp.web.Response(
                    body=response_body,
                    status=resp.status,
                    content_type=resp.content_type,
                )
        except aiohttp.ClientError as e:
            return aiohttp.web.json_response(
                {"error": {"message": f"Upstream error: {e}", "type": "proxy_error"}},
                status=502,
            )

    async def cleanup(self, app):
        if self._session and not self._session.closed:
            await self._session.close()


def main():
    parser = argparse.ArgumentParser(description="Trajectory logging proxy")
    parser.add_argument("--upstream", default="http://localhost:11434", help="Upstream SGLang URL")
    parser.add_argument("--port", type=int, default=11433, help="Proxy listen port")
    parser.add_argument("--host", default="0.0.0.0", help="Proxy listen host")
    parser.add_argument("--output-dir", default="/var/lib/vllm/models/trajectories/raw", help="JSONL output dir")
    parser.add_argument("--source", default="unknown", help="Source identifier (e.g. wanda, cosmo)")
    args = parser.parse_args()

    logger = TrajectoryLogger(args.upstream, args.output_dir, args.source)

    app = aiohttp.web.Application()
    app.on_cleanup.append(logger.cleanup)

    # Chat completions — log these
    app.router.add_post("/v1/chat/completions", logger.handle_chat_completions)

    # Everything else — passthrough
    app.router.add_route("*", "/{path:.*}", logger.handle_passthrough)

    print(f"Trajectory logger: {args.host}:{args.port} → {args.upstream} (source={args.source})")
    print(f"Logging to: {args.output_dir}")
    aiohttp.web.run_app(app, host=args.host, port=args.port, print=None)


if __name__ == "__main__":
    main()
