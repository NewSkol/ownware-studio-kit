# Ownware Studio kit

The way of working that comes pre-installed on every [Ownware Studio](https://dmitrisdoor.com/studio)
server. It is a Claude Code plugin marketplace: everything here is plain text you can read.

## What it does

| Piece | What it does for you |
|---|---|
| Rules file (`user/CLAUDE.md`) | How Claude works with you: a plan first, proof that things run, plain-English answers, asking before anything that cannot be undone. Installed as `~/.claude/CLAUDE.md`. If you edit yours, updates never overwrite it. |
| Project notes | Every project keeps `STATE.md` (where it stands) and `SESSIONS.md` (what happened). Claude reads them at the start and must update them before it stops. |
| Auto-save | Your work is committed and pushed to your GitHub at the end of each turn. New secret files (like `.env`) are refused. |
| Secret scanner | Refuses a commit that contains a password or API key. |
| Teach-me mode | On by default: each answer ends with one short lesson. Say `/teach-me off` to stop it. |
| Skills | `/handoff` (update the notes), `/verify-against-code` (check a claim by running it), `/teach-me`. |
| From other authors | [cc-safety-net](https://github.com/kenryu42/cc-safety-net) blocks destructive commands; [hookify](https://github.com/anthropics/claude-plugins-official) lets you write your own guardrails in plain English. Installed from their own sources. |

## Install or update

On a Studio server this happens automatically, weekly, from **signed releases only**: the
server checks that a release tag (`vX.Y.Z`) carries the Ownware Studio signature before using
it. The checking code and the trusted signature list live on the server, not in this repo, so
changing this repo cannot change what servers trust. Every update, refusal or failure adds a line
to `~/WHAT-CHANGED.md`.

```sh
bash install.sh            # install the checked-out kit (what the updater runs)
bash install.sh --dry-run  # show what would change
bash tests/check-kit.sh    # prove it works
bash release.sh            # (maintainer) sign and publish the version in plugin.json
```

## Licence

MIT, see LICENSE. Third-party parts: see THIRD-PARTY.md.
