local SITE = 5
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "hillfield"))
local P = { a1 = 16, l1 = 600, a2 = 8, l2 = 240, a3 = 6, l3 = 110, grid = 150, h1 = 24, h2 = 40, union = 1, warp = 60, climb = 22 }
for k, v in string.gmatch(VARIANT or "", "(%w+)=([%d%.%-]+)") do P[k] = tonumber(v) end
local field = K.hillField({ rect = { c.X - 300, c.X + 300, c.Z - 300, c.Z + 300 }, grid = P.grid, h = { P.h1, P.h2 }, seed = 77, taperFrom = 24, taper = 120, union = P.union == 1 and "max" or "sum" })
K.log("field hills: " .. #field.hills)
local feats = { K.rolling({ seed = 23, amp1 = P.a1, len1 = P.l1, amp2 = P.a2, len2 = P.l2, amp3 = P.a3, len3 = P.l3, warp = P.warp, taperFrom = 24, taper = 120 }), field }
LAB.build(G, feats, { climb = P.climb > 0 and P.climb or false })
return table.concat(K.out, "\n")
