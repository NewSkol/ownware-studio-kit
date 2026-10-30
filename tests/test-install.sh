#!/usr/bin/env bash
# Proves install.sh's file handling (rules, skills, keep-your-edits) in throwaway home folders with
# a stand-in `claude`, so it runs anywhere and touches no real settings. check-kit.sh calls it.
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0
ok()   { echo "  ok   $*"; PASS=$((PASS+1)); }
fail() { echo "  FAIL $*" >&2; exit 1; }
VERSION="$(python3 -c "import json;print(json.load(open('$KIT/plugins/studio-kit/.claude-plugin/plugin.json'))['version'])")"
SKILLS="handoff new-app security-check verify-against-code write-spec"

new_home() {
  local h="$T/$1"
  mkdir -p "$h/.local/bin" "$h/.claude/plugins" || fail "make home $1"
  cat > "$h/.local/bin/claude" <<'STUB'
#!/bin/bash
case "$*" in
  "plugin marketplace list") echo "ownware-studio cc-safety-net-dev claude-plugins-official" ;;
  "plugin list") echo "studio-kit@ownware-studio cc-safety-net@cc-safety-net-dev hookify@claude-plugins-official" ;;
esac
exit 0
STUB
  chmod +x "$h/.local/bin/claude"
  printf '{"plugins":{"studio-kit@ownware-studio":[{"version":"%s"}]}}' "$VERSION" > "$h/.claude/plugins/installed_plugins.json"
  echo "$h"
}
install_as() { HOME="$1" bash "$2/install.sh" >/dev/null 2>"$T/err" || fail "install.sh failed: $(cat "$T/err")"; }
newer_kit() {   # a copy of the kit whose rules and handoff skill have changed
  rm -rf "$T/newer"; mkdir "$T/newer" || fail "newer kit"
  (cd "$KIT" && tar --exclude=.git -cf - .) | tar -xf - -C "$T/newer" || fail "copy kit"
  echo "new rule" >> "$T/newer/user/CLAUDE.md"; echo "new rule" >> "$T/newer/user/AGENTS.md"
  echo "new step" >> "$T/newer/skills/handoff/SKILL.md"
  echo "$T/newer"
}

echo "== dry run"
H="$(new_home dry)"
HOME="$H" bash "$KIT/install.sh" --dry-run >/dev/null || fail "dry run failed"
[ ! -e "$H/.claude/CLAUDE.md" ] && [ ! -e "$H/.codex" ] && [ ! -e "$H/.agents" ] && [ ! -e "$H/.claude/skills" ] && [ ! -e "$H/WHAT-CHANGED.md" ] || fail "dry run changed something"
ok "changes nothing"

echo "== fresh install"
H="$(new_home fresh)"
install_as "$H" "$KIT"
cmp -s "$H/.claude/CLAUDE.md" "$KIT/user/CLAUDE.md" || fail "CLAUDE.md"
cmp -s "$H/.codex/AGENTS.md" "$KIT/user/AGENTS.md" || fail "AGENTS.md"
ok "both rules files in place"
for s in $SKILLS; do
  diff -r "$KIT/skills/$s" "$H/.agents/skills/$s" >/dev/null || fail "skill $s not copied"
  [ "$(readlink "$H/.claude/skills/$s")" = "$H/.agents/skills/$s" ] || fail "skill $s not linked for Claude"
  [ -f "$H/.claude/skills/$s/SKILL.md" ] || fail "link for $s does not reach SKILL.md"
done
ok "five skills in ~/.agents/skills, linked into ~/.claude/skills"
[ -z "$(find "$H" -name '*.kit-new' -o -name 'skills.kit-new')" ] || fail "new install left a .kit-new"
ok "no .kit-new on a clean install"

echo "== running it again"
before="$(wc -l < "$H/WHAT-CHANGED.md")"
install_as "$H" "$KIT"
[ "$(wc -l < "$H/WHAT-CHANGED.md")" = "$before" ] || fail "second run wrote to WHAT-CHANGED.md"
[ -z "$(find "$H" -name '*.kit-new' -o -name 'skills.kit-new')" ] || fail "second run left a .kit-new"
ok "second run changes nothing"

echo "== update over files nobody edited"
N="$(newer_kit)"
install_as "$H" "$N"
cmp -s "$H/.claude/CLAUDE.md" "$N/user/CLAUDE.md" && cmp -s "$H/.codex/AGENTS.md" "$N/user/AGENTS.md" || fail "rules not updated"
diff -r "$N/skills/handoff" "$H/.agents/skills/handoff" >/dev/null || fail "skill not updated"
[ -z "$(find "$H" -name '*.kit-new' -o -name 'skills.kit-new')" ] || fail "unedited files got a .kit-new"
ok "rules and skills updated in place"

echo "== update over files the user edited"
H="$(new_home edited)"
install_as "$H" "$KIT"
echo "my own rule" >> "$H/.claude/CLAUDE.md"
echo "my own rule" >> "$H/.codex/AGENTS.md"
echo "my own step" >> "$H/.agents/skills/handoff/SKILL.md"
N="$(newer_kit)"
install_as "$H" "$N"
grep -q "my own rule" "$H/.claude/CLAUDE.md" && grep -q "my own rule" "$H/.codex/AGENTS.md" || fail "edited rules overwritten"
cmp -s "$H/.claude/CLAUDE.md.kit-new" "$N/user/CLAUDE.md" && cmp -s "$H/.codex/AGENTS.md.kit-new" "$N/user/AGENTS.md" || fail "new rules not beside the edited ones"
ok "edited rules kept, new ones saved as .kit-new"
grep -q "my own step" "$H/.agents/skills/handoff/SKILL.md" || fail "edited skill overwritten"
diff -r "$N/skills/handoff" "$H/.agents/skills.kit-new/handoff" >/dev/null || fail "new skill not saved beside the edited one"
[ -z "$(find "$H/.agents/skills" -name '*.kit-new')" ] || fail "a .kit-new landed where the tools load skills"
ok "edited skill kept, new one saved outside the folder the tools load"
for f in "~/.claude/CLAUDE.md.kit-new" "~/.codex/AGENTS.md.kit-new" "~/.agents/skills.kit-new/handoff"; do
  [ "$(grep -cF "$f ($VERSION)" "$H/WHAT-CHANGED.md")" = 1 ] || fail "WHAT-CHANGED.md has no line for $f"
done
install_as "$H" "$N"
for f in "~/.claude/CLAUDE.md.kit-new" "~/.codex/AGENTS.md.kit-new" "~/.agents/skills.kit-new/handoff"; do
  [ "$(grep -cF "$f ($VERSION)" "$H/WHAT-CHANGED.md")" = 1 ] || fail "second run repeated the line for $f"
done
ok "one line each in WHAT-CHANGED.md, not repeated"

echo "== things that were there before the kit"
H="$(new_home mine)"
mkdir -p "$H/.codex" "$H/.claude/skills/write-spec" "$H/.agents/skills/security-check" "$H/elsewhere" || fail "set up"
echo "mine" > "$H/.codex/AGENTS.md"
echo "mine" > "$H/.claude/skills/write-spec/SKILL.md"
echo "mine" > "$H/.agents/skills/security-check/SKILL.md"
ln -s "$H/elsewhere" "$H/.claude/skills/new-app" || fail "set up link"
install_as "$H" "$KIT"
[ "$(cat "$H/.codex/AGENTS.md")" = mine ] && cmp -s "$H/.codex/AGENTS.md.kit-new" "$KIT/user/AGENTS.md" || fail "own AGENTS.md not kept"
[ "$(cat "$H/.claude/skills/write-spec/SKILL.md")" = mine ] || fail "own Claude skill folder replaced"
[ "$(readlink "$H/.claude/skills/new-app")" = "$H/elsewhere" ] || fail "someone else's link replaced"
[ "$(cat "$H/.agents/skills/security-check/SKILL.md")" = mine ] || fail "own skill replaced"
ok "own rules, skills and links left alone"

echo "INSTALL CHECKS PASSED ($PASS)"
