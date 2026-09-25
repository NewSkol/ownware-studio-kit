#!/usr/bin/env bash
# Weekly kit update (run by the ownware-kit-update timer as the studio user).
# Downloads the newest kit, then re-runs install.sh. A failed download is written to
# ~/WHAT-CHANGED.md instead of being silently skipped.
set -u
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANGES="$HOME/WHAT-CHANGED.md"
note() { [ -f "$CHANGES" ] || printf '# What changed on my server\n\nNewest at the bottom.\n\n' > "$CHANGES"; echo "- $(date +%F): $*" >> "$CHANGES"; }
if ! out=$(git -C "$KIT_DIR" pull -q --ff-only 2>&1); then
  note "kit update could not download the new version ($(printf '%s' "$out" | head -1)). Still on the previous kit."
  exit 1
fi
bash "$KIT_DIR/install.sh" || { note "kit update downloaded but did not install. Still on the previous kit."; exit 1; }
