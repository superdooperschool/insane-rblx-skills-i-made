---
name: rbx-net
description: Use when adding, changing, reviewing or auditing any Roblox client-to-server path - RemoteEvent, RemoteFunction, Net channel, BindableEvent bridge - when asked "is this exploitable", before a release, when a reward can be reached without the work, or when wiring a new panel action to the server.
---

# rbx-net

**Client sends intent, server recomputes everything, one router, one budget.** `scripts/net.lua`
prints every entry point with its handler, firers and validation marks.

## Run

`$R lua ~/.claude/skills/rbx-net/scripts/net.lua` -> table `ENTRY | HANDLER | FIRED BY | type rate user dist reply`.
Marks are string-presence heuristics over the handler body: a row of `-` is a lead to test by hand,
not a verdict. Channels registered via a variable do not appear; say so.

## Adding an action (the only pattern)

1. Client: `Net.fire("channel", intent...)` with at most 4 args, values the server can re-derive (an id, a slot index, a side). Never a price, amount, level, position of record.
2. Server: `Net.handle("channel", function(player, ...)` -> type-check every arg (`typeof`, `tonumber`, `math.clamp`) -> ownership (`player.UserId` vs the thing) -> distance if physical (`Magnitude`) -> recompute cost/eligibility from server state -> apply -> `Net.reply(player, "channel", ok, reason)`.
3. Shared rule modules (`SkillTree.blockedReason`) so UI and server cannot drift.
4. Rate: the router budgets 12 calls per player per second across all channels (`BUDGET 12 / WINDOW 1 / MAX_ARGS 4`); a heavy action adds its own per-player cooldown inside the handler.
5. `rbx-verify` contract check: every `fire` has a `handle`, every `on` has a `reply/broadcast`.

## Review questions (every remote, written in the report)

- Who validates the args, and what happens with `nil`, `NaN`, `-1`, `1e12`, a 50 KB string, a table?
- What does one spammed call cost the server (DataStore write? MemoryStore call? GetDescendants?)
- Can the client reach the reward without doing the work (fire the claim without the collect)?
- Is the server the source of the number (price, damage, position), or is it echoing the client?
- Raw remotes outside the router: why not a channel? If a RemoteFunction: it cannot be wrapped by a guard; is it self-throttled?

## Anti-cheat stance

- Zero false positives first. Tier 1 (unambiguous: teleport, humanoid tampering, constraint injection, impossible vY) -> hard strike. Tier 2 (ambiguous: hover, speed, wallkick edge) -> soft strike, setback only; repeated soft strikes inside a decay window escalate to one hard.
- Payload bombs (over caps) = instant kick; rate violations = strikes with decay.
- The packet layer can be spied from below Luau; wire-opacity is not security. The only defence is server-side re-derivation of every remote.

## Red flags

- `Net.fire("buy", price)` - a value, not an intent
- A handler with no `typeof` and no cooldown
- A new RemoteEvent instead of a channel, with no stated reason
- "The client already checks it"
- A rate-limit that punishes a player using two panels at once (per-action cooldowns instead of a window budget)
