-- Spray helpers for grow.lua (a spray grown on a stalk from a stem point,
-- and a check that it clears the text), and sparkles in leftover space.

local G = require("flora.geom")
local S = require("flora.sprig")
local Orn = require("flora.ornaments")

local Fill = {}
local pi = math.pi

-- Nearest point on any stem within `maxd`, with that stem's tangent.
local function nearest(stems, p, maxd)
  local best, bd, ba = nil, maxd, nil
  for _, s in ipairs(stems) do
    local pts = s.pts
    for i = 2, #pts, 2 do
      local d = G.dist(p, pts[i])
      if d < bd then
        best, bd, ba = pts[i], d, G.angle(pts[i - 1], pts[i])
      end
    end
  end
  return best, bd, ba
end
Fill.nearest = nearest

-- Grow one spray of `kind` toward (x, y) from stem point s, whose stem
-- runs along `tangent`, into batch `b`. The stalk peels off the stem
-- tangentially and sweeps into the gap; the spray continues its heading.
-- `scale` shrinks the spray; `lean` turns it. Returns the stalk, and for a
-- bloom its centre and radius.
function Fill.grow(b, rng, kind, s, tangent, d, x, y, r, scale, lean)
  local target = { x, y }
  local chord = G.angle(s, target)
  local dir0 = G.depart(s, tangent, target, 0.35)
  local a = chord + G.turn(chord, dir0) * 0.6 + lean
  local base = G.polar(s, chord, math.max(d - r * 0.55, 3))
  local stalk = G.link(s, dir0, base, a)
  b:line(stalk, d > 30 and 2 or 3)
  r = r * scale
  if kind == "bloom" then
    b:line(G.spline_points({ base, { x, y } }, 2), 2)
    return stalk, { x, y, r * 0.6 }
  elseif kind == "gyps" then
    S.gypsophila(b, rng, base, a, r * 0.5, r >= 14 and 5 or (r >= 8 and 4 or 3))
  elseif kind == "cyme" then
    S.cyme(b, rng, base, a, r * 1.25, rng:chance(0.5) and 1 or -1)
  elseif kind == "umbel" then
    S.umbel(b, rng, base, a, r * 0.85)
  elseif kind == "bud" then
    for k = -1, 1 do
      local stem = G.curve(base, a + k * 0.45, r * 0.6, rng:jit(0.4), 0, 4)
      b:line(stem, 3)
      local e = stem[#stem]
      b:bud(e[1], e[2], a + k * 0.45, r * 0.32)
    end
  else
    b:floret(x, y, r * 0.35, rng:range(0, 2 * pi), rng:int(1, 3))
  end
  return stalk
end

-- Does every point of batch `b` lie in open space (with its radius)?
function Fill.fits(g, b)
  local ok = true
  b:each_point(function(x, y, r)
    if ok and not (g:open_at(x, y) and g:open_at(x - r, y) and g:open_at(x + r, y)
        and g:open_at(x, y - r) and g:open_at(x, y + r)) then
      ok = false
    end
  end)
  return ok
end

-- The larger gilt's kinds by weight (orn_gilt.lua): the reference's own,
-- drawn from rng as they always were, and the newer ones, which replace a
-- pick from a stream of their own in proportion to their share of the
-- weight. With the newer kinds at 0, rng sees exactly the draws it did.
local function gilt_picker(rng, weights)
  local old, new, so, sn = {}, {}, 0, 0
  for _, k in ipairs(Orn.of("gilt")) do
    local w = Orn.weight(weights, k.name)
    if k.classic then old[k.sparkle], so = w, so + w else new[k.sparkle], sn = w, sn + w end
  end
  if so + sn == 0 then return nil end
  local alt = rng:fork("gilt kinds")
  return function()
    local kind = so > 0 and rng:weighted(old) or nil
    if sn > 0 and (not kind or alt:chance(sn / (so + sn))) then kind = alt:weighted(new) end
    return kind
  end
end

-- Sparkles in whatever free space is left; `weights` (ornaments settings)
-- weigh the larger gilt.
function Fill.sparkles(rng, g, n, weights)
  local cells = g:free_cells(2)
  local pick = gilt_picker(rng, weights)
  local items = {}
  local function put(x, y, size, kind)
    local reach = (kind == "cross" and 1.55 or 1) * size
    items[#items + 1] = { x, y, size, kind }
    g:reserve(x, y, reach * 2.2)
  end
  -- First the larger gilt, as the reference's dotted crosses and rosettes:
  -- one in each of the wider gaps the foliage leaves, up to a third of n.
  local big, tries = 0, 0
  while pick and big < n / 3 and tries < n * 30 and #cells > 0 do
    tries = tries + 1
    local c = cells[rng:int(1, #cells)]
    local r = g:clearance(c[1], c[2], 14)
    if r >= 9 then
      local size = rng:range(4.2, math.min(7.5, r * 0.5))
      put(c[1], c[2], size, pick())
      big = big + 1
    end
  end
  -- Then small sparkles in the narrower gaps.
  tries = 0
  while #items < n and tries < n * 20 and #cells > 0 do
    tries = tries + 1
    local c = cells[rng:int(1, #cells)]
    local r = g:clearance(c[1], c[2], 8)
    if r >= 3 then
      local size = rng:range(1.4, math.min(3.4, r * 0.8))
      put(c[1], c[2], size, rng:weighted({ plain = 5, dotted = 3, lozenge = 2 }))
    end
  end
  return items
end

return Fill
