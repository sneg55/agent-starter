# Agent Project Bootstrap

This repo contains patterns for bootstrapping AI-friendly projects. Follow these instructions to scaffold a complete new project for the developer.

## Step 1: Interview the Developer

Ask these questions **one at a time** before taking any action:

1. **Project name** — what is the name of the project?
2. **Description** — one sentence describing what it does.
3. **Tech stack** — language, framework, package manager (e.g. "TypeScript, Next.js, pnpm").
4. **Optional components** — which would you like installed?
   - Hooks (auto-enforce file size limits and codebase health checks)
   - Skills (commit, commit-push-pr, simplify, remember, dream, new-project)
   - Both
   - Neither
5. **Repo path** (only if hooks or skills selected) — what is the local path to this repo? (e.g. `~/code/claude-code-skills`)

Do not proceed past this step until you have all answers.

## Step 2: Scaffold the Project

Execute these steps in order. Read the referenced files in this repo for full detail on each pattern.

### 1. Create directory structure

Reference: `guides/large-codebase-best-practices.md` — Section 1 (Feature-based directory structure)

Create the project root and subdirectories:

```
<project-name>/
├── src/
│   ├── commands/      # entry points / CLI handlers
│   ├── core/          # domain logic
│   ├── types/         # shared interfaces and types
│   ├── utils/         # stateless helper functions
│   └── constants/     # named constants, no magic strings
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

### 4. Install hooks (if selected)

```bash
mkdir -p ~/.claude/hooks
cp <repo-path>/hooks/check-file-size.sh ~/.claude/hooks/
cp <repo-path>/hooks/check-codebase-health.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/check-file-size.sh ~/.claude/hooks/check-codebase-health.sh
```

Merge this into `~/.claude/settings.json` (do not overwrite existing keys):

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

Reference: `hooks/README.md` for full hook documentation.

### 5. Install skills (if selected)

```bash
mkdir -p ~/.claude/skills
cp -r <repo-path>/skills/commit ~/.claude/skills/
cp -r <repo-path>/skills/commit-push-pr ~/.claude/skills/
cp -r <repo-path>/skills/simplify ~/.claude/skills/
cp -r <repo-path>/skills/remember ~/.claude/skills/
cp -r <repo-path>/skills/dream ~/.claude/skills/
cp -r <repo-path>/skills/new-project ~/.claude/skills/
```

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

## Step 3: Verify Output

Confirm each item before reporting done:

- [ ] Project directory with feature-based structure (`src/commands`, `src/core`, `src/types`, `src/utils`, `src/constants`, `tests/`, `docs/`, `scripts/`)
- [ ] `CLAUDE.md` present with project name and description filled in
- [ ] `.gitignore`, `.env.example`, and `README.md` present
- [ ] Hooks installed and configured in `settings.json` (if selected)
- [ ] Skills installed to `~/.claude/skills/` (if selected)
- [ ] Initial git commit created
