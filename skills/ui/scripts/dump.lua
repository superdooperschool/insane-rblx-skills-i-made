local root = RBX.find("game.__ROOT__")
local out = {}
local function fmtv(v)
  local t = typeof(v)
  if t == "Color3" then return string.format("#%02X%02X%02X", v.R*255+0.5, v.G*255+0.5, v.B*255+0.5)
  elseif t == "UDim2" then return string.format("{%g,%d},{%g,%d}", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
  elseif t == "UDim" then return string.format("%g,%d", v.Scale, v.Offset)
  elseif t == "Vector2" then return string.format("%g,%g", v.X, v.Y)
  elseif t == "EnumItem" then return v.Name
  elseif t == "Font" then return v.Family:gsub("rbxasset://fonts/families/","") .. "/" .. v.Weight.Name .. "/" .. v.Style.Name
  elseif t == "Rect" then return string.format("%g,%g,%g,%g", v.Min.X, v.Min.Y, v.Max.X, v.Max.Y)
  else return tostring(v) end
end
local props = {
  Frame = {"Size","Position","AnchorPoint","BackgroundColor3","BackgroundTransparency","ZIndex","Visible","ClipsDescendants","LayoutOrder"},
  ScrollingFrame = {"Size","Position","AnchorPoint","BackgroundColor3","BackgroundTransparency","ScrollBarThickness","CanvasSize","AutomaticCanvasSize","ScrollBarImageColor3","ScrollingDirection"},
  TextLabel = {"Size","Position","AnchorPoint","BackgroundColor3","BackgroundTransparency","FontFace","TextSize","TextScaled","TextColor3","TextStrokeTransparency","TextXAlignment","TextYAlignment","Text","RichText","TextWrapped","AutomaticSize","ZIndex","LayoutOrder"},
  TextButton = {"Size","Position","AnchorPoint","BackgroundColor3","BackgroundTransparency","FontFace","TextSize","TextScaled","TextColor3","Text","AutoButtonColor","ZIndex","LayoutOrder"},
  TextBox = {"Size","Position","AnchorPoint","BackgroundColor3","FontFace","TextSize","TextColor3","PlaceholderText","PlaceholderColor3","ClearTextOnFocus"},
  ImageLabel = {"Size","Position","AnchorPoint","BackgroundTransparency","Image","ImageColor3","ImageTransparency","ScaleType","TileSize","ZIndex","LayoutOrder"},
  ImageButton = {"Size","Position","AnchorPoint","BackgroundTransparency","BackgroundColor3","Image","ImageColor3","ScaleType","AutoButtonColor","ZIndex","LayoutOrder"},
  UICorner = {"CornerRadius"},
  UIStroke = {"Thickness","Color","Transparency","ApplyStrokeMode","StrokeSizingMode"},
  UIShadow = {"BlurRadius","Color","Transparency","Offset"},
  UIPadding = {"PaddingTop","PaddingBottom","PaddingLeft","PaddingRight"},
  UIListLayout = {"FillDirection","Padding","HorizontalAlignment","VerticalAlignment","SortOrder","Wraps"},
  UIGridLayout = {"CellSize","CellPadding","FillDirection","HorizontalAlignment","SortOrder"},
  UIGradient = {"Rotation","Transparency"},
  UIAspectRatioConstraint = {"AspectRatio","AspectType","DominantAxis"},
  UIScale = {"Scale"},
  UISizeConstraint = {"MinSize","MaxSize"},
  UITextSizeConstraint = {"MinTextSize","MaxTextSize"},
  ScreenGui = {"IgnoreGuiInset","ResetOnSpawn","ZIndexBehavior","DisplayOrder","Enabled","ScreenInsets"},
  CanvasGroup = {"Size","Position","AnchorPoint","GroupTransparency","BackgroundTransparency","BackgroundColor3"},
  ViewportFrame = {"Size","Position","BackgroundTransparency"},
}
local count = 0
local function walk(inst, depth)
  count += 1
  if count > 1200 then return end
  local list = props[inst.ClassName]
  local parts = {}
  if list then
    for _, p in ipairs(list) do
      local ok, v = pcall(function() return inst[p] end)
      if ok then
        if p == "Text" and #tostring(v) > 40 then v = string.sub(tostring(v),1,40).."…" end
        table.insert(parts, p .. "=" .. fmtv(v))
      end
    end
  end
  if inst:IsA("UIGradient") then
    local ks = {}
    for _, k in ipairs(inst.Color.Keypoints) do table.insert(ks, fmtv(k.Value)) end
    table.insert(parts, "Color=" .. table.concat(ks, ">"))
  end
  local attrs = inst:GetAttributes()
  local an = {}
  for k, v in pairs(attrs) do table.insert(an, k .. ":" .. fmtv(v)) end
  if #an > 0 then table.insert(parts, "@{" .. table.concat(an, ",") .. "}") end
  table.insert(out, string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "] " .. table.concat(parts, " "))
  if inst:IsA("LuaSourceContainer") then return end
  for _, c in ipairs(inst:GetChildren()) do walk(c, depth + 1) end
end
walk(root, 0)
return table.concat(out, "\n")
