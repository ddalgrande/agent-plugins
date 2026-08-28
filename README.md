# agent-plugins

Agent skills for making a coding agent verify its own work and deliver it.

Written to the [Agent Skills standard](https://agentskills.io) (`SKILL.md`), so
the same skills run in **Claude Code, OpenAI Codex, Kimi**, and the [30+ other
tools](https://agents.md) that read the format — and with **GLM**, **Kimi K2**,
or any other model, since the skills live in the harness, not the model. There
is one copy of each skill; nothing is forked per agent.

## Plugins

| Plugin | Owns | Does |
|---|---|---|
| [feedback-loops](plugins/feedback-loops/) | **Code quality** ("is it correct?") | Encode your verification process as skills so the agent self-verifies. Skills: `setup-feedback-loop` (once per project — detects the stack, writes `docs/verification.md`), `green-loop` (every change — runs the recorded checks until green). Based on Anthropic's [_Feedback loops_](https://www.anthropic.com/engineering) post. |
| [ship](plugins/ship/) | **Delivery** ("is it delivered?") | Take a green change out the door. Skill: `ship` (`/ship`) — verify → feature branch → rebase → `/code-review` → push → PR → watch. Plus an opt-in, fail-open `Stop`-hook gate that refuses "done" while delivery is incomplete. |

## The split — one source of truth for checks

The two plugins are deliberately separate, with **no duplicated check commands**:

- **feedback-loops owns code quality.** The verification checks are defined
  **once** in the project's `docs/verification.md` and run by `green-loop`
  (run → observe → fix until green).
- **ship owns delivery only.** `/ship` takes an *already-green* change through
  feature branch → rebase onto the latest base → `/code-review` → push → PR →
  watch. It **delegates** the actual checks back to `green-loop`; it never
  re-implements lint/test/build commands.
- **The `ship-gate` Stop hook checks delivery state only** — tree clean → not on
  a protected branch → pushed → PR green → not conflicted → review requested —
  and runs **no** lint/tests. It **fails open** (missing config / `jq` /
  `python3` / `gh` → allow) and is **opt-in** via `.claude/ship.config.json`.

```
green-loop  →  (green)  →  /ship  →  branch → rebase → review → push → PR → watch
   ▲                                    │
   └──── re-run Layer 1 if the ─────────┘
         rebase moved the base
```

The **rebase → re-verify** rule: when the rebase pulls in new base commits (or
you resolve a conflict), the old green is stale, so `/ship` re-runs Layer 1 via
`green-loop` before continuing.

## Install

### Claude Code (plugin marketplace)

Gets the skills **and** the optional `ship-gate` Stop hook:

```bash
claude plugin marketplace add ddalgrande/agent-plugins
claude plugin install feedback-loops@ddalgrande-plugins
claude plugin install ship@ddalgrande-plugins
```

Or from a local clone: `claude plugin marketplace add /path/to/agent-plugins`.

### Codex, Kimi, and other SKILL.md agents

```bash
git clone https://github.com/ddalgrande/agent-plugins
cd agent-plugins
./install.sh
```

That symlinks every skill into `~/.agents/skills/` — the shared discovery
directory Codex and Kimi both read — so one install covers them, and
`git pull` updates them in place. Then restart the agent:

| Agent | Invoke | Reads |
|---|---|---|
| Claude Code | `/green-loop` | plugin, or `~/.claude/skills/` |
| Codex | `$green-loop`, or picked up automatically | `~/.agents/skills/` |
| Kimi | `/skill:green-loop` | `~/.agents/skills/` |

Other options:

```bash
./install.sh --list                     # what this repo provides
./install.sh --dry-run                  # show the plan, change nothing
./install.sh --copy                     # copy instead of symlink
./install.sh --project ~/code/my-app    # into my-app/.agents/skills, committable
./install.sh claude                     # ~/.claude/skills (no hooks)
```

The installer never overwrites a directory it didn't create — if something
else already owns a skill name, it says so and skips it.

### GLM, and other models

GLM is a **model**, not an agent — it runs inside a harness (Claude Code via
Z.AI's Anthropic-compatible API, Cline, Roo Code, Kilo Code, TRAE). Install for
**the harness you use** and the skills work with whatever model is behind it.
Nothing here is model-specific.

### What's portable, and what isn't

| Piece | Claude Code | Codex / Kimi / others |
|---|---|---|
| The three skills | ✅ | ✅ |
| `docs/verification.md` contract | ✅ | ✅ — plain Markdown |
| `ship-gate` Stop hook | ✅ | ❌ — hooks have no cross-agent equivalent |

Only the hook is Claude-specific. Everywhere else the skills are advisory
rather than enforced, which is how they behave on Claude Code too unless you
opt into the gate.

> **Migrating from `ship@ship-tools`?** Uninstall it first
> (`claude plugin uninstall ship@ship-tools`) — otherwise both plugins register
> a `Stop` hook and the gate runs twice. The config schema also changed: the old
> `gates`/`paths` keys are removed; the gate now reads only `gate.enabled` and
> `gate.max_blocks` from `.claude/ship.config.json`.

See each plugin's README for full docs:
[feedback-loops](plugins/feedback-loops/README.md) ·
[ship](plugins/ship/README.md).

## Repository layout

```
.claude-plugin/marketplace.json       # marketplace manifest (lists both plugins)
AGENTS.md                             # instructions for agents working on this repo
install.sh                            # portable installer for non-Claude agents
plugins/feedback-loops/               # code-quality plugin
├── .claude-plugin/plugin.json
├── README.md
└── skills/
    ├── setup-feedback-loop/SKILL.md
    └── green-loop/
        ├── SKILL.md
        └── references/e2e-recipes.md
plugins/ship/                         # delivery plugin
├── .claude-plugin/plugin.json
├── README.md
├── skills/ship/SKILL.md
└── hooks/
    ├── hooks.json                    # registers the Stop-hook gate
    └── ship-gate.sh                  # delivery-state gate (fail-open, opt-in)
```

## License

MIT
