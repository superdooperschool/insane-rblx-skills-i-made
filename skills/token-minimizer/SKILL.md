---
name: token-minimizer
description: Use at the start of every session that will read files, scripts, transcripts or web pages, run Studio/CLI tools, or last more than a few calls - and whenever context passes ~150k, a session feels slow or expensive, before any large read or screenshot, or when asked where tokens go. Applies to all work, not only Roblox; rbx and studio load it automatically.
---

# token-minimizer

**Cost = context size x model calls.** Measured over 114 Roblox sessions (9,397 calls): re-reading
already-seen context was **68%** of spend, output 17%, cache-write 15%. Every call re-sends the whole
conversation. Same work in four short sessions costs a third of one long one.

Re-measure: `node scripts/audit.mjs [--rbx] [--session <id>]`.
**Acceptance for a session:** unranged reads 0, truncated re-reads 0, avg context < 150k, < 8 calls per prompt.

## Five levers, ranked by measured impact

| # | Lever | Measured | Rule |
|---|---|---|---|
| 1 | Session length | Top sessions 300-570k avg context over 300-430 calls | One task per session. At a milestone write STATUS (20 lines: done / next / blockers) and `/compact` or start fresh reading only STATUS. Never "one more thing" past 200k. |
| 2 | Fixed prompt | 74k tokens before any work, repaid every call (27% of all context) | Load a skill only when its trigger fires. Never read a memory file the index already summarises unless the task names that system. Keep CLAUDE.md/AGENTS.md deduped. |
| 3 | Own output accumulates | 12.6M output tokens; 664 full-file writes; same helper re-sent 60x; one file rewritten 24x | Anchored `edit`, not full `write`. Reusable code lives in a file and is run by path. No narration between calls (970 prose-only calls). No restating the plan. |
| 4 | Tool results persist | 843 unranged reads; 44 re-reads of a truncated temp file; 243 same-file re-reads; 115 image reads | Outline/grep first, then a ranged read of the hit. Over ~4k chars: `--out file` + `grep`. Read an image once. Trees/listings always filtered. |
| 5 | Call count | 9.8 calls per prompt, 67 for one; 254 health checks; 185 play toggles; 15% parallel | Batch: one call with N asserts returning one table. Independent calls in one message. Health/status only after an error. |

## Protocol (every session)

1. **Open** - one-line task statement. No memory dives, no "let me understand the codebase".
2. **Locate** - symbol outline / literal find / filtered tree. Never a whole file to find one thing.
3. **Read** - only the window you will change. Big result -> file -> grep -> ranged read.
4. **Change** - anchored edit. Full write only for a new file or a requested rewrite.
5. **Verify** - one batched check returning booleans. One capture, read once.
6. **Report** - outcome first, once. Stop. No summary of the summary.
7. **Long task** - STATUS file at ~150k, then compact or new session.

Applies equally to: Studio scripts (`outline` / `read --from --to` / `find`), source files (`Grep` ->
`Read` with `offset`/`limit`), transcripts (`audit.mjs`, never `cat`), web pages (fetch once, extract,
discard), subagent reports (ask for the conclusion, not the file dumps).

## Red flags

- "Read the whole file to understand it"  -> outline first
- Opening the temp file a truncated result pointed at, in full  -> grep it
- Health/status check as the first call of every prompt
- Second `Read` of an image, a memory file, or anything already in context
- Re-sending a helper you sent earlier  -> save it, run by path
- `Write` of a file already written this session  -> `edit`
- Explaining what you are about to do, then doing it
- 20 calls in, nothing changed yet
- Context past 200k and still adding tasks

## Not the problem

Thinking tokens (negligible). Skill bodies once loaded (2k words each). Per-image cost (~1.5k). The
cost is length and repetition, not any single call.
