---
name: teach-me
description: Turn teach-me mode on or off, or show what has been learned so far. Teach-me mode ends every reply with one short lesson tied to the work. Use when the user says "/teach-me off", "/teach-me on", "stop teaching", "teach me again", or "what have I learned".
---

# Teach-me mode

Teach-me mode is on by default. It is controlled by one file:

- **Off:** create the empty file `~/.claude/teach-me-off`.
- **On:** delete `~/.claude/teach-me-off`.
- **What have I learned:** show `~/.claude/LEARNING.md` as a short list, newest first.

The change takes effect from the next session. For the rest of this session, follow the user's
choice straight away: stop (or start) adding the lesson paragraph now.

Confirm in one plain sentence what you did, for example: "Teach-me mode is off. Say /teach-me on
to bring it back."
