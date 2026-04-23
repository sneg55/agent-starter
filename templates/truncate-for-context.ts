// Truncate long tool outputs before feeding them back to the LLM.
//
// Problem: `cat large.log`, `rg -l` across a monorepo, or `npm test` on a
// big suite can return tens of thousands of lines. Injecting that verbatim
// into the conversation blows the context window and pushes useful history
// out of cache.
//
// Pattern: always pass tool output through a truncator that keeps a
// head + tail window and replaces the middle with a marker the LLM can
// recognize and reason about.
//
// Drop into src/utils/ and import from every tool's result formatter.

export type TruncateOptions = {
  /** Max total characters. Hard cap — output is always <= this. Default 32_000. */
  maxChars?: number
  /** Max total lines. Applied BEFORE char cap. Default 400. */
  maxLines?: number
  /** Lines to keep from the start when truncating by lines. Default 200. */
  headLines?: number
  /** Lines to keep from the end when truncating by lines. Default 100. */
  tailLines?: number
  /** Label for the marker, e.g. 'log', 'test output', 'grep match'. */
  kind?: string
}

const DEFAULTS = {
  maxChars: 32_000,
  maxLines: 400,
  headLines: 200,
  tailLines: 100,
  kind: 'output',
} as const

export type TruncateResult = {
  text: string
  truncated: boolean
  originalLines: number
  originalChars: number
}

export function truncateForContext(input: string, opts: TruncateOptions = {}): TruncateResult {
  const o = { ...DEFAULTS, ...opts }
  const originalChars = input.length
  const lines = input.split('\n')
  const originalLines = lines.length

  let text = input
  let truncated = false

  if (lines.length > o.maxLines) {
    const head = lines.slice(0, o.headLines)
    const tail = lines.slice(-o.tailLines)
    const elided = lines.length - o.headLines - o.tailLines
    text = [
      ...head,
      `[... ${elided} lines of ${o.kind} elided — total ${originalLines} lines ...]`,
      ...tail,
    ].join('\n')
    truncated = true
  }

  if (text.length > o.maxChars) {
    const half = Math.floor((o.maxChars - 100) / 2)
    const head = text.slice(0, half)
    const tail = text.slice(-half)
    text = `${head}\n[... ${text.length - 2 * half} chars elided ...]\n${tail}`
    truncated = true
  }

  return { text, truncated, originalLines, originalChars }
}

// Convenience: truncate and format for a tool result block.
export function formatToolOutput(input: string, opts: TruncateOptions = {}): string {
  const r = truncateForContext(input, opts)
  if (!r.truncated) return r.text
  return `${r.text}\n\n[truncated: ${r.originalLines} lines / ${r.originalChars} chars total]`
}
