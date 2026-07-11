# agent-starter

Skills, hooks, templates, and engineering guides for bootstrapping AI-agent-friendly projects, with a per-project self-improvement loop.

## What it is

A toolkit for setting up projects that AI agents can work in safely and productively. It scaffolds new projects, retrofits existing ones, and ships enforcement hooks, drop-in configs, and engineering patterns. The differentiator is the [self-improvement loop](#the-self-improvement-loop): scaffolded projects capture signal from their own usage and turn it into better rules over time.

| Component | What it does | Where |
|-----------|--------------|-------|
| **Skills** | 8 slash commands: scaffold, adopt, commit, reflect, remember, dream | [`skills/`](skills/) |
| **Hooks** | Enforcement (lint, file-size, dangerous-command) + signal capture for the loop | [`hooks/`](hooks/) |
| **Templates** | Drop-in configs: Biome, ESLint, ruff, pyright, `CLAUDE.md`, env boundaries | [`templates/`](templates/) |
| **Guides** | 9 engineering patterns for AI-agent codebases | [`guides/`](guides/) |
| **Self-improvement loop** | Projects learn from their own usage and propose their own rules | across the above |

Provenance: patterns marked _"derived from Anthropic's Claude Code source"_ are reverse-engineered from the Claude Code CLI; everything else is added on top. See [About](#about).

## Quick start

This repo doubles as a Claude Code plugin marketplace. Installing the plugin is the recommended path: it loads every skill **and** wires the enforcement hooks in one step.

```
/plugin marketplace add sneg55/agent-starter
/plugin install agent-starter@agent-starter
```

Then run `/new-project` (new codebase) or `/adopt-project` (existing one).

## Install

Pick the path that matches what you want:

| I want... | Do this |
|-----------|---------|
| Everything (skills + hooks), one step | Plugin install, see [Quick start](#quick-start) |
| Just the skills, globally | `npx skills add sneg55/agent-starter -a claude-code -g` |
| Just the hooks in `~/.claude` | `git clone …/agent-starter && cd agent-starter && ./install.sh` |
| To point an agent at the repo | See the table below |

### Point an agent at the repo

No install needed. Give an agent the repo URL and it reads the matching entry file and drives the setup interactively (audit-first, opt-in, nothing overwritten):

| Situation | Say | Agent reads |
|-----------|-----|-------------|
| New project | "read this repo and set up my project `https://github.com/sneg55/agent-starter/`" | [`AGENT.md`](AGENT.md) |
| Existing project | "read this repo and apply it to my project" | [`ADOPT.md`](ADOPT.md) |
| Whole team | ship the setup with the repo so everyone gets it from a `git pull` | [`TEAM.md`](TEAM.md) |

`TEAM.md` is the companion to `ADOPT.md`: where `ADOPT.md` installs into one developer's `~/.claude`, `TEAM.md` vendors the setup (hooks, shared config, plugin defaults) into the repo itself.

### Notes on the plugin and hooks

- The plugin wires five enforcement hooks (file-size, lint-on-edit, silent-error, dangerous-command, codebase-health) plus a `/loop` instruction-review hook, all from [`hooks/hooks.json`](hooks/hooks.json).
- The read-before-edit guard pair is left out of the plugin on purpose (recent Claude Code enforces read-before-edit natively). Opt into it with `./install.sh --with-read-guard`.
- `install.sh` merges its `settings.json` wiring idempotently via jq, so re-runs never duplicate entries.

## Components

### Skills

Install all skills globally with [npx skills](https://github.com/vercel-labs/skills): `npx skills add sneg55/agent-starter -a claude-code -g` (or get them via the plugin).

| Skill | What it does |
|-------|--------------|
| `/new-project` | Interviews you, then scaffolds directory structure, `CLAUDE.md`, configs, hooks, skills, and the first commit. Mirrors `AGENT.md`. |
| `/adopt-project` | Audits an existing codebase, proposes components grouped by invasiveness, applies only what you approve. Mirrors `ADOPT.md`. |
| `/commit` | One well-crafted commit: analyzes the diff, follows repo style, writes a "why not what" message. Includes the Git Safety Protocol. |
| `/commit-push-pr` | Full git flow: branch, commit, push, and create/update a PR with summary and test plan. |
| `/simplify` | Spawns 3 parallel agents (Code Reuse, Quality, Efficiency) to review your diff and fix issues. |
| `/reflect` | The **promote** step of the loop: reads the `.harness` ledger and `feedback` memories, clusters recurring mistakes, proposes gated rule/threshold/lint/ADR changes. |
| `/remember` | Scans auto-memory and proposes promotions to `CLAUDE.md`, `CLAUDE.local.md`, or shared memory. Detects duplicates, stale entries, conflicts. |
| `/dream` | Memory consolidation: merges, prunes, and re-indexes memory files across four phases (orient, gather, consolidate, prune). |

### Hooks

Ready-to-use hook scripts in [`hooks/`](hooks/). The plugin wires the first six; `install.sh` wires them into `~/.claude`. See [`guides/hooks-reference.md`](guides/hooks-reference.md) for the hook system itself.

| Hook | Fires on | What it does |
|------|----------|--------------|
| `check-file-size.sh` | Write/Edit | Warns when a file exceeds size targets. |
| `lint-on-edit.sh` | Write/Edit | Lints + typechecks the file just written. |
| `check-silent-errors.sh` | Write/Edit | Blocks writes that introduce swallowed/silent error handling. |
| `block-dangerous-commands.sh` | Bash | Blocks destructive shell commands before they run. |
| `check-codebase-health.sh` | Session start | Surfaces codebase-health signals at the start of a session. |
| `suggest-loop-improvements.sh` | Prompt submit | On `/loop`, injects an instruction-review step. |
| `track-reads.sh` + `require-read-before-edit.sh` | Read / Write+Edit | Opt-in read-guard pair (`--with-read-guard`): blocks edits to files not read this session. |
| `lib/log-event.sh` | called by hooks | Appends one JSON event to `.harness/ledger.jsonl` (the loop's signal capture). |
| `harness-ledger-stats.sh` | on demand | Computes the `recurring_events` metric over the ledger. |

### Templates

Drop-in configs in [`templates/`](templates/). Copy the ones you need.

**Lint (paired with [`guides/lint-rules-for-ai.md`](guides/lint-rules-for-ai.md)):**
- `biome.jsonc` + `eslint.config.mjs` (TypeScript). Biome owns formatting and fast syntactic rules; ESLint owns type-aware correctness (`no-floating-promises`, the `no-unsafe-*` family), import resolution (catches hallucinated modules), and security rules.
- `ruff.toml` + `pyrightconfig.json`, the Python counterpart. Ruff owns formatting and fast rules; pyright (strict) owns type-aware analysis.

**Error handling & boundaries:**
- `errorIds.ts` / `error_ids.py`: central error-ID registry + `AppError`; every throw references a stable `E_DOMAIN_NNN` that stays searchable across rewordings. Pairs with [`guides/error-id-registry.md`](guides/error-id-registry.md).
- `env.ts` / `env.py`: single env-var boundary; Zod/pydantic schema is the source of truth, invalid env fails loudly at startup. Pairs with [`guides/zod-at-the-boundary.md`](guides/zod-at-the-boundary.md).

**Context & scaffolding:**
- `truncate-for-context.ts` / `truncate_for_context.py`: head+tail truncator for tool output so `cat large.log` and `npm test` don't blow the context window.
- `CLAUDE.md`: project-instructions template with the full 4-type [memory taxonomy](#memory-taxonomy), file format, and git safety rules.
- `NEW_PROJECT_PROMPT.md`: copy-paste prompt to scaffold a project from scratch. Fill in the `{{placeholders}}`.

### Guides

Engineering patterns in [`guides/`](guides/).

| Guide | What it covers |
|-------|----------------|
| `large-codebase-best-practices.md` | Directory structure, file-size targets, naming, error handling, `CLAUDE.md` hierarchy. _Derived from Anthropic's Claude Code source._ |
| `lint-rules-for-ai.md` | Tiered Biome + ESLint (and ruff + pyright) rules that block the mistakes LLMs make: dropped `await`s, `any` escape hatches, hallucinated imports, half-finished functions. |
| `hooks-reference.md` | The Claude Code hook system: 4 hook types, all 27 events, exit-code behavior, config format, 10 worked examples. |
| `tool-authoring-pattern.md` | The `BashTool/`-style directory-per-tool layout extracted from Claude Code's source. |
| `error-id-registry.md` | Stable error IDs (`E_CFG_003`) shared across logs, telemetry, docs, and agents. |
| `discriminated-union-results.md` | `Result<Ok, Err>` as the one shape every fallible function returns, exhaustiveness-checked by the compiler. |
| `abort-signal-threading.md` | Threading `AbortSignal` through long-running calls so Ctrl+C, timeouts, and obsoleted work actually stop. |
| `prompt-caching.md` | Structuring prompts so Anthropic's prefix cache hits 80%+, plus the silent cache-breakers to avoid. |
| `zod-at-the-boundary.md` | Validate external data once, at entry; the schema is the source of truth for the type. |

## The Self-Improvement Loop

> _New, added on top of the original Anthropic patterns._

Most starters are a frozen snapshot: every project begins from the same patterns and never learns from how it's actually used. agent-starter ships the machinery for each scaffolded project to **improve itself** from its own signal.

The loop has four parts. The first three reuse the existing memory + hooks system; only signal capture and measurement are new.

```
 ① signal → ② store → ③ promote → ④ measure → (back to ①)
   ▲                                              │
   └──────────────────────────────────────────────┘
```

- **① Signal.** `hooks/lib/log-event.sh` appends one JSON event to the project's `.harness/ledger.jsonl` every time an enforcement hook blocks or warns (file too large, lint failure, swallowed error, edit-before-read). It's best-effort and always exits 0, so logging can never break a hook. Your explicit corrections are already captured as `feedback` memories, the highest-value signal.
- **② Store.** The append-only ledger (structured events) plus the existing memory files (prose knowledge). The raw ledger is gitignored (local and noisy); distilled learnings are committed.
- **③ Promote.** The `/reflect` skill reads the ledger and your feedback memories, clusters recurring mistakes, and **proposes** concrete changes for your approval: a new project rule, a hook-threshold tweak, a lint rule, or an ADR. Nothing is auto-applied, you stay in the loop on every change.
- **④ Measure.** `hooks/harness-ledger-stats.sh` computes a `recurring_events` metric (mistakes that fall in recurring `(rule, path-prefix)` clusters). Each reflection records a snapshot to `.harness/reflections/YYYY-MM-DD.md`, so the next reflection can confirm a promoted rule actually reduced the mistakes it targeted.

The principle: **signal is private (gitignored ledger), wisdom is shared (committed reflections and the rules they produce).** New projects scaffolded via `AGENT.md` / `/new-project` are born with the loop wired in.

## Memory Taxonomy

The `CLAUDE.md` template uses a 4-type memory system:

| Type | Scope | What belongs |
|------|-------|--------------|
| **user** | Who they are | Role, goals, preferences, knowledge level |
| **feedback** | How to work | Corrections AND confirmations, both what to avoid and keep doing |
| **project** | What's happening | Ongoing work, deadlines, incidents, decisions |
| **reference** | Where to look | Pointers to external systems (Linear, Grafana, Slack, etc.) |

Key principles:
- Never save what's derivable from code/git
- Convert relative dates to absolute
- Structure feedback with Why + How to apply
- Verify memories against current state before acting on them

## About

agent-starter started as Anthropic's own engineering patterns, extracted from the Claude Code CLI source and packaged into reusable form. It has since been extended with additional best practices, tooling, and original ideas that go beyond the source material, the flagship being the [self-improvement loop](#the-self-improvement-loop). Patterns marked _"derived from Anthropic's Claude Code source"_ are reverse-engineered from the real thing; everything else is added on top.

Licensed under [MIT](LICENSE).
