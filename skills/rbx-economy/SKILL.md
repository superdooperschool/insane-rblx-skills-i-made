---
name: rbx-economy
description: Use when tuning or designing any Roblox progression or economy number - XP curves, level pacing, prices, upgrade ladders, rebirth/gem payouts, drop odds, income rates, zone gates - or when a player "levels too fast/slow", coins inflate, or a multiplier stacks. Also use before touching GameConfig / LadderConfig / EggConfig.
---

# rbx-economy

**Tune with a table, not a feeling.** `scripts/curve.mjs` turns a curve or a price ladder into
time-to-level / cumulative-cost rows.

## Rules

| Rule | Origin |
|---|---|
| Time-anchor the level curve: `{level, minutes}` anchors, monotone cubic between, one `DesignXpPerMinute` | Example ladder: L10=10m, L50=1h, L100=5h, L150=10h, L200=15h, L1000=150h cap |
| Persist one raw number (`Xp`); level derives. Retune = no migration | shipped in two games |
| Power curves, never geometric: `cost(L) = max(A * L^k, floor)`, solve A from one anchor | geometric 1.9^L made L80 a 23-digit number |
| XP/coins on the bank action, not the pickup; per-second caps on the source | pickup XP was farmable; server caps 6 blades/s |
| Every payout has ONE multiplier chain, written down; player-to-player trades have none | `addCoins` x VIP x 2x x Rebirth minted coins on trades |
| Flat, capped bonuses for combos (`min(combo*3, 30)`) so other systems cannot multiply them | combo x grass-gain exploit |
| One global scale per subsystem (`Bazaar.VALUE_SCALE`, `Economy.SaleMult`, `GemTree.priceScale`) as the retune dial | coins were 4000/min at L1 until `SaleMult 0.15` |
| Batch caps on claims (`RebirthMaxBatch 20`) | one press granted 1500+ gems |
| Odds tables sum to 1 including "nothing"; show "1 in N" from the same table the roll uses | MutationRoll declared sum 0.956 |
| Gates read account Level + Rebirths only (nothing extra persisted) | retune moves every account instantly |
| Numbers flagged "guess" stay flagged until a table says otherwise | zone gates 6k/20k/2.5M |

## Gotchas (check before trusting any number you read)

- `GameConfig` **TUNING table in code silently wins** over the same-named Value instance; keep it `{}`. Value instances override code defaults (`Ball.GoBackCooldown` 20 vs code 3): read `ReplicatedStorage.GameConfig.<Category>` before `GameConfig.get` fallback.
- `UPGRADE_COST_LADDER` is hardcoded and ignores both.
- New `LadderConfig` entries are invisible to `levelFor`/`unlocked` until `Ladder.reload()`; `require` caches per session (`RBX.req`).
- `MaxLevel` set in the explorer overrides the code cap (showed 50/25 for a cap of 4).
- "3-hour full clear" style claims are estimates until measured; label them.

## Workflow

1. Grep MAP.md / `$R find` for the config key; confirm which of code default / Value instance / TUNING actually wins (`$R lua` reading `GameConfig.get` fresh via `RBX.req`).
2. `node scripts/curve.mjs power --A 1.61 --k 2.2 --floor 40 --max 1000 --rate 200` (or `anchors`, `ladder`, `geo`) and paste the rows into the report.
3. Edit the one dial. Never a second copy of a number.
4. `rbx-verify` fresh-require asserts on 3 sample levels/prices.
5. Report: before/after table, the dial changed, what stays an estimate.

## Red flags

- Editing a number without knowing which of the three sources wins
- A curve with no time anchor
- A new multiplier added to an existing chain "just for this"
- "Feels about right"
