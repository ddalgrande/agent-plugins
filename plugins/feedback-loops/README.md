# feedback-loops

Encode your verification processes as skills so your coding agent **self-verifies** and finishes ambitious tasks with less babysitting.

Based on Anthropic's [_Feedback loops: Help Claude Code complete ambitious tasks with less babysitting_](https://www.anthropic.com/engineering). Core idea: the more the agent can self-verify, the more independently it works, the higher the quality, and the fewer back-and-forths it takes.

## Skills

| Skill | Run | Does |
|---|---|---|
| `setup-feedback-loop` | once per project | Auto-detects the stack, finds the real verify commands (matching CI), writes a reusable `docs/verification.md`, and adds a prose pointer to it in `AGENTS.md`/`CLAUDE.md`. |
| `green-loop` | every change, before "done" | Runs the recorded checks, fixes failures, re-runs until green, then reports honestly. |

Both trigger automatically from context, or invoke by name.

## The loop

```
setup-feedback-loop  →  docs/verification.md  →  green-loop (run→observe→fix→repeat until green)
```

Three layers of verification:
1. **Internal checks** — typecheck, lint, test, build (fast, every change).
2. **End-to-end** — drive the running app and observe real behavior (feature changes).
3. **Pre-merge review** — a separate agent (`/code-review`) before PR/merge.

Once green, hand off to the companion [`ship`](../ship/) plugin (`/ship`) to
deliver the change (feature branch → rebase → review → push → PR → watch).
feedback-loops owns **correctness**; ship owns **delivery** — the check commands
live once here (in `docs/verification.md`) and are never duplicated in ship.

`docs/verification.md` is a human-readable, committable doc (referenced from `AGENTS.md`/`CLAUDE.md` by a prose pointer, not a context-heavy `@import`), so every future session and teammate inherits the same verification contract — and it renders on GitHub.

## Install

Claude Code:

```bash
claude plugin marketplace add ddalgrande/agent-plugins
claude plugin install feedback-loops@ddalgrande-plugins
```

Codex, Kimi, or any other [Agent Skills](https://agentskills.io) agent — run
`./install.sh` from a clone of this repo to put both skills in
`~/.agents/skills/`. Both are portable; nothing in this plugin is
Claude-specific. See the [root README](../../README.md#install) for details.

## Principles

- **Honest over complete** — only records checks that actually run; never fakes a green.
- **Match CI** — the loop mirrors what merge gates on.
- **Surgical** — writes one file; doesn't reconfigure your project.
