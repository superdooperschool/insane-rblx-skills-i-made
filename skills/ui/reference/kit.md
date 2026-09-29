# kit - the Sky Checker look as numbers

Source of truth (2026-09-27): the user's hand-authored UIs in the reference UI place: `StarterGui.CapsuleHUD`, `CapsuleInfo`, `CapsuleReel` and `Frames.{BallInventory,
BuyBack, Card, Codes, Daily, Dex, Guide, MainTab, Merchant, PlotManager, QuestsTalk, RaceLobby}`.
1,341 instances dumped with **every non-default property** (ReflectionService), rendered, and
counted. Shapes: `anatomy.md`. Builders: `scripts/sky.lua` (`SKY.*`, below).

The old dark-slate Bazaar kit (`#14171F -> #1E222B` panels, plate-and-X close button) is **legacy**.
Any panel without the shell Tiles is pre-restyle, not a reference.

## The look in one paragraph

Pale sky-blue shell with an ornamental texture, black 2px outlines on everything, and every inner
surface is an opaque **blue checkerboard** texture. Colour comes only from loud gradient buttons
(lime, blue, red, gold), text accents (gold prizes, green progress) and a red glossy image close
button that overhangs the header's right end. White GothamSSm Bold text with a black 1.5 outline,
always TextScaled. Soft black drop shadows under every raised piece.

## Assets (the style is mostly these four images)

| Key (`SKY.IMG`) | Asset | What it is | How it is used |
|---|---|---|---|
| `shell` | `rbxassetid://131017184238132` | pale sky-blue ornament (arched pillars, bubbles, stars) | on every panel root, `TileSize {1,0},{1,0}` (stretched once). 12 of 12 roots. Merchant uses `{0.6,0},{1,0}` for a denser row of arches. |
| `checker` | `rbxassetid://95676388705283` | **opaque** two-tone blue checker, 2x2 cells per tile (reads as `#5B99C2`/`#69A9CB`) | every header, card, row, chip, inset. 59 uses. Tint with `ImageColor3`: `#939393` progress track, `#DADADA` soft card, `#E8E8E8` input, `#FFD8E1` pink alert panel. `ImageTransparency 0.34` over a gradient = tinted tab. |
| `stripe` | `rbxassetid://84682738767744` | translucent white checker overlay | always tinted, always over a loud gradient: `#AA0000` on red sell buttons, `#7EE3FF` on the shell-gradient picker, `#45FF55` on a green done header. `TileSize {0.1,0},{0.5,0}`. |
| `close` | `rbxassetid://126722740435766` | glossy red rounded square with a white X | the whole close button. 9 of 9 panels with a close. |
| `coin` | `rbxassetid://88118342477318` | coin icon | `ScaleType Fit` + `UIAspectRatioConstraint 1`, left of a price. |
| `tick` | `rbxassetid://6972510111` | check mark | objective tick, gradient `#00FF00 -> #A7FF33`. |
| `arrow` | `rbxassetid://100517744926951` | arrow | reel arrows (rot 180 for the other side). |

**The checker is opaque, so it IS the fill.** 24 containers still carry the legacy slate gradient
underneath a checker Tiles - it is invisible. Never read the colour of a checker surface from its
UIGradient; never add a gradient under a checker expecting it to show.

## Tiles layer (the one structural rule of this style)

Every textured surface has a child `ImageLabel` named **`Tiles`**:
`Size {1,0},{1,0}`, `Position 0,0`, `BackgroundTransparency 1`, `ScaleType Tile`, `ZIndex 1`, and its
own **`UICorner` equal to the parent's** radius (else square corners poke past the rounded border).
Content siblings sit at `ZIndex 2` (labels) / `3` (button labels) so they draw over the tiles.

**TileSize** - keep checker cells square in pixels:
`TileSize = {(1/rows)/AR, 0},{1/rows, 0}` where `AR` = the surface's pixel width/height.
`SKY.tileSize(AR, rows)` computes it.

| Surface | rows | User value |
|---|---|---|
| Header strip (AR ~11) | 2 | `{0.05,0},{0.5,0}` (Merchant `{0.035,0.5}` for AR ~14) |
| Heading strip / list row (AR 17) | 1 | `{0.07,0},{1,0}` |
| Card / chip / button-with-tiles | 2 | `{0.2,0},{0.5,0}`, `{0.25,0},{0.5,0}` |
| Tall day card | ~3 | `{0.5,0},{0.35,0}` |
| Tab / quest card | 1 | `{0.35,0},{1,0}`, `{0.4,0},{1,0}` |
| Inset body (AR ~1.7) | 4 | `{0.15,0},{0.25,0}` (Daily). Never `1x1`: one stretched tile = giant squares |

## Tokens

| Token | Value |
|---|---|
| Font | GothamSSm **Bold** (`SKY.FONT`). 163 of 163 labels, every button. Only font. |
| Text size | `TextScaled = true` (161 of 163). Cap with `UITextSizeConstraint.MaxTextSize` (47 caps: 12-20 small labels, 24-32 titles, 44-48 hero/big button). |
| Text outline | `UIStroke` Contextual **1.5 black** on every label (163). Quest panel variant `#10141E`. Long body copy: Contextual `0.05` with `StrokeSizingMode ScaledSize` (Stats, QuestsTalk Content, Merchant Content). |
| Border | `UIStroke` Border **2 black** on every container, button, chip, row, stamp (183). Panel root adds `StrokeSizingMode FixedSize`. Blue inset: Border **3 `#4E75AC`**. |
| Corner | **12** panel / header / card / section, **8** buttons, chips, inner rows, inputs; pill `UDim.new(1,0)` for tags, stamps, pill buttons; `UDim.new(0.3,0)` tabs & small badges; `UDim.new(0.5,0)` progress bars. |
| Shell fill | root `BackgroundColor3 #FFFFFF` + UIGradient **-90 `#C7F2FF -> #B8E6FD`** + shell Tiles. (BuyBack alert variant `#FFFFFF -> #D6E2FF`.) |
| Inset fill | UIGradient -90 **`#628FBE -> #6297C7`** + Border 3 `#4E75AC` + checker Tiles `SKY.tileSize(AR, 4)` (~`{0.15,0.25}`). Info-card variant adds a second Border 5 `#B0DBFA` (double ring). |
| Shadow (`UIShadow`) | ladder below. Always `Color #000000` unless it is a glow. |
| Z | root 1; Tiles 1 at every level; sections 2; labels 2; button labels 3; list over its inset 3. |

## Colour

**Loud gradients** (`SKY.FILL`, `Rotation 90` = top-to-bottom light->dark on buttons):

| kind | colours | used for |
|---|---|---|
| `action` | `#E5FF00 -> #00FFAA` | primary: JOIN, START, REDEEM, CLAIM, BUY BACK, COLLECT (7) |
| `blue` | `#50AAFF -> #2864E6` | social / secondary: INVITE FRIENDS, INVITE |
| `danger` | `#FF5F5F -> #BE1E28` | leave / destructive |
| `sell` | `#FF6868 -> #C4162E` | sell / hold-to-sell (4), + stripe `#AA0000` |
| `gold` | `#FFDD57 -> #FF9900` | PICK UP, neutral-warm action |
| `price` | `#FFF454 -> #FDAA09` | purchase-with-coins bar |
| `alert` | `#FF8C8C -> #E63246` | alert header (BuyBack) |
| `race` | `#5AAFFF -> #7D50FF` | race type card |
| `claim` (rot -90) | `#78FFA0 -> #1EAA5A` | pill tag "Claim"/"Tomorrow" |
| `tab` (rot -90) | `#5B99C2 -> #69A9CB` | tab under a 0.34 checker |
| `quest` (rot -90) | `#2D4FD0 -> #4A74F0` | quest banner |
| `weather` (rot -90) | `#AAFF9B -> #FFFFF2` | HUD weather chip |
| `fill` (rot -180) | `#3CFF00 -> #2FFF00` | progress bar fill |

**Text** (`SKY.C`): white `#FFFFFF` (76) and `#EEF2FC` (46, titles and button labels); muted `#A0AABE`
(secondary values), `#BEC6DC` (column/section titles), `#AAADB4` claimed; gold `#FFD63C` / `#FFDD57`
(prizes, coin amounts), dim gold `#8C7830` (claimed amount); green `#54FF1A` (progress), `#78FFA0`
(income, VIEW link), `#21FF15` (Robux price), `#5ECC00` (perk); red `#FF8282` (status/error); cyan
`#5AC8FF` (TOMORROW); pink `#E678FF` (gems); dark `#5A647D` (unknown "?").

**Solids**: stamp off `#2E3444` (ring black, today ring white), stamp on `#12DA23`; progress track
`#3A3E4E` + stroke 1.5 `#14161E`; selected chip ring `#5B98C2` (border 2 + text outline 1.5).

## Shadow ladder (`SKY.shadow(obj, key)`)

| key | UIShadow | Where (user counts) |
|---|---|---|
| `panel` | blur 54, t 0 | panel root (6) |
| `card` | blur 12, t 0 | header, card, section, primary button, row in a lobby list (43) |
| `drop` | blur 15, t 0.5, offset (0,-5,0,5) | button inside a list row, price bar, sell buttons (8) |
| `soft` | blur 10, t 0.5 | tabs, chips, plot rows (5) |
| `glow` | blur 35, t 0.26, `#A9D6F4` (or `#FFFFFF`, `#83D4FF`) | info card, highlight card, rarity badge (7) |
| alert glow | blur 35, `#FF0008`, t 0 | HUD alert banner |

## Layout numbers (Scale only; every UDim2 written `UDim2.new(x, 0, y, 0)`)

- Panel root: `AnchorPoint 0.5,0.5`, `Position 0.5,0.5`, `UIAspectRatioConstraint` 1.14-1.6
  (Codes 0.4x0.42 AR 1.6; Daily 0.56x0.7 AR 1.42; Dex/Guide 0.56-0.6 x 0.74-0.76 AR 1.3; PlotManager
  0.62x0.76 AR 1.32; BuyBack 0.3x0.36 AR 1.14; RaceLobby 0.62x0.68).
- Header: `Size 0.94,0.12` `Position 0.5,0.03` `AnchorPoint 0.5,0` (10 of 10). Title `0.5,0.6` at
  `0.03,0.5` anchor `0,0.5` Left `#EEF2FC`. Sub `0.4588,0.8076` at `0.9035,0.5014` anchor `1,0.5` Right.
- Body: `Size 0.94,0.79` `Position 0.5,0.18` `AnchorPoint 0.5,0` - 0.03 margins all round.
- Close: `Size 0.09001,0.9265` `Position 1.015,0.4632` `AnchorPoint 1,0.5`, aspect 1, image at 1.5x.
- Button label: `Size 0.9,0.72` centred, or `1,1` inside `UIPadding 0.18/0.06`.
- List: transparent ScrollingFrame, `UIListLayout` Vertical `Padding 0.012-0.015` centre,
  `ScrollBarThickness 6` (or 3), `AutomaticCanvasSize Y`, `CanvasSize 0`. Row `Size 0.97,1` +
  `UIAspectRatioConstraint 7-20` (height follows width on every device).
- Tunables stay attributes on the panel (`PopTime`, `RowH`, `Gap`...) read with a fallback.

## SKY builder API (`scripts/sky.lua`, Edit datamodel only)

Run as `cat sky.lua yourbuild.lua | $R lua -`. No module needed, so it works in a bare UI place (which
has no ReplicatedStorage modules) and in the BETA place.

| Call | Builds |
|---|---|
| `SKY.shell(frame, aspect)` | skins an existing Frame as a panel root: white bg, corner 12, border 2 FixedSize, shell gradient, shadow 54, aspect, shell Tiles, `open` attribute. |
| `SKY.header(root, title, sub?, headerAR?)` | Header strip + Title (+ Sub) + CloseButton. Returns header, title, sub, close. |
| `SKY.close(parent)` | image close button (auto-called by `header`). |
| `SKY.card(parent, props, AR, {radius, shadow, fill, rows, tileSize, image, tiles, aspect})` | checker card. |
| `SKY.inset(parent, props, AR)` | blue inset body, 4-tile-tall checker. |
| `SKY.button(parent, props, text, kind, {radius, shadow, stripe, maxText})` | skinned TextButton + `Label` + `UIScale`. |
| `SKY.chip(parent, props, text, AR, {selected, radius, maxText})` | checker TextButton (tab, bet chip, filter). |
| `SKY.list(parent, props, gap, pad)` | transparent vertical ScrollingFrame; `pad=false` skips UIPadding. |
| `SKY.row(list, props, AR, {radius, shadow, fill, rows})` | checker row, `Size 0.97,1` + aspect + `UIScale "Pop"`. |
| `SKY.pill(parent, props, text, kind, maxText)` | pill tag. |
| `SKY.stamp(parent, props, letter, on)` | round stamp. |
| `SKY.label(parent, props, maxText?)` | kit label (font, scaled, white, outline 1.5, z2). |
| `SKY.frame / tiles / corner / border / outline / fill / shadow / aspect / pad / tileSize / set / new` | primitives. |

## Runtime (BETA place) - unchanged modules

`ReplicatedStorage.Modules.GUIS.{UIKit, Panels, SoundModule/UISound, Device, UITheme,
NotificationSystem}` live in the BETA place only. Still use `Panels.open/close/toggle/onFirstOpen`,
`SoundModule.bind` (reuses the button's authored `UIScale`), `UIKit.popIn` (reuses a `UIScale` named
`Pop`), `UIKit.hold`, `UIKit.paintGradient`, `UIKit.abbreviate`, `UIKit.textStyle`.
**`UIKit.skin(obj, kind)` paints the legacy slate look - never call it on Sky UI.** Recolour a Sky
button with `UIKit.paintGradient`; switch a chip's state by tweening its Border stroke colour.
