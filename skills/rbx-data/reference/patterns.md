# patterns - persistence rules with their origin (three shipped games)

## DataService shape

- Self-starting ModuleScript in ServerScriptService owns all persisted state and the mirrored instances (`player.Coins`, `player.Data.Owned.<x>`, `player.Data.Levels.<ball>.<stat>`).
- Store name `<Game>_v1`, key `p_<UserId>`. Autosave 120 s, save on `PlayerRemoving`, flush in `game:BindToClose` (needs a real wait in Studio).
- `profiles[player].loaded` gates `save()`. `profiles[player]` had no `data` field despite a comment; `loaded` is false for everyone with no store connection - a full debugging cycle was lost to that.
- Studio needs Game Settings > Security > Enable Studio Access to API Services; without it every call throws.
- 4-hook pattern per field: `defaultData`, `sanitise`, seed in `onPlayerAdded`, `snapshot`. Used for Bazaar, Trails, Plot, Mut, Retention. `MutationRoll` persisted nothing for weeks because `setup()` wiped slots on join with a TODO.
- Two duplicate `ReplicatedStorage.DataService` copies (1,377 lines each) replicated the whole save layer to clients while every server call site used the ServerScriptService one. Destroyed 2026-09-22. Grep for duplicates before trusting a path.
- `NotificationService` uses Open Cloud with Secret `notify_key`; telemetry token moved to `HttpService:GetSecret("telemetry_token"):AddPrefix("Bearer ")`. No plaintext credentials in a place file.
- `WeeklyLadder_<weekId>` is an OrderedDataStore, weeks anchored Monday 00:00 UTC.

## Attributes

- Cap 1024 bytes per instance; past it `SetAttribute` silently refuses; the LAST write vanishes, earlier ones stay.
- Real: Player carried 15 `Quest<i>*` + mastery/zones/spins/combos/mutations/ladder attrs -> `QuestResetAt` threw at `ProgressionService:165`.
- Real: 20 plot-slot attrs errored at `PlotService:90`; packed into one StringValue `plot.Slots` = `"1=r|hatchAt|name|x|y|z|size;5=..."`.
- Child `Configuration` = its own 1024. Mutation slots `S1..S25`/`L1..L25` measured 482/1024 worst case.
- No Instance/table/function attribute values. Unknown attribute names are legal and warn once: a renamed attribute makes an objective silently uncompletable.
- Preflight flags > 500 B as `attrHot`. Exact test = write, then read back in a separate call.

## Economy integrity

- `DataService.addCoins` multiplies every positive amount by VIP, 2x Coins pass, RebirthBonus. Only game payouts (harvest, golden pickups, offline) may use it. Player-to-player settlement writes `Coins.Value` and calls `DataService.touch`.
- A payout multiplier destroys the unit of account: NPC vendor pays flat `Bazaar.value(id)` to everyone.
- `a and b or c` is not a ternary: with a boolean middle term it falls through. Shipped a matching bug (sell at 900 filled a bid at 200). Explicit if/elseif.
- Order-book keys: ask `%012d` price, bid `MAX_PRICE - price`, ms stamp appended; one ascending range scan serves both sides.
- Defenses used instead of price collars: self-trade prevention, per-channel rate limit, 3% seller fee.

## MemoryStore

- Not durable, expires. Escrow mirrored into `prof.Bazaar[orderId]` in the same tick the item/coin is taken, before any yield; `k` nil until posted; nil `k` on rejoin = refund; ledger `q` decremented inside the fill callback.
- Collect-on-demand: fills accumulate in the shared record (`c` coins owed, `f` items owed); the user's own server claims them. `SortedMap:UpdateAsync` is CAS.
- Numeric table keys do not round-trip; use `s`/`m`/`h` named fields. Days archived to `BazaarDaily_v1`, one key per item, keep 90.

## Save discipline

- Team Create keeps edits; some places need a manual Ctrl+S. State which in STATUS.
- Real DataStore paths: user confirms first; read before write; scratch keys only while iterating; never write from a probe still being edited.
