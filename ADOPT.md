# Applying agent-starter to an Existing Project

`AGENT.md` scaffolds **new** projects. This file is the entry point for
retrofitting an **existing** codebase. Follow it when the developer says
"apply this repo to my project".

The difference that drives everything below: an existing project has state to
audit, every change is potentially destructive, and adoption must be
incremental. So the flow is **audit-first, merge-don't-overwrite, opt-in per
component**.

## Safety rails (read first)

- Create a branch before any write: `git checkout -b adopt/agent-starter`.
  Everything below is reversible by dropping the branch.
- Read every file before modifying it. Append and merge; never replace a file
  the developer wrote.
- After each merge-tier step, run the project's own test suite (and linter, if
  present). A red suite means stop and surface it.
- If the project has no tests, say so explicitly and default to the
  non-invasive tier only.
- Surface contradictions between starter patterns and existing conventions;
  never resolve them silently.

## Step 1: Interview

Ask one at a time:

1. **Components** - which are you interested in? (hooks / skills / CLAUDE.md +
   memory / lint configs / code patterns / "audit first, then decide")
2. **Repo path** - local path to agent-starter (only needed if files will be
   copied).

## Step 2: Audit (read-only)

Build a gap report before proposing anything.

**Detect the stack:**

- `package.json` + `tsconfig.json` → TypeScript/JavaScript
- `pyproject.toml` / `setup.py` / `requirements.txt` → Python
- Both → monorepo: audit each half separately
- Neither → other stack; only Tier 1 and CLAUDE.md apply

**Inventory** (present as a table: component | what exists | starter offering | conflicts):

- **Lint/format:** ESLint configs (flat or legacy), `biome.json`, Prettier;
  ruff (`ruff.toml` or `[tool.ruff]` in pyproject), mypy/pyright configs
- **Instructions:** `CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/`, `AGENTS.md`
- **Hooks:** `.claude/settings.json` hook entries; agent-starter hooks already
  installed (`~/.claude/hooks/.agent-starter-version`)
- **Tests:** `package.json` `scripts.test`, pytest/tox config, Makefile targets
- **File-size health:** run `bash <repo-path>/hooks/check-codebase-health.sh`
  from the project root, or
  `find src -name '*.ts' -o -name '*.py' | xargs wc -l | sort -rn | head -20`
- **Patterns already present:** central error registry? env boundary? Result
  types? (grep for scattered `process.env` / `os.environ`, raw
  `throw new Error` / `raise Exception`)

## Step 3: Propose

Present the menu grouped by invasiveness, with per-item conflict notes from
the audit. Wait for explicit approval per item (or "all of tier N"). Nothing
is applied unapproved.

### Tier 1 - Non-invasive (no project-file conflicts possible)

- **Hooks:** `bash <repo-path>/install.sh` - idempotent; installs to
  `~/.claude/hooks/` and merges the settings.json wiring with jq. Note for the
  developer: hooks are **user-global** - they will also fire in their other
  projects.
- **Skills:** copy from `<repo-path>/skills/` to `~/.claude/skills/` (see
  AGENT.md step 6 for the list).
- **Self-improvement ledger:**
  `mkdir -p .harness/reflections && echo '.harness/ledger.jsonl' >> .gitignore`
  - the hooks log to it automatically; `/reflect` reads it.

### Tier 2 - Additive (append, never replace)

- **No CLAUDE.md** → copy `templates/CLAUDE.md`, fill in project name and
  description.
- **CLAUDE.md exists** → append only the sections it lacks: Memory System,
  Git Safety, Implementation Notes, Self-improvement loop. Read the existing
  file first; if its instructions contradict a starter section, list the
  contradictions and let the developer choose. The diff must show additions
  only.
- **`.claude/rules/starter-patterns.md`** → the apply-on-touch file (Tier 4).

### Tier 3 - Merge-required (developer approval per file)

**TypeScript:**

- **No linter** → copy `templates/biome.json` + `templates/eslint.config.mjs`,
  install deps (AGENT.md step 4), run on the codebase, and report the damage.
  Where existing code fails a rule en masse, downgrade that rule to `warn`
  with a ratchet note instead of fixing hundreds of violations in the
  adoption branch.
- **Existing ESLint** → offer two paths: (a) cherry-pick the Tier 1
  correctness rules from `guides/lint-rules-for-ai.md` into their config, or
  (b) migrate to the starter flat config, carrying their custom rules over.
- **Prettier present** → don't add Biome's formatter (two formatters fight);
  adopt the ESLint half only.

**Python:**

- **No ruff config** → copy `templates/ruff.toml` +
  `templates/pyrightconfig.json`, run `ruff check`, report counts per rule
  family, and downgrade noisy families per-project rather than mass-fixing.
- **`[tool.ruff]` in pyproject.toml** → merge the starter's `select`/`ignore`
  lists into pyproject. Do **not** drop a standalone `ruff.toml` next to it -
  ruff.toml silently takes precedence and their existing config stops
  applying.
- **mypy in use** → don't add pyright without asking; two type checkers
  disagree with each other more than they catch for each other.

**Foundation templates (both stacks):** copy only where the pattern is absent
- env boundary (`env.ts` / `env.py`), error registry (`errorIds.ts` /
`error_ids.py`), truncator (`truncate-for-context.ts` /
`truncate_for_context.py`). Adapt import paths to the project's layout. Skip
any the project already has an equivalent for.

### Tier 4 - Gradual-only (never a bulk refactor)

Write `.claude/rules/starter-patterns.md` with apply-on-touch guidance:

```markdown
# Starter patterns - apply on touch

Apply these when already editing the relevant code. Never as a bulk refactor.

- Editing a file over 300 lines → split per the file-size hook's suggestions
  (types / constants / validation / utils).
- Touching a `throw` / `raise` site → route it through the error registry
  (`guides/error-id-registry.md`).
- Changing a fallible function's signature → consider returning a Result
  (`guides/discriminated-union-results.md`).
- Touching an env read → move it behind the env boundary
  (`guides/zod-at-the-boundary.md`).
- Adding a long-running operation → thread cancellation through it
  (`guides/abort-signal-threading.md`).
- Adding a new tool → use the directory-per-tool layout
  (`guides/tool-authoring-pattern.md`).
```

Explicitly out of scope: restructuring directories, rewriting existing error
handling, or converting APIs wholesale. The starter's layout is a target for
new code, not a migration mandate.

## Step 4: Apply

Execute the approved items tier by tier, in tier order. After each Tier 3
item, run the project's lint and tests; stop on red. One commit per component,
so the developer can drop any single adoption from the branch.

## Step 5: Verify

Confirm each item before reporting done:

- [ ] All changes on the adoption branch; default branch untouched
- [ ] Gap report presented; every applied item was explicitly approved
- [ ] Existing CLAUDE.md content preserved (diff shows additions only)
- [ ] Project tests + lint pass (or were already red and are unchanged)
- [ ] `.harness/ledger.jsonl` gitignored, if the loop was adopted
- [ ] Contradictions surfaced and the developer's choices recorded
      (in CLAUDE.md or the implementation notes)

## Rolling out to a team

The steps above install into **one developer's `~/.claude`**. To make the whole
team get the same setup from a `git pull` - vendoring hooks into the repo with
portable wiring, sharing `.claude/` config via `.gitignore`, handling the ledger
in a monorepo, and defaulting plugins - see [`TEAM.md`](TEAM.md).
