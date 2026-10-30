---
name: new-app
description: Create a new project ready for its first session - folder, git, the notes files (AGENTS.md, CLAUDE.md, STATE.md, SESSIONS.md, docs/prompts), secret-safe .gitignore and a private GitHub repo. Use when the user says "new app", "start a project", "new repo" or names a project that does not exist yet.
---

# New app

Set up the project; do not build or invent the product here. That is the spec's job.

## 1. Settle the name

Ask only if the user did not give one. Lowercase, letters, digits and hyphens
("recipe-book"). Refuse a name that already exists in `~/projects/`.

## 2. Create it

Templates are in this skill's `templates/` folder. In `~/projects/<name>/`:

1. `git init -b main`.
2. Copy `AGENTS.md`, `CLAUDE.md`, `STATE.md`, `SESSIONS.md`; replace `<Project>` with the
   name and `YYYY-MM-DD` with today.
3. `docs/prompts/01-spec.md` from `01-spec.md` (date filled in); empty `docs/prompts/done/`
   with a `.gitkeep`.
4. `.gitignore` from `gitignore`, `.env.example` from `env.example`.
5. If the user described the idea, put it in one line under "What it is" in AGENTS.md, in
   their words.

## 3. Check before the first save

- `git status --short` lists only the files above.
- No file contains a key or password (run the secret scanner if one is installed, for
  example `gitleaks dir .`).

## 4. Connect GitHub (private)

If `gh auth status` succeeds: `gh repo create <name> --private --source . --push` after a
first commit "Project created". Never make it public without the user's yes. If GitHub is not
connected, say so plainly: auto-save to GitHub will not work until it is.

## 5. Finish

Tell the user in three lines: where the project is, that it is saved privately on GitHub
(or not, and why), and that the next step is the spec interview (say "spec it").
