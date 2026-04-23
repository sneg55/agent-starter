# Zod at the Boundary

Validate external data the moment it enters your program. Never re-check inside. The schema is the source of truth for the type.

Zod is the convenient tool; the pattern is older (Pydantic, io-ts, ajv). Swap the library, keep the rule.

## The rule

Any data crossing into your program's type system passes through a Zod schema once. Inside the program, the inferred type is trusted.

Boundaries are:

- **User input** — CLI args, stdin, HTTP bodies, form submits.
- **Env vars** — `process.env.*`.
- **File reads** — config, cache, fixtures, anything from disk.
- **Network** — `fetch`, MCP responses, third-party APIs.
- **Database** — row reads, until the driver is schema-aware.
- **LLM output** — model responses parsed as JSON.
- **IPC** — subprocess stdout, worker messages.

Everything else is internal and already typed.

## One source of truth

Declare the schema; infer the type from it. Never both.

```ts
// Bad — two sources of truth, will desync.
interface Config {
  apiUrl: string
  timeout: number
}
const configSchema = z.object({
  apiUrl: z.string(),
  timeout: z.number(),
})

// Good — one source.
const configSchema = z.object({
  apiUrl: z.string().url(),
  timeout: z.number().int().positive(),
})
type Config = z.infer<typeof configSchema>
```

With `z.infer`, changing the schema is the *only* way to change the type. The compiler and the runtime stay synchronized.

## Config: the canonical example

```ts
// src/config/schema.ts
import { z } from 'zod'

export const configSchema = z.object({
  apiUrl: z.string().url(),
  timeout: z.number().int().positive().default(30_000),
  features: z.object({
    beta: z.boolean().default(false),
  }),
})

export type Config = z.infer<typeof configSchema>
```

```ts
// src/config/load.ts — the boundary
import { configSchema, type Config } from './schema'
import { ok, err, type Result } from '@/types/result'
import { AppError, ErrorIds } from '@/errors'

export function loadConfig(path: string): Result<Config> {
  const raw = JSON.parse(fs.readFileSync(path, 'utf8'))
  const parsed = configSchema.safeParse(raw)
  if (!parsed.success) {
    return err(
      new AppError(ErrorIds.CFG_SCHEMA_FAIL, 'config invalid', {
        path,
        issues: parsed.error.issues,
      }),
    )
  }
  return ok(parsed.data)
}
```

```ts
// src/features/some-feature.ts — inside, Config is trusted
import type { Config } from '@/config/schema'

export function runFeature(cfg: Config) {
  fetch(cfg.apiUrl, { signal })          // URL guaranteed by schema
  setTimeout(job, cfg.timeout)           // positive int guaranteed by schema
  if (cfg.features.beta) { /* ... */ }   // boolean guaranteed by schema
}
```

Nothing inside re-checks the shape. No `typeof`, no `if (cfg)`, no `??` fallbacks for fields the schema already defaulted.

## Env vars are a boundary too

Probably the most abused one. Don't sprinkle `process.env.X` across 40 files.

```ts
// src/env.ts — the single env boundary
import { z } from 'zod'

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  PORT: z.coerce.number().int().positive().default(3000),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  ANTHROPIC_API_KEY: z.string().min(1),
})

export const env = envSchema.parse(process.env) // throws at startup if invalid
export type Env = z.infer<typeof envSchema>
```

Paired with the existing ESLint rule `no-restricted-properties` (which already bans `process.env` deep in modules), the only way to read config is `import { env } from '@/env'`. The check runs once on import; everything else is a trusted field access.

Drop-in template: `templates/env.ts`.

## LLM output is a boundary

Models return JSON that "mostly" matches your schema. Parse it; never trust the shape.

```ts
const raw = JSON.parse(response.content)
const parsed = plannerSchema.safeParse(raw)
if (!parsed.success) {
  // Re-prompt with the specific Zod error, or fall back.
  return err(new AppError(ErrorIds.LLM_BAD_RESPONSE, 'planner shape invalid', {
    issues: parsed.error.issues,
  }))
}
use(parsed.data)
```

For tool-use / structured-output APIs, the model's schema adherence is near-perfect — but "near-perfect" is the exact failure mode you need to catch.

## Network responses

```ts
// src/integrations/github.ts
const repoSchema = z.object({
  full_name: z.string(),
  default_branch: z.string(),
  stargazers_count: z.number().int(),
})
type Repo = z.infer<typeof repoSchema>

export async function getRepo(owner: string, name: string): Promise<Result<Repo>> {
  const res = await fetch(`https://api.github.com/repos/${owner}/${name}`, { signal })
  const parsed = repoSchema.safeParse(await res.json())
  if (!parsed.success) {
    return err(new AppError(ErrorIds.NET_BAD_SHAPE, 'unexpected github response', {
      issues: parsed.error.issues,
    }))
  }
  return ok(parsed.data)
}
```

Downstream callers take `Repo`, not `unknown`. If GitHub adds a field, the schema ignores it. If GitHub removes one, every call site surfaces the error instead of a silent `undefined`.

## Patterns worth using

**`safeParse` at boundaries, `parse` at startup.** `safeParse` returns `Result`-like data; `parse` throws. Startup-time validation (env, loaded-once config) is fine to throw — if the env is bad, the app can't run. Runtime-receiving validation (HTTP body, file read, LLM reply) uses `safeParse` so one bad request doesn't crash the process.

**`.default()` inside the schema, not in consumer code.** Defaults are part of the shape. Put them in the schema so every caller gets the same default and the type reflects it.

**`.transform` to normalize.** Parsing an ISO date string to a `Date`, coercing `"1"/"0"` to boolean — do it in the schema, not per call site.

**Branded types for validated primitives.**

```ts
const emailSchema = z.string().email().brand<'Email'>()
type Email = z.infer<typeof emailSchema>   // string & { __brand: 'Email' }
```

Now a function that takes `Email` can only receive a parsed one. Raw strings fail at compile time. Useful for IDs, email, URL, anywhere a string-typed hole has caused bugs.

**Schemas live in `src/schemas/`.** The large-codebase guide already recommends this. A discoverable schema directory means when an agent is asked "what does the config look like?" there's one obvious file to read.

## What to skip

- **Internal types.** If data is constructed inside your program and never touches a boundary, don't wrap it in Zod. Schemas for `type UserRow = ...` that only exists in-memory is noise.
- **Hot paths.** Parse once at ingress, pass the trusted value. Don't re-parse in a loop. If a hot path needs validation, do a cheaper structural check and document why.
- **Test fixtures.** In tests, raw objects cast to the inferred type are fine. The whole test suite is inside the trust boundary.

## What this buys an agent

- **One file to read** to answer "what's the shape of X?" — the schema.
- **Failures happen at the edge** with the exact field and reason, not as `undefined is not a function` ten stack frames deep.
- **No defensive `typeof` checks inside** — LLMs routinely add them; Zod-at-the-boundary makes them obviously unnecessary, so the agent stops writing them.
- **Schema changes propagate as compile errors.** Add a field: the compiler lists every site that needs it. Remove one: same.
- **No type-lies.** `JSON.parse(x) as Config` compiles and lies; `configSchema.parse(x)` either succeeds honestly or fails loudly.

## Cross-references

- `guides/discriminated-union-results.md` — `safeParse` pairs naturally with `Result<T, AppError>`.
- `guides/error-id-registry.md` — schema failures throw with a stable `E_CFG_SCHEMA_FAIL` / `E_LLM_BAD_RESPONSE` ID.
- `guides/large-codebase-best-practices.md` §9 — env validation is the same pattern in miniature; this guide generalizes it.
