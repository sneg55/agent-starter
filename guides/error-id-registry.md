# Error ID Registry

Every thrown error gets a stable ID. One central file (`src/constants/errorIds.ts`) is the registry. Logs, telemetry, docs, and agents all reference the same ID.

## Why

LLMs write error messages that drift across edits. "Failed to parse config" becomes "Config parse error" becomes "Unable to read config" — three log lines for one bug. Grep stops working. Alerts stop firing.

A stable ID (`E_CFG_001`) fixes this:
- **Grep** works: `rg 'E_CFG_001'` finds every throw site, every log line, every test that asserts the error.
- **Agents can reference errors by ID** when asked "why did X fail?" — they look up the ID, not a fuzzy string match.
- **Docs point to IDs.** `See docs/errors.md#E_CFG_001` survives message rewording.
- **Dedup in telemetry.** One alert rule per ID, not one per phrasing.

## The registry

```ts
// src/constants/errorIds.ts
// Every error ID declared in one place. Never reuse a retired ID.
// Format: E_<DOMAIN>_<NUMBER>. Domain is 3–5 letters.

export const ErrorIds = {
  // Config (CFG)
  CFG_MISSING:       'E_CFG_001',
  CFG_INVALID_JSON:  'E_CFG_002',
  CFG_SCHEMA_FAIL:   'E_CFG_003',

  // Filesystem (FS)
  FS_NOT_FOUND:      'E_FS_001',
  FS_PERMISSION:     'E_FS_002',
  FS_DISK_FULL:      'E_FS_003',

  // Network (NET)
  NET_TIMEOUT:       'E_NET_001',
  NET_DNS:           'E_NET_002',
  NET_TLS:           'E_NET_003',

  // Tool execution (TOOL)
  TOOL_ABORTED:      'E_TOOL_001',
  TOOL_BAD_INPUT:    'E_TOOL_002',
  TOOL_TIMEOUT:      'E_TOOL_003',
} as const

export type ErrorId = (typeof ErrorIds)[keyof typeof ErrorIds]
```

A drop-in template: `templates/errorIds.ts`.

## The error class

One base class that forces every throw to carry an ID:

```ts
// src/errors.ts
import type { ErrorId } from './constants/errorIds'

export class AppError extends Error {
  readonly id: ErrorId
  readonly context: Record<string, unknown>
  constructor(id: ErrorId, message: string, context: Record<string, unknown> = {}) {
    super(message)
    this.id = id
    this.context = context
    this.name = 'AppError'
  }
}
```

Throw site:

```ts
throw new AppError(ErrorIds.CFG_SCHEMA_FAIL, 'config failed zod validation', {
  path: configPath,
  issues: parsed.error.issues,
})
```

Log line:

```
[E_CFG_003] config failed zod validation path=/etc/app.json issues=[...]
```

## Rules the registry enforces

1. **Never reuse a retired ID.** If you delete a throw site, the ID stays in the registry (mark it `// retired`). Old logs still need to be searchable.
2. **One ID per distinct cause, not per throw site.** Three throws of `FS_NOT_FOUND` is fine. Three different IDs for "file not found" is wrong.
3. **Numbers are stable.** Don't renumber. Append.
4. **Domain prefix is required.** `E_001` without a domain collides the moment the codebase grows.

## Optional: doc generation

Once the registry exists, a script can generate `docs/errors.md` from it — each ID with its message template, common causes, and remediation. This matters when the codebase gets big enough that people look errors up instead of reading the thrower.

```ts
// scripts/gen-error-docs.ts
import { ErrorIds } from '../src/constants/errorIds'
// emit markdown: for each [key, id] in ErrorIds …
```

## Lint support

Add to the ESLint config so raw `throw new Error(...)` gets flagged in favor of `AppError`:

```js
'no-restricted-syntax': [
  'error',
  {
    selector: 'ThrowStatement > NewExpression[callee.name="Error"]',
    message: 'Throw AppError(ErrorIds.X, ...) instead of raw Error. See guides/error-id-registry.md.',
  },
],
```

Exemptions: tests and scripts. Add an override.

## What this buys an agent

- When a test fails, the agent sees `[E_FS_002]` and jumps straight to the registry, then to every site that throws that ID.
- When asked to add a new error, the agent appends to `errorIds.ts` with a new number instead of inventing a new message, which means grep still works next week.
- When asked to *rename* an error, the agent changes the message but keeps the ID — no telemetry churn.
