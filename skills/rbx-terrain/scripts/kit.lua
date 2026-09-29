-- rbx-terrain kit. run.sh prepends this to a recipe and pipes both into `rbx lua -` (Edit datamodel).
-- Heightfield composer (mask, smooth base, additive + override features, rule paint, fractional-occupancy
-- write) plus SDF voxel ops for 3D pieces (bores, arches, skulls), baseline backup/restore and checks.
-- Every Terrain call stays <= 2048 studs per axis and <= 4,194,304 voxels.

local K = {}
local RES = 4
local T = workspace.Terrain
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local MAT = Enum.Material
local AIR, WATER = MAT.Air, MAT.Water
local MAX_VOX, MAX_AXIS = 4194304, 512
K.RES, K.MAT = RES, MAT
K.out = {}
local function log(s) K.out[#K.out + 1] = s end
K.log = log

local function cosb(t)
	if t <= 0 then return 1 elseif t >= 1 then return 0 end
	return 0.5 + 0.5 * math.cos(math.pi * t)
end
local function smooth01(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
K.cosb, K.smooth01 = cosb, smooth01
local function smax(a, b, k)
	local h = math.clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return a + (b - a) * h + k * h * (1 - h)
end
local function smin(a, b, k) return -smax(-a, -b, k) end

-- ============================================================ grid
function K.grid(box, pad)
	pad = pad or 96
	local cf, sz, part
	if typeof(box) == "string" then
		part = workspace:FindFirstChild(box)
		assert(part, "no box " .. box)
		cf, sz = part.CFrame, part.Size
	else
		cf, sz = CFrame.new(box.center), box.size
	end
	local G = { name = typeof(box) == "string" and box or (box.name or "scratch"), box = part }
	G.x0 = math.floor((cf.X - sz.X / 2) / RES) * RES
	G.z0 = math.floor((cf.Z - sz.Z / 2) / RES) * RES
	G.y0 = math.floor((cf.Y - sz.Y / 2 - pad) / RES) * RES
	G.y1 = math.ceil((cf.Y + sz.Y / 2 + pad) / RES) * RES
	G.NX = (math.ceil((cf.X + sz.X / 2) / RES) * RES - G.x0) / RES
	G.NZ = (math.ceil((cf.Z + sz.Z / 2) / RES) * RES - G.z0) / RES
	G.NY = (G.y1 - G.y0) / RES
	G.x1, G.z1 = G.x0 + G.NX * RES, G.z0 + G.NZ * RES
	return G
end
local function ix(G, gx, gz) return (gx - 1) * G.NZ + gz end
K.ix = ix
function K.cellXZ(G, gx, gz) return G.x0 + (gx - 0.5) * RES, G.z0 + (gz - 0.5) * RES end
function K.cellOf(G, x, z) return math.floor((x - G.x0) / RES) + 1, math.floor((z - G.z0) / RES) + 1 end
local function inGrid(G, gx, gz) return gx >= 1 and gz >= 1 and gx <= G.NX and gz <= G.NZ end

local function region(G, ax, bx, az, bz, ylo, yhi)
	return Region3.new(Vector3.new(G.x0 + (ax - 1) * RES, ylo, G.z0 + (az - 1) * RES), Vector3.new(G.x0 + bx * RES, yhi, G.z0 + bz * RES))
end

local function eachTile(G, ny, width, fn)
	local tz = math.min(G.NZ, MAX_AXIS, math.max(1, math.floor(MAX_VOX / (ny * width))))
	for gx = 1, G.NX, width do
		for gz = 1, G.NZ, tz do
			fn(gx, math.min(G.NX, gx + width - 1), gz, math.min(G.NZ, gz + tz - 1))
			task.wait()
		end
	end
end

-- ============================================================ read
function K.read(G)
	local H, M, GAP, WAT = {}, {}, {}, {}
	local NY = G.NY
	eachTile(G, NY, 32, function(ax, bx, az, bz)
		local mats, occs = T:ReadVoxels(region(G, ax, bx, az, bz, G.y0, G.y1), RES)
		for dx = 1, bx - ax + 1 do
			local mx, ox = mats[dx], occs[dx]
			for dz = 1, bz - az + 1 do
				local i = ix(G, ax + dx - 1, az + dz - 1)
				local seen, inGap, gs = false, false, 0
				for iy = NY, 1, -1 do
					local m, o = mx[iy][dz], ox[iy][dz]
					if m == WATER then
						if o > 0.05 and not seen then WAT[i] = true end
					elseif m ~= AIR and o > 0.05 then
						if not seen then
							seen = true
							H[i] = G.y0 + (iy - 1) * RES + o * RES
							M[i] = m
						elseif inGap then
							inGap = false
							if (gs - iy) * RES >= 8 then GAP[i] = true end
						end
					elseif seen and not inGap then
						inGap, gs = true, iy
					end
				end
			end
		end
	end)
	G.H, G.M, G.GAP, G.WAT = H, M, GAP, WAT
	return G
end

function K.slope(G, H)
	local S, NX, NZ = {}, G.NX, G.NZ
	for gx = 1, NX do
		for gz = 1, NZ do
			local i = (gx - 1) * NZ + gz
			local h = H[i]
			if h then
				local xp = gx < NX and H[i + NZ] or h
				local xm = gx > 1 and H[i - NZ] or h
				local zp = gz < NZ and H[i + 1] or h
				local zm = gz > 1 and H[i - 1] or h
				local a, b = (xp - xm) / (2 * RES), (zp - zm) / (2 * RES)
				S[i] = math.deg(math.atan(math.sqrt(a * a + b * b)))
			end
		end
	end
	return S
end

-- box mean over (2r+1)^2 cells via summed-area table; nil cells ignored
local function boxMean(G, H, r, valid)
	local NX, NZ = G.NX, G.NZ
	local S, C = {}, {}
	for gx = 0, NX do S[gx * (NZ + 1)] = 0; C[gx * (NZ + 1)] = 0 end
	for gz = 0, NZ do S[gz] = 0; C[gz] = 0 end
	for gx = 1, NX do
		for gz = 1, NZ do
			local k = gx * (NZ + 1) + gz
			local i0 = (gx - 1) * NZ + gz
			local h = H[i0]
			if valid and not valid[i0] then h = nil end
			S[k] = S[k - NZ - 1] + S[k - 1] - S[k - NZ - 2] + (h or 0)
			C[k] = C[k - NZ - 1] + C[k - 1] - C[k - NZ - 2] + (h and 1 or 0)
		end
	end
	local out = {}
	for gx = 1, NX do
		local ax, bx = math.max(1, gx - r), math.min(NX, gx + r)
		for gz = 1, NZ do
			local i = (gx - 1) * NZ + gz
			if H[i] then
				local az, bz = math.max(1, gz - r), math.min(NZ, gz + r)
				local k1, k2, k3, k4 = bx * (NZ + 1) + bz, (ax - 1) * (NZ + 1) + bz, bx * (NZ + 1) + az - 1, (ax - 1) * (NZ + 1) + az - 1
				local c = C[k1] - C[k2] - C[k3] + C[k4]
				out[i] = c > 0 and (S[k1] - S[k2] - S[k3] + S[k4]) / c or H[i]
			end
		end
	end
	return out
end
K.boxMean = boxMean

-- valid (optional): only those cells feed the average, so smoothing next to a cliff never pulls the
-- cliff's height into the meadow
function K.blur(G, H, r, passes, valid)
	local cur = H
	for _ = 1, passes or 2 do cur = boxMean(G, cur, r, valid) end
	return cur
end

-- Slope limiter for revamps (thermal erosion): wherever two neighbours differ by more than the talus
-- step, material slides from the high cell to the low one. A 35 deg bank becomes a <= deg bank twice as
-- wide, volume kept, crest and toe rounded by a final light blur. Cells with W = 0 (pads, locked ground)
-- never move; transfers scale with the smaller mask weight of the pair so the feather stays seamless.
function K.regrade(G, H, deg, iters)
	local NX, NZ, W = G.NX, G.NZ, G.W
	local talus = math.tan(math.rad(deg)) * RES
	local cur = {}
	for i, h in pairs(H) do cur[i] = h end
	for _ = 1, iters do
		local moved = 0
		for gx = 1, NX do
			for gz = 1, NZ do
				local i = (gx - 1) * NZ + gz
				local h, wi = cur[i], W[i] or 0
				if h and wi > 0 then
					for k = 1, 2 do
						local j = (k == 1 and gx < NX) and i + NZ or ((k == 2 and gz < NZ) and i + 1 or nil)
						local hj = j and cur[j]
						if hj then
							local wj = W[j] or 0
							local d = h - hj
							local ex = math.abs(d) - talus
							if ex > 0 and wj > 0 then
								local t = ex * 0.25 * math.min(wi, wj) * (d > 0 and 1 or -1)
								cur[i] -= t
								cur[j] += t
								h = cur[i]
								moved += 1
							end
						end
					end
				end
			end
		end
		if moved == 0 then break end
		task.wait()
	end
	local soft = K.blur(G, cur, 1, 1)
	for i, h in pairs(cur) do
		local w = W[i] or 0
		if w > 0 then cur[i] = h + w * (soft[i] - h) end
	end
	return cur
end

-- Final guard on the composed surface: no edited cell may exceed `deg` against any neighbour. Cells with
-- W = 0 (prop pads, locked ground) are fixed; an edited cell next to one relaxes toward it on its own, so
-- a tree left on an old steep bank ends up on a smooth skirt instead of a notch or pillar.
function K.limitSlope(G, H, deg, iters)
	local NX, NZ, W = G.NX, G.NZ, G.W
	local talus = math.tan(math.rad(deg)) * RES
	local cur = {}
	for i, h in pairs(H) do cur[i] = h end
	for _ = 1, iters do
		local moved = 0
		for gx = 1, NX do
			for gz = 1, NZ do
				local i = (gx - 1) * NZ + gz
				local h = cur[i]
				if h then
					local mi = (W[i] or 0) > 0
					for k = 1, 2 do
						local j = (k == 1 and gx < NX) and i + NZ or ((k == 2 and gz < NZ) and i + 1 or nil)
						local hj = j and cur[j]
						if hj then
							local mj = (W[j] or 0) > 0
							local d = h - hj
							local ex = math.abs(d) - talus
							if ex > 0.01 and (mi or mj) then
								local sg = d > 0 and 1 or -1
								if mi and mj then
									cur[i] -= sg * ex * 0.25
									cur[j] += sg * ex * 0.25
								elseif mi then
									cur[i] -= sg * ex * 0.5
								else
									cur[j] += sg * ex * 0.5
								end
								h = cur[i]
								moved += 1
							end
						end
					end
				end
			end
		end
		if moved == 0 then break end
	end
	return cur
end

function K.climbGuard(G, H, deg, rounds, keep, opt)
	opt = opt or {}
	local NX, NZ, W = G.NX, G.NZ, G.W
	local la = math.tan(math.rad(deg)) * math.cos(math.pi / 8) * RES
	local ld = la * math.sqrt(2)
	local function free(i) return H[i] ~= nil and (W[i] or 0) > 0 and not keep[i] end
	local edgeKeep = {}
	for i in pairs(keep) do
		if H[i] then
			local gx, gz = (i - 1) // NZ + 1, (i - 1) % NZ + 1
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local x2, z2 = gx + d[1], gz + d[2]
				local j = (x2 - 1) * NZ + z2
				if x2 >= 1 and z2 >= 1 and x2 <= NX and z2 <= NZ and H[j] and (W[j] or 0) > 0 and not keep[j] then edgeKeep[i] = true break end
			end
		end
	end
	local function anchor(i) return H[i] ~= nil and (edgeKeep[i] or ((W[i] or 0) == 0 and not keep[i] and not (G.WHY and G.WHY[i]))) end
	local FREE = {}
	local Rs, DIAG = opt.guardSource or 160, RES * math.sqrt(2)
	local function sweep(E, sign, Dsrc)
		local changed = true
		local r = 0
		while changed and r < (rounds or 8) do
			changed, r = false, r + 1
			for pass = 1, 2 do
				local a1, b1, st = 1, NX, 1
				if pass == 2 then a1, b1, st = NX, 1, -1 end
				for gx = a1, b1, st do
					local px = gx - st
					local pxOk = px >= 1 and px <= NX
					for gz = (st == 1 and 1 or NZ), (st == 1 and NZ or 1), st do
						local i = (gx - 1) * NZ + gz
						local v = E[i]
						if v and FREE[i] then
							local v0, dv = v, Dsrc[i]
							local qz = gz - st
							for q = 1, 4 do
								local j, w, dd
								if q == 1 then if qz >= 1 and qz <= NZ then j, w, dd = i - st, la, RES end
								elseif pxOk then
									local jb = i - st * NZ
									if q == 2 then j, w, dd = jb, la, RES
									elseif q == 3 then if gz > 1 then j, w, dd = jb - 1, ld, DIAG end
									elseif gz < NZ then j, w, dd = jb + 1, ld, DIAG end
								end
								if j then
									local e, dj = E[j], Dsrc[j]
									if e and dj + dd <= Rs then
										local c = e + sign * w
										if (sign > 0 and c < v) or (sign < 0 and c > v) then v = c; dv = dj + dd end
									end
								end
							end
							if math.abs(v - v0) > 1e-6 then E[i] = v; Dsrc[i] = dv; changed = true end
						end
					end
				end
			end
			task.wait()
		end
		return r
	end
	local U, Lo, DU, DL = {}, {}, {}, {}
	for i in pairs(H) do if free(i) then FREE[i] = true end if free(i) or anchor(i) then U[i], Lo[i], DU[i], DL[i] = H[i], H[i], 0, 0 end end
	local ru, rl = sweep(U, 1, DU), sweep(Lo, -1, DL)
	local CU, CL, DCU, DCL = {}, {}, {}, {}
	for i in pairs(U) do
		if anchor(i) then CU[i], CL[i], DCU[i], DCL[i] = H[i], H[i], 0, 0 else CU[i], CL[i], DCU[i], DCL[i] = 1e9, -1e9, 1e9, 1e9 end
	end
	sweep(CU, 1, DCU)
	sweep(CL, -1, DCL)
	local tanD = math.tan(math.rad(deg))
	local VD, big = {}, 1e9
	for i in pairs(H) do
		if free(i) then
			local gx, gz = (i - 1) // NZ + 1, (i - 1) % NZ + 1
			local h = H[i]
			local xp = gx < NX and H[i + NZ] or h
			local xm = gx > 1 and H[i - NZ] or h
			local zp = gz < NZ and H[i + 1] or h
			local zm = gz > 1 and H[i - 1] or h
			VD[i] = (((xp - xm) / (2 * RES)) ^ 2 + ((zp - zm) / (2 * RES)) ^ 2 > tanD * tanD) and 0 or big
		end
	end
	local reachR, featherR = opt.guardReach or 56, opt.guardFeather or 48
	for pass = 1, 2 do
		local a1, b1, st = 1, NX, 1
		if pass == 2 then a1, b1, st = NX, 1, -1 end
		for gx = a1, b1, st do
			for gz = (st == 1 and 1 or NZ), (st == 1 and NZ or 1), st do
				local i = (gx - 1) * NZ + gz
				local v = VD[i]
				if v and v > 0 then
					local px = gx - st
					if gz - st >= 1 and gz - st <= NZ and VD[i - st] then v = math.min(v, VD[i - st] + RES) end
					if px >= 1 and px <= NX then
						local j = i - st * NZ
						if VD[j] then v = math.min(v, VD[j] + RES) end
						if gz > 1 and VD[j - 1] then v = math.min(v, VD[j - 1] + RES * 1.414) end
						if gz < NZ and VD[j + 1] then v = math.min(v, VD[j + 1] + RES * 1.414) end
					end
					VD[i] = v
				end
			end
		end
	end
	local cap = opt.guardCap or 16
	local cur, touched, n, capped = {}, {}, 0, 0
	for i, h in pairs(H) do
		cur[i] = h
		if U[i] and free(i) and VD[i] and VD[i] < reachR + featherR then
			local m = math.clamp((U[i] + Lo[i]) / 2, math.min(CL[i], CU[i]), math.max(CL[i], CU[i]))
			if math.abs(m - h) > cap then capped += 1; m = h + math.clamp(m - h, -cap, cap) end
			m = h + (m - h) * (1 - smooth01((VD[i] - reachR) / featherR))
			if math.abs(m - h) > 0.01 then cur[i] = m; touched[i] = true; n += 1 end
		end
	end
	local zone = {}
	for i in pairs(touched) do
		local gx, gz = (i - 1) // NZ + 1, (i - 1) % NZ + 1
		for dx = -3, 3 do
			for dz = -3, 3 do
				local x2, z2 = gx + dx, gz + dz
				if x2 >= 1 and z2 >= 1 and x2 <= NX and z2 <= NZ and free((x2 - 1) * NZ + z2) then zone[(x2 - 1) * NZ + z2] = true end
			end
		end
	end
	for _ = 1, opt.guardSmooth or 4 do
		local soft = {}
		for i in pairs(zone) do
			local gx, gz = (i - 1) // NZ + 1, (i - 1) % NZ + 1
			local sum, c = 0, 0
			for dx = -1, 1 do
				for dz = -1, 1 do
					local x2, z2 = gx + dx, gz + dz
					local j = (x2 - 1) * NZ + z2
					if x2 >= 1 and z2 >= 1 and x2 <= NX and z2 <= NZ and (free(j) or anchor(j)) then sum += cur[j]; c += 1 end
				end
			end
			soft[i] = math.clamp(sum / c, math.min(CL[i], CU[i]), math.max(CL[i], CU[i]))
		end
		for i, v in pairs(soft) do cur[i] = v end
	end
	local S = K.slope(G, cur)
	local left, kc = 0, 0
	for i in pairs(U) do if free(i) and S[i] and S[i] > deg + 0.5 then left += 1 end end
	for _ in pairs(keep) do kc += 1 end
	log(string.format("climb guard %d deg: %d cells reshaped within %d studs of a violation (sweep rounds %d/%d), %d changes capped at %d studs, %d free cells still > %.1f deg, %d steep-kept", deg, n, reachR + featherR, ru, rl, capped, cap, left, deg + 0.5, kc))
	return cur
end

-- ============================================================ mask
local function distField(G, blocked)
	local NX, NZ, INF = G.NX, G.NZ, 1e9
	local D = {}
	for i = 1, NX * NZ do D[i] = blocked[i] and 0 or INF end
	local a, b = RES, RES * 1.41421
	for gx = 1, NX do
		for gz = 1, NZ do
			local i = (gx - 1) * NZ + gz
			local d = D[i]
			if d > 0 then
				if gx > 1 then
					d = math.min(d, D[i - NZ] + a)
					if gz > 1 then d = math.min(d, D[i - NZ - 1] + b) end
					if gz < NZ then d = math.min(d, D[i - NZ + 1] + b) end
				end
				if gz > 1 then d = math.min(d, D[i - 1] + a) end
				D[i] = d
			end
		end
	end
	for gx = NX, 1, -1 do
		for gz = NZ, 1, -1 do
			local i = (gx - 1) * NZ + gz
			local d = D[i]
			if d > 0 then
				if gx < NX then
					d = math.min(d, D[i + NZ] + a)
					if gz < NZ then d = math.min(d, D[i + NZ + 1] + b) end
					if gz > 1 then d = math.min(d, D[i + NZ - 1] + b) end
				end
				if gz < NZ then d = math.min(d, D[i + 1] + a) end
				D[i] = d
			end
		end
	end
	return D
end

-- opt: yMin, yMax, maxSlope(30), buffer(40), feather(24), minBlob(16 cells: smaller slope-only lumps ignored)
function K.mask(G, opt)
	opt = opt or {}
	local maxSlope, buffer, feather = opt.maxSlope or 30, opt.buffer or 12, opt.feather or 16
	local hard = opt.hardMats or { [MAT.Basalt] = true, [MAT.Rock] = true }
	local S = K.slope(G, G.H)
	G.S = S
	local N = G.NX * G.NZ
	local blocked, hardCell, why = {}, {}, {}
	for i = 1, N do
		local h = G.H[i]
		local w = (not h and "0") or (G.GAP[i] and "^") or (G.WAT[i] and "~") or (hard[G.M[i]] and "x") or (((opt.yMin and h < opt.yMin) or (opt.yMax and h > opt.yMax)) and "y")
		if w then
			blocked[i], hardCell[i], why[i] = true, true, w
		elseif S[i] > maxSlope then
			blocked[i], why[i] = true, "/"
		end
	end
	G.WHY = why
	-- slope-only lumps smaller than minBlob are bumps to smooth away, not boundaries
	local minBlob, seen = opt.minBlob or 16, {}
	for i = 1, N do
		if blocked[i] and not hardCell[i] and not seen[i] then
			local comp, stack, touchesHard = {}, { i }, false
			seen[i] = true
			while #stack > 0 do
				local c = table.remove(stack)
				comp[#comp + 1] = c
				local gx, gz = (c - 1) // G.NZ + 1, (c - 1) % G.NZ + 1
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local nx, nz = gx + d[1], gz + d[2]
					if inGrid(G, nx, nz) then
						local j = ix(G, nx, nz)
						if hardCell[j] then touchesHard = true end
						if blocked[j] and not hardCell[j] and not seen[j] then seen[j] = true; stack[#stack + 1] = j end
					end
				end
			end
			if #comp < minBlob and not touchesHard then
				for _, c in ipairs(comp) do blocked[c] = nil; why[c] = nil end
			end
		end
	end
	local D = distField(G, blocked)
	local W, DIST = {}, {}
	for gx = 1, G.NX do
		for gz = 1, G.NZ do
			local i = ix(G, gx, gz)
			local ex0, ex1, ez0, ez1 = G.x0, G.x1, G.z0, G.z1
			if G.edge then ex0, ex1, ez0, ez1 = G.edge[1], G.edge[2], G.edge[3], G.edge[4] end
			local x, z = K.cellXZ(G, gx, gz)
			local edge = math.min(x - ex0, ex1 - x, z - ez0, ez1 - z)
			local rc = opt.round or math.min(ex1 - ex0, ez1 - ez0) * 0.15
			if rc > 0 then
				local qx = math.abs(x - (ex0 + ex1) / 2) - ((ex1 - ex0) / 2 - rc)
				local qz = math.abs(z - (ez0 + ez1) / 2) - ((ez1 - ez0) / 2 - rc)
				edge = -(math.sqrt(math.max(qx, 0) ^ 2 + math.max(qz, 0) ^ 2) + math.min(math.max(qx, qz), 0) - rc)
			end
			DIST[i] = math.min(D[i], edge)
			W[i] = G.H[i] and smooth01((DIST[i] - buffer) / feather) or 0
		end
	end
	G.W, G.DIST = W, DIST
	return W
end

local function scaleMaskAround(G, x, z, r, feather)
	local reach = r + feather
	local ax, az = K.cellOf(G, x - reach, z - reach)
	local bx, bz = K.cellOf(G, x + reach, z + reach)
	for gx = math.max(1, ax), math.min(G.NX, bx) do
		for gz = math.max(1, az), math.min(G.NZ, bz) do
			local cx, cz = K.cellXZ(G, gx, gz)
			local d = math.sqrt((cx - x) ^ 2 + (cz - z) ^ 2)
			if d < reach then
				local i = ix(G, gx, gz)
				G.W[i] = G.W[i] * smooth01((d - r) / feather)
			end
		end
	end
end

-- Every part resting on the ground (trees, spawns, signs, shops, water planes) gets a pad of untouched
-- terrain so nothing floats or buries and no prop ever moves. Big invisible volumes are skipped.
-- Trees (children of workspace.Assets.Trees) are not pads: they ride the new ground and are relocated
-- by the user's placement rules (K.placeTrees). Their original pivots are backed up with the terrain.
function K.findTrees(G)
	local list = {}
	local folder = workspace:FindFirstChild("Assets") and workspace.Assets:FindFirstChild("Trees")
	for _, t in ipairs(folder and folder:GetChildren() or {}) do
		if t:IsA("PVInstance") then
			local cf, sz
			if t:IsA("Model") then
				local ok, a, b = pcall(t.GetBoundingBox, t)
				if ok then cf, sz = a, b end
			elseif t:IsA("BasePart") then
				cf, sz = t.CFrame, t.Size
			end
			local orig0 = G.treeOrig and G.treeOrig[t]
			if orig0 and cf then cf = cf + (orig0.Position - t:GetPivot().Position) end
			if cf and cf.X > G.x0 and cf.X < G.x1 and cf.Z > G.z0 and cf.Z < G.z1 then
				list[#list + 1] = { inst = t, x = cf.X, z = cf.Z, bottom = cf.Y - sz.Y / 2 }
			end
		end
	end
	return list
end

function K.protect(G, opt)
	opt = opt or {}
	local pads, skip = {}, {}
	for _, inst in ipairs(opt.exclude or {}) do skip[inst] = true end
	if G.box then skip[G.box] = true end
	G.trees = {}
	if opt.trees ~= false then
		for _, t in ipairs(K.findTrees(G)) do
			local gx, gz = K.cellOf(G, t.x, t.z)
			if inGrid(G, gx, gz) and G.H[ix(G, gx, gz)] then
				t.i = ix(G, gx, gz)
				G.trees[#G.trees + 1] = t
				skip[t.inst] = true
				for _, d in ipairs(t.inst:GetDescendants()) do skip[d] = true end
			end
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and not skip[d] then
			local p = d.Position
			if p.X > G.x0 and p.X < G.x1 and p.Z > G.z0 and p.Z < G.z1 then
				local cf, s = d.CFrame, d.Size
				local ex = (math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z) / 2
				local ey = (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
				local ez = (math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z) / 2
				local span = math.max(ex, ez) * 2
				local ghost = d.Transparency >= 0.99 and not d.CanCollide
				if span < 400 and not (ghost and span > 40) then
					local gx, gz = K.cellOf(G, p.X, p.Z)
					local h = inGrid(G, gx, gz) and G.H[ix(G, gx, gz)]
					if h and p.Y - ey < h + 12 and p.Y + ey > h - 12 then
						-- tall things (trees, lanterns, signs) touch the ground at a trunk; flat things
						-- (platforms, water planes, rugs) touch it across their whole footprint
						local foot = (ey * 2 > span * 0.6) and math.min(span / 2, 10) or math.min(span / 2, 120)
						pads[#pads + 1] = { x = p.X, z = p.Z, r = foot + (opt.margin or 6), name = d:GetFullName() }
					end
				end
			end
		end
	end
	for _, pd in ipairs(pads) do scaleMaskAround(G, pd.x, pd.z, pd.r, opt.feather or 10) end
	G.pads = pads
	return pads
end

-- world rect kept untouched (zone gates, spawn plazas), feathered outward
function K.keep(G, xa, xb, za, zb, feather)
	feather = feather or 16
	G.keeps = G.keeps or {}
	table.insert(G.keeps, { xa, xb, za, zb })
	for gx = 1, G.NX do
		for gz = 1, G.NZ do
			local x, z = K.cellXZ(G, gx, gz)
			local dx = math.max(xa - x, 0, x - xb)
			local dz = math.max(za - z, 0, z - zb)
			local d = math.sqrt(dx * dx + dz * dz)
			if d < feather then
				local i = ix(G, gx, gz)
				G.W[i] = G.W[i] * smooth01(d / feather)
			end
		end
	end
end

-- ============================================================ features
-- A feature: { kind, bbox = {xa, xb, za, zb}, add = fn(x, z) -> dh | nil,
--              over = fn(x, z, hCur, G) -> hTarget, weight | nil, paint = fn(x, z, dh) -> Material | nil,
--              tag = fn(x, z) -> string | nil, hit = fn(x, z) -> bool }
local function rot(x, z, cx, cz, deg)
	local a = math.rad(deg or 0)
	local dx, dz = x - cx, z - cz
	return dx * math.cos(a) + dz * math.sin(a), -dx * math.sin(a) + dz * math.cos(a)
end

function K.mound(o)
	local rx, rz, h = o.rx or o.r, o.rz or o.r, o.h
	if not o.on and h * math.pi / (2 * math.min(rx, rz)) > math.tan(math.rad(20.5)) then log(string.format("WARN mound %s flank %.1f deg > 20 (user round 5: r >= 4.5 h); the climb guard will cap it at 22", o.name or "?", math.deg(math.atan(h * math.pi / (2 * math.min(rx, rz)))))) end
	local R = math.max(rx, rz)
	return {
		kind = "mound", name = o.name, bbox = { o.x - R, o.x + R, o.z - R, o.z + R },
		add = function(x, z)
			local u, v = rot(x, z, o.x, o.z, o.rot)
			local d = math.sqrt((u / rx) ^ 2 + (v / rz) ^ 2)
			if d >= 1 then return nil end
			return h * cosb(d) + (o.on and o.on.add(x, z) or 0)
		end,
		paint = function(x, z, dh)
			if not dh then return nil end
			if dh > h * (o.crestAt or 0.72) then return o.crest end
			if dh > h * 0.12 then return o.flank end
		end,
		hit = function(x, z)
			local u, v = rot(x, z, o.x, o.z, o.rot)
			return (u / rx) ^ 2 + (v / rz) ^ 2 < 1
		end,
	}
end

function K.ring(o)
	local R, h, dish = o.R, o.h, o.dish or 0
	local w = math.max(o.w, h * math.pi / (2 * math.tan(math.rad(o.maxDeg or 20))))
	if w > o.w then log(string.format("ring %s w %d -> %d so the rim stays <= %d deg", o.name or "?", o.w, math.ceil(w), o.maxDeg or 20)) end
	local reach = R + w
	return {
		kind = "ring", name = o.name, bbox = { o.x - reach, o.x + reach, o.z - reach, o.z + reach },
		add = function(x, z)
			local d = math.sqrt((x - o.x) ^ 2 + (z - o.z) ^ 2)
			if d >= reach then return nil end
			return h * cosb(math.abs(d - R) / w) - dish * cosb(d / math.max(R - w * 0.5, 1))
		end,
		paint = function(x, z, dh)
			local d = math.sqrt((x - o.x) ^ 2 + (z - o.z) ^ 2)
			if d >= reach then return nil end
			if math.abs(d - R) < w * 0.35 then return o.rim end
			if d < R - w * 0.5 then return o.dishMat end
		end,
		hit = function(x, z) return (x - o.x) ^ 2 + (z - o.z) ^ 2 < reach * reach end,
	}
end

-- flatten a disc to y (or the smoothed ground at its centre) with a cosine blend; used under 3D pieces
function K.pad(o)
	local tanMax = math.tan(math.rad(o.maxDeg or 20))
	local reach = o.r + math.max(o.blend, (o.maxDrop or 40) * math.pi / (2 * tanMax))
	return {
		kind = "pad", name = o.name, bbox = { o.x - reach, o.x + reach, o.z - reach, o.z + reach },
		over = function(x, z, hCur, G)
			local d = math.sqrt((x - o.x) ^ 2 + (z - o.z) ^ 2)
			if d >= reach then return nil end
			local y = o.y or G.baseAt(o.x, o.z)
			local bl = math.max(o.blend, math.abs(hCur - y) * math.pi / (2 * tanMax))
			if d >= o.r + bl then return nil end
			return y, cosb((d - o.r) / bl)
		end,
		hit = function(x, z) return (x - o.x) ^ 2 + (z - o.z) ^ 2 < reach * reach end,
	}
end

-- Rolling base: warped two-octave noise over the whole box, fading to nothing near locked ground (taper
-- from DIST), so hills and dips run continuously into the cliffs instead of stopping at a seam.
function K.rolling(o)
	o = o or {}
	local s, warp = o.seed or 1, o.warp or 60
	local a1, l1, a2, l2 = o.amp1 or 24, o.len1 or 600, o.amp2 or 8, o.len2 or 240
	return {
		kind = "rolling", name = o.name or "rolling",
		roll = function(x, z, i, G)
			local wx = x + warp * math.noise(x / 170, z / 170, s + 11)
			local wz = z + warp * math.noise(x / 170, z / 170, s + 23)
			local v = a1 * 2 * math.noise(wx / l1, wz / l1, s) + a2 * 2 * math.noise(wx / l2, wz / l2, s + 5)
			if (o.amp3 or 7) > 0 then v += (o.amp3 or 7) * 2 * math.noise(wx / (o.len3 or 110), wz / (o.len3 or 110), s + 9) end
			local d = G.DIST and G.DIST[i] or 1e9
			return v * smooth01((d - (o.taperFrom or 16)) / (o.taper or 80))
		end,
	}
end

function K.hillField(o)
	local rng = Random.new(o.seed or 77)
	local g, j = o.grid or 150, o.jitter or 80
	local hh = o.h or { 28, 44 }
	local hA, hB, rA, rB, sA, sB = hh[1], hh[2], (o.rh or { 5.2, 6 })[1], (o.rh or { 5.2, 6 })[2], (o.sq or { 0.8, 1 })[1], (o.sq or { 0.8, 1 })[2]
	local HF = {}
	for gu = o.rect[1], o.rect[2], g do
		for gv = o.rect[3], o.rect[4], g do
			local u, v = gu + rng:NextNumber(-j, j), gv + rng:NextNumber(-j, j)
			local h = rng:NextNumber(hA, hB)
			local r = h * rng:NextNumber(rA, rB)
			local rot, sq = rng:NextNumber(0, 180), rng:NextNumber(sA, sB)
			local ok = not (o.skip and o.skip(u, v, r))
			for _, q in ipairs(HF) do
				if ok and (u - q[1]) ^ 2 + (v - q[2]) ^ 2 < ((o.spacing or 0.65) * (r + q[4])) ^ 2 then ok = false end
			end
			if ok then HF[#HF + 1] = { u, v, h, r, r * sq, rot } end
		end
	end
	local HB, bucket = 256, {}
	for _, q in ipairs(HF) do
		local R = math.max(q[4], q[5])
		for bx = math.floor((q[1] - R) / HB), math.floor((q[1] + R) / HB) do
			for bz = math.floor((q[2] - R) / HB), math.floor((q[2] + R) / HB) do
				local key = bx * 100003 + bz
				bucket[key] = bucket[key] or {}
				table.insert(bucket[key], { q[1], q[2], q[3], q[4], q[5], math.cos(math.rad(q[6])), math.sin(math.rad(q[6])) })
			end
		end
	end
	return {
		kind = "rolling", name = o.name or "hill field", hills = HF,
		roll = function(x, z, i, G)
			local lst = bucket[math.floor(x / HB) * 100003 + math.floor(z / HB)]
			if not lst then return 0 end
			local sum = 0
			for _, q in ipairs(lst) do
				local du, dv = x - q[1], z - q[2]
				local d = math.sqrt(((du * q[6] + dv * q[7]) / q[4]) ^ 2 + ((dv * q[6] - du * q[7]) / q[5]) ^ 2)
				if d < 1 then
					local v = q[3] * cosb(d)
					if o.union ~= "sum" then sum = sum > 0 and smax(sum, v, o.k or 10) or v else sum += v end
				end
			end
			return sum * smooth01(((G.DIST and G.DIST[i] or 1e9) - (o.taperFrom or 60)) / (o.taper or 220))
		end,
	}
end

function K.clearOf(list, frac)
	frac = frac or 0.4
	return function(x, z, r)
		local rr = r * frac
		for _, f in ipairs(list) do
			if f.hit then
				if f.hit(x, z) then return true end
				for k = 0, 7 do
					local a = k * math.pi / 4
					if f.hit(x + math.cos(a) * rr, z + math.sin(a) * rr) then return true end
				end
			end
		end
		return false
	end
end

function K.stone(x, z)
	if typeof(x) == "Vector3" then x, z = x.X, x.Z end
	return math.noise(x / 24, z / 24, 8.1) > 0.15 and MAT.Rock or MAT.Basalt
end

function K.cliff(o)
	local ref = K.path({ name = (o.name or "cliff") .. " ref", mode = "trough", pts = o.pts, halfW = 1, bank = o.reach or 420, depth = 0 })
	local side = ref.near(o.outside[1], o.outside[2])
	assert(side, "cliff outside point off the cliff line")
	side = side >= 0 and 1 or -1
	local h, w, rel, seed, ends = o.h, o.w or 60, o.rel or 0, o.seed or 1, o.ends or 250
	local total = ref.total
	local function wig(s) return (o.wig or 24) * math.noise(s / 260, seed, 0.5) + (o.wig2 or 10) * math.noise(s / 90, seed, 2.5) end
	local reach = o.reach or 420
	local function at(x, z)
		local n, s = ref.near(x, z)
		if not n then return nil end
		local env = o.base and 1 or smooth01(math.min(s, total - s) / ends)
		local t = (side * n - wig(s)) / w + 0.5
		if t <= 0 then return (o.base and 0 or nil), t, env, n end
		local top = rel * math.max(0, 0.5 + math.noise(x / 320, z / 320, seed + 7)) * smooth01((t - 1) * w / 60)
		if o.base then top *= smooth01((reach - math.abs(n)) / 80) end
		return env * (h * smooth01(t) + top), t, env, n
	end
	local bb = ref.bbox
	return {
		kind = "cliff", name = o.name or "cliff", bbox = bb, near = ref.near, hAt = function(x, z) return at(x, z) or 0 end,
		add = not o.base and function(x, z) return (at(x, z)) end or nil,
		over = o.base and function(x, z, hCur, G)
			local y, t, env, n = at(x, z)
			if not y or math.abs(n) > reach - 4 then return nil end
			return hCur - G.baseAt(x, z) + o.base + y, smooth01((reach - math.abs(n)) / 60)
		end or nil,
		steep = function(x, z)
			local y, t, env = at(x, z)
			return y ~= nil and env > 0.2 and t > -0.2 and t < 1.3
		end,
		hit = function(x, z) local n = ref.near(x, z) return n ~= nil and side * n > -w end,
	}
end

-- Bowl: a real depression, rim flush with the ground (optional low lip), rolling damped inside so the
-- floor is clean. Enter from any side. Wall slope = depth * pi / (2r).
function K.bowl(o)
	local r, depth, lip = o.r, o.depth, o.lip or 0
	local wallDeg = math.deg(math.atan(depth * math.pi / (2 * r)))
	if wallDeg > 13.8 then log(string.format("WARN bowl %s planned wall %.1f deg (depth %.1f, r/6.5 = %.1f) builds 1-2 deg steeper, over the user's 15 (round 6)", o.name or "?", wallDeg, depth, r / 6.5)) end
	local lipAt, lipW = r * 1.1, r * 0.3
	local reach = r * 1.45
	local function dist(x, z) return math.sqrt((x - o.x) ^ 2 + (z - o.z) ^ 2) end
	return {
		kind = "bowl", name = o.name, bbox = { o.x - reach, o.x + reach, o.z - reach, o.z + reach },
		add = function(x, z)
			local d = dist(x, z)
			if d >= reach then return nil end
			local v = (d < r) and -depth * cosb(d / r) or 0
			if lip > 0 then v += lip * cosb(math.abs(d - lipAt) / lipW) end
			return v
		end,
		damp = function(x, z)
			local d = dist(x, z)
			if d >= reach then return nil end
			return 1 - cosb(d / reach)
		end,
		ride = function(x, z) return dist(x, z) < r * 0.95 end,
		paint = function(x, z, dh)
			local d = dist(x, z)
			if d < r * 0.5 then return o.floorMat end
			if lip > 0 and math.abs(d - lipAt) < r * 0.1 then return o.rimMat end
		end,
		tag = function(x, z) if dist(x, z) < r * 0.35 then return "bowl" end end,
		hit = function(x, z) return dist(x, z) < (lip > 0 and lipAt + lipW or r) end,
	}
end

-- Table-top drop: flat top, sharp lip, ease-out face (steepest at the lip = where the ball leaves the
-- ground at speed, flattening into the landing). Face slope at the lip = 2h / w.
function K.table(o)
	assert(o.allowBanned, "K.table is banned (user round 5: table-tops useless); pass allowBanned = true only on an explicit user ask")
	local r, h, w = o.r, o.h, o.w
	if 2 * h / w > math.tan(math.rad(34)) then log("WARN table " .. (o.name or "?") .. " lip > 34 deg") end
	local reach = r + w
	local function dist(x, z)
		local u, v = rot(x, z, o.x, o.z, o.rot)
		return math.sqrt((u / (o.sx or 1)) ^ 2 + (v / (o.sz or 1)) ^ 2)
	end
	return {
		kind = "table", name = o.name, bbox = { o.x - reach * (o.sx or 1) - 4, o.x + reach * (o.sx or 1) + 4, o.z - reach * (o.sz or 1) - 4, o.z + reach * (o.sz or 1) + 4 },
		add = function(x, z)
			local d = dist(x, z)
			if d >= reach then return nil end
			if d <= r then return h end
			local t = (d - r) / w
			return h * (1 - t) ^ 2
		end,
		damp = function(x, z)
			local d = dist(x, z)
			if d >= reach then return nil end
			return smooth01((d - r * 0.6) / (r * 0.6 + w))
		end,
		ride = function(x, z) local d = dist(x, z) return d > r and d < reach end,
		paint = function(x, z)
			local d = dist(x, z)
			if d >= r - 5 and d <= r + 3 then return o.rimMat end
			if d > r and d < r + w * 0.6 then return o.faceMat end
		end,
		hit = function(x, z) return dist(x, z) < reach end,
	}
end

-- Catch-mull spline through pts ({x, z} pairs), sampled every ~4 studs
local function spline(pts, closed)
	local P = {}
	for _, p in ipairs(pts) do P[#P + 1] = Vector2.new(p[1], p[2]) end
	local n = #P
	local function at(k)
		if closed then return P[(k - 1) % n + 1] end
		return P[math.clamp(k, 1, n)]
	end
	local S = {}
	local last = closed and n or n - 1
	for k = 1, last do
		local p0, p1, p2, p3 = at(k - 1), at(k), at(k + 1), at(k + 2)
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude / 4))
		for s = 0, steps - 1 do
			local t = s / steps
			local t2, t3 = t * t, t * t * t
			S[#S + 1] = 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
		end
	end
	if closed then S[#S + 1] = S[1] else S[#S + 1] = P[n] end
	local len = { 0 }
	for k = 2, #S do len[k] = len[k - 1] + (S[k] - S[k - 1]).Magnitude end
	return S, len
end

-- path modes: "lane" (sunk, flat floor profile along s, cosine banks), "ramp" (floor eases from the
-- ground at the first point to the ground at the last), "berm" (additive ridge, optional groove)
function K.path(o)
	local S, L = spline(o.pts, o.closed)
	local halfW, bank = o.halfW, o.bank or 16
	local tan20 = math.tan(math.rad(o.maxDeg or 20))
	if o.mode == "berm" and o.h then
		local w = math.max(halfW, o.h * math.pi / (2 * tan20))
		if w > halfW then log(string.format("berm %s halfW %d -> %d so flanks stay <= %d deg", o.name or "?", halfW, math.ceil(w), o.maxDeg or 20)) end
		halfW = w
	elseif o.mode == "trough" and o.depth then
		local w = math.max(halfW, o.depth * math.pi / (2 * math.tan(math.rad(o.bankDeg or 22))))
		if w > halfW then log(string.format("trough %s halfW %d -> %d so sides stay <= %d deg", o.name or "?", halfW, math.ceil(w), o.bankDeg or 22)) end
		halfW = w
	end
	local laneLike = o.mode == "lane" or o.mode == "ramp" or o.mode == nil
	local bankCap = laneLike and math.max(bank, o.bankMax or 320) or bank
	local reach = halfW + bankCap + 4
	local B = 32
	local buckets = {}
	local xa, xb, za, zb = math.huge, -math.huge, math.huge, -math.huge
	for k = 1, #S - 1 do
		local a, b = S[k], S[k + 1]
		local sxa, sxb = math.min(a.X, b.X) - reach, math.max(a.X, b.X) + reach
		local sza, szb = math.min(a.Y, b.Y) - reach, math.max(a.Y, b.Y) + reach
		xa, xb, za, zb = math.min(xa, sxa), math.max(xb, sxb), math.min(za, sza), math.max(zb, szb)
		for bx = math.floor(sxa / B), math.floor(sxb / B) do
			for bz = math.floor(sza / B), math.floor(szb / B) do
				local key = bx * 100003 + bz
				local lst = buckets[key]
				if not lst then lst = {}; buckets[key] = lst end
				lst[#lst + 1] = k
			end
		end
	end
	local memo, memoN = {}, 0
	local function nearestRaw(x, z)
		local lst = buckets[math.floor(x / B) * 100003 + math.floor(z / B)]
		if not lst then return nil end
		local p = Vector2.new(x, z)
		local best, bs, bn = math.huge, 0, 0
		for _, k in ipairs(lst) do
			local a, b = S[k], S[k + 1]
			local ab = b - a
			local l2 = ab:Dot(ab)
			local t = l2 > 0 and math.clamp((p - a):Dot(ab) / l2, 0, 1) or 0
			local q = a + ab * t
			local d = (p - q).Magnitude
			if d < best then
				best = d
				bs = L[k] + (L[k + 1] - L[k]) * t
				bn = (ab.X * (p.Y - q.Y) - ab.Y * (p.X - q.X)) >= 0 and d or -d
			end
		end
		if best > reach then return nil end
		return bn, bs
	end
	local memoS = {}
	local function nearest(x, z)
		local key = x * 65536 + z
		local n = memo[key]
		if n ~= nil then
			if n == false then return nil end
			return n, memoS[key]
		end
		local a, b = nearestRaw(x, z)
		if memoN < 300000 then
			memoN += 1
			memo[key] = a or false
			memoS[key] = b
		end
		return a, b
	end
	local total = L[#L]
	local floorAt
	local f = {
		kind = o.mode, name = o.name, bbox = { xa, xb, za, zb }, total = total, near = nearest,
		hit = function(x, z)
			local n = nearest(x, z)
			return n ~= nil and math.abs(n) < halfW + bank * 0.5
		end,
		tag = function(x, z)
			local n = nearest(x, z)
			if n and math.abs(n) <= halfW - (o.lineInset or 12) then return o.tag or o.mode end
		end,
	}
	if o.mode == "dive" then
		-- Sunken route with an explicit floor: o.base minus a dish (o.depth), dipping to dip.depth at each
		-- o.dips point (flat for dip.flat, eased over depth*pi/(2*tan(o.grade))). Bank width grows with the
		-- local drop so banks stay <= o.bankDeg (capped at o.bank). o.covers = {{x, z, len}}: route stretches
		-- left uncarved (ground kept for K.slot on the same pts to bore through); the carve returns over
		-- o.coverFade along the route; the kept stretch widens by o.coverSpread per stud off the floor edge,
		-- so the portal is a V-notch around the opening and the ground beside the route keeps its own slope.
		local grade, bankTan = math.tan(math.rad(o.grade or 14)), math.tan(math.rad(o.bankDeg or 22))
		local notchTan = math.tan(math.rad(o.notchDeg or o.bankDeg or 22))
		local dips = {}
		for _, d in ipairs(o.dips or {}) do
			local _, s = nearest(d[1], d[2])
			assert(s, "dip off path " .. d[1] .. "," .. d[2])
			dips[#dips + 1] = { s = s, flat = d.flat or 120, D = d.depth, ramp = d.depth * math.pi / (2 * (d.grade and math.tan(math.rad(d.grade)) or grade)) }
		end
		local covers = {}
		for _, c in ipairs(o.covers or {}) do
			if c.fFrom then
				covers[#covers + 1] = { s = (c.fFrom + c.fTo) / 2 * total, half = (c.fTo - c.fFrom) / 2 * total }
			else
				local _, s = nearest(c[1], c[2])
				assert(s, "cover off path " .. c[1] .. "," .. c[2])
				covers[#covers + 1] = { s = s, half = c.len / 2 }
			end
		end
		floorAt = function(s)
			if o.floor then return o.floor(s, total) end
			local v = o.depth or 3
			for _, d in ipairs(dips) do v = math.max(v, d.D * cosb((math.abs(s - d.s) - d.flat / 2) / d.ramp)) end
			if o.endEase then v *= smooth01(math.min(s, total - s) / o.endEase) end
			return o.base - v
		end
		f.floorAt = function(x, z) local _, s = nearest(x, z) return s and floorAt(s) end
		f.damp = function(x, z)
			local n = nearest(x, z)
			return n and smooth01((math.abs(n) - halfW) / (bank * 0.6)) or nil
		end
		f.over = function(x, z, hCur)
			local n, s = nearest(x, z)
			if not n then return nil end
			local fy = floorAt(s)
			local bk = math.clamp((hCur - fy) * math.pi / (2 * bankTan), o.minBank or 40, bank)
			local w = cosb((math.abs(n) - halfW) / bk)
			local spread = math.max(0, math.abs(n) - halfW) * (o.coverSpread or 1)
			-- notch sides fade like banks: the taller the kept ground, the longer the fade (<= bankDeg)
			local fade = math.max(o.coverFade or 30, (hCur - fy) * math.pi / (2 * notchTan))
			for _, c in ipairs(covers) do w *= smooth01((math.abs(s - c.s) - c.half - spread) / fade) end
			if w <= 0 then return nil end
			return fy, w
		end
		f.paint = function(x, z)
			local n = nearest(x, z)
			if n and math.abs(n) <= halfW + 2 then return o.floorMat end
		end
		if #covers > 0 and o.portalKeep then
			f.steep = function(x, z)
				local n, s = nearest(x, z)
				if not n then return false end
				if math.abs(n) > halfW + (o.portalMargin or 8) then return false end
				for _, c in ipairs(covers) do
					if math.abs(math.abs(s - c.s) - c.half) < (o.notchReach or 40) then return true end
				end
				return false
			end
		end
	elseif o.mode == "wall" then
		-- Wall-ride bank as a heightfield: from o.inner off the centreline a quarter-pipe of radius o.R curls
		-- to o.ang, runs straight to o.h, rolls over a rounded crest (smooth min, o.crestR), then falls away
		-- at <= o.backDeg. Eases in/out over o.taper along the path; smooth-max union with the ground so the
		-- toes leave no crease. o.baseAt(x, z) = floor under the centreline; list it after the route feature.
		local R, ang, H = o.R or 50, math.rad(o.ang or 72), o.h or 55
		local m1, h1, tA = R * math.sin(ang), R * (1 - math.cos(ang)), math.tan(ang)
		local m2 = m1 + math.max(0, H - h1) / tA
		local m3 = m2 + (o.top or 20)
		local Lb = H * math.pi / (2 * math.tan(math.rad(o.backDeg or 20)))
		assert(bank >= o.inner + m3 + Lb, "wall bank must be >= " .. math.ceil(o.inner + m3 + Lb))
		local function sminp(a, b, k) local h = math.max(k - math.abs(a - b), 0) / k return math.min(a, b) - h * h * k / 4 end
		local kc = o.crestR or 16
		local function hp(m)
			if m <= 0 then return 0 end
			local face = m <= m1 and R - math.sqrt(math.max(0, R * R - m * m)) or h1 + (m - m1) * tA
			local back = m <= m3 and H or H * cosb((m - m3) / Lb)
			return sminp(face, back, kc)
		end
		local side = nearest(o.outside[1], o.outside[2])
		assert(side, "outside point off wall path")
		side = side >= 0 and 1 or -1
		local base = {}
		for k = 1, #S do base[k] = o.baseAt and o.baseAt(S[k].X, S[k].Y) or o.base end
		local function baseAt(s)
			local lo, hi = 1, #L
			while hi - lo > 1 do
				local mid = (lo + hi) // 2
				if L[mid] <= s then lo = mid else hi = mid end
			end
			local t = (L[hi] - L[lo]) > 0 and (s - L[lo]) / (L[hi] - L[lo]) or 0
			return base[lo] + (base[hi] - base[lo]) * t
		end
		f.over = function(x, z, hCur)
			local n, s = nearest(x, z)
			if not n then return nil end
			local m = side * n - o.inner
			local e = math.min(1 - cosb(s / (o.taper or 100)), 1 - cosb((total - s) / (o.taper or 100)))
			local h = e * hp(m)
			if h <= 0.01 then return nil end
			-- soft max(0, wall - ground) that reaches exactly 0 as h -> 0: no step or kink where the wall runs out
			-- face rises from the floor; the back settles onto the local ground where that is lower, else the
			-- tail floats above a dip and ends in a step
			local b = baseAt(s)
			if hCur < b then b += (hCur - b) * smooth01((m - m2) / (m3 + Lb - m2)) end
			local dh, k = b + h - hCur, o.blendK or 16
			return hCur + (dh + math.sqrt(dh * dh + k * k)) / 2 * smooth01(h / 8), 1
		end
		f.paint = function(x, z)
			local n = nearest(x, z)
			if n and side * n - o.inner > 0 and side * n - o.inner <= m2 then return o.face end
		end
		f.steep = function(x, z)
			local n = nearest(x, z)
			return n ~= nil and side * n - o.inner > -8 and side * n - o.inner <= m3 + kc
		end
	elseif o.mode == "trough" then
		-- U-valley that rides the terrain up and down; bends bank (outer side higher) from the path's
		-- curvature so the ball carves the turn instead of climbing out
		local depth, bankK, bankMax = o.depth, o.bankK or 60, o.bankMax or 0.6
		local KAP = {}
		for k = 1, #S do
			local a, b, c = S[math.max(1, k - 3)], S[k], S[math.min(#S, k + 3)]
			local t1, t2 = b - a, c - b
			local ang = 0
			if t1.Magnitude > 0 and t2.Magnitude > 0 then ang = math.atan2(t1.X * t2.Y - t1.Y * t2.X, t1.X * t2.X + t1.Y * t2.Y) end
			local ds = L[math.min(#S, k + 3)] - L[math.max(1, k - 3)]
			KAP[k] = ds > 0 and ang / (ds * 0.5) or 0
		end
		local KS = {}
		for k = 1, #S do
			local sum, c = 0, 0
			for j = k - 10, k + 10 do sum += KAP[math.clamp(j, 1, #S)]; c += 1 end
			KS[k] = sum / c
		end
		local function kapAt(sv)
			local lo, hi = 1, #L
			while hi - lo > 1 do
				local mid = (lo + hi) // 2
				if L[mid] <= sv then lo = mid else hi = mid end
			end
			return KS[lo]
		end
		if depth * math.pi / (2 * halfW) > math.tan(math.rad(31)) then log("WARN trough " .. (o.name or "?") .. " sides > 30 deg") end
		f.add = function(x, z)
			local n, sv = nearest(x, z)
			if not n then return nil end
			local an = math.abs(n)
			if an >= halfW then return nil end
			local tilt = math.clamp(-kapAt(sv) * bankK, -1, 1)
			local c = cosb(an / halfW)
			return -depth * c + tilt * bankMax * depth * (n / halfW) * c
		end
		f.ride = function(x, z)
			local n = nearest(x, z)
			return n ~= nil and math.abs(n) < halfW * 0.85
		end
		f.tag = function(x, z)
			local n = nearest(x, z)
			if n and math.abs(n) <= halfW * 0.25 then return o.tag or "trough" end
		end
		f.paint = function(x, z)
			local n = nearest(x, z)
			if not n then return nil end
			local an = math.abs(n)
			if an < halfW * 0.35 then return o.floorMat end
			if o.lipMat and an > halfW * 0.82 and an < halfW then return o.lipMat end
		end
	elseif o.mode == "berm" then
		local h, g = o.h, o.groove
		-- max over every nearby segment, not just the nearest: where two arms meet the profiles blend
		-- continuously instead of stepping at the Voronoi seam
		f.add = function(x, z)
			local lst = buckets[math.floor(x / B) * 100003 + math.floor(z / B)]
			if not lst then return nil end
			local p = Vector2.new(x, z)
			local ridge, groove, any = 0, 0, false
			for _, k in ipairs(lst) do
				local a, b = S[k], S[k + 1]
				local ab = b - a
				local l2 = ab:Dot(ab)
				local t = l2 > 0 and math.clamp((p - a):Dot(ab) / l2, 0, 1) or 0
				local q = a + ab * t
				local d = (p - q).Magnitude
				if d <= reach then
					any = true
					local n = (ab.X * (p.Y - q.Y) - ab.Y * (p.X - q.X)) >= 0 and d or -d
					ridge = math.max(ridge, h * cosb(d / halfW))
					if g then groove = math.max(groove, g.depth * cosb(math.abs(n - g.off) / g.halfW)) end
				end
			end
			if not any then return nil end
			return ridge - groove
		end
		f.paint = function(x, z, dh)
			local n = nearest(x, z)
			if not n then return nil end
			if g and math.abs(n - g.off) < g.halfW * 0.6 then return o.grooveMat end
			if dh and dh > h * 0.7 then return o.crest end
			if math.abs(n) < halfW then return o.flank end
		end
	else
		-- floor profile sampled once from the smoothed base, then averaged along s
		local cs = {}
		f.prepare = function(G)
			local raw = {}
			for k = 1, #S do raw[k] = G.baseAt(S[k].X, S[k].Y) end
			-- camber: the floor tilts with the hillside (clamped), so a trail benched across a slope
			-- never leaves a tall cut bank on its uphill side
			local maxT = o.camber and math.tan(math.rad(o.camber)) or 0
			for k = 1, #S do
				local a, b = S[math.max(1, k - 1)], S[math.min(#S, k + 1)]
				local t = (b - a).Magnitude > 0 and (b - a).Unit or Vector2.new(1, 0)
				local nrm = Vector2.new(-t.Y, t.X)
				local pp, pn = S[k] + nrm * halfW, S[k] - nrm * halfW
				cs[k] = maxT > 0 and math.clamp((G.baseAt(pp.X, pp.Y) - G.baseAt(pn.X, pn.Y)) / (2 * halfW), -maxT, maxT) or 0
			end
			local prof, win, n = {}, o.window or 15, #S
			for k = 1, n do
				if o.mode == "ramp" then
					local e = smooth01(L[k] / total)
					prof[k] = (o.y0 or raw[1]) * (1 - e) + (o.y1 or raw[n]) * e
				else
					local sum, c, csum = 0, 0, 0
					for j = k - win, k + win do
						local jj = o.closed and ((j - 1) % (n - 1) + 1) or math.clamp(j, 1, n)
						sum += raw[jj]; csum += cs[jj]; c += 1
					end
					prof[k] = sum / c - (o.depth or 0)
					cs[k] = csum / c
				end
			end
			floorAt = function(s)
				local lo, hi = 1, #L
				while hi - lo > 1 do
					local mid = (lo + hi) // 2
					if L[mid] <= s then lo = mid else hi = mid end
				end
				local t = (L[hi] - L[lo]) > 0 and (s - L[lo]) / (L[hi] - L[lo]) or 0
				return prof[lo] + (prof[hi] - prof[lo]) * t, cs[lo] + (cs[hi] - cs[lo]) * t
			end
		end
		f.floorAt = function(x, z)
			local _, s = nearest(x, z)
			if s and floorAt then return (floorAt(s)) end
		end
		if o.calm then
			local ci, co = o.calm[1], o.calm[2]
			f.damp = function(x, z)
				local n = nearest(x, z)
				if not n then return nil end
				return smooth01((math.abs(n) - ci) / (co - ci))
			end
		end
		f.over = function(x, z, hCur)
			local n, s = nearest(x, z)
			if not n then return nil end
			local an = math.abs(n)
			if an >= halfW + bankCap then return nil end
			local fy, c = floorAt(s)
			local y = fy + c * math.clamp(n, -halfW, halfW)
			local bk = math.clamp(math.abs(hCur - y) * math.pi / (2 * math.tan(math.rad(o.bankDeg or 22))), bank, bankCap)
			if an >= halfW + bk then return nil end
			return y, cosb((an - halfW) / bk)
		end
		f.paint = function(x, z)
			local n = nearest(x, z)
			if not n then return nil end
			local an = math.abs(n)
			if an <= halfW + 2 then return o.floorMat end
			if o.lipMat and an >= halfW + bank - 6 and an < halfW + bank then return o.lipMat end
			if an < halfW + bank then return o.bankMat end
		end
	end
	return f
end

-- ============================================================ compose + paint + write
local LEAFY, GRASS, LIME, ROCK, MUD, GROUND = MAT.LeafyGrass, MAT.Grass, MAT.Limestone, MAT.Rock, MAT.Mud, MAT.Ground
K.DIRT = "dirt"

local function resolveMat(m, x, z)
	if m == K.DIRT then return math.noise(x / 9, z / 9, 3.1) > 0.18 and GROUND or MUD end
	return m
end


-- Trees go where the user puts them (measured on Analyse_1-6): flat ground (slope p50 0-3, p90 <= 10),
-- never inside ride shapes (A3's swirl has none), >= ~40 apart, clear of fixed props. A tree whose spot
-- became a bowl, trough or drop face moves to the nearest spot that obeys that; every tree gets a small
-- level spot (r 10 + 14 blend) at the local ground height. Heights are applied after the slope limiter.
function K.placeTrees(G, Hf, RIDE)
	local S = K.slope(G, Hf)
	local W, NZ = G.W, G.NZ
	local placed = {}
	local function far(x, z, minD)
		for _, p in ipairs(placed) do if (p[1] - x) ^ 2 + (p[2] - z) ^ 2 < minD * minD then return false end end
		for _, pd in ipairs(G.pads or {}) do if (pd.x - x) ^ 2 + (pd.z - z) ^ 2 < (pd.r + 16) ^ 2 then return false end end
		return true
	end
	local function good(i, lim) return (W[i] or 0) > 0.9 and not RIDE[i] and (S[i] or 99) <= lim end
	local move = {}
	for _, t in ipairs(G.trees) do
		t.ni, t.nx, t.nz = t.i, t.x, t.z
		if (W[t.i] or 0) < 0.05 or good(t.i, 10) then placed[#placed + 1] = { t.x, t.z } else move[#move + 1] = t end
	end
	for _, t in ipairs(move) do
		local R = 40
		local gx0, gz0 = (t.i - 1) // NZ + 1, (t.i - 1) % NZ + 1
		local best, bd = nil, math.huge
		for dx = -R, R, 2 do
			for dz = -R, R, 2 do
				local d2 = dx * dx + dz * dz
				if d2 < bd and d2 <= R * R and inGrid(G, gx0 + dx, gz0 + dz) then
					local i = ix(G, gx0 + dx, gz0 + dz)
					if good(i, 6) then
						local x, z = K.cellXZ(G, gx0 + dx, gz0 + dz)
						if far(x, z, 40) then best, bd = i, d2 end
					end
				end
			end
		end
		if best then
			t.ni = best
			t.nx, t.nz = K.cellXZ(G, (best - 1) // NZ + 1, (best - 1) % NZ + 1)
			t.relocated = true
		else
			t.stuck = true
		end
		placed[#placed + 1] = { t.nx, t.nz }
	end
	for _, t in ipairs(G.trees) do
		if (W[t.ni] or 0) > 0.05 then
			local sum, n = 0, 0
			local ax, az = K.cellOf(G, t.nx - 24, t.nz - 24)
			local bx, bz = K.cellOf(G, t.nx + 24, t.nz + 24)
			for gx = math.max(1, ax), math.min(G.NX, bx) do
				for gz = math.max(1, az), math.min(NZ, bz) do
					local i = ix(G, gx, gz)
					local x, z = K.cellXZ(G, gx, gz)
					if Hf[i] and (x - t.nx) ^ 2 + (z - t.nz) ^ 2 < 64 then sum += Hf[i]; n += 1 end
				end
			end
			local y = n > 0 and sum / n or Hf[t.ni]
			for gx = math.max(1, ax), math.min(G.NX, bx) do
				for gz = math.max(1, az), math.min(NZ, bz) do
					local i = ix(G, gx, gz)
					local x, z = K.cellXZ(G, gx, gz)
					if Hf[i] then
						local w = cosb((math.sqrt((x - t.nx) ^ 2 + (z - t.nz) ^ 2) - 10) / 14) * math.min(1, (W[i] or 0) * 2)
						Hf[i] += w * (y - Hf[i])
					end
				end
			end
		end
	end
end

-- opt: smoothR (3), smoothPasses (2), noSmooth, regrade {deg, iters}, keepPaint, keepPaintDh (2),
-- leafyBlob (0.42), crestLime (2.5; false = off), maxSlope (34; false = off), trees (true)
function K.compose(G, features, opt)
	opt = opt or {}
	local tp, laps = os.clock(), {}
	local function lap(n) laps[#laps + 1] = string.format("%s %.2f", n, os.clock() - tp) tp = os.clock() end
	local H0, W, NZ = G.H, G.W, G.NZ
	local valid = {}
	for i, w in pairs(W) do if w > 0 then valid[i] = true end end
	local Hb = opt.noSmooth and H0 or K.blur(G, H0, opt.smoothR or 3, opt.smoothPasses or 2, valid)
	if opt.regrade then Hb = K.regrade(G, Hb, opt.regrade.deg or 24, opt.regrade.iters or 60) end
	G.Hb = Hb
	G.baseAt = function(x, z)
		local gx, gz = K.cellOf(G, x, z)
		gx, gz = math.clamp(gx, 1, G.NX), math.clamp(gz, 1, G.NZ)
		return Hb[ix(G, gx, gz)] or H0[ix(G, gx, gz)] or 0
	end
	local function cells(bb, fn)
		bb = bb or { G.x0, G.x1, G.z0, G.z1 }
		local ax, az = K.cellOf(G, bb[1], bb[3])
		local bx, bz = K.cellOf(G, bb[2], bb[4])
		for gx = math.max(1, ax), math.min(G.NX, bx) do
			for gz = math.max(1, az), math.min(G.NZ, bz) do
				local i = ix(G, gx, gz)
				if Hb[i] then
					local x, z = K.cellXZ(G, gx, gz)
					fn(i, x, z)
					if G.yieldEvery then
						G.yieldN = (G.yieldN or 0) + 1
						if G.yieldN % G.yieldEvery == 0 then task.wait() end
					end
				end
			end
		end
	end
	lap("base")
	local ROLL, POS, NEG, DAMP, P, TAG, RIDE, TOPP, TOPN = {}, {}, {}, {}, {}, {}, {}, {}, {}
	for _, f in ipairs(features) do if f.prepare then f.prepare(G) end end
	for _, f in ipairs(features) do
		if f.hit and f.bbox and (f.add or f.over) and f.kind ~= "cliff" then
			local n, low = 0, 0
			cells(f.bbox, function(i, x, z)
				local gx, gz = (i - 1) // NZ + 1, (i - 1) % NZ + 1
				if gx % 4 == 0 and gz % 4 == 0 and f.hit(x, z) then n += 1; if (W[i] or 0) < 0.98 then low += 1 end end
			end)
			if n > 0 and low / n > 0.02 then log(string.format("WARN %s: %.0f%% of its footprint is in the mask feather/buffer (W < 0.98), it will be squashed and steepened; move it inward or widen the box", f.name or f.kind or "?", low / n * 100)) end
		end
	end
	for _, f in ipairs(features) do
		-- product, not min: min() of two smooth damps kinks where they cross and the rolling shows it as a crease
		if f.damp then cells(f.bbox, function(i, x, z) local d = f.damp(x, z) if d then DAMP[i] = (DAMP[i] or 1) * d end end) end
	end
	lap("prepare+damp")
	for _, f in ipairs(features) do
		if f.roll then cells(nil, function(i, x, z) ROLL[i] = (ROLL[i] or 0) + f.roll(x, z, i, G) * (DAMP[i] or 1) end) end
	end
	lap("roll")
	for _, f in ipairs(features) do
		if f.add then
			cells(f.bbox, function(i, x, z)
				local dh = f.add(x, z)
				if dh then
					if f.ride and f.ride(x, z, dh) then RIDE[i] = true end
					local m = f.paint and f.paint(x, z, dh)
					if dh >= 0 then
						POS[i] = POS[i] and smax(POS[i], dh, opt.unionK or 12) or dh
						if m and (not TOPP[i] or dh > TOPP[i]) then TOPP[i] = dh; P[i] = m end
					else
						NEG[i] = NEG[i] and smin(NEG[i], dh, opt.unionK or 12) or dh
						if m and (not TOPN[i] or dh < TOPN[i]) then TOPN[i] = dh; P[i] = m end
					end
				end
			end)
		end
	end
	lap("add")
	local H1, DH = {}, {}
	for i, h in pairs(Hb) do
		local sh = (POS[i] or 0) + (NEG[i] or 0)
		H1[i] = h + (ROLL[i] or 0) + sh
		if POS[i] or NEG[i] then DH[i] = sh end
	end
	for _, f in ipairs(features) do
		if f.over then
			cells(f.bbox, function(i, x, z)
				local y, w = f.over(x, z, H1[i], G)
				if y and f.force then
					local wy = G.WHY and G.WHY[i]
					if wy ~= "x" and wy ~= "^" and wy ~= "~" and wy ~= "0" then W[i] = math.max(W[i], w) end
				end
				if y then
					H1[i] = H1[i] * (1 - w) + y * w
					if w > 0.5 and f.kind ~= "pad" then RIDE[i] = true end
					local m = f.paint and f.paint(x, z)
					if m then P[i] = m end
				end
			end)
		end
		if f.tag then
			cells(f.bbox, function(i, x, z)
				local t = f.tag(x, z)
				if t then TAG[i] = t end
			end)
		end
	end
	lap("over+tag")
	local Hf = {}
	for i, h0 in pairs(H0) do
		local w = W[i] or 0
		Hf[i] = w > 0 and (h0 + w * ((H1[i] or h0) - h0)) or h0
	end
	if G.trees and #G.trees > 0 and opt.trees ~= false then K.placeTrees(G, Hf, RIDE) end
	if type(opt.maxSlope) == "number" then Hf = K.limitSlope(G, Hf, opt.maxSlope, 40) end
	if opt.climb ~= false then
		local keep = {}
		for _, f in ipairs(features) do
			if f.steep then cells(f.bbox, function(i, x, z) if f.steep(x, z) then keep[i] = true end end) end
		end
		local faceDeg = opt.faceDeg == nil and 55 or opt.faceDeg
		if faceDeg then
			local S0, auto, ring = K.slope(G, Hf), 0, {}
			local grow, steps = opt.faceGrow or 35, opt.faceGrowReach and math.floor(opt.faceGrowReach / RES) or math.huge
			for i, sl in pairs(S0) do
				if sl >= faceDeg and not keep[i] then keep[i] = true; auto += 1; ring[#ring + 1] = i end
			end
			local step = 0
			while #ring > 0 and step < steps do
				step += 1
				local nextRing = {}
				for _, i in ipairs(ring) do
					local gx, gz = (i - 1) // NZ + 1, (i - 1) % NZ + 1
					for dx = -1, 1 do
						for dz = -1, 1 do
							local x2, z2 = gx + dx, gz + dz
							if x2 >= 1 and z2 >= 1 and x2 <= G.NX and z2 <= NZ then
								local j = (x2 - 1) * NZ + z2
								if not keep[j] and S0[j] and S0[j] >= grow then keep[j] = true; auto += 1; nextRing[#nextRing + 1] = j end
							end
						end
					end
				end
				ring = nextRing
			end
			if auto > 0 then log(string.format("climb guard: %d cells kept as deliberate faces (>= %d deg plus >= %d deg ground within %d studs: cliff faces and their shoulders); declare f.steep or pass faceDeg = false to guard them", auto, faceDeg, grow, steps * RES)) end
		end
		local band = opt.faceBand == nil and 3 or opt.faceBand
		if band > 0 then
			local grow = {}
			for i in pairs(keep) do
				local gx, gz = (i - 1) // NZ + 1, (i - 1) % NZ + 1
				for dx = -band, band do
					for dz = -band, band do
						local x2, z2 = gx + dx, gz + dz
						if x2 >= 1 and z2 >= 1 and x2 <= G.NX and z2 <= NZ and dx * dx + dz * dz <= band * band then grow[(x2 - 1) * NZ + z2] = true end
					end
				end
			end
			for i in pairs(grow) do keep[i] = true end
		end
		local src = opt.guardSource or 160
		if G.chunkMargin then
			local safe = math.max(0, G.chunkMargin - 128)
			if safe < src then
				log(string.format("WARN climb guard in chunk mode: chunkMargin %d only supports %d studs of guard reach (wanted %d); pass chunkMargin = %d for a full guard, or accept weaker fixes (no seams either way)", G.chunkMargin, safe, src, src + 128))
				src = safe
			end
		end
		Hf = K.climbGuard(G, Hf, opt.climb or 22, opt.guardRounds or 8, keep, { guardSmooth = opt.guardSmooth, guardReach = opt.guardReach, guardFeather = opt.guardFeather, guardCap = opt.guardCap, guardSource = src })
	end
	lap("trees+guard")
	for _, t in ipairs(G.trees or {}) do t.dy = (Hf[t.ni] or H0[t.i]) - H0[t.i] end
	-- rule paint on edited ground: feature paint first, then crest / hollow / slope / blob noise
	local S = K.slope(G, Hf)
	local mean = boxMean(G, Hf, 6)
	local PF = {}
	local blob = opt.leafyBlob or 0.42
	local crest = opt.crestLime == nil and 2.5 or opt.crestLime
	if opt.sun == nil and opt.shade == nil then
		opt.sun, opt.sunDark, opt.sunLit, opt.sunLitMat, opt.sunHi, opt.sunHiMat = Vector3.new(0.755, 0.553, -0.352), opt.sunDark or 0.05, opt.sunLit or 0.05, opt.sunLitMat or MAT.Slate, opt.sunHi or 0.12, opt.sunHiMat or LIME
	end
	local sun = opt.sun and opt.sun.Unit
	local function lit(gx, gz, i)
		local c = mean[i]
		local xa = gx > 1 and mean[i - NZ] or c
		local xb = gx < G.NX and mean[i + NZ] or c
		local za = gz > 1 and mean[i - 1] or c
		local zb = gz < NZ and mean[i + 1] or c
		if not (c and xa and xb and za and zb) then return 0 end
		return Vector3.new(-(xb - xa) / (2 * RES), 1, -(zb - za) / (2 * RES)).Unit:Dot(sun) - sun.Y
	end
	local ruled, rocky = {}, {}
	for gx = 1, G.NX do
		for gz = 1, NZ do
			local i = (gx - 1) * NZ + gz
			if (W[i] or 0) > 0.5 then
				local x, z = K.cellXZ(G, gx, gz)
				local m = P[i]
				if not m and opt.keepPaint and opt.keepPaint[G.M[i]] and math.abs(Hf[i] - H0[i]) < (opt.keepPaintDh or 2) then m = G.M[i] end
				local rock = opt.rock == nil and { deg = 35, mat = K.stone } or opt.rock
				if not m and rock and S[i] >= rock.deg then
					local steepN = 0
					for dx = -1, 1 do
						for dz = -1, 1 do
							local j = i + dx * NZ + dz
							if (dx ~= 0 or dz ~= 0) and S[j] and S[j] >= rock.deg then steepN += 1 end
						end
					end
					if steepN >= 4 then m = rock.mat(x, z); rocky[i] = true end
				end
				if not m then
					local s, rel = S[i], Hf[i] - mean[i]
					local nz = math.noise(x / 36, z / 36, 7.3)
					ruled[i] = true
					if sun then
						local l = lit(gx, gz, i)
						if l < -(opt.sunDark or 0.06) then m = GRASS
						elseif opt.sunHi and l > opt.sunHi then m = opt.sunHiMat or LIME
						elseif l > (opt.sunLit or 0.06) then m = opt.sunLitMat or LEAFY
						else m = opt.sunFlat or LEAFY end
					elseif opt.shade == "lit" then
						if crest and rel >= crest and s < 24 then m = LIME
						elseif s >= 13 or (rel <= -1.2 and nz > -0.4) then m = GRASS
						elseif nz > (opt.darkBlob or 0.5) then m = GRASS
						else m = LEAFY end
					elseif crest and rel >= crest and s < 24 then m = LIME
					elseif rel <= -1.2 and nz > -0.3 then m = LEAFY
					elseif s >= 12 and nz > -0.1 then m = LEAFY
					elseif nz > blob then m = LEAFY
					else m = GRASS end
				end
				if ruled[i] and W[i] < 1 and G.M[i] and opt.edgeFade ~= false and math.noise(x / 40, z / 40, 3.7) * 0.5 + 0.5 > W[i] ^ 0.7 then m = G.M[i] end
				PF[i] = resolveMat(m, x, z)
			end
		end
	end
	if sun then
		local tone = { [GRASS] = true, [LEAFY] = true, [LIME] = true, [MAT.Slate] = true }
		local function matAt(j) return PF[j] or G.M[j] end
		for _ = 1, math.max(opt.despeck or 2, 6) do
			local swap, any = {}, false
			local pool = {}
			for i in pairs(ruled) do pool[i] = true end
			for i in pairs(rocky) do pool[i] = true end
			for i in pairs(pool) do
				local gx, gz = (i - 1) // NZ + 1, (i - 1) % NZ + 1
				if gx > 1 and gz > 1 and gx < G.NX and gz < NZ then
					local cnt, best, bm = {}, 0, nil
					for dx = -1, 1 do
						for dz = -1, 1 do
							local m = (dx ~= 0 or dz ~= 0) and matAt(i + dx * NZ + dz)
							if m then
								cnt[m] = (cnt[m] or 0) + 1
								if cnt[m] > best then best, bm = cnt[m], m end
							end
						end
					end
					local me = PF[i]
					local lone = matAt(i - 1) ~= me and matAt(i + 1) ~= me and matAt(i - NZ) ~= me and matAt(i + NZ) ~= me
					if bm ~= me and ((lone and bm ~= AIR) or (tone[bm] and best >= 5 and not rocky[i])) then swap[i] = bm; any = true end
				end
			end
			for i, m in pairs(swap) do PF[i] = m end
			if not any then break end
		end
	end
	lap("paint")
	log("compose phases (s): " .. table.concat(laps, ", "))
	G.Hf, G.P, G.TAG, G.DH, G.RIDE = Hf, PF, TAG, DH, RIDE
	return Hf, PF
end

-- rewrite only columns whose height or paint changes; untouched columns are written back byte-identical
-- Occupancy comes from the distance to the surface along its normal (vertical offset * cos slope), not the
-- vertical offset alone: a column-only fill turns steep faces into a staircase that Roblox meshes as a
-- lattice of holes and spikes. Skin is measured the same way so no interior shows on steep faces.
function K.write(G, interior, clip)
	local H0, Hf, P, M, NZ, NX = G.H, G.Hf, G.P, G.M, G.NZ, G.NX
	local HL, ML = G.Hlive or H0, G.Mlive or M
	local changed = 0
	local function csAt(i, x, z)
		local hf = Hf[i]
		local hx = ((x < NX and Hf[i + NZ] or hf) - (x > 1 and Hf[i - NZ] or hf)) / (2 * RES)
		local hz = ((z < NZ and Hf[i + 1] or hf) - (z > 1 and Hf[i - 1] or hf)) / (2 * RES)
		return 1 / math.sqrt(1 + hx * hx + hz * hz)
	end
	local function readback(i, x, z)
		local hf, cs = Hf[i], csAt(i, x, z)
		local yb = G.y0 + math.floor((hf - 2 + 1.8 / cs - G.y0) / RES) * RES
		for _ = 1, 4 do
			local o = math.clamp(0.5 + (hf - yb - RES / 2) * cs / RES, 0, 1)
			if o >= 0.06 then return yb + o * RES end
			yb -= RES
		end
		return hf
	end
	local function differs(i, x, z)
		local h0, hf = H0[i], Hf[i]
		if not h0 then return false end
		local hl = HL[i] or h0
		if hf == h0 and not P[i] then return math.abs(hl - h0) > 0.02 or M[i] ~= ML[i] end
		return math.abs(readback(i, x, z) - hl) > 0.02 or (P[i] or M[i]) ~= ML[i]
	end
	for gx = 1, G.NX, 32 do
		for gz = 1, NZ, 32 do
			local bx, bz = math.min(G.NX, gx + 31), math.min(NZ, gz + 31)
			local function col(x, z)
				if not clip then return true end
				local wx, wz = K.cellXZ(G, x, z)
				return wx >= clip[1] and wx < clip[2] and wz >= clip[3] and wz < clip[4]
			end
			local lo, hi = math.huge, -math.huge
			for x = gx, bx do
				for z = gz, bz do
					local i = (x - 1) * NZ + z
					local h0, hf = H0[i], Hf[i]
					local hl = HL[i] or h0
					if h0 and col(x, z) and differs(i, x, z) then
						lo, hi = math.min(lo, h0, hf, hl), math.max(hi, h0, hf, hl)
					end
				end
			end
			if lo < math.huge then
				local ylo = math.floor((lo - 24) / RES) * RES
				local yhi = math.ceil((hi + 24) / RES) * RES
				local r = region(G, gx, bx, gz, bz, ylo, yhi)
				local mats, occs = T:ReadVoxels(r, RES)
				local ny = (yhi - ylo) / RES
				for x = gx, bx do
					local mx, ox = mats[x - gx + 1], occs[x - gx + 1]
					for z = gz, bz do
						local i = (x - 1) * NZ + z
						local h0, hf = H0[i], Hf[i]
						if h0 and col(x, z) and differs(i, x, z) then
							local opCol = G.skip3d and G.skip3d[i]
							if opCol then G.opCols = (G.opCols or 0) + 1 else changed += 1 end
							if G.Hlive and not opCol and changed <= 3 then log(string.format("rewrite sample: plan %.2f readback %.2f live %.2f base %.2f paint %s live %s", Hf[i], readback(i, x, z), HL[i] or -1, h0, tostring(P[i] or M[i]), tostring(ML[i]))) end
							local skin = P[i] or M[i]
							local dz = z - gz + 1
							local hx = ((x < NX and Hf[i + NZ] or hf) - (x > 1 and Hf[i - NZ] or hf)) / (2 * RES)
							local hz = ((z < NZ and Hf[i + 1] or hf) - (z > 1 and Hf[i - 1] or hf)) / (2 * RES)
							local cs = 1 / math.sqrt(1 + hx * hx + hz * hz)
							for iy = 1, ny do
								local yb = ylo + (iy - 1) * RES
								local o = math.clamp(0.5 + (hf - yb - RES / 2) * cs / RES, 0, 1)
								if o < 0.06 then
									mx[iy][dz], ox[iy][dz] = AIR, 0
								else
									local old = mx[iy][dz]
									if (hf - yb) * cs < 8 then
										mx[iy][dz] = skin
									elseif old == AIR or old == WATER then
										mx[iy][dz] = interior or skin
									end
									ox[iy][dz] = o
								end
							end
						end
					end
				end
				T:WriteVoxels(r, RES, mats, occs)
				task.wait()
			end
		end
	end
	return changed
end

-- ============================================================ SDF voxel ops (3D pieces)
K.sd = {}
function K.sd.ellipsoid(p, c, r)
	local q = (p - c) / r
	return (q.Magnitude - 1) * math.min(r.X, r.Y, r.Z)
end
function K.sd.capsule(p, a, b, r)
	local pa, ba = p - a, b - a
	local h = math.clamp(pa:Dot(ba) / ba:Dot(ba), 0, 1)
	return (pa - ba * h).Magnitude - r
end
function K.sd.roundBox(p, c, half, round)
	local q = (p - c)
	q = Vector3.new(math.abs(q.X), math.abs(q.Y), math.abs(q.Z)) - half + Vector3.one * round
	local out = Vector3.new(math.max(q.X, 0), math.max(q.Y, 0), math.max(q.Z, 0)).Magnitude
	return out + math.min(math.max(q.X, q.Y, q.Z), 0) - round
end
function K.sd.smin(a, b, k)
	local h = math.clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return b + (a - b) * h - k * h * (1 - h)
end
-- distance to a sampled curve (list of Vector3) minus radius
function K.sd.tube(p, pts, r)
	local best = math.huge
	for k = 1, #pts - 1 do best = math.min(best, K.sd.capsule(p, pts[k], pts[k + 1], r)) end
	return best
end

-- mode "add": union (fn returns d, material). mode "cut": subtract (fn returns d); opt.floor = {y, mat},
-- opt.wall = mat repaints solid voxels left within 2 voxels of the cut surface.
function K.voxels(bmin, bmax, mode, fn, opt)
	opt = opt or {}
	local r = Region3.new(bmin, bmax):ExpandToGrid(RES)
	local size = r.Size / RES
	if size.X > MAX_AXIS or size.Z > MAX_AXIS or size.X * size.Y * size.Z > MAX_VOX then
		local lo, hi = r.CFrame.Position - r.Size / 2, r.CFrame.Position + r.Size / 2
		if size.X >= size.Z then
			local mid = lo.X + math.floor(size.X / 2) * RES
			return K.voxels(lo, Vector3.new(mid, hi.Y, hi.Z), mode, fn, opt) + K.voxels(Vector3.new(mid, lo.Y, lo.Z), hi, mode, fn, opt)
		end
		local mid = lo.Z + math.floor(size.Z / 2) * RES
		return K.voxels(lo, Vector3.new(hi.X, hi.Y, mid), mode, fn, opt) + K.voxels(Vector3.new(lo.X, lo.Y, mid), hi, mode, fn, opt)
	end
	local mats, occs = T:ReadVoxels(r, RES)
	local base = r.CFrame.Position - r.Size / 2
	local n = 0
	for x = 1, size.X do
		local mx, ox = mats[x], occs[x]
		for z = 1, size.Z do
			for y = 1, size.Y do
				local my, oy = mx[y], ox[y]
				local p = base + Vector3.new((x - 0.5) * RES, (y - 0.5) * RES, (z - 0.5) * RES)
				local d, m = fn(p)
				if mode == "add" then
					local o = math.clamp(0.5 - d / RES, 0, 1)
					if o > oy[z] and (not opt.airOnly or my[z] == AIR or oy[z] <= 0.02) then oy[z] = o; my[z] = m; n += 1 end
				else
					local keep = math.clamp(0.5 + d / RES, 0, 1)
					if keep < oy[z] then
						oy[z] = keep
						n += 1
						if keep <= 0 then my[z] = AIR end
					end
					if oy[z] > 0 and d < (opt.band or RES * 4) and my[z] ~= AIR then
						if m then my[z] = m
						elseif opt.floor and p.Y <= opt.floor.y + 2 then my[z] = opt.floor.mat
						elseif opt.wall then my[z] = opt.wall end
					end
				end
			end
		end
	end
	T:WriteVoxels(r, RES, mats, occs)
	return n
end

-- ============================================================ backup / restore / hashes
local function folder()
	local f = SS:FindFirstChild("TerrainBackups")
	if not f then
		f = Instance.new("Folder")
		f.Name = "TerrainBackups"
		f.Parent = SS
	end
	return f
end

local function voxRegion(G)
	return Region3int16.new(
		Vector3int16.new(G.x0 / RES, G.y0 / RES, G.z0 / RES),
		Vector3int16.new(G.x0 / RES + G.NX - 1, G.y0 / RES + G.NY - 1, G.z0 / RES + G.NZ - 1)
	)
end

function K.hashTiles(G)
	local out = {}
	eachTile(G, G.NY, 32, function(ax, bx, az, bz)
		for tz = az, bz, 32 do
			local cz = math.min(bz, tz + 31)
			local mats, occs = T:ReadVoxels(region(G, ax, bx, tz, cz, G.y0, G.y1), RES)
			local h = 5381
			for x = 1, #mats do
				local mx, ox = mats[x], occs[x]
				for y = 1, #mx do
					local my, oy = mx[y], ox[y]
					for z = 1, #my do
						h = (h * 33 + my[z].Value * 256 + math.floor(oy[z] * 255)) % 4294967291
					end
				end
			end
			out[#out + 1] = ax .. "," .. tz .. "=" .. h
		end
	end)
	return table.concat(out, ";")
end

function K.backup(G, force)
	local f = folder()
	local old = f:FindFirstChild(G.name)
	if old and not force then return "baseline exists (kept): " .. old:GetAttribute("Stamp") end
	if old then old:Destroy() end
	local tr = T:CopyRegion(voxRegion(G))
	tr.Name = G.name
	tr:SetAttribute("Stamp", os.date("!%Y-%m-%d %H:%M"))
	tr:SetAttribute("Corner", Vector3.new(G.x0, G.y0, G.z0))
	local hv = Instance.new("StringValue")
	hv.Name = "Hashes"
	hv.Value = K.hashTiles(G)
	hv.Parent = tr
	K.snapTrees(G, tr)
	tr.Parent = f
	return "baseline saved " .. G.name .. " tiles=" .. select(2, hv.Value:gsub(";", ";")) + 1
end

-- original tree pivots live next to the terrain baseline (ObjectValue + Pivot attribute per tree)
function K.snapTrees(G, tr)
	if tr:FindFirstChild("Trees") then return end
	local f = Instance.new("Folder")
	f.Name = "Trees"
	for _, t in ipairs(K.findTrees(G)) do
		local ov = Instance.new("ObjectValue")
		ov.Name = "T"
		ov.Value = t.inst
		ov:SetAttribute("Pivot", t.inst:GetPivot())
		ov.Parent = f
	end
	f.Parent = tr
end

function K.restore(G)
	local tr = folder():FindFirstChild(G.name)
	assert(tr, "no baseline for " .. G.name .. " (run backup first)")
	T:PasteRegion(tr, Vector3int16.new(G.x0 / RES, G.y0 / RES, G.z0 / RES), true)
	local tf = tr:FindFirstChild("Trees")
	for _, ov in ipairs(tf and tf:GetChildren() or {}) do
		if ov.Value and ov.Value.Parent then ov.Value:PivotTo(ov:GetAttribute("Pivot")) end
	end
	return tr
end

function K.compareBaseline(G)
	local tr = folder():FindFirstChild(G.name)
	if not tr then return nil, "no baseline" end
	local want = {}
	for k, v in tr.Hashes.Value:gmatch("([%d,]+)=(%d+)") do want[k] = v end
	local diff, total = {}, 0
	for k, v in K.hashTiles(G):gmatch("([%d,]+)=(%d+)") do
		total += 1
		if want[k] ~= v then diff[#diff + 1] = k end
	end
	return diff, total
end

-- Dry runs must plan against the baseline, not a previous build: paste the baseline at a scratch spot
-- 20000 studs away, read it there, erase it. The live area is never touched.
function K.readBaseline(G, tr)
	local OFF = 20000
	local S = { name = G.name, x0 = G.x0 + OFF, z0 = G.z0 + OFF, y0 = G.y0, y1 = G.y1, NX = G.NX, NZ = G.NZ, NY = G.NY }
	S.x1, S.z1 = S.x0 + S.NX * RES, S.z0 + S.NZ * RES
	local box = Region3.new(Vector3.new(S.x0, S.y0, S.z0), Vector3.new(S.x1, S.y1, S.z1))
	T:PasteRegion(tr, Vector3int16.new(S.x0 / RES, S.y0 / RES, S.z0 / RES), true)
	local ok, err = pcall(K.read, S)
	T:FillBlock(box.CFrame, box.Size, AIR)
	if not ok then error(err, 0) end
	G.H, G.M, G.GAP, G.WAT = S.H, S.M, S.GAP, S.WAT
	return G
end

-- ============================================================ history + checks
function K.record(name, fn)
	local id = CHS:TryBeginRecording(name)
	local ok, err = pcall(fn)
	if id then CHS:FinishRecording(id, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
	if not ok then error(err, 0) end
end

-- clear air height above the ground at (x, z), scanning up from yFrom
function K.clearance(x, z, yFrom, yTo)
	local r = Region3.new(Vector3.new(x - 2, yFrom, z - 2), Vector3.new(x + 2, yTo, z + 2)):ExpandToGrid(RES)
	local mats, occs = T:ReadVoxels(r, RES)
	local base = r.CFrame.Position.Y - r.Size.Y / 2
	local floorY, run = nil, 0
	for y = 1, #mats[1] do
		local solid = mats[1][y][1] ~= AIR and occs[1][y][1] > 0.5
		if solid then
			if floorY and run > 0 then return run * RES, floorY end
			floorY, run = base + y * RES, 0
		elseif floorY then
			run += 1
		end
	end
	return run * RES, floorY
end

-- smoothness spec per tag (A2 racing line: slope 5-7, rough 0.12-0.22, 67% small steps)
K.spec = {
	lane = { slope = 8, rough = 0.12, small = 65 },
	trough = { slope = 24, rough = 0.2 },
	bowl = { rough = 0.2 },
	flow = { slope = 8, rough = 0.12, small = 65 },
	ramp = { slope = 15, rough = 0.2 },
	meadow = { rough = 0.2 },
	shape = { rough = 0.2 },
}

-- post-write report: columns outside the mask must be untouched; tagged lines graded against the spec
function K.check(G)
	local H0, M0, W = G.H, G.M, G.W
	G.skip3d = G.skip3d or {}
	local R = K.read({ name = G.name, x0 = G.x0, z0 = G.z0, y0 = G.y0, y1 = G.y1, NX = G.NX, NZ = G.NZ, NY = G.NY, x1 = G.x1, z1 = G.z1 })
	local H, M = R.H, R.M
	local outside, badWrite = 0, 0
	local onLocked3d = 0
	for i, h0 in pairs(H0) do
		if (W[i] or 0) == 0 then
			if not H[i] or math.abs(H[i] - h0) > 0.01 or M[i] ~= M0[i] then
				if G.skip3d[i] then onLocked3d += 1 else outside += 1 end
			end
		elseif H[i] and not G.skip3d[i] and math.abs(H[i] - G.Hf[i]) > 0.35 then
			badWrite += 1
		end
	end
	log(string.format("%s unmasked columns changed: %d  (write mismatch >0.35 stud: %d; 3D pieces resting on locked ground: %d cols)", outside == 0 and "PASS" or "FAIL", outside, badWrite, onLocked3d))
	local S = K.slope(G, H)
	-- bump = what is left after curvature cancels: |(h - B h) - (B h - B B h)|, B = 3x3 mean. Zero on any
	-- smooth hill, bowl or curve; only real lumps and voxel steps score (A2 lanes 0.19, A3 p90 0.31)
	local B1 = boxMean(G, H, 1)
	local B2 = boxMean(G, B1, 1)
	local groups = {}
	local NZ = G.NZ
	for gx = 2, G.NX - 1 do
		for gz = 2, NZ - 1 do
			local i = (gx - 1) * NZ + gz
			if (W[i] or 0) > 0.5 and H[i] and not G.skip3d[i] then
				local t = G.TAG[i] or (G.DH[i] and "shape") or "meadow"
				local g = groups[t] or { n = 0, slope = 0, rough = 0, small = 0, dead = 0, maxS = 0 }
				local h = H[i]
				g.n += 1
				g.slope += S[i]
				g.maxS = math.max(g.maxS, S[i])
				g.rough += math.abs((h - B1[i]) - (B1[i] - B2[i]))
				local st = math.max(math.abs((H[i + NZ] or h) - h), math.abs((H[i + 1] or h) - h))
				if st < 0.5 then g.small += 1 end
				if S[i] >= 45 and S[i] < 66 then g.dead += 1 end
				groups[t] = g
			end
		end
	end
	for t, g in pairs(groups) do
		local rough, small, dead = g.rough / g.n, g.small / g.n * 100, g.dead / g.n * 100
		local sp = K.spec[t] or {}
		local pass = dead < 2 and (not sp.slope or g.slope / g.n <= sp.slope) and (not sp.rough or rough <= sp.rough) and (not sp.small or small >= sp.small)
		log(string.format("%s %-8s n=%6d slope avg %4.1f max %4.1f  bump %.2f  steps<0.5 %3.0f%%  dead45-66 %.1f%%", pass and "PASS" or "FAIL", t, g.n, g.slope / g.n, g.maxS, rough, small, dead))
	end
	local mats, n = {}, 0
	for i, w in pairs(W) do
		if w > 0.5 and M[i] then mats[M[i].Name] = (mats[M[i].Name] or 0) + 1; n += 1 end
	end
	local pay = ((mats.Grass or 0) + (mats.LeafyGrass or 0) + (mats.Limestone or 0)) / math.max(n, 1) * 100
	local fam = pay + (mats.Slate or 0) / math.max(n, 1) * 100
	local parts = {}
	for k, v in pairs(mats) do parts[#parts + 1] = string.format("%s %.0f%%", k, v / n * 100) end
	table.sort(parts)
	log(string.format("%s blade materials %.0f%% of edited area (pay ground Grass/Leafy/Limestone %.0f%%) [%s]", fam >= 70 and "PASS" or "FAIL", fam, pay, table.concat(parts, ", ")))
	local padBad = 0
	for _, pd in ipairs(G.pads or {}) do
		local gx, gz = K.cellOf(G, pd.x, pd.z)
		if inGrid(G, gx, gz) then
			local i = ix(G, gx, gz)
			if H0[i] and H[i] and math.abs(H[i] - H0[i]) > 0.5 then padBad += 1 end
		end
	end
	log(string.format("%s props grounded: %d pads, %d moved >0.5 stud", padBad == 0 and "PASS" or "FAIL", #(G.pads or {}), padBad))
	local tBad, tN = 0, 0
	for _, t in ipairs(G.trees or {}) do
		if (G.W[t.ni] or 0) > 0.05 then
			tN += 1
			local want = G.Hf[t.ni]
			if H[t.ni] and want and math.abs(H[t.ni] - want) > 0.6 then tBad += 1 end
		end
	end
	log(string.format("%s trees seated on new ground: %d checked, %d off by >0.6 stud", tBad == 0 and "PASS" or "FAIL", tN, tBad))
	return R
end

-- ASCII preview of the planned (or current) surface: paint letter | height digit, pads 'T', unmasked '.'
function K.preview(G, H, P, cell)
	cell = cell or math.max(2, math.ceil(math.max(G.NX, G.NZ) / 60))
	local CODE = { Grass = "G", LeafyGrass = "L", Limestone = "l", Slate = "S", Rock = "R", Mud = "m", Ground = "g", Basalt = "B", Cobblestone = "C", Sand = "s" }
	local lo, hi = math.huge, -math.huge
	for i, w in pairs(G.W) do if w > 0.5 and H[i] then lo = math.min(lo, H[i]); hi = math.max(hi, H[i]) end end
	local padCell = {}
	for _, pd in ipairs(G.pads or {}) do
		local gx, gz = K.cellOf(G, pd.x, pd.z)
		padCell[((gx - 1) // cell) * 100000 + (gz - 1) // cell] = true
	end
	local lines = { string.format("preview cell=%d studs, X right, Z down; edited height %d..%d -> 0-9; untouched: x hard mat, / steep, ^ air under, y out of band, . buffer; T prop pad", cell * RES, lo, hi) }
	for cz = 1, G.NZ, cell do
		local a, b = {}, {}
		for cx = 1, G.NX, cell do
			local cnt, hs, hn, wsum, whyc = {}, 0, 0, 0, {}
			for x = cx, math.min(G.NX, cx + cell - 1) do
				for z = cz, math.min(G.NZ, cz + cell - 1) do
					local i = ix(G, x, z)
					wsum += G.W[i] or 0
					local wy = G.WHY and G.WHY[i]
					if wy then whyc[wy] = (whyc[wy] or 0) + 1 end
					local m = (P and P[i]) or G.M[i]
					if m then cnt[m] = (cnt[m] or 0) + 1 end
					if H[i] then hs += H[i]; hn += 1 end
				end
			end
			local best, bn = nil, 0
			for m, c in pairs(cnt) do if c > bn then best, bn = m, c end end
			local edited = wsum / (cell * cell) > 0.5
			if padCell[((cx - 1) // cell) * 100000 + (cz - 1) // cell] then a[#a + 1] = "T"
			elseif not edited then
				local bw, bc = ".", 0
				for k, c in pairs(whyc) do if c > bc then bw, bc = k, c end end
				a[#a + 1] = bw
			else a[#a + 1] = best and (CODE[best.Name] or "?") or " " end
			b[#b + 1] = (edited and hn > 0) and tostring(math.clamp(math.floor((hs / hn - lo) / math.max(1, hi - lo) * 10), 0, 9)) or "."
		end
		lines[#lines + 1] = table.concat(a) .. "  " .. table.concat(b)
	end
	return table.concat(lines, "\n")
end

-- summary of what the recipe changes before anything is written
function K.dry(G, features)
	local W = G.W
	local n, masked = 0, 0
	for i in pairs(G.H) do n += 1; if (W[i] or 0) > 0.5 then masked += 1 end end
	log(string.format("mask: %d/%d columns editable (%.0f%%), %d prop pads", masked, n, masked / n * 100, #(G.pads or {})))
	for _, f in ipairs(features) do
		local hits = {}
		if f.hit then
			for _, pd in ipairs(G.pads or {}) do
				if f.hit(pd.x, pd.z) then hits[#hits + 1] = pd.name:match("[^%.]+$") .. string.format("(%.0f,%.0f)", pd.x, pd.z) end
			end
		end
		log(string.format("%-10s %-6s conflicts %d %s", f.name or "?", f.kind or "?", #hits, table.concat(hits, " "):sub(1, 220)))
	end
	local stay, reloc, stuck, maxdy = 0, 0, 0, 0
	for _, t in ipairs(G.trees or {}) do
		if t.relocated then reloc += 1 elseif t.stuck then stuck += 1 else stay += 1 end
		maxdy = math.max(maxdy, math.abs(t.dy or 0))
	end
	log(string.format("trees: %d stay (ride with ground), %d relocated to flat spots, %d stuck, max lift/drop %.1f", stay, reloc, stuck, maxdy))
	local S = K.slope(G, G.Hf)
	local over, cells = 0, 0
	for i, w in pairs(W) do
		if w > 0.5 and S[i] then cells += 1; if S[i] > 31 and S[i] < 66 then over += 1 end end
	end
	log(string.format("planned cells 31-66 deg: %d (%.1f%% of edited)", over, over / math.max(cells, 1) * 100))
end


-- ============================================================ 3D op registry + run dispatcher
-- op3d records its footprint (excluded from heightfield checks) and only touches voxels in build mode
function K.op3d(G, name, bmin, bmax, mode, fn, opt)
	G.ops = G.ops or {}
	table.insert(G.ops, { name = name, bmin = bmin, bmax = bmax, mode = mode, fn = fn, opt = opt })
end

-- Swept 3D piece along a spline (every spline point, ~4 studs: coarser samples show as ribs inside a bore),
-- applied in chunks of 36 samples so each voxel only
-- tests nearby segments. prof(q, L, ground) runs once per sample after compose (ground = G.Hf there);
-- cell(p, n, q0, q1, t) gets the signed lateral offset n (same sign as K.path) and returns d[, material].
local function sweep(G, name, pts, mode, reach, yMin, yMax, prof, cell)
	local S, len = spline(pts)
	local Q = {}
	for k = 1, #S do Q[#Q + 1] = { p = S[k], s = len[k] } end
	local ready = false
	local function prep()
		if ready then return end
		ready = true
		for _, q in ipairs(Q) do
			local gx, gz = K.cellOf(G, q.p.X, q.p.Y)
			prof(q, len[#len], inGrid(G, gx, gz) and G.Hf[ix(G, gx, gz)] or 0)
		end
	end
	for a = 1, #Q - 1, 36 do
		local b = math.min(#Q, a + 36)
		local x0, x1, z0, z1 = 1e9, -1e9, 1e9, -1e9
		for k = a, b do
			local p = Q[k].p
			x0, x1, z0, z1 = math.min(x0, p.X), math.max(x1, p.X), math.min(z0, p.Y), math.max(z1, p.Y)
		end
		local m, ka, kb = reach + 8, math.max(1, a - 1), math.min(#Q, b + 1)
		local cx, cz, cbest, cbk, cbt, csg, cskip
		K.op3d(G, name .. " " .. a, Vector3.new(x0 - m, yMin, z0 - m), Vector3.new(x1 + m, yMax, z1 + m), mode, function(p)
			prep()
			if p.X ~= cx or p.Z ~= cz then
				cx, cz = p.X, p.Z
				local px, best, bk, bt, sg = Vector2.new(p.X, p.Z), math.huge, ka, 0, 1
				for k = ka, kb - 1 do
					local A, AB = Q[k].p, Q[k + 1].p - Q[k].p
					local t = math.clamp((px - A):Dot(AB) / AB:Dot(AB), 0, 1)
					local e = px - A - AB * t
					if e.Magnitude < best then best, bk, bt, sg = e.Magnitude, k, t, (AB.X * e.Y - AB.Y * e.X) >= 0 and 1 or -1 end
				end
				cbest, cbk, cbt, csg = best, bk, bt, sg
				cskip = (bk == ka and bt == 0 and ka > 1) or (bk == kb - 1 and bt == 1 and kb < #Q)
			end
			-- nearest point clamped to this chunk's inner end: the true nearest segment belongs to a neighbour
			-- chunk, and measuring from here would add a wide profile (wall back slope) in the wrong place
			if cskip then return 1e3 end
			return cell(p, csg * cbest, Q[cbk], Q[cbk + 1], cbt)
		end)
	end
	return Q
end

-- Arch bridge across a gully: deck from bank point o.a to bank point o.b, half-width o.width; the top runs
-- between the two bank heights and arches up so the crown is o.thick above the underside apex; the underside
-- is an elliptical arch of half-span o.open with its apex o.clear above o.floor. Top paint o.top, body o.body
-- (either may be a function of the voxel). Built as its own solid: the gully under it stays fully carved.
function K.water(G, name, f, level, o)
	o = o or {}
	local bb = f.bbox
	local follow = type(level) == "table"
	local depth = follow and level.depth or 0
	local top = follow and (level.yMax or G.y1) or level + 4
	local bottom = follow and (level.yMin or G.y0) or (o.yMin or level - 80)
	K.op3d(G, name, Vector3.new(bb[1], bottom, bb[3]), Vector3.new(bb[2], top, bb[4]), "add", function(p)
		if not f.hit(p.X, p.Z) then return 1e3 end
		local surf = level
		if follow then
			local fy = f.floorAt(p.X, p.Z)
			if not fy then return 1e3 end
			surf = fy + depth
		end
		return p.Y - surf, WATER
	end, { airOnly = true })
end

function K.archBridge(G, name, o)
	local A, B = Vector2.new(o.a[1], o.a[2]), Vector2.new(o.b[1], o.b[2])
	local ax, half, mid = (B - A).Unit, (B - A).Magnitude / 2, (A + B) / 2
	local ya, yb, rise
	local function ground(v) local gx, gz = K.cellOf(G, v.X, v.Y) return G.Hf[ix(G, gx, gz)] end
	local m = o.width + 8
	K.op3d(G, name, Vector3.new(math.min(A.X, B.X) - m, o.floor - 8, math.min(A.Y, B.Y) - m),
		Vector3.new(math.max(A.X, B.X) + m, o.floor + o.clear + o.thick + 24, math.max(A.Y, B.Y) + m), "add", function(p)
		if not rise then ya, yb = o.ya or ground(A), o.yb or ground(B) rise = o.floor + o.clear + o.thick - (ya + yb) / 2 end
		local q = Vector2.new(p.X, p.Z) - mid
		local t, w = q:Dot(ax), math.abs(q.X * ax.Y - q.Y * ax.X)
		if math.abs(t) > half then return 1e3 end
		local top = ya + (yb - ya) * (t + half) / (2 * half) + rise * cosb(math.abs(t) / half)
		local bot = math.abs(t) < o.open and o.floor + o.clear * math.sqrt(1 - (t / o.open) ^ 2) or -1e3
		local d = math.max(p.Y - top, bot - p.Y, w - o.width)
		local mt = p.Y > top - 5 and w < o.width - 3 and o.top or o.body
		return d, type(mt) == "function" and mt(p) or mt
	end)
end

-- Bore / slot: flat floor, rounded corners (o.round) into vertical walls; o.arch = vertical sides up to a
-- spring line then a semicircular roof of radius halfW (yTop - yFloor >= halfW). o.wall / floorMat may be
-- functions of the voxel position (patchy mixes). o.prof(s, L, ground, x, z) ->
-- yFloor, yTop, floorMat per sample: yTop above ground = open, below
-- ground = roofed and lined with o.wall (Mud: Basalt/Rock textures read as jagged crystals).
function K.lining(p)
	local n = math.noise(p.X / 16, p.Y / 16, p.Z / 16 + 0.37)
	if n > 0.12 then return MAT.Rock elseif n < -0.12 then return MAT.Ground end
	return MAT.Mud
end

function K.slot(G, name, pts, o)
	local halfW, rr, wall = o.halfW, o.round or 20, o.wall or K.lining
	sweep(G, name, pts, "cut", halfW, o.yMin, o.yMax, function(q, L, g)
		q.g = g
		q.yf, q.yt, q.fm = o.prof(q.s, L, g, q.p.X, q.p.Y)
	end, function(p, n, q0, q1, t)
		local yf, yt = q0.yf + (q1.yf - q0.yf) * t, q0.yt + (q1.yt - q0.yt) * t
		local d
		if o.arch then
			local ys, an = yt - halfW, math.abs(n)
			d = p.Y <= ys and math.max(an - halfW, yf - p.Y) or math.sqrt(an * an + (p.Y - ys) ^ 2) - halfW
		else
			local qx, qy = math.abs(n) - (halfW - rr), math.abs(p.Y - (yf + yt) / 2) - ((yt - yf) / 2 - rr)
			d = Vector2.new(math.max(qx, 0), math.max(qy, 0)).Magnitude + math.min(math.max(qx, qy), 0) - rr
		end
		if d >= RES * 4 then return d end
		local g = q0.g + (q1.g - q0.g) * t
		if yt <= g and p.Y > g - 8 then return d end
		local onFloor = p.Y < yf + 5 and math.abs(n) < halfW - (o.arch and 4 or rr)
		if yt > q0.g + (q1.g - q0.g) * t and not onFloor and p.Y < yf + 5 then return d end
		local m = onFloor and (t < 0.5 and q0 or q1).fm or wall
		return d, type(m) == "function" and m(p) or m
	end)
end

local function markSkip(G)
	G.skip3d = {}
	for _, op in ipairs(G.ops or {}) do
		local ax, az = K.cellOf(G, op.bmin.X, op.bmin.Z)
		local bx, bz = K.cellOf(G, op.bmax.X, op.bmax.Z)
		for gx = math.max(1, ax), math.min(G.NX, bx) do
			for gz = math.max(1, az), math.min(G.NZ, bz) do G.skip3d[ix(G, gx, gz)] = true end
		end
	end
end

-- RUN_MODE ("dry" | "build" | "map") is injected by run.sh. setup(G) returns features, composeOpts,
-- and may call K.keep / K.op3d; maskOpts feed K.mask; checks(G) runs after a build.
function K.subgrid(F, xa, xb, za, zb)
	local G = { name = F.name, box = F.box, y0 = F.y0, y1 = F.y1, NY = F.NY }
	G.x0 = math.max(F.x0, math.floor(xa / RES) * RES)
	G.z0 = math.max(F.z0, math.floor(za / RES) * RES)
	G.x1 = math.min(F.x1, math.ceil(xb / RES) * RES)
	G.z1 = math.min(F.z1, math.ceil(zb / RES) * RES)
	G.NX, G.NZ = (G.x1 - G.x0) / RES, (G.z1 - G.z0) / RES
	G.edge = { F.x0, F.x1, F.z0, F.z1 }
	return G
end

local CHUNK_MARGIN = 96
local function chunkGrid(F, c, m) m = m or CHUNK_MARGIN return K.subgrid(F, c[1] - m, c[2] + m, c[3] - m, c[4] + m) end
local function chunkFolder(F, create)
	local root = folder()
	local f = root:FindFirstChild(F.name .. "_chunks")
	if not f and create then
		f = Instance.new("Folder")
		f.Name = F.name .. "_chunks"
		f.Parent = root
	end
	return f
end

function K.readChunkBaselines(G, F, chunks, f, snap)
	local OFF = 20000
	local S = { name = G.name, x0 = G.x0 + OFF, z0 = G.z0 + OFF, y0 = G.y0, y1 = G.y1, NX = G.NX, NZ = G.NZ, NY = G.NY }
	S.x1, S.z1 = S.x0 + S.NX * RES, S.z0 + S.NZ * RES
	local boxes = {}
	for k, c in ipairs(chunks) do
		local tr = f:FindFirstChild("c" .. k)
		local C = chunkGrid(F, c, snap)
		if tr and C.x0 < G.x1 and C.x1 > G.x0 and C.z0 < G.z1 and C.z1 > G.z0 then
			T:PasteRegion(tr, Vector3int16.new((C.x0 + OFF) / RES, C.y0 / RES, (C.z0 + OFF) / RES), true)
			boxes[#boxes + 1] = Region3.new(Vector3.new(C.x0 + OFF, C.y0, C.z0 + OFF), Vector3.new(C.x1 + OFF, C.y1, C.z1 + OFF))
		end
	end
	local ok, err = pcall(K.read, S)
	for _, b in ipairs(boxes) do T:FillBlock(b.CFrame, b.Size, AIR) task.wait() end
	if not ok then error(err, 0) end
	G.H, G.M, G.GAP, G.WAT = S.H, S.M, S.GAP, S.WAT
	return #boxes
end

local function computeMargin(maskOpts) return maskOpts.chunkMargin or math.max(CHUNK_MARGIN, 288) end

local function readChunkBase(G, F, maskOpts, f)
	local snap = f:GetAttribute("Margin") or CHUNK_MARGIN
	if computeMargin(maskOpts) > snap then
		log("chunk baseline assembled from " .. K.readChunkBaselines(G, F, maskOpts.chunks, f, snap) .. " snapshots (snapshot margin " .. snap .. ", compute margin " .. computeMargin(maskOpts) .. ")")
	else
		K.readBaseline(G, f["c" .. CHUNK_INDEX])
	end
end

function K.chunkBackup(F, chunks, margin)
	local f = chunkFolder(F, true)
	if not f:GetAttribute("Margin") and #f:GetChildren() == 0 then f:SetAttribute("Margin", margin or CHUNK_MARGIN) end
	local made = 0
	for k, c in ipairs(chunks) do
		if not f:FindFirstChild("c" .. k) then
			local G = chunkGrid(F, c, margin)
			local tr = T:CopyRegion(Region3int16.new(Vector3int16.new(G.x0 / RES, G.y0 / RES, G.z0 / RES), Vector3int16.new(G.x1 / RES - 1, G.y1 / RES - 1, G.z1 / RES - 1)))
			tr.Name = "c" .. k
			tr.Parent = f
			made += 1
		end
	end
	return "chunk baselines: " .. made .. " new, " .. #f:GetChildren() .. " total"
end

local function runChunk(box, maskOpts, setup)
	local F = K.grid(box)
	local chunks = maskOpts.chunks
	local c = chunks[CHUNK_INDEX]
	assert(c, "no chunk " .. tostring(CHUNK_INDEX))
	local f = chunkFolder(F, false)
	assert(f and #f:GetChildren() >= #chunks, "chunk baselines missing: run chunk 0 first")
	local G = chunkGrid(F, c, computeMargin(maskOpts))
	G.chunkMargin = computeMargin(maskOpts)
	G.yieldEvery = 4000
	local tp, tl = os.clock(), {}
	local function lap(n) tl[#tl + 1] = string.format("%s %.1f", n, os.clock() - tp) tp = os.clock() task.wait() end
	readChunkBase(G, F, maskOpts, f)
	lap("read")
	K.mask(G, maskOpts)
	lap("mask")
	K.protect(G, maskOpts.protect)
	lap("protect")
	local features, copt = setup(G)
	copt = copt or {}
	copt.trees = false
	K.compose(G, features, copt)
	lap("compose")
	markSkip(G)
	local L = K.read({ name = G.name, x0 = G.x0, z0 = G.z0, x1 = G.x1, z1 = G.z1, y0 = G.y0, y1 = G.y1, NX = G.NX, NZ = G.NZ, NY = G.NY })
	G.Hlive, G.Mlive = L.H, L.M
	lap("live")
	log("phases (s, excl. yields): " .. table.concat(tl, ", "))
	local t0 = os.clock()
	K.record("rbx-terrain " .. G.name .. " chunk " .. CHUNK_INDEX, function()
		log("chunk " .. CHUNK_INDEX .. " columns rewritten: " .. K.write(G, nil, c) .. " (+" .. (G.opCols or 0) .. " under 3D pieces, re-applied by their op)")
		for _, op in ipairs(G.ops or {}) do
			local a = Vector3.new(math.max(op.bmin.X, c[1]), op.bmin.Y, math.max(op.bmin.Z, c[3]))
			local b = Vector3.new(math.min(op.bmax.X, c[2]), op.bmax.Y, math.min(op.bmax.Z, c[4]))
			if a.X < b.X and a.Z < b.Z then
				log(string.format("3d %s %s voxels %d", op.name, op.mode, K.voxels(a, b, op.mode, op.fn, op.opt)))
				task.wait()
			end
		end
	end)
	local C = K.read(K.subgrid(F, c[1], c[2], c[3], c[4]))
	local worst, off, n, sl, smax, steepOff = 0, 0, 0, 0, 0, 0
	local S = K.slope(G, G.Hf)
	for gx = 1, C.NX do
		for gz = 1, C.NZ do
			local x, z = K.cellXZ(C, gx, gz)
			local i = ix(G, K.cellOf(G, x, z))
			local h = C.H[(gx - 1) * C.NZ + gz]
			local inside = x >= c[1] and x < c[2] and z >= c[3] and z < c[4]
			if inside and h and G.Hf[i] and not G.skip3d[i] then
				local d = math.abs(h - G.Hf[i])
				if S[i] >= 45 then
					if d > 0.35 then steepOff += 1 end
					d = 0
				end
				if d > worst then G.worstAt = string.format("(%.0f,%.0f) live %.1f plan %.1f base %.1f", x, z, h, G.Hf[i], G.H[i]) end
				worst = math.max(worst, d)
				if d > 0.35 then off += 1 end
				if G.TAG[i] == "lane" then n += 1; sl += S[i]; smax = math.max(smax, S[i]) end
			end
		end
	end
	if G.worstAt then log("worst at " .. G.worstAt) end
	log(string.format("%s chunk %d core: heightfield vs plan off>0.35 %d cols (worst %.2f), steep-face cells off %d; lane cells %d slope avg %.1f max %.1f; write %.1fs", worst < 1.5 and "PASS" or "FAIL", CHUNK_INDEX, off, worst, steepOff, n, n > 0 and sl / n or 0, smax, os.clock() - t0))
	return table.concat(K.out, "\n")
end

function K.planGrab(G, rect)
	local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local codes = { Grass = "G", LeafyGrass = "L", Limestone = "S", Basalt = "B", Rock = "R", Water = "W", Pavement = "P", Mud = "M", Ground = "D", Sand = "A", Sandstone = "N", Cobblestone = "C", Slate = "T", Salt = "X", Asphalt = "Y", Concrete = "Z", Snow = "O", Glacier = "I", Ice = "E" }
	local function ch(n) return A:sub(n + 1, n + 1) end
	local ax, az, bx, bz = 1, 1, G.NX, G.NZ
	if rect then
		ax, az = K.cellOf(G, rect[1] + 2, rect[3] + 2)
		bx, bz = K.cellOf(G, rect[2] - 2, rect[4] - 2)
		ax, az, bx, bz = math.max(1, ax), math.max(1, az), math.min(G.NX, bx), math.min(G.NZ, bz)
	end
	local x0, z0 = K.cellXZ(G, ax, az)
	local rows = { string.format("#grab %d %d %d %d %d", x0, z0, bx - ax + 1, bz - az + 1, RES) }
	for gz = az, bz do
		local t = {}
		for gx = ax, bx do
			local i = ix(G, gx, gz)
			local h = G.Hf[i] or G.H[i]
			if h then
				local q = math.clamp(math.floor((h + 2 + 2048) * 16 + 0.5), 0, 262143)
				local m = (G.P and G.P[i]) or G.M[i]
				t[#t + 1] = ch(q // 4096) .. ch(q // 64 % 64) .. ch(q % 64) .. (m and codes[m.Name] or "?") .. "A"
			else
				t[#t + 1] = "AAA_A"
			end
		end
		rows[#rows + 1] = "|" .. table.concat(t)
	end
	local text = table.concat(rows, "\n")
	if #text <= 90000 then return text end
	local root = SS:FindFirstChild("TerrainPlan") or Instance.new("Folder")
	root.Name = "TerrainPlan"
	root.Parent = SS
	local old = root:FindFirstChild(G.name)
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = G.name
	local page, size, n = {}, 0, 0
	local function flush()
		n += 1
		local v = Instance.new("StringValue")
		v.Name = "p" .. n
		v.Value = table.concat(page, "\n")
		v.Parent = f
		page, size = {}, 0
	end
	for _, r in ipairs(rows) do
		if size + #r > 90000 and #page > 0 then flush() end
		page[#page + 1] = r
		size += #r + 1
	end
	if #page > 0 then flush() end
	f.Parent = root
	return "#pages " .. n .. " " .. G.name
end

function K.run(box, maskOpts, setup, checks)
	local mode = RUN_MODE or "dry"
	if mode == "check" then
		checks(K.grid(box))
		return table.concat(K.out, "\n")
	end
	if mode == "chunk" then
		if CHUNK_INDEX == 0 then return K.chunkBackup(K.grid(box), maskOpts.chunks, maskOpts.snapMargin or maskOpts.chunkMargin) end
		return runChunk(box, maskOpts, setup)
	end
	if mode == "plan" and CHUNK_INDEX and CHUNK_INDEX > 0 then
		local F = K.grid(box)
		local c = maskOpts.chunks[CHUNK_INDEX]
		local G = chunkGrid(F, c, computeMargin(maskOpts))
		G.chunkMargin = computeMargin(maskOpts)
		local f = chunkFolder(F, false)
		if f and f:FindFirstChild("c" .. CHUNK_INDEX) then readChunkBase(G, F, maskOpts, f) else K.read(G) end
		K.mask(G, maskOpts)
		K.protect(G, maskOpts.protect)
		local features, copt = setup(G)
		copt = copt or {}
		copt.trees = false
		K.compose(G, features, copt)
		return K.planGrab(G, c)
	end
	local G = K.grid(box)
	if mode == "build" then
		local tr = SS:FindFirstChild("TerrainBackups") and SS.TerrainBackups:FindFirstChild(G.name)
		if tr then
			K.snapTrees(G, tr)
			K.restore(G)
		else
			log(K.backup(G))
		end
	end
	local tr = SS:FindFirstChild("TerrainBackups") and SS.TerrainBackups:FindFirstChild(G.name)
	if mode ~= "build" and tr then
		K.readBaseline(G, tr)
		local tf = tr:FindFirstChild("Trees")
		if tf then
			G.treeOrig = {}
			for _, ov in ipairs(tf:GetChildren()) do if ov.Value then G.treeOrig[ov.Value] = ov:GetAttribute("Pivot") end end
		end
	else
		K.read(G)
	end
	K.mask(G, maskOpts)
	K.protect(G, maskOpts and maskOpts.protect)
	local features, copt = setup(G)
	K.compose(G, features, copt)
	markSkip(G)
	if mode ~= "build" then
		K.dry(G, features)
		for _, op in ipairs(G.ops or {}) do
			local hits = {}
			for _, pd in ipairs(G.pads) do
				if pd.x > op.bmin.X - pd.r and pd.x < op.bmax.X + pd.r and pd.z > op.bmin.Z - pd.r and pd.z < op.bmax.Z + pd.r then hits[#hits + 1] = pd.name:match("[^%.]+$") end
			end
			log(string.format("%-10s 3d-%s conflicts %d %s", op.name, op.mode, #hits, table.concat(hits, " ")))
		end
		if mode == "map" then log(K.preview(G, G.Hf, G.P)) end
		if mode == "plan" then return K.planGrab(G) end
		return table.concat(K.out, "\n")
	end
	K.record("rbx-terrain " .. G.name, function()
		log("columns rewritten: " .. K.write(G))
		local moved = 0
		for _, t in ipairs(G.trees or {}) do
			local d = Vector3.new(t.nx - t.x, t.dy or 0, t.nz - t.z)
			if d.Magnitude > 0.05 then t.inst:PivotTo(t.inst:GetPivot() + d); moved += 1 end
		end
		log("trees moved: " .. moved)
		for _, op in ipairs(G.ops or {}) do
			log(string.format("3d %s %s voxels %d", op.name, op.mode, K.voxels(op.bmin, op.bmax, op.mode, op.fn, op.opt)))
			task.wait()
		end
	end)
	K.check(G)
	if checks then checks(G) end
	return table.concat(K.out, "\n")
end

-- ============================================================ placement
-- clearance[i] = distance (studs) from cell i to the nearest locked cell (W < 0.95) or prop pad edge.
-- A disc feature of radius r fits wherever clearance >= r.
function K.clearance2d(G)
	local bad = {}
	for i = 1, G.NX * G.NZ do if (G.W[i] or 0) < 0.95 then bad[i] = true end end
	local D = distField(G, bad)
	G.CLR = D
	return D
end

-- greedy: biggest free discs first, centres at least `spacing` apart (default: sum of radii)
function K.spots(G, minR, n, spacing, filter)
	local D = G.CLR or K.clearance2d(G)
	local cand = {}
	for gx = 1, G.NX, 2 do
		for gz = 1, G.NZ, 2 do
			local i = ix(G, gx, gz)
			if D[i] >= minR then
				local x, z = K.cellXZ(G, gx, gz)
				if not filter or filter(x, z) then cand[#cand + 1] = { x = x, z = z, r = D[i], h = G.H[i] } end
			end
		end
	end
	table.sort(cand, function(a, b) return a.r > b.r end)
	local out = {}
	for _, c in ipairs(cand) do
		local ok = true
		for _, o in ipairs(out) do
			if (c.x - o.x) ^ 2 + (c.z - o.z) ^ 2 < (spacing or (c.r + o.r)) ^ 2 then ok = false; break end
		end
		if ok then out[#out + 1] = c; if #out >= n then break end end
	end
	return out
end

-- A* through the clearance field: returns spline control points ({x, z} every `spacing` studs) for a lane
-- whose footprint (minClear = halfW + bank / 2) never touches a prop pad or locked ground. Waypoints are
-- visited in order; cost prefers roomy cells so the line sits mid-gap rather than grazing trees.
function K.route(G, waypoints, minClear, spacing)
	local D = G.CLR or K.clearance2d(G)
	local NX, NZ = G.NX, G.NZ
	local function snap(x, z)
		local gx, gz = K.cellOf(G, x, z)
		local best, bi = -1, nil
		for dx = -12, 12 do
			for dz = -12, 12 do
				local ax, az = gx + dx, gz + dz
				if inGrid(G, ax, az) then
					local i = ix(G, ax, az)
					if D[i] > best then best, bi = D[i], i end
				end
			end
		end
		return bi
	end
	local nodes = {}
	local lastI
	for w = 1, #waypoints - 1 do
		local s, t = snap(waypoints[w][1], waypoints[w][2]), snap(waypoints[w + 1][1], waypoints[w + 1][2])
		local g, came, open = { [s] = 0 }, {}, { s }
		local tgx, tgz = (t - 1) // NZ + 1, (t - 1) % NZ + 1
		local function hscore(i)
			local gx, gz = (i - 1) // NZ + 1, (i - 1) % NZ + 1
			return math.sqrt((gx - tgx) ^ 2 + (gz - tgz) ^ 2) * RES
		end
		local f = { [s] = hscore(s) }
		local closed, found, steps = {}, false, 0
		while #open > 0 do
			steps += 1
			if steps % 4000 == 0 then task.wait() end
			local bi, bk = 1, f[open[1]]
			for k = 2, #open do if f[open[k]] < bk then bi, bk = k, f[open[k]] end end
			local c = open[bi]
			open[bi] = open[#open]
			open[#open] = nil
			if c == t then found = true break end
			closed[c] = true
			local cx, cz = (c - 1) // NZ + 1, (c - 1) % NZ + 1
			for dx = -1, 1 do
				for dz = -1, 1 do
					if dx ~= 0 or dz ~= 0 then
						local nx, nz = cx + dx, cz + dz
						if inGrid(G, nx, nz) then
							local n = ix(G, nx, nz)
							if not closed[n] and (D[n] >= minClear or n == t) then
								local step = (dx ~= 0 and dz ~= 0) and RES * 1.414 or RES
								local ng = g[c] + step * (1 + 20 / math.max(D[n], 1))
								if not g[n] or ng < g[n] then
									if not g[n] then open[#open + 1] = n end
									g[n], came[n], f[n] = ng, c, ng + hscore(n)
								end
							end
						end
					end
				end
			end
		end
		if not found then error(string.format("route: no gap >= %d studs between waypoint %d and %d", minClear, w, w + 1), 0) end
		local seg, c = {}, t
		while c do table.insert(seg, 1, c); c = came[c] end
		for k, i in ipairs(seg) do if not (k == 1 and lastI == i) then nodes[#nodes + 1] = i end end
		lastI = t
	end
	local pts, acc, prev = {}, 0, nil
	for k, i in ipairs(nodes) do
		local x, z = K.cellXZ(G, (i - 1) // NZ + 1, (i - 1) % NZ + 1)
		if prev then acc += math.sqrt((x - prev[1]) ^ 2 + (z - prev[2]) ^ 2) end
		if k == 1 or k == #nodes or acc >= (spacing or 90) then pts[#pts + 1] = { x, z }; acc = 0 end
		prev = { x, z }
	end
	return pts
end
