local root = RBX.find("game.__ROOT__")
local KIT_FONT = "rbxasset://fonts/families/GothamSSm.json"
local TILE_IMAGES = {
	["rbxassetid://131017184238132"] = "shell",
	["rbxassetid://95676388705283"] = "checker",
	["rbxassetid://84682738767744"] = "stripe",
}
local CLOSE_IMAGE = "rbxassetid://126722740435766"
local CORNER_OFFSETS = { [8] = true, [12] = true, [14] = true, [16] = true, [20] = true, [30] = true }
local issues = {}
local function flag(kind, inst, detail)
	issues[kind] = issues[kind] or { n = 0, ex = {} }
	local e = issues[kind]
	e.n += 1
	if #e.ex < 4 then
		table.insert(e.ex, inst:GetFullName():gsub("^StarterGui%.", "") .. (detail and (" " .. detail) or ""))
	end
end
local function hasOffset(u)
	return u.X.Offset ~= 0 or u.Y.Offset ~= 0
end
local function childOf(inst, cls, pred)
	for _, c in inst:GetChildren() do
		if c:IsA(cls) and (not pred or pred(c)) then
			return c
		end
	end
end
local function isTiles(c)
	return c:IsA("ImageLabel") and (c.Name == "Tiles" or (TILE_IMAGES[c.Image] ~= nil and c.ScaleType == Enum.ScaleType.Tile))
end
local function radius(inst)
	local c = childOf(inst, "UICorner")
	return c and c.CornerRadius
end
local function isPanelRoot(d)
	return d.Parent and d.Parent.Name == "Frames" and d.Parent:IsA("ScreenGui") and d:IsA("Frame")
end
local total = 0
local scan = { root }
for _, d in root:GetDescendants() do
	table.insert(scan, d)
end
for _, d in scan do
	if d:IsA("LuaSourceContainer") then
		continue
	end
	total += 1
	if d:IsA("GuiObject") then
		if hasOffset(d.Size) then
			flag("offset_size", d, tostring(d.Size))
		end
		if hasOffset(d.Position) then
			flag("offset_position", d, tostring(d.Position))
		end
		local isText = d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")
		if isText and d.Text ~= "" then
			if d.FontFace.Family ~= KIT_FONT then
				flag("wrong_font", d, (d.FontFace.Family:gsub("rbxasset://fonts/families/", "")))
			end
			if d.FontFace.Weight ~= Enum.FontWeight.Bold then
				flag("not_bold", d)
			end
			if d.Text ~= "" and not d.TextScaled then
				flag("text_not_scaled", d)
			end
			if d.Text ~= "" and d.TextTransparency < 1 and not childOf(d, "UIStroke", function(s)
				return s.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual
			end) then
				flag("text_no_outline", d)
			end
			if d.BackgroundTransparency >= 1 and childOf(d, "UIGradient", function(g)
				return g.Color.Keypoints[1].Value == g.Color.Keypoints[#g.Color.Keypoints].Value
			end) then
				flag("gradient_on_text", d)
			end
		end
		local tiles = childOf(d, "ImageLabel", isTiles)
		local opaque = d.BackgroundTransparency < 0.5 and not d:IsA("ScrollingFrame") and not d:IsA("ImageLabel") and not d:IsA("ViewportFrame")
		if opaque and not (isText and d:IsA("TextLabel")) then
			local isStamp = childOf(d, "UICorner", function(c)
				return c.CornerRadius == UDim.new(1, 0)
			end) and d.BackgroundColor3 ~= Color3.new(1, 1, 1)
			if not childOf(d, "UICorner") then
				flag("container_no_corner", d)
			end
			if not childOf(d, "UIStroke", function(s)
				return s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border
			end) then
				flag("container_no_border", d)
			end
			if not isStamp and not childOf(d, "UIGradient") and not tiles then
				flag("container_no_skin", d, "needs Tiles or a UIGradient")
			end
		end
		if isTiles(d) then
			if not TILE_IMAGES[d.Image] then
				flag("tiles_unknown_image", d, d.Image)
			end
			if d.ScaleType ~= Enum.ScaleType.Tile then
				flag("tiles_not_tile", d)
			end
			local pad = childOf(d.Parent, "UIPadding")
			local full = UDim2.new(1, 0, 1, 0)
			if pad then
				local w = 1 - pad.PaddingLeft.Scale - pad.PaddingRight.Scale
				local h = 1 - pad.PaddingTop.Scale - pad.PaddingBottom.Scale
				full = UDim2.new(1 / w, 0, 1 / h, 0)
			end
			if math.abs(d.Size.X.Scale - full.X.Scale) > 0.01 or math.abs(d.Size.Y.Scale - full.Y.Scale) > 0.01 then
				flag("tiles_not_full", d)
			end
			local pr, tr = radius(d.Parent), radius(d)
			if pr and tr ~= pr then
				flag("tiles_corner_mismatch", d, tostring(tr) .. " vs parent " .. tostring(pr))
			end
			for _, s in d.Parent:GetChildren() do
				if s ~= d and s:IsA("GuiObject") and s.ZIndex <= d.ZIndex then
					flag("content_under_tiles", s, "z" .. s.ZIndex .. " <= tiles z" .. d.ZIndex)
				end
			end
		end
		if d.Name == "CloseButton" then
			local img = childOf(d, "ImageLabel", function(i)
				return i.Image == CLOSE_IMAGE
			end) or childOf(d, "ImageButton", function(i)
				return i.Image == CLOSE_IMAGE
			end)
			if not img then
				flag("close_not_image", d, "use SKY.close")
			end
			if not childOf(d, "UIAspectRatioConstraint") then
				flag("close_no_aspect", d)
			end
		end
		if isPanelRoot(d) then
			local st = childOf(d, "ImageLabel", isTiles)
			if not st or st.Image ~= "rbxassetid://131017184238132" then
				flag("panel_no_shell_tiles", d)
			end
			if not childOf(d, "UIShadow") then
				flag("panel_no_shadow", d)
			end
			if d.Visible then
				flag("panel_visible_at_rest", d)
			end
		end
	elseif d:IsA("UIStroke") then
		if d.Thickness > 0 and d.Thickness < 1 and d.StrokeSizingMode ~= Enum.StrokeSizingMode.ScaledSize then
			flag("subpixel_stroke", d, string.format("%.3f", d.Thickness))
		end
		if d.StrokeSizingMode == Enum.StrokeSizingMode.ScaledSize and d.Thickness > 0.5 then
			flag("scaled_stroke_slab", d, tostring(d.Thickness))
		end
		if d.Thickness > 5 then
			flag("fat_stroke", d, tostring(d.Thickness))
		end
	elseif d:IsA("UICorner") then
		local r = d.CornerRadius
		if r.Scale == 0 and not CORNER_OFFSETS[r.Offset] and not (d.Parent and isTiles(d.Parent)) then
			flag("corner_off_ladder", d, tostring(r.Offset))
		end
	elseif d:IsA("UIPadding") then
		for _, k in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
			if d[k].Offset ~= 0 then
				flag("offset_padding", d, k)
				break
			end
		end
	elseif d:IsA("UIListLayout") or d:IsA("UIGridLayout") then
		if d:IsA("UIListLayout") and d.Padding.Offset ~= 0 then
			flag("offset_list_padding", d)
		end
		if d.SortOrder ~= Enum.SortOrder.LayoutOrder then
			flag("sort_not_layoutorder", d)
		end
	elseif d:IsA("UIScale") and d.Parent and d.Parent:IsA("ScreenGui") then
		flag("root_uiscale", d)
	end
end
local out = { string.format("%s: %d instances", root:GetFullName(), total) }
local n = 0
for kind, e in issues do
	n += e.n
	table.insert(out, string.format("  %-24s %4d  e.g. %s", kind, e.n, table.concat(e.ex, " | ")))
end
table.sort(out)
table.insert(out, 1, "ISSUES: " .. n)
return table.concat(out, "\n")
