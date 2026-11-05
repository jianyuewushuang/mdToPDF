-- The larger gilt scattered in the gaps the foliage leaves (fill.lua): the
-- reference's dotted crosses, rosettes and lozenges, and a five-pointed
-- star, a crescent and a trefoil. Each kind names the sparkle it paints
-- (ornament.lua's O.sparkles); `classic` marks the reference's own, which
-- keep their original random stream.

local Orn = require("flora.ornaments")
local O = require("flora.ornament")

local function kind(name, label, sparkle, classic)
  Orn.register({
    name = name, slot = "gilt", label = label, sparkle = sparkle, classic = classic,
    draw = function(pt, _, b)
      local s = math.min(b[3] - b[1], b[4] - b[2])
      O.sparkles(pt, { { (b[1] + b[3]) / 2, (b[2] + b[4]) / 2, s * 0.3, sparkle } })
    end,
  })
end

kind("gilt_cross", "Dotted cross", "cross", true)
kind("gilt_rosette", "Four-dot rosette", "rosette", true)
kind("gilt_dotted", "Dotted sparkle", "dotted", true)
kind("gilt_lozenge", "Lozenge", "lozenge", true)
kind("gilt_star", "Five-pointed star", "star5")
kind("gilt_crescent", "Crescent", "crescent")
kind("gilt_trefoil", "Trefoil", "trefoil")
