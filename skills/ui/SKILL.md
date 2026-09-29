---
name: ui
description: Use for any Roblox GUI work in Studio - "improve / restyle / revamp <X> ui", new panel, HUD element, shop, list, popup, card, button, mobile fix - or when UI looks off-style, flat, dark-slate legacy, offset-sized or inconsistent. Makes it match the user's Sky Checker look (sky-blue shell, blue checker tiles, loud gradient buttons, red image close). Roblox-specific; loads with rbx.
---

# ui - Sky Checker

"Improve X ui" = rebuild X's instances in the user's **Sky Checker** look, keep every name its
scripts use, prove it with the audit + one render. **Instances only**: never create or edit a
LocalScript / ModuleScript unless the user asks; read scripts only to learn the contract.

**Reference** (hand-authored reference UIs): `CapsuleHUD`, `CapsuleInfo`,
`CapsuleReel`, `Frames.{BallInventory, BuyBack, Card, Codes, Daily, Dex, Guide, MainTab, Merchant,
PlotManager, QuestsTalk, RaceLobby}`. Worked example: `Frames.RacePodium` (built by this skill).
Anything else with a dark slate `#14171F` look is legacy. Numbers: `reference/kit.md`. Exact shapes:
`reference/anatomy.md`. Builders: `scripts/sky.lua`. Runtime tweens (only if asked): `reference/motion.md`.

## Tokens (this skill must stay cheap)

- `S=<scratchpad>; R="node $HOME/.claude/skills/rbx/rbx.mjs"`; `--studio <id>` when 2 Studios.
- Recon = `dump.lua --out` then `grep`/`head`, never paste a whole panel into context.
- Never re-dump references: the numbers are in kit.md/anatomy.md. Read anatomy.md only for the archetypes you build.
- One build file, one `lua` call, one audit, one capture, one `Read`. No per-property calls.
- Do not read skill scripts back; their API is in kit.md.

## Recipe: improve / restyle `<X>` (6-8 Studio calls)

1. **Recon**: `sed "s|__ROOT__|StarterGui.Frames.<X>|" scripts/dump.lua | $R lua - --out $S/x.txt` -> `grep -v "UIStroke\|UICorner" $S/x.txt | cut -c1-160`.
2. **Contract**: `$R find "<X>" --studio <place with the scripts>` (UI place has none; scripts live in the game place). `$R read <script> --out`, then `grep -n "WaitForChild\|FindFirstChild\|\.Text\|TextColor3\|OfClass\|clear\|Destroy"`. Write down every child name + class + parent the script touches, and what its clear/render function destroys.
3. **Backup once**: clone `<X>` to `ServerStorage._<X>_old` (skip if it exists).
4. **Build** (`$S/build.lua`, run `cat scripts/sky.lua $S/build.lua | $R lua -`): keep the root frame (attributes, open state), destroy its children, rebuild with SKY: `SKY.shell(root, AR)` -> `SKY.header` -> body (`SKY.inset` / cards / `SKY.list` + `SKY.row` Template) -> buttons. Every contract name stays at the same parent and class. Return a contract check (FindFirstChild each name).
5. **Audit**: `sed "s|__ROOT__|StarterGui.Frames.<X>|" scripts/audit.lua | $R lua -` -> `ISSUES: 0`.
6. **Preview**: one `lua`: clone Template x3-5 with realistic data (long + short names, medal/state colours the script sets), `Visible=true`; `$R capture --dir $S/c`; `Read` once; second `lua` destroys samples, `Visible=false`.
7. **Fix what the render shows** (tile scale, text sizing, alignment), re-audit. Report: contract kept, backup path, and "copy `<X>` to the game place" if built in the UI place.

**Bulk / legacy restyle (cheapest path, use first):** `sed 's|__NAMES__|"A","B"|' scripts/reskin.lua > $S/rk.lua; cat scripts/sky.lua $S/rk.lua | $R lua -`. It re-skins every named `Frames` child by role in one call and never touches scripts or contract names: shell root, checker Header, image close, checker containers, loud buttons kept, loud cards tiled, legacy 3D layers (`Shadow/Foreground/Lines/...`) flattened, script-faded gradients left untiled, ScrollingFrames as insets, padded frames fixed with an `Inner` container (or offset tiles when children are script-referenced). Then loop the audit per panel in ONE Bash call and capture with isolation (hide every other Frames child + HUD, capture, restore) so the user's open panels never cover the shot.

New panel: same, but `SKY.frame(Frames, {Name=..., Size=..., Visible=false})` then `SKY.shell`; see `scripts/panel.lua`.

## Style in 12 lines (details kit.md)

- Root: white + gradient -90 `#C7F2FF->#B8E6FD` + shell Tiles `131017184238132` (TileSize 1x1), corner 12, Border 2 black FixedSize, shadow 54, UIAspectRatioConstraint 1.14-1.6.
- Every inner surface wears child `ImageLabel "Tiles"` = checker `95676388705283` (opaque: it IS the colour), own UICorner = parent radius, ZIndex 1. Labels z2, button labels z3.
- TileSize keeps cells square: `SKY.tileSize(AR, rows)`. Header rows 2 (~`{0.05,0.5}`), row/strip 1-2, card 2, **inset body 4 (~`{0.15,0.25}`)**. Never 1x1 on anything but the shell.
- Header `0.94,0.12` at `0.5,0.03`; body `0.94,0.79` at `0.5,0.18`; 0.03 margins. Title left at `0.03`, `0.5,0.6`, `#EEF2FC`.
- Close: transparent 1:1 TextButton `0.09001,0.9265` at `1.015,0.4632` anchor `1,0.5`, ImageLabel `126722740435766` at 1.5x. Overhangs the header on purpose.
- Buttons: the TextButton itself is skinned: rot-90 gradient (action `#E5FF00->#00FFAA`, blue `#50AAFF->#2864E6`, danger `#FF5F5F->#BE1E28`, sell `#FF6868->#C4162E`, gold `#FFDD57->#FF9900`), corner 8 (pill `1,0`), Border 2, shadow 12, `UIScale`, `Label 0.9,0.72` z3 `#EEF2FC`.
- Neutral buttons/tabs/chips: checker TextButton, Border 2, shadow soft 10/0.5; selected = Border + text outline `#5B98C2`.
- Inset (sunken body): gradient `#628FBE->#6297C7`, Border 3 `#4E75AC`, checker 4-tall.
- Rows: `0.97,1` + UIAspectRatioConstraint 7-20, checker, corner 8-12, shadow 12 (lobby) / 10 (dense list), `UIScale "Pop"`.
- Text: GothamSSm Bold, TextScaled, white / `#EEF2FC`, Contextual stroke 1.5 black. Muted `#A0AABE`, column titles `#BEC6DC`, prize gold `#FFD63C`, progress green `#54FF1A`, error `#FF8282`.
- Shadows: panel 54 | card 12 | drop 15 t.5 off(-5,5) | soft 10 t.5 | glow 35 `#A9D6F4` t.26.
- Scale only. Zero offsets anywhere (Size, Position, UIPadding, list Padding).

## Traps learned (each cost a rebuild once)

- A child named `Name`/`Size`/`Position` is shadowed by the property: `row.Name` is a string. Always `FindFirstChild`.
- Scripts use non-recursive `FindFirstChild`/`WaitForChild`: contract children stay DIRECT children. Decorations (badges, plates) go in as siblings at a lower ZIndex, never as wrappers.
- List `clear()` functions usually destroy every child except `Template`/`UIListLayout`: never put a `UIPadding` inside a script-filled list; inset the ScrollingFrame's rect instead (`SKY.list(..., gap, false)`).
- Tiles inside a ScrollingFrame scroll with the content: put the checker on an `SKY.inset` frame behind, the transparent list on top with the same rect at z3.
- Column heading strip must line up with rows: width = list width x row width (0.94 x 0.97 = 0.912 of panel); drive heading and row from one `COLS` table.
- TextScaled free text (names) renders short strings huge: add `UITextSizeConstraint` (~48) to that column only.
- Header tile AR = `0.94 * panelAR / 0.12`; inset AR = `0.94 * panelAR / bodyHeight`.
- `UIKit.skin` paints legacy slate: never on Sky UI. A bare UI place has no modules; SKY needs none.
- Items flush with a ScrollingFrame edge get their Border clipped: row holders `0.96` wide (list centres them) + top/bottom pad `0.012` when the script never clears the list.
- Lua threads cannot reparent scripts: when a container holds a LocalScript (`RebirthUI`, `CloseButtonStore`), keep that container instance and restyle it in place (strip its non-script children, re-skin); never destroy it.
- Scripts that tint `FindFirstChildOfClass("UIStroke")` get the FIRST stroke: create the Border stroke before any other UIStroke on that object (rank-tinted button borders: thickness 3).
- Arrow asset `100517744926951` renders blank on its own: use an action-gradient pill badge with a `>` label instead.
- Legacy Border strokes can be `StrokeSizingMode ScaledSize`: setting Thickness 2 on those paints a black slab. Always force `FixedSize` when normalising a Border stroke (audit: `scaled_stroke_slab`).
- UIPadding pads Tiles too (inset checker, white rim). Fix with an `Inner` container holding the content + padding, or, when a script references those children, offset tiles: `Size 1/(1-l-r), Position -l/(1-l-r)`.
- A panel saved mid-close-tween has `Size 0,0` and an off-screen Position: AbsoluteSize is 0, so tiles fall back to generic sizes. Restore an open size first, then skin.
- Script-faded gradients (Transparency keypoints > 0, e.g. level pips) must NOT get Tiles: opaque tiles would hide the fade.
- Capture only after `Visible=true` on the one target; always restore `Visible=false` and delete samples in the next call.

## Architecture (match it)

| Layer | Rule |
|---|---|
| ScreenGui stack | `Frames` (DisplayOrder 2) holds every panel; `HUD` 5; `Notification` 12; reels/banners 15-20; popups 30-50. New panel = Frame under `Frames`, never a new ScreenGui. `IgnoreGuiInset`, `ResetOnSpawn=false`, `ZIndexBehavior Sibling`. |
| Panel | `Frames.<Name>`, `Visible=false`, `open` attribute. Close = `Header.CloseButton` (Panels wires it). Opener = GuiButton with `OpensPanel="<Name>"`. |
| Templates | hidden `Template` inside its container; clones change only Text, colour, LayoutOrder, Visible. |
| Tunables | attributes on the panel frame; keep them on rebuild. |
| HUD | nothing in thumbstick (bottom-left) or jump (bottom-right) zones. |
| Responsive | Scale layout + aspect constraints; no root UIScale in the Sky look. |

## Red flags - stop

- Any non-zero offset; `fromOffset`; a Font other than GothamSSm Bold.
- A surface with no Tiles and no loud gradient; Tiles without its own UICorner; content at the Tiles' ZIndex.
- Checker TileSize 1x1 on a body; slate `#14171F` as a visible fill; a plate-and-X close button.
- Editing a LocalScript "while you're there"; renaming or re-parenting a contract child.
- Reporting done without `ISSUES: 0` and one rendered capture.
