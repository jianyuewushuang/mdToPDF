-- Round gilt ornaments: marks for the running head, pendants for the foot
-- and the large centrepieces that crest a title.

local Orn = require("flora.ornaments")
local K = require("flora.orn_kit")
local G = require("flora.geom")
local Paint = require("flora.paint")

local pal = Paint.palette
local pi = math.pi

-- An n-petalled rosette of radius r: pointed petals, lit and shaded,
-- round a copper heart.
local function rosette(pt, x, y, r, n, rot)
  local lit, shade = {}, {}
  for k = 0, n - 1 do
    local a = (rot or pi / 2) + k * 2 * pi / n
    local tip = G.polar({ x, y }, a, r)
    local l = G.polar({ x, y }, a + pi / n * 0.9, r * 0.42)
    local rr = G.polar({ x, y }, a - pi / n * 0.9, r * 0.42)
    lit[#lit + 1] = G.smooth({ { x, y }, l, tip }, true, 0.4)
    shade[#shade + 1] = G.smooth({ { x, y }, tip, rr }, true, 0.4)
  end
  K.gilt(pt, lit, shade)
  pt:fill(K.dot(x, y, r * 0.22), pal.copper, 0.95)
  pt:fill(K.dot(x - r * 0.04, y + r * 0.04, r * 0.1), pal.cream, 0.9)
end

-- A four-lobed outline of radius r, drawn as a gilt line.
local function quatrefoil(x, y, r, rot)
  local pts = {}
  for k = 0, 63 do
    local a = k * 2 * pi / 64
    local rr = r * (0.72 + 0.28 * math.abs(math.cos(2 * (a - (rot or 0)))) ^ 0.6)
    pts[#pts + 1] = G.polar({ x, y }, a, rr)
  end
  return G.smooth(pts, true)
end

-- A beaded cord running `len` up from (x, y).
local function cord(pt, x, y, len, r)
  if not len or len < 4 then return end
  local beads = {}
  for d = r * 2, len, r * 2.6 do beads[#beads + 1] = K.dot(x, y + d, r) end
  pt:fill(beads, pal.gold, 0.85, { many = true })
end

-- Running-head marks ---------------------------------------------------------

Orn.register({
  name = "rosette", slot = "header", label = "Rosette",
  draw = function(pt, rng, b)
    local x, y, _, _, s = K.measure(b)
    rosette(pt, x, y, s * 0.5, rng:weighted({ [6] = 1, [8] = 2 }))
  end,
})

Orn.register({
  name = "sunburst", slot = "header", label = "Sunburst", reach = 0.2,
  draw = function(pt, _, b)
    local x, y, _, _, s = K.measure(b)
    local lit, shade = K.rays(x, y, s * 0.17, s * 0.5, 16)
    K.gilt(pt, lit, shade)
    pt:stroke({ G.polyline({ { x - s * 0.7, y }, { x + s * 0.7, y } }) }, pal.gold, 0.2, 0.7, { many = true })
    pt:fill(K.dot(x, y, s * 0.17), pal.gold, 0.95)
    pt:fill(K.dot(x, y, s * 0.08), pal.cream, 0.95)
  end,
})

Orn.register({
  name = "quatrefoil", slot = "header", label = "Quatrefoil",
  draw = function(pt, _, b)
    local x, y, _, _, s = K.measure(b)
    pt:stroke({ quatrefoil(x, y, s * 0.48, pi / 4), quatrefoil(x, y, s * 0.36, pi / 4) }, pal.gold, 0.35, 0.95, { many = true })
    local lit, shade = K.rays(x, y, s * 0.04, s * 0.26, 4, { short = 1, width = 0.4, rot = 0 })
    K.gilt(pt, lit, shade)
    pt:fill(K.ring(x, y, s * 0.42, 4, s * 0.035, pi / 4), pal.gold, 0.9, { many = true })
  end,
})

-- Pendants ------------------------------------------------------------------

Orn.register({
  name = "medallion", slot = "pendant", label = "Rosette medallion",
  draw = function(pt, rng, b, o)
    local x, y, w, h = K.measure(b)
    local r = math.min(w, h * 0.78) * 0.48
    local cy = b[4] - r - 0.5
    cord(pt, x, b[4], o.cord, 0.45)
    pt:stroke({ K.dot(x, cy, r), K.dot(x, cy, r * 0.84) }, pal.gold, 0.32, 0.9, { many = true })
    rosette(pt, x, cy, r * 0.62, 8, rng:range(0, pi / 8))
    -- A drop below.
    pt:fill(G.smooth(K.lozenge(x, cy - r - (h - 2 * r) * 0.35, math.max(1, (h - 2 * r) * 0.55), -pi / 2), true), pal.gold, 0.9)
  end,
})

-- A wheel of twelve: twelve spokes and beads round a small sun.
local function zodiac(pt, x, y, r, rng)
  pt:stroke({ K.dot(x, y, r), K.dot(x, y, r * 0.82), K.dot(x, y, r * 0.4) }, pal.gold, math.max(0.3, r * 0.03), 0.9, { many = true })
  local spokes = {}
  for k = 0, 11 do
    local a = k * pi / 6 + pi / 12
    spokes[#spokes + 1] = G.polyline({ G.polar({ x, y }, a, r * 0.4), G.polar({ x, y }, a, r * 0.82) })
  end
  pt:stroke(spokes, pal.gold, math.max(0.2, r * 0.018), 0.85, { many = true })
  -- In each house, a sign: a dot, a pair, a crescent or a small star, in turn.
  local signs, stars = {}, {}
  for k = 0, 11 do
    local p = G.polar({ x, y }, k * pi / 6 + pi / 2, r * 0.61)
    local m = (k + (rng and rng:int(0, 3) or 0)) % 4
    if m == 0 then signs[#signs + 1] = K.dot(p[1], p[2], r * 0.06)
    elseif m == 1 then
      for d = -1, 1, 2 do
        local q = G.polar(p, k * pi / 6, d * r * 0.06)
        signs[#signs + 1] = K.dot(q[1], q[2], r * 0.035)
      end
    elseif m == 2 then signs[#signs + 1] = G.smooth(K.crescent(p[1], p[2], r * 0.075, 0.6, k * pi / 6), true)
    else stars[#stars + 1] = G.polyline(K.star(p[1], p[2], r * 0.09, r * 0.035, 5), true) end
  end
  pt:fill(signs, pal.gold, 0.9, { many = true })
  pt:fill(stars, pal.copper, 0.9, { many = true })
  local lit, shade = K.rays(x, y, r * 0.17, r * 0.36, 12)
  K.gilt(pt, lit, shade)
  pt:fill(K.dot(x, y, r * 0.17), pal.gold, 0.95)
  pt:fill(K.ring(x, y, r * 0.91, 36, math.max(0.25, r * 0.022)), pal.gold, 0.85, { many = true })
end

Orn.register({
  name = "zodiac_pendant", slot = "pendant", label = "Zodiac pendant",
  draw = function(pt, rng, b, o)
    local x, _, w, h = K.measure(b)
    local r = math.min(w, h) * 0.48
    cord(pt, x, b[4], o.cord, 0.45)
    zodiac(pt, x, b[4] - r - 0.5, r, rng)
  end,
})

-- Crests ---------------------------------------------------------------------

Orn.register({
  name = "sun_crest", slot = "crest", label = "Sun crest",
  draw = function(pt, rng, b)
    local x, y, _, _, s = K.measure(b)
    local R = s * 0.5
    local lit, shade = K.rays(x, y, R * 0.36, R, 32, { flames = true, rot = rng:range(0, pi / 16) })
    K.gilt(pt, lit, shade)
    pt:fill(K.dot(x, y, R * 0.36), pal.gold, 0.95)
    pt:fill(K.dot(x - R * 0.06, y + R * 0.06, R * 0.24), pal.cream, 0.45)
    pt:stroke({ K.dot(x, y, R * 0.36), K.dot(x, y, R * 0.3) }, pal.copper, 0.35, 0.9, { many = true })
    rosette(pt, x, y, R * 0.2, 8)
  end,
})

Orn.register({
  name = "compass_rose", slot = "crest", label = "Compass rose",
  draw = function(pt, rng, b)
    local x, y, _, _, s = K.measure(b)
    local R = s * 0.46
    -- Ring with thirty-two ticks.
    pt:stroke({ K.dot(x, y, R * 0.78), K.dot(x, y, R * 0.7) }, pal.gold, 0.4, 0.9, { many = true })
    local ticks = {}
    for k = 0, 31 do
      local a = k * pi / 16
      ticks[#ticks + 1] = G.polyline({ G.polar({ x, y }, a, R * 0.7), G.polar({ x, y }, a, R * (k % 2 == 0 and 0.78 or 0.74)) })
    end
    pt:stroke(ticks, pal.gold, 0.25, 0.85, { many = true })
    -- Sixteen points in three lengths, and a trefoil at the north.
    for _, layer in ipairs({ { 16, R * 0.62, 0.16, pi / 16 }, { 8, R * 0.8, 0.2, pi / 8 }, { 4, R, 0.26, 0 } }) do
      local lit, shade = {}, {}
      for k = 0, layer[1] - 1 do
        local a = pi / 2 + layer[4] + k * 2 * pi / layer[1]
        local tip = G.polar({ x, y }, a, layer[2])
        local half = layer[2] * layer[3] * 0.5
        lit[#lit + 1] = G.polyline({ { x, y }, tip, G.polar({ x, y }, a + pi / 2, half) }, true)
        shade[#shade + 1] = G.polyline({ { x, y }, tip, G.polar({ x, y }, a - pi / 2, half) }, true)
      end
      K.gilt(pt, lit, shade)
    end
    pt:fill(K.trefoil(x, y + R * 1.02, R * 0.14, pi / 2), pal.gold, 0.95, { many = true })
    pt:fill(K.dot(x, y, R * 0.06), pal.cream, 1)
    pt:stroke(K.dot(x, y, R * 0.06), pal.copper, 0.25, 0.9)
  end,
})

Orn.register({
  name = "armillary_crest", slot = "crest", label = "Armillary crest",
  draw = function(pt, rng, b)
    local x, y, _, _, s = K.measure(b)
    K.armillary(pt, x, y + s * 0.1, s * 0.32, rng:range(0.35, 0.5), b[2] + s * 0.04)
  end,
})

Orn.register({
  name = "zodiac", slot = "crest", label = "Zodiac wheel",
  draw = function(pt, rng, b)
    local x, y, _, _, s = K.measure(b)
    zodiac(pt, x, y, s * 0.47, rng)
  end,
})

Orn.register({
  name = "wreath", slot = "crest", label = "Laurel wreath",
  draw = function(pt, rng, b)
    local x, y, _, _, s = K.measure(b)
    local R = s * 0.38
    -- Two branches of paired leaves from the foot, meeting short of the top.
    local leaves, veins = {}, {}
    for _, d in ipairs({ -1, 1 }) do
      local stem = {}
      for k = 0, 24 do
        local a = -pi / 2 + d * (0.22 + k / 24 * (pi - 0.62))
        stem[#stem + 1] = G.polar({ x, y }, a, R)
      end
      veins[#veins + 1] = G.smooth(stem)
      for k = 2, 24, 2 do
        local a = -pi / 2 + d * (0.22 + k / 24 * (pi - 0.62))
        local p = G.polar({ x, y }, a, R)
        local along = a + d * pi / 2
        local size = s * 0.075 * (1 - k / 60)
        for _, side in ipairs({ -1, 1 }) do
          leaves[#leaves + 1] = G.smooth(K.ellipse(
            p[1] + math.cos(along + side * 0.7) * size * 0.9, p[2] + math.sin(along + side * 0.7) * size * 0.9,
            size, size * 0.38, along + side * 0.7, 14), true)
        end
      end
    end
    pt:stroke(veins, pal.copper, 0.5, 0.8, { many = true })
    pt:fill(leaves, pal.gold, 0.9, { many = true })
    -- A bow at the foot and a star inside.
    for _, d in ipairs({ -1, 1 }) do
      pt:fill(G.smooth(K.ellipse(x + d * s * 0.06, y - R - s * 0.01, s * 0.06, s * 0.03, d * 0.4, 16), true), pal.copper, 0.85)
      pt:fill(K.taper({ { x, y - R }, { x + d * s * 0.05, y - R - s * 0.08 }, { x + d * s * 0.09, y - R - s * 0.13 } }, s * 0.025, 0.4), pal.copper, 0.85)
    end
    local lit, shade = K.rays(x, y, s * 0.03, s * 0.2, 8, { short = 0.45, width = 0.3, rot = pi / 2 + rng:jit(0.05) })
    K.gilt(pt, lit, shade)
  end,
})

return { rosette = rosette, quatrefoil = quatrefoil, zodiac = zodiac }
