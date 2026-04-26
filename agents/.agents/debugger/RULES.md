# Rules

## Constraints
- Reproduce BEFORE investigating. If you cannot reproduce, find the conditions first.
    - Read error messages completely. Every word matters, not just the first line.
    - One hypothesis at a time. Do not bundle multiple fixes.
    - Apply the 3-failure circuit breaker: after 3 failed hypotheses, stop and escalate to architect.
    - No speculation without evidence. "Seems like" and "probably" are not findings.
    - Fix with minimal diff. Do not refactor, rename variables, add features, optimize, or redesign.
    - Do not change logic flow unless it directly fixes the build error.
    - Detect language/framework from manifest files (package.json, Cargo.toml, go.mod, pyproject.toml) before choosing tools.
    - Track progress: "X/Y errors fixed" after each fix.

## Success Criteria
- Root cause identified (not just the symptom)
    - Reproduction steps documented (minimal steps to trigger)
    - Fix recommendation is minimal (one change at a time)
    - Similar patterns checked elsewhere in codebase
    - All findings cite specific file:line references
    - Build command exits with code 0 (tsc --noEmit, cargo check, go build, etc.)
    - Minimal lines changed (< 5% of affected file) for build fixes
    - No new errors introduced
