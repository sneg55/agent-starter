# Claude Code Skills & Templates

Reusable skills and templates for Claude Code CLI, extracted from internal source patterns.

## Usage

Point an AI agent at this repo and say **"read this repo and set up my project"** — the agent reads `AGENT.md` and scaffolds a complete project interactively.

Or install the `/new-project` skill once and run it in any session:

```bash
cp -r skills/* ~/.claude/skills/
```

Then: `/new-project`

## Guides

### `guides/hooks-reference.md`
Complete reference for Claude Code's hook system — all 4 hook types, all 27 events, exit code behavior, configuration format, and 10 practical examples (auto-lint, block dangerous commands, agent verification, security review, Slack notifications, and more).

### `guides/large-codebase-best-practices.md`
Comprehensive best practices for setting up and scaling a large codebase with Claude Code — directory structure, file size targets, naming conventions, error handling, CLAUDE.md hierarchy, and more. All derived from analyzing Anthropic's own Claude Code CLI source.

## Templates

### `templates/NEW_PROJECT_PROMPT.md`
Copy-paste prompt for Claude Code to scaffold a new project from scratch. Covers directory structure, CLAUDE.md hierarchy, modular rules, error handling, constants, env validation, git setup, and coding standards. Just fill in the {{placeholders}} and go.

### `templates/CLAUDE.md`
Drop-in project instructions template with the full 4-type memory taxonomy (user, feedback, project, reference), memory file format, consolidation workflow, recall guidelines, and git safety rules.

**Usage:**
```bash
# Option A: paste the prompt into Claude Code for a new project
cat templates/NEW_PROJECT_PROMPT.md

# Option B: drop the CLAUDE.md template into an existing project
cp templates/CLAUDE.md /path/to/your/project/CLAUDE.md
```

## Skills

Place skill folders in `~/.claude/skills/` (personal) or `.claude/skills/` (per-project).

```bash
cp -r skills/* ~/.claude/skills/
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
