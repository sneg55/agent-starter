---
name: new-project
description: Full project bootstrap — interviews the developer (name, description, stack, components), then scaffolds directory structure, CLAUDE.md, config files, hooks, skills, and first commit.
user_invocable: true
allowed-tools:
- Read
- Write
- Edit
- Bash
- Glob
---

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
**How to use:** Tailor your behavior to the user's profile. Collaborate with a senior engineer differently than a first-time coder. Frame explanations relative to their domain knowledge.

Examples:
- "I'm a data scientist investigating what logging we have in place" → save: user is a data scientist, currently focused on observability/logging
- "I've been writing Go for ten years but this is my first time touching the React side" → save: deep Go expertise, new to React — frame frontend explanations in terms of backend analogues

### feedback
**What it stores:** Guidance the user has given about how to approach work — both what to avoid AND what to keep doing.
**When to save:** Any time the user corrects your approach ("no not that", "don't", "stop doing X") OR confirms a non-obvious approach worked ("yes exactly", "perfect, keep doing that"). Corrections are easy to notice; confirmations are quieter — watch for them.
**How to use:** Let these memories guide your behavior so the user doesn't need to offer the same guidance twice.
**Structure:** Lead with the rule, then a **Why:** line and a **How to apply:** line. Knowing why lets you judge edge cases.

Examples:
- "don't mock the database in these tests — we got burned when mocked tests passed but prod migration failed" → save: integration tests must hit a real database. Why: mock/prod divergence masked a broken migration. How to apply: all test files in this repo use real DB connections.
- "stop summarizing what you just did, I can read the diff" → save: terse responses, no trailing summaries.
- "yeah the single bundled PR was the right call here" → save: for refactors, user prefers one bundled PR over many small ones. Confirmed approach — not a correction.

### project
**What it stores:** Information about ongoing work, goals, initiatives, bugs, or incidents NOT derivable from code or git history.
**When to save:** When you learn who is doing what, why, or by when. Always convert relative dates to absolute (e.g., "Thursday" → "2026-03-05").
**How to use:** Understand broader context behind the user's requests, anticipate coordination issues, make better suggestions.
**Structure:** Lead with the fact/decision, then **Why:** and **How to apply:** lines. Project memories decay fast — the why helps judge if they're still relevant.

Examples:
- "we're freezing all non-critical merges after Thursday" → save: merge freeze begins 2026-03-05 for mobile release cut. Flag non-critical PRs after that date.
- "ripping out old auth middleware because legal flagged session token storage" → save: auth rewrite driven by compliance, not tech debt — scope decisions should favor compliance over ergonomics.

### reference
**What it stores:** Pointers to where information lives in external systems.
**When to save:** When you learn about resources in external systems and their purpose.
**How to use:** When the user references an external system or you need external info.

Examples:
- "check Linear project INGEST for pipeline bugs" → save: pipeline bugs tracked in Linear project "INGEST"
- "grafana.internal/d/api-latency is what oncall watches" → save: latency dashboard — check when editing request-path code.

## What NOT to Save

- Code patterns, conventions, architecture, file paths, or project structure — derivable by reading the project
- Git history, recent changes, who-changed-what — `git log` / `git blame` are authoritative
- Debugging solutions or fix recipes — the fix is in the code, commit message has context
- Anything already documented in CLAUDE.md files
- Ephemeral task details: in-progress work, temporary state, current conversation context

These exclusions apply even when the user explicitly asks. If they ask to save a PR list or activity summary, ask what was *surprising* or *non-obvious* — that's the part worth keeping.

## Memory File Format

Each memory is its own `.md` file with YAML frontmatter:

```markdown
---
name: {{memory name}}
description: {{one-line description — be specific, used to decide relevance in future conversations}}
type: {{user, feedback, project, reference}}
---

{{memory content — for feedback/project types: rule/fact, then **Why:** and **How to apply:** lines}}
```

### Saving Process
1. Write the memory to its own file (e.g., `user_role.md`, `feedback_testing.md`)
2. Add a one-line pointer in `MEMORY.md`: `- [Title](file.md) — one-line hook`
3. Keep `MEMORY.md` under 200 lines — it's an index, not a dump

### Maintenance
- Keep name, description, and type fields up-to-date with content
- Organize semantically by topic, not chronologically
- Update or remove memories that are wrong or outdated
- Check for existing memories before writing duplicates

## When to Access Memories

- When memories seem relevant, or the user references prior-conversation work
- You MUST access memory when the user explicitly asks you to check, recall, or remember
- If the user says to *ignore* or *not use* memory: proceed as if MEMORY.md were empty

## Before Recommending from Memory

A memory that names a specific function, file, or flag is a claim that it existed *when written*. It may have been renamed, removed, or never merged. Before recommending:

- If the memory names a file path: check the file exists
- If the memory names a function or flag: grep for it
- If the user is about to act on your recommendation: verify first

"The memory says X exists" is not the same as "X exists now."

A memory that summarizes repo state is frozen in time. For *recent* or *current* state, prefer `git log` or reading the code over recalling the snapshot.

## Memory Consolidation (Dream)

Periodically review and consolidate memories:

### Phase 1 — Orient
- List the memory directory to see what exists
- Read MEMORY.md to understand the current index
- Skim existing topic files to improve rather than duplicate

### Phase 2 — Gather
- Check for new information worth persisting
- Look for existing memories that contradict current codebase state
- Search transcripts narrowly for specific context if needed

### Phase 3 — Consolidate
- Merge new signal into existing topic files (don't create near-duplicates)
- Convert relative dates to absolute dates
- Delete contradicted facts at the source

### Phase 4 — Prune
- Keep MEMORY.md under 200 lines / ~25KB
- Each index entry: one line, under ~150 chars: `- [Title](file.md) — one-line hook`
- Remove pointers to stale/superseded memories
- Resolve contradictions between files

---

## Git Safety

- Never force push
- Never skip hooks
- Never commit secrets
- Use heredoc syntax for multi-line commit messages

## Project-Specific Instructions

**Project:** <project-name>
**Description:** <project-description>

<!-- Add your project-specific instructions below -->
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
