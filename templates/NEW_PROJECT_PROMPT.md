# New Project Bootstrap Prompt

Paste this into Claude Code when starting a new project. Replace placeholders in {{brackets}}.

---

## The Prompt

```
I'm starting a new project called {{PROJECT_NAME}}.

{{BRIEF DESCRIPTION — e.g., "A TypeScript API for token vesting schedules" or "A Python CLI for DeFi portfolio tracking"}}

Tech stack: {{e.g., TypeScript/Node, Python/FastAPI, Rust, Go, etc.}}

Set up the full project scaffolding following these principles:

## 1. Directory Structure (feature-based, not layer-based)

Create a structure where each feature lives in its own directory with ALL related files (implementation, types, constants, validation, tests). Use this layout:

src/
├── features/          # Feature modules — each gets its own directory
├── services/          # Shared business logic by domain
├── utils/             # Truly shared utilities
├── types/             # Shared type definitions (break import cycles here)
├── constants/         # Named constants by domain (errorIds, messages, config)
├── schemas/           # Validation schemas
├── entrypoints/       # App entry points
└── migrations/        # Data/config format migrations

## 2. CLAUDE.md Hierarchy

Create these files:

### CLAUDE.md (commit this — project conventions for all contributors)
Include:
- Project description and architecture overview
- Build/test/lint commands
- Code style rules
- Git workflow (branch naming, commit format, PR process)
- What NOT to do

### CLAUDE.local.md (gitignore this — personal preferences)
Just create it empty with a comment header.

### .claude/rules/ (modular instruction files)
Create these rule files:
- testing.md — testing philosophy, frameworks, patterns
- git-workflow.md — branch naming, commit messages, PR conventions
- code-style.md — formatting, naming, patterns to follow/avoid
- security.md — secrets handling, input validation, dependencies

## 3. Foundation Files (create from day one)

### Error handling (utils/errors)
- Custom error class hierarchy extending base Error
- Safe error extraction helpers: toError(unknown), errorMessage(unknown)
- Semantic boolean helpers: isNotFound(), isAbort(), isTimeout()

### Constants (constants/)
- errorIds — sequential numbered error codes with "Next ID: N" comment
- messages — all user-facing strings as named constants

### Environment (utils/env)
- Centralized env var access — never raw process.env/os.environ
- Validated with defaults and bounds
- isEnvTruthy / isEnvDefined helpers

### Types (types/)
- Start with an index file exporting shared interfaces
- Header comment: "Shared types extracted here to prevent import cycles"

## 4. Config Files

Create appropriate config for the tech stack:
- Package manager lockfile
- Linter config with custom rules for architectural boundaries
- Formatter config
- TypeScript/language config with strict settings
- .gitignore (include CLAUDE.local.md, env files, build output)
- .env.example with all expected env vars documented

## 5. Coding Standards to Embed

Apply these rules in all generated code:

### File size
- Target 64% of files under 200 lines
- When a responsibility grows past ~300 lines, extract to its own file
- Split by concern: types.ts, constants.ts, validation.ts, utils.ts

### Naming
- Files: PascalCase for classes/components, camelCase for utilities
- Directories: PascalCase for features, camelCase for utilities
- Functions: is/has prefix for booleans, get for getters, build for constructors
- Constants: SCREAMING_SNAKE_CASE

### No magic strings
- Every string literal that appears more than once becomes a constant
- Constants that might cause circular deps get their own tiny file

### Imports
- Use type-only imports where possible
- Document any cycle-breaking decisions in file headers

### Documentation
- Comments explain WHY, never WHAT
- File headers explain design decisions and dependencies
- Use @[TAG] markers for things that need coordinated updates
- Section headers (========) in files over 200 lines

### Registration over switch
- Use registration/plugin patterns for extensibility
- Each module registers itself, no central switch statement

## 6. Git Setup

- Initialize repo
- Create .gitignore
- Make initial commit with scaffold
- Set up branch protection rules in CLAUDE.md

## 7. README.md

Create a README with:
- Project description
- Quick start (install, run, test)
- Architecture overview pointing to key directories
- Contributing guidelines

---

Now scaffold everything. Create real files with real content — not just empty placeholders. Error utilities should have working implementations. Constants should have initial values. CLAUDE.md should have comprehensive instructions. Make it production-ready from commit zero.
```
