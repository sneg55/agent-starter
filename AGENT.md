# Agent Project Bootstrap

This repo contains patterns for bootstrapping AI-friendly projects. Follow these instructions to scaffold a complete new project for the developer.

> Scaffolding a **new** project. For applying these patterns to an **existing** codebase, see `ADOPT.md`.

## Step 0: Detect what's already installed

Hooks and skills install **system-wide** under `~/.claude/`, so they're shared
across every project. Detect them first and never ask about components that are
already present. Run:

```bash
# Hooks: install.sh stamps this file with the installed version
HOOKS_VER=$( [ -f ~/.claude/hooks/.agent-starter-version ] && cat ~/.claude/hooks/.agent-starter-version || echo "" )
HOOKS_N=$( ls ~/.claude/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ' )

# Skills: the starter skills this bootstrap installs
for s in commit commit-push-pr simplify remember dream new-project adopt-project reflect; do
  [ -d ~/.claude/skills/$s ] && echo "skill:$s present" || echo "skill:$s missing"
done
echo "hooks: version ${HOOKS_VER:-none}, $HOOKS_N scripts"
```

Hooks are installed if `.agent-starter-version` exists (record the version);
skills are installed per directory listed as `present`. Carry this into the
interview and scaffold: only ask about, and only install, what's **missing**. If
a stamped hooks version is present but older than the repo `VERSION`, note an
update is available and offer to re-run `install.sh` (idempotent) - don't force it.

## Step 1: Interview the Developer

Ask these questions **one at a time** before taking any action:

1. **Project name** - what is the name of the project?
2. **Description** - one sentence describing what it does.
3. **Tech stack** - language, framework, package manager (e.g. "TypeScript, Next.js, pnpm").
4. **Optional components** - ask **only about what Step 0 reported as missing**.
   If hooks and all skills are already installed, skip this question entirely -
   state what was detected and move on. Otherwise offer the missing set:
   - Hooks (auto-enforce file size limits, lint-on-save, silent-error and dangerous-command blocking, codebase health checks at `~/.claude/hooks/`)
   - Skills (commit, commit-push-pr, simplify, remember, dream, new-project, adopt-project, reflect at `~/.claude/skills/`)
   - Both
   - Neither
5. **Repo path** - what is the local path to the agent-starter repo? (e.g. `~/code/agent-starter`). Always required: the CLAUDE.md template, foundation templates, and lint configs are all copied from the repo. (Hooks and skills also install from here when selected and not already present.)

Do not proceed past this step until you have all answers.

## Step 2: Scaffold the Project

Execute these steps in order. Read the referenced files in this repo for full detail on each pattern.

### 1. Create directory structure

Reference: `guides/large-codebase-best-practices.md` - Section 1 (Feature-based directory structure)

Create the project root and subdirectories:

```
<project-name>/
├── src/
│   ├── features/      # feature modules - each gets its own directory
│   ├── services/      # shared business logic by domain
│   ├── utils/         # truly shared utilities
│   ├── types/         # shared type definitions (break import cycles here)
│   ├── constants/     # named constants by domain
│   ├── schemas/       # validation schemas
│   ├── entrypoints/   # app entry points
│   └── migrations/    # data/config format migrations
├── tests/
├── docs/
└── scripts/
```

### 2. Generate CLAUDE.md

Reference: `templates/CLAUDE.md`

Copy `templates/CLAUDE.md` into `<project-name>/CLAUDE.md`.
In the `## Project-Specific Instructions` section at the bottom, add:

```
**Project:** <project-name>
**Description:** <project-description>
```

### 3. Create config files

**`.gitignore`:**
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

**`.env.example`:**
```
# Required environment variables - copy to .env and fill in values
```

**`README.md`:**
```markdown
# <project-name>

<project-description>

## Getting Started

<!-- Add setup instructions here -->
```

**`CLAUDE.local.md`** (gitignored - personal, machine-local instructions that are never committed): create it with just a comment header.

**`.claude/rules/`** - modular instruction files loaded alongside CLAUDE.md. Create `.claude/rules/starter-patterns.md`, the apply-on-touch pattern index (the same file `ADOPT.md` Tier 4 writes), so new code has a pointer to each foundation guide. Optionally add topic stubs (`testing.md`, `git-workflow.md`, `code-style.md`, `security.md`) per `templates/NEW_PROJECT_PROMPT.md`.

### 4. Install lint configs (TypeScript/JavaScript or Python projects)

Reference: `guides/lint-rules-for-ai.md`

If the project's tech stack is TypeScript or JavaScript, copy both configs and install their dependencies. Biome handles formatting + fast syntactic rules; ESLint handles type-aware + plugin rules.

```bash
cp <repo-path>/templates/biome.jsonc <project-name>/biome.jsonc
cp <repo-path>/templates/eslint.config.mjs <project-name>/eslint.config.mjs
cd <project-name>
npm i -D @biomejs/biome eslint typescript-eslint eslint-plugin-import \
  eslint-plugin-sonarjs eslint-plugin-security eslint-plugin-eslint-comments
```

If the stack is Python, copy the ruff + pyright configs instead. Ruff handles formatting + fast syntactic rules; pyright handles type-aware analysis.

```bash
cp <repo-path>/templates/ruff.toml <project-name>/ruff.toml
cp <repo-path>/templates/pyrightconfig.json <project-name>/pyrightconfig.json
cd <project-name>
uv add --dev ruff pyright   # or: python -m pip install ruff pyright
```

Skip this step for other stacks (Rust, Go, etc.).

### 5. Copy foundation templates (TypeScript/JavaScript or Python)

Reference: `guides/error-id-registry.md`, `guides/zod-at-the-boundary.md`

These are the "create from day one" foundation files (see `templates/NEW_PROJECT_PROMPT.md` -> Foundation Files): a centralized env boundary, a numbered error registry, and an output truncator. Copy them for the matching stack into `src/utils/` / `src/constants/` per the directory layout, then adapt import paths.

TypeScript/JavaScript:

```bash
cp <repo-path>/templates/env.ts <project-name>/src/utils/env.ts
cp <repo-path>/templates/errorIds.ts <project-name>/src/constants/errorIds.ts
cp <repo-path>/templates/truncate-for-context.ts <project-name>/src/utils/truncate-for-context.ts
```

Python:

```bash
cp <repo-path>/templates/env.py <project-name>/src/utils/env.py
cp <repo-path>/templates/error_ids.py <project-name>/src/constants/error_ids.py
cp <repo-path>/templates/truncate_for_context.py <project-name>/src/utils/truncate_for_context.py
```

Skip for other stacks - point the developer at the guides above to build equivalents.

### 6. Install hooks (if selected and not already installed)

Skip if Step 0 detected hooks already installed **and** the stamped version
matches the repo `VERSION` - they're system-wide, so they already cover this
project. If installed but stale, offer to update by re-running the installer
(idempotent). Otherwise run it now.

The installer copies the hooks (and `lib/`) to `~/.claude/hooks/`, stamps the
installed version, and merges the hook wiring into `~/.claude/settings.json`
with jq. Existing entries are preserved and re-running never duplicates
anything, so there is no hand-editing of JSON:

```bash
bash <repo-path>/install.sh
```

Hooks wired by default:
- `check-file-size.sh` - block files >300 lines (PostToolUse:Write|Edit)
- `check-codebase-health.sh` - session-start health report (SessionStart)
- `lint-on-edit.sh` - Biome + ESLint on save; ruff check + format for Python (PostToolUse:Write|Edit)
- `check-silent-errors.sh` - block swallowed exceptions (PostToolUse:Write|Edit)
- `block-dangerous-commands.sh` - block force-push, `reset --hard`, recursive rm on `/`/`~` (PreToolUse:Bash)
- `suggest-loop-improvements.sh` - on `/loop`, offer tighter drop-in rewrites via an interactive picker before it runs (UserPromptSubmit)

Optional: add `--with-read-guard` to also wire `track-reads.sh` +
`require-read-before-edit.sh` (force Read before Edit). Recent Claude Code
versions enforce read-before-edit natively, so only install it for older
versions.

Reference: `hooks/README.md` for full hook documentation and manual-install snippets.

### 7. Install skills (if selected and not already installed)

Copy **only the skills Step 0 reported as `missing`**. Skills are system-wide,
so any already present already cover this project - leave them as-is rather than
overwriting (a blind `cp -r` would clobber local edits):

```bash
mkdir -p ~/.claude/skills
for s in commit commit-push-pr simplify remember dream new-project adopt-project reflect; do
  [ -d ~/.claude/skills/$s ] || cp -r <repo-path>/skills/$s ~/.claude/skills/
done
```

To deliberately refresh an already-installed skill after pulling a newer repo,
copy that one explicitly: `cp -r <repo-path>/skills/<name> ~/.claude/skills/`.

### 8. Initialize the self-improvement ledger

Create the project-local ledger directory and ignore the raw signal (keep the
distilled reflections tracked):

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

### 9. Initialize git and first commit

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

## Step 3: Verify Output

Confirm each item before reporting done:

- [ ] Project directory with feature-based structure (`src/features`, `src/services`, `src/utils`, `src/types`, `src/constants`, `src/schemas`, `src/entrypoints`, `src/migrations`, `tests/`, `docs/`, `scripts/`)
- [ ] `CLAUDE.md` copied from `templates/CLAUDE.md` with project name and description filled in
- [ ] `.gitignore`, `.env.example`, `README.md`, and `CLAUDE.local.md` present (`CLAUDE.local.md` gitignored)
- [ ] `.claude/rules/starter-patterns.md` written
- [ ] Lint configs copied + deps installed - `biome.jsonc` + `eslint.config.mjs` (TS/JS) or `ruff.toml` + `pyrightconfig.json` (Python); skipped for other stacks
- [ ] Foundation templates copied - env boundary + error registry + truncator for the stack (TS or Python); skipped for other stacks
- [ ] Hooks installed to `~/.claude/hooks/` and configured in `settings.json` (if selected)
- [ ] Skills installed to `~/.claude/skills/` (if selected)
- [ ] `.harness/reflections/` created and `.harness/ledger.jsonl` added to `.gitignore`
- [ ] `reflect` skill installed to `~/.claude/skills/reflect`
- [ ] Initial git commit created
