# anatomy - Sky Checker archetypes, exact values

From the user's reference UIs (see kit.md). Copy the shape; change only Name, Text, Size fractions,
LayoutOrder. Notation: `sz(x,y)` / `pos(x,y)` are Scale (offsets always 0), `a` = AnchorPoint,
`z` = ZIndex, `T[...]` = child `ImageLabel "Tiles"` (Size 1,1, ScaleType Tile, z1, own UICorner = parent's),
`Sh` = UIShadow, `B` = UIStroke Border, `O` = UIStroke Contextual (text outline).
SKY call in brackets.

## 1. Panel root [SKY.shell]
```
<Name> Frame sz(0.4-0.62, 0.42-0.76) pos(0.5,0.5) a(0.5,0.5) bg #FFFFFF z1 Visible=false @open=false
  UICorner 12 | B 2 black FixedSize | UIGradient -90 #C7F2FF>#B8E6FD | Sh 54 | UIAspectRatioConstraint 1.14-1.6
  T[shell 131017184238132, TileSize 1x1, corner 12]
```
Glow variant (inventory): Sh 35 `#A9D6F4` t0.26. Alert variant (BuyBack): gradient `#FFFFFF>#D6E2FF`, header `alert`.

## 2. Header strip [SKY.header]
```
Header Frame sz(0.94,0.12) pos(0.5,0.03) a(0.5,0) bg #FFFFFF z2
  UICorner 12 | B 2 | Sh 12 | T[checker, {0.05,0},{0.5,0}]
  Title TextLabel sz(0.5,0.6) pos(0.03,0.5) a(0,0.5) Left #EEF2FC z2 | O 1.5
  Sub   TextLabel sz(0.4588,0.8076) pos(0.9035,0.5014) a(1,0.5) Right #FFFFFF z2 | O 1.5   (optional: streak, counts)
  CloseButton TextButton sz(0.09001,0.9265) pos(1.015,0.4632) a(1,0.5) bgT1 Text="" AutoButtonColor=false z2 @BTNFXEnabled=false
    UIAspectRatioConstraint 1
    ImageLabel sz(1.5,1.5) pos(0.5,0.5) a(0.5,0.5) bgT1 Image 126722740435766
```
Sub can be two lines ("0/38 discovered / +0% income"). Dialogue variant (QuestsTalk): header `sz(0.94,0.236)`, one centred `NpcName`.

## 3. Body region
Open body: `Body Frame sz(0.94,0.79) pos(0.5,0.18) a(0.5,0) bgT1 z2` - cards sit on the shell.
Inset body [SKY.inset]:
```
Body Frame sz(0.94,0.79) pos(0.5,0.18) a(0.5,0) bg #FFFFFF z2
  UICorner 12 | UIGradient -90 #628FBE>#6297C7 | B 3 #4E75AC | T[checker, SKY.tileSize(AR,4) ~ {0.15,0},{0.25,0}]
```

## 4. Checker card / section [SKY.card]
```
Card Frame bg #FFFFFF z2 | UICorner 12 (8 when nested) | B 2 | Sh 12 | T[checker, SKY.tileSize(AR,2)]
  Title TextLabel pos(0.02-0.04, 0.06-0.08) Left #FFFFFF z2 | O 1.5
```
Examples: RaceLobby Party `sz(0.95,0.265)` T{0.1,0.5}; Host `sz(0.339,0.153)` AR 3.3 T{0.2,0.5};
Daily Week `T{0.07,0.5}`, Tomorrow `T{0.115,0.5}`, Ladder `T{0.25,0.5}`. Tinted: ImageColor3 `#FFD8E1` (pink), `#DADADA`, `#E8E8E8`.

## 5. Loud button [SKY.button]
```
Join TextButton sz(0.3,0.4) a(1,0) bg #FFFFFF Text="" AutoButtonColor=false z2
  UICorner 8 | B 2 | UIGradient 90 <kind> | Sh 12 | UIScale | (UIPadding 0.18/0.06 when Label is 1,1)
  Label TextLabel sz(0.9,0.72) pos(0.5,0.5) a(0.5,0.5) #EEF2FC z3 | O 1.5 | (UITextSizeConstraint 20-48)
```
In a list row: Sh 15 t0.5 offset(-5,5) ("drop"). Pill variant: corner `1,0`, holder Frame + transparent `Hit` TextButton z5.
Stripe variant (sell/picker): add T[stripe 84682738767744, {0.1,0},{0.5,0}, ImageColor3 #AA0000 / #7EE3FF].
Price bar: gradient `price #FFF454>#FDAA09`, coin icon left, amount label.

## 6. Checker chip / tab [SKY.chip]
```
B1 TextButton sz(0.22,1) bg #FFFFFF Text="" z1 | UICorner 8 | B 2 | Sh 10 t0.5 | UIScale | T[checker,{0.2,0},{0.5,0}]
  Label sz(0.9,0.72) #EEF2FC z3 | O 1.5
selected: B 2 #5B98C2 + O 1.5 #5B98C2
```
Tabs: corner `0.3,0`, gradient `tab #5B99C2>#69A9CB`, T ImageTransparency 0.34 `{0.35,0},{1,0}`, B 1.6, row in `UIListLayout` Horizontal pad 0.015-0.02.

## 7. List + row [SKY.list + SKY.row]
```
Rows ScrollingFrame bgT1 z3 ScrollBarThickness 6 CanvasSize 0 AutomaticCanvasSize Y (no UIPadding if a script clears it)
  UIListLayout Vertical pad 0.012-0.015 h Center
  Template Frame sz(0.97,1) bg #FFFFFF Visible=false | UIAspectRatioConstraint 7 (lobby) - 20 (dense) | UICorner 8-12 | B 2 | Sh 12 or 10 t0.5 | UIScale "Pop" | T[checker, SKY.tileSize(AR,2)]
    columns: labels at fixed x fractions, z2; buttons right-anchored a(1,0.5) at 0.97-0.995
```
Behind a script-filled list: an inset (3) with the same rect at z2, list at z3.

## 8. Heading strip (column titles)
```
Heading Frame sz(0.912,0.075) a(0.5,0) z2 | UICorner 12 | B 2 | Sh 12 | T[checker, SKY.tileSize(~16,1)] | (AR 17 inside lists)
  column labels sz(w,0.6) #BEC6DC (or #EEF2FC), same x fractions as the row
```

## 9. Pill tag [SKY.pill]
`Tag Frame sz(0.86,0.13) a(0.5,1) pos(0.5,0.95) | UICorner 1,0 | B 2 | UIGradient -90 #78FFA0>#1EAA5A | Label #F1F5FF maxText 12`. Claimed state: text `#AAADB4`, darker fill.

## 10. Stamp / badge [SKY.stamp]
`Slot Frame sz(1,1) bg #2E3444 (on #12DA23) | UIAspectRatioConstraint 1 by Height | UICorner 1,0 | Ring=B 2 black (today white) | Letter sz(0.6,0.6) #EEF2FC`.
Place badge in a row: `sz(0.1,0.76) a(0.5,0.5)` bg `#2E3444`, label sibling on top z3 (medal colour set by script).

## 11. Input
```
InputContainer Frame bg #FFFFFF | UICorner 8 | B 2 | UIGradient -90 #628FBE>#6297C7 | T[checker,{0.25,0},{1,0}, ImageColor3 #E8E8E8]
  Input TextBox sz(1,1) bgT1 #FFFFFF PlaceholderText "ENTER CODE" PlaceholderColor3 #6E7688 ClearTextOnFocus=false | O 2
```

## 12. Progress bar
```
Bar Frame bg #3A3E4E | UICorner 0.5,0 | B 1.5 #14161E | T[checker,{0.15,0},{1,0}, ImageColor3 #939393, corner 0.5]
  Fill Frame sz(p,1) | UICorner 0,20 | UIGradient -180 #3CFF00>#2FFF00
  Count TextLabel sz(1,0.8) z5 | O 1.5 | maxText 20
```

## 13. Day / reward card (Daily)
`Day TextButton sz(0.132,1) | UICorner 8 | B 2 | Sh 12 | UIScale "Pop" | T[checker,{0.5,0},{0.35,0}]` with `Day` label top (maxText 16),
`Icon` ImageLabel Fit `sz(0.62,0.3)`, `Amount` gold `#FFDD57` (claimed `#8C7830`), pill tag bottom.

## 14. HUD pieces
- Info card (CapsuleInfo): outer shell-gradient card corner 12 B 2 Sh 35 `#A9D6F4` t.26 AR 3.4; inner `Info` inset `#628FBE>#6297C7` with B 2 `#4E75AC` + B 5 `#B0DBFA` (double ring), corner `0.05,0`, glow Sh 35 `#FFFFFF`.
- Weather chip: gradient -90 `#AAFF9B>#FFFFF2`, corner 2, B 2, Sh 10 t.5, AR 4.74, label + timer + green perk `#5ECC00`.
- Alert banner: solid red gradient `#FF0000`, corner 7, B 2, Sh 35 `#FF0008`, AR 9.9, centred white label.
- Screen vignette (Threat): 4 edge frames bgT 0.45, gradient `#FF3737>#BE0A19>#5A000A` with transparency ramp 0/0.2/0.58/0.88/1 toward centre.
- Punch text: TextLabel sz(0.55,0.08) maxText 44, O 1.5 t0.2, own UIScale.

## Shadow / corner / z ladders

| | value |
|---|---|
| Shadow | root 54 · header/card/primary button 12 · in-row button 15 t.5 off(-5,5) · chip/tab/dense row 10 t.5 · glow 35 t.26 |
| Corner | 12 panel/header/card · 8 button/chip/row/input · `1,0` pill/stamp · `0.3,0` tab/badge · `0.5,0` bar |
| Stroke | Border 2 black everything · 3 `#4E75AC` inset · text Contextual 1.5 black · long copy 0.05 ScaledSize |
| Z | root 1 · Tiles 1 · sections 2 · labels 2 · button labels 3 · list over inset 3 · close 2 |
