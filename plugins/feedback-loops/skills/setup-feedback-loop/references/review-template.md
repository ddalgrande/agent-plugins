# REVIEW.md template

Copy the block below to `REVIEW.md` at the repo root. Fill every `<...>` from
the repo. Keep the result under ~40 lines: every review loads it.

```markdown
# Review guidance

Read by every code reviewer — human or agent — for this repo.

## What failure looks like here
- `<path or area>`: <the failure, in a few words — e.g. "the number is wrong">
- `<path or area>`: <...>

## Always look hard at
- <sensitive paths from the high risk tier in docs/verification.md>

## Skip
- <generated, vendored, or lock files — e.g. `package-lock.json`, `dist/**`>

## How to report
- Tag each finding `Important` (must fix before merge), `Nit` (optional), or
  `Pre-existing` (a bug this diff did not introduce — do not block on it).
- Give file and line for every finding, and the command or test that shows
  the failure where one can be run. No evidence → do not post it.
- Do not post findings that are only about style or naming.
- At most 3 `Nit` findings per review.
- On a bug fix, check that the fix addresses the root cause, not the symptom.
- Start the summary with the count, e.g. "2 Important, 1 Nit". If nothing needs
  fixing, say so in one line.
```
