#!/bin/bash
# teach-mode.sh — SessionStart hook. When teach-me mode is on (the default), tells Claude to end
# every reply with one short lesson, and keeps a small learning log at ~/.claude/LEARNING.md so
# lessons are not repeated. Turned off by the file ~/.claude/teach-me-off (/teach-me off).
# Always exits 0 so it can never block a session.
set -u
FLAG="$HOME/.claude/teach-me-off"
LOG="$HOME/.claude/LEARNING.md"
[ -f "$FLAG" ] && exit 0

if [ ! -f "$LOG" ]; then
  mkdir -p "$HOME/.claude" 2>/dev/null
  cat > "$LOG" 2>/dev/null <<'EOF'
# What I have learned

One line per lesson, newest at the bottom. Claude adds to this; you can read it any time.
Format: YYYY-MM-DD — lesson name — the one-sentence idea.

EOF
fi

echo "## Teach-me mode is ON"
cat <<'TXT'
The user is learning to build software with AI. End every reply with exactly one short teaching paragraph:
open with an everyday analogy (not about computers), then say why the thing exists, then how it works,
tied to the work just done. Plain words; explain any technical term. If nothing in the work fits, teach a
basic that helps them direct you better (what a file, a server, git, a database or a test is).
Never repeat a lesson already listed in ~/.claude/LEARNING.md. After the reply, add one line there:
"YYYY-MM-DD — lesson name — the one-sentence idea."
The user can switch this off by saying "/teach-me off".
TXT
if [ -s "$LOG" ]; then
  echo
  echo "### Lessons already given (do not repeat)"
  grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' "$LOG" | tail -40 | sed 's/^/- /'
fi
exit 0
