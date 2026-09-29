# ui

Every GUI must look identical on a phone and on a 1440p monitor. That is the whole standard, and
almost every rule here exists to serve it.

## Authoring

- **Author real instances.** Build the tree in Studio (or via `execute_luau` in the Edit
  datamodel so it persists), then clone authored Templates at runtime. Never `Instance.new` a UI
  tree in a LocalScript: it is unreviewable, undesignable, and the user cannot restyle it.
- Capture the user's authored look into a `BASE` or `Template` before cloning variants. Once
  variants exist, restyling means editing N trees instead of one.
- Templates live in `ReplicatedStorage`, not `StarterGui`, unless they are the live copy.
- Default division of labour: this skill authors structure and behaviour, the user restyles.
  Say so in YOUR CHANGES rather than inventing a palette.

## Scaling

One root `UIScale` named `Fit` per ScreenGui:

```lua
local cam = workspace.CurrentCamera
local function fit()
    local vp = cam.ViewportSize
    scale.Scale = math.clamp(math.min(vp.X / 1920, vp.Y / 1080), 0.5, 1.25)
end
cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
fit()
```

- Offset-only sizing is banned. Use `UDim2.fromScale`, or scale plus a small offset for padding.
- **Only one UIScale applies per object.** An open/close pop animation therefore goes on an
  INNER UIScale on the panel, so it multiplies with `Fit` instead of fighting it.
- `UIAspectRatioConstraint` must be a DIRECT child of the frame it constrains. Nested one level
  down it silently does nothing.
- `UIListLayout` / `UIGridLayout` beat manual position maths, and they survive a font change.
- Buttons need a real hit area on mobile: nothing smaller than about 44 points after `Fit`.

## Mobile specifics

- The bottom-left thumbstick and bottom-right jump button are real screen regions. A HUD element
  placed there eats the player's move input, and the symptom is "the game feels laggy when I
  move", not "the button does not work".
- Test with `skill(rbx-device-simulator-lua)`: it drives Studio's Device Simulator so you can
  switch form factor and orientation and capture each one, instead of guessing from one window.

## Verifying

1. Probe 7 (scale audit) for structure.
2. `screen_capture` for how it actually renders. ScreenGuis draw in Edit mode, so this works
   without Play.
3. Probe 6 for weight. A panel that builds its whole tree on the join frame is the classic cause
   of a long join stall. Build per tab or per board on first view instead.

A UI change with no capture in the report is unverified work.

## Sound

Keep the UI voice pool separate from ambient sounds. Cloned Sounds on fixed `Debris:AddItem`
timers pile up: at a few per second they become dozens of live Sound instances and evict each
other, so the purchase click stops playing while ambience keeps going. Destroy on `Ended`, cap
the pool, and keep the pools separate.
