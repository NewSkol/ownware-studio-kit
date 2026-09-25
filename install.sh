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

# 1. The rules file. Never overwrite a file the user has edited: keep theirs, put ours beside it.
mkdir -p "$HOME/.claude"
target="$HOME/.claude/CLAUDE.md"; stamp="$HOME/.claude/.kit-claude-md.sha256"
new_sum="$(sha256sum "$KIT_DIR/user/CLAUDE.md" | awk '{print $1}')"
if [ ! -f "$target" ]; then
  run cp "$KIT_DIR/user/CLAUDE.md" "$target" || fail "rules file"
elif [ -f "$stamp" ] && [ "$(sha256sum "$target" | awk '{print $1}')" = "$(cat "$stamp")" ]; then
  [ "$(cat "$stamp")" = "$new_sum" ] || run cp "$KIT_DIR/user/CLAUDE.md" "$target" || fail "rules file"
elif [ "$(sha256sum "$target" | awk '{print $1}')" != "$new_sum" ]; then
  log "your ~/.claude/CLAUDE.md has your own edits; the kit's version is saved as CLAUDE.md.kit-new"
  run cp "$KIT_DIR/user/CLAUDE.md" "$HOME/.claude/CLAUDE.md.kit-new" || fail "rules file copy"
  NOTE_RULES=1
fi
[ "$DRY_RUN" = 1 ] || { [ -f "$target" ] && [ "$(sha256sum "$target" | awk '{print $1}')" = "$new_sum" ] && echo "$new_sum" > "$stamp"; }

# 2. Our own plugin, from this folder.
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

# 3. Third-party plugins.
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

# 4. Proof.
if [ "$DRY_RUN" = 0 ]; then
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
  if [ "${NOTE_RULES:-0}" = 1 ] && ! grep -q "CLAUDE.md.kit-new ($KIT_VERSION)" "$CHANGES" 2>/dev/null; then
    echo "- $(date +%F): new rules in ~/.claude/CLAUDE.md.kit-new ($KIT_VERSION). Yours were kept because you edited them; ask Claude to merge the two." >> "$CHANGES"
  fi
fi
log "done. Kit $KIT_VERSION installed."
