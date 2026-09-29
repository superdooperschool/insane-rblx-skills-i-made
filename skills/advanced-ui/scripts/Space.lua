local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Space = {}

local GLOW = "rbxassetid://12064824932"
local SOFT = "rbxassetid://118302663239247"
local SPARK = "rbxassetid://112882057182762"

local NEBULA = {
	Color3.fromRGB(190, 60, 255), Color3.fromRGB(110, 70, 255), Color3.fromRGB(50, 120, 255),
	Color3.fromRGB(30, 190, 230), Color3.fromRGB(255, 80, 170), Color3.fromRGB(140, 40, 220),
}

local function sprite(parent, image, x, y, size, color, alpha, z)
	local s = Instance.new("ImageLabel")
	s.BackgroundTransparency = 1
	s.Image = image
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.fromScale(x, y)
	s.Size = UDim2.fromScale(size, size)
	s.ImageColor3 = color
	s.ImageTransparency = alpha
	s.ZIndex = z
	s.Parent = parent
	return s
end

local function square(parent, name, size, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(size, size)
	f.ZIndex = z
	local a = Instance.new("UIAspectRatioConstraint")
	a.AspectRatio = 1
	a.DominantAxis = Enum.DominantAxis.Height
	a.Parent = f
	f.Parent = parent
	return f
end

local function layer(parent, name, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1.3, 1.3)
	f.ZIndex = z
	f.Parent = parent
	return f
end

function Space.build(parent, dense)
	local old = parent:FindFirstChild("Space")
	if old then old:Destroy() end
	local root = Instance.new("Frame")
	root.Name = "Space"
	root.BackgroundColor3 = Color3.new(1, 1, 1)
	root.BorderSizePixel = 0
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 2
	local sky = Instance.new("UIGradient")
	sky.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 6, 38)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(26, 10, 58)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 12, 36)),
	})
	sky.Rotation = 60
	sky.Parent = root
	local warp = Instance.new("UIScale")
	warp.Name = "Warp"
	warp.Parent = root
	root.Parent = parent

	local st = { root = root, sky = sky, warp = warp, t = 0, clouds = {}, layers = {}, rings = {}, stars = {}, nextShot = 1.5, twinkleAt = 0, spin = 0, spinVel = 0 }
	local k = dense and 1 or 0.55

	local neb = layer(root, "Nebula", 3)
	st.nebula = neb
	for i = 1, math.floor(11 * (dense and 1 or 0.7)) do
		local c = sprite(neb, SOFT, 0.15 + math.random() * 0.7, 0.15 + math.random() * 0.7, 0, NEBULA[(i - 1) % #NEBULA + 1], 0.8 + math.random() * 0.08, 3)
		local s = 0.35 + math.random() * 0.4
		c.Size = UDim2.fromScale(s, s)
		local a = Instance.new("UIAspectRatioConstraint")
		a.AspectRatio = 1.4 + math.random() * 0.6
		a.Parent = c
		c.Rotation = math.random(0, 180)
		st.clouds[#st.clouds + 1] = { img = c, x = c.Position.X.Scale, y = c.Position.Y.Scale, a = c.ImageTransparency, ph = math.random() * 6.28, sp = 0.05 + math.random() * 0.08 }
	end

	for li, spec in { { "Far", 4, 70, 0.0025, 0.004, 0.45 }, { "Mid", 5, 45, 0.004, 0.006, 0.3 }, { "Near", 6, 25, 0.006, 0.009, 0.15 } } do
		local l = layer(root, spec[1], spec[2])
		st.layers[li] = l
		for _ = 1, math.floor(spec[3] * k) do
			local s = spec[4] + math.random() * (spec[5] - spec[4])
			local hue = math.random() < 0.3 and Color3.fromRGB(170, 200, 255) or (math.random() < 0.15 and Color3.fromRGB(255, 220, 180) or Color3.new(1, 1, 1))
			local star = sprite(l, GLOW, math.random(), math.random(), s * 3, hue, spec[6] + math.random() * 0.3, spec[2])
			local a = Instance.new("UIAspectRatioConstraint")
			a.Parent = star
			st.stars[#st.stars + 1] = star
		end
	end

	local disc = square(root, "Galaxy", 1.25, 7)
	st.disc = disc
	local RINGS = dense and 11 or 8
	local ARMS = 2
	local TWIST = 2.6
	for r = 1, RINGS do
		local ring = Instance.new("Frame")
		ring.Name = "Ring" .. r
		ring.BackgroundTransparency = 1
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(1, 1)
		ring.ZIndex = 7
		ring.Parent = disc
		local rf = r / RINGS
		local radius = 0.03 + rf * 0.44
		for arm = 1, ARMS do
			for j = 1, math.floor(13 * k) + 2 do
				local rr = radius + (math.random() - 0.5) * 0.04
				local th = arm * math.pi + TWIST * math.log(rr / 0.03 + 1) + (math.random() - 0.5) * 0.5 + j * 0.02
				local warm = 1 - rf
				local col = Color3.fromRGB(170 + 85 * warm, 190 + 50 * warm, 255 - 70 * warm)
				local size = (0.006 + math.random() * 0.014) * (1.2 - rf * 0.5)
				local alpha = 0.15 + rf * 0.45 + math.random() * 0.2
				if math.random() < 0.08 then
					col = Color3.fromRGB(255, 110, 200)
					size *= 2.4
					alpha = 0.35
				end
				sprite(ring, GLOW, 0.5 + math.cos(th) * rr, 0.5 + math.sin(th) * rr, size * 3, col, alpha, 7)
			end
		end
		for arm = 1, ARMS do
			local th = arm * math.pi + TWIST * math.log(radius / 0.03 + 1)
			local haze = sprite(ring, SOFT, 0.5 + math.cos(th) * radius, 0.5 + math.sin(th) * radius, 0.1 + rf * 0.1, Color3.fromRGB(150, 125, 255), 0.8 + rf * 0.08, 7)
			haze.Rotation = math.deg(th)
		end
		for _ = 1, math.floor(6 * k) do
			local th = math.random() * math.pi * 2
			local rr = radius + (math.random() - 0.5) * 0.05
			sprite(ring, GLOW, 0.5 + math.cos(th) * rr, 0.5 + math.sin(th) * rr, 0.012 + math.random() * 0.01, Color3.fromRGB(200, 210, 255), 0.55 + math.random() * 0.3, 7)
		end
		st.rings[r] = { frame = ring, rf = rf }
	end
	st.coreBig = sprite(disc, SOFT, 0.5, 0.5, 0.42, Color3.fromRGB(255, 170, 120), 0.62, 8)
	st.coreMid = sprite(disc, GLOW, 0.5, 0.5, 0.22, Color3.fromRGB(255, 225, 190), 0.25, 8)
	st.coreHot = sprite(disc, GLOW, 0.5, 0.5, 0.09, Color3.new(1, 1, 1), 0, 8)
	st.shots = layer(root, "Shots", 8)
	return st
end

local function shootingStar(st)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.AnchorPoint = Vector2.new(1, 0.5)
	f.Size = UDim2.fromScale(0.12 + math.random() * 0.08, 0.0025)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.85, 0.35), NumberSequenceKeypoint.new(1, 0) })
	g.Parent = f
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local angle = 20 + math.random() * 25
	f.Rotation = angle
	local x0, y0 = 0.1 + math.random() * 0.6, 0.05 + math.random() * 0.35
	f.Position = UDim2.fromScale(x0, y0)
	f.ZIndex = 8
	f.Parent = st.shots
	local d = 0.35 + math.random() * 0.25
	local rad = math.rad(angle)
	local t = 0.55 + math.random() * 0.3
	TweenService:Create(f, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(x0 + math.cos(rad) * d, y0 + math.sin(rad) * d),
		BackgroundTransparency = 1,
	}):Play()
	Debris:AddItem(f, t + 0.05)
end

function Space.kick(st, speed)
	st.spinVel = speed
end

function Space.step(st, dt, cx, cy, z)
	st.t += dt
	local t = st.t
	st.spin += st.spinVel * dt
	st.spinVel *= math.exp(-dt * 1.7)
	for _, r in st.rings do
		r.frame.Rotation = t * 4 + 14 * math.sin(t * 0.25 + r.rf * 4) + st.spin * (1.15 - r.rf * 0.3)
	end
	local pulse = 1 + 0.07 * math.sin(t * 1.6)
	st.coreBig.Size = UDim2.fromScale(0.42 * pulse, 0.42 * pulse)
	st.coreMid.Size = UDim2.fromScale(0.22 * (2 - pulse), 0.22 * (2 - pulse))
	st.sky.Rotation = 60 + 12 * math.sin(t * 0.07)
	for _, c in st.clouds do
		c.img.Position = UDim2.fromScale(c.x + 0.03 * math.sin(t * c.sp + c.ph), c.y + 0.025 * math.cos(t * c.sp * 0.8 + c.ph))
		c.img.ImageTransparency = c.a + 0.05 * math.sin(t * c.sp * 3 + c.ph)
		c.img.Rotation += dt * 2 * c.sp
	end
	local px, py = -(cx or 0), -(cy or 0)
	st.nebula.Position = UDim2.new(0.5, px * 0.012, 0.5, py * 0.012)
	for i, l in st.layers do
		local f = 0.01 + i * 0.012
		l.Position = UDim2.new(0.5, px * f, 0.5, py * f)
	end
	st.disc.Position = UDim2.new(0.5, px * 0.02, 0.5, py * 0.02)
	local zs = 1 + math.clamp(math.log(math.max(z or 1, 0.05)), -1, 1) * 0.04
	st.disc.Size = UDim2.fromScale(1.25 * zs, 1.25 * zs)
	st.twinkleAt += dt
	if st.twinkleAt > 0.04 and #st.stars > 0 then
		st.twinkleAt = 0
		local s = st.stars[math.random(#st.stars)]
		local base = s.ImageTransparency
		local tw = TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), { ImageTransparency = math.max(base - 0.5, 0) })
		tw:Play()
	end
	st.nextShot -= dt
	if st.nextShot <= 0 then
		st.nextShot = 2.2 + math.random() * 3.5
		shootingStar(st)
		return true
	end
	return false
end

return Space
