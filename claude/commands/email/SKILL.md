---
name: email
description: Manage email for jon@cosmickmedia.com. Check inbox status, search emails, archive, and trigger processing. Triggers on "email", "inbox", "mail", "gmail", "cosmickmedia".
---

# Email Management Pipeline

Google Workspace account synced to local Maildir. Full AI processing with Google Calendar tasks for action items.

## Account

| Account | Purpose | Processing |
|---------|---------|------------|
| **jon@cosmickmedia.com** | Primary contact email | Full AI classification, Google Tasks for action items |

## Architecture

```
Cron (every 5 min) → mbsync → notmuch → mail-process.sh
    jon@: AI classification → Google Tasks for actionable items
```

## Quick Status

```bash
# How many unprocessed emails?
notmuch count "tag:new AND path:jon/**"

# Recent emails
notmuch search --limit=20 "path:jon/** AND tag:processed" --sort=newest-first

# Total email count
notmuch count "path:jon/**"
```

## Reading the Knowledge Base

```bash
# Current inbox status
cat ~/.mail/knowledge/inbox-status.md

# Pending action items (also in Google Tasks → Email list)
cat ~/.mail/knowledge/action-items.md

# Contact profiles (jon@ contacts)
ls ~/.mail/knowledge/contacts/
cat ~/.mail/knowledge/contacts/{name}.md

# Active threads
ls ~/.mail/knowledge/threads/
cat ~/.mail/knowledge/threads/{thread}.md

```

## Searching Email

```bash
# Search by sender
notmuch search "from:sarah@example.com"

# Search by subject
notmuch search 'subject:"project proposal"'

# Search by date range
notmuch search "date:2026-02-01..2026-02-16"

# Search with account filter
notmuch search "path:jon/** AND from:client@company.com"

# Full-text body search
notmuch search "body:invoice"

# Show a specific email (by message ID or search)
notmuch show "id:<message-id@example.com>"
```

## Reading Specific Emails

```bash
# Show email content (plain text)
notmuch show --format=text "from:sarah@example.com AND subject:proposal" | head -100

# Show as JSON (for parsing)
notmuch show --format=json "id:<message-id>" | python3 -m json.tool

# Extract with our helper (structured JSON output)
EXTRACT=~/.claude/skills/email/scripts/mail-extract.py
python3 $EXTRACT /path/to/email/file
```

## Archiving & Tagging

```bash
# Archive specific emails (remove from inbox view)
notmuch tag +archived -- "from:newsletter@example.com AND path:jon/**"

# Mark as spam
notmuch tag +spam -new -- "from:spammer@example.com"

# Manually tag
notmuch tag +important -- "subject:urgent AND path:jon/**"

# Remove tags
notmuch tag -new -- "path:jon/** AND from:*@godaddy.com AND subject:marketing"
```

## Manual Processing

```bash
# Run the full pipeline manually (sync + index + process)
~/.claude/skills/email/scripts/mail-process.sh

# Run bulk scan (one-time bootstrap)
~/.claude/skills/email/scripts/bulk-scan.sh --account jon

# Sync only (no processing)
mbsync jon && notmuch new
```

## Processing Log

```bash
# View recent processing activity
tail -50 ~/.mail/process.log

# Watch in real-time
tail -f ~/.mail/process.log
```

## File Locations

| Path | Purpose |
|------|---------|
| `~/.mail/jon/` | jon@ Maildir |
| `~/.mail/knowledge/` | AI-generated knowledge base |
| `~/.mail/process.log` | Processing pipeline log |
| `~/.mbsyncrc` | mbsync config (stowed from dotfiles) |
| `~/.config/notmuch/default/config` | notmuch config |
| `~/.config/mail/jon-app-password` | Google App Password (NOT stowed) |

## Credentials (NOT stowed, NOT committed)

- `~/.config/mail/jon-app-password` — Google App Password for jon@
- `~/.config/google-calendar/credentials.json` — GCP OAuth client credentials
- `~/.config/google-calendar/token.json` — OAuth token (auto-created)
