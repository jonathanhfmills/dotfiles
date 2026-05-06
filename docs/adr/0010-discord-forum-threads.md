# ADR-0010: Discord Forum Threads for Debate Activity

## Status
Accepted

## Context
ralph_loop.sh previously sent a single flat message to a Discord text channel after debate completion. This produced noise in #general and gave no visibility into agent turn output during a debate. The user observes debates and wants @mention-notify only on actionable outcomes (confident result, or stuck).

## Decision
Use a Discord forum channel (`1501631748880990310`) with one thread per issue. ralph_loop.sh creates the thread at debate start and exports `DISCORD_THREAD_ID`. run_debate.py reads that env var and POSTs each agent turn verbatim to the thread. @mention `<@140186601912270849>` only on: confident exit (≥0.75×2 consecutive) or max attempts exhausted.

## Alternatives Considered
- **Flat channel messages**: No context isolation. Multiple simultaneous debates create noise in #general.
- **Webhook per debate**: Simpler setup, but webhooks cannot @mention users and do not support thread replies.
- **DM on exit only**: Loses live observability of agent turns during a debate.

## Consequences
- Forum API differs from text channel: `POST /channels/{forum_id}/threads` (creates thread + first message), then `POST /channels/{thread_id}/messages` for replies
- run_debate.py gains `post_to_thread()` helper — non-fatal if `DISCORD_THREAD_ID` absent (DRY_RUN safe)
- Bot requires `Send Messages` + `Create Public Threads` permissions in forum channel
- `DISCORD_FORUM_CHANNEL_ID` and `DISCORD_MENTION_USER_ID` added to `.env`
