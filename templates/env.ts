// Single env boundary. See guides/zod-at-the-boundary.md.
//
// Rules:
//   1. This file is the ONLY place `process.env` is read.
//     (The ESLint config enforces this via no-restricted-properties.)
//   2. The schema is the source of truth for the `Env` type.
//   3. `envSchema.parse` throws at import time — fail fast on misconfiguration.
//   4. Add new vars here, declare their shape, provide a default where sensible.
//
// Consumers:
//   import { env } from '@/env'
//   fetch(env.API_URL, { signal })

import { z } from 'zod'

const envSchema = z.object({
  // ── Runtime ──────────────────────────────────────────────────────────────
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),

  // ── External services (examples — replace with your own) ─────────────────
  // DATABASE_URL: z.string().url(),
  // REDIS_URL: z.string().url().optional(),
  // ANTHROPIC_API_KEY: z.string().min(1),
  // SENTRY_DSN: z.string().url().optional(),
}) satisfies z.ZodType

export type Env = z.infer<typeof envSchema>

function loadEnv(): Env {
  const parsed = envSchema.safeParse(process.env)
  if (!parsed.success) {
    // Render a readable error at startup. One bad env var should surface the
    // exact field and reason, not crash 10 stack frames deep.
    const lines = parsed.error.issues.map((i) => `  ${i.path.join('.')}: ${i.message}`)
    // eslint-disable-next-line no-console -- startup error; must reach stderr.
    console.error(`[env] invalid configuration:\n${lines.join('\n')}`)
    process.exit(1)
  }
  return parsed.data
}

// eslint-disable-next-line no-restricted-properties -- this file is the boundary.
export const env = loadEnv()
