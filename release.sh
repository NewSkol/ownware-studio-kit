#!/usr/bin/env bash
# Publish a kit release: a signed tag vX.Y.Z matching plugin.json's version.
# Studio servers install only tags signed with this key (their trusted list lives in the
# Ownware Studio recipe, not here). Run on the release machine:
#
#   bash release.sh            sign and publish the version in plugin.json
#   bash release.sh --dry-run  check everything, sign nothing
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
KEY="${KIT_SIGNING_KEY:-$HOME/.ssh/ownware_kit_release}"
fail() { echo "[release] FAILED: $*" >&2; exit 1; }

v=$(python3 -c "import json;print(json.load(open('plugins/studio-kit/.claude-plugin/plugin.json'))['version'])")
m=$(python3 -c "import json;print(json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['version'])")
[ "$v" = "$m" ] || fail "plugin.json says $v but marketplace.json says $m"
tag="v$v"
[ -f "$KEY" ] || fail "signing key not found at $KEY"
[ -z "$(git status --porcelain)" ] || fail "uncommitted changes; commit them first"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && fail "$tag already exists; bump the version first"
[ "$(git rev-parse HEAD)" = "$(git rev-parse '@{u}' 2>/dev/null)" ] || fail "main is not pushed to GitHub yet"

signers=$(mktemp); trap 'rm -f "$signers"' EXIT
printf 'release@ownware-studio namespaces="git" %s\n' "$(cut -d' ' -f1,2 "$KEY.pub")" > "$signers"

if [ "${1:-}" = "--dry-run" ]; then echo "[release] ready to sign and publish $tag"; exit 0; fi
git -c gpg.format=ssh -c user.signingkey="$KEY" tag -s "$tag" -m "Ownware Studio kit $tag" || fail "signing"
git -c gpg.format=ssh -c gpg.ssh.allowedSignersFile="$signers" verify-tag "$tag" 2>/dev/null || fail "the new tag does not verify"
git push -q origin "$tag" || fail "could not publish $tag"
echo "[release] published $tag (signed). Servers pick it up at their next weekly update."
