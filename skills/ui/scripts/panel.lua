local NAME = "NewPanel"
local TITLE = "NEW PANEL"
local SUB = nil
local SIZE = UDim2.new(0.5, 0, 0.62, 0)
local AR = 1.3
local ROW_AR = 7
local COLS = {
	{ "Label", "ITEM", 0.04, 0.5, Enum.TextXAlignment.Left, 0 },
	{ "Value", "0", 0.6, 0.18, Enum.TextXAlignment.Center, 0.5 },
}
local ACTION = { name = "Action", text = "CLAIM", kind = "action" }

local Frames = RBX.find("game.StarterGui.Frames")
local root = Frames:FindFirstChild(NAME)
if root then
	for _, c in root:GetChildren() do
		c:Destroy()
	end
else
	root = SKY.frame(Frames, { Name = NAME })
end
SKY.set(root, { Size = SIZE, Visible = false })
SKY.shell(root, AR)
SKY.header(root, TITLE, SUB, 0.94 * AR / 0.12)
SKY.inset(root, {
	Name = "Body",
	Size = UDim2.new(0.94, 0, 0.79, 0),
	Position = UDim2.new(0.5, 0, 0.18, 0),
	AnchorPoint = Vector2.new(0.5, 0),
}, 0.94 * AR / 0.79)
local list = SKY.list(root, {
	Name = "List",
	Size = UDim2.new(0.94, 0, 0.77, 0),
	Position = UDim2.new(0.5, 0, 0.19, 0),
	AnchorPoint = Vector2.new(0.5, 0),
}, 0.015, false)
local row = SKY.row(list, { Name = "Template", Visible = false }, ROW_AR)
for _, c in COLS do
	SKY.label(row, {
		Name = c[1],
		Text = c[2],
		Size = UDim2.new(c[4], 0, 0.55, 0),
		Position = UDim2.new(c[3], 0, 0.5, 0),
		AnchorPoint = Vector2.new(c[6], 0.5),
		TextXAlignment = c[5],
	})
end
if ACTION then
	SKY.button(row, {
		Name = ACTION.name,
		Size = UDim2.new(0.22, 0, 0.62, 0),
		Position = UDim2.new(0.97, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
	}, ACTION.text, ACTION.kind, { shadow = "drop" })
end
return string.format("%s built: %d instances", root:GetFullName(), #root:GetDescendants())
