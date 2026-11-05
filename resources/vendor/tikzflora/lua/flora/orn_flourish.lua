-- Flourishes to set under a title, after three hands: the writing
-- master's pen (a copperplate flourish of crossing ovals and a pen swash),
-- the printer's case (the swelled rule) and the medieval flourisher's
-- penwork (fleuronnée). Pen kinds come in ink or in gilt; printed kinds in
-- gilt.
--
-- Copperplate rules followed here: the strokes are ovals and compound
-- curves, never circles; loops cross near right angles; a shade (a
-- downstroke) only ever crosses a hairline; each half winds out to a curl.

local Orn = require("flora.ornaments")
local K = require("flora.orn_kit")
local G = require("flora.geom")
local Paint = require("flora.paint")
local Pen = require("flora.orn_pen")
local Gild = require("flora.orn_gild")

local pal = Paint.palette
local pi = math.pi

-- Paint pen-stroke outlines `polys` (point lists) in ink, or gilt when
-- `gilt` is set; `dots` are {x, y, r} terminals.
local function ink(pt, polys, dots, gilt, shade)
  local paths = {}
  for i, p in ipairs(polys) do paths[i] = G.polyline(p, true) end
  for _, d in ipairs(dots or {}) do paths[#paths + 1] = K.dot(d[1], d[2], d[3]) end
  if gilt then
    Gild.fill(pt, paths, { bevel = math.max(0.1, shade * 0.22), key = 0.06, shadow = 0, light = pi / 2 + 0.35 })
  else
    pt:fill(paths, pal.ink, 0.9, { many = true, blend = "multiply" })
  end
end

-- Copperplate ----------------------------------------------------------------

-- One half of a copperplate flourish, written from the centre outward in
-- units of about the flourish's height: a lead out of the centre, a flat
-- oval loop on the line (its falling shade crosses the rising hairline
-- that entered it), a compound curve, and a curl winding in at the end.
local function copperplate_half(rng)
  local lead, a = Pen.path({ 0.08, 0 }, 0, {
    { rng:range(0.3, 0.5), rng:range(0.02, 0.06), "bell" }, { rng:range(0.3, 0.5), -rng:range(0.02, 0.06), "bell" } })
  local side = rng:chance(0.7) and 1 or -1
  local loop = Pen.loop(lead[#lead], a, rng:range(0.5, 0.75), rng:range(0.26, 0.38), rng:range(0.45, 0.8), side)
  local segs = {}
  local waves = rng:int(1, 2)
  local L = rng:range(0.8, 1.2) / waves
  for i = 1, waves do
    local amp = rng:range(0.04, 0.07) * (i % 2 == 1 and -side or side)
    segs[#segs + 1] = { L, amp, "bell" }
    segs[#segs + 1] = { L, -amp, "bell" }
  end
  local curl = rng:chance(0.6) and 1 or -1
  segs[#segs + 1] = { rng:range(0.25, 0.4), curl * 0.08, "c" }
  segs[#segs + 1] = { rng:range(0.8, 1.1), curl * rng:range(1.0, 1.4), "in" }
  local tail = Pen.path(loop[#loop], a, segs)
  local pts = {}
  for _, part in ipairs({ lead, loop, tail }) do
    for i = (#pts > 0 and 2 or 1), #part do pts[#pts + 1] = part[i] end
  end
  return pts
end

-- Points turned about the origin so that the first and last lie level.
local function level(pts)
  local a = G.angle(pts[1], pts[#pts])
  return G.transform(pts, 0, 0, -a)
end

Orn.register({
  name = "copperplate", slot = "flourish", label = "Copperplate flourish", reach = 0.04,
  draw = function(pt, rng, b)
    local half = copperplate_half(rng)
    local form = rng:weighted({ mirror = 3, turn = 2 })
    local strokes, extra = {}, {}
    if form == "mirror" then
      strokes = { half, Pen.mirror(half, 0, -1) }
      -- Between the halves: a lozenge, alone or between two balls.
      strokes[#strokes + 1] = { { -0.06, 0 }, { 0, 0.12 }, { 0.06, 0 }, { 0, -0.12 } }
      strokes[#strokes].solid = true
      if rng:chance(0.5) then extra = { { 0, 0.24 }, { 0, -0.24 } } end
    else
      -- One stroke through the centre: the left half is the right turned
      -- half a turn, written toward the centre, and the whole is levelled.
      local left = Pen.rotate(half, 0, 0)
      local whole = {}
      for i = #left, 2, -1 do whole[#whole + 1] = left[i] end
      for _, p in ipairs(half) do whole[#whole + 1] = p end
      strokes = { level(whole) }
    end
    local ext = Pen.extent(strokes)
    local fit, s = Pen.fit(ext, b, math.min(b[3] - b[1], b[4] - b[2]) * 0.08)
    local shade = G.clamp(s * 0.03, 0.45, 1.8)
    local polys, dots = {}, {}
    for _, st in ipairs(strokes) do
      if st.solid then
        polys[#polys + 1] = fit(st)
      else
        polys[#polys + 1] = Pen.pointed(fit(st), { hair = math.max(0.16, shade * 0.12), shade = shade, taper = { 0.02, 0.08 } })
      end
    end
    for _, p in ipairs(fit(extra)) do dots[#dots + 1] = { p[1], p[2], shade * 0.9 } end
    ink(pt, polys, dots, rng:chance(0.5), shade)
  end,
})

-- The pen swash: an S out of each side of a central lozenge, ending in a
-- curl, shaded where the pen pulls down.
Orn.register({
  name = "swash", slot = "flourish", label = "Pen swash",
  draw = function(pt, rng, b)
    local cx, cy, w, h = K.measure(b)
    local u, v = w / 2, h / 2
    local lift = rng:range(0.6, 1)
    local wave = rng:range(0.3, 0.5)
    local curl = rng:range(0.85, 1.15)
    local polys = {}
    for _, d in ipairs({ -1, 1 }) do
      local pts = G.spline_points(Pen.mirror({ { cx + u * 0.04, cy }, { cx + u * 0.16, cy + v * 0.5 * lift },
        { cx + u * 0.38, cy - v * wave }, { cx + u * 0.62, cy + v * wave * 0.7 * lift }, { cx + u * 0.8, cy } }, cx, d), 10)
      local tail = K.scroll(pts[#pts], d > 0 and -0.4 or pi + 0.4, h * 0.95 * curl, d)
      for i = 2, #tail do pts[#pts + 1] = tail[i] end
      polys[#polys + 1] = Pen.pointed(pts, { hair = 0.2, shade = h * 0.035, taper = { 0.03, 0.1 } })
    end
    local gilt = rng:chance(0.4)
    local lozenge = { { cx, cy + v * 0.3 }, { cx + v * 0.18, cy }, { cx, cy - v * 0.3 }, { cx - v * 0.18, cy } }
    polys[#polys + 1] = lozenge
    ink(pt, polys, { { cx - u * 0.94, cy, h * 0.04 }, { cx + u * 0.94, cy, h * 0.04 } }, gilt, h * 0.035)
  end,
})

-- Swelled rule -----------------------------------------------------------------

-- A swelled rule from x0 to x1 about height y, `t` thick at its middle:
-- a lens tapering to hairline points. Points, closed.
local function lens(x0, x1, y, t, pw)
  local top, out = {}, {}
  for i = 0, 40 do
    local f = i / 40
    top[#top + 1] = { x0 + (x1 - x0) * f, y + t / 2 * math.sin(pi * f) ^ (pw or 1.4) + 0.06 }
  end
  for _, p in ipairs(top) do out[#out + 1] = p end
  for i = #top - 1, 2, -1 do out[#out + 1] = { top[i][1], 2 * y - top[i][2] } end
  return out
end

Orn.register({
  name = "swelled_rule", slot = "flourish", label = "Swelled rule", reach = 0.02,
  draw = function(pt, rng, b)
    local cx, cy, w, h = K.measure(b)
    local form = rng:weighted({ plain = 2, broken = 3, oxford = 2, triple = 2 })
    local t = h * rng:range(0.11, 0.16)
    local x0, x1 = b[1] + w * 0.04, b[3] - w * 0.04
    local paths, dots = {}, {}
    if form == "plain" then
      paths[1] = G.polyline(lens(x0, x1, cy, t), true)
    elseif form == "broken" then
      -- Two swells meeting a lozenge, with a bead either side of it.
      local s = h * 0.26
      paths[1] = G.polyline(lens(x0, cx - s * 1.5, cy, t), true)
      paths[2] = G.polyline(lens(cx + s * 1.5, x1, cy, t), true)
      paths[3] = G.smooth(K.lozenge(cx - s * 0.7, cy, s * 1.4, 0), true)
      dots = { { cx - s * 1.15, cy }, { cx + s * 1.15, cy } }
    elseif form == "oxford" then
      -- A swell over a hairline, as the thick and thin of an Oxford rule.
      paths[1] = G.polyline(lens(x0, x1, cy + t * 0.55, t), true)
      paths[2] = G.polyline(lens(x0 + w * 0.06, x1 - w * 0.06, cy - t * 0.75, t * 0.22, 0.3), true)
    else
      -- A long swell between two short ones, beads in the gaps.
      local g = w * 0.035
      local side = (x1 - x0) * 0.17
      paths[1] = G.polyline(lens(x0 + side + g, x1 - side - g, cy, t), true)
      paths[2] = G.polyline(lens(x0, x0 + side, cy, t * 0.55), true)
      paths[3] = G.polyline(lens(x1 - side, x1, cy, t * 0.55), true)
      dots = { { x0 + side + g / 2, cy }, { x1 - side - g / 2, cy } }
    end
    Gild.fill(pt, paths, { bevel = t * 0.12, key = 0.15, shadow = t * 0.12, light = pi / 2 + 0.3, each = true })
    if #dots > 0 then Gild.dots(pt, dots, t * 0.3) end
  end,
})

-- Fleuronnée -----------------------------------------------------------------

local sprig, echo = Pen.sprig, Pen.echo

Orn.register({
  name = "fleuronnee", slot = "flourish", label = "Fleuronnée penwork", reach = 0.05,
  draw = function(pt, rng, b)
    local cx, cy, w, h = K.measure(b)
    -- The two colours of the flourisher's pot, in either role.
    local line, accent = pal.ink, pal.copper
    if rng:chance(0.35) then line, accent = pal.copper, pal.ink end
    local hw = G.clamp(h * 0.006, 0.16, 0.3)
    local hairs, beads, rings = {}, {}, {}
    local function hair(pts, f) hairs[#hairs + 1] = G.polyline(Pen.hairline(pts, hw, f), true) end
    local reach = w * 0.47
    local bud = h * rng:range(0.22, 0.28)
    local n = rng:int(4, 6)
    local turns = rng:range(0.9, 1.25)
    local wave = rng:range(0, 0.05)
    local size = rng:range(0.4, 0.5)
    local gap = h * rng:range(0.05, 0.07)
    for _, d in ipairs({ -1, 1 }) do
      -- The spine: a hairline from the bud out to each end, waving
      -- slightly, winding into a curl, with an echo along its curl.
      local start = { cx + d * bud * 1.05, cy }
      local spine = G.spline_points({ start, { cx + d * reach * 0.35, cy + h * wave }, { cx + d * reach * 0.7, cy - h * wave },
        { cx + d * reach * 0.84, cy } }, 10)
      local curl = sprig(spine[#spine], d > 0 and 0 or pi, h * 0.55, d, turns)
      for i = 2, #curl do spine[#spine + 1] = curl[i] end
      hair(spine, 0.6)
      local ce = echo(curl, -d * gap)
      local cut = {}
      for i = 1, math.floor(#ce * 0.7) do cut[i] = ce[i] end
      hair(cut, 0.3)
      local tip = curl[#curl]
      rings[#rings + 1] = { tip[1], tip[2], h * 0.045 }
      -- Sprigs along the spine, turning up and down in turn, each with an
      -- echo on its outer side and closing on a pearl; three dots in the
      -- gaps between them.
      for k = 1, n do
        local f = 0.06 + 0.68 * (k - 0.5) / n
        local p, along = G.at(spine, f)
        local side = (k % 2 == 1) and 1 or -1
        local sp = sprig(p, along + side * d * 0.85, h * size * rng:range(0.85, 1.1), -side * d, rng:range(0.95, 1.25))
        hair(sp, 0.5)
        local e = echo(sp, side * d * gap)
        local part = {}
        for i = 2, math.floor(#e * 0.55) do part[#part + 1] = e[i] end
        if #part > 2 then hair(part, 0.2) end
        local q = sp[#sp]
        rings[#rings + 1] = { q[1], q[2], h * 0.035 }
        local m = G.at(spine, f + 0.34 / n)
        local off = -side * h * 0.17
        for j = -1, 1 do
          beads[#beads + 1] = { m[1] + j * h * 0.045, m[2] + off + (j == 0 and -side * h * 0.045 or 0), h * 0.022 }
        end
      end
      -- A feather of short hairlines leaving the bud.
      for j = -1, 1, 2 do
        local f = sprig({ cx + d * bud * 0.9, cy + j * bud * 0.3 }, (d > 0 and 0 or pi) + j * d * 0.7, h * 0.3, -j * d, 0.7)
        hair(f, 0.4)
      end
    end
    -- The bud: a lozenge in the accent, ringed by two echo lines, as the
    -- flourisher traced round the initial.
    local core = K.lozenge(cx - bud * 0.6, cy, bud * 1.2, 0)
    for _, sc in ipairs({ 1.4, 1.8 }) do
      local e = G.toward(core, cx, cy, sc)
      e[#e + 1] = e[1]
      hair(e, 1)
    end
    pt:fill(hairs, line, 0.92, { many = true, blend = "multiply" })
    local circles = {}
    for _, r in ipairs(rings) do circles[#circles + 1] = G.polyline(Pen.hairline(K.ellipse(r[1], r[2], r[3], r[3], 0, 20), hw), true) end
    pt:fill(circles, line, 0.92, { many = true, blend = "multiply" })
    local dots = {}
    for _, q in ipairs(beads) do dots[#dots + 1] = K.dot(q[1], q[2], q[3]) end
    for _, r in ipairs(rings) do dots[#dots + 1] = K.dot(r[1], r[2], r[3] * 0.45) end
    pt:fill(dots, accent, 0.92, { many = true, blend = "multiply" })
    pt:fill(G.smooth(core, true), accent, 0.9, { blend = "multiply" })
    pt:fill(K.dot(cx, cy, bud * 0.13), pal.cream, 0.9)
  end,
})
