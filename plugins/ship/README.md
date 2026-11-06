# ship

Take a **green** change out the door: feature branch → rebase onto the latest
base → `/code-review` → push → PR → watch to green. Delivery only — it does
**not** define or run your project's checks. Those live once in
`docs/verification.md` and are run by the [`feedback-loops`](../feedback-loops/)
plugin's `green-loop`. Ship calls that loop; it never re-implements it.

> **Single source of truth.** `feedback-loops` answers *"is it correct?"* (checks
> in `docs/verification.md`, run by `green-loop`). `ship` answers *"is it
> delivered?"* (branch, rebase, review, push, PR, watch). No check command is
> duplicated across the two.

## What it does

| Piece | Kind | Does |
|---|---|---|
| `ship` | skill (`/ship`) | verify green (delegates to `green-loop`) → feature branch → rebase (**re-run Layer 1 when the base moved**) → `/code-review` → push → open PR → watch to green |
| `ship-gate` | Stop hook | opt-in, fail-open gate that refuses "done" while delivery is incomplete — **no lint/tests, delivery state only** |

## The rebase → re-verify rule

After rebasing onto the latest base, if the base moved (or you resolved a
conflict), the earlier green is stale — `ship` re-runs Layer 1 via `green-loop`
before continuing. Code proven green against the old base is not proven green
against the new one.

## Closing review threads

Pushing the fix isn't enough. For each review comment `ship` addresses, it
*replies on the thread* with what changed and **marks the thread resolved**, so
the review loop is visibly closed — the commit closes the code, the reply +
resolved thread closes the conversation. Delivery isn't done while a thread is
left silently open.

## Review rounds, findings, and risk

- **Findings are tagged** `Important` / `Nit` / `Pre-existing`, need file:line
  evidence, and style-only findings are dropped. Every `Important` is fixed or
  answered with a reason.
- **Rounds are capped** — `max review rounds` in `docs/verification.md`
  Layer 3, default 3. After round 1 only the new diff is re-reviewed. At the
  cap, `ship` stops and asks whether the approach is wrong, so an agent author
  and an agent reviewer cannot loop forever.
- **The PR body** always has **Testing** (commands + real output),
  **Not proven**, **Risk**, and **How to revert**.
- **Risk tier comes from the changed paths**, not the author (tiers in
  `docs/verification.md`, or built-in defaults). Medium and high need a human
  reviewer; a bot review never fills that slot.

## Stacked PRs

When the user asks for a stack (each PR targets the branch below it), `ship`
restacks with `git rebase --update-refs`, pushes with
`--force-with-lease --force-if-includes`, reviews each PR on its own diff, and
merges bottom up — retargeting the next PR to the base and dropping
squash-merged parent commits with `git rebase --onto`. An agent review verdict
survives a restack when the PR diff's `git patch-id --verbatim` is unchanged.
Human approvals dismissed by the push are requested again, and Layer 1 still
re-runs on any branch whose tree moved.

## The gate

The `Stop` hook (`hooks/ship-gate.sh`) enforces the delivery half
deterministically. It checks, in order:

1. working tree clean (tracked files; untracked-only is fine)
2. not stranded on a protected branch (`main`/`master`/`develop`/`release/*`)
3. branch pushed with an upstream, nothing unpushed
4. PR checks green *(needs `gh`)*
5. PR not conflicted *(needs `gh`)*
6. a review requested *(needs `gh`)*

It runs **no** lint, tests, typecheck, or build — that is `feedback-loops`'
job, and duplicating it here would create a second source of truth.

### Fail-open by design

- **Opt-in:** does nothing unless `.claude/ship.config.json` exists.
- Missing `jq` *and* `python3` → allows (a `python3` fallback covers the no-`jq`
  case).
- No `gh` / `gh` not authenticated → the GitHub-dependent checks are skipped
  (a pushed branch is allowed to stop).
- Detached HEAD, not a git repo, unreadable state → allows.
- Gives up after `gate.max_blocks` **consecutive** blocks, so a genuinely stuck
  delivery never traps the session.

### Config — `.claude/ship.config.json`

```json
{
  "gate": {
    "enabled": true,
    "max_blocks": 3
  }
}
```

| Key | Default | Meaning |
|---|---|---|
| `gate.enabled` | `true` | `false` disables the gate without deleting the file. |
| `gate.max_blocks` | `3` | Consecutive blocks before the gate gives up and fails open. |

The gate is invoked as `bash "${CLAUDE_PLUGIN_ROOT}/hooks/ship-gate.sh"`, so a
missing execute bit on the script does not matter.

## Install

Claude Code — gets the skill **and** the `ship-gate` Stop hook:

```bash
claude plugin marketplace add ddalgrande/agent-plugins
claude plugin install ship@ddalgrande-plugins
```

Pairs with `feedback-loops`:

```bash
claude plugin install feedback-loops@ddalgrande-plugins
```

Codex, Kimi, pi, or any other [Agent Skills](https://agentskills.io) agent — run
`./install.sh` from a clone of this repo to put the skill in
`~/.agents/skills/`. The delivery loop works in full there; only the Stop-hook
gate below is Claude-specific, since hooks have no cross-agent equivalent. See
the [root README](../../README.md#install) for details.

> **Migrating from `ship@ship-tools`?** Uninstall the old plugin first
> (`claude plugin uninstall ship@ship-tools`) — otherwise both register a `Stop`
> hook and the gate runs twice. The config schema also changed: the old
> `gates`/`paths` keys are gone; only `gate.enabled` and `gate.max_blocks`
> remain.

## Principles

- **Delivery, not quality.** Never re-runs the checks; delegates to `green-loop`.
- **Fail open.** A delivery gate that blocks on its own missing dependencies is
  worse than no gate.
- **Rebase then re-verify.** A moved base invalidates the old green.
