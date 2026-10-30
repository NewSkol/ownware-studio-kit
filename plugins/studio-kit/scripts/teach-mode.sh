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

The AI adds one lesson per reply while teach-me mode is on, tied to the work we just did.
Each lesson opens with an everyday comparison, then why the thing exists, then how it works.

Stages: 🟡 taught once · 🟢 taught again from a different case and it stuck (never repeated).
A 🟡 lesson comes back once, from a new situation, before it turns 🟢.

## Areas

| Area | Stage | Last touched |
|---|---|---|
| Files, folders and the terminal | 🔴 | |
| Git: saving, history, undo | 🔴 | |
| Secrets and keys | 🔴 | |
| Servers, domains, deploys | 🔴 | |
| Databases and who sees what | 🔴 | |
| Tests and proof | 🔴 | |
| Directing the AI (plans, specs, context) | 🔴 | |
| Security basics | 🔴 | |
| Money: subscriptions, API costs | 🔴 | |

## Lessons (newest at the bottom)
Format: YYYY-MM-DD — lesson name — the one-sentence idea — 🟡 or 🟢

EOF
fi

echo "## Teach-me mode is ON"
cat <<'TXT'
The user is learning to build software with AI. End every reply with exactly one short teaching paragraph:
open with an everyday analogy (not about computers), then say why the thing exists, then how it works,
tied to the work just done. Plain words; explain any technical term. If nothing in the work fits, teach a
basic that helps them direct you better (what a file, a server, git, a database or a test is).
Stages in ~/.claude/LEARNING.md: never repeat a lesson marked 🟢 or with no mark. A lesson marked 🟡 may come
back once, from a different situation; when it does, change its mark to 🟢. After the reply, add one line
under Lessons: "YYYY-MM-DD — lesson name — the one-sentence idea — 🟡" and, if the file has an Areas table,
update that area's row (stage and date).
The user can switch this off by saying "/teach-me off".
TXT
if [ -s "$LOG" ]; then
  echo
  echo "### Lessons already given (🟢 or no mark: do not repeat; 🟡: only from a different situation)"
  grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' "$LOG" | tail -40 | sed 's/^/- /'
fi
exit 0
