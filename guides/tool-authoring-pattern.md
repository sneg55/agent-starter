# Tool-Authoring Pattern

Extracted from Claude Code's own tool implementations (`BashTool/`, `FileEditTool/`, `GrepTool/` etc.). Every tool is a directory of small, single-purpose files. The pattern scales from a two-file tool to an 18-file one without rearranging anything.

## The shape

```
src/tools/MyTool/
├── MyTool.ts          # The handler — glues the pieces together
├── toolName.ts        # Just the name constant (see "Why separate")
├── schema.ts          # Zod input schema (types inferred from it)
├── prompt.ts          # The instruction string the LLM sees
├── validation.ts      # Input checks beyond schema (e.g. "path exists")
├── permissions.ts     # "Is this invocation allowed?"
├── security.ts        # "Is this invocation safe?" (different from allowed)
├── execute.ts         # The actual side-effectful work
├── result.ts          # The discriminated-union result type + formatter
├── constants.ts       # Timeouts, limits, magic strings
├── errors.ts          # Tool-specific error IDs + classes
├── UI.tsx             # Optional: how results render in a TUI
└── index.ts           # Barrel export — only what callers need
```

Not every tool needs all of these. A read-only tool skips `permissions.ts` and `security.ts`. A silent tool skips `UI.tsx`. But the *slots* are always in the same place, so an agent editing an unfamiliar tool knows where to look.

## Why separate files (not one `MyTool.ts`)

- **`toolName.ts` is a string constant.** It's imported by logging, telemetry, the registry, and sometimes by other tools that compose this one. Keeping it in a leaf file with zero other imports breaks the cycle that would otherwise form (`MyTool.ts` imports `telemetry.ts` imports `toolNames.ts` imports `MyTool.ts`…).
- **`prompt.ts` is the LLM contract.** It changes often, is reviewed by humans for tone, and wants its own diff. Bundling it into `MyTool.ts` means every prompt tweak churns the handler file.
- **`schema.ts` is the source of truth for types.** Infer `Input = z.infer<typeof schema>` and import the type from here. Nothing else should define the input shape.
- **`permissions.ts` vs `security.ts`.** *Permissions* is policy ("user config says no `rm`"). *Security* is invariants ("regardless of config, never `eval` user strings"). Collapsing them loses the distinction, and agents routinely confuse the two when asked to loosen one.
- **`result.ts`** owns the `Result<Ok, Err>` discriminated union. See `guides/discriminated-union-results.md` for why this shape and not throwing.

## The handler

`MyTool.ts` is a thin orchestrator:

```ts
import { TOOL_NAME } from './toolName'
import { schema, type Input } from './schema'
import { prompt } from './prompt'
import { validate } from './validation'
import { checkPermissions } from './permissions'
import { checkSecurity } from './security'
import { execute } from './execute'
import { type Result } from './result'

export const MyTool = {
  name: TOOL_NAME,
  prompt,
  schema,
  async run(input: Input, ctx: Ctx): Promise<Result> {
    const v = validate(input)
    if (!v.ok) return v
    const p = checkPermissions(input, ctx)
    if (!p.ok) return p
    const s = checkSecurity(input, ctx)
    if (!s.ok) return s
    return execute(input, ctx)
  },
}
```

Every gate returns the same `Result` shape, so the pipeline is five lines and every failure mode is a discriminated-union variant the caller already knows how to render.

## The registry, not a switch

Tools register themselves into a map:

```ts
// src/tools/index.ts
import { MyTool } from './MyTool'
import { OtherTool } from './OtherTool'

export const tools = {
  [MyTool.name]: MyTool,
  [OtherTool.name]: OtherTool,
} as const
```

No `switch (name) { case "my_tool": …}` dispatch. Adding a tool is a one-line change here plus a new directory. The large-codebase guide covers this pattern (§12) — this is its highest-ROI application.

## Testing shape

Tests live next to the tool, mirroring the file split:

```
src/tools/MyTool/
├── __tests__/
│   ├── validation.test.ts   # Pure input tests — no mocks
│   ├── permissions.test.ts  # Policy tests — inject ctx
│   ├── security.test.ts     # Invariant tests — inject ctx
│   └── MyTool.test.ts       # End-to-end: mocks execute()
```

`execute.ts` is the only file that touches the outside world; it's the only one that ever needs fakes. Everything else is pure functions you can test without plumbing.

## When to split a file out

Default: stay inline until a file passes ~150 lines or picks up a second responsibility. When it does:

- Constants → `constants.ts`
- Error IDs → `errors.ts`
- A second validation path → `validation.ts`

Don't pre-split. An empty `security.ts` is worse than an inline check — it signals "this tool has a security story" when it doesn't.

## What this buys an agent

- **Locatability.** "Where's the permission check?" always has the same answer.
- **Small diffs.** Prompt tweaks touch one file. Schema changes touch one file.
- **Safe refactors.** Moving `execute.ts` behind a queue doesn't ripple into `prompt.ts`.
- **No cycles.** The `toolName.ts` trick alone eliminates a whole class of import-cycle bugs.
