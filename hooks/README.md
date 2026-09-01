# Claude Code Hooks

Ready-to-use hook scripts for Claude Code. Add to your `settings.json`.

## Setup

Recommended - run the idempotent installer from the repo root. It copies the
hooks (and `lib/`) to `~/.claude/hooks/`, stamps the installed version into
`~/.claude/hooks/.agent-starter-version`, and merges the hook wiring into
`~/.claude/settings.json` with jq (existing entries preserved, re-runs never
duplicate):

```bash
./install.sh                       # default hook set
./install.sh --with-read-guard     # also wire track-reads + require-read-before-edit
./install.sh --with-comment-guard  # also wire check-new-comments
./install.sh --with-em-dash-guard  # also wire check-em-dash
./install.sh --help                # every flag
```

Requires `jq` and `python3`.

Manual alternative:

1. Copy hooks to your Claude config:
```bash
mkdir -p ~/.claude/hooks
cp hooks/*.sh hooks/*.py ~/.claude/hooks/
mkdir -p ~/.claude/hooks/lib && cp hooks/lib/*.sh ~/.claude/hooks/lib/
chmod +x ~/.claude/hooks/*.sh ~/.claude/hooks/*.py ~/.claude/hooks/lib/*.sh
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
- **Modules** (`.ts`, `.py`, ...): **>300 lines BLOCKS** the write (exit 2), **>200 WARNS**
- **Stylesheets** (`.css`, `.scss`, `.sass`, `.less`): **>400 BLOCKS**, **>250 WARNS**
- **Single-file components** (`.astro`, `.vue`, `.svelte`): **>400 BLOCKS**, **>250 WARNS**
- Skips non-code files (.md, .mdx, .markdown, .json, .yaml, etc.)
- Suggests extraction targets that fit the language: types/constants/validation/utils
  for modules, and layers (tokens, base, components, states) for stylesheets

Stylesheets get their own tier because they have no types, constants, or helper
functions to extract, so the module advice is noise for them, and 200 lines is tight
for a language whose unit is roughly one declaration per line.

Single-file components get a tier for the same reason: the component, its scoped
stylesheet, and its client script in one file is the framework's unit, not a smell. A
301-line `Header.astro` was 21 lines of frontmatter, 31 of markup, 149 of scoped
`<style>`, and 100 of client `<script>`. Scored against the module default it is the CSS
that trips the limit, and flattening it into a global sheet to win back lines would lose
the scoping and make the code worse.

**Per-project thresholds:** drop a `.harness/file-size.conf` in the repo root with
`WARN_THRESHOLD=` and `BLOCK_THRESHOLD=` lines to override the defaults. The right number
depends on the codebase, not on this hook. Only those two integers are read, by pattern:
the file is never sourced, so a config committed to a repo cannot run shell on every edit.
The split advice stays the hook's, so a project can move the line but cannot turn the
advice into something unhelpful.

### lint-on-edit.sh
**Event:** PostToolUse (Write, Edit)
**What it does:** Runs Biome (`biome check --write`) then ESLint (`eslint --fix --max-warnings 0`) on any `.ts/.tsx/.js/.jsx/.mjs/.cjs` file Claude writes. Each tool runs only if its config + local binary are present.
- **Exit 2** with the tool output on stderr if errors remain - Claude sees the errors and self-corrects on the next turn.
- Biome handles format + fast syntactic rules with autofix; ESLint handles type-aware + plugin rules (import resolution, sonarjs, security).
- Opt-in `tsc --noEmit` per project: `touch .claude/enable-typecheck-on-edit` in the project root.
- No-ops silently when no `package.json` is present or when neither tool is installed.
- **Python:** runs `ruff check --fix`, then `ruff format`, on `.py` files when a ruff binary is available (`.venv/bin/ruff` or on PATH). No-ops when ruff or a project root (pyproject/setup.py/requirements/.git) is absent.
- **Python type-check:** opt-in `mypy` per project (the type-aware step, like `tsc` on the TS path): `touch .claude/enable-typecheck-on-edit` in the project root. The marker is your consent - when it's present and no mypy binary is found (`.venv/bin/mypy` or on PATH), the hook installs mypy (into `.venv` when present, otherwise via `pip`/`python3 -m pip`) rather than silently skipping. It then runs `mypy <file>` and blocks (exit 2) on type errors. If the install fails (no network/pip), it warns without blocking the edit.

Pairs with `templates/biome.jsonc` + `templates/eslint.config.mjs` (TS) and `templates/ruff.toml` + `templates/pyrightconfig.json` (Python). See `guides/lint-rules-for-ai.md` for the rule rationale and split.

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
- Skips `*/scratchpad/*`. A one-off probe in the session scratchpad is deleted with the
  session, so holding it to the re-raise-or-log-with-context contract is noise, not safety.
  The exemption is deliberately not `/tmp/*`: on Linux that is where `mktemp -d` puts real
  project checkouts, including this repo's own test fixtures.
- Pairs with the guidance in `guides/hooks-reference.md` § "Block silent error patterns".

### block-dangerous-commands.sh
**Event:** PreToolUse (Bash)
**What it does:** Blocks destructive shell commands before they run: `git push --force`/`-f` (suggests `--force-with-lease`), `git reset --hard/--merge`, `git clean -f`, `git checkout -- .` / `git restore .`, recursive `rm` on `/`, `/*`, `~` or `$HOME`, and `chmod -R 777 /`.

- **Exit 2** with the matched reason on stderr so Claude can pick a safer alternative.
- Logs a `dangerous-command` event to the `.harness` ledger, as a stable reason
  code plus the command's *shape* (`force_push: git push ...`). The raw command
  is **not** stored: a blocked command is the one most likely to be carrying a
  token, a signed URL, or customer data, and the ledger is durable on-disk state.
  Set `CLAUDE_LEDGER_VERBOSE=1` to keep the full command locally when debugging.
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

### rm-scope-guard.py
**Event:** PreToolUse (Bash)
**What it does:** Allows `rm` whose targets are inside the working directory, blocks `rm`
whose targets escape it: absolute paths, `../` escapes, `~/...`, `$HOME/...`.

`block-dangerous-commands.sh` catches only `rm` on `/`, `/*`, `~`, and `$HOME`, which is the
catastrophic case and not the common one. The common one is an agent tidying up and reaching
one directory too far. The two hooks are complementary; wire both.

- **Exit 2** listing the escaping targets, with the alternatives: move the path into a
  project-local `.trash/`, or run the `rm` from a shell outside Claude.
- Logs an `rm-scope` event to the `.harness` ledger.
- **Escape hatch:** `CLAUDE_ALLOW_DANGEROUS=1`, the same variable
  `block-dangerous-commands.sh` uses.

Tokenizing is quote-aware (`shlex` with `punctuation_chars`), so the remote payload of
`ssh host 'cd /opt/app && rm -rf cache'` stays one argument and is never judged against the
local working directory. `$HOME` and `${HOME}` are expanded; no other variable is, because
guessing at an undefined variable's value produces false positives in the blocking
direction.

Four things it deliberately handles, each of which is a bypass if missed:

- **`cd` is tracked across the command.** `cd .. && rm -rf sibling` resolves the target
  against the parent, not against the payload's cwd. The *boundary* stays fixed at the
  session's working directory: `cd` changes where a relative path resolves, never how far
  the guard lets you reach. `cd -` makes the directory unknowable, so relative targets after
  it are treated as escaping.
- **Wrapped invocations.** `sudo -n rm`, `command rm`, `env rm`, `\rm`, and `/bin/rm` are all
  found, by scanning each segment for the `rm` token rather than by requiring it first.
- **Redirection operands are not targets.** `rm -f build.log >/dev/null` used to be blocked
  because `shlex` emits `/dev/null` as its own token.
- **Symlinks are resolved**, so `/tmp` and `/var/folders` paths on macOS compare correctly
  against a realpath'd boundary.

**Known gaps:** commands that build `rm` arguments dynamically (`xargs rm`, `find -exec rm`,
`eval`) pass through unchecked, because the `rm` wrapping is not visible to a string parser.
Because targets are resolved through symlinks, removing an in-cwd symlink that points
outside cwd is blocked even though `rm` would only delete the link. Both err in the safe
direction.

### worktree-session-prompt.sh + worktree-exit-offer.sh
**Events:** SessionStart, Stop
**What they do together:** Keep parallel agents from colliding in one checkout.

`worktree-session-prompt.sh` reports at session start whether this is the shared main
checkout or a linked worktree, with the branch and the uncommitted-file count. In the main
checkout it instructs Claude to ask, before the first edit, whether to take a fresh worktree
instead. Other sessions and agents use that same checkout, so a branch flip there can
silently revert a peer's edits.

`worktree-exit-offer.sh` fires on Stop and tells you the worktree is safe to leave, but only
once it is clean and fully pushed to its upstream: that is the one moment when exiting loses
nothing. It is silent in the main checkout, on a dirty tree, on a detached HEAD, with no
upstream, and with any unpushed commit.

It emits `systemMessage`, which surfaces to you and does not re-enter the model's turn, so
the note is addressed to you rather than phrased as an instruction to Claude. Making Claude
act on it would mean blocking the Stop event to force another turn, which is too aggressive
for an advisory that fires every time a worktree happens to be clean.

The session-start message names the base branch it suggests, derived from
`refs/remotes/origin/HEAD` or the current branch's upstream, and falls back to "this repo's
default branch" when neither exists. It does not assume `origin/main`.

Both are no-ops outside a git repository.

### check-new-comments.py (opt-in)
**Event:** PreToolUse (Write, Edit, MultiEdit)
**What it does:** Blocks an edit that adds a comment, block comment, or Python docstring, on
the principle that code should carry its own meaning. Wire it with
`./install.sh --with-comment-guard`.

- **Exit 2** listing the offending added lines, with the rewrite the rule wants: a name, a
  type, a named constant, a small function, or a test whose name states the constraint.
- Diffs against the prior text, so only *added* comments count. Deleting comments is always
  allowed; reflowing or rewording an existing one counts as adding.
- Catches **trailing** comments (`x = 1  # why`, `const x = 1; // why`) as well as
  whole-line ones. Quoted strings are masked before the search, so `"https://example.com"`
  and `tag = "# not a comment"` are not false positives. Unmasked JS regex literals holding
  adjacent slashes (`/\//g`) are a known false positive; exempt the file if you hit it.
- Toolchain directives pass on their own: shebangs, `noqa`, `type: ignore`,
  `eslint-disable`, `@ts-expect-error`, `biome-ignore`, coverage pragmas, `SPDX-`,
  `silent-ok`, and about twenty more, in trailing position too.
- **Exemptions:** a glob per line in `.harness/comment-exempt` (project) or
  `~/.claude/comment-exempt` (global). Both files are read; either can match. A glob is
  tried against the repo-relative path (`src/generated/*.ts`), the absolute path, and the
  bare basename (`*.generated.ts`), so committed project globs need no machine-specific
  prefix.
- The language tables live in `comment_syntax.py` beside it.
- **Escape hatch:** `CLAUDE_SKIP_COMMENT_CHECK=1`.

This is a house style, not a correctness rule, which is why it is off by default. The case
for it: a comment is a second copy of the design that no test covers, no type checks, and no
reviewer verifies, so it drifts silently and then misleads with the authority of source.

### check-em-dash.py (opt-in)
**Event:** PostToolUse (Write, Edit)
**What it does:** Blocks em dashes (U+2014) and horizontal bars (U+2015) in `.md`, `.mdx`,
and `.markdown` files. Wire it with `./install.sh --with-em-dash-guard`.

- **Exit 2** listing the offending lines. En dashes and hyphens are not flagged, because
  they are correct in numeric ranges and flagging them produces mostly false positives.
- Skips anything outside `$CLAUDE_PROJECT_DIR`, and skips `.harness/`, `.superpowers/`, and
  `node_modules/` inside it: those hold gitignored agent-written reports, not prose this
  rule governs.
- Logs an `em-dash` event to the `.harness` ledger.

Also a house style. Wire it if em dashes read as machine-written to you.

### suggest-loop-improvements.sh
**Event:** UserPromptSubmit
**What it does:** When you run `/loop`, injects an instruction that has Claude propose 2-3 improved, drop-in replacements for the command before it runs, then present them with the `AskUserQuestion` tool so you pick one interactively (A / B / C, plus "Run original unchanged") - no copy-paste. Claude runs only the option you select.

- The hook does **no LLM work and spawns no nested session** - it only injects context, so the already-running model generates the variants. Fast (<50ms), needs no API key.
- Filters by prompt text (`UserPromptSubmit` has no matcher), so it is a silent no-op for every other prompt.
- Each replacement adds only the missing precision - explicit success criteria, a stop condition, bounded scope, a verification step - while preserving your interval and args.
- Non-blocking (exit 0): if the command is already solid, or the session is headless (no interactive prompt), the original runs unchanged.

**Scoped to `/loop` only, on purpose.** `/loop` hands control to Claude to interpret and act, so the injected "ask first" instruction lands *before* any action and the picker can render. Client-side local commands like `/goal` execute their effect at submit time (the CLI sets the goal and arms its Stop hook before Claude's turn even starts), so an advisory (exit 0) injection cannot intercept them, and `/goal` also explicitly tells Claude not to pause and ask. The hook therefore matches only `/loop*` and ignores `/goal`. Interactive gating like this works only for commands whose effect Claude performs on its turn, not for client-side commands.

Add to `settings.json`:

```json
{
  "UserPromptSubmit": [
    {
      "hooks": [
        { "type": "command", "command": "~/.claude/hooks/suggest-loop-improvements.sh", "timeout": 10, "statusMessage": "Reviewing loop instructions..." }
      ]
    }
  ]
}
```

## Exit Code Behavior
- **Exit 0** - success, proceed normally
- **Exit 2** - BLOCK the action, stderr shown to Claude as error
- **Other** - warning shown to user, doesn't block

## Hook input: JSON on stdin

Claude Code sends command hooks a JSON payload on **stdin**, with the tool's own
arguments nested under `.tool_input`. There is no `$ARGUMENTS` variable for
command hooks; that placeholder exists only for `type: "prompt"` hooks.

Every hook here resolves its input through `lib/hook-input.sh`:

```bash
. "$(dirname "$0")/lib/hook-input.sh"
hook_input_init "${1:-}"
FILE_PATH=$(hook_input_file)     # or: CMD=$(hook_input_command)
```

It accepts a positional argument first (so CI and direct test invocation work
without stdin), then `$ARGUMENTS` for legacy callers, then the stdin payload.

**Malformed input is loud, not silent.** Non-empty input that isn't JSON exits 1
with an explanation on stderr: visible to the user, but not blocking, since a
parser bug should never be able to brick a session. Absent input stays exit 0,
which is the legitimate case of a hook run outside Claude Code.

This lives in one file for a reason. The same resolution block was previously
pasted into each hook, so when it turned out to be wrong there was no single
place to fix it: the correction reached three hooks and missed three others,
which went on silently enforcing nothing. Test hooks by piping a real payload,
never by setting `$ARGUMENTS` alone, or the test will pass against a hook that
is a no-op in production.

## Self-improvement ledger

`lib/log-event.sh` is a best-effort helper the enforcement hooks call when they
block or warn. It appends one JSON event to the project's `.harness/ledger.jsonl`
and always exits 0, so logging can never break a hook.

Three properties the metric depends on:
- **One ledger per repo.** The root is the git toplevel, so an edit inside a workspace
  member (`web/`, with its own `package.json`) does not fork a second ledger there.
- **Repo-relative paths**, so `harness-ledger-stats.sh` can cluster by real prefix.
  Absolute paths collapse every event into one useless `/Users` bucket.
- **Exact duplicates are dropped.** A hook registered twice (say, once by a plugin and
  again in `settings.json`) fires twice per edit and would otherwise double every
  count, silently inflating the metric `/reflect` reports.

`harness-ledger-stats.sh` reads that ledger and prints per-rule counts plus the
`recurring_events` metric (events in `(rule, path-prefix)` clusters seen ≥ N times
in a window). The `/reflect` skill uses it to propose improvements and to measure
whether recurring mistakes drop over time.

With no `--ledger` argument it merges the ledger of **every linked worktree** of the current
repo and normalizes paths to the main checkout's root, so an event logged as an absolute
path or under `.claude/worktrees/<name>/` lands in the same cluster as its peers. Hooks log
relative to whichever checkout the edit happened in, so when parallel worktrees are the
normal workflow, reading a single ledger hides most of the signal. Pass `--ledger PATH`
to read exactly one file instead.

The Python hooks (`rm-scope-guard.py`, `check-new-comments.py`, `check-em-dash.py`) call the
same `lib/log-event.sh`, resolved relative to the hook's own directory, so they log into the
same ledger.

Gitignore the raw ledger but keep the distilled reflections (run from your project root):
`echo '.harness/ledger.jsonl' >> .gitignore`
