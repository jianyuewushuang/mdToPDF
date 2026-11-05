-- The pen behind the penwork ornaments. Paths are written as the hand
-- moves: a run of segments, each turning by a set amount with its
-- curvature held, tightening or relaxing (clothoid pieces), so loops close
-- smoothly and curls wind in as a flourisher's do. Strokes then take their
-- width from the pen's travel: a pointed pen opens into a shade only when
-- it is pulled toward the writer, so downstrokes swell and upstrokes and
-- crossings stay hairlines.

local G = require("flora.geom")

local M = {}
local pi, cos, sin = math.pi, math.cos, math.sin

-- Curvature profiles over a segment's length, t in 0-1, each scaled so
-- the segment turns by its full `turn`: c even, `in` tightening (a curl
-- winding in), `out` relaxing, `bell` swelling and relaxing.
local SHAPES = {
  c = { function() return 1 end, 1 },
  ["in"] = { function(t) return t * t end, 1 / 3 },
  out = { function(t) return (1 - t) ^ 2 end, 1 / 3 },
  bell = { function(t) return sin(pi * t) end, 2 / pi },
}

-- Points of a path from p heading `a`, through `segs`: each {len, turn,
-- shape}, len in units, turn in full turns (positive anticlockwise).
-- Returns the points and the final heading.
function M.path(p, a, segs)
  local pts = { { p[1], p[2] } }
  local q = p
  for _, s in ipairs(segs) do
    local f, mean = SHAPES[s[3] or "c"][1], SHAPES[s[3] or "c"][2]
    local kmax = 2 * pi * s[2] / (s[1] * mean)
    local seg
    seg, a = G.flow(q, a, s[1], function(t) return kmax * f(t) end,
      math.max(12, math.ceil(math.abs(s[2]) * 72), math.ceil(s[1] * 40)))
    for i = 2, #seg do pts[#pts + 1] = seg[i] end
    q = seg[#seg]
  end
  return pts, a
end

-- A penman's oval loop: from p heading `a`, the pen circles an oval rx by
-- ry (along and across the heading) while drifting `drift` forward, so it
-- leaves along the heading it came in on, `drift` further on, having crossed
-- its own entry. `side` 1 loops to the left of travel, -1 to the right.
function M.loop(p, a, rx, ry, drift, side)
  local pts = {}
  local n = 72
  for i = 0, n do
    local th = -pi / 2 + 2 * pi * i / n
    local x = rx * cos(th) + drift * i / n
    local y = side * ry * (sin(th) + 1)
    pts[#pts + 1] = { p[1] + x * cos(a) - y * sin(a), p[2] + x * sin(a) + y * cos(a) }
  end
  return pts
end

-- A pen curl off a stem: from p heading `a`, sweeping `dir` (1
-- anticlockwise) and winding in, `s` long. Points.
function M.sprig(p, a, s, dir, turns)
  return (M.path(p, a, { { s * 0.35, dir * 0.06, "c" }, { s * 0.65, dir * (turns or 1.05), "in" } }))
end

-- Points of `pts` moved `d` along their left normal: an echo line, as a
-- flourisher traces a second hairline beside the first.
function M.echo(pts, d)
  local out, n = {}, #pts
  for i = 1, n do
    local a = G.angle(pts[math.max(1, i - 1)], pts[math.min(n, i + 1)])
    out[i] = G.polar(pts[i], a + pi / 2, d)
  end
  return out
end

-- Points mirrored about the vertical line x = cx (d = -1), or as they are.
function M.mirror(pts, cx, d)
  if d == 1 then return pts end
  local out = {}
  for i, p in ipairs(pts) do out[i] = { 2 * cx - p[1], p[2] } end
  return out
end

-- Points turned half a turn about (cx, cy).
function M.rotate(pts, cx, cy)
  local out = {}
  for i, p in ipairs(pts) do out[i] = { 2 * cx - p[1], 2 * cy - p[2] } end
  return out
end

-- Box {x0, y0, x1, y1} round a list of point lists.
function M.extent(lists)
  local b = { math.huge, math.huge, -math.huge, -math.huge }
  for _, pts in ipairs(lists) do
    for _, p in ipairs(pts) do
      b[1], b[2] = math.min(b[1], p[1]), math.min(b[2], p[2])
      b[3], b[4] = math.max(b[3], p[1]), math.max(b[4], p[2])
    end
  end
  return b
end

-- A map that scales point lists drawn in their own units by one factor so
-- that `ext` (their extent) fits box b less `pad` all round, centred.
-- Returns map(pts) and the scale.
function M.fit(ext, b, pad)
  pad = pad or 0
  local w, h = ext[3] - ext[1], ext[4] - ext[2]
  local s = math.min((b[3] - b[1] - 2 * pad) / math.max(w, 1e-6), (b[4] - b[2] - 2 * pad) / math.max(h, 1e-6))
  local ox = (b[1] + b[3]) / 2 - s * (ext[1] + ext[3]) / 2
  local oy = (b[2] + b[4]) / 2 - s * (ext[2] + ext[4]) / 2
  return function(pts)
    local out = {}
    for i, p in ipairs(pts) do out[i] = { ox + s * p[1], oy + s * p[2] } end
    return out
  end, s
end

-- Moving average of list `v` over `r` neighbours either side.
local function smooth(v, r)
  local out, n = {}, #v
  for i = 1, n do
    local sum, c = 0, 0
    for j = math.max(1, i - r), math.min(n, i + r) do sum, c = sum + v[j], c + 1 end
    out[i] = sum / c
  end
  return out
end

-- The outline of a pointed-pen stroke along `pts` (in travel order), as a
-- closed point list. Options, widths as half-widths in pt:
--   hair    the hairline (default 0.18)
--   shade   the fullest shade (default 1.2)
--   down    the pen's pull direction, radians (default straight down;
--           a slanted hand pulls along its slant)
--   taper   share of the length over which each end thins to a hairline
--           (default 0.06; {start, finish} for each end)
--   step    resampling step, pt (default 0.5)
function M.pointed(pts, o)
  o = o or {}
  local hair, shade = o.hair or 0.18, o.shade or 1.2
  local n = math.max(8, math.ceil(G.length(pts) / (o.step or 0.5)))
  local q = G.resample(pts, n)
  local dx, dy = cos(o.down or -pi / 2), sin(o.down or -pi / 2)
  local s = {}
  for i = 1, n do
    local a, b = q[math.max(1, i - 1)], q[math.min(n, i + 1)]
    local tx, ty = b[1] - a[1], b[2] - a[2]
    local l = math.sqrt(tx * tx + ty * ty)
    local pull = l > 0 and (tx * dx + ty * dy) / l or 0
    s[i] = math.max(0, pull) ^ 1.6
  end
  -- Pressure builds and eases over a few points, not instantly.
  s = smooth(s, math.max(2, math.floor(n * 0.025)))
  local t0 = type(o.taper) == "table" and o.taper[1] or o.taper or 0.06
  local t1 = type(o.taper) == "table" and o.taper[2] or o.taper or 0.06
  local w = {}
  for i = 1, n do
    local t = (i - 1) / (n - 1)
    local env = G.smoothstep(0, math.max(t0, 1e-6), t) * G.smoothstep(0, math.max(t1, 1e-6), 1 - t)
    w[i] = hair * (0.55 + 0.45 * env) + (shade - hair) * s[i] * env
  end
  return G.ribbon(q, function(t) return w[math.floor(t * (n - 1) + 0.5) + 1] end)
end

-- The outline of a broad-nib stroke: width follows the angle between the
-- travel and the nib's edge, held at `angle` (default 30 degrees), from
-- `hair` to `nib` (half-widths, pt).
function M.broad(pts, o)
  o = o or {}
  local hair, nib, ang = o.hair or 0.15, o.nib or 1, o.angle or pi / 6
  local n = math.max(8, math.ceil(G.length(pts) / (o.step or 0.5)))
  local q = G.resample(pts, n)
  local w = {}
  for i = 1, n do
    local a, b = q[math.max(1, i - 1)], q[math.min(n, i + 1)]
    local t = (i - 1) / (n - 1)
    local env = G.smoothstep(0, 0.05, t) * G.smoothstep(0, 0.05, 1 - t)
    w[i] = hair + (nib - hair) * math.abs(sin(G.angle(a, b) - ang)) * env
  end
  return G.ribbon(q, function(t) return w[math.floor(t * (n - 1) + 0.5) + 1] end)
end

-- A hairline (monoline) stroke outline along `pts`, `w` half-wide, thinning
-- at its finish.
function M.hairline(pts, w, finish)
  local n = math.max(6, math.ceil(G.length(pts) / 0.6))
  local q = G.resample(pts, n)
  return G.ribbon(q, function(t) return w * (1 - (1 - (finish or 1)) * t) end)
end

return M
