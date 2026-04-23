# Lint Rules for AI-Driven Codebases

Drop `templates/biome.json` and `templates/eslint.config.mjs` into any TypeScript project scaffolded from this repo. Biome runs first (format + fast syntactic rules, with autofix); ESLint runs second (type-aware + plugin-specific rules). This doc explains **why** those rules and not others, and **which tool owns which rule**.

## Biome vs ESLint split

Biome is 10-100× faster than ESLint but can't do type-aware analysis or match ESLint's plugin ecosystem. The split:

- **Biome owns:** formatting, `noUnusedVariables`, `noUnreachable`, `noConstantCondition`, `noSelfCompare`, `useStrictEquality`, `useThrowOnlyError`, `noEmptyBlockStatements`, `noConsole`, `noDebugger`, `useConst`, `noVar`, `useTemplate`, `useShorthandPropertyAssignment`, `useConsistentArrayType`, `useConsistentTypeDefinitions`, `useImportType`, `useOptionalChain`, `noDuplicateImports`, `noRestrictedImports` (package names), `noExplicitAny`, `noNonNullAssertion`, `noGlobalEval`. Roughly Tier 1 non-type-aware + Tier 3 debug leftovers + Tier 6 style.
- **ESLint owns:** the rules below. All of them need either TypeScript type info or plugin logic Biome doesn't ship. These are the highest-value AI guardrails.

The post-edit hook (`hooks/lint-on-edit.sh`) runs `biome check --write` then `eslint --fix` and pipes errors from either back to the agent.

## Principle

Lint is a feedback channel to the agent. Every rule should either:

1. Catch a class of defect LLMs actually introduce, or
2. Pin the agent to a project-specific convention it would otherwise drift from.

Rules that enforce taste, cosmetics, or arbitrary limits don't belong here — they produce noise the agent learns to suppress.

## What LLMs actually get wrong

Observed failure modes across agent-written TypeScript, in rough order of frequency:

- **Dropped `await`s and misused promises** — fire-and-forget async, `Promise<T>` passed where `T` is expected, `if (asyncFn())` against a truthy promise.
- **`any` as an escape hatch** — when types don't line up, agents reach for `any`, `as any`, or non-null `!` assertions instead of fixing the shape.
- **Hallucinated modules and APIs** — imports from packages not in `package.json`, functions that don't exist on the imported symbol.
- **Half-finished work** — empty function bodies, `TODO` placeholders, unreachable code after an early return, duplicated blocks from a botched refactor.
- **Silent warning suppression** — `eslint-disable` without justification when a rule trips.
- **Debug leftovers** — `console.log`, `debugger`, alerts left in after the agent "verifies" something.
- **Incoherent error handling** — empty `catch`, `throw "string"`, errors swallowed or rethrown without context.
- **Config sprawl** — `process.env.X` read deep inside modules instead of injected at the boundary.
- **Module cycles** — circular imports introduced by "helpful" extractions.

The ruleset is organized around these.

## Tiers

### Tier 1 — Correctness (`error`)
The bugs. Non-negotiable.
- **Async**: `no-floating-promises`, `no-misused-promises`, `require-await`, `await-thenable`, `return-await`.
- **Type safety**: `no-explicit-any`, the full `no-unsafe-*` family, `no-non-null-assertion`, `strict-boolean-expressions`, `switch-exhaustiveness-check`, `no-unnecessary-condition`.
- **Dead / incoherent code**: `no-unused-vars`, `no-unreachable`, `no-constant-condition`, `no-constant-binary-expression`, `no-self-compare`.
- **Equality**: `eqeqeq` (with `null: 'ignore'`).
- **Errors**: `no-throw-literal`, `only-throw-error`, `no-empty` (catches count).

### Tier 2 — Imports & dependencies
Highest-ROI rules, often skipped.
- `import/no-unresolved` — catches hallucinated module paths.
- `import/no-extraneous-dependencies` — catches invented packages.
- `import/no-cycle`, `import/no-self-import`, `import/no-duplicates`.
- `consistent-type-imports` — keeps type/value imports separated; matters for transpile correctness and tree-shaking.
- `no-restricted-imports` — pin the agent away from `lodash`/`moment`/`axios` picks when the project has a chosen stack; disallow deep `../../../` relative paths.

### Tier 3 — Agent-specific traps
- `no-console`, `no-debugger`, `no-alert` — debug leftovers.
- `no-empty-function` — stubbed handlers the agent forgot to finish.
- `no-restricted-properties` for `process.env` — force config injection at boundaries.
- `eslint-comments/require-description` + `no-unlimited-disable` + `no-unused-disable` — if the agent suppresses a rule, require a reason. Otherwise suppression becomes the path of least resistance.

### Tier 4 — Complexity (cognitive, not line count)
- `sonarjs/cognitive-complexity: 15` — the signal that actually correlates with "hard to read."
- `complexity`, `max-depth`, `max-nested-callbacks`, `max-params: 4` — all `warn`, not `error`. Utilities legitimately need 3–4 params.
- **No `max-lines` or `max-lines-per-function`.** Line caps punish coherent long code (reducers, parsers, JSX-heavy components) and reward fragmentation — the agent satisfies the cap by splitting into single-use helpers that only make sense read together. Cognitive complexity measures the thing you actually care about.

### Tier 5 — Security
Cheap, high leverage.
- `security/detect-unsafe-regex`, `detect-eval-with-expression`, `detect-object-injection`, `detect-non-literal-regexp`, `detect-child-process`.
- `no-eval`, `no-implied-eval`, `no-new-func`.

### Tier 6 — Style (lean)
Semantic choices only. Prettier/Biome handles layout.
- `consistent-type-definitions: type`, `array-type: array-simple`.
- `prefer-nullish-coalescing`, `prefer-optional-chain`, `prefer-readonly`.
- `prefer-const`, `no-var`, `object-shorthand`, `prefer-template`.

## Deliberately excluded

Some rules circulate as "AI guardrails" but produce more noise than signal on real codebases:

| Rule | Why not |
|---|---|
| Ban all comments | *Why*-comments (constraints, invariants, workaround rationale) are load-bearing. Ban low-signal *what*-comments in review, not in lint. |
| `max-lines` / `max-lines-per-function` | Arbitrary line caps cause over-extraction into incoherent helpers. Use cognitive complexity. |
| `max-params: 2` | Too tight for `clamp(x, min, max)`-shaped utilities. 4 is defensible. |
| `no-magic-numbers` | Noisy (HTTP codes, dates, math constants, array indexes). Enable per-directory if at all. |
| `id-length: { min: 2 }` | Breaks idiomatic `i`, `e`, `_`, `k`, `v`. |
| Wholesale `eslint-plugin-unicorn` | Many rules are taste (`no-null`, `prefer-node-protocol`, `no-array-reduce`); dropping it in wholesale is a style transplant, not a guardrail. |
| Project-wide `no-console` as `off` | Agents leave `console.log` everywhere. Keep it `error` with `{ allow: ['warn', 'error'] }`. |

## Tier 7 — Enforcement (where the leverage lives)

Rules only shape agent behavior if the agent sees failures. Wire lint into the loop:

1. **Post-edit hook** (`hooks/lint-on-edit.sh`) — runs `eslint --fix` on the file the agent just wrote and returns errors on stderr with exit 2. The agent reads the errors in its next turn and self-corrects. This is where most of the value is; a perfect ruleset with no feedback loop is noise.
2. **Pre-commit** — `lint-staged` + `husky`, commit blocks on error. Backstop against hook misconfiguration.
3. **CI as last line only** — by CI the agent has moved on; the correction cost is high.
4. **Type-aware linting on** (`parserOptions.projectService`) — half of Tier 1 requires type info. Worth the lint slowdown.

A useful heuristic: if a rule fires and the agent suppresses it without fixing, the rule is miscalibrated. Tune the rule, don't tolerate the suppression.

## Install

```bash
cp <repo>/templates/biome.json <project>/biome.json
cp <repo>/templates/eslint.config.mjs <project>/eslint.config.mjs
cd <project>
npm i -D @biomejs/biome eslint typescript-eslint eslint-plugin-import \
  eslint-plugin-sonarjs eslint-plugin-security eslint-plugin-eslint-comments
```

Then wire in the post-edit hook: `hooks/lint-on-edit.sh` + settings in `hooks/README.md`. The hook runs Biome first (fast, autofix), then ESLint (type-aware).
