local SITE = 12
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "trough", 900))
local M = K.MAT
local PTS = { { c.X - 330, c.Z - 200 }, { c.X - 120, c.Z - 180 }, { c.X + 60, c.Z - 60 }, { c.X + 80, c.Z + 120 }, { c.X - 60, c.Z + 250 }, { c.X - 300, c.Z + 260 } }
LAB.build(G, {
	K.path({ name = "trough", mode = "trough", pts = PTS, halfW = 40, depth = 18, floorMat = M.Grass, lipMat = M.Limestone }),
}, {}, { buffer = 24, feather = 80 })
task.wait(1)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local function top(x, z) local h = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1200, 0), rp) return h and h.Position.Y - 2 or 0 end
local ref = K.path({ name = "ref", mode = "trough", pts = PTS, halfW = 1, bank = 200, depth = 0 })
local bendL, bendR = top(c.X + 60 + 30, c.Z - 60 - 20), top(c.X + 60 - 30, c.Z - 60 + 20)
local nL = ref.near(c.X + 60 + 30, c.Z - 60 - 20)
local nR = ref.near(c.X + 60 - 30, c.Z - 60 + 20)
K.log(string.format("INFO trough bend at (60,-60): side n=%.0f h %.1f, side n=%.0f h %.1f (bank tilt: outer side of the bend higher)", nL or 0, bendL, nR or 0, bendR))
return table.concat(K.out, "\n")
