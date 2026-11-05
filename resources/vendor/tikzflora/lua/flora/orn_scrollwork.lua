-- The scrollwork layout's gilt frame (frames.lua): a band of gilt along
-- the title's oval (oval.lua), its lengths joined by bosses, with a fine
-- gilt fillet inside it, a crest at its head, C-scrolls and a tailpiece at
-- its foot and a pair of scrolls with an acanthus leaf at each side, as
-- on engraved title pages whose frames are pierced scrollwork. The band
-- goes under the plants, which twine over it; head and foot go over them.

local Orn = require("flora.ornaments")
local Rng = require("flora.rng")
local K = require("flora.orn_kit")
local G = require("flora.geom")
local Paint = require("flora.paint")
local Acanthus = require("flora.orn_acanthus")
local Scroll = require("flora.orn_scroll")

local M = {}
local pal = Paint.palette
local pi = math.pi

-- Raster gilt joins every shape painted since its last image into one
-- image the size of their bounds; the band is flushed length by length so
-- no image spans the oval.
local function flush(pt)
  if pt.gilt_pending then require("flora.orn_raster").flush(pt) end
end

-- Paint `fn` with gold and copper gilt, as an ornament's are.
local function gilt(pt, fn)
  Orn.draw({ draw = function(p) fn(p) end }, pt, nil, { 0, 0, 0, 0 })
end

-- The oval's point at arclength s, offset d inward: x, y, and the inward
-- normal.
local function at(ov, s, d)
  local x, y, nx, ny = ov:point(ov:theta(s))
  return x + nx * d, y + ny * d, nx, ny
end

-- The closed outline of the band from arclength s0 to s1, between inward
-- offsets d0 and d1.
local function strip(ov, s0, s1, d0, d1)
  local n = math.max(2, math.ceil((s1 - s0) / 4))
  local outer, inner = {}, {}
  for i = 0, n do
    local s = s0 + (s1 - s0) * i / n
    local x, y = at(ov, s, d0)
    outer[#outer + 1] = { x, y }
    x, y = at(ov, s, d1)
    inner[#inner + 1] = { x, y }
  end
  for i = #inner, 1, -1 do outer[#outer + 1] = inner[i] end
  return outer
end

-- The frame's plan for oval `ov` on page spec: its band width, the boxes
-- of its head and foot pieces (which the plants keep out of) and the
-- kinds picked for them. Each pick has its own stream, so the choice
-- never moves anything else.
function M.plan(spec, ov)
  local rng = Rng.new(tonumber(spec.seed) or 1)
  local w = G.clamp(ov.a * 0.028, 4.5, 8)
  local head = G.clamp(ov.a * 0.3, 52, 84)
  local foot = G.clamp(ov.a * 0.5, 80, 140)
  local top = ov.cy + ov.b
  local bot = ov.cy - ov.b
  local plan = {
    w = w,
    crest = Orn.pick(rng:fork("choose scrollwork crest"), "crest", spec.ornaments),
    tail = Orn.pick(rng:fork("choose scrollwork tailpiece"), "tailpiece", spec.ornaments),
    head = { ov.cx - head / 2, top - head * 0.42, ov.cx + head / 2, top + head * 0.58 },
    foot = { ov.cx - foot / 2, bot - foot * 0.36, ov.cx + foot / 2, bot + foot * 0.28 },
  }
  return plan
end

-- The band, its bosses and fillet: paint before the plants.
function M.under(pt, spec, ov, plan)
  local w = plan.w
  local n = 20
  local len = ov.len
  local boss = w * 0.95
  gilt(pt, function(p)
    for k = 0, n - 1 do
      local s0, s1 = len * k / n + boss * 0.6, len * (k + 1) / n - boss * 0.6
      p:fill(G.polyline(strip(ov, s0, s1, -w / 2, w / 2), true), pal.gold, 0.95)
      flush(p)
      -- The fillet, a hairline of gold inside the band.
      p:fill(G.polyline(strip(ov, s0 - boss * 0.5, s1 + boss * 0.5, w * 1.15, w * 1.15 + 0.7), true), pal.gold, 0.9)
      flush(p)
    end
    for k = 0, n - 1 do
      local x, y = at(ov, len * k / n, 0)
      p:fill(K.dot(x, y, boss), pal.gold, 0.95)
      p:fill(K.dot(x, y, boss * 0.4), pal.copper, 0.9)
      flush(p)
    end
    -- Beads along the outside of the band.
    for k = 0, n - 1 do
      local beads = {}
      for j = 1, 5 do
        local x, y = at(ov, len * (k + j / 6) / n, -w * 1.05)
        beads[#beads + 1] = K.dot(x, y, w * 0.18)
      end
      p:fill(beads, pal.gold, 0.9, { many = true })
      flush(p)
    end
  end)
end

-- A pair of C-scrolls and an acanthus leaf springing outward from the band
-- at arclength s.
local function side(pt, ov, s, size, w)
  local x, y, nx, ny = at(ov, s, -w * 0.5)
  local out = math.atan(-ny, -nx)
  for _, d in ipairs({ -1, 1 }) do
    local p = { x - ny * d * size * 0.12, y + nx * d * size * 0.12 }
    Scroll.scroll(pt, p, out + d * 0.9, size * 0.55, -d, w * 0.75)
    flush(pt)
  end
  local leaf, veins, eyes = Acanthus.leaf({ x, y }, out, size * 0.9, { lobes = 3, curl = 0.15 })
  Acanthus.paint_leaves(pt, { leaf }, veins, size, eyes)
  flush(pt)
end

-- The head, foot and side pieces: paint after the plants.
function M.over(pt, spec, ov, plan)
  local rng = Rng.new(tonumber(spec.seed) or 1)
  local w = plan.w
  gilt(pt, function(p)
    for _, s in ipairs({ ov.len * 0.25, ov.len * 0.75 }) do side(p, ov, s, G.clamp(ov.b * 0.16, 28, 52), w) end
    -- C-scrolls at the foot, curling out and up from the band's lowest
    -- point.
    local fb = plan.foot
    local fs = (fb[3] - fb[1])
    for _, d in ipairs({ -1, 1 }) do
      Scroll.scroll(p, { ov.cx + d * fs * 0.1, ov.cy - ov.b - w * 0.6 }, pi / 2 - d * (pi / 2 + 0.35), fs * 0.36, d, w * 1.1)
      flush(p)
    end
    -- Two scrolls flanking the crest at the head, curling down the band.
    local hb = plan.head
    local hs = hb[3] - hb[1]
    for _, d in ipairs({ -1, 1 }) do
      Scroll.scroll(p, { ov.cx + d * hs * 0.32, ov.cy + ov.b + w * 0.3 }, pi / 2 - d * (pi / 2 - 0.25), hs * 0.42, -d, w * 0.85)
      flush(p)
    end
  end)
  if plan.crest then Orn.draw(plan.crest, pt, rng:fork("scrollwork crest"), plan.head) end
  if plan.tail then
    local fb = plan.foot
    local tw = (fb[3] - fb[1]) * 0.62
    local th = tw / 1.6
    local cx, y1 = (fb[1] + fb[3]) / 2, ov.cy - ov.b - w * 1.2
    Orn.draw(plan.tail, pt, rng:fork("scrollwork tailpiece"), { cx - tw / 2, y1 - th, cx + tw / 2, y1 })
  end
end

return M
