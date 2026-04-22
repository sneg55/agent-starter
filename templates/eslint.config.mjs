// ESLint flat config tuned for AI-agent-driven TypeScript codebases.
// Rationale, tier-by-tier, in guides/lint-rules-for-ai.md.
//
// Assumes: ESLint >= 9, TypeScript, type-aware linting enabled via projectService.
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
  ...tseslint.configs.stylisticTypeChecked,

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
      // ── Tier 1: Correctness ────────────────────────────────────────────────
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/require-await': 'error',
      '@typescript-eslint/await-thenable': 'error',
      '@typescript-eslint/return-await': ['error', 'always'],

      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-unsafe-call': 'error',
      '@typescript-eslint/no-unsafe-member-access': 'error',
      '@typescript-eslint/no-unsafe-return': 'error',
      '@typescript-eslint/no-unsafe-argument': 'error',
      '@typescript-eslint/no-non-null-assertion': 'error',
      '@typescript-eslint/strict-boolean-expressions': [
        'error',
        { allowNullableObject: true, allowNullableBoolean: true },
      ],
      '@typescript-eslint/switch-exhaustiveness-check': 'error',
      '@typescript-eslint/no-unnecessary-condition': 'error',

      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      'no-unreachable': 'error',
      'no-constant-condition': 'error',
      'no-constant-binary-expression': 'error',
      'no-self-compare': 'error',
      'no-unused-private-class-members': 'error',

      eqeqeq: ['error', 'always', { null: 'ignore' }],

      'no-throw-literal': 'error',
      '@typescript-eslint/only-throw-error': 'error',
      'no-empty': ['error', { allowEmptyCatch: false }],

      // ── Tier 2: Imports & dependency hygiene ───────────────────────────────
      'import/no-unresolved': 'error',
      'import/no-cycle': ['error', { maxDepth: 10 }],
      'import/no-self-import': 'error',
      'import/no-duplicates': 'error',
      'import/no-extraneous-dependencies': 'error',
      'import/first': 'error',
      'import/newline-after-import': 'error',
      '@typescript-eslint/consistent-type-imports': [
        'error',
        { prefer: 'type-imports', fixStyle: 'inline-type-imports' },
      ],
      // Pin the agent away from common hallucinated/legacy picks.
      'no-restricted-imports': [
        'error',
        {
          paths: [
            { name: 'lodash', message: 'Use native JS or lodash-es.' },
            { name: 'moment', message: 'Use date-fns or Temporal.' },
            { name: 'axios', message: 'Use fetch.' },
          ],
          patterns: ['../../../*'],
        },
      ],

      // ── Tier 3: Agent-specific traps ───────────────────────────────────────
      'no-console': ['error', { allow: ['warn', 'error'] }],
      'no-debugger': 'error',
      'no-alert': 'error',
      'no-warning-comments': [
        'warn',
        { terms: ['fixme', 'xxx', 'hack'], location: 'anywhere' },
      ],
      'no-empty-function': ['error', { allow: ['arrowFunctions', 'methods'] }],
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

      // ── Tier 4: Complexity (cognitive, not line count) ─────────────────────
      'sonarjs/cognitive-complexity': ['error', 15],
      'sonarjs/no-duplicate-string': ['error', { threshold: 5 }],
      'sonarjs/no-identical-functions': 'error',
      'sonarjs/no-collapsible-if': 'error',
      'sonarjs/prefer-immediate-return': 'error',
      complexity: ['warn', 15],
      'max-depth': ['warn', 4],
      'max-nested-callbacks': ['warn', 3],
      'max-params': ['warn', 4],

      // ── Tier 5: Security ───────────────────────────────────────────────────
      'security/detect-object-injection': 'warn',
      'security/detect-non-literal-regexp': 'warn',
      'security/detect-unsafe-regex': 'error',
      'security/detect-eval-with-expression': 'error',
      'security/detect-child-process': 'warn',
      'no-eval': 'error',
      'no-implied-eval': 'error',
      'no-new-func': 'error',

      // ── Tier 6: Style (semantic choices only; Prettier/Biome does layout) ──
      '@typescript-eslint/consistent-type-definitions': ['error', 'type'],
      '@typescript-eslint/array-type': ['error', { default: 'array-simple' }],
      '@typescript-eslint/prefer-nullish-coalescing': 'error',
      '@typescript-eslint/prefer-optional-chain': 'error',
      '@typescript-eslint/prefer-readonly': 'error',
      'prefer-const': 'error',
      'no-var': 'error',
      'object-shorthand': 'error',
      'prefer-template': 'error',
    },
  },

  // Tests: loosen the rules that fight legitimate test patterns.
  {
    files: ['**/*.{test,spec}.{ts,tsx}', 'tests/**/*.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-non-null-assertion': 'off',
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      'sonarjs/no-duplicate-string': 'off',
      'max-nested-callbacks': 'off',
      'no-restricted-properties': 'off',
    },
  },
)
