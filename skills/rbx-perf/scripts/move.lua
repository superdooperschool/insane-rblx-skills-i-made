-- Server: drive player 1 along A -> B. MODE "move" (SPEED studs/s back and forth) or "stand" (midpoint).
local MODE, DURATION, SPEED = "__MODE__", __DUR__, __SPEED__
local A, B = Vector3.new(__A__), Vector3.new(__B__)
local RunService = game:GetService("RunService")
local plr = game.Players:GetPlayers()[1]
local root = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
if not root then return "no root" end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { plr.Character }
local function ground(p)
	local hit = workspace:Raycast(p, Vector3.new(0, -800, 0), params)
	return hit and hit.Position.Y + root.Size.Y / 2 or p.Y
end
workspace:SetAttribute("BenchRunning", true)
task.spawn(function()
	local t0, x, dir = os.clock(), 0, 1
	local len, unit = (B - A).Magnitude, (B - A).Unit
	while os.clock() - t0 < DURATION and root.Parent do
		local dt = RunService.Heartbeat:Wait()
		if MODE == "move" then
			x += dir * SPEED * dt
			if x > len then x, dir = len, -1 elseif x < 0 then x, dir = 0, 1 end
		else
			x = len * 0.5
		end
		local p = A + unit * x
		root.CFrame = CFrame.new(p.X, ground(p), p.Z)
		root.AssemblyLinearVelocity = MODE == "move" and unit * dir * SPEED or Vector3.zero
	end
	workspace:SetAttribute("BenchRunning", false)
end)
return "driving " .. MODE
