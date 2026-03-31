# Claude Code Skills

Reusable skills for Claude Code CLI. Place these in `~/.claude/skills/` or `.claude/skills/` in your project root.

## Skills

### /simplify
Code review and cleanup — spawns 3 parallel agents (Code Reuse, Quality, Efficiency) to review your git diff and fix issues.

### /remember
Memory review and organization — scans auto-memory entries and proposes promotions to CLAUDE.md, CLAUDE.local.md, or shared memory. Detects duplicates, outdated entries, and conflicts.

## Installation

Copy the skill folders into your Claude Code skills directory:

```bash
# Personal (applies to all projects)
cp -r skills/* ~/.claude/skills/

# Or per-project
cp -r skills/* .claude/skills/
```
