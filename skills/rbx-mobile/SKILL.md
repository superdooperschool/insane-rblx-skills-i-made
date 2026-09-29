---
name: rbx-mobile
description: Use when a Roblox UI or control must work on phone/tablet/console, when a HUD element sits near the bottom corners, when "the game feels laggy when I move" on touch, when text is unreadable on phone, before shipping any panel, or when asked to check mobile/device layouts. Pairs with the ui skill.
---

# rbx-mobile

**Same screen on a phone and a 1440p monitor, and the thumb zones stay empty.** `scripts/mobile_audit.lua`
checks the structural rules in Edit; the Device Simulator capture is the visual proof.

## Rules (each from a shipped bug)

| Rule | Bug it prevents |
|---|---|
| Nothing in the bottom-left (thumbstick) or bottom-right (jump) zones; use `Device.controlZones()` | HUD element there eats move input: reads as "laggy movement", not "button broken" |
| Scale layout only; pixel values (stroke, corner, text) scaled by one runtime factor: `DEVICE_SCALE[class] * clamp(min(vp.X/1920, vp.Y/1080), 1, 1.3)` (Phone 0.46, Tablet 0.72, Console 1.1, Desktop 1.0), floor at 1 so a phone is never shrunk twice | double-scaling |
| Strokes are TOLD their thickness per role, floored at 1 px; text floored at `MIN_TEXT 12` | 732 invisible sub-pixel strokes; 16 labels at 8 px |
| Hit area >= 44 pt after scaling; close buttons get a min size on touch | mis-taps |
| Pop/hover animations on an inner `UIScale`, never `Size` (aspect-constrained buttons fight a Size tween) | jitter |
| `UIAspectRatioConstraint` direct child of the frame it constrains | silent no-op |
| Touch: no hover; two-tap on spendable nodes (first selects, second buys); mute hover SFX; `MouseEnter` gated by last input type | one-tap spends on an unread node |
| Drag panning from `UserInputService`, not the frame (buttons sink the press); `DRAG_SLOP 8 px` + suppress click after a drag | a drag starting on a hex also buys it |
| `AbsolutePosition` excludes the topbar inset for EVERY ScreenGui; correct both `IgnoreGuiInset` kinds | off-by-topbar layout |
| Measure the union of descendants, not `AbsoluteSize`, for overflowing grids | wrong collision solve |
| Do not invalidate a panel's cached open layout mid-close tween | reopens at partial size |
| Screen rays: `UIS:GetMouseLocation()` pairs with `ScreenPointToRay`, not `ViewportPointToRay` | ray offset by topbar |
| `StarterGui.ScreenOrientation = LandscapeSensor`; ship the stock `PlayerModule` + `DynamicThumbstick` unless the character is not a Humanoid (then a custom stick with identity-tracked touches) | left half of screen claimed by the stick |
| `MobileQuality`: Precise MeshParts -> Automatic, particle rate halved, clouds off on phone | phone fps |

## Workflow

1. `sed "s|__ROOT__|StarterGui.HUD|" ~/.claude/skills/rbx-mobile/scripts/mobile_audit.lua | $R lua -` -> zones, small hit areas, offsets, nested aspect constraints, root UIScale stacks, tiny text.
2. `ui` skill audit on the panel.
3. Device Simulator: `$R call skill '{"skill_name":"rbx-device-simulator-lua"}'` for the driver; capture Phone portrait/landscape, Tablet, Desktop; `Read` each once.
4. Report a table per device: `element | issue | fix`. A mobile claim without a phone capture is unverified.

## Red flags

- A new HUD element anchored at (0,1) or (1,1)
- `TextSize = 8`, `Thickness = 0.05`
- `UDim2.new(0, 44, 0, 44)` "for the hit area"
- "Works on my monitor"
