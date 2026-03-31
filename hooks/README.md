# Claude Code Hooks

Ready-to-use hook scripts for Claude Code. Add to your `settings.json`.

## Setup

1. Copy hooks to your Claude config:
```bash
mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

2. Add to `~/.claude/settings.json` (or `.claude/settings.json` per-project):

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

## Available Hooks

### check-file-size.sh
**Event:** PostToolUse (Write)
**What it does:** Checks every file Claude writes:
- **>300 lines: BLOCKS the write** (exit 2) and tells Claude to split the file
- **>200 lines: WARNS** that the file is getting large
- Skips non-code files (.md, .json, .yaml, etc.)
- Suggests specific extraction targets (types, constants, validation, utils)

### check-codebase-health.sh
**Event:** SessionStart
**What it does:** On every new session, reports:
- File size distribution across the codebase
- Percentage of files under 200 lines (target: 64%)
- Lists any files over 500 lines that need splitting
- Only outputs when there are issues (silent when healthy)

## Exit Code Behavior
- **Exit 0** — success, proceed normally
- **Exit 2** — BLOCK the action, stderr shown to Claude as error
- **Other** — warning shown to user, doesn't block
