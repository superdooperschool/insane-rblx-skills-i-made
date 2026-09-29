local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Fx = {}

Fx.IMG = {
	hex = "rbxassetid://115473439644159",
	hexGlow = "rbxassetid://92201971057466",
	hexRing = "rbxassetid://91433731622381",
	glow = "rbxassetid://12064824932",
	glowSoft = "rbxassetid://118302663239247",
	sparkle = "rbxassetid://112882057182762",
	starburst = "rbxassetid://6490035152",
	ring = "rbxassetid://119064104030965",
	ringSoft = "rbxassetid://70668101542387",
	gem = "rbxassetid://127386484477779",
}

local layers = {}

function Fx.init(gui)
	layers.under = gui.World.Canvas.Under
	layers.over = gui.World.Canvas.Over
	layers.screen = gui.Screen
	layers.twinkles = gui.Bg.Twinkles
end

function Fx.tween(obj, time, props, style, dir, delay)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	t:Play()
	return t
end

function Fx.image(layer, image, x, y, size, props)
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency = 1
	im.Image = image
	im.AnchorPoint = Vector2.new(0.5, 0.5)
	im.Position = UDim2.fromOffset(x, y)
	im.Size = UDim2.fromOffset(size, size)
	im.ZIndex = 60
	for k, v in props or {} do
		im[k] = v
	end
	im.Parent = layers[layer] or layer
	return im
end

function Fx.flash(x, y, size, color, time, layer)
	local g = Fx.image(layer or "over", Fx.IMG.glow, x, y, size * 0.4, { ImageColor3 = color or Color3.new(1, 1, 1), ImageTransparency = 0.05 })
	Fx.tween(g, time or 0.35, { Size = UDim2.fromOffset(size, size), ImageTransparency = 1 })
	Debris:AddItem(g, (time or 0.35) + 0.05)
end

function Fx.ring(x, y, from, to, color, time, image, layer)
	local r = Fx.image(layer or "over", image or Fx.IMG.ring, x, y, from, { ImageColor3 = color or Color3.new(1, 1, 1), ImageTransparency = 0.1 })
	Fx.tween(r, time or 0.45, { Size = UDim2.fromOffset(to, to), ImageTransparency = 1 }, Enum.EasingStyle.Quart)
	Debris:AddItem(r, (time or 0.45) + 0.05)
end

function Fx.hexWave(x, y, w, h, color, time)
	local r = Fx.image("under", Fx.IMG.hexRing, x, y, 0, { ImageColor3 = color, ImageTransparency = 0, Size = UDim2.fromOffset(w, h) })
	Fx.tween(r, time or 0.5, { Size = UDim2.fromOffset(w * 2.4, h * 2.4), ImageTransparency = 1 }, Enum.EasingStyle.Quart)
	Debris:AddItem(r, (time or 0.5) + 0.05)
end

function Fx.burst(x, y, radius, count, colors, size, layer)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.6
		local d = radius * (0.6 + math.random() * 0.6)
		local s = size * (0.6 + math.random() * 0.7)
		local col = colors[(i - 1) % #colors + 1]
		local p = Fx.image(layer or "over", Fx.IMG.sparkle, x, y, s, { ImageColor3 = col, Rotation = math.random(0, 90) })
		local t = 0.45 + math.random() * 0.3
		Fx.tween(p, t, { Position = UDim2.fromOffset(x + math.cos(a) * d, y + math.sin(a) * d), Rotation = p.Rotation + math.random(-120, 120) }, Enum.EasingStyle.Quint)
		Fx.tween(p, t * 0.6, { Size = UDim2.fromOffset(0, 0), ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, t * 0.4)
		Debris:AddItem(p, t + 0.05)
	end
end

function Fx.starburst(x, y, size, color, time)
	local s = Fx.image("under", Fx.IMG.starburst, x, y, size * 0.3, { ImageColor3 = color, ImageTransparency = 0.1 })
	Fx.tween(s, time or 0.5, { Size = UDim2.fromOffset(size, size), ImageTransparency = 1, Rotation = 40 }, Enum.EasingStyle.Quint)
	Debris:AddItem(s, (time or 0.5) + 0.05)
end

function Fx.shatter(x, y, size, color)
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2 + math.random() * 0.5
		local s = size * (0.18 + math.random() * 0.14)
		local shard = Fx.image("over", Fx.IMG.hex, x + math.cos(a) * size * 0.18, y + math.sin(a) * size * 0.18, s, { ImageColor3 = color, Rotation = math.random(0, 360) })
		local d = size * (0.55 + math.random() * 0.5)
		local t = 0.42 + math.random() * 0.2
		Fx.tween(shard, t, {
			Position = UDim2.fromOffset(x + math.cos(a) * d, y + math.sin(a) * d + size * 0.25),
			Rotation = shard.Rotation + math.random(-260, 260),
			Size = UDim2.fromOffset(s * 0.2, s * 0.2),
			ImageTransparency = 0.6,
		}, Enum.EasingStyle.Quad)
		Debris:AddItem(shard, t + 0.05)
	end
	Fx.flash(x, y, size * 1.3, Color3.fromRGB(190, 215, 255), 0.3)
end

function Fx.popText(x, y, text, color, size)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromOffset(x, y)
	t.Size = UDim2.fromOffset(size * 3, size)
	t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	t.TextSize = math.floor(size * 0.8)
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.ZIndex = 70
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Parent = t
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = t
	t.Parent = layers.over
	Fx.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	Fx.tween(t, 0.9, { Position = UDim2.fromOffset(x, y - size * 1.6) }, Enum.EasingStyle.Quint)
	Fx.tween(t, 0.3, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.65)
	Fx.tween(st, 0.3, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.65)
	Debris:AddItem(t, 1)
end

function Fx.screenFlash(color, peak, inTime, outTime)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1
	f.ZIndex = 90
	f.Parent = layers.screen
	Fx.tween(f, inTime, { BackgroundTransparency = 1 - peak })
	task.delay(inTime, function()
		Fx.tween(f, outTime, { BackgroundTransparency = 1 })
	end)
	Debris:AddItem(f, inTime + outTime + 0.05)
end

function Fx.flyer(image, from, toFn, size, time, arc, onArrive)
	local p = Instance.new("ImageLabel")
	p.BackgroundTransparency = 1
	p.Image = image
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Size = UDim2.fromOffset(size, size)
	local base = layers.screen.AbsolutePosition
	p.Position = UDim2.fromOffset(from.X - base.X, from.Y - base.Y)
	p.ZIndex = 80
	p.Parent = layers.screen
	local ctrl = from + Vector2.new((math.random() - 0.5) * arc * 2, -arc * (0.6 + math.random() * 0.6))
	task.spawn(function()
		local t = 0
		while t < 1 do
			t = math.min(t + task.wait() / time, 1)
			local to = toFn()
			local e = t * t
			local a = from:Lerp(ctrl, e)
			local b = ctrl:Lerp(to, e)
			local pos = a:Lerp(b, e)
			p.Position = UDim2.fromOffset(pos.X - base.X, pos.Y - base.Y)
			p.Rotation = t * 200
			local s = size * (1 + math.sin(t * math.pi) * 0.35) * (1 - t * 0.45)
			p.Size = UDim2.fromOffset(s, s)
		end
		p:Destroy()
		if onArrive then onArrive() end
	end)
end

function Fx.twinkle(width, height)
	local x, y = math.random() * width, math.random() * height
	local s = 6 + math.random() * 14
	local p = Instance.new("ImageLabel")
	p.BackgroundTransparency = 1
	p.Image = Fx.IMG.sparkle
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromOffset(x, y)
	p.Size = UDim2.fromOffset(0, 0)
	p.ImageColor3 = Color3.fromHSV(0.55 + math.random() * 0.25, 0.25, 1)
	p.ZIndex = 6
	p.Parent = layers.twinkles
	local t = 0.6 + math.random() * 0.8
	Fx.tween(p, t * 0.5, { Size = UDim2.fromOffset(s, s), Rotation = 45 }, Enum.EasingStyle.Sine)
	Fx.tween(p, t * 0.5, { Size = UDim2.fromOffset(0, 0), Rotation = 90 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In, t * 0.5)
	Debris:AddItem(p, t + 0.05)
end

local CONFETTI = {
	Color3.fromRGB(255, 214, 60), Color3.fromRGB(95, 205, 255), Color3.fromRGB(215, 130, 255),
	Color3.fromRGB(255, 105, 150), Color3.fromRGB(84, 255, 120), Color3.new(1, 1, 1),
}

function Fx.confetti(count)
	local layer = layers.screen
	local w, h = layer.AbsoluteSize.X, layer.AbsoluteSize.Y
	local bits = {}
	for i = 1, count do
		local col = CONFETTI[(i - 1) % #CONFETTI + 1]
		local s = h * (0.011 + math.random() * 0.01)
		local p
		local shape = i % 3
		if shape == 0 then
			p = Instance.new("ImageLabel")
			p.BackgroundTransparency = 1
			p.Image = Fx.IMG.hex
			p.ImageColor3 = col
			s *= 1.5
		elseif shape == 1 then
			p = Instance.new("ImageLabel")
			p.BackgroundTransparency = 1
			p.Image = Fx.IMG.sparkle
			p.ImageColor3 = col
			s *= 1.7
		else
			p = Instance.new("Frame")
			p.BorderSizePixel = 0
			p.BackgroundColor3 = col
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.3, 0)
			c.Parent = p
		end
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.ZIndex = 85
		local lane = i % 4
		local b = { p = p, w = s, h = shape == 2 and s * 1.8 or s, rot = math.random(0, 360), vr = (math.random() - 0.5) * 540,
			fs = 4 + math.random() * 6, ph = math.random() * 6.28, sw = 1.5 + math.random() * 2, delay = math.random() * 0.5 }
		if lane < 2 then
			b.x, b.y = math.random() * w, -h * (0.05 + math.random() * 0.25)
			b.vx, b.vy = (math.random() - 0.5) * w * 0.05, h * (0.1 + math.random() * 0.15)
		else
			local left = lane == 2
			b.x, b.y = left and -s or w + s, h * (0.85 + math.random() * 0.1)
			b.vx = (left and 1 or -1) * w * (0.3 + math.random() * 0.35)
			b.vy = -h * (1.05 + math.random() * 0.45)
			b.delay *= 0.3
		end
		p.Position = UDim2.fromOffset(b.x, b.y)
		p.Size = UDim2.fromOffset(b.w, b.h)
		p.Visible = false
		p.Parent = layer
		bits[#bits + 1] = b
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local alive = 0
		for _, b in bits do
			local p = b.p
			if p.Parent then
				if now - t0 >= b.delay then
					p.Visible = true
					b.vy = math.min(b.vy + h * 1.25 * dt, h * 0.32)
					b.vx *= 1 - math.min(1.6 * dt, 0.5)
					b.x += (b.vx + math.sin(now * b.sw + b.ph) * w * 0.035) * dt
					b.y += b.vy * dt
					b.rot += b.vr * dt
					local flip = math.abs(math.cos(now * b.fs + b.ph))
					p.Position = UDim2.fromOffset(b.x, b.y)
					p.Rotation = b.rot
					p.Size = UDim2.fromOffset(b.w * (0.2 + 0.8 * flip), b.h)
					local age = now - t0
					if age > 3.4 then
						local fade = math.clamp((age - 3.4) / 0.5, 0, 1)
						if p:IsA("ImageLabel") then p.ImageTransparency = fade else p.BackgroundTransparency = fade end
					end
					if b.y > h + 60 or age > 3.9 then p:Destroy() end
				end
				if p.Parent then alive += 1 end
			end
		end
		if alive == 0 then conn:Disconnect() end
	end)
end

function Fx.hyperspace(duration, rate)
	local layer = layers.screen
	local w, h = layer.AbsoluteSize.X, layer.AbsoluteSize.Y
	local cx, cy = w * 0.5, h * 0.5
	local maxR = math.sqrt(cx * cx + cy * cy) + 60
	local streaks = {}
	local t0 = os.clock()
	local acc = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local age = os.clock() - t0
		if age < duration then
			acc += dt * rate * (0.35 + math.min(age / duration, 1) * 1.8)
			while acc >= 1 do
				acc -= 1
				local f = Instance.new("Frame")
				f.BorderSizePixel = 0
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.BackgroundColor3 = Color3.fromHSV(0.55 + math.random() * 0.25, 0.15 + math.random() * 0.3, 1)
				f.ZIndex = 70
				local g = Instance.new("UIGradient")
				g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
				g.Parent = f
				f.Parent = layer
				streaks[#streaks + 1] = { f = f, a = math.random() * math.pi * 2, r = h * (0.03 + math.random() * 0.15),
					v = h * (0.25 + math.random() * 0.45), th = math.max(h * 0.0028 * (0.6 + math.random()), 1.5) }
			end
		end
		local alive = 0
		for _, s in streaks do
			if s.f.Parent then
				s.v *= 1 + dt * 3.4
				s.r += s.v * dt
				local len = math.min(s.v * 0.1, h * 0.4)
				local mid = s.r - len * 0.5
				s.f.Position = UDim2.fromOffset(cx + math.cos(s.a) * mid, cy + math.sin(s.a) * mid)
				s.f.Size = UDim2.fromOffset(len, s.th)
				s.f.Rotation = math.deg(s.a)
				if s.r - len > maxR then s.f:Destroy() else alive += 1 end
			end
		end
		if alive == 0 and age >= duration then conn:Disconnect() end
	end)
end

function Fx.converge(x, y, size, color, time)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + math.random() * 0.4
		local d = size * (1.8 + math.random() * 0.9)
		local s = size * (0.2 + math.random() * 0.14)
		local shard = Fx.image("over", Fx.IMG.hex, x + math.cos(a) * d, y + math.sin(a) * d, s, { ImageColor3 = color, Rotation = math.random(0, 360), ImageTransparency = 1 })
		Fx.tween(shard, time * 0.35, { ImageTransparency = 0 })
		Fx.tween(shard, time, { Position = UDim2.fromOffset(x, y), Rotation = shard.Rotation + math.random(200, 420), Size = UDim2.fromOffset(s * 0.35, s * 0.35) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Debris:AddItem(shard, time + 0.02)
	end
	for i = 1, 10 do
		local a = math.random() * math.pi * 2
		local d = size * (2.4 + math.random())
		local sp = Fx.image("over", Fx.IMG.sparkle, x + math.cos(a) * d, y + math.sin(a) * d, size * 0.18, { ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 1 })
		Fx.tween(sp, time * 0.4, { ImageTransparency = 0 })
		Fx.tween(sp, time * (0.85 + math.random() * 0.15), { Position = UDim2.fromOffset(x, y), Rotation = 180 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Debris:AddItem(sp, time + 0.02)
	end
end

function Fx.hexGrid()
	local layer = layers.screen
	local w, h = layer.AbsoluteSize.X, layer.AbsoluteSize.Y
	local box = h / 5.2
	local sx, sy = box * 0.686, box * 0.79
	local cx, cy = w * 0.5, h * 0.5
	local far = math.sqrt(cx * cx + cy * cy)
	local tiles = {}
	for col = -1, math.ceil(w / sx) + 1 do
		for row = -1, math.ceil(h / sy) + 1 do
			local x = col * sx
			local y = row * sy + (col % 2) * sy * 0.5
			local d = math.clamp(math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2) / far, 0, 1)
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = Fx.IMG.hex
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromOffset(x, y)
			img.Size = UDim2.fromOffset(0, 0)
			img.ImageColor3 = Color3.fromRGB(58, 36, 120):Lerp(Color3.fromRGB(14, 10, 36), d)
			img.ZIndex = 65
			img.Parent = layer
			tiles[#tiles + 1] = { img = img, d = d, x = x, y = y, base = img.ImageColor3, full = UDim2.fromOffset(box * 1.05, box * 1.05) }
		end
	end
	return tiles
end

function Fx.hexCover(tiles, dur, fromCenter)
	for _, t in tiles do
		local k = fromCenter and t.d or (1 - t.d)
		t.img.Rotation = fromCenter and -90 or 90
		Fx.tween(t.img, 0.3, { Size = t.full, Rotation = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, k * dur)
	end
end

function Fx.hexPulse(tiles, dur, color)
	local layer = layers.screen
	local w = layer.AbsoluteSize.X
	for _, t in tiles do
		local delay = math.clamp(t.x / w, 0, 1) * dur
		task.delay(delay, function()
			if not t.img.Parent then return end
			t.img.ImageColor3 = color
			Fx.tween(t.img, 0.35, { ImageColor3 = t.base }, Enum.EasingStyle.Quad)
		end)
	end
end

function Fx.hexReveal(tiles, dur, fromCenter)
	for _, t in tiles do
		local k = fromCenter and t.d or (1 - t.d)
		local tw = Fx.tween(t.img, 0.32, { Size = UDim2.fromOffset(0, 0), Rotation = fromCenter and 120 or -120 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In, k * dur)
		tw.Completed:Once(function() t.img:Destroy() end)
		Debris:AddItem(t.img, k * dur + 0.6)
	end
end

function Fx.beam(x1, y1, x2, y2, color, width, time)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1 then return end
	local b = Instance.new("Frame")
	b.BorderSizePixel = 0
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromOffset((x1 + x2) * 0.5, (y1 + y2) * 0.5)
	b.Size = UDim2.fromOffset(len, width)
	b.Rotation = math.deg(math.atan2(dy, dx))
	b.BackgroundColor3 = color
	b.ZIndex = 5
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.6) })
	g.Parent = b
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	b.Parent = layers.under
	Fx.tween(b, time, { Size = UDim2.fromOffset(len, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(b, time + 0.05)
end

function Fx.clear()
	for _, l in layers do
		for _, c in l:GetChildren() do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end
end

return Fx
