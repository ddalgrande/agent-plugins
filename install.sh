#!/usr/bin/env bash
# Install these skills for any agent that reads the Agent Skills standard
# (SKILL.md). See README.md for the per-agent details.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="agents"
PROJECT_DIR=""
MODE=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Install the agent-plugins skills for a SKILL.md-compatible coding agent.

Usage:
  ./install.sh [target] [options]

Targets:
  agents              ~/.agents/skills        (default)
                      Read by Codex, Kimi, pi, and any agent following the
                      Agent Skills standard. One install covers them all.
  claude              ~/.claude/skills
                      For Claude Code without the plugin marketplace. Prefer
                      `claude plugin install` instead — it also gets the hooks.
  --project <dir>     <dir>/.agents/skills
                      Per-repo install so teammates and CI inherit the skills.

Options:
  --copy              Copy the skill directories (default for --project).
  --link              Symlink to this clone (default for user-level installs,
                      so `git pull` updates the skills in place).
  --list              List the skills this repo provides, then exit.
  --dry-run           Print what would happen, change nothing.
  -h, --help          Show this help.

Examples:
  ./install.sh                          # ~/.agents/skills, symlinked
  ./install.sh --copy                   # ~/.agents/skills, copied
  ./install.sh --project ~/code/my-app  # my-app/.agents/skills, copied
EOF
}

# Every skill in the repo, as "<name>|<absolute path>".
list_skills() {
  local dir
  for dir in "$REPO_ROOT"/plugins/*/skills/*/; do
    [ -f "${dir}SKILL.md" ] || continue
    printf '%s|%s\n' "$(basename "$dir")" "${dir%/}"
  done
}

while [ $# -gt 0 ]; do
  case "$1" in
    agents|claude) TARGET="$1"; shift ;;
    --project)
      TARGET="project"
      [ $# -ge 2 ] || { echo "error: --project needs a directory" >&2; exit 2; }
      PROJECT_DIR="$2"; shift 2 ;;
    --copy)    MODE="copy"; shift ;;
    --link)    MODE="link"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --list)
      list_skills | while IFS='|' read -r name path; do
        printf '%-22s %s\n' "$name" "${path#"$REPO_ROOT"/}"
      done
      exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument '$1' (try --help)" >&2; exit 2 ;;
  esac
done

case "$TARGET" in
  agents)  DEST="$HOME/.agents/skills";  MODE="${MODE:-link}" ;;
  claude)  DEST="$HOME/.claude/skills";  MODE="${MODE:-link}" ;;
  project)
    # A copy is the default here so the skills can be committed and travel
    # with the repo; a symlink into this clone would break for teammates.
    [ -d "$PROJECT_DIR" ] || { echo "error: no such directory: $PROJECT_DIR" >&2; exit 2; }
    DEST="$(cd "$PROJECT_DIR" && pwd)/.agents/skills"
    MODE="${MODE:-copy}" ;;
esac

SKILLS="$(list_skills)"
[ -n "$SKILLS" ] || { echo "error: no skills found under $REPO_ROOT/plugins" >&2; exit 1; }

echo "Installing to $DEST (mode: $MODE)"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run — nothing will be written)"

[ "$DRY_RUN" -eq 1 ] || mkdir -p "$DEST"

while IFS='|' read -r name path; do
  target="$DEST/$name"

  # Only ever replace something we own: our own symlink, a directory that looks
  # like a previously installed copy of this skill, or an empty leftover
  # directory. Anything else holds content we did not put there, so leave it.
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ -L "$target" ] || [ -f "$target/SKILL.md" ] || \
       { [ -d "$target" ] && [ -z "$(ls -A "$target")" ]; }; then
      [ "$DRY_RUN" -eq 1 ] || rm -rf "$target"
    else
      echo "  ! $name — $target exists and is not a skill; skipping" >&2
      continue
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  + $name ($MODE)"
    continue
  fi

  if [ "$MODE" = "link" ]; then
    ln -s "$path" "$target"
  else
    cp -R "$path" "$target"
  fi
  echo "  + $name"
done <<EOF
$SKILLS
EOF

cat <<EOF

Done. Restart your agent (or open a new session) so it rescans for skills.

  Codex   \$skill-name, or it picks the skill up on its own
  Kimi    /skill:skill-name
  pi      /skill:skill-name, or it picks the skill up on its own
  Claude  /skill-name
EOF
