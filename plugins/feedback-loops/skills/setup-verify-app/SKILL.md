---
name: setup-verify-app
description: Use when a project has no repeatable way for an agent to drive the real running app (web UI, CLI/TUI, service, mobile, desktop), or when the user asks to "make a verify skill", "create a verification skill for this app", "map the features to verify", or to audit or refresh an existing `verify-<app>` skill and its feature map. Writes a project-local `verify-<app>` skill (Launch, Doctor, Drive, Evidence, Cleanup, plus a `features/` map) and proves it by running it once. Not for typecheck/lint/test checks (use setup-feedback-loop and green-loop) and not for a one-off manual check.
---

# Setup Verify App

Layer 2 of the feedback loop drives the real app. The generic recipes in
`green-loop` (`references/e2e-recipes.md`) do not know this repo's ports, seed
data, selectors, or traps. This skill writes them down once, as a project-local
skill named `verify-<app>`, so any agent can read it cold in the middle of a
task and drive the app correctly. `green-loop` uses it for Layer 2 when it
exists.

**Pick the mode.** Decide which app to verify, then look for a skill named
`verify-<that app>` in both `.agents/skills/` and `.claude/skills/` (the Layer 2 `skill:` line in
`docs/verification.md` names it if one exists). Found → **maintain**. Not
found → **create**, even if skills for other apps exist (e.g. a second app in
a monorepo). Ignore other skills whose names only start with `verify-`. If you
cannot tell which app the user means, ask.

## Where it lives
`<skills>/verify-<app>/`, where `<skills>` is the project's skill folder. Use
the folder the repo already uses. If it has none, ask which agents the team
uses: `.claude/skills/` is read by Claude Code, `.agents/skills/` by Codex,
Kimi, pi, and other Agent Skills agents. If the team uses both, write the skill
once in `.agents/skills/verify-<app>/` and make `.claude/skills/verify-<app>` a
relative symlink to it — never two copies. `<app>` is the app's short name in
lowercase-with-hyphens.

## Scope
This skill writes only:
- `<skills>/verify-<app>/` — its `SKILL.md`, `features/`, and any helper
  scripts it owns;
- in create mode, one line in the Layer 2 section of `docs/verification.md`
  that points at the new skill (only if that file exists).

It never edits product code. If the app does something wrong, that is a product
bug: report it to the user and do not hide it in the map. It has no branch,
push, or PR steps — to deliver the result, hand off to the `ship` skill
(`/ship`), or follow the repo's own delivery process.

## Create mode

### 1. Learn the app from the repo
Answer each question from the code, docs, and CI. Ask the user only what you
cannot observe.
- **Surface** — what does a user touch: web UI, CLI/TUI, API, mobile app,
  desktop app? If there are several, pick the primary one and list the others.
- **Start** — the repo's own dev command (package scripts, Makefile, README,
  the Layer 2 section of `docs/verification.md`). Note ports, env vars, seed
  data, and auth.
- **Drive** — how an agent can operate it. Use the repo's existing harness
  first (Playwright, Cypress, Detox, Maestro specs, CLI scripts, documented
  endpoints). Only if none exists, take a generic recipe from `green-loop`'s
  `references/e2e-recipes.md`.
- **Observe** — what evidence exists: screenshots, accessibility snapshots,
  terminal transcripts, response bodies, logs, exit codes, stored data.
- **Isolate** — can two instances run side by side (ports, data dirs,
  profiles)? If yes, the generated skill starts its own instance on its own
  port and data dir. If not, it must stop and ask the user when another
  instance holds the port or data — for example the user's own dev server.
  Either way, the skill drives only the instance it started, and never stops
  one it did not start.

If the app does not build or start as it is, stop and report the exact
failure (command and error) to the user. Do not fix product code here — see
*Scope*. Only setup that belongs to verification (a disposable data dir, an
env file for the run, seed data) may live in the skill's own folder. A skill
written against a broken start teaches wrong steps.

### 2. Write `verify-<app>/SKILL.md`
Give it frontmatter: `name: verify-<app>` and a `description` that names the
app, the surface, and when to use it. Without frontmatter, agents do not find
the skill. Then write these sections. Fill each one with real values from
step 1. Leave no placeholder.
- **Launch** — the exact command that starts the app from an empty data dir,
  including migrations and seed data, and the signal that it is ready. Ready
  means usable, not only that a process answers. Launch writes the run's state
  (run dir, port, PID) to one state file at a path the other sections name, so
  a later shell can find the instance. It picks a free port when the app can
  run beside another instance. It refuses to start while a live instance from
  an earlier run is still recorded. For a short-lived CLI or TUI
  there is no server: build once, then start each drive in its own fresh,
  isolated session.
- **Doctor** — one read-only check that the instance is worth driving: the
  process is up, it is the right build, the port belongs to this run, auth is
  valid. "Right build" means the version or commit the app reports matches the
  checkout; if the app reports neither, say which check stands in for it. Run it before the first drive and after anything surprising.
- **Drive** — the harness commands with this repo's real handles: accessible
  names, test IDs, routes, prompt strings, CLI flags. Do not use screen
  coordinates or tab order. Say which directory each command runs from and
  which env vars it needs (e.g. a CLI that must be told the run's port).
- **Evidence** — what to capture for a proof, and the path where it goes
  (outside the repo, or a gitignored path). State the proof rules:
  - drive the real user path, not internal setters or test-only endpoints;
  - capture the action and the resulting state, not only the final screen;
  - assert exact results (counts, values, exit codes), so an input the app
    silently ignores makes the proof fail instead of pass;
  - cover at least one error path per feature (bad input, missing item);
  - check side effects (files, rows, messages) as well as what is visible;
  - use mocks only where production already isolates the external system;
  - for a dry-run or test mode, observe what it really skips — do not trust
    its name.
- **Cleanup** — stop only what this run started (the PIDs, containers, or
  sessions it recorded). Never kill by process name. Keep the evidence and the
  app logs; remove the state file and scratch data. Running Cleanup twice, or
  after a failed Launch, must be safe.
- **Helpers** — make every script the skill ships executable, and show its
  invocation in the skill body. Keep run state safe: create the run directory
  with `mktemp -d` (private, owned by the current user), not a fixed shared
  path such as `/tmp/<app>-verify`. Read saved state (PIDs, ports) by parsing
  and checking it — never `source` or `eval` a state file.

Write for an agent that has never seen the app and reads the skill in the
middle of a task.

### 3. Seed the feature map
Write `verify-<app>/features/README.md` and one file per user-facing feature.
Start with the top 3–5 features, found from routes, commands, menus, or docs.
Use the shape in `references/feature-map-template.md` (relative to this skill).
Each feature file says, from the user's side: what the feature does, its
sub-features with short IDs, every entry point a user has, how to drive each
step (action → exact command → observable result), and the gotchas.

Two rules keep the map honest:
- If the seed data lacks a precondition that a journey needs, the journey
  fails and the reason goes in that feature's gotchas. Never weaken a journey
  so that it passes.
- A proof through one entry point does not prove the others the map lists.

### 4. Prove it — run it once, end to end
Follow the generated skill exactly: Launch → Doctor → drive **one** mapped
feature through every entry point the map lists for it → capture evidence →
Cleanup. Then confirm the evidence is still at its
named path; a cleanup that deletes the proof fails this step. Fix what fails and
run it again. Run the generated cleanup after every failed attempt, so failed
attempts do not leave processes or ports behind. A skill that was never run is
a draft, not a deliverable.

If you proved it in a stand-in for the real target (a container instead of a
device, a local stack instead of a remote one), list each setup step the
stand-in did that the real target will not. Those steps stay unverified.

### 5. Wire it in and report
- If `docs/verification.md` exists, add this line to its Layer 2 section:
  `- skill: verify-<app> (feature map: <skills>/verify-<app>/features/)`.
  If it does not exist, say so in the report and suggest `setup-feedback-loop`;
  until then agents find the skill only by its frontmatter.
- Report the skill's path, the features you mapped, the feature you proved and
  the path to its evidence, and anything still unverified. Suggest that the
  user commits the skill so teammates and future sessions get it.

## Maintain mode
Use it when the app changed, when a Layer 2 run found the map wrong, or when
the user asks to audit the skill. The unit of work is the feature: cover every
feature file from source and drive every feature live.

1. **Index.** Read `features/README.md` and list the feature files beside it.
   Fix missing, extra, duplicate, or dead entries.
2. **Read each feature from source.** If your agent can dispatch subagents,
   give each feature file to its own read-only subagent, in parallel;
   otherwise do them one by one. Each returns: a summary of how the feature
   works, its source entry points, likely drift with file:line citations (or
   "none"), and one live recipe. These readers never drive the app and never
   edit files.
3. **Reconcile.** Merge the recipes into as few app states as you can.
   Spot-check the cited drift. Look at recent changes for user-facing features
   the map lacks: `git log` since the map last changed, or, if the map was
   never committed, the changes the user names or the recent commits. Call a feature
   missing only with a concrete source path.
4. **Drive every feature live** — even when the source looks clean. You are
   the only driver. Follow the skill's own Launch model. Hold these rules for
   the whole pass:
   - run Doctor before the first drive and after every failed drive; when
     Doctor cannot see the problem (a stuck UI on a healthy process), reset to
     a known state or relaunch;
   - check that the evidence so far is still at its path after every cleanup;
   - clean up what each failed drive left behind before the next drive.

   If Doctor fails because the skill is out of date, fix the skill and retry
   once; if it still fails, the outcome is `blocked`. A feature you cannot
   reach is "unreachable" only with the missing prerequisite (auth,
   entitlement, OS, external state) and the route you tried.
5. **Triage.**
   - The map describes the feature wrongly → doc drift: fix the map.
   - The feature works but the harness cannot drive it → harness gap: fix the
     harness, then drive it again live before you keep the fix.
   - The app is broken → product gap: report it to the user. Do not edit
     product code and do not change the map to match the bug.
6. **Outcome.** Report exactly one:
   - `clean` — every feature was covered from source and live; nothing to change.
   - `changed` — proven fixes to the skill or map, listed per feature.
   - `blocked` — coverage could not finish; say exactly what blocked it.

   Give coverage per feature (driven / unreachable + prerequisite). Changes
   stay inside the skill's folder; to deliver them, hand off to `ship`.

## Composition
- `setup-feedback-loop` points Layer 2 at this skill when the app needs more
  than a generic recipe.
- `green-loop` uses `verify-<app>` for Layer 2 when it exists, and gives it to
  the independent verdict agent. When a Layer 2 run finds the map wrong, it
  fixes the one feature file it proved wrong, and suggests a maintain pass for
  wider drift.
- `ship` delivers the result. This skill never branches, pushes, or opens PRs.
