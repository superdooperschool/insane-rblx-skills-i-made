-- rbx-terrain scan: the grammar numbers for one marker box (run.sh scan <Box> [map]).
-- Pads 96 studs above/below the box so a shallow marker still sees the whole surface.
local NAME = "__BOX__"
local SHOW_MAP = __MAP__
local RES = 4
local PAD_Y = 96
local p = workspace:FindFirstChild(NAME)
local T = workspace.Terrain
local out = {}
local function w(s) out[#out + 1] = s end

local cf, size = p.CFrame, p.Size
local rx, ry, rz = cf:ToOrientation()
w(string.format("%s center=(%.0f,%.0f,%.0f) size=(%.0f,%.0f,%.0f) rot=(%.1f,%.1f,%.1f)", NAME, cf.X, cf.Y, cf.Z, size.X, size.Y, size.Z, math.deg(rx), math.deg(ry), math.deg(rz)))

local function snapDown(v) return math.floor(v / RES) * RES end
local function snapUp(v) return math.ceil(v / RES) * RES end
local x0, x1 = snapDown(cf.X - size.X / 2), snapUp(cf.X + size.X / 2)
local z0, z1 = snapDown(cf.Z - size.Z / 2), snapUp(cf.Z + size.Z / 2)
local y0, y1 = snapDown(cf.Y - size.Y / 2 - PAD_Y), snapUp(cf.Y + size.Y / 2 + PAD_Y)
local NX, NZ, NY = (x1 - x0) / RES, (z1 - z0) / RES, (y1 - y0) / RES

local AIR, WATER = Enum.Material.Air, Enum.Material.Water
local H, M, WAT, GAP, GAPH, SOLIDN = {}, {}, {}, {}, {}, {}
local matSolid = {}
local topOccHist = { 0, 0, 0, 0, 0 }
local hitsTop, hitsBottom = 0, 0

local CH = 32
for cx = 0, NX - 1, CH do
	local cw = math.min(CH, NX - cx)
	local r = Region3.new(Vector3.new(x0 + cx * RES, y0, z0), Vector3.new(x0 + (cx + cw) * RES, y1, z1))
	local mats, occs = T:ReadVoxels(r, RES)
	for ix = 1, cw do
		local mx, ox = mats[ix], occs[ix]
		for iz = 1, NZ do
			local gx = cx + ix
			local idx = (gx - 1) * NZ + iz
			local top, topMat, water, seenSolid, gapTotal, gapTop = nil, nil, false, false, 0, nil
			local inGap, gapStart = false, nil
			for iy = NY, 1, -1 do
				local m, o = mx[iy][iz], ox[iy][iz]
				local solid = m ~= AIR and m ~= WATER and o > 0.05
				if m == WATER and o > 0.05 and not seenSolid then water = true end
				if solid then
					matSolid[m] = (matSolid[m] or 0) + 1
					if not seenSolid then
						seenSolid = true
						top = y0 + (iy - 1) * RES + o * RES
						topMat = m
						local b = math.min(5, math.floor(o * 5) + 1)
						topOccHist[b] += 1
						if iy == NY then hitsTop += 1 end
					elseif inGap then
						inGap = false
						local gh = (gapStart - iy) * RES
						if gh >= 8 then
							gapTotal += gh
							gapTop = gapTop or (y0 + (iy) * RES)
						end
					end
				elseif seenSolid and not inGap then
					inGap, gapStart = true, iy
				end
			end
			if seenSolid then
				local lowest = mx[1][iz]
				if lowest ~= AIR and lowest ~= WATER then hitsBottom += 1 end
			end
			H[idx], M[idx], WAT[idx] = top, topMat, water
			if gapTotal > 0 then GAP[idx] = gapTotal; GAPH[idx] = gapTop end
		end
	end
	task.wait()
end

local function at(gx, gz)
	if gx < 1 or gz < 1 or gx > NX or gz > NZ then return nil end
	return H[(gx - 1) * NZ + gz]
end

local cols, terrCols = NX * NZ, 0
local hs = {}
local matTop = {}
local slopeB = { 5, 10, 20, 30, 45, 55, 70, 91 }
local slopeCnt, slopeMat = {}, {}
for i = 1, #slopeB do slopeCnt[i] = 0; slopeMat[i] = {} end
local SL = {}
local waterCols, gapCols = 0, 0
for gx = 1, NX do
	for gz = 1, NZ do
		local idx = (gx - 1) * NZ + gz
		local h = H[idx]
		if WAT[idx] then waterCols += 1 end
		if GAP[idx] then gapCols += 1 end
		if h then
			terrCols += 1
			hs[#hs + 1] = h
			local m = M[idx]
			matTop[m] = (matTop[m] or 0) + 1
			local hxp, hxm, hzp, hzm = at(gx + 1, gz) or h, at(gx - 1, gz) or h, at(gx, gz + 1) or h, at(gx, gz - 1) or h
			local g = math.sqrt(((hxp - hxm) / (2 * RES)) ^ 2 + ((hzp - hzm) / (2 * RES)) ^ 2)
			local deg = math.deg(math.atan(g))
			SL[idx] = deg
			for i, b in ipairs(slopeB) do
				if deg < b then
					slopeCnt[i] += 1
					slopeMat[i][m] = (slopeMat[i][m] or 0) + 1
					break
				end
			end
		end
	end
end
table.sort(hs)
local function pct(q) return hs[math.max(1, math.floor(#hs * q))] or 0 end
w(string.format("grid %dx%d cols @%d studs, terrain cols %.0f%%, water %.1f%%, overhang/tunnel cols %.1f%%, surface at scan ceiling %d, solid at scan floor %d", NX, NZ, RES, terrCols / cols * 100, waterCols / cols * 100, gapCols / cols * 100, hitsTop, hitsBottom))
w(string.format("height min %.0f p10 %.0f p25 %.0f p50 %.0f p75 %.0f p90 %.0f max %.0f", pct(0), pct(0.1), pct(0.25), pct(0.5), pct(0.75), pct(0.9), pct(1)))

local function matList(tbl, total, minPct)
	local arr = {}
	for m, n in pairs(tbl) do arr[#arr + 1] = { m.Name, n } end
	table.sort(arr, function(a, b) return a[2] > b[2] end)
	local s = {}
	for _, e in ipairs(arr) do
		local p = e[2] / total * 100
		if p >= (minPct or 0.5) then s[#s + 1] = string.format("%s %.0f%%", e[1], p) end
	end
	return table.concat(s, ", ")
end
w("TOP material: " .. matList(matTop, terrCols, 0.2))
local solidTotal = 0
for _, n in pairs(matSolid) do solidTotal += n end
w("ALL solid voxels: " .. matList(matSolid, solidTotal, 0.5))
w(string.format("top voxel occupancy hist (0-.2,.2-.4,.4-.6,.6-.8,.8-1): %s", table.concat(topOccHist, ",")))
w("SLOPE (deg) -> %area [top mats]:")
local prev = 0
for i, b in ipairs(slopeB) do
	if slopeCnt[i] > 0 then
		w(string.format("  %2d-%2d: %4.1f%%  [%s]", prev, b, slopeCnt[i] / terrCols * 100, matList(slopeMat[i], slopeCnt[i], 3)))
	end
	prev = b
end

-- material by height band (10 bands between p2 and p98)
local lo, hi = pct(0.02), pct(0.98)
local bandMat, bandCnt = {}, {}
for i = 1, 10 do bandMat[i] = {}; bandCnt[i] = 0 end
for idx, h in pairs(H) do
	local b = math.clamp(math.floor((h - lo) / math.max(1, hi - lo) * 10) + 1, 1, 10)
	bandCnt[b] += 1
	local m = M[idx]
	bandMat[b][m] = (bandMat[b][m] or 0) + 1
end
w(string.format("MATERIAL BY HEIGHT band (%.0f..%.0f):", lo, hi))
for i = 10, 1, -1 do
	if bandCnt[i] > 0 then
		w(string.format("  b%-2d y~%4.0f %4.1f%% [%s]", i, lo + (i - 0.5) * (hi - lo) / 10, bandCnt[i] / terrCols * 100, matList(bandMat[i], bandCnt[i], 4)))
	end
end

-- roughness on walkable (<25deg): |h - mean 5x5|
local rsum, rn, lapsum = 0, 0, 0
local roughBins = { 0, 0, 0, 0 }
for gx = 3, NX - 2 do
	for gz = 3, NZ - 2 do
		local idx = (gx - 1) * NZ + gz
		local h, s = H[idx], SL[idx]
		if h and s and s < 25 then
			local sum, n = 0, 0
			for dx = -2, 2 do for dz = -2, 2 do local v = at(gx + dx, gz + dz); if v then sum += v; n += 1 end end end
			local d = math.abs(h - sum / n)
			rsum += d; rn += 1
			local lap = math.abs((at(gx + 1, gz) or h) + (at(gx - 1, gz) or h) + (at(gx, gz + 1) or h) + (at(gx, gz - 1) or h) - 4 * h)
			lapsum += lap
			if d < 0.25 then roughBins[1] += 1 elseif d < 0.75 then roughBins[2] += 1 elseif d < 2 then roughBins[3] += 1 else roughBins[4] += 1 end
		end
	end
end
if rn > 0 then
	w(string.format("ROUGHNESS walkable(<25deg): mean|h-avg5x5| %.2f studs, mean|laplacian| %.2f; bins <.25:%.0f%% <.75:%.0f%% <2:%.0f%% >=2:%.0f%%", rsum / rn, lapsum / rn, roughBins[1] / rn * 100, roughBins[2] / rn * 100, roughBins[3] / rn * 100, roughBins[4] / rn * 100))
end

-- material adjacency on the surface
local adj = {}
for gx = 1, NX - 1 do
	for gz = 1, NZ - 1 do
		local idx = (gx - 1) * NZ + gz
		local a = M[idx]
		if a then
			for _, j in ipairs({ idx + NZ, idx + 1 }) do
				local b = M[j]
				if b and b ~= a then
					local k = a.Name < b.Name and (a.Name .. "|" .. b.Name) or (b.Name .. "|" .. a.Name)
					adj[k] = (adj[k] or 0) + 1
				end
			end
		end
	end
end
local aa = {}
for k, n in pairs(adj) do aa[#aa + 1] = { k, n } end
table.sort(aa, function(a, b) return a[2] > b[2] end)
local as = {}
for i = 1, math.min(10, #aa) do as[#as + 1] = aa[i][1] .. " " .. aa[i][2] end
w("BORDERS: " .. table.concat(as, ", "))

-- patches (4-connected) per top material
local seen = {}
local patch = {}
for idx = 1, NX * NZ do
	local m = M[idx]
	if m and not seen[idx] then
		local stack, n = { idx }, 0
		seen[idx] = true
		while #stack > 0 do
			local c = table.remove(stack)
			n += 1
			local gx, gz = (c - 1) // NZ + 1, (c - 1) % NZ + 1
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local nx, nz = gx + d[1], gz + d[2]
				if nx >= 1 and nz >= 1 and nx <= NX and nz <= NZ then
					local j = (nx - 1) * NZ + nz
					if not seen[j] and M[j] == m then seen[j] = true; stack[#stack + 1] = j end
				end
			end
		end
		local pr = patch[m] or { count = 0, big = 0, sizes = {} }
		pr.count += 1
		pr.big = math.max(pr.big, n)
		pr.sizes[#pr.sizes + 1] = n
		patch[m] = pr
	end
end
w("PATCHES (count>=3 cells, median area studs^2, largest):")
for m, pr in pairs(patch) do
	local big = {}
	for _, n in ipairs(pr.sizes) do if n >= 3 then big[#big + 1] = n end end
	table.sort(big)
	if #big > 0 then
		w(string.format("  %-11s n=%d median=%d largest=%d", m.Name, #big, big[math.max(1, #big // 2)] * RES * RES, pr.big * RES * RES))
	end
end

-- gaps / tunnels
if gapCols > 0 then
	local gh = {}
	for idx, g in pairs(GAP) do gh[#gh + 1] = g end
	table.sort(gh)
	w(string.format("AIR GAPS under surface: %d cols, gap height p10 %d p50 %d p90 %d", gapCols, gh[math.max(1, #gh // 10)], gh[math.max(1, #gh // 2)], gh[math.max(1, #gh * 9 // 10)]))
end


-- per-material role: mean slope and height vs the 52-stud local mean (crest vs hollow)
do
	local S2, C2 = {}, {}
	local function k(gx, gz) return gx * (NZ + 1) + gz end
	for gx = 0, NX do S2[k(gx, 0)] = 0; C2[k(gx, 0)] = 0 end
	for gz = 0, NZ do S2[k(0, gz)] = 0; C2[k(0, gz)] = 0 end
	for gx = 1, NX do for gz = 1, NZ do
		local h = H[(gx - 1) * NZ + gz]
		S2[k(gx, gz)] = S2[k(gx - 1, gz)] + S2[k(gx, gz - 1)] - S2[k(gx - 1, gz - 1)] + (h or 0)
		C2[k(gx, gz)] = C2[k(gx - 1, gz)] + C2[k(gx, gz - 1)] - C2[k(gx - 1, gz - 1)] + (h and 1 or 0)
	end end
	local R = 6
	local st = {}
	for gx = 1, NX do for gz = 1, NZ do
		local i = (gx - 1) * NZ + gz
		local h, m = H[i], M[i]
		if h and SL[i] then
			local ax, az, bx, bz = math.max(1, gx - R), math.max(1, gz - R), math.min(NX, gx + R), math.min(NZ, gz + R)
			local c = C2[k(bx, bz)] - C2[k(ax - 1, bz)] - C2[k(bx, az - 1)] + C2[k(ax - 1, az - 1)]
			local mean = (S2[k(bx, bz)] - S2[k(ax - 1, bz)] - S2[k(bx, az - 1)] + S2[k(ax - 1, az - 1)]) / c
			local s = st[m] or { n = 0, deg = 0, rel = 0, up = 0, down = 0 }
			s.n += 1; s.deg += SL[i]; s.rel += h - mean
			if h - mean > 1.5 then s.up += 1 elseif h - mean < -1.5 then s.down += 1 end
			st[m] = s
		end
	end end
	w("ROLE (slope avg | height vs local mean | % above +1.5 | % below -1.5):")
	local arr = {}
	for m, s in pairs(st) do if s.n > 50 then arr[#arr + 1] = { m.Name, s } end end
	table.sort(arr, function(a, b) return a[2].n > b[2].n end)
	for _, e in ipairs(arr) do
		local s = e[2]
		w(string.format("  %-11s slope %4.1f  rel %+5.1f  up %3.0f%%  down %3.0f%%", e[1], s.deg / s.n, s.rel / s.n, s.up / s.n * 100, s.down / s.n * 100))
	end
end

if not SHOW_MAP then return table.concat(out, "\n") end
-- ASCII maps (X right, Z down)
local CODE = {
	Grass = "G", LeafyGrass = "L", Limestone = "l", Slate = "S", Rock = "R", Sand = "s", Mud = "m", Ground = "g",
	Cobblestone = "C", Basalt = "B", Concrete = "c", Sandstone = "d", Salt = "t", Snow = "n", Ice = "i", Glacier = "I",
	Pavement = "p", Brick = "b", WoodPlanks = "w", CrackedLava = "v", Asphalt = "a",
}
local cell = math.max(2, math.ceil(math.max(NX, NZ) / 64))
w(string.format("MAP cell=%d studs, X->right, Z->down. mat | height 0-9 (lo..hi) ~water ^overhang # >=45deg", cell * RES))
for cz = 1, NZ, cell do
	local l1, l2 = {}, {}
	for cx = 1, NX, cell do
		local cnt, hsum, hn, wat, gap, steep = {}, 0, 0, 0, 0, 0
		for gx = cx, math.min(NX, cx + cell - 1) do
			for gz = cz, math.min(NZ, cz + cell - 1) do
				local idx = (gx - 1) * NZ + gz
				local m = M[idx]
				if m then cnt[m] = (cnt[m] or 0) + 1; hsum += H[idx]; hn += 1 end
				if WAT[idx] then wat += 1 end
				if GAP[idx] then gap += 1 end
				if SL[idx] and SL[idx] >= 45 then steep += 1 end
			end
		end
		local best, bn = nil, 0
		for m, n in pairs(cnt) do if n > bn then best, bn = m, n end end
		local area = cell * cell
		if not best then l1[#l1 + 1] = " "; l2[#l2 + 1] = " "
		else
			l1[#l1 + 1] = (wat > area / 3) and "~" or (gap > area / 3) and "^" or (CODE[best.Name] or "?")
			local hv = hsum / hn
			l2[#l2 + 1] = (steep > area / 2) and "#" or tostring(math.clamp(math.floor((hv - lo) / math.max(1, hi - lo) * 10), 0, 9))
		end
	end
	w(table.concat(l1) .. "  " .. table.concat(l2))
end
return table.concat(out, "\n")
