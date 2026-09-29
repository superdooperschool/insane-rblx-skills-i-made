---
name: rbx-release
description: Use before publishing or shipping a Roblox place build, before an update goes live, after an overnight build, or when asked "is it ready", "anything left on", "audit before release". Also use to find leftover debug switches, dead assets, exposed credentials, live post-effects, and disabled features.
---

# rbx-release

**One script, one table, every `!` line explained.** A real pre-release audit found live DOF in
every zone, a plaintext bearer token in a ServerStorage module, two dead 1,377-line DataService
copies replicated to clients, a 4,981-descendant unreferenced asset folder, a free-model "anticheat"
LocalScript with `loadstring`, `AUTO_OPEN = true` opening a 3,862-instance panel on every join. None
would have shipped with this list.

## Run

```
$R lua ~/.claude/skills/rbx-release/scripts/release.lua      # Edit datamodel, read-only
$R lua ~/.claude/skills/rbx-verify/scripts/verify.lua        # compile + contract + flags
$R lua ~/.claude/skills/rbx-net/scripts/net.lua              # every entry point has a validated handler
```

## Checklist (script covers the first block; the rest is by hand)

**Scripted**: `GlobalShadows`, every `PostEffect` Enabled
state (DOF/Blur enabled = `!`), `print()` count, debug flags (`FAKE/DEBUG/AUTO_OPEN/TEST/BYPASS/GOD/SKIP = true`),
admin/chat-command scripts, disabled scripts, test/probe/debug-named instances, HttpService callers,
disabled ScreenGuis, full-screen opaque frames visible on spawn, loose unanchored parts, Sounds > 3
volume, StreamingEnabled, RespawnTime.

**By hand, each time**:
- Zone/lighting presets copy the non-tweenable `Enabled` bool (`ZoneLighting.applyPreset`), blur 0 in every preset.
- No plaintext tokens/keys anywhere (`$R find "Bearer"`, `find "api."`, `find "key ="`): secrets via `HttpService:GetSecret`.
- No duplicate module copies in ReplicatedStorage of server-only code (`$R find "DataStoreService" --path ReplicatedStorage`).
- ReplicatedStorage descendant count < ~2,000; asset kits parked in ServerStorage (`_ParkedWorld`).
- ReplicatedFirst holds only what must load first; no unnamed Actors, no free-model scripts (`find "loadstring"`, `find "getfenv"`).
- Shop products: every card has a real ProductID (hide when 0), no placeholder icons on live cards.
- Dead asset ids (404 sounds/images) removed; HUD icons are the intended art.
- Disabled scripts: each is either archived or explained (8 of 34 were real features once).
- Hidden panels (`Panels.HIDDEN`) are intended for this release.
- Admin commands gated `RunService:IsStudio() or rank >= 254 or ADMINS[userId]`.
- Analytics/debug HUDs (`GrassAnalyticsHUD`) off. Studio-only conveniences off.
- MaxPlayers vs capacity of per-player world objects (7 plots vs 60 players).
- `rbx-net` table: every `net:` row has a handler and `type`+`rate` marks or an explanation.
- rbx-verify `!` rows = 0. `ui` audit on panels touched this cycle. A `client_fires_unhandled_channel` row is confirmed with `$R find "<channel>"` first: handlers registered through a variable (`Net.handle(CH.x, ...)`) are invisible to the scanner and are not a blocker.
- STATUS/HANDOFF updated; "what is unverified" listed for the user.

## Report shape

`RELEASE: <ready | N blockers>` then a table `Check | Result | Action`, blockers first. Nothing else.

## Red flags

- "Looks fine in Studio" (Studio never applies zone presets: DOF was invisible there for weeks)
- A `!` row left in the output without a sentence
- Skipping the by-hand block because the script passed
