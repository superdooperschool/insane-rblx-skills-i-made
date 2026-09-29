---
name: rbx-data
description: Use when adding, changing or debugging anything a Roblox place persists or shares - DataStore profiles, new saved fields, attributes on players, MemoryStore, cross-server state, receipts, migrations, "my data reset", "the last attribute vanished", or when a module cannot be required in Edit because of BindToClose.
---

# rbx-data

**One raw number persisted, everything else derived; four hooks per field; 1024 bytes per instance.**
`reference/patterns.md` has every rule with its origin. `scripts/attrbytes.lua` measures the cap.

## The four hooks (every new persisted field, no exceptions)

`DataService`: `defaultData` (shape) -> `sanitise` (drop unknown ids, clamp to caps, force owned
starter, string keys, 200-char strings to nil) -> per-player seed in `onPlayerAdded` -> `snapshot`.
A field missing one hook silently resets on join (mutation slots did, for weeks).

## Rules

| Rule | Why (measured) |
|---|---|
| Persist `Xp` only; Level and stats derive from a curve function | retune = no migration |
| XP and coins come from the bank/sale action, never the pickup | pickup XP was farmable |
| A profile that failed to load is never saved (`loaded` gate) | outage would overwrite with defaults |
| `StudioAccessToApisNotAllowed` is permanent: warn once, disable store, keep saving OFF | retry loop is pointless and dangerous |
| `UpdateAsync`, never Get+Set pairs; every store call in `pcall` with backoff; check `GetRequestBudgetForRequestType` | multi-server races lose data |
| Loaded values are the instance's creation default, not set-after | `.Changed` fires a fake "+5000" pop on join |
| Sparse tables use string keys (`Mut["3"]`) | numeric sparse arrays do not survive JSON |
| `addCoins` multiplies by VIP/2x/RebirthBonus; player-to-player settlement writes `Coins.Value` + `touch` | routed trades minted coins (100 paid, 291 banked) |
| `ProcessReceipt`: grant + mark PurchaseId + flush BEFORE `PurchaseGranted`, else `NotProcessedYet` | duplicate grants |
| Renaming a store (`_v1` -> `_v2`) is a reset without a wipe; reverting restores | - |
| **Attributes: 1024 bytes per instance total; overflow silently drops the LAST write** | 15 quest attrs on Player killed `QuestResetAt`; 20 plot slots errored |
| Blocks of attributes go on a child `Configuration` (own 1024) or one packed `StringValue` | mutation slots 482/1024 on their own Configuration |
| Anything created on join needs client `ChildAdded` rebinding | client scripts load first |
| MemoryStore is not durable: mirror escrow into the profile in the SAME tick, before any yield | orders hold real property |
| Cross-server: collect-on-demand, `SortedMap:UpdateAsync` is CAS | another server cannot write your live profile |
| MemoryStore records: fixed string fields, never numeric keys; archive to a DataStore for >eviction window | `BazaarDaily_v1`, keep 90 |
| Session-only state is documented as such | reward bitmask, roll history |

## Workflow

1. Grep MAP.md for `DataService`, `defaultData`, `sanitise`, `snapshot`: find the four hook sites.
2. Add the field in all four; `sanitise` first (it runs on every load).
3. Attribute plan: `scripts/attrbytes.lua` on Player and any Configuration; stay under 500 bytes per instance.
4. Verify with the `rbx-verify` harness (`reference/harness.md` in that skill): stubbed store, deep-copy round trip, scenario asserts. `DataService` cannot be required in Edit.
5. Live store: read before write, scratch key never a real UserId, user confirms any migration ("it will just default" only if they said so).

## Red flags

- A new `SetAttribute` on Player without a byte count
- `require(DataService)` in a `lua` call
- A field added to `defaultData` only
- Migration answer "it will just default"
- `GetAsync` then `SetAsync`
