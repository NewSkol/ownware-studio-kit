#!/usr/bin/env bash
# Ownware Studio kit installer. Run as the studio user (not root). Safe to re-run: it is also
# how updates are applied. Every step checks its own result.
#
#   bash install.sh             install or update
#   bash install.sh --dry-run   show what would change

set -uo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_VERSION="$(python3 -c "import json;print(json.load(open('$KIT_DIR/plugins/studio-kit/.claude-plugin/plugin.json'))['version'])")"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
CHANGES="$HOME/WHAT-CHANGED.md"
export PATH="$HOME/.local/bin:$PATH"

log()  { echo "[kit] $*"; }
fail() { echo "[kit] FAILED: $*" >&2; exit 1; }
run()  { if [ "$DRY_RUN" = 1 ]; then echo "    would run: $*"; return 0; fi; "$@"; }

[ "$(id -u)" != 0 ] || fail "run as the studio user, not root"
command -v claude >/dev/null || fail "Claude Code is not installed"

# Third-party plugins, installed from their authors' own marketplaces (not copied).
# Format: marketplace-source|plugin@marketplace-name
# Full HTTPS addresses on purpose: with "owner/repo" Claude Code may clone over SSH, which fails
# on a new server that has no GitHub SSH key.
THIRD_PARTY="
https://github.com/kenryu42/cc-safety-net.git|cc-safety-net@cc-safety-net-dev
https://github.com/anthropics/claude-plugins-official.git|hookify@claude-plugins-official
"

log "Ownware Studio kit $KIT_VERSION$( [ "$DRY_RUN" = 1 ] && echo ' (dry run)')"

KEPT=()   # new copies saved beside something the user edited; each gets a line in WHAT-CHANGED.md

# 1. The rules files. Never overwrite a file the user has edited: keep theirs, put ours beside it.
# install_rules <file in user/> <target> <stamp holding the sha256 of what we last installed>
install_rules() {
  local src="$KIT_DIR/user/$1" target="$2" stamp="$3" new_sum
  new_sum="$(sha256sum "$src" | awk '{print $1}')"
  run mkdir -p "$(dirname "$target")" || fail "rules folder for $target"
  if [ ! -f "$target" ]; then
    run cp "$src" "$target" || fail "rules file $target"
  elif [ -f "$stamp" ] && [ "$(sha256sum "$target" | awk '{print $1}')" = "$(cat "$stamp")" ]; then
    [ "$(cat "$stamp")" = "$new_sum" ] || run cp "$src" "$target" || fail "rules file $target"
  elif [ "$(sha256sum "$target" | awk '{print $1}')" != "$new_sum" ]; then
    log "your $target has your own edits; the kit's version is saved as $target.kit-new"
    run cp "$src" "$target.kit-new" || fail "rules file copy $target.kit-new"
    KEPT+=("$target.kit-new")
  fi
  [ "$DRY_RUN" = 1 ] || { [ -f "$target" ] && [ "$(sha256sum "$target" | awk '{print $1}')" = "$new_sum" ] && echo "$new_sum" > "$stamp"; }
}
install_rules CLAUDE.md "$HOME/.claude/CLAUDE.md" "$HOME/.claude/.kit-claude-md.sha256"
install_rules AGENTS.md "$HOME/.codex/AGENTS.md" "$HOME/.codex/.kit-agents-md.sha256"

# 2. Skills: one copy in ~/.agents/skills (Codex reads it), linked into ~/.claude/skills (Claude
# reads it). Same keep-your-edits rule as the rules files, one stamp per skill folder. The new copy
# of an edited skill goes in ~/.agents/skills.kit-new: inside skills/ both tools would load it twice.
tree_sum() { (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}'); }
run mkdir -p "$HOME/.agents/skills" "$HOME/.agents/.kit-skills" "$HOME/.claude/skills" || fail "skills folders"
for src in "$KIT_DIR"/skills/*/; do
  name="$(basename "$src")"; dst="$HOME/.agents/skills/$name"; stamp="$HOME/.agents/.kit-skills/$name.sha256"; link="$HOME/.claude/skills/$name"
  new_sum="$(tree_sum "$src")"
  cur_sum=""; [ -e "$dst" ] && cur_sum="$(tree_sum "$dst")"
  if [ -n "$cur_sum" ] && [ "$cur_sum" != "$new_sum" ] && [ "$cur_sum" != "$(cat "$stamp" 2>/dev/null)" ]; then
    copy="$HOME/.agents/skills.kit-new/$name"
    log "your $name skill has your own edits; the kit's version is saved as $copy"
    run mkdir -p "$HOME/.agents/skills.kit-new" || fail "skills.kit-new"
    run rm -rf "$copy" || fail "old $copy"
    run cp -R "$src" "$copy" || fail "skill copy $copy"
    KEPT+=("$copy")
  elif [ "$cur_sum" != "$new_sum" ]; then
    run rm -rf "$dst" || fail "old skill $name"
    run cp -R "$src" "$dst" || fail "skill $name"
  fi
  [ "$DRY_RUN" = 1 ] || { [ "$(tree_sum "$dst")" = "$new_sum" ] && echo "$new_sum" > "$stamp"; }
  # Anything already at the Claude link's address that is not our link belongs to someone else.
  if [ ! -e "$link" ] && [ ! -L "$link" ]; then
    run ln -s "$dst" "$link" || fail "link for skill $name"
  elif [ "$(readlink "$link")" != "$dst" ]; then
    log "kept your own $link; Claude uses it instead of the kit's $name skill"
  fi
done

# 3. Our own plugin, from this folder.
if claude plugin marketplace list 2>/dev/null | grep -q "ownware-studio"; then
  run claude plugin marketplace update ownware-studio >/dev/null || fail "update kit marketplace"
else
  run claude plugin marketplace add "$KIT_DIR" >/dev/null || fail "add kit marketplace"
fi
if claude plugin list 2>/dev/null | grep -q "studio-kit@ownware-studio"; then
  run claude plugin update studio-kit@ownware-studio >/dev/null 2>&1 || log "plugin update reported a problem; checking the installed version next"
else
  run claude plugin install -y studio-kit@ownware-studio >/dev/null || fail "install studio-kit"
fi

# 4. Third-party plugins.
echo "$THIRD_PARTY" | while IFS='|' read -r source plugin; do
  [ -n "$source" ] || continue
  mk="${plugin#*@}"
  if ! claude plugin marketplace list 2>/dev/null | grep -q "$mk"; then
    run claude plugin marketplace add "$source" >/dev/null || fail "add marketplace $source"
  fi
  if ! claude plugin list 2>/dev/null | grep -q "$plugin"; then
    run claude plugin install -y "$plugin" >/dev/null || fail "install $plugin"
  fi
done || exit 1

# 5. Proof.
if [ "$DRY_RUN" = 0 ]; then
  for src in "$KIT_DIR"/skills/*/; do
    [ -f "$HOME/.agents/skills/$(basename "$src")/SKILL.md" ] || fail "skill $(basename "$src") is not in ~/.agents/skills after install"
  done
  installed="$(claude plugin list 2>/dev/null)"
  for p in studio-kit@ownware-studio cc-safety-net@cc-safety-net-dev hookify@claude-plugins-official; do
    echo "$installed" | grep -q "$p" || fail "$p is not installed after install"
  done
  got="$(python3 -c "import json,os
d=json.load(open(os.path.expanduser('~/.claude/plugins/installed_plugins.json')))
print(d.get('plugins',d)['studio-kit@ownware-studio'][0].get('version',''))" 2>/dev/null)"
  if [ "$got" != "$KIT_VERSION" ]; then
    [ -f "$CHANGES" ] || printf '# What changed on my server\n\nNewest at the bottom.\n\n' > "$CHANGES"
    echo "- $(date +%F): kit update FAILED: installed $got, expected $KIT_VERSION." >> "$CHANGES"
    fail "studio-kit is $got after install, expected $KIT_VERSION"
  fi
  prev="$(cat "$HOME/.claude/.kit-version" 2>/dev/null || echo none)"
  if [ "$prev" != "$KIT_VERSION" ]; then
    [ -f "$CHANGES" ] || printf '# What changed on my server\n\nNewest at the bottom.\n\n' > "$CHANGES"
    echo "- $(date +%F): Studio kit $prev -> $KIT_VERSION." >> "$CHANGES"
    echo "$KIT_VERSION" > "$HOME/.claude/.kit-version"
  fi
  for copy in ${KEPT[@]+"${KEPT[@]}"}; do
    shown="~${copy#"$HOME"}"
    grep -qF "$shown ($KIT_VERSION)" "$CHANGES" 2>/dev/null && continue
    [ -f "$CHANGES" ] || printf '# What changed on my server\n\nNewest at the bottom.\n\n' > "$CHANGES"
    echo "- $(date +%F): new version in $shown ($KIT_VERSION). Yours was kept because you edited it; ask your AI to merge the two." >> "$CHANGES"
  done
fi
log "done. Kit $KIT_VERSION installed."
