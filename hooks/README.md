# Claude Code Hooks

Ready-to-use hook scripts for Claude Code. Add to your `settings.json`.

## Setup

Recommended - run the idempotent installer from the repo root. It copies the
hooks (and `lib/`) to `~/.claude/hooks/`, stamps the installed version into
`~/.claude/hooks/.agent-starter-version`, and merges the hook wiring into
`~/.claude/settings.json` with jq (existing entries preserved, re-runs never
duplicate):

```bash
./install.sh                    # default hook set
./install.sh --with-read-guard  # also wire track-reads + require-read-before-edit
```

Manual alternative:

1. Copy hooks to your Claude config:
```bash
mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
mkdir -p ~/.claude/hooks/lib && cp hooks/lib/*.sh ~/.claude/hooks/lib/
chmod +x ~/.claude/hooks/*.sh ~/.claude/hooks/lib/*.sh
```

2. Add to `~/.claude/settings.json` (or `.claude/settings.json` per-project):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
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
**Event:** PostToolUse (Write, Edit)
**What it does:** Checks every file Claude writes or edits (wire to both - a file can grow past the limit through repeated Edits):
- **>300 lines: BLOCKS the write** (exit 2) and tells Claude to split the file
- **>200 lines: WARNS** that the file is getting large
- Skips non-code files (.md, .json, .yaml, etc.)
- Suggests specific extraction targets (types, constants, validation, utils)

### lint-on-edit.sh
**Event:** PostToolUse (Write, Edit)
**What it does:** Runs Biome (`biome check --write`) then ESLint (`eslint --fix --max-warnings 0`) on any `.ts/.tsx/.js/.jsx/.mjs/.cjs` file Claude writes. Each tool runs only if its config + local binary are present.
- **Exit 2** with the tool output on stderr if errors remain - Claude sees the errors and self-corrects on the next turn.
- Biome handles format + fast syntactic rules with autofix; ESLint handles type-aware + plugin rules (import resolution, sonarjs, security).
- Opt-in `tsc --noEmit` per project: `touch .claude/enable-typecheck-on-edit` in the project root.
- No-ops silently when no `package.json` is present or when neither tool is installed.
- **Python:** runs `ruff check --fix`, then `ruff format`, on `.py` files when a ruff binary is available (`.venv/bin/ruff` or on PATH). No-ops when ruff or a project root (pyproject/setup.py/requirements/.git) is absent.
- **Python type-check:** opt-in `mypy` per project (the type-aware step, like `tsc` on the TS path): `touch .claude/enable-typecheck-on-edit` in the project root. The marker is your consent - when it's present and no mypy binary is found (`.venv/bin/mypy` or on PATH), the hook installs mypy (into `.venv` when present, otherwise via `pip`/`python3 -m pip`) rather than silently skipping. It then runs `mypy <file>` and blocks (exit 2) on type errors. If the install fails (no network/pip), it warns without blocking the edit.

Pairs with `templates/biome.json` + `templates/eslint.config.mjs` (TS) and `templates/ruff.toml` + `templates/pyrightconfig.json` (Python). See `guides/lint-rules-for-ai.md` for the rule rationale and split.

Add to `settings.json`:

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "~/.claude/hooks/lint-on-edit.sh",
      "timeout": 30,
      "statusMessage": "Linting..."
    }
  ]
}
```

### check-codebase-health.sh
**Event:** SessionStart
**What it does:** On every new session, reports:
- File size distribution across the codebase
- Percentage of files under 200 lines (target: 64%)
- Lists any files over 500 lines that need splitting
- Only outputs when there are issues (silent when healthy)

### track-reads.sh + require-read-before-edit.sh
**Events:** PostToolUse (Read) + PreToolUse (Edit, Write)
**What they do together:** Force a Read before every Edit/Write in a session. `track-reads.sh` logs every Read to `$CLAUDE_SESSION_DIR/read-files.txt`; `require-read-before-edit.sh` blocks any Edit/Write to an existing file that isn't in that log.

> **Largely superseded:** recent Claude Code versions enforce read-before-edit natively - Edit fails without a prior Read, and Write refuses to overwrite an unread file. Keep this pair only for older versions, or if you want the attempted-unread-edit signal in the `.harness` ledger. `install.sh` wires it only with `--with-read-guard`.

- **Why:** LLMs routinely edit files from memory rather than current contents. This catches hallucinated edits before they corrupt files.
- **Exempt paths:** add globs to `.claude/read-before-edit-exempt` (one per line).
- **Escape hatch:** set `CLAUDE_SKIP_READ_CHECK=1` to disable.
- **Install both** - the pre-hook fails open with a warning if the post-hook isn't logging.

Add to `settings.json`:

```json
{
  "PostToolUse": [
    { "matcher": "Read",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/track-reads.sh", "timeout": 3 }] }
  ],
  "PreToolUse": [
    { "matcher": "Edit|Write",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/require-read-before-edit.sh", "timeout": 3 }] }
  ]
}
```

### check-silent-errors.sh
**Event:** PostToolUse (Write, Edit)
**What it does:** Blocks writes that introduce silent error handling. Catches bare `except:`, `except: pass`, `except: ...`, empty `catch {}`, and `catch` blocks whose only body is `console.log`.

- **Exit 2** with specific line numbers on stderr so Claude can fix and retry.
- Exempt a single site with an inline comment: `// silent-ok` (JS/TS) or `# silent-ok` (Python).
- Pairs with the guidance in `guides/hooks-reference.md` § "Block silent error patterns".

### block-dangerous-commands.sh
**Event:** PreToolUse (Bash)
**What it does:** Blocks destructive shell commands before they run: `git push --force`/`-f` (suggests `--force-with-lease`), `git reset --hard/--merge`, `git clean -f`, `git checkout -- .` / `git restore .`, recursive `rm` on `/`, `/*`, `~` or `$HOME`, and `chmod -R 777 /`.

- **Exit 2** with the matched reason on stderr so Claude can pick a safer alternative.
- Logs a `dangerous-command` event to the `.harness` ledger.
- **Escape hatch:** set `CLAUDE_ALLOW_DANGEROUS=1` after the developer explicitly approves.

Add to `settings.json`:

```json
{
  "PreToolUse": [
    { "matcher": "Bash",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/block-dangerous-commands.sh", "timeout": 3, "statusMessage": "Checking command safety..." }] }
  ]
}
```

## Exit Code Behavior
- **Exit 0** - success, proceed normally
- **Exit 2** - BLOCK the action, stderr shown to Claude as error
- **Other** - warning shown to user, doesn't block

## Self-improvement ledger

`lib/log-event.sh` is a best-effort helper the enforcement hooks call when they
block or warn. It appends one JSON event to the project's `.harness/ledger.jsonl`
and always exits 0, so logging can never break a hook.

`harness-ledger-stats.sh` reads that ledger and prints per-rule counts plus the
`recurring_events` metric (events in `(rule, path-prefix)` clusters seen ≥ N times
in a window). The `/reflect` skill uses it to propose improvements and to measure
whether recurring mistakes drop over time.

Gitignore the raw ledger but keep the distilled reflections (run from your project root):
`echo '.harness/ledger.jsonl' >> .gitignore`
