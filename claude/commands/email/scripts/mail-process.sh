#!/bin/bash
# Email processing pipeline — runs every 5 min via cron
#
# 1. Sync jon@ via mbsync
# 2. Index new mail via notmuch
# 3. Process jon@ (full AI classification + task creation)

set -euo pipefail

# Ensure PATH includes user binaries (cron has minimal PATH)
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Allow headless claude -p calls from within Claude Code sessions
unset CLAUDECODE 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXTRACT="$SCRIPT_DIR/mail-extract.py"
GCAL="$HOME/.claude/skills/calendar/scripts/gcal"
KNOWLEDGE_DIR="$HOME/.mail/knowledge"
LOGPREFIX="[mail-process]"

# ─── Locking ─────────────────────────────────────────

LOCKFILE="/tmp/mail-process.lock"
exec 200>"$LOCKFILE"
flock -n 200 || { echo "$LOGPREFIX Already running, exiting."; exit 0; }

log() { echo "$LOGPREFIX $(date '+%H:%M:%S') $*"; }

# ─── 1. Sync ─────────────────────────────────────────

log "Syncing mailboxes..."
mbsync jon 2>&1 | while read -r line; do log "mbsync: $line"; done || {
    log "WARNING: mbsync failed (network issue?), continuing with local mail"
}

# ─── 2. Index ────────────────────────────────────────

log "Indexing new mail..."
notmuch new 2>&1 | while read -r line; do log "notmuch: $line"; done

# ─── 3. Process jon@ ────────────────────────────────

process_jon() {
    local count
    count=$(notmuch count "path:jon/** AND tag:new" 2>/dev/null || echo 0)

    if [[ "$count" -eq 0 ]]; then
        log "jon@: No new mail"
        return 0
    fi

    # Cap at 50 emails per cron run to avoid API overload
    # Use bulk-scan.sh for larger backlogs
    local max_batch=50
    if [[ "$count" -gt "$max_batch" ]]; then
        log "jon@: $count new emails (processing first $max_batch — run bulk-scan.sh for full backlog)"
    else
        log "jon@: Processing $count new emails"
    fi

    # Write file list and message IDs (capped)
    local filelist="/tmp/jon-process-files.txt"
    local idlist="/tmp/jon-process-ids.txt"
    notmuch search --output=files --limit="$max_batch" "path:jon/** AND tag:new" > "$filelist" 2>/dev/null
    notmuch search --output=messages --limit="$max_batch" "path:jon/** AND tag:new" > "$idlist" 2>/dev/null

    # Extract content to temp file
    local content_file="/tmp/jon-process-content.json"
    python3 "$EXTRACT" --max-body-lines 200 --batch "$filelist" > "$content_file"

    # Process with Claude
    python3 - <<'PYEOF' "$content_file" "$KNOWLEDGE_DIR" "$GCAL"
import json
import os
import re
import subprocess
import sys
from datetime import datetime

def parse_claude_json(stdout):
    """Parse JSON from claude -p --output-format json output."""
    outer = json.loads(stdout)
    if "result" in outer:
        raw = outer["result"] if isinstance(outer["result"], str) else json.dumps(outer["result"])
    else:
        raw = stdout
    # Strip markdown code fences if present
    raw = re.sub(r'^```(?:json)?\s*\n?', '', raw.strip())
    raw = re.sub(r'\n?```\s*$', '', raw.strip())
    return json.loads(raw)

with open(sys.argv[1]) as f:
    emails = json.load(f)
knowledge_dir = sys.argv[2]
gcal = sys.argv[3]

# Filter errors
valid = [e for e in emails if "error" not in e]
if not valid:
    print("No valid emails to process")
    sys.exit(0)

# Prepare for Claude
batch = []
for e in valid:
    batch.append({
        "from": f"{e.get('from_name', '')} <{e.get('from_addr', '')}>",
        "subject": e.get("subject", ""),
        "date": e.get("date_iso", e.get("date", "")),
        "message_id": e.get("message_id", ""),
        "in_reply_to": e.get("in_reply_to", ""),
        "body_preview": (e.get("body", "") or "")[:3000],
        "attachments": e.get("attachments", []),
    })

# Fetch existing tasks for dedup
existing_tasks = []
existing_task_ids = set()
task_context = ""
try:
    r = subprocess.run(
        [gcal, "tasks", "list"],
        capture_output=True, text=True, timeout=30
    )
    if r.returncode == 0 and r.stdout.strip() != "No tasks found.":
        existing_tasks = json.loads(r.stdout)
        existing_task_ids = {t["id"] for t in existing_tasks}
        lines = [f'  - id="{t["id"]}" title="{t["title"]}"' for t in existing_tasks]
        task_context = "\n".join(lines)
except Exception as e:
    print(f"WARNING: Could not fetch existing tasks for dedup: {e}", file=sys.stderr)

dedup_section = ""
if task_context:
    dedup_section = f"""
DEDUP: These tasks already exist in the Email task list:
{task_context}

If an email's action matches an existing task (same person, same topic), set "existing_task_id"
to that task's id instead of creating a duplicate. Only set this when you are confident it is
the same action — not just a vaguely similar topic.
"""

prompt = f"""You are processing {len(batch)} new emails for jon@cosmickmedia.com.

For each email, provide:
1. category: "urgent" | "actionable" | "informational" | "newsletter" | "routine" | "spam"
2. summary: One-line description
3. action_needed: null or specific action (e.g., "Reply to Sarah about Q2 budget proposal")
4. action_due: null or due date ("today", "tomorrow", "+3d", "YYYY-MM-DD")
5. contact_update: null or brief note to add to contact profile
6. existing_task_id: null (create new task) or an existing task ID from the list below (update that task instead)
{dedup_section}
Respond with ONLY valid JSON:
{{
  "emails": [
    {{
      "message_id": "...",
      "from_addr": "...",
      "category": "...",
      "summary": "...",
      "action_needed": null,
      "action_due": null,
      "contact_update": null,
      "existing_task_id": null
    }}
  ]
}}

Emails:
{json.dumps(batch, indent=2)}"""

try:
    result = subprocess.run(
        ["claude", "-p", "--output-format", "json", prompt],
        capture_output=True, text=True, timeout=120
    )
    if result.returncode != 0:
        print(f"Claude error: {result.stderr[:200]}", file=sys.stderr)
        sys.exit(1)

    response = parse_claude_json(result.stdout)

except (json.JSONDecodeError, subprocess.TimeoutExpired) as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)

# Process results
actions_created = 0
tasks_updated = 0
for er in response.get("emails", []):
    addr = er.get("from_addr", "").lower()

    # Update contact profile
    if addr and er.get("contact_update"):
        contacts_dir = os.path.join(knowledge_dir, "contacts")
        os.makedirs(contacts_dir, exist_ok=True)
        safe = "".join(c if c.isalnum() or c in " -_@." else "" for c in addr)[:50]
        cfile = os.path.join(contacts_dir, f"{safe}.md")
        if os.path.exists(cfile):
            with open(cfile, "a") as f:
                f.write(f"\n**{datetime.now().strftime('%Y-%m-%d')}:** {er['contact_update']}\n")
        else:
            with open(cfile, "w") as f:
                f.write(f"# {addr}\n\n**Context:** {er['contact_update']}\n")

    # Create or update task for actionable items
    if er.get("action_needed"):
        dedup_id = er.get("existing_task_id")
        try:
            if dedup_id and dedup_id in existing_task_ids:
                # Update existing task — append new email context
                append_text = f"[{datetime.now().strftime('%Y-%m-%d')}] From: {addr}\n{er.get('summary', '')}"
                cmd = [gcal, "tasks", "update", dedup_id, "--append-notes", append_text]
                subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                tasks_updated += 1
            else:
                # Create new task
                cmd = [gcal, "tasks", "add", er["action_needed"]]
                if er.get("action_due"):
                    cmd.extend(["--due", er["action_due"]])
                cmd.extend(["--notes", f"From: {addr}\n{er.get('summary', '')}"])
                subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                actions_created += 1
        except Exception as e:
            print(f"Task create/update failed: {e}", file=sys.stderr)

# Update inbox status
status_file = os.path.join(knowledge_dir, "inbox-status.md")
with open(status_file, "w") as f:
    f.write("# Inbox Status\n\n")
    f.write(f"**Last processed:** {datetime.now().isoformat()[:19]}\n\n")
    f.write(f"## jon@cosmickmedia.com\n")
    f.write(f"- Last batch: {len(valid)} emails processed\n")
    f.write(f"- Tasks created: {actions_created}\n")
    f.write(f"- Tasks updated (dedup): {tasks_updated}\n\n")

# Update action items log
actions_file = os.path.join(knowledge_dir, "action-items.md")
if actions_created > 0 or tasks_updated > 0:
    with open(actions_file, "a") as f:
        f.write(f"\n## {datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n")
        for er in response.get("emails", []):
            if er.get("action_needed"):
                dedup_id = er.get("existing_task_id")
                if dedup_id and dedup_id in existing_task_ids:
                    f.write(f"- [~] {er['action_needed']} *(updated existing task)*\n")
                else:
                    f.write(f"- [ ] {er['action_needed']}\n")

print(f"Processed {len(valid)} emails, created {actions_created} tasks, updated {tasks_updated} (dedup)")
PYEOF

    # Tag only the processed batch by message ID
    while IFS= read -r mid; do
        notmuch tag -new +processed -- "$mid"
    done < "$idlist"
    log "jon@: Done"
    rm -f "$filelist" "$idlist" "$content_file"
}

# ─── Run ─────────────────────────────────────────────

process_jon

log "Pipeline complete"
