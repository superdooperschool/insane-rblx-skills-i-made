# advanced-ui patterns

Every rule below fixed a real defect in a shipped build. Section anchors match SKILL.md.

## immersive
Full-screen mode that replaces the game view (tree, map, collection book).

- Keep the existing panel system as the trigger (`Frames.X` + `open` attribute) and make that frame an empty stub. Drive a separate `ScreenGui` (`IgnoreGuiInset`, `ResetOnSpawn=false`, `DisplayOrder 90`, `Enabled=false` in StarterGui).
- On enter: disable every PlayerGui ScreenGui with `DisplayOrder >` yours (except Tutorial), tag each with attribute `HiddenByTree`; restore by the tag (survives respawn/script restart).
- `StarterGui:SetCoreGuiEnabled` off for Chat, PlayerList, Backpack, EmotesMenu - remember only the ones YOU turned off, keep the list across a fast reopen (`S.core = S.core or {}`). The Roblox menu button cannot be hidden.
- `GuiService.TouchControlsEnabled = false` while open, restore previous value.
- Restore hidden guis/CoreGui at the END of the exit animation, never at its start (they draw over your exit).
- Every delayed step checks an `openToken` so close/reopen mid-animation never half-applies.

## camera
`scripts/Cam.lua`. World lives in `Canvas` (Size 0, AnchorPoint 0) with a `UIScale "Zoom"`; nodes use offset world units. Camera writes two properties per frame: `Zoom.Scale` and `Canvas.Position = (W/2 - x*z, H/2 - y*z)`.

- Follow = exponential spring (`k = 1 - exp(-dt*7.5)`), zoom interpolated in log space.
- Flights = `backInOut(t, s)` on position (built-in anticipation + overshoot, `s` 0.3-1.4) + smoothstep log-zoom with optional mid-flight dip. A new flight or user input cancels the old one and fires its `done`.
- `focus(x, y, span)`: node centred on SCREEN centre, zoom so `span` node-widths fill min(safeW, safeH). "Big node not zoomed enough" = span too large.
- `fit(rect, pad, maxZ)`: symmetric safe margins (L/R 0.07, T 0.08, B 0.1) - asymmetric margins read as "off-centre".
- Input: drag sets TARGET only (spring smooths it); track velocity with lerp 0.35; on release glide `target -= vel*0.2/z` if released < 80ms after last move. Wheel = `zoomAt(cursor, 1.15)`. Pinch uses `TouchPinch` scale vs zoom at Begin.
- Min zoom from viewport: `minZ = max(vpY*0.06, 34px) / nodeHeight` so phones never shrink nodes to dots.
- `AbsolutePosition` and `InputObject.Position` share GUI space - do NOT add `GetGuiInset()`. Screen-layer child position = absolute - layer.AbsolutePosition.

## layout
Hex/graph layouts fail on DATA, not on the solver: a node with 31 children cannot touch them all (6 neighbours).
1. Restructure: root <= 3 children; branches fork off tier 2/4 of earlier branches (fishbone: branch i>3 hangs off branch floor((i-4)/2)+1); extra content goes into child boards behind portal nodes.
2. `scripts/Layout.lua`: DFS placement, continuation child (same id stem) goes straight, forks turn +-60deg alternating by depth, full backtracking with budget, greedy nearest-free fallback. Try all 6 root directions, keep the best fit for the viewport aspect. < 1 ms per 70-node board.
3. Verify with numbers: overlaps 0, every node hex-distance 1 from parent, greedy fallback not used.
4. Positions come from the full board (stable as you buy); camera fits only visible nodes.

## overlap
Tiles that touch must NEVER overlap, including during animation.
- Draw each hex at 0.93 of grid spacing (thin dark gap like reference sims).
- Any scale on a tile <= 1/0.93 ~ 1.07; use 1.035 hover, 1.04 bounce peak.
- `bounce(f, from, peak, up, down)`: Quint to peak, then Quad back to 1 - replaces Back/Elastic.
- Juice without overlap: `iconPunch` (icon 0.6 -> 0.42 Back), rim colour, shine sweep, shadow lift inside the gap.
- Hovered tile ZIndex up (30), restored after its out-tween.
- Selection outline sits ON the rim (ring image at 1.01 scale above fill), not outside it.

## text
- `TextScaled` computes size once; a later ancestor `UIScale` change (pop-in from 0) leaves it tiny or clipped. Inside any animated/zoomed container: `TextScaled=false`, set `TextSize` in world units, fit with `TextService:GetTextSize` (GothamBold approximates GothamSSm - fit to ~55% of tile width).
- Setting `TextScaled=true` flips `TextWrapped=true`; a wrapped label silently DROPS lines that overflow its height. Builders that default TextScaled must set `TextWrapped=false` explicitly.
- Two-word names: split at the space nearest the middle (`string.char(10)`), smaller size for 2 lines.
- Scale-animate HUD text by tweening `Size`/`Position`, never a UIScale.

## tooltip
- `CanvasGroup` so `GroupTransparency` fades the whole card; everything must stay inside its bounds (breakout icon = inside the group, above the card top).
- Style in the game's palette: bright gradient card in the item's kind colour, 3px black border, faint checker tiles, top gloss, white text with black stroke, icon hex breaking out of the top-left at -8deg, status chip (green OWNED/FREE, lime BUY+price, red short, blue ENTER/GO BACK, grey LOCKED).
- Follow: target above the node (flip below if clipped), `pos = pos:Lerp(target, 1-exp(-dt*14))`; first show fades + lifts + rotates -4 -> 0 (Back); switching nodes dips transparency and nudges rotation instead of hiding.
- Hide with a 0.2s delay token so moving between neighbours glides instead of flickering.
- Touch: one tap acts; show the tip for ~1.3s after.

## states
One palette per kind, state = variant:
| State | Look |
|---|---|
| owned | full colour, no price |
| buyable | full colour, price, shine sweep across fill, rim pulse white<->pale gold |
| short | desaturated fill, red price, dim icon |
| unknown | dark glass (fill 0.18 transparent, rim 0.3), big "?" - reveal by SHATTER (shards + flash), never fade |
| teleport/portal | yellow, X/Y progress, notification badge, periodic hop |
Kinds: blue normal, purple capstone, yellow anything that moves you (portal, sub-tree root/back).

## badges
Clone the game's own notification (e.g. `HUD.Left.Shop.ExclamationMark`) for every badge; add UIScale "Pop"; count text with fixed TextSize. Tiles with a badge hop every ~2s (scale <= 1.035, rotation +-2.5deg), badge bobs harder. HUD opener badges count only real purchases (skip portals and free non-root nodes).

## purchase
- Client keeps `truth` (replicated), `pred` (in-flight, priced), `shown` (display-owned, advanced at impact). `owned[id] = truth or pred` via metatable so rule functions (blockedReason) see predictions; wallet = value - pending prices not yet in truth.
- FIFO request queue with spacing > server cooldown (0.17s vs 0.15s): rapid clicks never get "too fast".
- Flow: click sound + squish -> camera flight (0.5s) while currency flyers travel from the wallet widget (bezier, target recomputed per frame from camera) -> wait result -> impact at the END (bounce, icon punch, flash, hex wave, ring, burst, stat popText) -> refresh reveals children staggered by distance -> camera nudges to include new children (never zoom in).
- Failure: roll back pred, denied sound, shake.
- Buy-all: simulate cheapest-first (price / wallet) on a copy; ONE batch remote; tour marks all (hidden ones as "?"), fly node to node shattering "?", zoom out, collect each with a small gap and rising pitch, then finale. Button count = plan size, "i/N" while running, "SKIP >>" doubles speed.
- Finale: camera punch (1.1x then settle), screen flash, 3 hex waves, starburst, burst, confetti sim, wave-bounce every bought tile by distance, banner + stat summary line.

## audio
- Own sounds: `soften()` = tag `TreeSfx`, volume x0.55, EqualizerSoundEffect (-8/-4/+1). Route through the game's sound module (`UISound.play`, `UISound.transient`) so the SFX volume/mute setting applies.
- Library sounds: clone from `SoundService.Sounds`; names can contain stray newlines - resolve by prefix.
- Background: move every Sound that is not tagged (workspace, SoundService incl. Music and library templates, PlayerGui) into a `TreeDuck` SoundGroup created as a CHILD of its original group (nesting keeps the original volume), carrying a clone of `ReplicatedStorage.Muffler` gains + volume 0.6, tweened in 0.8s. `DescendantAdded` (deferred) ducks sounds created while open. On close tween back, then restore each sound's group. Never touch `Sound.Volume` of music: zone scripts own it.
- Edit-mode tests leave `TreeDuck` groups behind: destroy them after testing.

## background
`scripts/Space.lua`: sky UIGradient, nebula clouds (soft glow sprites drifting), 3 parallax star layers, spiral arms as N ring Frames each holding arm stars; per frame only ring rotations + a few twinkles. Rotation is inherited by children. `Space.kick(speed)` adds decaying spin (entrance/exit). Half the sprites on touch devices. Root AnchorPoint 0.5 so the warp UIScale zooms from centre.

## choreo
Default (user-approved, keep it this simple unless asked): 4 beats in, 4 out, each with its own sound.

Entrance (~2s): veil dims game + `Fx.hyperspace` streaks + spinning portal hex ring and glow (0-0.62s, riser whoosh) -> white flash + soft ring blasting outward, background visible with warp 1.9 -> 1 (UIScale on a centre-anchored root) and `Space.kick` spin, HUD slides in -> gold title slams (Size 1.3x -> 1, -7deg -> 0, Back) with a live stat sub-line, floats away after 1.5s -> content: shards converge into the root (`Fx.converge`), root forms (flash, hex wave, burst), rings pop outward with ripples while the camera flies 1.7x -> focus, then settles on the fit once the flight lands.

Exit (~1.2s): HUD out -> tiles fold into the root outside-in with spin (Quint In) -> implosion flash + collapsing rings, background spins backward and ZOOMS IN while the veil darkens and audio unducks -> soft flash, veil clears, restore hidden UI, cleanup.

Optional heavier variant (user said "keep it simpler" - only on request): screen hex-wall wipe (`Fx.hexGrid/hexCover/hexPulse/hexReveal`), chromatic ghost title, canvas roll, children flying out of parents with `Fx.beam`, black-hole spiral exit. Code lives in `scripts/Fx.lua`.

Rules: every delayed beat checks `openToken`; canvas rotation always returns to 0 (tooltips/flyers assume no roll).

## harness
`scripts/harness_example.lua`: run the real LocalScript source in Edit with `loadstring` + `setfenv`: fake `game` proxy (Players.LocalPlayer = proxy over a Folder with Gems/Coins/Data, PlayerGui proxy returning a cloned ScreenGui), fake remotes with the server's rules and cooldown, stub sound module (count voices, destroy transients), fresh clones of required modules, and a return tail exposing internals. One call returns sorted `key = value` booleans. Keep-mode stashes state in `_G` for captures; always run a cleanup + leftover check (harness GUIs, sample nodes, duck groups). Harness GUIs are clickable in the user's viewport.

## workflow
- `scripts/push.sh <file> <game.Path>`: loadstring compile in Studio, abort on error, then hash-verified write. Never write unchecked source.
- Patch big scripts with Python files written by the Write tool (region replace between two anchors, `assert count == 1`). Inline bash heredocs collapse backslashes (`\\n` became a real newline inside a Lua string).
- Split past ~200 locals: controller + Layout/Cam/Fx/Space modules (created via `multi_edit` with `className`).
- Build static instances with one builder script (re-runnable, destroys and rebuilds); keep contract names stable.
- Capture after every visual change; read the image; fix what it shows.
