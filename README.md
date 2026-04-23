# agent-starter

Anthropic's own engineering patterns, extracted from the Claude Code CLI source leak and packaged into reusable skills, templates, and guides for bootstrapping AI-agent-friendly projects.

## Usage

Point an AI agent at this repo and say **"read this repo and set up my project"** — the agent reads `AGENT.md` and scaffolds a complete project interactively.

Or install the `/new-project` skill once and run it in any session:

```bash
npx skills add sneg55/agent-starter -a claude-code -g
```

Then: `/new-project`

## Guides

### `guides/large-codebase-best-practices.md`
Comprehensive best practices for setting up and scaling a large codebase with Claude Code — directory structure, file size targets, naming conventions, error handling, CLAUDE.md hierarchy, and more. All derived from analyzing Anthropic's own Claude Code CLI source.

### `guides/lint-rules-for-ai.md`
Tiered Biome + ESLint ruleset tuned for AI-agent-driven TypeScript codebases. Blocks the specific mistakes LLMs make (dropped `await`s, `any` escape hatches, hallucinated imports, half-finished functions) rather than enforcing arbitrary line caps. Biome handles fast syntactic rules + formatting; ESLint keeps type-aware and plugin-specific rules. Pairs with `templates/biome.json`, `templates/eslint.config.mjs`, and `hooks/lint-on-edit.sh`.

### `guides/hooks-reference.md`
Complete reference for Claude Code's hook system — all 4 hook types, all 27 events, exit code behavior, configuration format, and 10 practical examples (auto-lint, block dangerous commands, agent verification, security review, Slack notifications, and more).

### `guides/tool-authoring-pattern.md`
The `BashTool/`-style directory-per-tool layout extracted from Claude Code's own source. Each tool is a handful of single-purpose files (`toolName.ts`, `schema.ts`, `prompt.ts`, `validation.ts`, `permissions.ts`, `security.ts`, `execute.ts`, `result.ts`). Gives an agent a predictable place to look when editing any tool and breaks whole classes of import cycles.

### `guides/error-id-registry.md`
Every thrown error carries a stable ID (`E_CFG_003`) from a central registry. Logs, telemetry, docs, and agents all reference the same ID, so error-message rewordings don't break grep or alerting. Pairs with `templates/errorIds.ts`.

### `guides/discriminated-union-results.md`
`Result<Ok, Err>` as the one shape every fallible function returns. Exhaustiveness-checked via the compiler; no ad-hoc `{success, data}` / `{ok: 1}` drift across edits. Reserves throws for programmer errors only.

### `guides/abort-signal-threading.md`
Thread `AbortSignal` through every long-running call so Ctrl+C, timeouts, and obsoleted work actually stop. Covers the canonical entry-point shape, `AbortSignal.any` for composed timeouts, the `AbortError` swallow anti-pattern, and an ESLint rule idea for bare `fetch()`.

### `guides/prompt-caching.md`
How to structure prompts so Anthropic's prefix cache hits 80%+. Canonical order (system → tools → stable context → history → user turn), the cache breakpoint layout, silent cache-breakers (timestamps, unstable JSON key order, per-user strings in the prefix), and TTL-aware polling intervals.

### `guides/zod-at-the-boundary.md`
Validate external data the moment it enters your program; never re-check inside. The schema is the source of truth for the type (`type T = z.infer<typeof schema>`). Covers env vars, config files, HTTP responses, and LLM output. Pairs with `templates/env.ts`.

## Templates

### `templates/NEW_PROJECT_PROMPT.md`
Copy-paste prompt for Claude Code to scaffold a new project from scratch. Covers directory structure, CLAUDE.md hierarchy, modular rules, error handling, constants, env validation, git setup, and coding standards. Just fill in the {{placeholders}} and go.

### `templates/biome.json` + `templates/eslint.config.mjs`
Drop-in Biome + ESLint configs tuned for AI-agent TypeScript projects. Biome owns formatting and fast syntactic rules; ESLint owns type-aware correctness (`no-floating-promises`, the `no-unsafe-*` family), import resolution (catches hallucinated modules), sonarjs cognitive complexity, and security rules. See `guides/lint-rules-for-ai.md` for the rationale and the full split.

### `templates/CLAUDE.md`
Drop-in project instructions template with the full 4-type memory taxonomy (user, feedback, project, reference), memory file format, consolidation workflow, recall guidelines, and git safety rules.

### `templates/errorIds.ts`
Central error ID registry + `AppError` class. Every throw site references a stable `E_DOMAIN_NNN` ID that stays searchable even as messages get rewritten. Pairs with `guides/error-id-registry.md`.

### `templates/truncate-for-context.ts`
Head-plus-tail truncator for tool output. Keeps the first N lines and last M lines, replaces the middle with `[... X lines elided ...]`. Pipe every tool result through this so `cat large.log` and `npm test` don't blow the context window.

### `templates/env.ts`
Single env-var boundary. All `process.env` reads happen here and nowhere else (the ESLint config enforces this). Zod schema is the source of truth for the `Env` type; invalid env fails loudly at startup with the exact field and reason. Pairs with `guides/zod-at-the-boundary.md`.

**Usage:**
```bash
# Option A: paste the prompt into Claude Code for a new project
cat templates/NEW_PROJECT_PROMPT.md

# Option B: drop the CLAUDE.md template into an existing project
cp templates/CLAUDE.md /path/to/your/project/CLAUDE.md
```

## Skills

Install all skills globally with [npx skills](https://github.com/vercel-labs/skills):

```bash
npx skills add sneg55/agent-starter -a claude-code -g
```

### /simplify
Code review and cleanup — spawns 3 parallel agents (Code Reuse, Quality, Efficiency) to review your git diff and fix issues.

### /remember
Memory review and organization — scans auto-memory entries and proposes promotions to CLAUDE.md, CLAUDE.local.md, or shared memory. Detects duplicates, outdated entries, and conflicts.

### /commit
Create a single well-crafted git commit. Analyzes diff, follows repo's commit style, writes a "why not what" message. Includes Git Safety Protocol.

### /commit-push-pr
Full git workflow — creates branch, commits, pushes, and creates/updates a PR with summary and test plan. Detects existing PRs and updates them.

### /dream
Memory consolidation — reflective pass that merges, prunes, and re-indexes memory files. Run periodically to keep memories organized. Works through 4 phases: orient, gather, consolidate, prune.

### /new-project
Full project bootstrap — interviews the developer (name, description, stack, components), then scaffolds directory structure, CLAUDE.md, config files, hooks, skills, and first commit. Mirrors `AGENT.md`.

## Memory Taxonomy

The template uses a 4-type memory system:

| Type | Scope | What belongs |
|------|-------|-------------|
| **user** | Who they are | Role, goals, preferences, knowledge level |
| **feedback** | How to work | Corrections AND confirmations — both what to avoid and keep doing |
| **project** | What's happening | Ongoing work, deadlines, incidents, decisions |
| **reference** | Where to look | Pointers to external systems (Linear, Grafana, Slack, etc.) |

Key principles:
- Never save what's derivable from code/git
- Convert relative dates to absolute
- Structure feedback with Why + How to apply
- Verify memories against current state before acting on them
