# QWEN.md

Behavioral guidelines cut common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** Bias toward caution over speed. Trivial tasks: use judgment.

## 1. Think Before Coding

**No assumptions. No hidden confusion. Surface tradeoffs.**

Before implementing:
- State assumptions explicitly. Uncertain → ask.
- Multiple interpretations exist → present them, don't pick silently.
- Simpler approach exists → say so. Push back when warranted.
- Unclear → stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No unrequested "flexibility" or "configurability".
- No error handling for impossible scenarios.
- 200 lines when 50 works → rewrite.

Ask: "Would senior engineer call this overcomplicated?" Yes → simplify.

## 3. Surgical Changes

**Touch only what you must. Clean only your own mess.**

Editing existing code:
- Don't "improve" adjacent code, comments, formatting.
- Don't refactor non-broken things.
- Match existing style.
- Unrelated dead code → mention, don't delete.

When changes create orphans:
- Remove imports/variables/functions YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

Test: every changed line traces directly to user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

Multi-step tasks → brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong criteria → loop independently. Weak criteria ("make it work") → constant clarification.

---

**Working if:** fewer unnecessary diff changes, fewer overwrought rewrites, clarifying questions before mistakes not after.

## 5. Keep AGENTS.md Current

After changes: update root `AGENTS.md` + `AGENTS.md` in each dir touched. Reflect new targets, removed files, changed patterns, etc.

## 6. README Is a Product Artifact

README = front door. Non-technical readers decide if worth installing. Treat like UI copy.

- Readable by non-AI users. Translate jargon ("SessionStart hook" → "auto-runs on startup").
- Install commands must be complete + accurate. One broken command loses real users.
- Preserve intentional voice/brand. Quirky style is a choice — don't normalize it.
- Benchmark/metric numbers: verify against real runs. Never invent or round. Re-run if doubt.
- Readability check before commit: would non-programmer understand + install within 60 seconds?

## 7. Git Hygiene

After work in git repo: ask user "commit, push, or both? [both]" — default both.
