# New Project Bootstrap

<!-- Mirrors AGENT.md in the claude-code-skills repo. If guides change, update this skill to match. -->

Use when starting a new project from scratch. Scaffolds a complete AI-friendly project following the claude-code-skills patterns: feature-based directory structure, CLAUDE.md with memory taxonomy, config files, optional hooks and skills, first commit.

## Phase 1: Interview

Ask these questions **one at a time** before taking any action:

1. **Project name** — what is the name of the project?
2. **Description** — one sentence describing what it does.
3. **Tech stack** — language, framework, package manager (e.g. "TypeScript, Next.js, pnpm").
4. **Optional components** — which would you like installed?
   - Hooks (auto-enforce file size limits and codebase health checks at `~/.claude/hooks/`)
   - Skills (commit, commit-push-pr, simplify, remember, dream, new-project at `~/.claude/skills/`)
   - Both
   - Neither
5. **Repo path** (only if hooks or skills selected) — what is the local path to the claude-code-skills repo? (e.g. `~/code/claude-code-skills`). If the answer to question 4 was "Neither", skip this question.

Do not proceed past this step until you have all answers.

## Phase 2: Scaffold

Execute these steps in order.

### 1. Create directory structure

```bash
mkdir -p <project-name>/src/commands
mkdir -p <project-name>/src/core
mkdir -p <project-name>/src/types
mkdir -p <project-name>/src/utils
mkdir -p <project-name>/src/constants
mkdir -p <project-name>/tests
mkdir -p <project-name>/docs
mkdir -p <project-name>/scripts
```

Design principle: organize by feature, not by technical layer. Keep files under 200 lines each — that's the target size for AI-readable code. Constants go in `src/constants/` (no magic strings anywhere). Shared TypeScript types go in `src/types/` to avoid import cycles.

### 2. Generate CLAUDE.md

Create `<project-name>/CLAUDE.md`:

```markdown
# Project Instructions

## Memory System

You have a persistent, file-based memory system. Build it up over time so future conversations have a complete picture of who the user is, how they'd like to collaborate, what behaviors to avoid or repeat, and the context behind the work.

If the user explicitly asks you to remember something, save it immediately as whichever type fits best. If they ask you to forget something, find and remove the relevant entry.

## Types of Memory

There are four discrete types. Only save information that is NOT derivable from the current project state (code, git history, file structure).

### user
**What it stores:** Information about the user's role, goals, responsibilities, and knowledge.
**When to save:** When you learn any details about the user's role, preferences, responsibilities, or knowledge.
**How to use:** Tailor your behavior to the user's profile. Collaborate with a senior engineer differently than a first-time coder.

### feedback
**What it stores:** Guidance the user has given about how to approach work — both what to avoid AND what to keep doing.
**When to save:** Any time the user corrects your approach OR confirms a non-obvious approach worked.
**Structure:** Lead with the rule, then a **Why:** line and a **How to apply:** line.

### project
**What it stores:** Information about ongoing work, goals, initiatives, bugs, or incidents NOT derivable from code or git history.
**When to save:** When you learn who is doing what, why, or by when. Always convert relative dates to absolute.
**Structure:** Lead with the fact/decision, then **Why:** and **How to apply:** lines.

### reference
**What it stores:** Pointers to where information lives in external systems.
**When to save:** When you learn about resources in external systems and their purpose.

## What NOT to Save

- Code patterns, conventions, architecture, file paths, or project structure
- Git history, recent changes — `git log` / `git blame` are authoritative
- Debugging solutions or fix recipes
- Anything already documented in CLAUDE.md files
- Ephemeral task details

## Memory File Format

Each memory is its own `.md` file with YAML frontmatter:

```markdown
---
name: {{memory name}}
description: {{one-line description}}
type: {{user, feedback, project, reference}}
---

{{memory content}}
```

Add a one-line pointer in `MEMORY.md`: `- [Title](file.md) — one-line hook`. Keep MEMORY.md under 200 lines.

## Git Safety

- Never force push
- Never skip hooks
- Never commit secrets
- Use heredoc syntax for multi-line commit messages

## Project-Specific Instructions

**Project:** <project-name>
**Description:** <project-description>

<!-- Add project-specific instructions below -->
```

### 3. Create config files

**`.gitignore`** at `<project-name>/.gitignore`:
```
node_modules/
dist/
.env
*.log
.DS_Store
.cache/
coverage/
```

**`.env.example`** at `<project-name>/.env.example`:
```
# Required environment variables — copy to .env and fill in values
```

**`README.md`** at `<project-name>/README.md`:
```markdown
# <project-name>

<project-description>

## Getting Started

<!-- Add setup instructions here -->
```

### 4. Install hooks (if selected)

```bash
mkdir -p ~/.claude/hooks
cp <repo-path>/hooks/check-file-size.sh ~/.claude/hooks/
cp <repo-path>/hooks/check-codebase-health.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/check-file-size.sh ~/.claude/hooks/check-codebase-health.sh
```

Merge into `~/.claude/settings.json`. Read the existing file first, then append to the `hooks.PostToolUse` and `hooks.SessionStart` arrays — do not replace existing entries. If the hook command already appears verbatim, skip it:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/check-file-size.sh",
            "timeout": 5,
            "statusMessage": "Checking file size..."
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/check-codebase-health.sh .",
            "timeout": 15,
            "statusMessage": "Checking codebase health..."
          }
        ]
      }
    ]
  }
}
```

Hook behavior:
- `check-file-size.sh` — runs after every Write. Blocks (exit 2) files over 300 lines; warns over 200 lines. Skips `.md`, `.json`, `.yaml`.
- `check-codebase-health.sh` — runs at session start. Reports files over 500 lines that need splitting. Silent when healthy.

### 5. Install skills (if selected)

```bash
mkdir -p ~/.claude/skills
cp -r <repo-path>/skills/commit ~/.claude/skills/
cp -r <repo-path>/skills/commit-push-pr ~/.claude/skills/
cp -r <repo-path>/skills/simplify ~/.claude/skills/
cp -r <repo-path>/skills/remember ~/.claude/skills/
cp -r <repo-path>/skills/dream ~/.claude/skills/
# new-project skill is included in this repo at skills/new-project/
cp -r <repo-path>/skills/new-project ~/.claude/skills/
```

Installed skills:
- `/commit` — single well-crafted git commit with "why not what" message
- `/commit-push-pr` — full workflow: branch, commit, push, create/update PR
- `/simplify` — 3 parallel agents review your diff for reuse, quality, efficiency
- `/remember` — review auto-memory and promote to CLAUDE.md or CLAUDE.local.md
- `/dream` — memory consolidation: merge, prune, re-index memory files
- `/new-project` — this skill (bootstrap a new project)

### 6. Initialize git and first commit

```bash
cd <project-name>
git init
git add .
git commit -m "$(cat <<'EOF'
Initial project scaffold

Bootstrapped using claude-code-skills patterns.
EOF
)"
```

## Phase 3: Verify

Confirm each item before reporting done:

- [ ] Project directory with feature-based structure (`src/commands`, `src/core`, `src/types`, `src/utils`, `src/constants`, `tests/`, `docs/`, `scripts/`)
- [ ] `CLAUDE.md` present with project name and description filled in
- [ ] `.gitignore`, `.env.example`, and `README.md` present
- [ ] Hooks installed to `~/.claude/hooks/` and configured in `settings.json` (if selected)
- [ ] Skills installed to `~/.claude/skills/` (if selected)
- [ ] Initial git commit created

## Allowed Tools

Read, Write, Edit, Bash, Glob
