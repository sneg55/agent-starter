# Rolling agent-starter out to a whole team

`ADOPT.md` retrofits agent-starter onto an existing codebase **on one
developer's machine** - it installs hooks and skills into `~/.claude`, which is
per-user and does not travel. This file is the companion for the next question:
**how do you make the whole team get the same setup from a `git pull`?**

Run `ADOPT.md` first (or alongside this). Everything here assumes the audit-first,
opt-in, one-commit-per-component discipline from `ADOPT.md` still holds.

## The one idea that drives everything

agent-starter components split into two buckets. Sort every component before you
touch anything:

| Travels with the repo (commit once → everyone gets it on pull) | Per-machine (each dev installs; does **not** travel) |
| --- | --- |
| `CLAUDE.md` additions | hook **scripts** (if installed via `install.sh` → `~/.claude/hooks/`) |
| `.claude/rules/starter-patterns.md` | skills (`~/.claude/skills/`) |
| hook **wiring** in `.claude/settings.json` | plugins (install into `~/.claude`, trust-gated) |
| **vendored** hook scripts in `.claude/hooks/` | |
| lint configs (`ruff.toml`, ESLint, `biome.json`) | |
| `.harness/reflections/` (ledger stays gitignored) | |

The single biggest decision is **hooks**: ship them per-machine (lighter, stays
in sync with upstream, but every dev must run `install.sh` and they fire in
*other* projects too) or **vendor them into the repo** (deterministic, zero
per-dev setup, no version drift - at the cost of a manual upstream bump). For a
team, prefer vendoring.

## Vendoring the hooks (the portable way)

> **Gotcha:** `install.sh --claude-dir ./.claude` looks like it would vendor the
> hooks, but it writes **absolute** command paths (`/Users/you/project/.claude/
> hooks/...`) for any non-default `--claude-dir`. Those break on every other
> teammate's checkout. Do not use it for vendoring.

Instead:

1. Copy the scripts in:
   ```bash
   mkdir -p .claude/hooks/lib
   cp <repo-path>/hooks/*.sh        .claude/hooks/
   cp <repo-path>/hooks/lib/*.sh    .claude/hooks/lib/
   cp <repo-path>/VERSION           .claude/hooks/.agent-starter-version
   chmod +x .claude/hooks/*.sh .claude/hooks/lib/*.sh
   ```
   Drop the read-guard pair (`track-reads.sh`, `require-read-before-edit.sh`)
   unless you want it - recent Claude Code enforces read-before-edit natively,
   and those two carry a `$HOME/.claude/session` dependency you don't want in a
   shared repo.
2. Wire `.claude/settings.json` with **`$CLAUDE_PROJECT_DIR`-relative** paths so
   they resolve on every checkout regardless of location. Same jq structure as
   `install.sh`, but `H='$CLAUDE_PROJECT_DIR/.claude/hooks'`:
   ```jsonc
   {
     "hooks": {
       "PostToolUse": [
         { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-file-size.sh",     "timeout": 5,  "statusMessage": "Checking file size..." }] },
         { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/lint-on-edit.sh",        "timeout": 30, "statusMessage": "Linting..." }] },
         { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-silent-errors.sh", "timeout": 5,  "statusMessage": "Checking error handling..." }] }
       ],
       "PreToolUse":  [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/block-dangerous-commands.sh", "timeout": 3, "statusMessage": "Checking command safety..." }] }],
       "SessionStart":[{ "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-codebase-health.sh .", "timeout": 15, "statusMessage": "Checking codebase health..." }] }],
       "UserPromptSubmit":[{ "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/suggest-loop-improvements.sh", "timeout": 10, "statusMessage": "Reviewing loop/goal instructions..." }] }]
     }
   }
   ```
3. The wired hooks are portable as-is - they read tool input from `$ARGUMENTS`
   and `lib/log-event.sh` finds the project root by walking up. (The `$HOME`
   references in `block-dangerous-commands.sh` are the intentional dangerous-`rm`
   detector, not a path dependency.) Smoke-test one before committing:
   ```bash
   ARGUMENTS='{"file_path":"<some-file-over-300-lines>"}' bash .claude/hooks/check-file-size.sh; echo "exit $?"   # expect exit 2
   ```

## .gitignore: share team config, keep personal state private

If `.claude/` is gitignored (common), you can't add files under it without an
exception. A blanket `.claude/` exclude also can't be selectively re-included.
Replace it with an ignore-contents-then-re-include block:

```gitignore
# Claude Code: ignore personal/local state, share team config
.claude/*
!.claude/hooks/
!.claude/rules/
!.claude/settings.json
```

This shares hooks/rules/settings while keeping `.claude/worktrees/` and
`.claude/settings.local.json` personal. Verify with `git check-ignore`.

## The ledger in a monorepo

`lib/log-event.sh` writes `.harness/ledger.jsonl` next to the **nearest**
`package.json` / `.claude` / `.git` marker walking up from the edited file. In a
monorepo that means ledgers land in **subtree** `.harness/` dirs (e.g.
`web/.harness/`, `api/.harness/`), not just the root. A root-anchored gitignore
rule (`.harness/ledger.jsonl`) misses them and they get committed by accident.
Use a pattern that matches every tree:

```gitignore
**/.harness/ledger.jsonl
```

Reflections (`**/.harness/reflections/`) stay committed - signal is private,
wisdom is shared.

## CLAUDE.md for a team

Follow ADOPT.md's append-only rule, with one change: **skip the Memory System
section.** agent-starter's memory system is built around a single dev's
`~/.claude` memory dir; that state never travels with a team repo, so
documenting it in a shared `CLAUDE.md` misleads the team. Append only **Git
Safety**, **Implementation Notes**, and **Self-improvement loop**. Add a short
**Agent tooling** pointer to your onboarding doc (below).

## Lint when you can't run it

ADOPT.md says run the linter and downgrade en-masse failures to `warn`. On a
team rollout you often **can't** run it - deps aren't installed in the adoption
environment, or there's no test suite to catch regressions. In that case add the
new rules as **`warn`, never `error`**, so they can't break the team's
`lint`/CI, and leave an explicit RATCHET note in the config: promote to `error`
once a developer with deps installed measures the real count. Defer type-aware
rules (which need project-service setup and a separate noise pass) entirely.

## Plugins (e.g. superpowers): default, don't "force"

A plugin **cannot be hard-required from a repo.** It installs into each dev's
`~/.claude`, gated by Claude Code's folder-trust prompt, and a committed
`enabledPlugins` entry for a plugin the dev hasn't installed is a **silent
no-op** - no warning, no auto-install. There's also no reliable signal a hook
could check to detect whether a plugin is active, and no commit-time trace, so
neither hooks nor CI can enforce it.

The strongest repo-level lever is **default-on + install prompt + docs**. Commit
to `.claude/settings.json`:

```jsonc
{
  "extraKnownMarketplaces": {
    "claude-plugins-official": { "source": { "source": "github", "repo": "anthropics/claude-plugins-official" } }
  },
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true
  }
}
```

`extraKnownMarketplaces` makes Claude Code **prompt teammates to install** the
marketplace+plugin when they trust the repo folder; `enabledPlugins` turns it on
once installed. True enforcement only exists via org-admin **managed settings**,
which is not a repo-level mechanism - so the actual "requirement" lives in your
onboarding doc.

## Write an onboarding doc

Vendoring means near-zero setup, but document the rest so a new teammate knows
what to expect. A `docs/agent-tooling-onboarding.md` (linked from `CLAUDE.md`)
should cover:

- **Prerequisites:** Claude Code; `jq` (the hooks shell out to it - without it
  they silently no-op); the plugin(s) you default on.
- **What runs automatically:** the hooks (and what each blocks/warns on), the
  apply-on-touch rules, the lint configs - all from `git pull`, no install.
- **The one manual step:** install the plugin (accept the marketplace prompt on
  folder-trust, or `claude plugin install <id>`), and how to verify it loaded.
- **The `/reflect` loop:** the ledger is gitignored; reflections are committed.

## Roll it out as a reviewed PR/MR

Vendored config changes how every teammate's agent behaves - that's a convention
change, so it should be **reviewed, not pushed to the default branch.** Put the
whole adoption on a branch (one commit per component, per ADOPT.md), open a
PR/MR, and let the team approve the conventions before they land.

## Verify (team addendum to ADOPT.md Step 5)

- [ ] Hook wiring uses `$CLAUDE_PROJECT_DIR`-relative paths, not `~/.claude` or
      absolute paths
- [ ] A vendored hook smoke-tested (e.g. file-size returns exit 2 on a big file)
- [ ] `.gitignore` shares `hooks`/`rules`/`settings.json`, keeps `worktrees` and
      `settings.local.json` private (checked with `git check-ignore`)
- [ ] Ledger ignored in **every** tree (`**/.harness/ledger.jsonl`), reflections
      still trackable
- [ ] Memory System section **not** added to a shared `CLAUDE.md`
- [ ] New lint rules are `warn` (with a ratchet note) if the linter couldn't be
      run during adoption
- [ ] Plugin defaults committed (`extraKnownMarketplaces` + `enabledPlugins`) and
      the install step is in the onboarding doc
- [ ] The whole thing is on a branch / PR for team review, not pushed to default
