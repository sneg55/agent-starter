# Claude Code Hooks Reference

Hooks let you run shell commands, LLM prompts, verification agents, or HTTP webhooks automatically when Claude Code performs actions. Configure in `~/.claude/settings.json` (global) or `.claude/settings.json` (per-project).

---

## Hook Types

### 1. command — Run a shell command
```json
{
  "type": "command",
  "command": "npm run lint",
  "shell": "bash",
  "timeout": 30,
  "statusMessage": "Linting...",
  "async": false,
  "once": false
}
```

### 2. prompt — Evaluate with an LLM
```json
{
  "type": "prompt",
  "prompt": "Is this safe? $ARGUMENTS",
  "model": "claude-sonnet-4-6",
  "timeout": 30
}
```

### 3. agent — Spawn a sub-agent with tools
```json
{
  "type": "agent",
  "prompt": "Verify unit tests pass after this change. $ARGUMENTS",
  "model": "claude-sonnet-4-6",
  "timeout": 120
}
```

### 4. http — POST to a webhook URL
```json
{
  "type": "http",
  "url": "https://hooks.slack.com/services/YOUR/WEBHOOK",
  "headers": {
    "Authorization": "Bearer $MY_TOKEN"
  },
  "allowedEnvVars": ["MY_TOKEN"],
  "timeout": 10
}
```

---

## All 27 Events

### Tool Events
| Event | Matcher Field | Description |
|-------|---------------|-------------|
| `PreToolUse` | tool_name | Before tool execution — can block it |
| `PostToolUse` | tool_name | After tool execution |
| `PostToolUseFailure` | tool_name | After tool execution fails |
| `PermissionDenied` | tool_name | After auto mode denies a tool |
| `PermissionRequest` | tool_name | When permission dialog shows |

### Session Events
| Event | Matcher Field | Description |
|-------|---------------|-------------|
| `SessionStart` | source (startup, resume, clear, compact) | New session starts |
| `SessionEnd` | reason (clear, logout, prompt_input_exit) | Session ending |
| `UserPromptSubmit` | — | When user sends a message |
| `Stop` | — | Before Claude finishes responding |
| `StopFailure` | error (rate_limit, auth, billing, etc.) | Turn ends due to API error |

### Agent Events
| Event | Matcher Field | Description |
|-------|---------------|-------------|
| `SubagentStart` | agent_type | Subagent started |
| `SubagentStop` | agent_type | Subagent concludes |

### Compaction Events
| Event | Matcher Field | Description |
|-------|---------------|-------------|
| `PreCompact` | trigger (manual, auto) | Before compaction |
| `PostCompact` | trigger (manual, auto) | After compaction |

### File & Config Events
| Event | Matcher Field | Description |
|-------|---------------|-------------|
| `FileChanged` | filename pattern | Watched file changes |
| `ConfigChange` | source (user/project/local/policy/skills) | Config files change |
| `CwdChanged` | — | Working directory changes |

### Task Events
| Event | Matcher Field | Description |
|-------|---------------|-------------|
| `TaskCreated` | — | Task being created |
| `TaskCompleted` | — | Task being completed |

### Other Events
| Event | Matcher Field | Description |
|-------|---------------|-------------|
| `Setup` | trigger (init, maintenance) | Repo setup |
| `Notification` | notification_type | Notifications sent |
| `Elicitation` | mcp_server_name | MCP server requests input |
| `ElicitationResult` | mcp_server_name | After user responds to MCP |
| `InstructionsLoaded` | load_reason | Instruction file loaded |
| `WorktreeCreate` | — | Worktree created |
| `WorktreeRemove` | — | Worktree removed |
| `TeammateIdle` | — | Teammate about to go idle |

---

## Exit Code Behavior

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success — proceed normally |
| 2 | **BLOCK** — stderr shown to Claude, action stopped |
| Other | Warning — stderr shown to user only, doesn't block |

---

## Configuration Format

```json
{
  "hooks": {
    "<EventName>": [
      {
        "matcher": "<optional string to match>",
        "hooks": [
          {
            "type": "command|prompt|agent|http",
            ...hook-specific fields
          }
        ]
      }
    ]
  }
}
```

### Common Fields (all hook types)
- `if` — filter condition using permission syntax (e.g., `"Bash(git *)"`, `"Write(*.ts)"`)
- `timeout` — max seconds
- `statusMessage` — shown during execution
- `once` — remove hook after first execution

### Special Variables
- `$ARGUMENTS` — full hook input JSON
- `$ARGUMENTS[0]`, `$0` — indexed access to arguments
- `$ENV_VAR` — environment variable interpolation (http headers only, must be in allowedEnvVars)

---

## Practical Examples

### Auto-lint after every file write
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "eslint --fix \"$(echo $ARGUMENTS | jq -r '.file_path')\"",
            "timeout": 30,
            "statusMessage": "Linting..."
          }
        ]
      }
    ]
  }
}
```

### Block dangerous git commands
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$ARGUMENTS\" | grep -qE '(force.push|--force|--hard|rm -rf /)' && echo 'BLOCKED: dangerous command' >&2 && exit 2 || exit 0",
            "if": "Bash(git *)"
          }
        ]
      }
    ]
  }
}
```

### Agent verification after code changes
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "agent",
            "prompt": "Verify the code change is correct. Check: 1) No syntax errors, 2) Tests still pass, 3) No regressions. Context: $ARGUMENTS",
            "model": "claude-sonnet-4-6",
            "timeout": 120,
            "statusMessage": "Verifying changes..."
          }
        ]
      }
    ]
  }
}
```

### LLM security review before Bash
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Security review this shell command. Check for: secret leaks, destructive operations, network exfiltration, privilege escalation. Command: $ARGUMENTS. Reply JSON: {\"decision\": \"approve\"} or {\"decision\": \"block\", \"reason\": \"...\"}",
            "model": "claude-haiku-4",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

### Slack notification on session end
```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "https://hooks.slack.com/services/T00/B00/xxx",
            "headers": {
              "Content-Type": "application/json"
            },
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### Auto-save WIP commit when Claude stops
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "git diff --quiet || (git add -A && git commit -m 'WIP: auto-save from Claude session')",
            "async": true,
            "statusMessage": "Auto-saving..."
          }
        ]
      }
    ]
  }
}
```

### Run tests after writing test files
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$ARGUMENTS\" | jq -r '.file_path' | grep -q '\\.test\\.' && npm test -- --bail || exit 0",
            "timeout": 60,
            "statusMessage": "Running tests..."
          }
        ]
      }
    ]
  }
}
```

### Block writes to protected files
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$ARGUMENTS\" | jq -r '.file_path' | grep -qE '(package-lock\\.json|\\.env|secrets)' && echo 'BLOCKED: protected file' >&2 && exit 2 || exit 0"
          }
        ]
      }
    ]
  }
}
```

### Notify on errors
```json
{
  "hooks": {
    "StopFailure": [
      {
        "matcher": "rate_limit",
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude hit rate limit\" with title \"Claude Code\"'",
            "async": true
          }
        ]
      }
    ]
  }
}
```

### Watch .env changes and reload
```json
{
  "hooks": {
    "FileChanged": [
      {
        "matcher": ".envrc|.env",
        "hooks": [
          {
            "type": "command",
            "command": "direnv export json > /tmp/claude-env.json",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

---

## Settings File Locations

| File | Scope |
|------|-------|
| `~/.claude/settings.json` | Global (all projects) |
| `.claude/settings.json` | Project (committed) |
| `.claude/settings.local.json` | Personal project (gitignored) |

Priority: user settings > project settings > local settings
