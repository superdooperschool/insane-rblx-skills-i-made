local Cam = {}
Cam.__index = Cam

local SAFE = { left = 0.07, right = 0.07, top = 0.08, bottom = 0.1 }

local function backInOut(t, s)
	s *= 1.525
	t *= 2
	if t < 1 then
		return 0.5 * (t * t * ((s + 1) * t - s))
	end
	t -= 2
	return 0.5 * (t * t * ((s + 1) * t + s) + 2)
end

local function smooth(t)
	return t * t * (3 - 2 * t)
end

function Cam.new(world, canvas, zoom)
	return setmetatable({
		world = world, canvas = canvas, zoom = zoom,
		x = 0, y = 0, z = 1, tx = 0, ty = 0, tz = 1,
		minZ = 0.12, maxZ = 3.2, flight = nil,
	}, Cam)
end

function Cam:clampZ(z)
	return math.clamp(z, self.minZ, self.maxZ)
end

function Cam:apply()
	local size = self.world.AbsoluteSize
	self.zoom.Scale = self.z
	self.canvas.Position = UDim2.fromOffset(size.X * 0.5 - self.x * self.z, size.Y * 0.5 - self.y * self.z)
end

function Cam:step(dt)
	local f = self.flight
	if f then
		f.t = math.min(f.t + dt / f.duration, 1)
		local a = backInOut(f.t, f.s)
		self.x = f.x0 + (f.x1 - f.x0) * a
		self.y = f.y0 + (f.y1 - f.y0) * a
		local lz = math.log(f.z0) + (math.log(f.z1) - math.log(f.z0)) * smooth(f.t)
		self.z = math.exp(lz) * (1 - f.dip * math.sin(math.pi * f.t))
		if f.t >= 1 then
			self.flight = nil
			self.tx, self.ty, self.tz = f.x1, f.y1, f.z1
			if f.done then task.spawn(f.done) end
		end
	else
		local k = 1 - math.exp(-dt * 7.5)
		self.x += (self.tx - self.x) * k
		self.y += (self.ty - self.y) * k
		self.z = math.exp(math.log(self.z) + (math.log(self.tz) - math.log(self.z)) * k)
	end
	self:apply()
end

function Cam:fly(x, y, z, duration, opts)
	opts = opts or {}
	local prev = self.flight
	if prev and prev.done then task.spawn(prev.done) end
	self.flight = {
		t = 0, duration = math.max(duration, 0.01), s = opts.s or 1,
		x0 = self.x, y0 = self.y, z0 = self.z,
		x1 = x, y1 = y, z1 = self:clampZ(z), dip = opts.dip or 0.06, done = opts.done,
	}
end

function Cam:flyWait(x, y, z, duration, opts)
	local finished = false
	opts = table.clone(opts or {})
	opts.done = function() finished = true end
	self:fly(x, y, z, duration, opts)
	local t0 = os.clock()
	while not finished and os.clock() - t0 < duration + 1 do
		task.wait()
	end
end

function Cam:goTo(x, y, z)
	if self.flight then
		local done = self.flight.done
		self.flight = nil
		if done then task.spawn(done) end
	end
	self.tx, self.ty, self.tz = x, y, self:clampZ(z or self.tz)
end

function Cam:snap(x, y, z)
	self:goTo(x, y, z)
	self.x, self.y, self.z = self.tx, self.ty, self.tz
	self:apply()
end

function Cam:safe()
	local size = self.world.AbsoluteSize
	local w = size.X * (1 - SAFE.left - SAFE.right)
	local h = size.Y * (1 - SAFE.top - SAFE.bottom)
	local ox = size.X * (SAFE.left - SAFE.right) * 0.5
	local oy = size.Y * (SAFE.top - SAFE.bottom) * 0.5
	return w, h, ox, oy
end

function Cam:fit(minx, miny, maxx, maxy, pad, maxZ)
	pad = pad or 0
	local w, h, ox, oy = self:safe()
	local bw, bh = math.max(maxx - minx + pad * 2, 1), math.max(maxy - miny + pad * 2, 1)
	local z = self:clampZ(math.min(w / bw, h / bh, maxZ or self.maxZ))
	local cx, cy = (minx + maxx) * 0.5, (miny + maxy) * 0.5
	return cx - ox / z, cy - oy / z, z
end

function Cam:focus(x, y, span)
	local w, h = self:safe()
	return x, y, self:clampZ(math.min(w, h) / span)
end

function Cam:toScreen(x, y)
	local size = self.world.AbsoluteSize
	local pos = self.world.AbsolutePosition
	return Vector2.new(pos.X + size.X * 0.5 + (x - self.x) * self.z, pos.Y + size.Y * 0.5 + (y - self.y) * self.z)
end

function Cam:toWorld(px, py)
	local size = self.world.AbsoluteSize
	local pos = self.world.AbsolutePosition
	return self.x + (px - pos.X - size.X * 0.5) / self.z, self.y + (py - pos.Y - size.Y * 0.5) / self.z
end

function Cam:zoomAt(px, py, factor)
	local wx, wy = self:toWorld(px, py)
	local z = self:clampZ(self.tz * factor)
	local size = self.world.AbsoluteSize
	local pos = self.world.AbsolutePosition
	local sx, sy = px - pos.X - size.X * 0.5, py - pos.Y - size.Y * 0.5
	self:goTo(wx - sx / z, wy - sy / z, z)
end

function Cam:pan(dx, dy)
	self:goTo(self.tx - dx / self.z, self.ty - dy / self.z, self.tz)
end

return Cam
