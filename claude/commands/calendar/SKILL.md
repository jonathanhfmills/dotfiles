---
name: calendar
description: Manage Google Calendar events and Google Tasks. Add/list/complete tasks, create events, and manage the "Email" task list used by the email pipeline. Triggers on "calendar", "schedule", "event", "task", "agenda", "tasks".
---

# Google Calendar & Tasks Management

All commands use the `gcal` CLI script which wraps the Google Calendar and Tasks APIs.

## CLI Tool

Script location: `~/.claude/skills/calendar/scripts/gcal`

```bash
GCAL=~/.claude/skills/calendar/scripts/gcal
```

### Authentication

Uses a GCP service account (cosmo-911@cosmo-485701.iam.gserviceaccount.com) with domain-wide delegation to impersonate jon@cosmickmedia.com. No interactive OAuth flow needed.

```bash
# Test authentication
$GCAL auth
```

Requires:
- `~/.config/google-calendar/service-account.json` — GCP service account key
- Domain-wide delegation enabled in Google Workspace Admin for the service account
- Scopes: `https://www.googleapis.com/auth/calendar`, `https://www.googleapis.com/auth/tasks`

## Tasks

The email pipeline creates tasks on the **"Email"** task list. Personal tasks use the default list.

```bash
# List pending tasks (Email list, the default)
$GCAL tasks list

# List tasks due today
$GCAL tasks list --due today

# List tasks from a different list
$GCAL tasks list --tasklist "My Tasks"

# Add a task
$GCAL tasks add "Review proposal from Sarah" --due 2026-02-20 --notes "See email thread about Q2 budget"

# Add task due today
$GCAL tasks add "Reply to hosting inquiry" --due today

# Add task due in 3 days
$GCAL tasks add "Follow up on invoice" --due +3d

# Complete a task
$GCAL tasks complete TASK_ID

# Delete a task
$GCAL tasks delete TASK_ID
```

### Due date formats
- `today`, `tomorrow` — relative
- `+Nd` — N days from now (e.g., `+3d`)
- `YYYY-MM-DD` — absolute date

## Events

```bash
# List events for next 7 days
$GCAL events list

# List events for next 30 days
$GCAL events list --days 30

# Add a timed event
$GCAL events add "Meeting with client" --date 2026-02-20 --time 14:00 --duration 90

# Add an all-day event (omit --time)
$GCAL events add "Company retreat" --date 2026-03-01
```

Events default to 60 minutes if `--duration` is not specified. Timezone: America/New_York.

## Task Lists

```bash
# List all task lists
$GCAL tasklists list

# Create a new task list
$GCAL tasklists create "Project Alpha"
```

The "Email" task list is auto-created on first use by the email pipeline.

## Architecture Notes

- **Google Tasks** (not calendar events) are used for email action items because:
  - Tasks have checkboxes (done/not done)
  - Don't block calendar time
  - Show in Calendar sidebar
  - Better semantic fit for "review this email" / "reply to X"
- The email processing pipeline (`mail-process.sh`) creates tasks automatically
- Jon checks calendar tasks at his own pace — no notifications
- Service account key at `~/.config/google-calendar/service-account.json` (NOT stowed, NOT committed)
- GCP project: cosmo-485701, service account: cosmo-911
