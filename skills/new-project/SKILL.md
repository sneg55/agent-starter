---
name: new-project
description: Full project bootstrap - interviews the developer (name, description, stack, components), then scaffolds directory structure, CLAUDE.md, config files, hooks, skills, and first commit.
user_invocable: true
allowed-tools:
- Read
- Write
- Edit
- Bash
- Glob
---

# New Project Bootstrap

<!-- Mirrors AGENT.md in the agent-starter repo. If guides change, update this skill to match. -->

Use when starting a new project from scratch. Scaffolds a complete AI-friendly project following the agent-starter patterns: feature-based directory structure, CLAUDE.md with memory taxonomy, config files, optional hooks and skills, first commit.

For existing projects, use `/adopt-project` instead.

## Phase 1: Interview

Ask these questions **one at a time** before taking any action:

1. **Project name** - what is the name of the project?
2. **Description** - one sentence describing what it does.
3. **Tech stack** - language, framework, package manager (e.g. "TypeScript, Next.js, pnpm").
4. **Optional components** - which would you like installed?
   - Hooks (auto-enforce file size limits, lint-on-save, silent-error and dangerous-command blocking, codebase health checks at `~/.claude/hooks/`)
   - Skills (commit, commit-push-pr, simplify, remember, dream, new-project, adopt-project, reflect at `~/.claude/skills/`)
   - Both
   - Neither
5. **Repo path** - what is the local path to the agent-starter repo? (e.g. `~/code/agent-starter`). Always required: the CLAUDE.md template, foundation templates, and lint configs are all copied from the repo. (Hooks and skills also install from here when selected.)

Do not proceed past this step until you have all answers.

## Phase 2: Scaffold

Execute these steps in order.

### 1. Create directory structure

```bash
mkdir -p <project-name>/src/features
mkdir -p <project-name>/src/services
mkdir -p <project-name>/src/utils
mkdir -p <project-name>/src/types
mkdir -p <project-name>/src/constants
mkdir -p <project-name>/src/schemas
mkdir -p <project-name>/src/entrypoints
mkdir -p <project-name>/src/migrations
mkdir -p <project-name>/tests
mkdir -p <project-name>/docs
mkdir -p <project-name>/scripts
```

Design principle: organize by feature, not by technical layer. Each feature gets its own directory under `src/features/` with ALL related files (implementation, types, constants, validation, tests). Keep files under 200 lines each. Shared type definitions go in `src/types/` to break import cycles. Named constants go in `src/constants/` (no magic strings anywhere).

### 2. Generate CLAUDE.md

Copy the canonical template - do **not** inline or hand-write it, so it never
drifts from `templates/CLAUDE.md` (which carries the Memory System, Git Safety,
Implementation Notes, and Self-improvement loop sections):

```bash
cp <repo-path>/templates/CLAUDE.md <project-name>/CLAUDE.md
```

Then fill in the `## Project-Specific Instructions` section at the bottom:

```
**Project:** <project-name>
**Description:** <project-description>
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
CLAUDE.local.md
```

**`.env.example`** at `<project-name>/.env.example`:
```
# Required environment variables - copy to .env and fill in values
```

**`README.md`** at `<project-name>/README.md`:
```markdown
# <project-name>

<project-description>

## Getting Started

<!-- Add setup instructions here -->
```

**`CLAUDE.local.md`** at `<project-name>/CLAUDE.local.md` (gitignored above - personal, machine-local instructions that never get committed):
```markdown
# Personal Instructions (local only)

<!-- Your personal preferences for this project. Not committed. -->
```

**`.claude/rules/`** - modular instruction files the agent loads alongside CLAUDE.md. Create the directory and the apply-on-touch pattern index, which is the same file `/adopt-project` writes (Tier 4):

```bash
mkdir -p <project-name>/.claude/rules
```

Write `<project-name>/.claude/rules/starter-patterns.md`:

```markdown
# Starter patterns - apply on touch

Apply these when already editing the relevant code. Never as a bulk refactor.

- Editing a file over 300 lines -> split per the file-size hook's suggestions
  (types / constants / validation / utils).
- Touching a `throw` / `raise` site -> route it through the error registry
  (`guides/error-id-registry.md`).
- Changing a fallible function's signature -> consider returning a Result
  (`guides/discriminated-union-results.md`).
- Touching an env read -> move it behind the env boundary
  (`guides/zod-at-the-boundary.md`).
- Adding a long-running operation -> thread cancellation through it
  (`guides/abort-signal-threading.md`).
- Adding a new tool -> use the directory-per-tool layout
  (`guides/tool-authoring-pattern.md`).
```

Optionally also create topic stubs (`testing.md`, `git-workflow.md`, `code-style.md`, `security.md`) per `templates/NEW_PROJECT_PROMPT.md` - offer these but don't force them.

**Lint configs** - if the stack is TypeScript/JavaScript:

```bash
cp <repo-path>/templates/biome.json <project-name>/biome.json
cp <repo-path>/templates/eslint.config.mjs <project-name>/eslint.config.mjs
cd <project-name> && npm i -D @biomejs/biome eslint typescript-eslint eslint-plugin-import \
  eslint-plugin-sonarjs eslint-plugin-security eslint-plugin-eslint-comments
```

If the stack is Python:

```bash
cp <repo-path>/templates/ruff.toml <project-name>/ruff.toml
cp <repo-path>/templates/pyrightconfig.json <project-name>/pyrightconfig.json
cd <project-name> && uv add --dev ruff pyright   # or: python -m pip install ruff pyright
```

See `guides/lint-rules-for-ai.md` for what the rules catch. Skip for other stacks.

### 4. Copy foundation templates (TypeScript/JavaScript or Python)

Reference: `guides/error-id-registry.md`, `guides/zod-at-the-boundary.md`,
`guides/large-codebase-best-practices.md`

These are the "create from day one" foundation files (see
`templates/NEW_PROJECT_PROMPT.md` -> Foundation Files): a centralized env
boundary, a numbered error registry, and an output truncator. Copy them for the
matching stack and adapt import paths to the layout.

If the stack is TypeScript/JavaScript:

```bash
cp <repo-path>/templates/env.ts <project-name>/src/utils/env.ts
cp <repo-path>/templates/errorIds.ts <project-name>/src/constants/errorIds.ts
cp <repo-path>/templates/truncate-for-context.ts <project-name>/src/utils/truncate-for-context.ts
```

If the stack is Python:

```bash
cp <repo-path>/templates/env.py <project-name>/src/utils/env.py
cp <repo-path>/templates/error_ids.py <project-name>/src/constants/error_ids.py
cp <repo-path>/templates/truncate_for_context.py <project-name>/src/utils/truncate_for_context.py
```

Skip for other stacks (Rust, Go, etc.) - point the developer at the guides above
to build equivalents.

### 5. Install hooks (if selected)

Run the idempotent installer - it copies the hooks (and `lib/`) to
`~/.claude/hooks/`, stamps the installed version, and merges the hook wiring
into `~/.claude/settings.json` with jq. Existing entries are preserved and
re-running never duplicates anything - do not hand-edit the JSON:

```bash
bash <repo-path>/install.sh
```

Hook behavior (wired by default):
- `check-file-size.sh` - runs after every Write/Edit. Blocks (exit 2) files over 300 lines; warns over 200 lines. Skips `.md`, `.json`, `.yaml`.
- `lint-on-edit.sh` - Biome + ESLint on save for JS/TS; ruff check + format for Python.
- `check-silent-errors.sh` - blocks writes that introduce swallowed exceptions.
- `block-dangerous-commands.sh` - blocks force-push, `git reset --hard`, recursive rm on `/`/`~`, before they run.
- `check-codebase-health.sh` - runs at session start. Reports files over 500 lines that need splitting. Silent when healthy.
- `suggest-loop-improvements.sh` - when you run `/loop`, proposes 2-3 tighter drop-in rewrites (explicit success criteria, stop condition, scope, verification) and lets you pick one via an interactive menu. Advisory only for client-side commands like `/goal`.

Optional: `--with-read-guard` also wires `track-reads.sh` + `require-read-before-edit.sh`. Recent Claude Code versions enforce read-before-edit natively, so only add it for older versions.

### 6. Install skills (if selected)

```bash
mkdir -p ~/.claude/skills
cp -r <repo-path>/skills/commit ~/.claude/skills/
cp -r <repo-path>/skills/commit-push-pr ~/.claude/skills/
cp -r <repo-path>/skills/simplify ~/.claude/skills/
cp -r <repo-path>/skills/remember ~/.claude/skills/
cp -r <repo-path>/skills/dream ~/.claude/skills/
# new-project skill is included in this repo at skills/new-project/
cp -r <repo-path>/skills/new-project ~/.claude/skills/
cp -r <repo-path>/skills/adopt-project ~/.claude/skills/
cp -r <repo-path>/skills/reflect ~/.claude/skills/
```

Installed skills:
- `/commit` - single well-crafted git commit with "why not what" message
- `/commit-push-pr` - full workflow: branch, commit, push, create/update PR
- `/simplify` - 3 parallel agents review your diff for reuse, quality, efficiency
- `/remember` - review auto-memory and promote to CLAUDE.md or CLAUDE.local.md
- `/dream` - memory consolidation: merge, prune, re-index memory files
- `/new-project` - this skill (bootstrap a new project)
- `/adopt-project` - apply these patterns to an existing codebase
- `/reflect` - read ledger, cluster recurring mistakes, propose improvements

### 7. Initialize the self-improvement ledger

```bash
mkdir -p <project-name>/.harness/reflections
touch <project-name>/.harness/reflections/.gitkeep
echo '.harness/ledger.jsonl' >> <project-name>/.gitignore
```

The enforcement hooks use `hooks/lib/log-event.sh` to append structured events to
`.harness/ledger.jsonl` as the agent works. Run `/reflect` periodically: it reads
the ledger via `harness-ledger-stats.sh`, clusters recurring mistakes, and proposes
rule / threshold / ADR changes for your approval. See `templates/CLAUDE.md` →
"Self-improvement loop".

### 8. Initialize git and first commit

```bash
cd <project-name>
git init
git add .
git commit -m "$(cat <<'EOF'
Initial project scaffold

Bootstrapped using agent-starter patterns.
EOF
)"
```

## Phase 3: Verify

Confirm each item before reporting done:

- [ ] Project directory with feature-based structure (`src/features`, `src/services`, `src/utils`, `src/types`, `src/constants`, `src/schemas`, `src/entrypoints`, `src/migrations`, `tests/`, `docs/`, `scripts/`)
- [ ] `CLAUDE.md` copied from `templates/CLAUDE.md` (not inlined) with project name and description filled in
- [ ] `.gitignore`, `.env.example`, `README.md`, and `CLAUDE.local.md` present (`CLAUDE.local.md` gitignored)
- [ ] `.claude/rules/starter-patterns.md` written
- [ ] Lint configs copied + deps installed - `biome.json` + `eslint.config.mjs` (TS/JS) or `ruff.toml` + `pyrightconfig.json` (Python); skipped for other stacks
- [ ] Foundation templates copied - env boundary + error registry + truncator for the stack (TS or Python); skipped for other stacks
- [ ] Hooks installed to `~/.claude/hooks/` and configured in `settings.json` (if selected)
- [ ] Skills installed to `~/.claude/skills/` (if selected)
- [ ] `.harness/reflections/` created and `.harness/ledger.jsonl` added to `.gitignore`
- [ ] `reflect` skill installed to `~/.claude/skills/reflect`
- [ ] Initial git commit created

## Allowed Tools

Read, Write, Edit, Bash, Glob
