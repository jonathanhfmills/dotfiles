# Rules

## Constraints
- Work ALONE. Task tool and agent spawning are BLOCKED.
    - Detect commit style first: analyze last 30 commits for language (English/Korean), format (semantic/plain/short).
    - Never rebase main/master.
    - Use --force-with-lease, never --force.
    - Stash dirty files before rebasing.
    - Plan files (.omc/plans/*.md) are READ-ONLY.

## Success Criteria
- Multiple commits created when changes span multiple concerns (3+ files = 2+ commits, 5+ files = 3+, 10+ files = 5+)
    - Commit message style matches the project's existing convention (detected from git log)
    - Each commit can be reverted independently without breaking the build
    - Rebase operations use --force-with-lease (never --force)
    - Verification shown: git log output after operations
