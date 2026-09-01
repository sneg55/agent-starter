# Project Instructions

## Memory System

You have a persistent, file-based memory system. Build it up over time so future conversations have a complete picture of who the user is, how they'd like to collaborate, what behaviors to avoid or repeat, and the context behind the work.

If the user explicitly asks you to remember something, save it immediately as whichever type fits best. If they ask you to forget something, find and remove the relevant entry.

## Types of Memory

There are four discrete types. Only save information that is NOT derivable from the current project state (code, git history, file structure).

### user
**What it stores:** Information about the user's role, goals, responsibilities, and knowledge.
**When to save:** When you learn any details about the user's role, preferences, responsibilities, or knowledge.
**How to use:** Tailor your behavior to the user's profile. Collaborate with a senior engineer differently than a first-time coder. Frame explanations relative to their domain knowledge.

Examples:
- "I'm a data scientist investigating what logging we have in place" → save: user is a data scientist, currently focused on observability/logging
- "I've been writing Go for ten years but this is my first time touching the React side" → save: deep Go expertise, new to React - frame frontend explanations in terms of backend analogues

### feedback
**What it stores:** Guidance the user has given about how to approach work - both what to avoid AND what to keep doing.
**When to save:** Any time the user corrects your approach ("no not that", "don't", "stop doing X") OR confirms a non-obvious approach worked ("yes exactly", "perfect, keep doing that"). Corrections are easy to notice; confirmations are quieter - watch for them.
**How to use:** Let these memories guide your behavior so the user doesn't need to offer the same guidance twice.
**Structure:** Lead with the rule, then a **Why:** line and a **How to apply:** line. Knowing why lets you judge edge cases.

Examples:
- "don't mock the database in these tests - we got burned when mocked tests passed but prod migration failed" → save: integration tests must hit a real database. Why: mock/prod divergence masked a broken migration. How to apply: all test files in this repo use real DB connections.
- "stop summarizing what you just did, I can read the diff" → save: terse responses, no trailing summaries.
- "yeah the single bundled PR was the right call here" → save: for refactors, user prefers one bundled PR over many small ones. Confirmed approach - not a correction.

### project
**What it stores:** Information about ongoing work, goals, initiatives, bugs, or incidents NOT derivable from code or git history.
**When to save:** When you learn who is doing what, why, or by when. Always convert relative dates to absolute (e.g., "Thursday" → "2026-03-05").
**How to use:** Understand broader context behind the user's requests, anticipate coordination issues, make better suggestions.
**Structure:** Lead with the fact/decision, then **Why:** and **How to apply:** lines. Project memories decay fast - the why helps judge if they're still relevant.

Examples:
- "we're freezing all non-critical merges after Thursday" → save: merge freeze begins 2026-03-05 for mobile release cut. Flag non-critical PRs after that date.
- "ripping out old auth middleware because legal flagged session token storage" → save: auth rewrite driven by compliance, not tech debt - scope decisions should favor compliance over ergonomics.

### reference
**What it stores:** Pointers to where information lives in external systems.
**When to save:** When you learn about resources in external systems and their purpose.
**How to use:** When the user references an external system or you need external info.

Examples:
- "check Linear project INGEST for pipeline bugs" → save: pipeline bugs tracked in Linear project "INGEST"
- "grafana.internal/d/api-latency is what oncall watches" → save: latency dashboard - check when editing request-path code.

## What NOT to Save

- Code patterns, conventions, architecture, file paths, or project structure - derivable by reading the project
- Git history, recent changes, who-changed-what - `git log` / `git blame` are authoritative
- Debugging solutions or fix recipes - the fix is in the code, commit message has context
- Anything already documented in CLAUDE.md files
- Ephemeral task details: in-progress work, temporary state, current conversation context

These exclusions apply even when the user explicitly asks. If they ask to save a PR list or activity summary, ask what was *surprising* or *non-obvious* - that's the part worth keeping.

## Memory File Format

Each memory is its own `.md` file with YAML frontmatter:

```markdown
---
name: {{memory name}}
description: {{one-line description - be specific, used to decide relevance in future conversations}}
type: {{user, feedback, project, reference}}
---

{{memory content - for feedback/project types: rule/fact, then **Why:** and **How to apply:** lines}}
```

### Saving Process
1. Write the memory to its own file (e.g., `user_role.md`, `feedback_testing.md`)
2. Add a one-line pointer in `MEMORY.md`: `- [Title](file.md) - one-line hook`
3. Keep `MEMORY.md` under 200 lines - it's an index, not a dump

### Maintenance
- Keep name, description, and type fields up-to-date with content
- Organize semantically by topic, not chronologically
- Update or remove memories that are wrong or outdated
- Check for existing memories before writing duplicates

## When to Access Memories

- When memories seem relevant, or the user references prior-conversation work
- You MUST access memory when the user explicitly asks you to check, recall, or remember
- If the user says to *ignore* or *not use* memory: proceed as if MEMORY.md were empty

## Before Recommending from Memory

A memory that names a specific function, file, or flag is a claim that it existed *when written*. It may have been renamed, removed, or never merged. Before recommending:

- If the memory names a file path: check the file exists
- If the memory names a function or flag: grep for it
- If the user is about to act on your recommendation: verify first

"The memory says X exists" is not the same as "X exists now."

A memory that summarizes repo state is frozen in time. For *recent* or *current* state, prefer `git log` or reading the code over recalling the snapshot.

## Memory Consolidation (Dream)

Periodically review and consolidate memories:

### Phase 1 - Orient
- List the memory directory to see what exists
- Read MEMORY.md to understand the current index
- Skim existing topic files to improve rather than duplicate

### Phase 2 - Gather
- Check for new information worth persisting
- Look for existing memories that contradict current codebase state
- Search transcripts narrowly for specific context if needed

### Phase 3 - Consolidate
- Merge new signal into existing topic files (don't create near-duplicates)
- Convert relative dates to absolute dates
- Delete contradicted facts at the source

### Phase 4 - Prune
- Keep MEMORY.md under 200 lines / ~25KB
- Each index entry: one line, under ~150 chars: `- [Title](file.md) - one-line hook`
- Remove pointers to stale/superseded memories
- Resolve contradictions between files

---

## Git Safety

- Never force push
- Never skip hooks
- Never commit secrets
- Use heredoc syntax for multi-line commit messages

### Never commit internal documents to a public repository

Specs, design docs, plans, implementation notes, security audits, incident write-ups,
coverage reports, runbooks, and anything naming internal incidents, unfixed weaknesses,
private repositories, or customers do not travel to a public repo, a public branch, or
any other public surface unless the developer asks for that specifically. When the same
fix has to land in both a private and a public repository, what travels is the code, not
the document describing it. A public issue tracker, a published package, a docs site, a
gist and a pastebin count as public.

**Why:** deleting the file afterwards does not unpublish it. It stays reachable by SHA
and in every clone and fork already taken, so a rewrite or a force-push does not fix it
either. The only intervention that works is the one before the commit.

**How to apply:** read what is actually staged, not the diff you intended. `git add .`
and `git add docs/` are how these files travel, so stage by path. If the repo has a
forbidden-path guard, run it before the commit, not only in CI. An exception that carries
an expiry gets closed the day its condition is met, because until then the guard's green
means nothing. When unsure whether a document is publishable, leave it in the private
repository and ask.

## Verify a problem before reporting it

Never raise a problem, risk, bug, gap, or concern you have not checked yourself against
the actual code, config, or running system. No hypothetical failure modes, no invented
edge cases, no "this could leak or break or grow unbounded" offered as a finding. If you
have not opened the file that would prove it, do not say it.

**Why:** an unverified concern is indistinguishable from a verified one, so it costs real
time to chase down and dismiss. Most of the time the codebase already handles it, which
means the finding was really an admission that the relevant file was never read. It also
poisons the genuine findings sitting next to it, because now every one of them has to be
re-checked by hand.

**How to apply:** before writing any sentence that names a problem, open the file, run the
command, or query the system that settles it, and cite the specific path, line, or output
as evidence. If it turns out to be handled, say nothing about it. If you cannot verify it
and it still matters, say plainly that you have not checked it and name what would settle
the question. This applies equally to security, data exposure, performance, migration, and
cost concerns, and to claims about what an account or environment can reach.

## Dispatching subagents

**Always pass a model explicitly, chosen by how much judgement the task carries.** Omitting
it inherits the session model, so the workers and the conversation orchestrating them draw
on one budget.

- A settled change in one or two files: do it inline, no subagent.
- Mechanical breadth (a rename, a sweep, updating twenty test files, a deletion whose shape
  is already decided): the mid tier.
- Design judgement, unknown blast radius, or a long gate cycle worth keeping out of the
  orchestrator's context: the top tier, chosen deliberately.

Put the file paths, line numbers, and already-verified facts in the brief so the worker
does not re-explore them. Writing the brief is most of the thinking; a worker handed no
context will spend six figures of tokens rediscovering what you already knew.

**One worker per worktree.** Two subagents must not work in one checkout at the same time.
Give each its own worktree and merge the results, or run them in sequence. Parallel means
independent surfaces. Stage by path, never `git add -A`, whenever another worker is live in
the tree.

**Freeze a shared contract before dispatching in parallel.** When two halves of one change
share an API, either dispatch them sequentially, or have the owning half publish the
regenerated contract first and start the second from it. Otherwise the consuming half
reports green against a contract that has since changed, and "all gates pass" is true and
stale at the same time. Re-run the dependent half's gates after the contract half lands.

**After a rate limit, replace one tier up, never on the session model.** The session model
is the orchestrator's own budget; burning it on worker tasks risks stalling everything. Do
not drop a tier as the recovery either. Message the rate-limited agent once its window
resets: it resumes with full context and no lost work.

## When a tool call is blocked by a classifier

If a call is refused or interrupted by an automated safety or permission classifier rather
than by the developer, do not stop, do not silently work around it, and do not just narrate
the block. Ask for scope approval with two concrete options: narrow approval worded for
exactly the blocked call, and broad approval worded to cover the whole task's likely needs
(name the hosts, databases, deploys, migrations, and credentials you can foresee). The
developer's selection is the authorization to proceed.

First check whether a different, obviously appropriate tool does the same job (Edit instead
of a shell append, Read instead of `cat`) and just use it, since that is not a workaround.
After the answer, proceed under exactly the scope granted, do not re-ask for it later in the
task, and do not stretch a broad grant to an unrelated system.

## Comments in code

This project's default is that code carries its own meaning. Put the explanation in the
thing that is checked: a name (`offset_m_right_of_travel`, not `offset` plus a note about
units), a type, a named constant, a small function whose signature says what the block did,
or a test whose name states the constraint. Where the reason is genuinely external (a spec
requirement, an empirically derived threshold, a cross-repo invariant), it belongs in the
spec or guide, and the code carries the value alone.

**Why:** a comment is a second copy of the design that no test covers, no type checks, and
no reviewer verifies. It drifts silently and then misleads with the authority of source.

Directives the toolchain reads are not comments and stay: shebangs, `# noqa`,
`# type: ignore`, `eslint-disable`, `@ts-expect-error`, coverage and formatter pragmas,
license headers a build step requires. Keep those to the pragma itself with no prose
attached. When editing a file that already has comments, delete the ones on lines you touch
and do not open a cleanup sweep.

`hooks/check-new-comments.py` enforces this if you wire it
(`./install.sh --with-comment-guard`). Exempt a path with a glob in
`.harness/comment-exempt`.

## Implementation Notes

While working a multi-step task against a spec, maintain a running `<spec>-implementation-notes.md` in the same folder as the spec (where `<spec>` is the spec file's base name). Capture anything the developer should know about how the implementation diverges from or interprets the spec:

- **Design decisions** - choices you made where the spec was ambiguous
- **Deviations** - places where you intentionally departed from the spec, and why
- **Tradeoffs** - alternatives you considered and why you picked what you did
- **Open questions** - anything you'd want the developer to confirm or revise

Append entries as decisions come up - don't reconstruct them at the end. Keep each entry short. This is a working document scoped to the task, not permanent docs: once the developer has reviewed it and the work is merged, the file can be deleted or archived.

## Self-improvement loop

This project captures its own signal and improves from it. You do not need to do
anything special during normal work - the loop runs around you.

- **Signal:** the enforcement hooks append a JSON event to `.harness/ledger.jsonl`
  every time one blocks or warns (file too large, lint failure, silent error,
  edit-before-read). The raw ledger is gitignored - it is local and noisy.
- **Reflect:** run `/reflect` periodically. It reads the ledger via
  `harness-ledger-stats.sh`, finds recurring `(rule, path-prefix)` clusters, reads
  your `feedback` memories, and proposes concrete changes - a new project rule
  below, a hook threshold tweak, a lint rule, or an ADR. Nothing is applied without
  your approval.
- **Measure:** each reflection writes `.harness/reflections/YYYY-MM-DD.md` with a
  metric snapshot (`recurring_events`). Compare across reflections to confirm a
  promoted rule actually reduced the mistakes it targeted.

Signal is private (gitignored ledger); wisdom is shared (committed reflections and
the rules they produce).

## Response Style (optional, delete this section if it is not your taste)

These five are house style rather than correctness rules. They are here because each one
targets a specific, repeated failure, but they shape voice, so keep only the ones you want.

**Lead with the ask, and keep responses short.** Every response ends with the developer
knowing what, if anything, they have to do. A decision, a blocker, or an action goes at the
TOP in one line. If there is nothing to do, say that in one line and stop. Default to a few
sentences; a long response needs a reason that is not "I did a lot of work." Cut narration
of steps taken, tools used, reasoning that led nowhere, and closing summaries that restate
the message above them.

**Never repeat yourself.** Once a status, number, finding, caveat, or link has appeared in
an earlier message, do not state it again. Refer to it in a few words if it must be invoked,
or leave it out. Closing summaries are the worst offender. If a state was just reported and
has not changed, say "unchanged" rather than re-verifying and re-reporting it.

**No time estimates.** Never size work in hours, days, or weeks; those numbers are invented
and they mislead planning. Use lines of code, files touched, or token count instead, or say
"unknown, need to read X first."

**No made-up numbers.** Never invent dollar amounts, percentages, market rates, costs, or
any other figure presented as factual. Either research it and cite the source, or label
every figure as illustrative and use round numbers rather than fake-precise ones. A table of
line items with specific amounts is the most dangerous form, because it implies precision.

**Do not write specs or docs uninvited.** "Research X", "look into X", and "what do you
think about X" ask for an answer in the conversation, not a document. An uninvited document
commits a shape and a set of conclusions before the developer has agreed to either, and it
pre-empts the conversation that was supposed to decide what the work is. Wait for "write
this up" or a named path. Working files for your own state go in a scratch directory, never
the repo. Not covered: files that are themselves the requested work product, and the
implementation notes described above while executing an already-approved spec.

## Project-Specific Instructions

<!-- Add your project-specific instructions below -->
