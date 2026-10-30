# Plan NN: <short title> (written YYYY-MM-DD)

Paste into a fresh session in this project, or say "do the next plan".

## Goal
One or two sentences: what the user will be able to do after this session.

## Do
1. Concrete step, naming files or screens.
2. ...
3. Tests: name each one by the behaviour it checks ("a second person cannot see my notes").

## Do not
- What is out of scope for this session.
- Anything from the user's "must never happen" list that this step touches.

## Ask the user
- Decisions this session needs (with your recommendation), or "none".

## Prove it
The real run that shows it works: the command and its expected output, the page to open and
what it should show, or the test result. Paste it in the reply.

## Always
- Read first: `AGENTS.md` / `CLAUDE.md`, `STATE.md`, `SPEC.md`. One session.
- Done means a real run, pasted. Never edit a test to make it pass.
- Deleting data, spending money, sending to other people or publishing needs the user's yes.
- Finish with the `handoff` skill: STATE.md "Next" points at the next plan; move this file
  to `docs/prompts/done/`.
