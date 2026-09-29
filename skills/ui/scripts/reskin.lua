local NAMES = { __NAMES__ }
local want = {}
for _, n in NAMES do
	want[n] = true
end
local Frames = game.StarterGui.Frames
local TILE = {
	["rbxassetid://131017184238132"] = true,
	["rbxassetid://95676388705283"] = true,
	["rbxassetid://84682738767744"] = true,
}
local PROTECT = { CloseButton = true, Header = true, Template = true }
local LAYER = { Shadow = true, Foreground = true, Lines = true, Highlight = true, Shine = true, Glow = true, Background = true }

local sources = {}
for _, svc in game:GetChildren() do
	local ok, list = pcall(function()
		return svc:GetDescendants()
	end)
	if ok then
		for _, s in list do
			if s:IsA("LuaSourceContainer") then
				local okS, v = pcall(function()
					return s.Source
				end)
				if okS then
					table.insert(sources, v)
				end
			end
		end
	end
end
local ALL = table.concat(sources, "\n")
local function referenced(n)
	return string.find(ALL, '"' .. n .. '"', 1, true) ~= nil or string.find(ALL, "." .. n, 1, true) ~= nil
end

local function child(inst, cls, pred)
	for _, c in inst:GetChildren() do
		if c:IsA(cls) and (not pred or pred(c)) then
			return c
		end
	end
end
local function isTiles(c)
	return c:IsA("ImageLabel") and (c.Name == "Tiles" or (TILE[c.Image] and c.ScaleType == Enum.ScaleType.Tile))
end
local function border(d)
	return child(d, "UIStroke", function(s)
		return s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border
	end)
end
local function loud(g)
	for _, k in g.Color.Keypoints do
		local c = k.Value
		local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
		if mx - mn > 0.35 and mx > 0.55 then
			return true
		end
	end
	return false
end
local function lum(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end
local function hasScript(inst)
	return inst:IsA("LuaSourceContainer") or inst:FindFirstChildWhichIsA("LuaSourceContainer", true) ~= nil
end
local function killGradients(d)
	for _, g in d:GetChildren() do
		if g:IsA("UIGradient") and not loud(g) then
			g:Destroy()
		end
	end
end
local function faded(g)
	for _, k in g.Transparency.Keypoints do
		if k.Value > 0 then
			return true
		end
	end
	return false
end
local function flatten(d, st)
	d.BackgroundTransparency = 1
	for _, c in d:GetChildren() do
		if isTiles(c) or c:IsA("UIShadow") or (c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border) then
			c:Destroy()
		end
	end
	st.layers += 1
end
local function tileFor(d)
	local a = d.AbsoluteSize
	if a.X < 2 or a.Y < 2 then
		return SKY.tileSize(4, 2)
	end
	local rows = a.Y < 150 and 2 or (a.Y < 320 and 3 or 4)
	return SKY.tileSize(a.X / a.Y, rows)
end
local function raiseAbove(d, tiles)
	for _, c in d:GetChildren() do
		if c ~= tiles and c:IsA("GuiObject") and c.ZIndex <= tiles.ZIndex then
			c.ZIndex = tiles.ZIndex + 1
		end
	end
end

local function fixPadding(d, tiles, st)
	local pad = child(d, "UIPadding")
	if not pad or not tiles then
		return
	end
	local l, r, t, b = pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom
	if l.Scale == 0 and r.Scale == 0 and t.Scale == 0 and b.Scale == 0 and l.Offset == 0 and r.Offset == 0 and t.Offset == 0 and b.Offset == 0 then
		return
	end
	local movers, movable = {}, not child(d, "LuaSourceContainer")
	for _, c in d:GetChildren() do
		local skin = c == tiles or c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient") or c:IsA("UIShadow")
			or c:IsA("UIAspectRatioConstraint") or c:IsA("UIScale") or c:IsA("UISizeConstraint") or c:IsA("UITextSizeConstraint")
		if not skin then
			table.insert(movers, c)
			if c:IsA("GuiObject") and (PROTECT[c.Name] or referenced(c.Name) or hasScript(c)) then
				movable = false
			end
		end
	end
	if movable then
		local box = SKY.new("Frame", d, {
			Name = "Inner",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = tiles.ZIndex + 1,
		})
		for _, c in movers do
			c.Parent = box
		end
		tiles.Size = UDim2.new(1, 0, 1, 0)
		tiles.Position = UDim2.new(0, 0, 0, 0)
		st.inner += 1
	else
		local w, h = 1 - l.Scale - r.Scale, 1 - t.Scale - b.Scale
		tiles.Size = UDim2.new(1 / w, 0, 1 / h, 0)
		tiles.Position = UDim2.new(-l.Scale / w, 0, -t.Scale / h, 0)
		st.offsetTiles += 1
	end
end

local function styleText(d, st)
	d.FontFace = SKY.FONT
	d.TextStrokeTransparency = 1
	if d.AutomaticSize == Enum.AutomaticSize.None and d.Size.Y.Scale > 0 then
		d.TextScaled = true
	end
	local s = child(d, "UIStroke", function(x)
		return x.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual
	end)
	if not s then
		SKY.outline(d)
	elseif s.StrokeSizingMode ~= Enum.StrokeSizingMode.ScaledSize then
		s.Thickness, s.Color, s.Transparency = 1.5, SKY.C.ink, 0
		for _, g in s:GetChildren() do
			if g:IsA("UIGradient") then
				g:Destroy()
			end
		end
	end
	if lum(d.TextColor3) < 0.3 then
		d.TextColor3 = SKY.C.white
	end
	st.text += 1
end

local function close(d, st)
	for _, c in d:GetChildren() do
		if not c:IsA("LuaSourceContainer") then
			c:Destroy()
		end
	end
	d.BackgroundTransparency = 1
	d.AutoButtonColor = false
	if d:IsA("TextButton") then
		d.Text = ""
	elseif d:IsA("ImageButton") then
		d.Image = ""
	end
	if d.Parent.Name == "Header" then
		d.Size = UDim2.new(0.09001, 0, 0.9265, 0)
		d.Position = UDim2.new(1.015, 0, 0.4632, 0)
		d.AnchorPoint = Vector2.new(1, 0.5)
	end
	d:SetAttribute("BTNFXEnabled", false)
	SKY.aspect(d, 1)
	SKY.new("ImageLabel", d, {
		Size = UDim2.new(1.5, 0, 1.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = SKY.IMG.close,
		ZIndex = 1,
	})
	st.close += 1
end

local function container(d, depth, st)
	if d:IsA("ScrollingFrame") then
		killGradients(d)
		if not child(d, "UIGradient") then
			SKY.fill(d, "inset")
		end
		d.BackgroundColor3 = SKY.C.white
		if not child(d, "UICorner") then
			SKY.corner(d, SKY.R.panel)
		end
		local b = border(d) or SKY.border(d)
		b.Thickness, b.Color = 3, SKY.C.insetLine
		st.scroll += 1
		return
	end
	local tiles = child(d, "ImageLabel", isTiles)
	local grad = child(d, "UIGradient")
	if grad and faded(grad) then
		if tiles then
			tiles:Destroy()
			tiles = nil
		end
		d.BackgroundColor3 = SKY.C.white
		if not child(d, "UICorner") then
			SKY.corner(d, SKY.R.inner)
		end
		if not border(d) then
			SKY.border(d)
		end
		st.faded += 1
		return
	end
	local isHeader = d.Name == "Header" and depth == 0
	local guiKids = 0
	for _, c in d:GetChildren() do
		if c:IsA("GuiObject") and not isTiles(c) then
			guiKids += 1
		end
	end
	local bigCard = grad and loud(grad) and guiKids >= 3 and not d:IsA("TextBox")
	if (isHeader or bigCard) and not tiles then
		for _, g in d:GetChildren() do
			if g:IsA("UIGradient") then
				g:Destroy()
			end
		end
		grad = nil
	end
	if isHeader then
		d.Size = UDim2.new(0.94, 0, d.Size.Y.Scale, 0)
		d.Position = UDim2.new(0.5, 0, d.Position.Y.Scale, 0)
		d.AnchorPoint = Vector2.new(0.5, d.AnchorPoint.Y)
	end
	local ownText = (d:IsA("TextButton") or d:IsA("TextLabel") or d:IsA("TextBox")) and d.Text ~= ""
	local ownImage = (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= ""
	local corner = child(d, "UICorner") or SKY.corner(d, depth <= 1 and SKY.R.panel or SKY.R.inner)
	d.BackgroundColor3 = SKY.C.white
	if tiles then
		st.kept += 1
	elseif grad and loud(grad) then
		st.loud += 1
	elseif ownText or ownImage then
		killGradients(d)
		SKY.fill(d, "tab")
		st.flat += 1
	else
		killGradients(d)
		tiles = SKY.tiles(d, "checker", tileFor(d), corner.CornerRadius)
		st.tiles += 1
	end
	if tiles then
		local tc = child(tiles, "UICorner") or SKY.corner(tiles)
		tc.CornerRadius = corner.CornerRadius
		raiseAbove(d, tiles)
		fixPadding(d, tiles, st)
	end
	local b = border(d)
	if b then
		if b.Thickness < 1.5 or b.Thickness > 4 then
			b.Thickness = 2
		end
		b.Color, b.Transparency, b.StrokeSizingMode = SKY.C.ink, 0, Enum.StrokeSizingMode.FixedSize
	else
		SKY.border(d)
	end
	if not child(d, "UIShadow") then
		SKY.shadow(d, d.AbsoluteSize.Y > 70 and "card" or "soft")
	end
end

local function shell(root, st)
	local pos, anchor = root.Position, root.AnchorPoint
	for _, c in root:GetChildren() do
		if c:IsA("UIGradient") or c:IsA("UICorner") or c:IsA("UIShadow") or (c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border) or (isTiles(c) and c.Image == SKY.IMG.shell) then
			c:Destroy()
		end
	end
	local a = root.AbsoluteSize
	local ar = (not child(root, "UIAspectRatioConstraint") and a.Y > 1) and math.floor(a.X / a.Y * 100 + 0.5) / 100 or nil
	SKY.shell(root, ar)
	root.Position, root.AnchorPoint = pos, anchor
	local tiles = child(root, "ImageLabel", function(c)
		return c.Image == SKY.IMG.shell
	end)
	raiseAbove(root, tiles)
	fixPadding(root, tiles, st)
end

local report = {}
for _, root in Frames:GetChildren() do
	if want[root.Name] and root:IsA("GuiObject") then
		local st = { tiles = 0, kept = 0, loud = 0, flat = 0, scroll = 0, text = 0, close = 0, inner = 0, offsetTiles = 0, layers = 0, faded = 0 }
		local wasVisible = root.Visible
		root.Visible = true
		local snapshot = root:GetDescendants()
		shell(root, st)
		local skip = {}
		for _, d in snapshot do
			if d.Parent == nil or skip[d] then
				continue
			end
			local blocked = false
			local p = d.Parent
			while p and p ~= root do
				if skip[p] or p:IsA("ViewportFrame") then
					blocked = true
					break
				end
				p = p.Parent
			end
			if blocked or not d:IsA("GuiObject") or isTiles(d) then
				continue
			end
			if d.Name == "CloseButton" and not d:IsA("GuiButton") then
				local btn = d:FindFirstChildWhichIsA("ImageButton")
				if btn then
					d.BackgroundTransparency = 1
					for _, c in btn:GetChildren() do
						if not c:IsA("LuaSourceContainer") and not c:IsA("UIScale") then
							c:Destroy()
						end
					end
					btn.Image, btn.BackgroundTransparency, btn.ScaleType = SKY.IMG.close, 1, Enum.ScaleType.Fit
					d:SetAttribute("CloseImage", true)
					st.close += 1
				end
				skip[d] = true
				continue
			end
			if d.Name == "CloseButton" and d:IsA("GuiButton") then
				close(d, st)
				skip[d] = true
				continue
			end
			if LAYER[d.Name] and d.Parent ~= root and not (d:IsA("TextLabel") or d:IsA("TextButton")) then
				flatten(d, st)
				continue
			end
			local isText = d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")
			if isText and d.Text ~= "" then
				styleText(d, st)
			end
			local depth, q = 0, d.Parent
			while q and q ~= root do
				depth += 1
				q = q.Parent
			end
			if d.BackgroundTransparency < 0.5 and not d:IsA("ViewportFrame") and not (d:IsA("ImageLabel") and d.Image ~= "" and d.BackgroundTransparency > 0) then
				container(d, depth, st)
			end
		end
		root.Visible = wasVisible
		local parts = {}
		for k, v in st do
			if v > 0 then
				table.insert(parts, k .. "=" .. v)
			end
		end
		table.sort(parts)
		table.insert(report, root.Name .. ": " .. table.concat(parts, " "))
	end
end
return table.concat(report, "\n")
