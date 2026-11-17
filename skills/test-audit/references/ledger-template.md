# Lane ledger: <lane name>

Baseline SHA: `<sha>`. Production owners: `<paths>`.

## Summary

One paragraph: which contracts this lane protects and at which layers (pure
function, server, job, route, UI, e2e).

## Files

| File | Contract protected | Layer | Mark | Note |
|---|---|---|---|---|
| `src/feature/thing.test.ts` | <contract> | unit | R | <a few words> |

Mark is `R`, `F`, `C`, `D`, or `mixed` when tests in one file need different marks.

## Candidates

Non-R items only, one block each:

### <mark>: `<file>:<line>` "<test name>"

- **Detects:** the failure this test catches, or "nothing" and why.
- **Keeper (C/D):** `<file>:<line>` "<test name>", and why it is at least as strong.
- **Repair (F):** what is vacuous now and what the repaired assertion checks.
- **Seam:** the export it reaches, its non-test callers (expected none), and what
  deleting it unlocks.
- **History:** the commit or reason it exists.
- **Runs in:** the hook or CI stage that runs this test and its keeper.
- **Confidence:** high or medium.

## Baseline failures

Files that fail at the baseline SHA, with the failure. These are possible product
bugs, not deletion candidates.

## Cross-lane suspicions

Contracts that look re-proven in another lane, naming the other file when known.
