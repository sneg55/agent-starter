# Lint Rules for AI-Driven Codebases

Ship `templates/eslint.config.mjs` into any new TypeScript project scaffolded from this repo. This doc explains **why** those rules and not others.

## Principle

Catch the defects LLMs actually introduce. Pin the agent to project conventions. Leave taste to review.

A popular framing ([ESLint as AI Guardrails](https://medium.com/@albro/eslint-as-ai-guardrails-the-rules-that-make-ai-code-readable-8899c71d3446)) proposes five rules: ban comments, cap params at 2, cap functions at 50 lines, cap files at 250 lines, ban magic numbers. This config deliberately rejects most of it. Those rules optimize for "looks tidy in a demo," not for the failure modes agents exhibit on real codebases — dropped `await`s, `any` escape hatches, hallucinated imports, half-finished functions.

## Tiers

### Tier 1 — Correctness
The bugs LLMs actually ship. Non-negotiable.
- **Async correctness**: `no-floating-promises`, `no-misused-promises`, `require-await`, `await-thenable`, `return-await`. Agents drop `await` constantly.
- **Type safety**: `no-explicit-any`, `no-unsafe-*`, `no-non-null-assertion`, `strict-boolean-expressions`, `switch-exhaustiveness-check`, `no-unnecessary-condition`. `any` is the LLM's escape hatch — close it.
- **Dead / hallucinated code**: `no-unused-vars`, `no-unreachable`, `no-constant-condition`, `no-self-compare`.
- **Errors**: `no-throw-literal`, `only-throw-error`, `no-empty` (no `allowEmptyCatch`).

### Tier 2 — Imports & dependency hygiene
Highest-ROI rules almost nobody turns on.
- `import/no-unresolved`, `import/no-cycle`, `import/no-duplicates`, `import/no-extraneous-dependencies` — catch hallucinated modules, invented packages, cycles.
- `consistent-type-imports` — keeps type/value imports separated, helps tree-shaking and transpile correctness.
- `no-restricted-imports` — pin the agent away from `lodash`/`moment`/`axios` picks and deep `../../../` paths.

### Tier 3 — Agent-specific traps
- `no-console`, `no-debugger`, `no-alert` — agents leave debug prints.
- `no-empty-function` — catches stubbed-out handlers agents forgot to finish.
- `no-restricted-properties` for `process.env` — force config injection at boundaries.
- `eslint-comments/require-description` + `no-unlimited-disable` + `no-unused-disable` — agents *will* suppress warnings if you let them. Require justification.

### Tier 4 — Complexity (cognitive, not line count)
- `sonarjs/cognitive-complexity: 15` — the signal that actually matters.
- `complexity`, `max-depth`, `max-nested-callbacks`, `max-params: 4` — all `warn`, not `error`; utilities legitimately need 3–4 params.
- **No `max-lines` / `max-lines-per-function`.** Arbitrary line caps cause the opposite failure mode: over-extraction into incoherent single-use helpers. Measure cognition, not length.

### Tier 5 — Security
`security/detect-unsafe-regex`, `detect-eval-with-expression`, `detect-object-injection`, plus `no-eval`/`no-implied-eval`/`no-new-func`. Cheap, high leverage.

### Tier 6 — Style (lean)
Only semantic choices, not layout. Prettier/Biome handles formatting.
- `consistent-type-definitions: type`, `array-type: array-simple`
- `prefer-nullish-coalescing`, `prefer-optional-chain`, `prefer-readonly`
- `prefer-const`, `no-var`, `object-shorthand`, `prefer-template`

## Explicitly rejected

| Rule | Why not |
|---|---|
| `no-comments/disallowComments` | *Why*-comments (constraints, invariants, workaround rationale) are valuable. Ban low-signal *what*-comments in review instead. |
| `max-lines: 250` | Forces artificial module splits of coherent concepts. |
| `max-lines-per-function: 50` | Encourages over-extraction into single-use helpers. Use cognitive complexity. |
| `better-max-params: 2` | Too tight for `clamp(x, min, max)`-shaped utilities. 4 is defensible. |
| `no-magic-numbers` | Noisy (HTTP codes, dates, math constants). Enable per-directory if at all. |
| `id-length: { min: 2 }` | Breaks idiomatic `i`, `e`, `_`, `k`, `v`. |
| Wholesale `eslint-plugin-unicorn` | Taste transplant dressed as guardrails. |

## Enforcement (Tier 7 — where the leverage actually lives)

Rules only matter if the agent sees failures. Wire them into the loop:

1. **Pre-commit** — `lint-staged` + `husky` runs ESLint on staged files; commit blocks on error.
2. **Post-edit hook** — `hooks/lint-on-edit.sh` runs `eslint --fix` + `tsc --noEmit` on files the agent just wrote. The agent reads the error output in the next turn and self-corrects. This is 10× more valuable than any specific rule.
3. **CI as backstop, never primary gate** — by CI it's too late; the agent has moved on.
4. **Type-aware rules on** (`parserOptions.projectService`). Half of Tier 1 only works with type info. Worth the lint slowdown.

## Install

```bash
cp <repo>/templates/eslint.config.mjs <project>/eslint.config.mjs
cd <project>
npm i -D eslint typescript-eslint eslint-plugin-import \
  eslint-plugin-sonarjs eslint-plugin-security eslint-plugin-eslint-comments
```

Then wire in the post-edit hook (see `hooks/lint-on-edit.sh` + `hooks/README.md`).
