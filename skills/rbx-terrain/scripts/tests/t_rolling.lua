local SITE = 4
LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "rolling"))
LAB.build(G, { K.rolling({}) })
return table.concat(K.out, "\n")
