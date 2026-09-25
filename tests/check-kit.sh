#!/usr/bin/env bash
# Proves the installed kit works, not just that its files exist. Run as the studio user after
# install.sh. Uses throwaway projects under ~/projects/kit-test-* and a local fake "GitHub"
# (a bare git repo in /tmp); cleans up after itself.
set -u   # no pipefail: "grep -q" stops reading early, which pipefail would report as a failure
export PATH="$HOME/.local/bin:$PATH"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
ok()   { echo "  ok   $*"; PASS=$((PASS+1)); }
fail() { echo "  FAIL $*" >&2; cleanup; exit 1; }
cleanup() { rm -rf "$HOME/projects/kit-test-a" "$HOME/projects/kit-test-b" /tmp/kit-test-remote.git "$HOME/.claude/teach-me-off"; }
cleanup

echo "== plugin and marketplace are valid"
claude plugin validate "$KIT_DIR" >/dev/null 2>&1 || fail "marketplace does not validate: $(claude plugin validate "$KIT_DIR" 2>&1 | tail -3)"
claude plugin validate "$KIT_DIR/plugins/studio-kit" >/dev/null 2>&1 || fail "plugin does not validate"
ok "claude plugin validate"

echo "== installed"
list="$(claude plugin list 2>/dev/null)"
for p in studio-kit@ownware-studio cc-safety-net@cc-safety-net-dev hookify@claude-plugins-official; do
  echo "$list" | grep -q "$p" || fail "$p not installed"
  ok "$p installed"
done
cmp -s "$HOME/.claude/CLAUDE.md" "$KIT_DIR/user/CLAUDE.md" || fail "~/.claude/CLAUDE.md is not the kit's rules file"
ok "rules file in place"

# Run the scripts from the installed copy, the way Claude Code runs them.
ROOT_DIR="$(find "$HOME/.claude/plugins" -path '*studio-kit*' -name hooks.json -printf '%h\n' 2>/dev/null | grep -v "$KIT_DIR" | head -1)"
ROOT_DIR="${ROOT_DIR%/hooks}"
[ -n "$ROOT_DIR" ] && [ -f "$ROOT_DIR/scripts/project-orient.sh" ] || fail "cannot find the installed studio-kit"
S="$ROOT_DIR/scripts"
payload() { printf '{"cwd":"%s","session_id":"kit-test"}' "$1"; }

echo "== orientation"
A="$HOME/projects/kit-test-a"; mkdir -p "$A" && git -C "$A" init -q -b main
payload "$A" | bash "$S/project-orient.sh" | grep -q "has no notes yet" || fail "new project not told to set up notes"
ok "new project gets set-up instructions"
printf '# A — state\n## Next\n1. ship it\n' > "$A/STATE.md"; printf '# Sessions\n## 2026-01-01 — start\n' > "$A/SESSIONS.md"
payload "$A" | bash "$S/project-orient.sh" | grep -q "1. ship it" || fail "STATE.md not shown"
ok "project with notes gets its STATE.md"
payload "/tmp" | bash "$S/project-orient.sh" | grep -q . && fail "acted outside ~/projects"
ok "ignores folders outside ~/projects"

echo "== handoff gate"
git -C "$A" add -A && git -C "$A" commit -qm notes
echo "console.log(1)" > "$A/app.js"; git -C "$A" add app.js && git -C "$A" commit -qm code
payload "$A" | bash "$S/handoff-gate.sh" | grep -q '"decision": "block"' || fail "stale notes not blocked"
ok "blocks when code is newer than the notes"
echo "## 2026-01-02 — more" >> "$A/SESSIONS.md"; echo "x" >> "$A/STATE.md"; git -C "$A" commit -qam handoff
payload "$A" | bash "$S/handoff-gate.sh" | grep -q block && fail "blocked although notes are fresh"
ok "passes when notes are fresh"

echo "== auto-save to GitHub (a local stand-in)"
git init -q --bare -b main /tmp/kit-test-remote.git
git clone -q /tmp/kit-test-remote.git "$HOME/projects/kit-test-b" 2>/dev/null
B="$HOME/projects/kit-test-b"
echo hi > "$B/index.html"; git -C "$B" add -A; git -C "$B" commit -qm first; git -C "$B" push -q -u origin main 2>/dev/null
echo "hello" > "$B/about.html"
payload "$B" | bash "$S/git-autosync.sh" push >/dev/null
git -C /tmp/kit-test-remote.git log --oneline -1 | grep -q "Auto-sync" || fail "change was not committed and pushed"
ok "commits and pushes at the end of a turn"
echo "SECRET=1" > "$B/.env"
out="$(payload "$B" | bash "$S/git-autosync.sh" push)"
echo "$out" | grep -q "look like secrets" || fail "a new .env file was not refused"
git -C /tmp/kit-test-remote.git show --name-only --format= HEAD | grep -q '\.env' && fail ".env reached the remote"
ok "refuses to push a new .env file"

echo "== secret scanner"
rm -f "$B/.env"; printf 'key = "AKIA%s"\n' "ABCDEFGHIJKLMNOP" > "$B/config.js"; git -C "$B" add config.js
( cd "$B" && printf '{"tool_input":{"command":"git commit -m x"},"cwd":"%s"}' "$B" | python3 "$S/secret-scanner.py" >/dev/null 2>&1 ); rc=$?
[ "$rc" = 2 ] || fail "scanner did not refuse a fake AWS key (exit $rc)"
ok "refuses a commit containing a key"
git -C "$B" reset -q config.js; rm -f "$B/config.js"
( cd "$B" && printf '{"tool_input":{"command":"git commit -m y"},"cwd":"%s"}' "$B" | python3 "$S/secret-scanner.py" >/dev/null 2>&1 ) || fail "scanner refused a clean commit"
ok "lets a clean commit through"

echo "== teach-me mode"
bash "$S/teach-mode.sh" < /dev/null | grep -q "Teach-me mode is ON" || fail "teach mode not on by default"
[ -f "$HOME/.claude/LEARNING.md" ] || fail "learning log not created"
ok "on by default, learning log created"
touch "$HOME/.claude/teach-me-off"
bash "$S/teach-mode.sh" < /dev/null | grep -q . && fail "teach mode still talks when switched off"
ok "silent when switched off"

cleanup
echo "KIT CHECKS PASSED ($PASS)"
