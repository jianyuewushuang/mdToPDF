-- Ribbon banners behind a title's lines, for the bouquet layout
-- (frames.lua): each line sits on the face of a ribbon whose two ends
-- fold back behind it into swallowtails, as on engraved title pages. The
-- face is pale paper drawn round with a sepia hairline; the tails behind
-- are darker and hatched, and a small fold joins each tail to the face.
-- Boxes are page boxes {x0, y0, x1, y1}, y up.

local G = require("flora.geom")

local M = {}

local FACE = { 0.985, 0.968, 0.925 }
local BACK = { 0.925, 0.885, 0.795 }
local FOLD = { 0.785, 0.715, 0.590 }
local LINE = { 0.330, 0.250, 0.165 }

-- The ribbon behind one line box `l`, its tails dropping (dir -1) or
-- rising (dir 1). Returns {face, tails = {...}, folds = {...}}: closed
-- point lists.
function M.shape(l, dir)
  local lh = l.y1 - l.y0
  local py = math.max(4, lh * 0.38)
  local x0, x1, y0, y1 = l.x0 - math.max(8, lh * 0.7), l.x1 + math.max(8, lh * 0.7), l.y0 - py, l.y1 + py
  local h = y1 - y0
  local d = dir * h * 0.42
  local len, notch, f = h * 1.15, h * 0.38, h * 0.3
  local out = { face = { { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }, tails = {}, folds = {}, box = { x0 - len, math.min(y0, y0 + d), x1 + len, math.max(y1, y1 + d) } }
  for _, s in ipairs({ -1, 1 }) do
    local e = s < 0 and x0 or x1
    local tip = e + s * len
    out.tails[#out.tails + 1] = {
      { e, y0 + d }, { tip, y0 + d }, { tip - s * notch, (y0 + y1) / 2 + d }, { tip, y1 + d }, { e, y1 + d },
    }
    -- The fold shows where the tail turns under the face: below the face
    -- for a dropping tail, above it for a rising one.
    local edge = dir < 0 and y0 or y1
    out.folds[#out.folds + 1] = { { e, edge }, { e - s * f, edge }, { e, edge + d } }
  end
  return out
end

-- Hatching across polygon `poly`: parallel lines at angle `ang`, `gap`
-- apart, clipped by the painter to the polygon.
local function hatch(pt, poly, ang, gap, rgb, w, op)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(poly) do
    x0, y0, x1, y1 = math.min(x0, p[1]), math.min(y0, p[2]), math.max(x1, p[1]), math.max(y1, p[2])
  end
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  local r = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) / 2 + 1
  local ux, uy = math.cos(ang), math.sin(ang)
  local lines = {}
  for k = -r, r, gap do
    local mx, my = cx - uy * k, cy + ux * k
    lines[#lines + 1] = G.polyline({ { mx - ux * r, my - uy * r }, { mx + ux * r, my + uy * r } })
  end
  pt:clip_begin(G.polyline(poly, true))
  pt:stroke(lines, rgb, w, op, { many = true })
  pt:clip_end()
end

-- The bow's knot: a rounded band k wide about (x, y), a little taller
-- than wide. Points, closed.
local function knot_shape(x, y, k)
  local out = {}
  for i = 0, 15 do
    local a = 2 * math.pi * i / 16
    out[#out + 1] = { x + k * math.cos(a), y + k * 1.35 * math.sin(a) + k * 0.2 }
  end
  return out
end

-- A bow of the same ribbon tied round a bouquet's stems at (x, y), s
-- across: two loops tilted up from the knot, each a teardrop pinched at
-- the knot with its shaded opening near the outer end, two tails falling
-- from the knot, and the knot.
function M.bow(pt, x, y, s)
  local loops, holes, tails = {}, {}, {}
  local L = s * 0.56
  for _, d in ipairs({ -1, 1 }) do
    local c, sn = math.cos(0.38), math.sin(0.38)
    -- Local (u along the loop, v across it), tilted up and mirrored for
    -- the left loop.
    local function at(u, v) return { x + d * (u * c - v * sn), y + u * sn + v * c } end
    local loop, hole = {}, {}
    for i = 0, 31 do
      local a = 2 * math.pi * i / 32
      local u = L * 0.5 * (1 - math.cos(a))
      local v = L * 0.3 * math.sin(a) * G.smoothstep(0, L * 0.4, u)
      loop[#loop + 1] = at(u, v)
      hole[#hole + 1] = at(L * 0.66 + L * 0.2 * math.cos(a), L * 0.1 * math.sin(a))
    end
    loops[#loops + 1], holes[#holes + 1] = loop, hole
    local tip = { x + d * s * 0.42, y - s * 0.95 }
    tails[#tails + 1] = {
      { x - d * s * 0.04, y - s * 0.02 }, { x + d * s * 0.12, y - s * 0.04 },
      { tip[1] + d * s * 0.08, tip[2] + s * 0.02 }, { tip[1] - d * s * 0.02, tip[2] + s * 0.12 },
      { tip[1] - d * s * 0.12, tip[2] - s * 0.02 },
    }
  end
  for _, t in ipairs(tails) do
    pt:fill(G.polyline(t, true), BACK, 1)
    hatch(pt, t, -1.2, 1.4, LINE, 0.2, 0.5)
    pt:stroke(G.polyline(t, true), LINE, 0.4, 0.9)
  end
  for i, l in ipairs(loops) do
    local c = G.smooth(l, true)
    pt:fill(c, FACE, 1)
    pt:stroke(c, LINE, 0.45, 0.9)
    -- The loop's opening: the ribbon's inside, darker and hatched.
    local h = G.smooth(holes[i], true)
    pt:fill(h, BACK, 1)
    hatch(pt, holes[i], 0.6, 1.2, LINE, 0.18, 0.5)
    pt:stroke(h, LINE, 0.35, 0.9)
  end
  local k = s * 0.09
  local knot = G.smooth(knot_shape(x, y, k), true)
  pt:fill(knot, BACK, 1)
  hatch(pt, knot_shape(x, y, k), 1.57, 1.3, LINE, 0.18, 0.45)
  pt:stroke(knot, LINE, 0.45, 0.9)
end

-- Paint a ribbon behind each of `lines` (page boxes), alternating the
-- tails' direction from line to line, the first dropping.
function M.paint(pt, lines)
  for i, l in ipairs(lines) do
    local r = M.shape(l, i % 2 == 1 and -1 or 1)
    for _, t in ipairs(r.tails) do
      pt:fill(G.polyline(t, true), BACK, 1)
      hatch(pt, t, 0, 1.5, LINE, 0.22, 0.55)
    end
    for _, f in ipairs(r.folds) do pt:fill(G.polyline(f, true), FOLD, 1) end
    local outline = {}
    for _, t in ipairs(r.tails) do outline[#outline + 1] = G.polyline(t, true) end
    for _, f in ipairs(r.folds) do outline[#outline + 1] = G.polyline(f, true) end
    pt:stroke(outline, LINE, 0.45, 0.9, { many = true })
    pt:fill(G.polyline(r.face, true), FACE, 1)
    -- The face's edges, drawn twice like an engraver's border rule.
    local f = r.face
    local inset = {
      G.polyline({ { f[1][1] + 1.5, f[1][2] + 1.6 }, { f[2][1] - 1.5, f[2][2] + 1.6 } }),
      G.polyline({ { f[4][1] + 1.5, f[4][2] - 1.6 }, { f[3][1] - 1.5, f[3][2] - 1.6 } }),
    }
    pt:stroke(G.polyline(f, true), LINE, 0.5, 0.95)
    pt:stroke(inset, LINE, 0.22, 0.6, { many = true })
  end
end

return M
