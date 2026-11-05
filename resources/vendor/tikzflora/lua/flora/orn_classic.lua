-- The original ornaments, as registry kinds: the night-sky star cartouche,
-- the compass at the running head and the knot pendant (ornament.lua).

local Orn = require("flora.ornaments")
local O = require("flora.ornament")

Orn.register({
  name = "night", slot = "cartouche", label = "Night sky",
  draw = function(pt, rng, b)
    O.panel(pt, rng, b[1], b[2], b[3] - b[1], b[4] - b[2])
  end,
})

-- The compass's crosshair reaches 1.5 times its radius.
Orn.register({
  name = "compass", slot = "header", label = "Compass star", reach = 0.26,
  draw = function(pt, _, b)
    O.compass(pt, (b[1] + b[3]) / 2, (b[2] + b[4]) / 2, (b[3] - b[1]) / 2, { hair = 1.5 })
  end,
})

-- The cord runs up o.cord pt from the pendant's top.
Orn.register({
  name = "knot", slot = "pendant", label = "Knot pendant",
  draw = function(pt, rng, b, o)
    O.pendant(pt, rng, (b[1] + b[3]) / 2, (b[2] + b[4]) / 2, b[3] - b[1], b[4] - b[2], o.cord or 0)
  end,
})
