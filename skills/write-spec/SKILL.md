---
name: write-spec
description: Turn an idea into SPEC.md and a queue of numbered build plans, by interviewing the user. Use before building anything with more than one screen or moving part, or when the user says "spec it", "new feature", "I have an idea" or "plan this project". Writes no application code.
---

# Write a spec

The user is not a programmer. Your job here is to find out what they want, write it down in
their words, and cut the work into sessions that each end with proof. No code, no stack choice.

## 1. Read first

`AGENTS.md` / `CLAUDE.md`, `STATE.md`, `SESSIONS.md`, any existing `SPEC.md` and `docs/`.
Do not ask what these already answer.

## 2. Interview

A few questions at a time (use the question tool if the tool has one), in plain words, with
2-4 concrete options each and your recommendation first. Cover:

- Who uses it, and what they do in the first minute.
- The one thing it must do on day one. What is explicitly **not** in the first version.
- What data it keeps, whose it is, and who may see it.
- Money, emails or messages to other people, sign-in: yes or no, and with what service.
- How we will know it works: what the user will click or see.
- What must never happen (lose data, charge twice, show one person's data to another).

Stop when the answers would not change the plan. Questions the user wants to leave open are
fine: list them.

## 3. Write SPEC.md

```markdown
# <Project> — spec
Interview held YYYY-MM-DD. The user's answers, tidied, not reinterpreted.

## In one line
## Who it is for
## What it does (first version)
## Not in the first version
## Data and who sees it
## Rules the user set
## How we know it works
## Still open (answer in the phase that needs it)
```

Later changes go in a dated `## Amendment YYYY-MM-DD` section at the end; never silently
rewrite what the user said.

## 4. Cut it into plans

One file per session in `docs/prompts/`, numbered `02-`, `03-` ... (this interview is `01-`).
Each small enough for one session, each ending with a check that proves it works. Use
`prompt-template.md` in this skill's folder. The first build plan chooses the stack, with a
one-line reason, and asks the user before anything that costs money.

## 5. Finish

Run the `handoff` skill: STATE.md "Next" points at `02-`. Tell the user in three lines what
the first version will do, how many sessions it should take, and which questions are open.
