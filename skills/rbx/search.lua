local function blankComments(s)
	local out = {}
	local i, n = 1, #s
	while i <= n do
		local c = string.sub(s, i, i)
		if c == "-" and string.sub(s, i + 1, i + 1) == "-" then
			local eq = string.match(s, "^%[(=*)%[", i + 2)
			local stop
			if eq then
				local close = "]" .. eq .. "]"
				local e = string.find(s, close, i + 2, true)
				stop = e and (e + #close - 1) or n
			else
				local e = string.find(s, "\n", i, true)
				stop = e and (e - 1) or n
			end
			for k = i, stop do
				out[#out + 1] = (string.sub(s, k, k) == "\n") and "\n" or " "
			end
			i = stop + 1
		elseif c == '"' or c == "'" then
			local q = c
			out[#out + 1] = c
			i = i + 1
			while i <= n do
				local ch = string.sub(s, i, i)
				out[#out + 1] = ch
				i = i + 1
				if ch == "\\" then
					if i <= n then
						out[#out + 1] = string.sub(s, i, i)
						i = i + 1
					end
				elseif ch == q or ch == "\n" then
					break
				end
			end
		elseif c == "[" then
			local eq = string.match(s, "^%[(=*)%[", i)
			if eq then
				local close = "]" .. eq .. "]"
				local e = string.find(s, close, i, true)
				local stop = e and (e + #close - 1) or n
				out[#out + 1] = string.sub(s, i, stop)
				i = stop + 1
			else
				out[#out + 1] = c
				i = i + 1
			end
		else
			out[#out + 1] = c
			i = i + 1
		end
	end
	return table.concat(out)
end

local function lineIndex(s)
	local starts = { 1 }
	local i = 1
	while true do
		local e = string.find(s, "\n", i, true)
		if not e then break end
		starts[#starts + 1] = e + 1
		i = e + 1
	end
	return starts
end

local function lineOf(starts, pos)
	local lo, hi = 1, #starts
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if starts[mid] <= pos then lo = mid else hi = mid - 1 end
	end
	return lo
end

local function lineText(s, starts, ln)
	local a = starts[ln]
	local b = starts[ln + 1]
	local t = b and string.sub(s, a, b - 2) or string.sub(s, a)
	return (string.gsub(string.gsub(t, "^%s+", ""), "%s+$", ""))
end

local function isWordChar(ch)
	return ch ~= "" and string.match(ch, "[%w_]") ~= nil
end

local function collect(root)
	local out = {}
	if root:IsA("LuaSourceContainer") then out[#out + 1] = root end
	local ok, kids = pcall(function() return root:GetDescendants() end)
	if not ok then return out end
	for _, d in ipairs(kids) do
		if d:IsA("LuaSourceContainer") then out[#out + 1] = d end
	end
	return out
end

local function run(cfg)
	local term = cfg.term
	local needle = cfg.ignoreCase and string.lower(term) or term
	local roots = {}
	if cfg.path and cfg.path ~= "" then
		local n = game
		for seg in string.gmatch(cfg.path, "[^%.]+") do
			if seg ~= "game" then
				local nx = n:FindFirstChild(seg)
				if not nx and n == game then
					local sok, sv = pcall(function() return game:GetService(seg) end)
					if sok then nx = sv end
				end
				if not nx then return { error = "no such path: " .. cfg.path } end
				n = nx
			end
		end
		roots[1] = n
	else
		roots = { game }
	end

	local hits = {}
	local scanned, skipped, truncated = 0, 0, false
	local limit = cfg.limit or 100

	for _, root in ipairs(roots) do
		for _, inst in ipairs(collect(root)) do
			if truncated then break end
			local sok, raw = pcall(function() return inst.Source end)
			if sok and raw and #raw > 0 then
				local probe = cfg.ignoreCase and string.lower(raw) or raw
				if string.find(probe, needle, 1, true) then
					scanned = scanned + 1
					local clean = cfg.includeComments and raw or blankComments(raw)
					local hay = cfg.ignoreCase and string.lower(clean) or clean
					local starts = lineIndex(clean)
					local from = 1
					local seenLine = {}
					while true do
						local a, b = string.find(hay, needle, from, true)
						if not a then break end
						local okWord = true
						if cfg.word then
							local before = a > 1 and string.sub(hay, a - 1, a - 1) or ""
							local after = string.sub(hay, b + 1, b + 1)
							okWord = not isWordChar(before) and not isWordChar(after)
						end
						if okWord then
							local ln = lineOf(starts, a)
							if not seenLine[ln] then
								seenLine[ln] = true
								hits[#hits + 1] = inst:GetFullName() .. ":" .. ln .. ": " .. lineText(clean, starts, ln)
								if #hits >= limit then truncated = true break end
							end
						end
						from = b + 1
					end
				else
					skipped = skipped + 1
				end
			end
		end
	end

	return {
		hits = hits,
		matchedScripts = scanned,
		skippedScripts = skipped,
		truncated = truncated,
		commentsIgnored = not cfg.includeComments,
	}
end

local function outline(cfg)
	local n = game
	for seg in string.gmatch(cfg.path, "[^%.]+") do
		if seg ~= "game" then
			local nx = n:FindFirstChild(seg)
			if not nx and n == game then
				local sok, sv = pcall(function() return game:GetService(seg) end)
				if sok then nx = sv end
			end
			if not nx then return { error = "no such path: " .. cfg.path } end
			n = nx
		end
	end
	if not n:IsA("LuaSourceContainer") then return { error = "not a script: " .. cfg.path } end
	local clean = blankComments(n.Source)
	local starts = lineIndex(clean)
	local out = {}
	for ln = 1, #starts do
		local t = lineText(clean, starts, ln)
		if t ~= "" then
			local sig = string.match(t, "^local%s+function%s+([%w_%.:]+)")
				or string.match(t, "^function%s+([%w_%.:]+)")
				or string.match(t, "^local%s+([%w_]+)%s*=%s*function")
				or string.match(t, "^([%w_%.:]+)%s*=%s*function")
			if sig then out[#out + 1] = ln .. ": " .. t end
		end
	end
	return { path = n:GetFullName(), lines = #starts, defs = out }
end

if CFG.mode == "outline" then return outline(CFG) end
return run(CFG)
