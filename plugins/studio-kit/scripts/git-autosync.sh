#!/bin/bash
# git-autosync.sh — keep the projects in ~/projects in sync with GitHub automatically.
#
#   pull <dir>   run at SessionStart: fast-forward from GitHub before you work
#   push <dir>   run at Stop:         commit + push what you changed
#
# Refuses to act unless the repo lives under a known project root, and refuses
# to commit secrets or mass deletions. Never force-pushes. Always exits 0 so a
# sync problem can never block a Claude Code session.

set -uo pipefail

MODE="${1:-}"
START_DIR="${2:-}"

# Claude Code sends the hook payload as JSON on stdin; it carries the session's
# working directory. Fall back to $PWD when there is no payload (manual runs).
if [ -z "$START_DIR" ]; then
  if [ ! -t 0 ]; then
    START_DIR=$(python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("cwd") or "")
except Exception:
    print("")' 2>/dev/null)
  fi
  START_DIR="${START_DIR:-$PWD}"
fi
LOG="$HOME/.claude/git-autosync.log"
ROOTS=("${STUDIO_PROJECTS:-$HOME/projects}")
# Repos we can't push to (other people's projects you cloned) — pull only.
# Add a name here, or put an empty file .studio-pull-only in the repo.
PULL_ONLY=()

log() { printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$MODE" "$1" >> "$LOG"; }
say() { printf '%s\n' "$1"; }

# --- locate the repo -------------------------------------------------------
[ -d "$START_DIR" ] || exit 0
REPO=$(git -C "$START_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$REPO" ] || exit 0
NAME=$(basename "$REPO")

# --- guard: must live under a known project root ---------------------------
under_root=false
for r in "${ROOTS[@]}"; do
  case "$REPO/" in "$r"/*) under_root=true; break;; esac
done
$under_root || exit 0


# --- guard: single instance per repo ---------------------------------------
if command -v sha1sum >/dev/null 2>&1; then HASH=sha1sum; else HASH=shasum; fi
LOCK="/tmp/.autosync-$(printf '%s' "$REPO" | $HASH | cut -c1-12).lock"
if ! mkdir "$LOCK" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

BRANCH=$(git -C "$REPO" branch --show-current 2>/dev/null)
[ -n "$BRANCH" ] || exit 0                          # detached HEAD: hands off
git -C "$REPO" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 || exit 0   # no upstream

is_pull_only() {
  [ -f "$REPO/.studio-pull-only" ] && return 0
  for p in "${PULL_ONLY[@]+"${PULL_ONLY[@]}"}"; do [ "$NAME" = "$p" ] && return 0; done
  return 1
}

# ===========================================================================
case "$MODE" in
pull)
  git -C "$REPO" fetch --quiet origin 2>/dev/null || { log "$NAME: fetch failed"; exit 0; }
  behind=$(git -C "$REPO" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
  ahead=$(git -C "$REPO" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  [ "$behind" -eq 0 ] && exit 0

  if git -C "$REPO" pull --ff-only --quiet origin 2>/dev/null; then
    log "$NAME: pulled $behind"
    say "{\"systemMessage\":\"⬇︎ $NAME: pulled $behind new commit(s) from GitHub\"}"
  else
    # local edits or divergence block the fast-forward — say so, change nothing
    log "$NAME: pull blocked (behind=$behind ahead=$ahead)"
    say "{\"systemMessage\":\"⚠︎ $NAME is $behind commit(s) behind GitHub but the pull was blocked (local changes or diverged history). Resolve before working.\"}"
  fi
  ;;

push)
  is_pull_only && exit 0

  if [ -z "$(git -C "$REPO" status --porcelain)" ]; then
    # nothing to commit; still push any commits made by hand this session
    ahead=$(git -C "$REPO" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
    if [ "$ahead" -gt 0 ] && git -C "$REPO" push --quiet origin HEAD 2>/dev/null; then
      log "$NAME: pushed $ahead"
      say "{\"systemMessage\":\"⬆︎ $NAME: pushed $ahead commit(s) to GitHub\"}"
    fi
    exit 0
  fi

  # --- guard: secrets ------------------------------------------------------
  secrets=$(git -C "$REPO" status --porcelain -uall 2>/dev/null | awk '{print $NF}' \
    | grep -iE '(^|/)\.env($|\.)|\.pem$|\.p12$|\.key$|id_rsa|\.jks$|\.keystore$|credentials\.json|service-account.*\.json' \
    | grep -viE '\.env\.(example|sample|template)$' | head -5)
  if [ -n "$secrets" ]; then
    # only block if it's NOT already tracked (an already-committed .env is pre-existing)
    newsecret=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      git -C "$REPO" ls-files --error-unmatch "$f" >/dev/null 2>&1 || newsecret="$newsecret $f"
    done <<< "$secrets"
    if [ -n "$newsecret" ]; then
      log "$NAME: BLOCKED, new secret file(s):$newsecret"
      say "{\"systemMessage\":\"⛔︎ $NAME: auto-sync stopped — these look like secrets and were NOT committed:$newsecret. Add them to .gitignore, then commit manually.\"}"
      exit 0
    fi
  fi

  # --- guard: mass deletion ------------------------------------------------
  dels=$(git -C "$REPO" status --porcelain | grep -c '^ *D' || true)
  total=$(git -C "$REPO" status --porcelain | wc -l | tr -d ' ')
  if [ "$dels" -gt 5 ] && [ $((dels * 2)) -gt "$total" ]; then
    log "$NAME: BLOCKED, $dels/$total are deletions"
    say "{\"systemMessage\":\"⛔︎ $NAME: auto-sync stopped — $dels of $total changes are file deletions. That usually means a stale copy overwrote the repo. Nothing was committed; review with 'git status'.\"}"
    exit 0
  fi

  # --- commit + push -------------------------------------------------------
  git -C "$REPO" add -A >/dev/null 2>&1
  git -C "$REPO" diff --cached --quiet && exit 0   # everything was ignored

  n=$(git -C "$REPO" diff --cached --name-only | wc -l | tr -d ' ')
  files=$(git -C "$REPO" diff --cached --name-only | head -3 | xargs -n1 basename 2>/dev/null | paste -sd', ' -)
  [ "$n" -gt 3 ] && files="$files and $((n-3)) more"
  git -C "$REPO" commit -q -m "Auto-sync: $files" -m "Committed automatically at the end of a Claude Code session." 2>/dev/null

  if git -C "$REPO" push --quiet origin HEAD 2>/dev/null; then
    log "$NAME: committed $n file(s) + pushed"
    say "{\"systemMessage\":\"⬆︎ $NAME: committed $n file(s) and pushed to GitHub\"}"
  else
    log "$NAME: commit ok, push FAILED"
    say "{\"systemMessage\":\"⚠︎ $NAME: changes committed locally but the push failed (GitHub may have newer commits). Run 'git pull --rebase && git push'.\"}"
  fi
  ;;
esac
exit 0
