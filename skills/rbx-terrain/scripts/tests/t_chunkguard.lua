local c = LAB.site(14)
local BOX = LAB.box(14, "chunkguard", 900)
local CH = { { c.X - 450, c.X, c.Z - 450, c.Z }, { c.X, c.X + 450, c.Z - 450, c.Z }, { c.X - 450, c.X, c.Z, c.Z + 450 }, { c.X, c.X + 450, c.Z, c.Z + 450 } }
local M = K.MAT
return K.run(BOX, { chunks = CH, buffer = 24, feather = 80, chunkMargin = VARIANT == "m96" and 96 or 288, snapMargin = VARIANT == "snap96" and 96 or nil }, function(G)
	return {
		K.mound({ name = "steep corner hill", x = c.X + 10, z = c.Z - 10, r = 150, h = 64 }),
		K.bowl({ name = "steep bowl", x = c.X - 200, z = c.Z + 180, r = 110, depth = 34 }),
	}, {}
end)
