---
name: ship
description: Use to take a finished, green change out the door — when the user says "ship it", "ship this", "open a PR", "get this merged", "deliver this", or asks you to finish delivery. Runs the delivery loop — verify green → feature branch → rebase onto the latest base (re-running Layer 1 when the base moved) → /code-review → push → open the PR → watch it to green. Delivery only; it does NOT define or run the project's checks (that is feedback-loops' green-loop, reading docs/verification.md).
---

# Ship

Take a change that is already **green** and deliver it: onto a feature branch,
rebased on the latest base, reviewed, pushed, and up as a PR that stays watched
until it is mergeable. This skill owns **delivery**. It does **not** own code
quality — the checks live once in `docs/verification.md` and are run by the
`feedback-loops` plugin's `green-loop` skill. Ship *calls* that loop; it never
re-defines lint/test/build commands of its own.

> Split, so there is a single source of truth:
> **feedback-loops** = "is it correct?" (checks in `docs/verification.md`, run by `green-loop`).
> **ship** = "is it delivered?" (branch, rebase, review, push, PR, watch).

## The delivery loop

### 1. Verify green (delegate — do not re-implement)
Delivery starts only from a green tree. Run the `green-loop` skill
(`feedback-loops@ddalgrande-plugins`) to execute Layer 1 (and Layer 2 for
feature changes) from `docs/verification.md`. Do not hardcode or duplicate the
check commands here — if `green-loop` reports red, stop and fix; you are not
shipping a red change.

### 2. Get onto a feature branch
Delivery never happens as a direct commit to a protected branch (`main`,
`master`, `develop`, `release/*`).
- On a protected branch with un-shipped commits → create a feature branch
  (`git switch -c <type>/<slug>`) so those commits move with you, or cherry-pick
  them over. Never push work straight to a protected branch.
- Already on a feature branch → continue.

### 3. Rebase onto the latest base — and re-verify if the base moved
Fetch and rebase onto the current base branch so the PR is not stale:

```
git fetch origin
git rebase origin/<base>        # e.g. origin/main
```

**If the rebase pulled in new base commits (the base moved) or you resolved any
conflict, the earlier green is stale — re-run Layer 1 via `green-loop` before
continuing.** Code that was green against the old base is not proven green
against the new one. A clean rebase that fast-forwards nothing new does not need
a re-run. On conflicts, resolve them, `git rebase --continue`, then re-verify.

### 4. Pre-merge review (separate agent)
Get a fresh-context second pair of eyes (Layer 3) before the change goes up.
Run your agent's review command — `/code-review` in Claude Code, or the
equivalent elsewhere — and if it has none, dispatch a subagent with a clean
context and the diff. Address findings, and if you changed code in response,
loop back to step 1 (re-verify) — a review fix is a change like any other.

**Ask for findings you can act on.** Tell the reviewer (or brief the subagent)
to:
- tag each finding `Important`, `Nit`, or `Pre-existing` (a bug this diff did
  not introduce — record it, do not block this PR on it);
- give file and line evidence for each finding, and a command or test that
  shows the failure where one can be run — drop findings it cannot point at;
- drop findings that are only about style or naming;
- start its summary with the finding count, and say plainly when nothing needs
  fixing.

Fix every `Important` finding, or answer it with a short reason it is wrong or
intended. When a finding names a class of bug, fix every instance of that class
in the diff, not only the line the reviewer cited.

**Cap the review rounds.** One round = one review plus the fixes for it. Read
the cap from the Layer 3 section of `docs/verification.md`
(`max review rounds`); if it does not state one, use **3**.
- After round 1, re-review **only the new diff** since the last review, not the
  whole branch, and do not re-raise findings already answered.
- If the cap is reached and the reviewer still reports `Important` findings,
  **stop the loop.** Do not start another round. Tell the user the remaining
  findings and ask whether the approach itself is wrong. An author agent and a
  reviewer agent can otherwise loop without converging.

**When the same finding comes back.** If a reviewer flags the same kind of
problem that an earlier review or PR already flagged, propose moving the lesson
into structure — a lint rule, a test, a `docs/verification.md` check, or a line
in the repo's review guidance (e.g. `REVIEW.md`) — so the next change cannot
repeat it. Do not make that change in this PR unless the user agrees.

### 5. Push
```
git push -u origin <branch>
```

### 6. Open the PR
Open a PR into the base branch. Use the repo's PR template if one exists
(`.github/pull_request_template.md` and the usual locations); fill its sections
from the actual diff. Do not open a PR unless delivery is the user's intent
(they asked to ship / open a PR).

Whether or not a template exists, the body must contain these sections. Add
any the template lacks:
- **Testing** — evidence first: each command that ran and the decisive lines of
  its real output (or a screenshot / recording path), then one line of prose.
  Never a bare "tests pass".
- **Not proven** — what these checks do not show (e.g. "no device run",
  "tests cover the happy path only", "Layer 2 skipped: no simulator"). Write
  "nothing known" only if that is true. A reviewer who cannot see what the
  checks missed should do a full review, not a quick approval.
- **Risk** — the risk tier and why (see below).
- **How to revert** — the exact undo: revert the merge commit, turn off a named
  flag, or the manual steps if a revert is not enough (migrations, data
  changes, released builds).

**Risk tier — set by the change, not by the author.** If the Layer 3 section of
`docs/verification.md` defines risk tiers (path patterns mapped to how many
human approvals they need), match the changed paths against them. Each changed
path takes the highest tier whose pattern it matches; a path that matches no
pattern is medium. The change's tier is the highest tier among its paths, so a
change is low only if every path is low. Without tiers, use these defaults:
- **low** — docs, copy, comments, tests only, or additive behind a flag that is
  off: automated review and green CI are enough. Agent instruction files
  (`AGENTS.md`, `CLAUDE.md`, `SKILL.md`, review guidance) are not low.
- **medium** — ordinary product code: one human approval.
- **high** — auth, payments/billing, security, data migrations, release or
  install scripts, and any CI workflow file (`.github/workflows/*`): one human
  approval at least, two if the repo has a second maintainer.

State the tier in the **Risk** section. For medium and high, request a human
reviewer. An approval or review from a bot or agent never fills a slot that
needs a human, and the person who asked for an agent-written change counts as
its human reviewer only if they actually reviewed it.

### 7. Watch to green
After the PR is up, keep an eye on CI and reviews until it is mergeable
(subscribe to PR activity if the environment supports it). A red or conflicted
PR is not delivered. On CI failure: re-diagnose, fix (via `green-loop`), push,
let CI re-run. On merge conflict: rebase (step 3, which re-triggers re-verify),
push.

The review-round cap from step 4 also applies to reviews on the PR (an
automated PR reviewer re-running on each push counts as a round). Answer
reviewer findings by their tag the same way as in step 4. When the cap is
reached, stop pushing fixes. Reply on each open thread that it waits on the
user's decision, leave it unresolved, convert the PR to draft
(`gh pr ready --undo`, or your host's equivalent), and ask the user. Never
resolve a thread you did not fix just to finish.

**Close review threads visibly — pushing the fix isn't enough.** For each
review comment you address, *reply on that thread* saying what you changed (and
why, if you pushed back), then **mark the thread resolved**. A silent push
leaves the reviewer guessing whether you saw the comment; the commit closes the
code, but the reply + resolved thread is what closes the *conversation*. Don't
resolve a thread you only partially addressed, and don't resolve someone else's
thread without a reply. Delivery isn't done until every thread is either
resolved or has an explicit, unresolved reason it can't be.

## The Stop-hook gate (optional, opt-in, Claude Code only)
This plugin also ships a `Stop` hook (`hooks/ship-gate.sh`) that enforces the
*delivery* half deterministically: it refuses to let the session declare done
while the tree is dirty, work is stranded on a protected branch, the branch is
unpushed, or (when `gh` is available) the PR is red, conflicted, or unreviewed.

Hooks are a Claude Code mechanism with no cross-agent equivalent, so this
section applies only there. On other agents the steps above still work in full
— you just get the skill's discipline without the deterministic backstop.

- **Opt-in:** it does nothing unless `.claude/ship.config.json` exists in the repo.
- **Delivery only:** it runs **no** lint/tests/build — it never duplicates
  `green-loop`. It only inspects git/PR state.
- **Fails open:** missing config, no `jq`/`python3`, no `gh`, or detached HEAD →
  it allows the stop. It also gives up after `gate.max_blocks` consecutive
  blocks so a genuinely stuck delivery never traps the session.
- **Cannot see risk tiers:** its review check passes on a bot review with all
  threads resolved. That does **not** meet the human-approval rule for medium
  and high changes (step 6) — request the human reviewer anyway. A draft PR
  skips the review check, which is how the round-cap stop (step 7) passes it.

Minimal config:

```json
{ "gate": { "enabled": true, "max_blocks": 3 } }
```

Set `"enabled": false` to turn it off without deleting the file.

## Report
End with the delivery state the user can trust: branch, base it was rebased on,
whether a re-verify ran (and why), review outcome (rounds used of the cap, and
open findings by tag), risk tier, push status, and the PR URL + its CI state.
Say plainly if anything is still red or needs manual follow-up.

## Composition
- **feedback-loops → ship.** After `green-loop` reports green, hand off to
  `/ship`. `green-loop` proves correctness; `ship` delivers it. The two never
  duplicate each other's job.
