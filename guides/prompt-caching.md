# Prompt Caching Strategy

Anthropic's prompt cache has a 5-minute TTL and is keyed by prefix. A cache hit is ~10× cheaper and ~2× faster than a miss. Most agent apps leave 50–90% of their achievable cache hit rate on the table because they structure prompts naively.

This guide is the minimum structural discipline to get hit rates above 80% without thinking about it on every call.

## The one rule

**Put the stable stuff first. Never put volatile stuff in front of stable stuff.**

A cache hit requires the *exact prefix* to match. One character of drift at byte 0 invalidates everything downstream.

## The canonical order

From first byte to last:

1. **System prompt** (hard-coded string, rarely changes).
2. **Tool definitions** (sorted by name, serialized with a stable JSON key order).
3. **Retrieved context / RAG chunks** that are stable for this session or user (project CLAUDE.md, repo metadata). Sort and dedupe.
4. **Conversation history** (append-only — never reorder past turns).
5. **Current user turn** (the only part that changes per-call).

Each of 1–3 gets a `cache_control: { type: 'ephemeral' }` breakpoint at its end. Anthropic allows up to 4 breakpoints — that's enough for this layout.

```ts
const response = await client.messages.create({
  model: 'claude-opus-4-7',
  system: [
    { type: 'text', text: SYSTEM_PROMPT,          cache_control: { type: 'ephemeral' } },
    { type: 'text', text: renderTools(tools),     cache_control: { type: 'ephemeral' } },
    { type: 'text', text: renderStableCtx(ctx),   cache_control: { type: 'ephemeral' } },
  ],
  messages: [
    ...history,           // append-only
    { role: 'user', content: currentTurn },
  ],
  max_tokens: 4096,
})
```

## Things that silently break caching

**Timestamps anywhere in the stable prefix.** A "generated at" line in the system prompt destroys every hit.

**Tool definitions in declaration order.** If two callers register tools in different orders, they can't share cache. Sort by name.

**Non-deterministic JSON serialization.** `JSON.stringify` with unsorted keys, locale-sensitive number formatting, or floating-point results changes bytes without changing meaning. Use a stable serializer or a sorted-keys helper.

**Interleaving RAG chunks with the user turn.** Putting retrieved context *after* the user message means every new query re-fetches chunks in a different order, and the cache can't help. Retrieve first, inject into the stable section, then add the turn.

**Per-user personalization in the system prompt.** "Hello, {name}" at byte 0 = one cache per user. Put the name at the end of the stable section (after a breakpoint) or in the user turn.

**Streaming your own summaries back in.** If an intermediate step rewrites earlier history ("compacting" past turns), the prefix changes and every subsequent call misses. Keep compaction at a coarse granularity — all-or-nothing per session, not per turn.

## Measuring hit rate

Log the cache fields on every response:

```ts
const { cache_creation_input_tokens, cache_read_input_tokens, input_tokens } = response.usage
const total = cache_creation_input_tokens + cache_read_input_tokens + input_tokens
const hitRate = cache_read_input_tokens / total
```

A healthy agent loop runs **> 0.85** hit rate steady-state. Below 0.5 means the prefix is unstable — go find the timestamp.

## Sizing for the cache

The cache has a **1024-token minimum** per breakpoint (varies by model — check docs). A breakpoint on a 200-token section wastes the breakpoint. Either bundle small sections together or drop the breakpoint.

## TTL behavior

- **5-minute TTL, refreshed on every hit.** A steadily used session keeps its cache warm indefinitely.
- **First call in > 5 min eats the miss.** This is why polling loops (`ScheduleWakeup`, etc.) should pick intervals of either < 270s (stay warm) or > 1200s (amortize the miss). 5-minute polls are the worst case — a miss on every tick.

## Patterns specific to agents

- **Subagents share no cache with the parent.** Each dispatch is a fresh conversation. Keep subagent system prompts small and stable; they pay the miss every time.
- **Tool-result feedback loops cache well.** The tool call + tool result stay in the append-only history, so the next turn hits on everything up to and including the result.
- **Plan-then-execute beats interleaved reasoning.** If the agent plans in one long turn then executes in short turns, each execute turn caches against the long plan. Interleaved thought-action-thought restarts the "reasoning" every turn and misses more.

## What this buys

- 80%+ input cost reduction on typical agent workloads.
- 30–50% latency reduction on repeat turns.
- Much smaller spread between cheap and expensive sessions — billing becomes predictable.

## Cross-references

- The `claude-api` skill (available in this environment) includes prompt caching by default in scaffolded apps.
- The agent-starter `ScheduleWakeup` guidance already warns against 5-minute intervals for the same TTL reason.
