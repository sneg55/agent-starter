# Claude Code Skills & Templates

Reusable skills and templates for Claude Code CLI, extracted from internal source patterns.

## Templates

### `templates/CLAUDE.md`
Drop-in project instructions template with the full 4-type memory taxonomy (user, feedback, project, reference), memory file format, consolidation workflow, recall guidelines, and git safety rules.

**Usage:** Copy to your project root as `CLAUDE.md` and add project-specific instructions at the bottom.

```bash
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

### /dream
Memory consolidation — reflective pass that merges, prunes, and re-indexes memory files. Run periodically to keep memories organized. Works through 4 phases: orient, gather, consolidate, prune.

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
