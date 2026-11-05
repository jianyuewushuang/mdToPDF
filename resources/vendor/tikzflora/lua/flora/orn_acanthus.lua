-- Acanthus, the leaf Vitruvius has growing round a basket on a girl's
-- grave and Callimachus copying into the Corinthian capital. Here it
-- sheathes a rinceau, the running scroll of classical friezes, set under
-- a title, and fills a corner round two volutes. Leaves and stems are
-- gilt; their veins are tooled in.

local Orn = require("flora.ornaments")
local K = require("flora.orn_kit")
local G = require("flora.geom")
local Pen = require("flora.orn_pen")
local Gild = require("flora.orn_gild")

local M = {}
local pi, sin = math.pi, math.sin

-- An acanthus leaf from `base` heading `ang`, `len` long. Its midrib
-- bends and its tip turns over by `o.curl` turns (signed); each side has
-- `o.lobes` lobes, each a swelling of forward-pointing teeth cut off by a
-- deep notch, the two sides out of step. Returns the outline (points,
-- closed), veins (point lists) and eyes: the small hollows where the
-- notches reach in toward the midrib (point lists, closed).
function M.leaf(base, ang, len, o)
  o = o or {}
  local curl = o.curl or 0.2
  local rib = G.resample(Pen.path(base, ang, { { len * 0.5, curl * 0.2, "c" }, { len * 0.5, curl * 0.8, "in" } }), 160)
  local n, W = o.lobes or 4, len * (o.wide or 0.23)
  local function env(t)
    return W * sin(pi * (0.06 + 0.94 * t ^ 0.8)) ^ 0.85 * (1 - 0.3 * t)
  end
  local function lobe(t, phase)
    local u = (t * n + phase) % 1
    local swell = 0.18 + 0.82 * sin(pi * u ^ 0.8) ^ 0.55
    local teeth = 0.72 + 0.28 * ((u * 3) % 1) ^ 2.2
    return swell * teeth
  end
  local left, right, veins = {}, {}, {}
  local m = #rib
  for i = 1, m do
    local t = (i - 1) / (m - 1)
    local a = G.angle(rib[math.max(1, i - 1)], rib[math.min(m, i + 1)])
    local stalk = G.smoothstep(0.02, 0.14, t)
    local wl = env(t) * (0.25 + 0.75 * stalk * lobe(t, 0))
    local wr = env(t) * (0.25 + 0.75 * stalk * lobe(t, 0.5))
    left[i] = G.polar(rib[i], a + pi / 2, wl)
    right[i] = G.polar(rib[i], a - pi / 2, wr)
  end
  local out = {}
  for i = 1, m do out[#out + 1] = left[i] end
  for i = m - 1, 2, -1 do out[#out + 1] = right[i] end
  -- The midrib, a vein out to the head of each lobe and an eye at the
  -- foot of each notch.
  local eyes = {}
  local mid = {}
  for i = 1, math.floor(m * 0.88) do mid[i] = rib[i] end
  veins[1] = mid
  for _, sp in ipairs({ { 0, left }, { 0.5, right } }) do
    local side, pts = sp[1], sp[2]
    for k = 0, n - 1 do
      local t1 = (k + 0.92 - side) / n
      if t1 > 0.12 and t1 < 0.9 then
        local i1 = math.floor(t1 * (m - 1)) + 1
        local i0 = math.max(1, i1 - math.floor(m * 0.12))
        veins[#veins + 1] = { rib[i0], G.mix(rib[i1], pts[i1], 0.7) }
      end
      local tn = (k + 1 - side) / n
      if tn > 0.15 and tn < 0.85 then
        local j = math.floor(tn * (m - 1)) + 1
        local q = G.mix(rib[j], pts[j], 0.55)
        local r = env(tn) * 0.12
        eyes[#eyes + 1] = K.ellipse(q[1], q[2], r * 1.6, r, G.angle(rib[math.max(1, j - 1)], rib[math.min(m, j + 1)]), 12)
      end
    end
  end
  return out, veins, eyes
end

-- Paint gilt leaves (outlines) with their veins tooled in umber and
-- their eyes cut in.
function M.paint_leaves(pt, leaves, veins, size, eyes)
  local paths = {}
  for i, l in ipairs(leaves) do paths[i] = G.smooth(l, true) end
  Gild.fill(pt, paths, { each = true, bevel = G.clamp(size * 0.012, 0.12, 0.45), key = 0.14, shadow = size * 0.01 })
  local vp = {}
  for _, v in ipairs(veins) do vp[#vp + 1] = G.smooth(v) end
  pt:stroke(vp, Gild.umber, G.clamp(size * 0.006, 0.12, 0.3), 0.55, { many = true })
  local ep = {}
  for _, e in ipairs(eyes or {}) do ep[#ep + 1] = G.smooth(e, true) end
  if #ep > 0 then pt:fill(ep, Gild.umber, 0.6, { many = true }) end
end

-- A stem as a tapered gilt ribbon along `pts`, w wide at its root.
local function stems(pt, list, w)
  local paths = {}
  for _, s in ipairs(list) do paths[#paths + 1] = K.taper(s.pts, s.w or w, 0.3) end
  Gild.fill(pt, paths, { bevel = w * 0.18, key = 0.12, shadow = w * 0.2 })
end

-- Leaves gathered for painting together: outlines, veins and eyes.
local function bunch() return { leaves = {}, veins = {}, eyes = {} } end

local function gather(bn, l, v, e)
  bn.leaves[#bn.leaves + 1] = l
  for _, x in ipairs(v) do bn.veins[#bn.veins + 1] = x end
  for _, x in ipairs(e) do bn.eyes[#bn.eyes + 1] = x end
end

-- `bn` with every point list passed through f.
local function remap(bn, f)
  local out = bunch()
  for _, key in ipairs({ "leaves", "veins", "eyes" }) do
    for i, l in ipairs(bn[key]) do out[key][i] = f(l) end
  end
  return out
end

-- One half of a rinceau, the right one, in units of about its height,
-- written from the calyx outward: a waving stem winding into a large
-- volute, leaves sheathing it where it bends, and a tendril off the crest.
local function rinceau_half(rng)
  local up = rng:chance(0.5) and 1 or -1
  local a0 = up * rng:range(0.15, 0.35)
  local swing = rng:range(0.08, 0.14)
  local stem = Pen.path({ 0.18, -0.12 }, a0, {
    { rng:range(1.2, 1.5), -up * swing, "bell" },
    { rng:range(1.0, 1.3), up * swing * 0.6, "bell" },
    { rng:range(0.3, 0.45), -up * 0.05, "c" },
    { rng:range(1.5, 1.8), -up * rng:range(1.3, 1.6), "in" },
  })
  local bn = bunch()
  local function leaf(at, turn, len, curl)
    local p, a = G.at(stem, at)
    gather(bn, M.leaf(p, a + turn, len, { curl = curl, lobes = rng:int(3, 4), wide = rng:range(0.2, 0.25) }))
  end
  -- Leaves sheath the stem at its root and as it turns into the volute,
  -- each turned away from the stem, the side the stem bends from.
  leaf(0.02, up * 0.4, rng:range(0.7, 0.85), -up * rng:range(0.2, 0.3))
  leaf(rng:range(0.58, 0.64), -up * 0.5, rng:range(0.6, 0.75), up * rng:range(0.2, 0.3))
  -- A tendril springs from the crest of the wave and curls the other way.
  local p, a = G.at(stem, rng:range(0.3, 0.4))
  local tend = Pen.sprig(p, a + up * 0.9, rng:range(0.45, 0.6), -up, rng:range(0.9, 1.2))
  local tip = tend[#tend]
  local berries = {}
  for k = 0, 2 do berries[#berries + 1] = G.polar(tip, a + up * (0.6 + k * 0.7), 0.07) end
  return { stem = stem, bunch = bn, tendril = tend, berries = berries }
end

Orn.register({
  name = "rinceau", slot = "flourish", label = "Acanthus rinceau", reach = 0.05,
  draw = function(pt, rng, b)
    local half = rinceau_half(rng)
    -- The calyx: two leaves splayed from the centre and a bud between.
    local calyx = bunch()
    for _, d in ipairs({ -1, 1 }) do
      gather(calyx, M.leaf({ d * 0.04, -0.3 }, pi / 2 - d * 1.0, 0.6, { curl = -d * 0.25, lobes = 3 }))
    end
    gather(calyx, M.leaf({ 0, -0.3 }, pi / 2, 0.5, { curl = 0, lobes = 3, wide = 0.2 }))
    -- Mirror the half into the left, then fit everything to the box.
    local lists = { half.stem, Pen.mirror(half.stem, 0, -1) }
    for _, l in ipairs(half.bunch.leaves) do lists[#lists + 1] = l lists[#lists + 1] = Pen.mirror(l, 0, -1) end
    for _, l in ipairs(calyx.leaves) do lists[#lists + 1] = l end
    local fit, s = Pen.fit(Pen.extent(lists), b, math.min(b[3] - b[1], b[4] - b[2]) * 0.06)
    local function left(l) return fit(Pen.mirror(l, 0, -1)) end
    stems(pt, { { pts = fit(half.stem) }, { pts = left(half.stem) },
      { pts = fit(half.tendril), w = s * 0.03 }, { pts = left(half.tendril), w = s * 0.03 } }, s * 0.07)
    local all = bunch()
    for _, bn in ipairs({ remap(half.bunch, fit), remap(half.bunch, left), remap(calyx, fit) }) do
      for _, key in ipairs({ "leaves", "veins", "eyes" }) do
        for _, l in ipairs(bn[key]) do all[key][#all[key] + 1] = l end
      end
    end
    M.paint_leaves(pt, all.leaves, all.veins, s, all.eyes)
    local dots = {}
    for _, p in ipairs(fit(half.berries)) do dots[#dots + 1] = p end
    for _, p in ipairs(left(half.berries)) do dots[#dots + 1] = p end
    Gild.dots(pt, dots, s * 0.04)
    -- A rosette in the eye of each volute.
    local roundel = require("flora.orn_roundel")
    local e = { half.stem[#half.stem] }
    for _, q in ipairs({ fit(e)[1], left(e)[1] }) do
      roundel.rosette(pt, q[1], q[2], s * 0.13, 8, rng:range(0, pi / 8))
    end
  end,
})

Orn.register({
  name = "acanthus_corner", slot = "corner", label = "Acanthus corner", reach = 0.04,
  draw = function(pt, rng, b, o)
    K.corner(pt, b, o, function(x0, y0, s)
      local u = function(x, y) return { x0 + x * s, y0 + y * s } end
      -- A volute along each edge out of the corner, winding in toward the
      -- page; a large leaf on the diagonal between them.
      local list, bn = {}, bunch()
      local turn = rng:range(1.2, 1.5)
      for _, e in ipairs({ { 0, 1 }, { pi / 2, -1 } }) do
        local a, d = e[1], e[2]
        local stem = Pen.path(u(0.08, 0.08), a, { { s * 0.4, d * 0.02, "c" }, { s * 0.55, d * turn, "in" } })
        list[#list + 1] = { pts = stem }
        local p, ta = G.at(stem, 0.28)
        gather(bn, M.leaf(p, ta + d * 0.45, s * 0.34, { curl = -d * 0.22, lobes = 3 }))
      end
      local curl = (rng:chance(0.5) and 1 or -1) * rng:range(0.18, 0.28)
      gather(bn, M.leaf(u(0.1, 0.1), pi / 4, s * rng:range(0.62, 0.72), { curl = curl, lobes = 4, wide = 0.24 }))
      stems(pt, list, s * 0.05)
      M.paint_leaves(pt, bn.leaves, bn.veins, s, bn.eyes)
      require("flora.orn_roundel").rosette(pt, x0 + s * 0.08, y0 + s * 0.08, s * 0.09, 8, pi / 8)
    end)
  end,
})

return M
