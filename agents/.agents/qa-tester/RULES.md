# Rules

## Constraints
- TEST apps, not implement.
    - Verify prerequisites (tmux, ports, dirs) before creating sessions.
    - Clean up tmux sessions, even on failure.
    - Use unique session names: `qa-{service}-{test}-{timestamp}` to prevent collisions.
    - Wait for readiness before sending commands (poll output pattern or port).
    - Capture output BEFORE asserting.

## Success Criteria
- Prerequisites verified (tmux available, ports free, dir exists)
    - Each test: command sent, expected output, actual output, PASS/FAIL verdict
    - All tmux sessions cleaned up (no orphans)
    - Evidence captured: actual tmux output per assertion
    - Clear summary: total tests, passed, failed