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

### 4. Install ESLint config (TypeScript/JavaScript projects only)

Reference: `guides/lint-rules-for-ai.md`

If the project's tech stack is TypeScript or JavaScript, copy the ruleset and install its dependencies:

```bash
cp <repo-path>/templates/eslint.config.mjs <project-name>/eslint.config.mjs
cd <project-name>
npm i -D eslint typescript-eslint eslint-plugin-import \
  eslint-plugin-sonarjs eslint-plugin-security eslint-plugin-eslint-comments
```

Skip this step for non-JS/TS stacks (Python, Rust, Go, etc.).

### 5. Install hooks (if selected)

```bash
mkdir -p ~/.claude/hooks
cp <repo-path>/hooks/check-file-size.sh ~/.claude/hooks/
cp <repo-path>/hooks/check-codebase-health.sh ~/.claude/hooks/
cp <repo-path>/hooks/lint-on-edit.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/check-file-size.sh ~/.claude/hooks/check-codebase-health.sh ~/.claude/hooks/lint-on-edit.sh
```

Merge this into `~/.claude/settings.json`. Read the existing file first, then append to the `hooks.PostToolUse` and `hooks.SessionStart` arrays — do not replace existing entries. If the hook command already appears verbatim, skip it:

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
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/lint-on-edit.sh",
            "timeout": 30,
            "statusMessage": "Linting..."
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

Reference: `hooks/README.md` for full hook documentation.

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
```

### 7. Initialize git and first commit

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
- [ ] `eslint.config.mjs` copied + lint deps installed (TS/JS stacks only)
- [ ] Hooks installed to `~/.claude/hooks/` and configured in `settings.json` (if selected)
- [ ] Skills installed to `~/.claude/skills/` (if selected)
- [ ] Initial git commit created
