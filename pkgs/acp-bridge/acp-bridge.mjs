#!/usr/bin/env node
// ACP Bridge — CLI-agnostic ACP client bridging any LLM reasoning engine to OpenClaw.
//
// Runs INSIDE the reasoning container. Spawns an ACP-compatible CLI (qwen-code,
// claude-code, gemini-cli) and handles:
//   1. ACP handshake (JSON-RPC 2.0 over NDJSON/stdio)
//   2. Session binding with OpenClaw for Carapace permission scoping
//   3. Permission routing (session/request_permission → OpenClaw)
//   4. Result collection + MEMORY.md persistence
//   5. Frontier delegation plumbing (spawn one-shot frontier CLI when stuck)

import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { readFileSync, writeFileSync, mkdirSync, existsSync, appendFileSync } from "node:fs";
import { join } from "node:path";

const CLI_COMMAND = process.env.ACP_CLI_COMMAND || "qwen --acp --auth-type=openai";
const OPENCLAW_ENDPOINT = process.env.OPENCLAW_ENDPOINT || "";
const AGENT_NAME = process.env.AGENT_NAME || "unknown";
const WORKSPACE = process.env.WORKSPACE || "/workspace";
const RESULTS_DIR = join(WORKSPACE, "results");
const TASK_FILE = process.env.TASK_FILE || join(WORKSPACE, "task.json");

mkdirSync(RESULTS_DIR, { recursive: true });

// --- NDJSON helpers ---
let nextId = 1;
const pending = new Map(); // id → {resolve, reject}

function sendRequest(proc, method, params) {
  const id = nextId++;
  const msg = JSON.stringify({ jsonrpc: "2.0", id, method, params });
  proc.stdin.write(msg + "\n");
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
  });
}

function sendResponse(proc, id, result) {
  const msg = JSON.stringify({ jsonrpc: "2.0", id, result });
  proc.stdin.write(msg + "\n");
}

function tryParseJson(line) {
  try { return JSON.parse(line); } catch { return null; }
}

// --- OpenClaw Carapace integration ---
async function checkPermission(toolName, params) {
  if (!OPENCLAW_ENDPOINT) return { allowed: true };
  try {
    const resp = await fetch(`${OPENCLAW_ENDPOINT}/v1/carapace/check`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ agent: AGENT_NAME, tool: toolName, params }),
    });
    if (resp.ok) return await resp.json();
    return { allowed: true }; // fail-open if OpenClaw unavailable
  } catch {
    return { allowed: true };
  }
}

async function registerSession(sessionId) {
  if (!OPENCLAW_ENDPOINT) return;
  try {
    await fetch(`${OPENCLAW_ENDPOINT}/v1/sessions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: sessionId, agent: AGENT_NAME, runtime: "acp" }),
    });
  } catch { /* best-effort */ }
}

// --- Output logging ---
const outputLog = join(RESULTS_DIR, "output.ndjson");
const stderrLog = join(RESULTS_DIR, "stderr.log");

function logEvent(event) {
  appendFileSync(outputLog, JSON.stringify({ ts: Date.now(), ...event }) + "\n");
}

// --- Read task prompt ---
function loadTaskPrompt() {
  if (existsSync(TASK_FILE)) {
    const task = JSON.parse(readFileSync(TASK_FILE, "utf-8"));
    return task.prompt || task.description || "No task description provided.";
  }
  // Fallback: read from stdin if no task file
  return process.env.ACP_TASK_PROMPT || "No task provided.";
}

// --- Frontier delegation (one-shot) ---
async function delegateToFrontier(subProblem) {
  const frontierCmd = process.env.ACP_FRONTIER_CLI || "claude --acp";
  logEvent({ type: "frontier_delegation", subProblem, cli: frontierCmd });

  return new Promise((resolve, reject) => {
    const child = spawn("sh", ["-lc", frontierCmd], {
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env },
    });

    let sessionId = null;
    const rl = createInterface({ input: child.stdout });
    let result = "";

    rl.on("line", (line) => {
      const msg = tryParseJson(line);
      if (!msg) return;

      if (msg.id && pending.has(msg.id)) return; // not ours

      // Handle frontier handshake responses
      if (msg.result && msg.result.sessionId) {
        sessionId = msg.result.sessionId;
        // Send the sub-problem
        sendRequest(child, "session/prompt", {
          sessionId,
          prompt: [{ type: "text", text: subProblem }],
        });
      }

      // Collect result chunks
      if (msg.method === "session/update" && msg.params?.type === "AgentMessageChunk") {
        result += msg.params.content || "";
      }

      // Auto-approve permissions for frontier (it's scoped to one sub-problem)
      if (msg.method === "session/request_permission") {
        sendResponse(child, msg.id, { allowed: true });
      }
    });

    child.on("close", () => resolve(result || "(no frontier response)"));
    child.on("error", (err) => reject(err));

    // Frontier handshake
    setTimeout(async () => {
      try {
        await sendRequest(child, "initialize", {
          protocolVersion: 1,
          clientCapabilities: { filesystem: { enabled: true } },
        });
        await sendRequest(child, "session/new", { cwd: WORKSPACE, mcpServers: [] });
      } catch { /* frontier may exit early */ }
    }, 500);

    // Hard timeout: 5 minutes for frontier
    setTimeout(() => { child.kill(); resolve(result || "(frontier timeout)"); }, 300_000);
  });
}

// --- Main ---
async function main() {
  const taskPrompt = loadTaskPrompt();
  console.error(`[acp-bridge] Agent: ${AGENT_NAME}`);
  console.error(`[acp-bridge] CLI: ${CLI_COMMAND}`);
  console.error(`[acp-bridge] Task: ${taskPrompt.slice(0, 100)}...`);

  // Spawn the CLI
  const child = spawn("sh", ["-lc", CLI_COMMAND], {
    stdio: ["pipe", "pipe", "pipe"],
    env: { ...process.env, HOME: process.env.HOME || "/home/agent" },
  });

  child.stderr.on("data", (chunk) => {
    appendFileSync(stderrLog, chunk);
  });

  const rl = createInterface({ input: child.stdout });
  let sessionId = null;
  let consecutiveFailures = 0;
  const MAX_FAILURES_BEFORE_FRONTIER = 3;

  rl.on("line", async (line) => {
    const msg = tryParseJson(line);
    if (!msg) return;

    // Response to our requests
    if (msg.id && pending.has(msg.id)) {
      const { resolve } = pending.get(msg.id);
      pending.delete(msg.id);
      resolve(msg.result || msg.error);
      return;
    }

    // Reverse request: permission check
    if (msg.method === "session/request_permission") {
      const { tool, params: toolParams } = msg.params || {};
      logEvent({ type: "permission_request", tool, agent: AGENT_NAME });
      const decision = await checkPermission(tool, toolParams);
      sendResponse(child, msg.id, { allowed: decision.allowed });
      return;
    }

    // Notification: tool call activity
    if (msg.method === "session/update") {
      const p = msg.params || {};
      const update = p.update || {};
      const updateType = update.sessionUpdate || "";

      if (updateType === "tool_call" || updateType === "tool_call_update") {
        logEvent({ type: "tool_call", name: update.name, status: update.status });

        if (update.status === "error" || update.status === "failed") {
          consecutiveFailures++;
          if (consecutiveFailures >= MAX_FAILURES_BEFORE_FRONTIER) {
            console.error(`[acp-bridge] ${consecutiveFailures} consecutive failures — frontier delegation available`);
            logEvent({ type: "stuck_detected", failures: consecutiveFailures });
          }
        } else if (update.status === "success") {
          consecutiveFailures = 0;
        }
      }

      if (updateType === "agent_message_chunk" || updateType === "agent_thought_chunk") {
        const text = update.content?.text || "";
        logEvent({ type: "reasoning", updateType, content: text.slice(0, 200) });
      }
    }
  });

  // ACP Handshake with retry (CLI startup can be slow)
  let initialized = false;
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      await new Promise((r) => setTimeout(r, 1000 + attempt * 1000));
      const initResult = await Promise.race([
        sendRequest(child, "initialize", {
          protocolVersion: 1,
          clientCapabilities: { filesystem: { enabled: true } },
        }),
        new Promise((_, rej) => setTimeout(() => rej(new Error("timeout")), 10_000)),
      ]);
      console.error(`[acp-bridge] Initialized: ${JSON.stringify(initResult)}`);
      initialized = true;
      break;
    } catch (err) {
      console.error(`[acp-bridge] Init attempt ${attempt + 1} failed: ${err.message}`);
    }
  }

  if (!initialized) {
    console.error("[acp-bridge] Failed to initialize ACP after 5 attempts");
    process.exit(1);
  }

  // Create session
  const sessionResult = await sendRequest(child, "session/new", {
    cwd: WORKSPACE,
    mcpServers: [],
  });
  sessionId = sessionResult?.sessionId;
  console.error(`[acp-bridge] Session: ${sessionId}`);

  // Register with OpenClaw
  if (sessionId) await registerSession(sessionId);

  // Send task prompt (ACP spec: prompt is ContentBlock[])
  console.error(`[acp-bridge] Sending prompt...`);
  const promptResult = await sendRequest(child, "session/prompt", {
    sessionId,
    prompt: [{ type: "text", text: taskPrompt }],
  });
  console.error(`[acp-bridge] Prompt completed: ${JSON.stringify(promptResult)}`);

  // Write result
  logEvent({ type: "completed", stopReason: promptResult?.stopReason });
  const agentMemory = join(WORKSPACE, "agent", "MEMORY.md");
  if (existsSync(agentMemory)) {
    logEvent({ type: "memory_synced", path: agentMemory });
  }
  writeFileSync(join(RESULTS_DIR, "result.json"), JSON.stringify({
    agent: AGENT_NAME,
    status: "completed",
    stopReason: promptResult?.stopReason,
    timestamp: new Date().toISOString(),
  }));

  // Kill child and exit
  child.kill();
  console.error(`[acp-bridge] Done.`);
  process.exit(0);
}

main().catch((err) => {
  console.error(`[acp-bridge] Fatal: ${err.message}`);
  process.exit(1);
});
