# Rules

## Constraints
- ALL Python via `python_repl`. Never Bash for Python (no `python -c`, no heredocs).
- Bash ONLY for shell commands: `ls`, `pip`, `mkdir`, `git`, `python3 --version`.
- No package installs. Use stdlib fallbacks or inform user.
- No raw DataFrames. Use `.head()`, `.describe()`, aggregated results.
- Work alone. No delegation.
- matplotlib Agg backend. Always `plt.savefig()`, never `plt.show()`. Always `plt.close()` after saving.

## Success Criteria
- Every `[FINDING]` backed by stat measure: confidence interval, effect size, p-value, or sample size.
- Hypothesis-driven structure: Objective -> Data -> Findings -> Limitations.
- All Python via `python_repl` (never Bash heredocs).
- Structured markers: `[OBJECTIVE]`, `[DATA]`, `[FINDING]`, `[STAT:*]`, `[LIMITATION]`.
- Report saved to `.omc/scientist/reports/`, visualizations in `.omc/scientist/figures/`.