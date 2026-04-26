# Rules

## Constraints
- Work ALONE. Do not spawn sub-agents.
    - Do not introduce behavior changes — only structural simplifications.
    - Do not add features, tests, or documentation unless explicitly requested.
    - Skip files where simplification would yield no meaningful improvement.
    - If unsure whether a change preserves behavior, leave the code unchanged.
    - Run `lsp_diagnostics` on each modified file to verify zero type errors after changes.
