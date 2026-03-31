# Best Practices for Large Codebases with Claude Code

Derived from analyzing Anthropic's Claude Code CLI source (~1,900 files, 512K+ lines TypeScript). These patterns make a codebase both maintainable at scale AND AI-friendly for development with Claude Code.

---

## 1. Directory Structure: Feature-Based, Not Layer-Based

Don't organize by technical layer (all controllers in one folder, all models in another). Organize by feature — each feature gets its own directory with ALL related files.

```
src/
├── tools/
│   ├── BashTool/           # 18 files — everything about Bash in one place
│   │   ├── BashTool.tsx    # Main implementation
│   │   ├── toolName.ts     # Just the constant (breaks circular deps)
│   │   ├── constants.ts    # Config values
│   │   ├── prompt.ts       # AI prompt text
│   │   ├── permissions.ts  # Access control logic
│   │   ├── security.ts     # Security validation
│   │   ├── validation.ts   # Input validation
│   │   ├── utils.ts        # Helpers
│   │   └── UI.tsx          # Display component
│   ├── FileEditTool/
│   └── GrepTool/
├── commands/               # Each slash-command gets its own directory
├── services/               # Business logic by domain
│   ├── analytics/
│   ├── api/
│   └── mcp/
├── constants/              # Named constants by domain
│   ├── errorIds.ts
│   ├── xml.ts
│   └── toolLimits.ts
├── types/                  # Shared types (exist to break import cycles)
├── schemas/                # Validation schemas (Zod)
├── utils/                  # Truly shared utilities
├── entrypoints/            # App entry points
├── migrations/             # Data/config format migrations
└── bootstrap/              # Initialization state
```

**Why this works:** When Claude Code needs to modify a feature, everything is in one directory. No jumping across 6 folders to understand one feature.

---

## 2. Keep Files Small — Target 64% Under 200 Lines

Claude Code's own codebase file size distribution:

| Size | Files | % |
|------|-------|---|
| ≤50 lines | 437 | 23% |
| 51-100 lines | 349 | 19% |
| 101-200 lines | 423 | 22% |
| 201-500 lines | 425 | 23% |
| 501-1000 lines | 163 | 9% |
| >1000 lines | 88 | 5% |

**64% of files are under 200 lines.** This is not an accident — it's designed for AI context windows.

### How to split files by concern:

```
Feature/
├── toolName.ts         # 2 lines — just the name constant
├── constants.ts        # 10-30 lines — config values
├── types.ts            # Type definitions only
├── prompt.ts           # AI prompt text
├── permissions.ts      # Access control
├── security.ts         # Security validation
├── validation.ts       # Input validation
├── utils.ts            # Pure helper functions
├── Feature.tsx         # Main implementation
└── UI.tsx              # Display/rendering
```

**Rule:** When a single responsibility grows past ~300 lines, extract it to its own file.

---

## 3. Zero Magic Strings — Everything Gets a Constant

Create a `constants/` directory and be religious about it:

```typescript
// constants/xml.ts — ALL tag names
export const COMMAND_NAME_TAG = 'command-name'
export const BASH_INPUT_TAG = 'bash-input'

// constants/errorIds.ts — numbered error codes
export const E_TOOL_USE_FAILED = 341
export const E_SUMMARY_GENERATION_FAILED = 344
// Next ID: 345 — add new errors here with the next sequential number

// constants/messages.ts — even single strings
export const NO_CONTENT_MESSAGE = '(no content)'

// Feature/toolName.ts — break circular deps
// This file exists to break circular dependency from prompt.ts
export const BASH_TOOL_NAME = 'Bash'
```

**Why:** AI can grep for constant usage, refactor safely, and never introduce typos in strings.

---

## 4. Break Import Cycles Explicitly

Circular dependencies are the #1 codebase killer at scale. Claude Code's pattern:

```typescript
// types/permissions.ts
/**
 * Pure permission type definitions extracted to break import cycles.
 * This file contains only type definitions and constants with NO runtime
 * dependencies.
 */
export type PermissionMode = 'allow' | 'deny' | 'ask'

// Feature/toolName.ts
// Here to break circular dependency from prompt.ts
export const TOOL_NAME = 'MyTool'
```

**Rules:**
- Shared types go in `types/` with a header comment explaining WHY they're extracted
- Constants that might cause cycles get their own tiny files
- Use `import type` consistently for type-only imports
- Document cycle-breaking decisions in file headers

---

## 5. Naming Conventions That Scale

```
Files:
  PascalCase     — classes, components: BashTool.tsx, AppState.tsx
  camelCase      — utilities, functions: bashPermissions.ts, envUtils.ts
  kebab-case     — config/data files: cost-tracker.ts

Directories:
  PascalCase     — feature modules: BashTool/, PromptInput/
  camelCase      — utility groups: bash/, plugins/

Types:
  PascalCase     — with descriptive suffixes: ToolInputJSONSchema

Functions:
  is/has prefix  — booleans: isENOENT(), hasExactErrorMessage()
  get prefix     — getters: getErrnoCode(), getClaudeAiBaseUrl()
  build prefix   — constructors: buildTool(), buildMemoryPrompt()

Constants:
  SCREAMING_SNAKE — values: DEFAULT_MAX_RESULT_SIZE_CHARS
```

### The "Intentionally Long Name" Pattern

Force developers to think before using sensitive operations:

```typescript
// You literally can't use this without acknowledging what you're doing
export class TelemetrySafeError_I_VERIFIED_THIS_IS_NOT_CODE_OR_FILEPATHS extends Error {}

type AnalyticsMetadata_I_VERIFIED_THIS_IS_NOT_CODE_OR_FILEPATHS = string
```

---

## 6. Error Handling Architecture

Don't just throw Error. Build a hierarchy:

```typescript
// utils/errors.ts
export class AppError extends Error { }
export class AbortError extends AppError { }
export class ConfigParseError extends AppError { }
export class ShellError extends AppError { }

// Safe error extraction — never use (e as SomeType)
export function toError(e: unknown): Error { ... }
export function errorMessage(e: unknown): string { ... }
export function getErrnoCode(e: unknown): string | undefined { ... }

// Semantic boolean helpers
export function isENOENT(e: unknown): boolean { ... }
export function isAbortError(e: unknown): boolean { ... }

// Sequential error IDs for production tracing
// constants/errorIds.ts
export const E_CONFIG_PARSE_FAILED = 101
export const E_NETWORK_TIMEOUT = 102
// Next ID: 103
```

**Why:** AI can pattern-match on error types, suggest correct handlers, and never produce unsafe casts.

---

## 7. CLAUDE.md Hierarchy — 4 Layers

Set up instructions at multiple levels of specificity:

```
/etc/app/CLAUDE.md              # Global defaults (managed/deployed)
~/.claude/CLAUDE.md             # User's personal global prefs
project/CLAUDE.md               # Project conventions (committed)
project/.claude/CLAUDE.md       # Extended project instructions
project/.claude/rules/*.md      # Modular rule files (any .md gets loaded)
project/CLAUDE.local.md         # Personal project prefs (gitignored)
```

**Lower layers override higher ones.** Use `.claude/rules/` for modular, composable instructions instead of one massive CLAUDE.md.

Example rules structure:
```
.claude/rules/
├── testing.md          # "Always use real DB, never mock"
├── git-workflow.md     # "Feature branches, squash merge"
├── code-style.md       # "Functional style, no classes"
└── security.md         # "Never commit secrets, scan before push"
```

---

## 8. Lazy Loading Everything

Fast startup matters. Load expensive things on demand:

```typescript
// Commands: lazy-load via dynamic import
const help = {
  type: 'local-jsx',
  name: 'help',
  load: () => import('./help.js'),
} satisfies Command

// Heavy dependencies: import when needed, not at module load
async function analyze() {
  const { OpenTelemetry } = await import('./otel.js')  // 400KB
  // ...
}

// Feature-flagged modules: conditional require for tree-shaking
const AdvancedTool = FEATURE_ENABLED
  ? require('./AdvancedTool.js').AdvancedTool
  : null
```

---

## 9. Environment Variables: Validated, Not Raw

Never use `process.env.X` directly throughout the codebase:

```typescript
// utils/envUtils.ts — centralize ALL env access
export function isEnvTruthy(val: string | undefined): boolean { ... }
export function isEnvDefinedFalsy(val: string | undefined): boolean { ... }

// utils/envValidation.ts — validated with defaults and bounds
export function validateBoundedIntEnvVar(
  name: string,
  defaultValue: number,
  min: number,
  max: number
): number { ... }

// Two-phase initialization
applySafeConfigEnvironmentVariables()   // Phase 1: before trust dialog
applyConfigEnvironmentVariables()        // Phase 2: after trust established
```

**Enforce with a lint rule:** `custom-rules/no-process-env-top-level` — prevents raw env access at module scope.

---

## 10. Custom ESLint Rules as Architectural Guardrails

Don't rely on code review to catch structural violations. Automate:

```
custom-rules/
├── no-top-level-side-effects      # Modules must be pure at import time
├── no-process-env-top-level       # No raw env access at module scope
├── safe-env-boolean-check         # Prevent truthy/falsy bugs with env vars
├── bootstrap-isolation            # Prevent circular deps in bootstrap
└── no-sync-fs                     # Flag synchronous file operations
```

---

## 11. Documentation: WHY, Not WHAT

```typescript
// BAD — explains what (the code already says this)
// Increment the counter by one
counter++

// GOOD — explains why (non-obvious constraint)
// The SDK class is checked via instanceof because minified builds mangle
// class names, making constructor.name unreliable
if (error instanceof AnthropicError) { ... }

// GOOD — section headers for navigation in large files
// ============================================================================
// Permission Modes
// ============================================================================

// GOOD — @[TAG] markers for coordinated updates
// @[MODEL LAUNCH] — update this when adding new model support

// GOOD — design intent at file level
/** DESIGN: This module has NO dependencies to avoid import cycles. */
```

---

## 12. Registration Pattern Over Switch Statements

Don't maintain a central switch/if-else for extensibility:

```typescript
// BAD — adding a tool means editing a central file
switch (toolName) {
  case 'bash': return new BashTool()
  case 'grep': return new GrepTool()
  // ... 40 more cases
}

// GOOD — each module registers itself
// BashTool/index.ts
registerTool(BashTool)

// GrepTool/index.ts
registerTool(GrepTool)

// skills/simplify.ts
registerBundledSkill({
  name: 'simplify',
  description: 'Review changed code...',
  async getPromptForCommand(args) { ... },
})
```

---

## 13. Memoize Expensive Operations

```typescript
import { memoize } from 'lodash-es'

// Platform detection, config reads, git queries — compute once
export const getProjectDir = memoize((cwd: string) => {
  // expensive git root detection
})

// But provide escape hatches
getProjectDir.cache.clear!()  // When config changes
```

---

## 14. Migrations Directory

Codebases evolve. Config formats change. Handle it:

```
src/migrations/
├── migrateV1ToV2.ts
├── migrateSettingsFormat.ts
└── migrateSonnet45ToSonnet46.ts   # Even model version changes!
```

Each migration is a standalone function that transforms old format → new format. Run at startup, track which have been applied.

---

## 15. Secret Scanning Before Data Leaves the Machine

```typescript
// services/secretScanner.ts
// Uses gitleaks-derived regex rules
const SECRET_PATTERNS = [
  /AKIA[0-9A-Z]{16}/,              // AWS Access Key
  /AIza[0-9A-Za-z\-_]{35}/,        // GCP API Key
  // Deliberately assembled at runtime so the literal doesn't appear in bundle
  const ANT_KEY_PFX = ['sk','ant','api'].join('-')
]

// Block writes containing secrets
function checkForSecrets(content: string): SecretMatch[] { ... }

// Called from every file write operation
if (isSharedPath(path)) {
  const secrets = checkForSecrets(content)
  if (secrets.length > 0) throw new SecretDetectedError(secrets)
}
```

---

## Quick-Start Checklist for a New Project

```bash
mkdir my-project && cd my-project
git init

# 1. Directory structure
mkdir -p src/{features,services,utils,types,constants,schemas,entrypoints,migrations}
mkdir -p .claude/rules

# 2. CLAUDE.md hierarchy
touch CLAUDE.md                    # Project conventions (commit this)
touch CLAUDE.local.md              # Personal prefs (gitignore this)
echo "CLAUDE.local.md" >> .gitignore

# 3. Modular rules
touch .claude/rules/testing.md
touch .claude/rules/git-workflow.md
touch .claude/rules/code-style.md

# 4. Constants from day one
touch src/constants/errorIds.ts
touch src/constants/messages.ts

# 5. Error utilities from day one
touch src/utils/errors.ts
touch src/utils/envUtils.ts

# 6. Types directory for shared interfaces
touch src/types/index.ts
```

---

## The Golden Rule

**Every decision should optimize for this: when Claude Code reads your codebase, can it understand the full context of a feature without loading more than 5 files?**

That means:
- Features are co-located, not scattered
- Files are small and focused
- Constants are named, not magic
- Types are shared cleanly
- Documentation explains WHY
- Conventions are written in CLAUDE.md, not tribal knowledge
