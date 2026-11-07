---
name: green-loop
description: Use after editing code and before declaring a task done, or when the user asks to "verify", "run the feedback loop", "is it green", "self-verify", or "make sure it actually works". Runs the project's recorded checks, fixes failures, and re-runs until everything is green — then reports honestly. Reads docs/verification.md (runs setup-feedback-loop first if it is missing).
---

# Green Loop

Execute the project's feedback loop: run each check, observe, fix failures, re-run until green. This is the loop that lets you finish ambitious work without the user babysitting every step.

## 0. Load the loop definition
- Read `docs/verification.md` (the project's checklist; CLAUDE.md's verification pointer names it if it lives elsewhere, e.g. `.claude/rules/testing.md`).
- **Missing?** Invoke the `setup-feedback-loop` skill once to create it, then continue. (If the user wants a quick one-off and won't persist anything, detect the obvious checks ad hoc — typecheck, lint, test — and run those instead.)

## 1. Define success criteria first
State, in one line, what "done" means for *this* change before running anything — e.g. "all Layer 1 checks pass and the new endpoint returns 200 with the expected body." Weak criteria ("make it work") make the loop unverifiable; concrete criteria let it run independently. The standing bar is the **Definition of Done** in `docs/verification.md` (Layer 1 green, Layer 2 verified, no regressions, docs updated, Layer 3 clean); this step restates it concretely for the change at hand.

## 2. The loop — Layer 1 (internal checks)
Run checks in the recorded order (fast → slow: typecheck → lint → test → build). For each:

```
run check
 ├─ pass → next check
 └─ fail → read the actual error → form a hypothesis → make the smallest fix
           → re-run THAT check → continue the loop
```

Loop discipline:
- **Re-run after every fix.** A fix isn't done until its check is green.
- **Read real output.** Quote the actual error to yourself; don't pattern-match a guess.
- **Bound the retries.** If the same check fails ~3 times with no progress, stop looping. Summarize what you tried, the current error, and ask the user — that's a real `needs input:`, not a failure to grind harder.
- **Don't move the goalposts.** Never weaken a check, skip a failing test, add `|| true`, or mark a box done to make the loop pass. A green loop you faked is worse than a red one you reported.

## 3. Layer 2 — end-to-end (feature changes)
Unit tests passing ≠ the feature works. If the change is user-facing, run the recorded real-app leg and **observe actual behavior** — seeing it work, not inferring it from tests.

**Use the repo's `verify-<app>` skill first.** If the project has one (in its skill folder, e.g. `.agents/skills/verify-*/` or `.claude/skills/verify-*/`, or named in the Layer 2 section of `docs/verification.md`), follow it: Launch, Doctor, then drive each feature in its `features/` map that the change touches, capture its evidence, and Cleanup. It knows this repo's ports, seed data, and handles; the generic recipes below do not. If a step in the map is wrong, finish the verification, fix that one feature file if the fix is clear and proven by your run, and list it in the report. For wider drift, suggest a `setup-verify-app` maintain pass in the report — do not run it in the middle of this task. If the repo has no such skill and its Layer 2 needs more than a generic recipe, suggest `setup-verify-app` in the report.

Without a `verify-<app>` skill, follow the concrete recipes in `references/e2e-recipes.md` (relative to this skill):
- **Backend** → boot the service, hit the changed endpoint (happy + error + auth paths), assert status/body, and grep the logs — a 200 with a stack trace is still a bug.
- **Web UI** → start the dev server, drive the flow with Playwright (or chrome-devtools MCP), screenshot key states, and assert zero console errors / no failed network requests — not just that pixels look right.
- **Video / glitch capture** → for animated or visually sensitive changes, record the flow (Playwright `recordVideo`, chrome-devtools performance trace, or mobile-mcp screen recording) and **review the recording** for jank, flicker, layout shift, and broken transitions that a static screenshot can't show. Never claim "no glitches" off a recording you didn't actually inspect.

Use whichever MCP/tool the environment has (preference order in the recipes file); save artifacts to a temp dir, not the repo. If a leg can't run here (no device, external dependency), say so explicitly and list what the user must verify manually — don't silently claim it works.

**Independent verdict for risky changes.** An author checks what it meant to build, not what it built. When the change is **medium or high** in the risk tiers of `docs/verification.md` — or, when no tiers exist, any change that is not only docs, copy, comments, or tests (agent instruction files such as `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, `REVIEW.md` are never low) — have an agent that did **not** write the code run the Layer 2 leg: dispatch a fresh-context subagent with the diff, the intent in one line, and the Layer 2 section (and the path to the `verify-<app>` skill, if the repo has one). It reports `PASS`, `PASS+NOTES`, or `FAIL`, each with the commands it ran, their output, and the evidence paths. Your own Layer 2 run stays as a first pass; the independent verdict is the one you report. On `FAIL`, fix, re-run Layer 1, and dispatch a new subagent; apply the same ~3-attempt bound as Layer 1, then stop and ask. If your agent cannot dispatch a subagent, say so in the report and list the Layer 2 checks the user should repeat.

## 4. Layer 3 — pre-merge review (before PR/merge)
When the change is headed for a PR or merge, get a **second pair of eyes from a separate agent**: run whatever review command your agent provides (`/code-review` or `/review` in Claude Code, `$code-review` in Codex, `/skill:code-review` in Kimi or pi), or failing that dispatch a subagent with a fresh context and the diff. What matters is that the reviewer did **not** write the code — a fresh-context reviewer catches what the author-context agent rationalized past. Address findings, then re-run Layer 1.

Review loop rules (the `ship` skill applies the same rules in full):
- Give the reviewer the repo's review guidance (`REVIEW.md`, if it exists) along with the diff. On a stacked branch (its PR targets another feature branch), "the diff" is against that parent branch (`git diff <parent>...HEAD`), not against the base — here and for the independent Layer 2 verdict.
- Ask the reviewer to tag each finding `Important`, `Nit`, or `Pre-existing`, give file and line evidence, and drop style-only findings.
- **Cap the rounds.** Use `max review rounds` from the Layer 3 section of `docs/verification.md`, or **3** if it is not set. After round 1, re-review only the new diff. At the cap, if `Important` findings remain, stop and ask the user whether the approach is wrong — do not start another round.

> Layer 3 review is part of *delivery*. If the `ship` plugin is installed, this step is folded into `/ship` (see step 7) — don't run it twice.

## 5. Turn repeated mistakes into checks
Before reporting, look at what went red during this loop and what the reviewer flagged. For each failure that a check could have caught earlier — and especially one that has happened before in this repo — propose the structural fix: a test, a lint rule, a type, a new line in `docs/verification.md`, or a line in the repo's review guidance (e.g. `REVIEW.md`). An instruction repeated in prose is a symptom; a check is the fix. Make the change only if it is in scope for the current task or the user agrees; otherwise list it in the report.

## 6. Report
End with a tight status the user can trust:
- ✅ each check that passed — evidence first: the command and the decisive lines of its real output, so it's auditable.
- ⚠️ anything skipped and why (e.g. "e2e: no simulator in this env — verify manually").
- 🕳️ **not proven** — what the green checks do not show (e.g. "tests cover the happy path only", "no device run"). A green check proves one property; say which ones it did not.
- 🔁 any proposed mistake-to-check fixes from step 5.
- 📝 docs updated for any behavior/API/flag/setup change (or state "no docs impact").
- The success criteria from step 1, marked met / not met.

State results plainly. If something failed, say so with the output. Only write a completion headline once the loop is actually green against the criteria you set.

## 7. Hand off to delivery
Green proves the change is **correct** — it does not deliver it. When the change is meant to go out (the user asked to ship / open a PR / merge), hand off to the `ship` skill (`/ship`, from `ship@ddalgrande-plugins`): it takes the green change onto a feature branch, rebases onto the latest base (re-running this loop's Layer 1 if the base moved), runs Layer 3 review, pushes, opens the PR, and watches it to green. Keep the split clean — this loop owns *correctness*, `ship` owns *delivery*; don't reimplement branch/push/PR steps here.

## Composition
- Pair with `setup-feedback-loop` (defines the loop) — this skill (runs it).
- Hand off to `ship` (`/ship`) once green when the change is headed out the door — correctness here, delivery there.
- For unattended/background runs, this loop is the safety rail: it keeps working until green or until it hits a real blocker worth surfacing.
