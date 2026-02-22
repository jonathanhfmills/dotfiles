#!/usr/bin/env python3
"""Extract structured data from RFC 2822 email files.

Usage:
    mail-extract.py FILE [FILE ...]          # Full extraction (headers + body)
    mail-extract.py --headers-only FILE ...  # Headers only (for bulk scan)
    mail-extract.py --batch FILE_LIST        # Read file paths from a file

Outputs JSON array of email objects.
"""

import argparse
import email
import email.policy
import json
import os
import sys
from email import policy
from email.utils import parseaddr, parsedate_to_datetime


def extract_text_body(msg, max_lines=200):
    """Extract plain text body from email, respecting MIME structure."""
    body = ""

    if msg.is_multipart():
        for part in msg.walk():
            ct = part.get_content_type()
            cd = str(part.get("Content-Disposition", ""))

            # Skip attachments
            if "attachment" in cd:
                continue

            if ct == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    charset = part.get_content_charset() or "utf-8"
                    try:
                        body = payload.decode(charset, errors="replace")
                    except (LookupError, UnicodeDecodeError):
                        body = payload.decode("utf-8", errors="replace")
                    break
            elif ct == "text/html" and not body:
                # Fallback: strip HTML tags for a rough text version
                payload = part.get_payload(decode=True)
                if payload:
                    charset = part.get_content_charset() or "utf-8"
                    try:
                        html = payload.decode(charset, errors="replace")
                    except (LookupError, UnicodeDecodeError):
                        html = payload.decode("utf-8", errors="replace")
                    # Crude HTML stripping
                    import re
                    body = re.sub(r"<[^>]+>", " ", html)
                    body = re.sub(r"\s+", " ", body).strip()
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            charset = msg.get_content_charset() or "utf-8"
            try:
                body = payload.decode(charset, errors="replace")
            except (LookupError, UnicodeDecodeError):
                body = payload.decode("utf-8", errors="replace")

    # Truncate to max_lines
    lines = body.split("\n")
    if len(lines) > max_lines:
        lines = lines[:max_lines]
        lines.append(f"[... truncated at {max_lines} lines ...]")

    return "\n".join(lines).strip()


def extract_email(filepath, headers_only=False, max_body_lines=200):
    """Extract structured data from a single email file."""
    try:
        with open(filepath, "rb") as f:
            msg = email.message_from_binary_file(f, policy=policy.default)
    except Exception as e:
        return {"error": str(e), "file": filepath}

    from_name, from_addr = parseaddr(msg.get("From", ""))
    to_name, to_addr = parseaddr(msg.get("To", ""))

    result = {
        "file": filepath,
        "message_id": msg.get("Message-ID", ""),
        "in_reply_to": msg.get("In-Reply-To", ""),
        "from_name": from_name,
        "from_addr": from_addr,
        "to": msg.get("To", ""),
        "subject": msg.get("Subject", ""),
        "date": msg.get("Date", ""),
    }

    # Parse date to ISO format
    try:
        dt = parsedate_to_datetime(msg.get("Date", ""))
        result["date_iso"] = dt.isoformat()
    except Exception:
        result["date_iso"] = ""

    if not headers_only:
        result["body"] = extract_text_body(msg, max_lines=max_body_lines)
        # Attachment info
        attachments = []
        if msg.is_multipart():
            for part in msg.walk():
                cd = str(part.get("Content-Disposition", ""))
                if "attachment" in cd:
                    filename = part.get_filename() or "unnamed"
                    attachments.append(filename)
        result["attachments"] = attachments

    return result


def main():
    parser = argparse.ArgumentParser(description="Extract data from email files")
    parser.add_argument("files", nargs="*", help="Email file paths")
    parser.add_argument("--headers-only", action="store_true", help="Extract headers only")
    parser.add_argument("--batch", help="Read file paths from this file (one per line)")
    parser.add_argument("--max-body-lines", type=int, default=200, help="Max body lines (default: 200)")
    args = parser.parse_args()

    files = list(args.files)
    if args.batch:
        with open(args.batch) as f:
            files.extend(line.strip() for line in f if line.strip())

    if not files:
        parser.print_help()
        sys.exit(1)

    results = []
    for filepath in files:
        if os.path.isfile(filepath):
            results.append(extract_email(filepath, args.headers_only, args.max_body_lines))
        else:
            results.append({"error": "File not found", "file": filepath})

    json.dump(results, sys.stdout, indent=2, default=str)
    print()


if __name__ == "__main__":
    main()
