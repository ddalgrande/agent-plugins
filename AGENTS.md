# AGENTS.md

Instructions for coding agents working **on this repository**. If you are
looking for how to *install* these skills into your own project, see
[README.md](README.md).

## What this repo is

A collection of agent skills, distributed two ways from one source of truth:

- as **Claude Code plugins** (`plugins/*/` with `.claude-plugin/plugin.json`,
  listed in `.claude-plugin/marketplace.json`)
- as **portable Agent Skills** (`SKILL.md`) installable into `.agents/skills/`
  for Codex, Kimi, pi, and any other agent following the
  [Agent Skills standard](https://agentskills.io), via `./install.sh`

There is exactly one copy of each skill, at
`plugins/<plugin>/skills/<skill>/SKILL.md`. `install.sh` links or copies those
directories — it never transforms them. **Do not fork a per-agent variant of a
skill.** If something needs to differ per agent, it belongs in prose inside the
one `SKILL.md`, not in a second file.

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest (lists both plugins)
install.sh                        # portable installer for non-Claude agents
plugins/<plugin>/
├── .claude-plugin/plugin.json    # Claude Code plugin manifest
├── README.md
├── skills/<skill>/SKILL.md       # the skill — single source of truth
└── hooks/                        # Claude Code only (hooks.json + scripts)
```

## Rules for changing a skill

1. **Keep the frontmatter portable.** Only `name` and `description` are
   guaranteed across agents. `description` is what every agent matches against
   to decide whether to load the skill, so it must say *when to use it* and
   *when not to* — not just what it does.
2. **Body stays agent-neutral.** Write "your agent's instructions file
   (`AGENTS.md` / `CLAUDE.md`)", not just `CLAUDE.md`. Where you name an
   agent-specific command (e.g. `/code-review`), give the generic fallback in
   the same sentence.
3. **Claude-only features stay clearly labelled.** Hooks are the main one —
   `hooks/hooks.json` is a Claude Code mechanism with no cross-agent
   equivalent. A skill must remain useful without them.
4. **Bump versions on any skill change** — the plugin's
   `.claude-plugin/plugin.json` *and* its entry in
   `.claude-plugin/marketplace.json`. The two must not drift.

## Verifying a change

There is no test suite. Before opening a PR:

```bash
# every manifest still parses
python3 -c "import json,glob; [json.load(open(f)) for f in \
  glob.glob('.claude-plugin/*.json') + glob.glob('plugins/*/.claude-plugin/*.json') \
  + glob.glob('plugins/*/hooks/*.json')]"

bash -n install.sh plugins/ship/hooks/ship-gate.sh   # shell syntax
./install.sh --list                                  # every skill is discovered
./install.sh --dry-run                               # install plan is sane
```

If you changed `install.sh`, also run a real install into a throwaway directory
(`./install.sh --project /tmp/probe`) and confirm the skill directories arrive
complete, `references/` included.

## Conventions

- Plugin and skill names are lowercase-with-hyphens and must match across the
  directory name, `SKILL.md` `name:`, and the manifests.
- Keep each `SKILL.md` under ~500 lines; move detail into `references/`.
- The two plugins are deliberately separate: `feedback-loops` owns
  correctness, `ship` owns delivery. Do not let check commands leak into
  `ship`, and do not let branch/PR steps leak into `feedback-loops`.
