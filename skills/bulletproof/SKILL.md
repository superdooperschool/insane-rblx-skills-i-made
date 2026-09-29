---
name: bulletproof
description: Fire-and-forget mode for Roblox Studio Luau tasks the user wants fully completed without supervision. Forces planning, MCP-verified execution in Studio, self-review, and explicit blocker surfacing. Use when user says "bulletproof", "full-proof", "fully complete", "do this while I work on X", or hands off a Roblox Studio task and walks away. STRICTLY for Roblox Studio Luau work via the rbx MCP server.
---

# Bulletproof — Roblox Studio Luau

User hand off Studio task. User work elsewhere. You finish solid via MCP or surface blocker fast. No silent stuck. No fake done. No web/non-Studio detours.

## Scope guard
- ONLY Roblox Studio Luau tasks executed via the `mcp__rbx__studio` dispatch tool (`op` + `args`), or the `rbx` CLI.
- If task not Roblox Studio Luau → say so, exit skill, ask user redirect.
- No Python, JS, web frameworks, generic file edits outside Studio session.

## Phase 1 — Plan
1. Restate task in 1 sentence. Ambiguous → ASK before any tool call.
2. `mcp__rbx__studio` with `op:"health"` → confirm a place is open. `(NO PLACE OPEN)` or no studios → STOP, ask user to open Studio + set the place active.
3. Map target instances: `search_game_tree` + `inspect_instance` to locate exact scripts/objects. No guess paths.
4. `script_grep` / `script_search` for existing logic before writing new. Reuse over duplicate.
5. TaskCreate 3-7 step plan. Each step concrete + verifiable in Studio.
6. Pick verification method: Play test? Console output? Visual screenshot? State this up front.

## Phase 2 — Execute
- Use `script_read` before `multi_edit`. Never blind-edit.
- Prefer `multi_edit` for batched changes — atomic, less round-trips.
- Respect user code rules: NO `print()` for status/info logging, use `warn()` only for real errors. Write no comments at all: names carry the meaning.
- Luau idioms: typed `local` where helpful, `task.wait`/`task.spawn` over `wait`/`spawn`, `:GetService()` over direct globals, attributes/CollectionService over name-matching when fits.
- Heavy script-tree exploration → spawn Explore agent. Keep main context clean.

## Phase 3 — Verify in Studio (mandatory)
Pick all that apply:
- **Logic change**: `start_stop_play` → `get_console_output` → confirm no errors, expected `warn()` fires when triggered, no unexpected output.
- **Visual / UI**: `screen_capture` before + after. Compare.
- **Anticheat / detection**: trigger condition manually via `execute_luau` or `user_keyboard_input`/`user_mouse_input`. Watch BOTH false positive (legit action no flag) AND true positive (cheat action flag). Both directions or not done.
- **Instance/property edit**: `inspect_instance` post-edit, confirm property landed.
- **Refactor**: `script_read` every changed script end-to-end. Diff matches intent, no orphan code.

If verify fail → fix → re-verify. Max 3 cycles. After 3 → STOP, surface blocker.

## Phase 4 — Self-review
- Re-read final state of every changed script via `script_read`.
- Scope creep added? Trim.
- TODO/placeholder/mock left? Remove or flag explicitly.
- Print spam crept in? Strip.
- Zero comments? Remove every comment you added.
- Edge cases user implied? List in report.

## Phase 5 — Report
End with:
```
DONE: <one-line what shipped in Studio>
VERIFIED: <exact MCP tool + output/screenshot proving it works>
SCRIPTS TOUCHED: <full instance paths>
SKIPPED: <anything not done + why>
BLOCKERS: <specific question or missing access, if any>
NEXT: <suggested follow-up or "none">
```

## Stuck rules
- Same Luau error twice → STOP. No blind retry. Report exact error + last attempt.
- Studio session lost mid-task → `list_roblox_studios`, ask user resume.
- MCP tool returns unexpected schema → surface raw response, ask.
- >15 tool calls, no measurable progress → stop, summarize state, ask user.
- Irreversible action (delete instance, overwrite user-authored script with no backup) → confirm with user first even in fire-and-forget mode.

## Out of scope (do NOT do)
- Edit files outside Studio (`.claude/`, system files, non-Luau code).
- Install plugins, modify Studio settings, change MCP config.
- Web search for Luau syntax — use `execute_luau` to test in-engine instead.
