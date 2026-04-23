// ESLint flat config — trimmed companion to templates/biome.json.
// Biome handles fast syntactic rules + formatting (see biome.json).
// ESLint keeps ONLY the rules Biome can't do: type-aware checks and
// plugin-specific checks (import resolution, sonarjs complexity, security).
//
// Rationale and tier-by-tier breakdown: guides/lint-rules-for-ai.md.
//
// Assumes: ESLint >= 9, TypeScript, type-aware linting via projectService.
// Install:
//   npm i -D eslint typescript-eslint eslint-plugin-import \
//     eslint-plugin-sonarjs eslint-plugin-security eslint-plugin-eslint-comments

import tseslint from 'typescript-eslint'
import importPlugin from 'eslint-plugin-import'
import sonarjs from 'eslint-plugin-sonarjs'
import security from 'eslint-plugin-security'
import comments from 'eslint-plugin-eslint-comments'

export default tseslint.config(
  {
    ignores: ['dist/**', 'build/**', 'coverage/**', 'node_modules/**', '*.config.*'],
  },

  ...tseslint.configs.recommendedTypeChecked,

  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
    plugins: {
      import: importPlugin,
      sonarjs,
      security,
      'eslint-comments': comments,
    },
    rules: {
      // ── Tier 1: Type-aware correctness (Biome cannot do these) ─────────────
      // Async bugs — the highest-value AI guardrails.
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/require-await': 'error',
      '@typescript-eslint/await-thenable': 'error',
      '@typescript-eslint/return-await': ['error', 'always'],

      // Type-unsafe escape hatches.
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-unsafe-call': 'error',
      '@typescript-eslint/no-unsafe-member-access': 'error',
      '@typescript-eslint/no-unsafe-return': 'error',
      '@typescript-eslint/no-unsafe-argument': 'error',
      '@typescript-eslint/strict-boolean-expressions': [
        'error',
        { allowNullableObject: true, allowNullableBoolean: true },
      ],
      '@typescript-eslint/switch-exhaustiveness-check': 'error',
      '@typescript-eslint/no-unnecessary-condition': 'error',
      '@typescript-eslint/only-throw-error': 'error',
      '@typescript-eslint/prefer-nullish-coalescing': 'error',
      '@typescript-eslint/prefer-readonly': 'error',

      // ── Tier 2: Imports (catches hallucinated modules — Biome can't resolve) ─
      'import/no-unresolved': 'error',
      'import/no-cycle': ['error', { maxDepth: 10 }],
      'import/no-self-import': 'error',
      'import/no-extraneous-dependencies': 'error',
      'import/first': 'error',
      'import/newline-after-import': 'error',
      // Deep relative paths — style.noRestrictedImports in Biome covers package names,
      // but pattern matching on relative paths is ESLint-only.
      'no-restricted-imports': ['error', { patterns: ['../../../*'] }],

      // ── Tier 3: Agent-specific traps (plugin-only) ─────────────────────────
      'no-warning-comments': [
        'warn',
        { terms: ['fixme', 'xxx', 'hack'], location: 'anywhere' },
      ],
      'no-restricted-properties': [
        'error',
        {
          object: 'process',
          property: 'env',
          message: 'Inject config at the boundary; do not read process.env deep in modules.',
        },
      ],
      'eslint-comments/require-description': ['error', { ignore: [] }],
      'eslint-comments/no-unlimited-disable': 'error',
      'eslint-comments/no-unused-disable': 'error',

      // ── Tier 4: Complexity (sonarjs — Biome has noExcessiveCognitiveComplexity
      //    but sonarjs's heuristics are more mature) ─────────────────────────
      'sonarjs/cognitive-complexity': ['error', 15],
      'sonarjs/no-duplicate-string': ['error', { threshold: 5 }],
      'sonarjs/no-identical-functions': 'error',
      'sonarjs/no-collapsible-if': 'error',
      'sonarjs/prefer-immediate-return': 'error',
      complexity: ['warn', 15],
      'max-depth': ['warn', 4],
      'max-nested-callbacks': ['warn', 3],
      'max-params': ['warn', 4],

      // ── Tier 5: Security (Biome only has noGlobalEval) ─────────────────────
      'security/detect-object-injection': 'warn',
      'security/detect-non-literal-regexp': 'warn',
      'security/detect-unsafe-regex': 'error',
      'security/detect-eval-with-expression': 'error',
      'security/detect-child-process': 'warn',
      'no-implied-eval': 'error',
      'no-new-func': 'error',

      // ── Turn OFF rules Biome now owns, so they don't double-fire ───────────
      // (typescript-eslint recommendedTypeChecked enables some of these.)
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-non-null-assertion': 'off',
      '@typescript-eslint/no-unused-vars': 'off',
    },
  },

  {
    files: ['**/*.{test,spec}.{ts,tsx}', 'tests/**/*.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      'sonarjs/no-duplicate-string': 'off',
      'max-nested-callbacks': 'off',
      'no-restricted-properties': 'off',
    },
  },
)
