# Discriminated-Union Tool Results

Every function that can fail returns a `Result` — a discriminated union — instead of throwing. Callers `switch` on the discriminant. The compiler enforces exhaustiveness.

## Why

LLMs invent ad-hoc result shapes every time. Three edits in, one tool returns `{ success: true, data }`, another returns `{ok: 1, result}`, a third throws on failure and returns the raw value on success. Callers can't reason about any of them. Aggregators (e.g. "run these five tools in parallel") become a mess of try/catch + shape-sniffing.

Fixing the shape *once*, at the edge of the codebase, removes this class of drift.

## The shape

```ts
// src/types/result.ts
export type Result<Ok, Err = AppError> =
  | { ok: true; value: Ok }
  | { ok: false; error: Err }

export const ok = <T>(value: T): Result<T, never> => ({ ok: true, value })
export const err = <E>(error: E): Result<never, E> => ({ ok: false, error })
```

Usage:

```ts
import { ok, err, type Result } from '@/types/result'
import { AppError, ErrorIds } from '@/errors'

export async function readConfig(path: string): Promise<Result<Config>> {
  try {
    const raw = await fs.readFile(path, 'utf8')
    const parsed = configSchema.safeParse(JSON.parse(raw))
    if (!parsed.success) {
      return err(new AppError(ErrorIds.CFG_SCHEMA_FAIL, 'invalid config', { issues: parsed.error.issues }))
    }
    return ok(parsed.data)
  } catch (e) {
    return err(new AppError(ErrorIds.CFG_INVALID_JSON, 'config read failed', { path, cause: String(e) }))
  }
}
```

Caller:

```ts
const r = await readConfig(path)
if (!r.ok) {
  log.error(r.error.toLogLine())
  return r                           // propagate the same shape outward
}
use(r.value)
```

## Why not throw

- **Throws aren't in the signature.** `readConfig(p): Promise<Config>` lies about its failure modes. `Result<Config>` doesn't.
- **Throws break parallelism.** `Promise.all([a(), b(), c()])` rejects on the first throw and abandons the other results. `Promise.all([a(), b(), c()])` with `Result`s returns every outcome — the aggregator decides policy.
- **Agents skip `try/catch`.** LLMs reliably forget to wrap a call that can throw. They don't forget to check `r.ok` because the compiler makes them.

Reserve throws for **programmer errors** (invariant violations, unreachable branches). Operational failures — bad input, missing file, network timeout — always return `Result`.

## Discriminant is always `ok: true | false`

Don't get clever. Don't use `status: 'success' | 'error' | 'pending'`. Don't use tagged strings. `ok: boolean` is the one shape the whole codebase shares, and narrowing with `if (r.ok)` works without imports.

If a function has more than two outcomes (e.g. "found", "not found", "error"), widen the error side:

```ts
type ReadError =
  | { kind: 'not_found' }
  | { kind: 'permission' }
  | { kind: 'io'; cause: unknown }

type ReadResult = Result<Buffer, ReadError>
```

The outer discriminant stays `ok`; the inner `kind` discriminates failure modes. Callers that only care about success/failure write `if (!r.ok) return r`. Callers that care about the mode `switch (r.error.kind)`.

## Exhaustiveness

Pair with `@typescript-eslint/switch-exhaustiveness-check` (already in the config). Add an `assertNever` helper for the default branch:

```ts
export function assertNever(x: never): never {
  throw new Error(`unhandled variant: ${JSON.stringify(x)}`)
}

switch (r.error.kind) {
  case 'not_found':  return retry()
  case 'permission': return abort(r.error)
  case 'io':         return log(r.error)
  default: return assertNever(r.error)
}
```

Adding a fourth variant makes the switch a compile error at every call site. That's the feature.

## Helpers worth having

```ts
// Short-circuit: return on the first err, accumulate values.
export function collect<T, E>(results: Result<T, E>[]): Result<T[], E> {
  const values: T[] = []
  for (const r of results) {
    if (!r.ok) return r
    values.push(r.value)
  }
  return ok(values)
}

// Map over the ok side without unwrapping.
export function mapOk<A, B, E>(r: Result<A, E>, f: (a: A) => B): Result<B, E> {
  return r.ok ? ok(f(r.value)) : r
}
```

Don't add a library. These three are enough.

## Lint support

Already enabled in `templates/eslint.config.mjs`:

- `@typescript-eslint/switch-exhaustiveness-check` — catches missed variants.
- `@typescript-eslint/only-throw-error` — no throwing strings/objects.
- `@typescript-eslint/no-unnecessary-condition` — catches `if (r.ok === true)`–style redundancy.

Project-specific, worth adding:

```js
// Disallow bare `throw` inside async functions that look like operations
// rather than invariant checks. Heuristic — tune per codebase.
'no-restricted-syntax': [
  'error',
  {
    selector: "FunctionDeclaration[async=true] ThrowStatement",
    message: 'Return Result instead of throwing. Reserve throws for programmer errors.',
  },
],
```

Turn this off in `src/invariants/**` if you have one.

## Cross-references

- `guides/error-id-registry.md` — the `Err` half of `Result<Ok, Err>` should be `AppError` with an `ErrorId`.
- `guides/tool-authoring-pattern.md` — every tool handler returns `Result`.
