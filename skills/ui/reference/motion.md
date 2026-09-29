# motion - default animations, mandatory

Every number here is from shipped game code (`Panels`, `SoundModule`, `UIKit`, `BazaarUI`). Use
these exact TweenInfos; a panel that opens with a different curve reads as a different game.

| Event | Tween | Where |
|---|---|---|
| Panel open | `Size 0,0` at `Position 0.5,1.5` -> authored size/pos. `TweenInfo(0.30, Back, Out)`. Sound `open`. Closes every other panel first. | `Panels.open(name)` |
| Panel close | -> `Size 0,0`, `Position 0.5,-1.6`. `TweenInfo(0.18, Quad, In)`. `Visible=false` on Completed. Sound `close`. | `Panels.close(name)` |
| Button hover | inner `UIScale` x1.04, `TweenInfo(0.12, Back, Out)`; skipped on touch. Sound `hover`. | `SoundModule.bind(btn, onClick, 1.04)` |
| Button press | x0.95 on Down, settle on Up (`SETTLE_TWEEN`). Sound `click` on Activated. | same |
| Control tap (toggle/cycle) | holder `Size` x0.86 -> back, `TweenInfo(0.25, Back, Out)`. Sound `tick`. Capture the authored size ONCE at load, never at click time. | `BazaarUI.pop` |
| Row / card enter | `UIKit.popIn(row, 0.25)` (UIScale 0.85 -> 1, Back Out). Stagger `i * 0.03`, cap 12 rows. | list fill |
| State colour change | stroke `Color` `TweenInfo(0.18)`; gradients are NOT tweenable, set `UIKit.gradientFor` outright. | toggles |
| HUD out of the way (fullscreen panels) | each HUD object slides 1.3 screen off its nearest edge, `TweenInfo(0.3, Quad, Out)`; per-frame-driven guis are `Enabled=false` instead. | `BazaarUI.fullscreen` |
| Denied / invalid | `SoundModule.shake(obj, 8, 0.18)` + sound `denied`. | inputs |
| Number change | count-up 0.4s, `tick` per step. | counters |
| Purchase / success | sound `purchase` / `success`, `popIn` on the affected row. | actions |

Config knobs: `GameConfig` UI `PanelOpenTime 0.30` / `PanelCloseTime 0.18`; per-panel attributes
(`PopTime`, `SlideTime`, `FlashTime`...) on the frame. Read them with a fallback, never hardcode a
second copy.

## Panel script skeleton

Create with `multi_edit` (`className: "LocalScript"`, parent = the panel frame). This is the whole
job of a panel LocalScript: clone, fill, bind. No `Instance.new` of GuiObjects.

```lua
--[[
	<Name>UI -- fills StarterGui.Frames.<Name>. Rows are clones of the authored Template; this script
	only writes Text, colour, LayoutOrder, Visible. All sizes stay authored (Scale).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GUIS = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GUIS")
local UIKit = require(GUIS:WaitForChild("UIKit"))
local UISound = require(GUIS:WaitForChild("UISound"))
local Panels = require(GUIS:WaitForChild("Panels"))

local panel = script.Parent
panel.Visible = false
local Scroll = panel:WaitForChild("Body"):WaitForChild("Scroll")
local Template = Scroll:WaitForChild("Template")
local rows = {}

local function fill(row, item, i)
	row.Name = item.id
	row.LayoutOrder = i
	row.Label.Text = item.label
	UIKit.textStyle(row.Label)
	local btn = row.Action.TextButton
	UISound.bind(btn, function() item.onClick(row) end)
end

local function render(items)
	for _, r in rows do r:Destroy() end
	rows = {}
	for i, item in items do
		local row = Template:Clone()
		fill(row, item, i)
		row.Visible = true
		row.Parent = Scroll
		rows[i] = row
		task.delay(math.min(i, 12) * 0.03, UIKit.popIn, row, 0.25)
	end
end

Panels.onFirstOpen(panel, function()
	render(ITEMS) -- your data
end)
```

Opener: any HUD GuiButton with attribute `OpensPanel = "<Name>"` (PanelLinks wires it). Close: the
authored `Header.CloseButton` (Panels wires it). Do not connect either yourself.
