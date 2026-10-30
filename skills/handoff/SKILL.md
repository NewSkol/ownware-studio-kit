---
name: handoff
description: End-of-session handoff for a project with STATE.md. Rewrites STATE.md, adds today's SESSIONS.md entry, moves finished plans to docs/prompts/done/. Use when work is done for now, when a hook says the handoff is stale, or when the user says "wrap up", "handoff" or "we're done".
---

# Handoff

Leave the project so that the next session, in any tool, can find its feet in one minute.
Do not change code here.

## 1. Rewrite STATE.md (never append)

Under 60 lines. Only what is true now: move history to SESSIONS.md, delete what is finished.

```markdown
# <Project> — state
Rewritten YYYY-MM-DD.

## What it is
One or two lines: who uses it, what it does.

## Live where
Addresses, servers, how a deploy happens. "Only on my preview address" is fine.

## Now
What is in progress, and what is verified working versus only written.

## Broken / watch
Known failures, flaky steps, things to check before trusting a result.

## Next
1. The next one to three things, in order. Name the docs/prompts/ file if there is one.
   Put a decision only the user can make first, as "0. You: decide ...".

## Ask before
This project's one-way doors (real data, paid services, messages to customers).
```

## 2. Add today's entry to SESSIONS.md

One entry per day; if today's exists, extend it. Never rewrite older entries.

```markdown
## YYYY-MM-DD — short topic

- Done: specific bullets, file or feature names
- Decided: what and why
- Verified: the command or check that proved it, with its result, or "not run"
- Open: questions or the next step
```

## 3. Plans queue

Planned work lives in `docs/prompts/NN-name.md`, one file per future session. Move a finished
plan to `docs/prompts/done/`. STATE.md "Next" points at the plan that is up next.

## 4. Save

- Claude Code: do not commit or push; the auto-save hook does it at the end of the turn.
- Codex or any tool without auto-save: commit with a plain-English message, then `git push`
  (never `--force`) if the project has a remote.

Finish with one line to the user: what STATE.md now says under "Next".
