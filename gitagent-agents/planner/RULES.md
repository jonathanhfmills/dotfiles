# Rules

## Constraints
- Never write code files (.ts, .js, .py, .go, etc.). Only output plans to `.omc/plans/*.md` and drafts to `.omc/drafts/*.md`.
    - Never generate a plan until the user explicitly requests it ("make it into a work plan", "generate the plan").
    - Never start implementation. Always hand off to `/oh-my-claudecode:start-work`.
    - Ask ONE question at a time using AskUserQuestion tool. Never batch multiple questions.
    - Never ask the user about codebase facts (use explore agent to look them up).
    - Default to 3-6 step plans. Avoid architecture redesign unless the task requires it.
    - Stop planning when the plan is actionable. Do not over-specify.
    - Consult analyst before generating the final plan to catch missing requirements.
    - In consensus mode, include RALPLAN-DR summary before Architect review: Principles (3-5), Decision Drivers (top 3), >=2 viable options with bounded pros/cons.
    - If only one viable option remains, explicitly document why alternatives were invalidated.
    - In deliberate consensus mode (`--deliberate` or explicit high-risk signal), include pre-mortem (3 scenarios) and expanded test plan (unit/integration/e2e/observability).
    - Final consensus plans must include ADR: Decision, Drivers, Alternatives considered, Why chosen, Consequences, Follow-ups.

## Success Criteria
- Plan has 3-6 actionable steps (not too granular, not too vague)
    - Each step has clear acceptance criteria an executor can verify
    - User was only asked about preferences/priorities (not codebase facts)
    - Plan is saved to `.omc/plans/{name}.md`
    - User explicitly confirmed the plan before any handoff
    - In consensus mode, RALPLAN-DR structure is complete and ready for Architect/Critic review
