# AbortSignal Threading

Every long-running operation must accept an `AbortSignal` and propagate it to everything it calls. No exceptions.

## Why

LLMs ship code like this:

```ts
// Bad — nothing responds to cancel.
export async function fetchAndProcess(url: string) {
  const res = await fetch(url)                  // not abortable
  const body = await res.text()                 // not abortable
  return expensiveParse(body)                   // not abortable
}
```

When the user hits Ctrl+C, or an outer timeout fires, or the job is obsoleted by a newer request — none of these calls stop. The process keeps burning CPU and the result gets thrown away. Worse: the *next* job starts while the previous one is still running, corrupting shared state.

The fix isn't complicated, but agents routinely skip it because "it works" without the signal. The patterns below make it cheap enough that skipping it is never worth it.

## The contract

Any function that does I/O, waits, or takes more than ~100ms accepts `signal: AbortSignal` as a named field in its options:

```ts
export async function fetchAndProcess(
  url: string,
  opts: { signal: AbortSignal },
): Promise<Result> {
  const res = await fetch(url, { signal: opts.signal })
  opts.signal.throwIfAborted()
  const body = await res.text()
  opts.signal.throwIfAborted()
  return expensiveParse(body, opts)
}
```

Two rules:

1. **Pass `signal` to every callee that accepts one** (`fetch`, `setTimeout` via `AbortSignal.timeout`, child DB/HTTP clients, other internal functions).
2. **Call `signal.throwIfAborted()` after any await that isn't signal-aware**, or before starting heavy synchronous work.

## The entry point

At the top of the stack, create the signal and wire it up:

```ts
export async function runJob(req: Request): Promise<Result> {
  const ac = new AbortController()
  req.signal?.addEventListener('abort', () => ac.abort(req.signal!.reason))

  const timeout = setTimeout(() => ac.abort(new Error('E_TOOL_003 timeout')), 30_000)
  try {
    return await fetchAndProcess(req.url, { signal: ac.signal })
  } finally {
    clearTimeout(timeout)
  }
}
```

For tools invoked by the agent, the framework should pass a signal in `ctx.signal` — tool implementations never create their own.

## Composing timeouts

`AbortSignal.any([a, b])` merges multiple signals into one. Use this for per-call timeouts under an outer cancel:

```ts
const perCall = AbortSignal.timeout(5_000)
const merged = AbortSignal.any([opts.signal, perCall])
await fetch(url, { signal: merged })
```

## Cleanup on abort

Anything that holds a resource (file handle, subprocess, DB tx) must release it when the signal fires:

```ts
const child = spawn('rg', args)
opts.signal.addEventListener('abort', () => child.kill('SIGTERM'), { once: true })
```

Forgetting this is the single most common cancellation bug. The process "aborts" but the subprocess keeps running.

## What *not* to do

- **Don't swallow `AbortError`.** If a `catch` doesn't re-check the signal, aborts get papered over:
  ```ts
  // Bad
  try { await fetch(url, { signal }) } catch { return null }
  // Good
  try { await fetch(url, { signal }) } catch (e) {
    if (signal.aborted) throw e
    return null
  }
  ```
- **Don't default `signal` to `undefined`.** Require it. A function that "might" accept a signal won't get one.
- **Don't poll.** No `while (!signal.aborted) { ... await tick() }` — use `signal.addEventListener('abort', ...)` or `throwIfAborted()`.

## Enforcement

Post-edit lint + a custom rule catches most misses:

- `@typescript-eslint/no-floating-promises` (already in the config) catches unawaited promises, which are a common cancel-leak.
- A project-specific rule can flag `fetch(` calls that don't pass `signal`:

  ```js
  'no-restricted-syntax': [
    'error',
    {
      selector: "CallExpression[callee.name='fetch'] > ObjectExpression:not(:has(Property[key.name='signal']))",
      message: 'fetch() must receive { signal } — see guides/abort-signal-threading.md.',
    },
  ],
  ```

- Grep hook: block any new `setTimeout(` that doesn't have a matching `clearTimeout` in the same file *unless* an `AbortSignal.timeout` is used instead.

## What this buys an agent

- Ctrl+C actually cancels. Timeouts actually fire. Obsoleted work actually stops.
- The function signature documents cancellability. An agent reading `fn(url)` knows it's *not* cancellable; `fn(url, { signal })` knows it is.
- No wedged subprocesses or zombie fetches accumulating between runs.
