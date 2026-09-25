---
name: handoff
description: End-of-session notes for a project that has STATE.md. Rewrites STATE.md, adds today's entry to SESSIONS.md, moves finished plans to docs/prompts/done/. Use when work is done for now, when the Stop hook says the notes are stale, or when the user says "wrap up", "handoff", "we're done", "save where we are".
---

# Handoff

Leave the project so that the next session can understand it in one minute. Never change code here.

## 1. Rewrite STATE.md (never append)

Keep it under 60 lines. Only what is true now. Template:

```markdown
# <Project> — state
Rewritten YYYY-MM-DD.

## What it is
One or two lines. Who uses it, what it does.

## Live where
Web addresses, and how it gets published.

## Now
What is in progress, and what is proven working versus only written.

## Broken / watch
Known problems, and things to check before trusting a result.

## Next
The next one to three things, in order. Name the docs/prompts/ file if one exists.

## Ask before
Things in this project that cannot be undone (real customer data, payments, emails to people).
```

## 2. Add today's entry to SESSIONS.md

One entry per day. If today's entry exists, extend it. Format:

```markdown
## YYYY-MM-DD — short topic

- Done: specific bullets, with file or feature names
- Decided: what and why
- Verified: the command or check that proved it, or "not run"
- Open: questions or the next step
```

## 3. Planned work

Plans for future sessions live in `docs/prompts/<topic>.md`, one file each. When a plan is
finished, move it to `docs/prompts/done/`. Point "Next" in STATE.md at the plan that is up next.

## 4. Do not commit or push by hand

Auto-save commits and pushes to GitHub at the end of the turn. Finish with one line to the user:
what STATE.md now says under "Next".
