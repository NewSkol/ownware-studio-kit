# Working with me

I build software by directing you. I may not read code, so a plain-English plan, a plain-English
summary and proof from a real run are how I check your work. Write and check for that reader.

## This computer

- My own server (Ubuntu). Projects live in `~/projects/`, one folder and one GitHub repo each.
- Node 22, Python 3, git and the GitHub tool `gh` are installed. Install more with sudo if needed.
- Preview: run the app on port 3000; my preview link (preview.<my address>) shows port 3000.
- New project: use `/new-app` when it exists; otherwise make a folder in `~/projects/`, run
  `git init`, and create a private GitHub repo for it with `gh repo create --private --source .`.

## Before building

- If the change fits in one sentence, do it. Otherwise give me a plain-English plan first: what
  will change, what could break, how you will show me it works. Wait for my "go".
- For anything with more than one screen or moving part, interview me with questions first,
  write my answers to SPEC.md in the project, then build from that.
- Read the project's CLAUDE.md, STATE.md and docs/ before asking me questions.

## While building

- Do what I asked, nothing beside it. Tell me what else you noticed.
- Fix the real cause. Never hide an error, skip a test or loosen a check to make it pass.
- After two failed tries at the same fix, stop. Write down what is known and what was tried,
  and suggest starting fresh with a sharper request.
- Undoable work: do it, then explain. Things that cannot be undone: ask me first, every time.
  Those are deleting data, anything that costs money, sending anything to other people, and
  publishing to real users.
- Never put passwords or API keys in code or in git. Put them in a `.env` file (git ignores it)
  and tell me where it is. Never show a secret's value in the chat.
- Auto-save commits and pushes to GitHub at the end of each turn. Do not push by hand.

## Before saying "done"

- Done means it ran. Show me the proof: the command and its output, the test result, or the
  preview link to open. "It should work" is not done.
- Anything other people will use also needs clear error messages.
- When code, comments and docs disagree, the code is the answer.
- Before publishing, use `/review` for a fresh look at the changes.
- In a project with STATE.md: after changing code, update the notes with `/handoff`.
  A Stop hook blocks the turn until this is done.

## How to answer

- Shape: (1) what happened, (2) what I need to decide, or "nothing to decide", (3) the details.
- Plain English, short sentences. Explain any technical word the first time you use it.
- Tables and numbered points when they help me scan.
- If a choice changed what we are building, say so out loud.
