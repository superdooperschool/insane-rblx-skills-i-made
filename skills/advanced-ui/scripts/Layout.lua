local Layout = {}

local DQ = { 1, 1, 0, -1, -1, 0 }
local DR = { 0, -1, -1, 0, 1, 1 }
local SQRT3 = math.sqrt(3)

local function wrap(d)
	return (d - 1) % 6 + 1
end

local function key(q, r)
	return (q + 2048) * 4096 + (r + 2048)
end

local function stem(id)
	return (id:gsub("%d+$", ""))
end

function Layout.pixel(q, r)
	return 1.5 * q, SQRT3 * (r + q * 0.5)
end

function Layout.solve(nodes, rootId, firstDir)
	local byId, kids, size = {}, {}, {}
	for _, n in nodes do
		byId[n.id] = n
	end
	for _, n in nodes do
		local p = n.requires
		if n.id ~= rootId and p and byId[p] then
			kids[p] = kids[p] or {}
			table.insert(kids[p], n.id)
		end
	end
	local function count(id)
		local c = 1
		for _, k in kids[id] or {} do
			c += count(k)
		end
		size[id] = c
		return c
	end
	count(rootId)

	local function ordered(id)
		local list = table.clone(kids[id] or {})
		local s = stem(id)
		table.sort(list, function(a, b)
			local ca, cb = stem(a) == s, stem(b) == s
			if ca ~= cb then return ca end
			if size[a] ~= size[b] then return size[a] > size[b] end
			return a < b
		end)
		return list
	end

	local function candidates(id, childId, d, depth, index, count)
		if d == 0 then
			local base = wrap((firstDir or 3) + math.floor((index - 1) * 6 / count + 0.5))
			return { base, wrap(base + 1), wrap(base - 1), wrap(base + 2), wrap(base - 2), wrap(base + 3) }
		end
		if stem(childId) == stem(id) or (index == 1 and count == 1) then
			return { d, wrap(d + 1), wrap(d - 1), wrap(d + 2), wrap(d - 2) }
		end
		local side = (math.floor(depth / 2) + index) % 2 == 0 and 1 or -1
		return { wrap(d + side), wrap(d - side), wrap(d + 2 * side), wrap(d - 2 * side), d }
	end

	local cells, used, stack = {}, {}, {}
	local budget = 60000
	local greedy = false

	local function claim(id, q, r)
		local k = key(q, r)
		used[k] = id
		cells[id] = { q = q, r = r }
		stack[#stack + 1] = k
	end

	local function undo(mark)
		while #stack > mark do
			local k = table.remove(stack)
			local id = used[k]
			used[k] = nil
			if id then cells[id] = nil end
		end
	end

	local function nearestFree(q, r)
		for ring = 1, 64 do
			local cq, cr = q + DQ[5] * ring, r + DR[5] * ring
			for side = 1, 6 do
				for _ = 1, ring do
					if not used[key(cq, cr)] then return cq, cr end
					cq += DQ[side]
					cr += DR[side]
				end
			end
		end
		return q, r
	end

	local place

	local function placeKids(id, list, i, q, r, d, depth)
		if i > #list then return true end
		local childId = list[i]
		for _, cd in candidates(id, childId, d, depth, i, #list) do
			local nq, nr = q + DQ[cd], r + DR[cd]
			if not used[key(nq, nr)] then
				if greedy then
					claim(childId, nq, nr)
					place(childId, nq, nr, cd, depth + 1)
					return placeKids(id, list, i + 1, q, r, d, depth)
				end
				budget -= 1
				if budget < 0 then error("budget") end
				local mark = #stack
				claim(childId, nq, nr)
				if place(childId, nq, nr, cd, depth + 1) and placeKids(id, list, i + 1, q, r, d, depth) then
					return true
				end
				undo(mark)
			end
		end
		if not greedy then return false end
		local fq, fr = nearestFree(q, r)
		claim(childId, fq, fr)
		place(childId, fq, fr, d == 0 and 3 or d, depth + 1)
		return placeKids(id, list, i + 1, q, r, d, depth)
	end

	function place(id, q, r, d, depth)
		return placeKids(id, ordered(id), 1, q, r, d, depth)
	end

	claim(rootId, 0, 0)
	local ok, solved = pcall(place, rootId, 0, 0, 0, 0)
	if not (ok and solved) then
		undo(0)
		greedy = true
		claim(rootId, 0, 0)
		place(rootId, 0, 0, 0, 0)
	end
	return cells, greedy
end

return Layout
