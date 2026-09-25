#!/bin/bash
# project-orient.sh — SessionStart hook. Prints the project's orientation into Claude's context.
#   Project on the system (has STATE.md): STATE.md, SESSIONS.md tail, prompt queue, handoff rule.
#   Project not yet on the system:        instructions to set it up first.
# Only acts on git repos under $STUDIO_PROJECTS (default ~/projects).
# Read-only. Always exits 0 so it can never block a session.
set -u
CWD=""
if [ ! -t 0 ]; then
  CWD=$(python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("cwd") or "")
except Exception: print("")' 2>/dev/null)
fi
CWD="${CWD:-$PWD}"
[ -d "$CWD" ] || exit 0
REPO=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$REPO" ] || exit 0
NAME=$(basename "$REPO")
ROOT="${STUDIO_PROJECTS:-$HOME/projects}"
case "$REPO/" in "$ROOT"/*) ;; *) exit 0;; esac

if [ ! -f "$REPO/STATE.md" ]; then
  cat <<ONB
## Project orientation: $NAME has no notes yet
Before the first task, set up this project's notes (a few minutes), then tell the user in one line that you did:
1. Read CLAUDE.md and README.md if they exist, and \`git log --oneline -30\`.
2. CLAUDE.md in the project: keep only project facts (what it is, how to run it, how to test it, what to ask before). Add a last line \`@STATE.md\`. Create it if missing.
3. Write STATE.md from the template in the handoff skill.
4. Create SESSIONS.md with one first entry saying what the project is and where it stands.
5. Create docs/prompts/ for planned work (finished plans go in docs/prompts/done/).
ONB
  exit 0
fi

echo "## Orientation for $NAME"
if ! grep -q '^@STATE\.md' "$REPO/CLAUDE.md" 2>/dev/null; then
  echo "### STATE.md (current truth)"; head -80 "$REPO/STATE.md"; echo
fi
if [ -f "$REPO/SESSIONS.md" ]; then
  echo "### Recent sessions (end of SESSIONS.md)"; tail -60 "$REPO/SESSIONS.md"; echo
fi
if ls "$REPO"/docs/prompts/*.md >/dev/null 2>&1; then
  echo "### Planned work (docs/prompts/)"; ls "$REPO"/docs/prompts/*.md | xargs -n1 basename | sed 's/^/- /'; echo
fi
cat <<REM
### Handoff rule
After any change to this project: rewrite STATE.md (Now, Broken, Next), add to today's entry in SESSIONS.md, and move finished plans to docs/prompts/done/. The /handoff skill does all three. A Stop hook blocks the turn while the code is newer than these notes.
REM
exit 0
