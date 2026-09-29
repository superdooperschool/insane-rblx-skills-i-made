local SITE = 3
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "pad"))
local ok, err = pcall(K.table, { x = c.X, z = c.Z, r = 60, h = 10, w = 40 })
K.log((ok and "FAIL" or "PASS") .. " table banned: " .. (ok and "K.table built without allowBanned" or tostring(err):match("[^:]*$")))
LAB.build(G, {
	K.mound({ name = "host", x = c.X, z = c.Z, r = 220, h = 36 }),
	K.pad({ name = "pad", x = c.X + 90, z = c.Z, r = 40, blend = 24 }),
})
return table.concat(K.out, "\n")
