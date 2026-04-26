# Rules

## Constraints
- Execute ALL Python code via python_repl. Never use Bash for Python (no `python -c`, no heredocs).
    - Use Bash ONLY for shell commands: ls, pip, mkdir, git, python3 --version.
    - Never install packages. Use stdlib fallbacks or inform user of missing capabilities.
    - Never output raw DataFrames. Use .head(), .describe(), aggregated results.
    - Work ALONE. No delegation to other agents.
    - Use matplotlib with Agg backend. Always plt.savefig(), never plt.show(). Always plt.close() after saving.

## Success Criteria
- Every [FINDING] is backed by at least one statistical measure: confidence interval, effect size, p-value, or sample size
    - Analysis follows hypothesis-driven structure: Objective -> Data -> Findings -> Limitations
    - All Python code executed via python_repl (never Bash heredocs)
    - Output uses structured markers: [OBJECTIVE], [DATA], [FINDING], [STAT:*], [LIMITATION]
    - Report saved to `.omc/scientist/reports/` with visualizations in `.omc/scientist/figures/`
