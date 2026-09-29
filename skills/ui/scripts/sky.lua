local SKY = {}

SKY.FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

SKY.IMG = {
	shell = "rbxassetid://131017184238132",
	checker = "rbxassetid://95676388705283",
	stripe = "rbxassetid://84682738767744",
	close = "rbxassetid://126722740435766",
	coin = "rbxassetid://88118342477318",
	tick = "rbxassetid://6972510111",
	arrow = "rbxassetid://100517744926951",
}

SKY.C = {
	white = Color3.fromHex("FFFFFF"),
	text = Color3.fromHex("EEF2FC"),
	muted = Color3.fromHex("A0AABE"),
	mutedTitle = Color3.fromHex("BEC6DC"),
	gold = Color3.fromHex("FFD63C"),
	coin = Color3.fromHex("FFDD57"),
	good = Color3.fromHex("54FF1A"),
	mint = Color3.fromHex("78FFA0"),
	robux = Color3.fromHex("21FF15"),
	bad = Color3.fromHex("FF8282"),
	cyan = Color3.fromHex("5AC8FF"),
	gem = Color3.fromHex("E678FF"),
	ink = Color3.fromHex("000000"),
	insetLine = Color3.fromHex("4E75AC"),
	selected = Color3.fromHex("5B98C2"),
	slot = Color3.fromHex("2E3444"),
	stamp = Color3.fromHex("12DA23"),
	barTrack = Color3.fromHex("3A3E4E"),
}

SKY.FILL = {
	shell = { "C7F2FF", "B8E6FD", -90 },
	pale = { "FFFFFF", "D6E2FF", -90 },
	inset = { "628FBE", "6297C7", -90 },
	tab = { "5B99C2", "69A9CB", -90 },
	quest = { "2D4FD0", "4A74F0", -90 },
	claim = { "78FFA0", "1EAA5A", -90 },
	weather = { "AAFF9B", "FFFFF2", -90 },
	action = { "E5FF00", "00FFAA", 90 },
	blue = { "50AAFF", "2864E6", 90 },
	danger = { "FF5F5F", "BE1E28", 90 },
	sell = { "FF6868", "C4162E", 90 },
	gold = { "FFDD57", "FF9900", 90 },
	price = { "FFF454", "FDAA09", 90 },
	alert = { "FF8C8C", "E63246", 90 },
	race = { "5AAFFF", "7D50FF", 90 },
	fill = { "3CFF00", "2FFF00", -180 },
}

SKY.SHADOW = {
	panel = { 54, 0 },
	card = { 12, 0 },
	drop = { 15, 0.5, true },
	soft = { 10, 0.5 },
	glow = { 35, 0.26, false, "A9D6F4" },
}

SKY.R = {
	panel = UDim.new(0, 12),
	inner = UDim.new(0, 8),
	pill = UDim.new(1, 0),
	soft = UDim.new(0.3, 0),
	bar = UDim.new(0.5, 0),
}

function SKY.new(class, parent, props)
	local i = Instance.new(class)
	for k, v in props or {} do
		i[k] = v
	end
	i.Parent = parent
	return i
end

function SKY.set(inst, props)
	for k, v in props or {} do
		inst[k] = v
	end
	return inst
end

function SKY.corner(p, r)
	return SKY.new("UICorner", p, { CornerRadius = r or SKY.R.inner })
end

function SKY.border(p, t, color, fixed)
	local s = SKY.new("UIStroke", p, {
		Thickness = t or 2,
		Color = color or SKY.C.ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	if fixed then
		s.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
	end
	return s
end

function SKY.outline(label, t, color)
	return SKY.new("UIStroke", label, {
		Thickness = t or 1.5,
		Color = color or SKY.C.ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function SKY.fill(p, key)
	local f = SKY.FILL[key]
	return SKY.new("UIGradient", p, {
		Color = ColorSequence.new(Color3.fromHex(f[1]), Color3.fromHex(f[2])),
		Rotation = f[3],
	})
end

function SKY.shadow(p, key, color)
	local s = SKY.SHADOW[key or "card"]
	return SKY.new("UIShadow", p, {
		BlurRadius = UDim.new(0, s[1]),
		Transparency = s[2],
		Offset = s[3] and UDim2.new(0, -5, 0, 5) or UDim2.new(0, 0, 0, 0),
		Color = color or (s[4] and Color3.fromHex(s[4])) or SKY.C.ink,
	})
end

function SKY.aspect(p, ratio, byHeight)
	return SKY.new("UIAspectRatioConstraint", p, {
		AspectRatio = ratio or 1,
		DominantAxis = byHeight and Enum.DominantAxis.Height or Enum.DominantAxis.Width,
	})
end

function SKY.pad(p, tb, lr)
	return SKY.new("UIPadding", p, {
		PaddingTop = UDim.new(tb, 0),
		PaddingBottom = UDim.new(tb, 0),
		PaddingLeft = UDim.new(lr or tb, 0),
		PaddingRight = UDim.new(lr or tb, 0),
	})
end

function SKY.tileSize(aspect, rows)
	local y = 1 / (rows or 2)
	return UDim2.new(y / aspect, 0, y, 0)
end

function SKY.tiles(p, image, tileSize, radius, props)
	local t = SKY.new("ImageLabel", p, {
		Name = "Tiles",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = SKY.IMG[image] or image,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = tileSize or UDim2.new(1, 0, 1, 0),
		ZIndex = 1,
	})
	SKY.set(t, props)
	SKY.corner(t, radius or SKY.R.panel)
	return t
end

function SKY.label(p, props, maxText)
	local l = SKY.new("TextLabel", p, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = SKY.FONT,
		TextScaled = true,
		TextWrapped = true,
		RichText = false,
		TextColor3 = SKY.C.white,
		ZIndex = 2,
	})
	SKY.set(l, props)
	SKY.outline(l)
	if maxText then
		SKY.new("UITextSizeConstraint", l, { MaxTextSize = maxText })
	end
	return l
end

function SKY.frame(p, props)
	return SKY.new("Frame", p, SKY.set({
		BackgroundColor3 = SKY.C.white,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, props))
end

function SKY.shell(frame, aspect)
	SKY.set(frame, {
		BackgroundColor3 = SKY.C.white,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ZIndex = 1,
	})
	frame:SetAttribute("open", frame:GetAttribute("open") or false)
	SKY.corner(frame, SKY.R.panel)
	SKY.border(frame, 2, nil, true)
	SKY.fill(frame, "shell")
	SKY.shadow(frame, "panel")
	if aspect then
		SKY.aspect(frame, aspect)
	end
	SKY.tiles(frame, "shell", nil, SKY.R.panel)
	return frame
end

function SKY.close(p)
	local b = SKY.new("TextButton", p, {
		Name = "CloseButton",
		Size = UDim2.new(0.09001, 0, 0.9265, 0),
		Position = UDim2.new(1.015, 0, 0.4632, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		FontFace = SKY.FONT,
		ZIndex = 2,
	})
	b:SetAttribute("BTNFXEnabled", false)
	SKY.aspect(b, 1)
	SKY.new("ImageLabel", b, {
		Size = UDim2.new(1.5, 0, 1.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = SKY.IMG.close,
		ZIndex = 1,
	})
	return b
end

function SKY.header(root, title, sub, headerAspect)
	local h = SKY.frame(root, {
		Name = "Header",
		Size = UDim2.new(0.94, 0, 0.12, 0),
		Position = UDim2.new(0.5, 0, 0.03, 0),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	SKY.corner(h, SKY.R.panel)
	SKY.border(h)
	SKY.shadow(h, "card")
	SKY.tiles(h, "checker", SKY.tileSize(headerAspect or 11, 2), SKY.R.panel)
	local t = SKY.label(h, {
		Name = "Title",
		Text = title,
		Size = UDim2.new(0.5, 0, 0.6, 0),
		Position = UDim2.new(0.03, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = SKY.C.text,
	})
	local s
	if sub then
		s = SKY.label(h, {
			Name = "Sub",
			Text = sub,
			Size = UDim2.new(0.4588, 0, 0.8076, 0),
			Position = UDim2.new(0.9035, 0, 0.5014, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	return h, t, s, SKY.close(h)
end

function SKY.card(p, props, aspect, opts)
	opts = opts or {}
	local c = SKY.frame(p, props)
	local r = opts.radius or SKY.R.panel
	SKY.corner(c, r)
	SKY.border(c)
	if opts.shadow ~= false then
		SKY.shadow(c, opts.shadow or "card")
	end
	if opts.fill then
		SKY.fill(c, opts.fill)
	end
	SKY.tiles(c, opts.image or "checker", opts.tileSize or SKY.tileSize(aspect or 4, opts.rows or 2), r, opts.tiles)
	if opts.aspect then
		SKY.aspect(c, opts.aspect)
	end
	return c
end

function SKY.inset(p, props, aspect)
	local c = SKY.frame(p, props)
	SKY.corner(c, SKY.R.panel)
	SKY.fill(c, "inset")
	SKY.border(c, 3, SKY.C.insetLine)
	SKY.tiles(c, "checker", SKY.tileSize(aspect or 1.7, 4), SKY.R.panel)
	return c
end

function SKY.button(p, props, text, kind, opts)
	opts = opts or {}
	local b = SKY.new("TextButton", p, SKY.set({
		BackgroundColor3 = SKY.C.white,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		FontFace = SKY.FONT,
		ZIndex = 2,
	}, props))
	SKY.corner(b, opts.radius or SKY.R.inner)
	SKY.border(b)
	SKY.fill(b, kind or "action")
	SKY.shadow(b, opts.shadow or "card")
	SKY.new("UIScale", b)
	if opts.stripe then
		SKY.tiles(b, "stripe", UDim2.new(0.1, 0, 0.5, 0), opts.radius or SKY.R.inner, { ImageColor3 = opts.stripe })
	end
	local l = SKY.label(b, {
		Name = "Label",
		Text = text,
		Size = UDim2.new(0.9, 0, 0.72, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = SKY.C.text,
		ZIndex = 3,
	}, opts.maxText)
	return b, l
end

function SKY.chip(p, props, text, aspect, opts)
	opts = opts or {}
	local b = SKY.new("TextButton", p, SKY.set({
		BackgroundColor3 = SKY.C.white,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		FontFace = SKY.FONT,
		ZIndex = 2,
	}, props))
	local r = opts.radius or SKY.R.inner
	SKY.corner(b, r)
	SKY.border(b, 2, opts.selected and SKY.C.selected or nil)
	SKY.shadow(b, "soft")
	SKY.new("UIScale", b)
	SKY.tiles(b, "checker", SKY.tileSize(aspect or 3, 2), r)
	local l = SKY.label(b, {
		Name = "Label",
		Text = text,
		Size = UDim2.new(0.9, 0, 0.72, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = SKY.C.text,
		ZIndex = 3,
	}, opts.maxText)
	return b, l
end

function SKY.list(p, props, gap, pad)
	local s = SKY.new("ScrollingFrame", p, SKY.set({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = SKY.C.ink,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
	}, props))
	SKY.new("UIListLayout", s, {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(gap or 0.015, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	if pad ~= false then
		SKY.new("UIPadding", s, { PaddingTop = UDim.new(pad or 0.02, 0), PaddingBottom = UDim.new(pad or 0.02, 0) })
	end
	return s
end

function SKY.row(p, props, aspect, opts)
	opts = opts or {}
	local r = SKY.card(p, SKY.set({
		Size = UDim2.new(0.97, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		ZIndex = 1,
	}, props), aspect, { radius = opts.radius, shadow = opts.shadow or "card", fill = opts.fill, rows = opts.rows or 2, aspect = aspect })
	SKY.new("UIScale", r, { Name = "Pop" })
	return r
end

function SKY.pill(p, props, text, kind, maxText)
	local t = SKY.frame(p, props)
	SKY.corner(t, SKY.R.pill)
	SKY.border(t)
	SKY.fill(t, kind or "claim")
	local l = SKY.label(t, {
		Name = "Label",
		Text = text,
		Size = UDim2.new(0.9, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Color3.fromHex("F1F5FF"),
	}, maxText or 12)
	return t, l
end

function SKY.stamp(p, props, text, on)
	local s = SKY.frame(p, SKY.set({ BackgroundColor3 = on and SKY.C.stamp or SKY.C.slot }, props))
	SKY.aspect(s, 1, true)
	SKY.corner(s, SKY.R.pill)
	local ring = SKY.border(s)
	ring.Name = "Ring"
	SKY.label(s, {
		Name = "Letter",
		Text = text,
		Size = UDim2.new(0.6, 0, 0.6, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = SKY.C.text,
	})
	return s
end
