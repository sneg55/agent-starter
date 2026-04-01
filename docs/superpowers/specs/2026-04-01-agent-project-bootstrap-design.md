# Agent Project Bootstrap Design

**Date:** 2026-04-01  
**Status:** Approved

## Problem

A developer wants to say "read this repo and set up my project" — and have an AI agent produce a complete, opinionated project scaffold: directory structure, CLAUDE.md, config files, hooks installed, skills installed, first commit. Currently the repo's content is written for humans to read, not for agents to execute. There's no single entry point, no interview flow, no action sequence.

## Goal

Make this repo directly executable by an AI agent with no manual steps beyond pointing it at the repo.

## Approach: `AGENT.md` + `/new-project` skill (Option C)

Two artifacts, same mental model, different delivery:

- **`AGENT.md`** — repo entry point for agents reading the repo from a GitHub URL or local clone (scenario B)
- **`/new-project` skill** — installable skill for developers who use Claude Code regularly (scenario C)

Both share the same interview questions, execution sequence, and output checklist. The skill is self-contained; `AGENT.md` references other repo files.

## `AGENT.md` Design

Lives at the repo root. Written as imperative agent instructions.

### Structure

1. **Purpose** — one sentence orienting the agent
2. **Interview** — explicit ordered list of questions to ask the developer before taking any action:
   - Project name
   - Short description
   - Tech stack (language, framework, package manager)
   - Which optional components to install: hooks, skills, both, or neither
3. **Execution sequence** — numbered steps, each referencing the relevant repo file:
   1. Create directory structure per `guides/large-codebase-best-practices.md`
   2. Generate `CLAUDE.md` from `templates/CLAUDE.md`
   3. Set up config files (linter, tsconfig, .gitignore, .env.example)
   4. Install hooks: copy `hooks/*.sh` to `~/.claude/hooks/`, add config to `settings.json`
   5. Install skills: copy `skills/*` to `~/.claude/skills/`
   6. Create first commit
4. **Output checklist** — what "done" looks like so the agent can self-verify

## `/new-project` Skill Design

Lives at `skills/new-project/SKILL.md`. Installed via `cp -r skills/* ~/.claude/skills/`.

### Structure

Mirrors `AGENT.md` but fully self-contained — no internet or repo access required at runtime:

1. **Trigger** — when to use (starting a new project from scratch)
2. **Interview phase** — same questions as `AGENT.md`, asked one at a time before any action
3. **Execution phase** — same numbered steps, but instructions are inlined (not referenced)
4. **Allowed tools** — `Read`, `Write`, `Edit`, `Bash`, `Glob`
5. **Output checklist** — same as `AGENT.md`

## Relationship & Sync

| | `AGENT.md` | `/new-project` skill |
|---|---|---|
| **Access** | GitHub URL or local clone | Pre-installed in `~/.claude/skills/` |
| **Instructions** | References repo files | Self-contained, fully inlined |
| **Best for** | First-time users, one-off setup | Regular users, repeated use |
| **Maintenance** | Canonical source of truth | Must stay in sync with `AGENT.md` |

The skill header includes a sync note: "Mirrors `AGENT.md` — if guides change, update this skill to match."

## Output Checklist (what "done" looks like)

- [ ] Project directory created with feature-based structure
- [ ] `CLAUDE.md` generated and filled in
- [ ] Config files present (linter, tsconfig, .gitignore, .env.example)
- [ ] Hooks installed to `~/.claude/hooks/` and configured in `settings.json` (if selected)
- [ ] Skills installed to `~/.claude/skills/` (if selected)
- [ ] Initial git commit created
