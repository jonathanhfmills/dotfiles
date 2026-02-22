#!/bin/bash
# Bulk scan for bootstrapping email knowledge base
#
# Usage:
#   bulk-scan.sh --account jon       # AI-assisted, batched classification
#
# Extracts headers + body snippets, batches through Claude
# for contact profiling and action item detection

set -euo pipefail

# Allow headless claude -p calls from within Claude Code sessions
unset CLAUDECODE 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXTRACT="$SCRIPT_DIR/mail-extract.py"
GCAL="$HOME/.claude/skills/calendar/scripts/gcal"
KNOWLEDGE_DIR="$HOME/.mail/knowledge"

# ─── Parse args ──────────────────────────────────────

ACCOUNT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --account) ACCOUNT="$2"; shift 2 ;;
        *) echo "Usage: bulk-scan.sh --account jon" >&2; exit 1 ;;
    esac
done

if [[ -z "$ACCOUNT" ]] || [[ "$ACCOUNT" != "jon" ]]; then
    echo "Usage: bulk-scan.sh --account jon" >&2
    exit 1
fi

mkdir -p "$KNOWLEDGE_DIR/contacts" "$KNOWLEDGE_DIR/threads" "$KNOWLEDGE_DIR/digest"

# ─── Jon account bulk scan ───────────────────────────

scan_jon() {
    echo "=== Bulk scan: jon@cosmickmedia.com ==="
    echo "Mode: AI-assisted, batched"

    # Get all unprocessed jon emails
    local files
    files=$(notmuch search --output=files "path:jon/** AND tag:new" 2>/dev/null || true)

    if [[ -z "$files" ]]; then
        echo "No new jon@ emails to scan."
        return 0
    fi

    local count
    count=$(echo "$files" | wc -l)
    echo "Found $count unprocessed emails"

    # Write file list
    local filelist="/tmp/jon-bulk-files.txt"
    echo "$files" > "$filelist"

    # Extract headers + body (first 100 lines for bulk scan) — write to temp file
    echo "Extracting email content..."
    local content_file="/tmp/jon-bulk-content.json"
    python3 "$EXTRACT" --max-body-lines 100 --batch "$filelist" > "$content_file"

    # Batch into groups of 20 and process with Claude
    echo "Processing with Claude AI in batches of 20..."
    python3 - <<'PYEOF' "$content_file" "$KNOWLEDGE_DIR" "$GCAL"
import json
import os
import subprocess
import sys

with open(sys.argv[1]) as f:
    all_emails = json.load(f)
knowledge_dir = sys.argv[2]
gcal = sys.argv[3]

# Filter out errors
emails = [e for e in all_emails if "error" not in e]
print(f"Processing {len(emails)} valid emails")

# Batch into groups of 20
batch_size = 20
batches = [emails[i:i+batch_size] for i in range(0, len(emails), batch_size)]

all_contacts = {}
all_actions = []
tasks_updated = 0

# Fetch existing tasks once for dedup across all batches
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
    print(f"WARNING: Could not fetch existing tasks for dedup: {e}")

dedup_section = ""
if task_context:
    dedup_section = f"""
DEDUP: These tasks already exist in the Email task list:
{task_context}

If an email's action matches an existing task (same person, same topic), set "existing_task_id"
to that task's id instead of creating a duplicate. Only set this when you are confident it is
the same action — not just a vaguely similar topic.
"""

for batch_num, batch in enumerate(batches, 1):
    print(f"\nBatch {batch_num}/{len(batches)} ({len(batch)} emails)...")

    # Prepare batch for Claude
    batch_summary = []
    for e in batch:
        batch_summary.append({
            "from": f"{e.get('from_name', '')} <{e.get('from_addr', '')}>",
            "to": e.get("to", ""),
            "subject": e.get("subject", ""),
            "date": e.get("date_iso", e.get("date", "")),
            "message_id": e.get("message_id", ""),
            "in_reply_to": e.get("in_reply_to", ""),
            "body_preview": (e.get("body", "") or "")[:2000],
        })

    prompt = f"""Analyze these {len(batch)} emails from jon@cosmickmedia.com's inbox.

For each email, provide:
1. category: "urgent" | "actionable" | "informational" | "newsletter" | "stale" | "resolved"
2. summary: One-line description
3. action_needed: null or a specific action item string
4. action_due: null or suggested due date (YYYY-MM-DD or "+Nd" relative)
5. contact_info: Brief note about who the sender is and their relationship (if determinable)
6. existing_task_id: null (create new task) or an existing task ID from the list below (update that task instead)
{dedup_section}
Also identify any ongoing threads that span multiple emails in this batch.

Respond with ONLY valid JSON in this format:
{{
  "emails": [
    {{
      "message_id": "...",
      "from_addr": "...",
      "category": "...",
      "summary": "...",
      "action_needed": null,
      "action_due": null,
      "contact_info": "...",
      "existing_task_id": null
    }}
  ],
  "threads": [
    {{
      "subject": "...",
      "participants": ["..."],
      "status": "active|resolved|stale",
      "summary": "..."
    }}
  ]
}}

Emails:
{json.dumps(batch_summary, indent=2)}"""

    try:
        result = subprocess.run(
            ["claude", "-p", "--output-format", "json", prompt],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode != 0:
            print(f"  Claude error: {result.stderr[:200]}")
            continue

        response = json.loads(result.stdout)
        # Handle claude wrapping in a result key
        if "result" in response:
            response = json.loads(response["result"]) if isinstance(response["result"], str) else response["result"]

    except (json.JSONDecodeError, subprocess.TimeoutExpired) as e:
        print(f"  Parse/timeout error: {e}")
        continue

    # Process results
    for email_result in response.get("emails", []):
        addr = email_result.get("from_addr", "").lower()
        if addr and email_result.get("contact_info"):
            if addr not in all_contacts:
                all_contacts[addr] = {
                    "name": email_result.get("from_addr", ""),
                    "info": email_result.get("contact_info", ""),
                    "categories": [],
                    "last_subject": "",
                }
            all_contacts[addr]["categories"].append(email_result.get("category", ""))
            all_contacts[addr]["last_subject"] = email_result.get("summary", "")

        # Collect action items
        if email_result.get("action_needed"):
            all_actions.append({
                "title": email_result["action_needed"],
                "due": email_result.get("action_due", "+3d"),
                "notes": f"From: {addr}\n{email_result.get('summary', '')}",
                "existing_task_id": email_result.get("existing_task_id"),
            })

    # Save thread info
    for thread in response.get("threads", []):
        safe_subject = "".join(c if c.isalnum() or c in " -_" else "" for c in thread.get("subject", "unknown"))[:50]
        thread_file = os.path.join(knowledge_dir, "threads", f"{safe_subject.strip().replace(' ', '-')}.md")
        with open(thread_file, "w") as f:
            f.write(f"# {thread.get('subject', 'Unknown Thread')}\n\n")
            f.write(f"**Status:** {thread.get('status', 'unknown')}\n")
            f.write(f"**Participants:** {', '.join(thread.get('participants', []))}\n\n")
            f.write(f"{thread.get('summary', '')}\n")

# Save contact profiles
contacts_dir = os.path.join(knowledge_dir, "contacts")
for addr, info in all_contacts.items():
    safe_name = "".join(c if c.isalnum() or c in " -_@." else "" for c in addr)[:50]
    contact_file = os.path.join(contacts_dir, f"{safe_name}.md")
    with open(contact_file, "w") as f:
        f.write(f"# {info['name']}\n\n")
        f.write(f"**Email:** {addr}\n")
        f.write(f"**Context:** {info['info']}\n")
        f.write(f"**Typical categories:** {', '.join(set(info['categories']))}\n")
        f.write(f"**Recent:** {info['last_subject']}\n")

# Create or update calendar tasks for action items
actions_created = 0
print(f"\nProcessing {len(all_actions)} action items...")
for action in all_actions:
    dedup_id = action.get("existing_task_id")
    try:
        if dedup_id and dedup_id in existing_task_ids:
            from datetime import datetime as _dt
            append_text = f"[{_dt.now().strftime('%Y-%m-%d')}] {action.get('notes', '')}"
            cmd = [gcal, "tasks", "update", dedup_id, "--append-notes", append_text]
            subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            tasks_updated += 1
            print(f"  ~ {action['title']} (updated existing)")
        else:
            cmd = [gcal, "tasks", "add", action["title"]]
            if action.get("due"):
                cmd.extend(["--due", action["due"]])
            if action.get("notes"):
                cmd.extend(["--notes", action["notes"]])
            subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            actions_created += 1
            print(f"  + {action['title']}")
    except Exception as e:
        print(f"  Failed: {action['title']}: {e}")

# Save inbox status overview
status_file = os.path.join(knowledge_dir, "inbox-status.md")
with open(status_file, "w") as f:
    f.write("# Inbox Status\n\n")
    f.write(f"**Last bulk scan:** {__import__('datetime').datetime.now().isoformat()[:19]}\n\n")
    f.write(f"## jon@cosmickmedia.com\n")
    f.write(f"- Emails scanned: {len(emails)}\n")
    f.write(f"- Contacts identified: {len(all_contacts)}\n")
    f.write(f"- Action items created: {actions_created}\n")
    f.write(f"- Tasks updated (dedup): {tasks_updated}\n\n")

# Save action items for reference
actions_file = os.path.join(knowledge_dir, "action-items.md")
with open(actions_file, "w") as f:
    f.write("# Pending Action Items\n\n")
    f.write("*Synced to Google Tasks (Email list)*\n\n")
    for action in all_actions:
        dedup_id = action.get("existing_task_id")
        if dedup_id and dedup_id in existing_task_ids:
            f.write(f"- [~] **{action['title']}** *(updated existing task)*\n")
        else:
            f.write(f"- [ ] **{action['title']}**\n")
        if action.get("notes"):
            for line in action["notes"].split("\n"):
                f.write(f"  {line}\n")
        f.write("\n")

print(f"\nDone: {len(all_contacts)} contacts, {actions_created} tasks created, {tasks_updated} updated (dedup)")
PYEOF

    # Tag all as processed
    echo "Tagging emails as processed..."
    notmuch tag -new +processed +bulk-scanned -- "path:jon/** AND tag:new"

    echo "=== Jon bulk scan complete ==="
    echo "Review:"
    echo "  Contacts:     $KNOWLEDGE_DIR/contacts/"
    echo "  Threads:      $KNOWLEDGE_DIR/threads/"
    echo "  Inbox status: $KNOWLEDGE_DIR/inbox-status.md"
    echo "  Action items: $KNOWLEDGE_DIR/action-items.md"
    rm -f "$filelist" "$content_file"
}

# ─── Main ────────────────────────────────────────────

scan_jon
