# Agent Project Bootstrap

This repo contains patterns for bootstrapping AI-friendly projects. Follow these instructions to scaffold a complete new project for the developer.

## Step 1: Interview the Developer

Ask these questions **one at a time** before taking any action:

1. **Project name** — what is the name of the project?
2. **Description** — one sentence describing what it does.
3. **Tech stack** — language, framework, package manager (e.g. "TypeScript, Next.js, pnpm").
4. **Optional components** — which would you like installed?
   - Hooks (auto-enforce file size limits and codebase health checks at `~/.claude/hooks/`)
   - Skills (commit, commit-push-pr, simplify, remember, dream, new-project at `~/.claude/skills/`)
   - Both
   - Neither
5. **Repo path** (only if hooks or skills selected) — what is the local path to the agent-starter repo? (e.g. `~/code/agent-starter`). If the answer to question 4 was "Neither", skip this question.

Do not proceed past this step until you have all answers.

## Step 2: Scaffold the Project

Execute these steps in order. Read the referenced files in this repo for full detail on each pattern.

### 1. Create directory structure

Reference: `guides/large-codebase-best-practices.md` — Section 1 (Feature-based directory structure)

Create the project root and subdirectories:

```
<project-name>/
├── src/
│   ├── features/      # feature modules — each gets its own directory
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
```

**`.env.example`:**
```
# Required environment variables — copy to .env and fill in values
```

**`README.md`:**
```markdown
# <project-name>

<project-description>

## Getting Started

<!-- Add setup instructions here -->
```

### 4. Install Biome + ESLint configs (TypeScript/JavaScript projects only)

Reference: `guides/lint-rules-for-ai.md`

If the project's tech stack is TypeScript or JavaScript, copy both configs and install their dependencies. Biome handles formatting + fast syntactic rules; ESLint handles type-aware + plugin rules.

```bash
cp <repo-path>/templates/biome.json <project-name>/biome.json
cp <repo-path>/templates/eslint.config.mjs <project-name>/eslint.config.mjs
cd <project-name>
npm i -D @biomejs/biome eslint typescript-eslint eslint-plugin-import \
  eslint-plugin-sonarjs eslint-plugin-security eslint-plugin-eslint-comments
```

Skip this step for non-JS/TS stacks (Python, Rust, Go, etc.).

### 5. Install hooks (if selected)

Run the idempotent installer — it copies the hooks (and `lib/`) to
`~/.claude/hooks/`, stamps the installed version, and merges the hook wiring
into `~/.claude/settings.json` with jq. Existing entries are preserved and
re-running never duplicates anything, so there is no hand-editing of JSON:

```bash
bash <repo-path>/install.sh
```

Hooks wired by default:
- `check-file-size.sh` — block files >300 lines (PostToolUse:Write|Edit)
- `check-codebase-health.sh` — session-start health report (SessionStart)
- `lint-on-edit.sh` — Biome + ESLint on save; ruff for Python (PostToolUse:Write|Edit)
- `check-silent-errors.sh` — block swallowed exceptions (PostToolUse:Write|Edit)
- `block-dangerous-commands.sh` — block force-push, `reset --hard`, recursive rm on `/`/`~` (PreToolUse:Bash)

Optional: add `--with-read-guard` to also wire `track-reads.sh` +
`require-read-before-edit.sh` (force Read before Edit). Recent Claude Code
versions enforce read-before-edit natively, so only install it for older
versions.

Reference: `hooks/README.md` for full hook documentation and manual-install snippets.

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
cp -r <repo-path>/skills/reflect ~/.claude/skills/
```

### 7. Initialize the self-improvement ledger

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

## Step 3: Verify Output

Confirm each item before reporting done:

- [ ] Project directory with feature-based structure (`src/features`, `src/services`, `src/utils`, `src/types`, `src/constants`, `src/schemas`, `src/entrypoints`, `src/migrations`, `tests/`, `docs/`, `scripts/`)
- [ ] `CLAUDE.md` present with project name and description filled in
- [ ] `.gitignore`, `.env.example`, and `README.md` present
- [ ] `biome.json` + `eslint.config.mjs` copied + lint deps installed (TS/JS stacks only)
- [ ] Hooks installed to `~/.claude/hooks/` and configured in `settings.json` (if selected)
- [ ] Skills installed to `~/.claude/skills/` (if selected)
- [ ] `.harness/reflections/` created and `.harness/ledger.jsonl` added to `.gitignore`
- [ ] `reflect` skill installed to `~/.claude/skills/reflect`
- [ ] Initial git commit created
