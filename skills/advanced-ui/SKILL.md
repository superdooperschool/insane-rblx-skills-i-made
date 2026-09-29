---
name: advanced-ui
description: Use when a Roblox GUI must feel premium or game-like rather than a static panel - full-screen menus, skill trees, maps, zoomable/pannable canvases, juicy purchase or unlock animations, hover tooltips, entrance/exit transitions, procedural animated backgrounds, muffling game audio behind a menu - or when a UI feels snappy/cheap, text renders tiny or clipped, elements overlap on hover, zoom drifts to a corner, or sounds are too loud.
---

# advanced-ui

## Overview
Premium UI = choreography + restraint. Every motion has anticipation, overshoot capped by layout, and a smooth return; every state change has sound; nothing overlaps; the game behind goes quiet. Proven on a shipped galaxy rebirth tree (hex canvas, nested trees, BUY ALL, warp entrance).

**REQUIRED:** `rbx` for Studio transport. `ui` for house palette. User taste rules from memory override defaults here.

## Quick Reference

| Need | Pattern | File |
|---|---|---|
| Full-screen mode | own ScreenGui DO 90, tag+hide higher guis, hide CoreGui chat/list/backpack, touch controls off; restore ALL at END of exit | patterns.md#immersive |
| Zoom/pan canvas | Canvas Frame + UIScale, world offsets, one RenderStepped | scripts/Cam.lua |
| Camera feel | spring follow (k 7.5), backInOut flights, focus centred, symmetric safe margins, drag eases + inertia | scripts/Cam.lua |
| Tight graph layout | fix DATA shape first (<=3 kids), then backtracking hex solver | scripts/Layout.lua |
| No overlap | draw at 0.93 of spacing; every hover/bounce <= 1/0.93; juice via icon punch inside | patterns.md#overlap |
| Readable text in scaled canvas | TextScaled off, TextService fit, manual 2-line wrap, TextWrapped=false | patterns.md#text |
| Tooltip | CanvasGroup, bright card in item colour, black border, breakout icon, status chip, lerp-follow, 0.2s hide delay | patterns.md#tooltip |
| Juice kit | flash, ring, hexWave, burst, starburst, shatter, converge, flyer, popText, confetti sim, hyperspace, hexGrid/Cover/Pulse/Reveal, beam | scripts/Fx.lua |
| Animated bg | ring Frames rotate (children inherit), parallax layers, twinkle, shooting stars, spin kick | scripts/Space.lua |
| Purchase flow | optimistic pred + FIFO queue (server cooldown), display-owned vs truth, batch remote for buy-all | patterns.md#purchase |
| Menu audio | tag own sounds, soften (0.55 vol + mild EQ), duck everything else into nested SoundGroup w/ Muffler | patterns.md#audio |
| Entrance/exit | keep simple: streaks+portal, flash, title slam, converge core, ring ripple; exit = fold into core, implode, zoom in | patterns.md#choreo |
| Prove it | Edit-mode setfenv harness + captures, compile-gated push | scripts/harness_example.lua, scripts/push.sh |

## Motion rules
- Hover 0.3-0.4s Quint in AND out; never < 0.2s (user: "too snappy").
- Pops: tween to peak (<=1.04) Quint, then settle Quad. No Elastic/Back past the gap.
- Scale pivots on AnchorPoint: centre-zoom layers need AnchorPoint 0.5 + Position 0.5.
- Stagger reveals by distance from the cause (0.05-0.07s each).
- Sound on every state change; pitch rises with depth/combo.

## Common Mistakes
| Symptom | Cause | Fix |
|---|---|---|
| Text 6px in 22px box | TextScaled computed during UIScale pop, never recomputed | fixed TextSize (world units) |
| 2-word name shows 1 word | TextScaled=true forced TextWrapped=true; wrapped labels drop overflow lines | TextWrapped=false |
| Zoom slides to top-left | UIScale on AnchorPoint(0,0) frame | anchor 0.5,0.5 |
| Hexes overlap on hover/buy | scale > gap | cap scale, punch the icon |
| Dark slate tooltip "looks ass" | ignores game palette | bright card in item colour |
| Music not muffled / fights zone fades | per-sound Volume or missed runtime sounds | nested SoundGroup + DescendantAdded |
| Menu HUD pops over exit anim | restored hidden guis at exit start | restore at end |
| BUY ALL "1 READY" lies | counted single-affordable, not plan | count = #plan() |
| Script broke silently | raw newline in Lua string from heredoc | Write-tool patch scripts + push.sh gate |
| Stray badge in shipped UI | preview samples left in StarterGui | preview in harness clone only; leftover check |
| Half a tile stuck top-left ("me") | template Frame inside a Folder in a ScreenGui still renders | template `Visible=false`; clones set Visible |
| "Pop is not a valid member" in Play | tween Completed callback runs after the view was destroyed | check `v.dead` / `f.Parent` in every delayed or Completed callback |
| Banner/title fade-out looks cheap | transparency fade | exit = shrink + rise (Back In), then hide |

Details, code and recipes: `reference/patterns.md`. Drop-in modules: `scripts/`.
