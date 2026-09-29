-- rbx-mobile/scripts/mobile_audit.lua: structural mobile checks on a GUI subtree, Edit datamodel, read-only.
-- usage: sed "s|__ROOT__|StarterGui.HUD|" mobile_audit.lua | $R lua -
-- Zones are estimated from Scale positions on a 1920x1080 reference (AbsoluteSize is 0 under StarterGui in Edit).
local root = RBX.find("game.__ROOT__")
local W, H = 1920, 1080
local PHONE = 0.46
local issues = {}
local function flag(kind, inst, detail)
	issues[kind] = issues[kind] or { n = 0, ex = {} }
	local e = issues[kind]
	e.n += 1
	if #e.ex < 4 then table.insert(e.ex, (inst:GetFullName():gsub("^StarterGui%.", "")) .. (detail and (" " .. detail) or "")) end
end
-- absolute rect from Scale chain (ignores UIListLayout placement; good enough for zone tests)
local function rect(g)
	local x, y, w, h = 0, 0, W, H
	local chain = {}
	local p = g
	while p and p:IsA("GuiObject") do table.insert(chain, 1, p) p = p.Parent end
	for _, o in ipairs(chain) do
		local ow, oh = o.Size.X.Scale * w + o.Size.X.Offset, o.Size.Y.Scale * h + o.Size.Y.Offset
		local ox, oy = x + o.Position.X.Scale * w + o.Position.X.Offset - o.AnchorPoint.X * ow, y + o.Position.Y.Scale * h + o.Position.Y.Offset - o.AnchorPoint.Y * oh
		x, y, w, h = ox, oy, ow, oh
	end
	return x, y, w, h
end
local function inZone(x, y, w, h)
	local cx, cy = x + w / 2, y + h / 2
	if cy > H * 0.62 and cx < W * 0.24 then return "thumbstick" end
	if cy > H * 0.62 and cx > W * 0.80 then return "jump" end
	return nil
end
local total = 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("LuaSourceContainer") then continue end
	total += 1
	if d:IsA("GuiObject") and d.Visible then
		local x, y, w, h = rect(d)
		local z = inZone(x, y, w, h)
		if z and d:IsA("GuiButton") then flag("!button_in_" .. z .. "_zone", d) end
		if z and not d:IsA("GuiButton") and d.BackgroundTransparency < 0.9 and w * h > 40 * 40 then flag("opaque_in_" .. z .. "_zone", d) end
		if d:IsA("GuiButton") and (w * PHONE < 44 or h * PHONE < 44) and w > 0 and h > 0 then flag("!hit_area_under_44pt_on_phone", d, string.format("%dx%d", w * PHONE, h * PHONE)) end
		if d.Size.X.Offset ~= 0 or d.Size.Y.Offset ~= 0 or d.Position.X.Offset ~= 0 or d.Position.Y.Offset ~= 0 then flag("offset_sizing", d) end
		if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" and not d.TextScaled and d.TextSize * PHONE < 12 then flag("!text_under_12_on_phone", d, tostring(d.TextSize)) end
	elseif d:IsA("UIAspectRatioConstraint") then
		local p = d.Parent
		if p and p:IsA("GuiObject") and p.Parent and p.Parent:IsA("GuiObject") then
			-- nested one level down and the parent is a wrapper of identical size: usually the wrong frame
			if p.Size.X.Scale == 1 and p.Size.Y.Scale == 1 then flag("aspect_on_full_size_child", d) end
		end
	elseif d:IsA("UIScale") then
		local n, p = 0, d.Parent
		while p do if p:IsA("GuiObject") and p:FindFirstChildOfClass("UIScale") then n += 1 end p = p.Parent end
		if n >= 2 then flag("uiscale_stack_3_deep", d) end
	elseif d:IsA("UIStroke") and d.Thickness > 0 and d.Thickness < 1 and d.Transparency < 0.99 then
		flag("subpixel_stroke", d, string.format("%.3f", d.Thickness))
	end
end
local out = { string.format("%s: %d instances (zones estimated on 1920x1080, phone factor %.2f)", root:GetFullName(), total, PHONE) }
local n = 0
local keys = {}
for k in pairs(issues) do table.insert(keys, k) end
table.sort(keys)
for _, k in ipairs(keys) do local e = issues[k] n += e.n table.insert(out, string.format("  %-32s %4d  e.g. %s", k, e.n, table.concat(e.ex, " | "))) end
table.insert(out, 1, "ISSUES: " .. n)
return table.concat(out, "\n")
