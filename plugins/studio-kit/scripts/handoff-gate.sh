#!/bin/bash
# handoff-gate.sh — Stop hook. Blocks the turn while code in an onboarded repo is newer than
# its handoff files (STATE.md, SESSIONS.md). Passes for repos without STATE.md.
# Only acts on git repos under $STUDIO_PROJECTS (default ~/projects).
# Invariant: the last commit touching code must be an ancestor of (or equal to) the last commit
# touching STATE.md/SESSIONS.md, and uncommitted code changes must come with uncommitted handoff changes.
set -u
IN=""; [ -t 0 ] || IN=$(cat)
field() { printf '%s' "$IN" | python3 -c "import sys,json
try: v=json.load(sys.stdin).get('$1'); print('' if v is None else v)
except Exception: print('')" 2>/dev/null; }
CWD=$(field cwd); SID=$(field session_id)
CWD="${CWD:-$PWD}"; SID="${SID:-nosession}"
[ -d "$CWD" ] || exit 0
REPO=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$REPO/STATE.md" ] || exit 0
ROOT="${STUDIO_PROJECTS:-$HOME/projects}"
case "$REPO/" in "$ROOT"/*) ;; *) exit 0;; esac
cd "$REPO" || exit 0
COUNTER="${TMPDIR:-/tmp}/claude-handoff-gate-$SID"

is_handoff() { case "$1" in STATE.md|SESSIONS.md|docs/prompts/*|.claude/*) return 0;; esac; return 1; }

stale=false; changed=()
# 1. uncommitted changes
dirty_handoff=false
while IFS= read -r line; do
  [ -n "$line" ] || continue
  p="${line:3}"; p="${p##* -> }"
  if is_handoff "$p"; then case "$p" in STATE.md|SESSIONS.md) dirty_handoff=true;; esac; else changed+=("$p"); fi
done < <(git status --porcelain --untracked-files=all 2>/dev/null)
if [ ${#changed[@]} -gt 0 ] && ! $dirty_handoff; then stale=true; fi
# 2. committed history: last code commit must be reachable from last handoff commit
if ! $stale && [ ${#changed[@]} -eq 0 ]; then
  last_code=$(git log -1 --format=%H -- . ':(exclude)STATE.md' ':(exclude)SESSIONS.md' ':(exclude)docs/prompts' ':(exclude).claude' 2>/dev/null)
  last_hand=$(git log -1 --format=%H -- STATE.md SESSIONS.md 2>/dev/null)
  if [ -n "$last_code" ]; then
    if [ -z "$last_hand" ] || ! git merge-base --is-ancestor "$last_code" "$last_hand" 2>/dev/null; then
      stale=true
      while IFS= read -r p; do changed+=("$p"); done < <(git show --name-only --format= "$last_code" 2>/dev/null | head -8)
    fi
  fi
fi

if ! $stale; then rm -f "$COUNTER"; exit 0; fi
n=0; [ -f "$COUNTER" ] && n=$(cat "$COUNTER" 2>/dev/null || echo 0)
if [ "$n" -ge 2 ]; then
  rm -f "$COUNTER"
  echo '{"systemMessage":"handoff-gate: STATE.md/SESSIONS.md still stale after 2 nudges; letting the turn end."}'
  exit 0
fi
echo $((n+1)) > "$COUNTER"
list=$(printf '%s, ' "${changed[@]:0:8}"); list="${list%, }"
python3 - "$list" <<'PY'
import json,sys
files=sys.argv[1]
reason=("Handoff is stale: code in this repo changed after STATE.md and SESSIONS.md were last updated "
        f"(for example: {files}). Before stopping: rewrite STATE.md (Now, Broken, Next), append or extend "
        "today's entry in SESSIONS.md (done, decisions and why, verified how), move finished prompts to "
        "docs/prompts/done/. The /handoff skill does this. Then stop.")
print(json.dumps({"decision":"block","reason":reason,"systemMessage":"handoff-gate: updating STATE.md and SESSIONS.md before stopping"}))
PY
exit 0
