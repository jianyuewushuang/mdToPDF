-- Plane geometry for the generator: points are {x, y} arrays in TeX points.
--
-- Paths handed to the emitter are command lists:
--   {"m", x, y}  {"l", x, y}  {"c", x1, y1, x2, y2, x, y}  {"o", x, y, r}  {"z"}

local G = {}

local sin, cos, sqrt, atan, pi = math.sin, math.cos, math.sqrt, math.atan, math.pi
local floor = math.floor

function G.lerp(a, b, t)
  return a + (b - a) * t
end

function G.clamp(x, a, b)
  return x < a and a or (x > b and b or x)
end

function G.smoothstep(a, b, x)
  local t = G.clamp((x - a) / (b - a), 0, 1)
  return t * t * (3 - 2 * t)
end

function G.dist(p, q)
  local dx, dy = q[1] - p[1], q[2] - p[2]
  return sqrt(dx * dx + dy * dy)
end

function G.angle(p, q)
  return atan(q[2] - p[2], q[1] - p[1])
end

function G.polar(p, ang, r)
  return { p[1] + r * cos(ang), p[2] + r * sin(ang) }
end

function G.mix(p, q, t)
  return { p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t }
end

-- Rotate by `ang`, scale by `s` (or sx, sy), then translate to (ox, oy).
function G.transform(pts, ox, oy, ang, sx, sy)
  sx = sx or 1
  sy = sy or sx
  local c, s = cos(ang or 0), sin(ang or 0)
  local out = {}
  for i, p in ipairs(pts) do
    local x, y = p[1] * sx, p[2] * sy
    out[i] = { ox + x * c - y * s, oy + x * s + y * c }
  end
  return out
end

-- Scale a polygon toward a fixed point.
function G.toward(pts, cx, cy, s)
  local out = {}
  for i, p in ipairs(pts) do
    out[i] = { cx + (p[1] - cx) * s, cy + (p[2] - cy) * s }
  end
  return out
end

function G.bbox(pts)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(pts) do
    if p[1] < x0 then x0 = p[1] end
    if p[1] > x1 then x1 = p[1] end
    if p[2] < y0 then y0 = p[2] end
    if p[2] > y1 then y1 = p[2] end
  end
  return x0, y0, x1, y1
end

function G.area(pts)
  local a, n = 0, #pts
  for i = 1, n do
    local p, q = pts[i], pts[i % n + 1]
    a = a + p[1] * q[2] - q[1] * p[2]
  end
  return a / 2
end

function G.centroid(pts)
  local x, y = 0, 0
  for _, p in ipairs(pts) do
    x, y = x + p[1], y + p[2]
  end
  return { x / #pts, y / #pts }
end

-- A sampler of points inside `pts` (even-odd rule), close to uniform by
-- area. The polygon is cut into horizontal rows `h` pt tall; each row's
-- inside spans are found once, then a sample picks a row by its inside
-- length, a span within it and a point in that span. Points may stray up to
-- h/2 past the outline vertically, so use it for paint that is clipped.
-- Returns sample(rng) -> x, y, or nil for a degenerate polygon.
function G.span_sampler(pts, h)
  local _, y0, _, y1 = G.bbox(pts)
  local n = #pts
  local rows, cum, total = {}, {}, 0
  for y = y0 + h / 2, y1, h do
    local xs = {}
    local j = n
    for i = 1, n do
      local a, b = pts[i], pts[j]
      if (a[2] > y) ~= (b[2] > y) then
        xs[#xs + 1] = (b[1] - a[1]) * (y - a[2]) / (b[2] - a[2]) + a[1]
      end
      j = i
    end
    table.sort(xs)
    local len = 0
    for k = 1, #xs - 1, 2 do len = len + xs[k + 1] - xs[k] end
    if len > 0 then
      total = total + len
      rows[#rows + 1] = { y = y, xs = xs }
      cum[#cum + 1] = total
    end
  end
  if total <= 0 then return nil end
  return function(rng)
    local u = rng:next() * total
    local lo, hi = 1, #cum
    while lo < hi do
      local mid = (lo + hi) // 2
      if cum[mid] < u then lo = mid + 1 else hi = mid end
    end
    local row = rows[lo]
    local into = u - (cum[lo - 1] or 0)
    local xs = row.xs
    for k = 1, #xs - 1, 2 do
      local w = xs[k + 1] - xs[k]
      if into <= w or k + 2 > #xs - 1 then
        return xs[k] + math.min(into, w), row.y + (rng:next() - 0.5) * h
      end
      into = into - w
    end
  end
end

-- Even-odd point-in-polygon test.
function G.inside(pts, x, y)
  local c, n = false, #pts
  local j = n
  for i = 1, n do
    local pi_, pj = pts[i], pts[j]
    if (pi_[2] > y) ~= (pj[2] > y)
      and x < (pj[1] - pi_[1]) * (y - pi_[2]) / (pj[2] - pi_[2]) + pi_[1] then
      c = not c
    end
    j = i
  end
  return c
end

-- Smooth value noise on [0, period): returns f(x) in [-1, 1]. Periodic noise
-- lets a closed contour wobble without a seam.
function G.noise(rng, period)
  period = period or 64
  local v = {}
  for i = 0, period - 1 do
    v[i] = rng:next() * 2 - 1
  end
  return function(x)
    local i = floor(x)
    local f = x - i
    local a, b = v[i % period], v[(i + 1) % period]
    f = f * f * (3 - 2 * f)
    return a + (b - a) * f
  end
end

-- Two octaves of periodic noise.
function G.fbm(rng, period)
  local n1, n2 = G.noise(rng, period), G.noise(rng, period * 2)
  return function(x)
    return 0.7 * n1(x) + 0.3 * n2(x * 2)
  end
end

-- Catmull-Rom spline through points, as a Bezier command list.
function G.smooth(pts, closed, tension)
  local k = (tension or 1) / 6
  local n = #pts
  local cmds = { { "m", pts[1][1], pts[1][2] } }
  if n < 3 then
    for i = 2, n do
      cmds[#cmds + 1] = { "l", pts[i][1], pts[i][2] }
    end
    if closed then cmds[#cmds + 1] = { "z" } end
    return cmds
  end
  local function at(i)
    if closed then
      return pts[(i - 1) % n + 1]
    end
    return pts[G.clamp(i, 1, n)]
  end
  local last = closed and n or n - 1
  for i = 1, last do
    local p0, p1, p2, p3 = at(i - 1), at(i), at(i + 1), at(i + 2)
    cmds[#cmds + 1] = {
      "c",
      p1[1] + (p2[1] - p0[1]) * k, p1[2] + (p2[2] - p0[2]) * k,
      p2[1] - (p3[1] - p1[1]) * k, p2[2] - (p3[2] - p1[2]) * k,
      p2[1], p2[2],
    }
  end
  if closed then cmds[#cmds + 1] = { "z" } end
  return cmds
end

function G.polyline(pts, closed)
  local cmds = { { "m", pts[1][1], pts[1][2] } }
  for i = 2, #pts do
    cmds[#cmds + 1] = { "l", pts[i][1], pts[i][2] }
  end
  if closed then cmds[#cmds + 1] = { "z" } end
  return cmds
end

-- Densify a polyline with Catmull-Rom interpolation, `per` samples per span.
function G.spline_points(pts, per)
  local n, out = #pts, {}
  if n < 2 then return { pts[1] } end
  local function at(i) return pts[G.clamp(i, 1, n)] end
  for i = 1, n - 1 do
    local p0, p1, p2, p3 = at(i - 1), at(i), at(i + 1), at(i + 2)
    for s = 0, per - 1 do
      local t = s / per
      local t2, t3 = t * t, t * t * t
      local function cr(a, b, c, d)
        return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2
          + (-a + 3 * b - 3 * c + d) * t3)
      end
      out[#out + 1] = { cr(p0[1], p1[1], p2[1], p3[1]), cr(p0[2], p1[2], p2[2], p3[2]) }
    end
  end
  out[#out + 1] = { pts[n][1], pts[n][2] }
  return out
end

function G.length(pts)
  local L = 0
  for i = 2, #pts do
    L = L + G.dist(pts[i - 1], pts[i])
  end
  return L
end

-- Point and unit tangent at arclength fraction t of a polyline.
function G.at(pts, t)
  local total = G.length(pts)
  local target = G.clamp(t, 0, 1) * total
  for i = 2, #pts do
    local d = G.dist(pts[i - 1], pts[i])
    if target <= d or i == #pts then
      local f = d > 0 and G.clamp(target / d, 0, 1) or 0
      local p = G.mix(pts[i - 1], pts[i], f)
      return p, G.angle(pts[i - 1], pts[i])
    end
    target = target - d
  end
  return pts[#pts], 0
end

-- Resample a polyline to `n` points evenly spaced by arclength.
-- Each point is exactly G.at(pts, i / (n - 1)); the segment lengths are
-- measured once rather than once per point.
function G.resample(pts, n)
  local m = #pts
  local ds, total = {}, 0
  for i = 2, m do
    local d = G.dist(pts[i - 1], pts[i])
    ds[i] = d
    total = total + d
  end
  local out = {}
  for i = 0, n - 1 do
    local target = G.clamp(i / (n - 1), 0, 1) * total
    local p = pts[m]
    for k = 2, m do
      local d = ds[k]
      if target <= d or k == m then
        p = G.mix(pts[k - 1], pts[k], d > 0 and G.clamp(target / d, 0, 1) or 0)
        break
      end
      target = target - d
    end
    out[#out + 1] = p
  end
  return out
end

-- Closed outline around a centerline whose half-width at fraction t is w(t).
-- Ends are capped with a short round so tapered strokes keep a soft tip.
-- Where a point's neighbours coincide (closer than 1e-9 pt) the heading
-- carries over from the point before (0 at the start), so a line of one
-- repeated point still gets a fixed normal rather than one rounding noise
-- picks.
function G.ribbon(pts, w)
  local n = #pts
  local left, right = {}, {}
  local heading = 0
  for i = 1, n do
    local a = pts[math.max(i - 1, 1)]
    local b = pts[math.min(i + 1, n)]
    if math.abs(b[1] - a[1]) + math.abs(b[2] - a[2]) > 1e-9 then heading = G.angle(a, b) end
    local ang = heading + pi / 2
    local hw = w((i - 1) / (n - 1))
    left[i] = G.polar(pts[i], ang, hw)
    right[i] = G.polar(pts[i], ang, -hw)
  end
  local out = {}
  for i = 1, n do out[#out + 1] = left[i] end
  for i = n, 1, -1 do out[#out + 1] = right[i] end
  return out
end

-- Displace each vertex along a random direction; used for wash layers.
function G.deform(pts, rng, amp)
  local nz = G.noise(rng, #pts)
  local nz2 = G.noise(rng, #pts)
  local out = {}
  for i, p in ipairs(pts) do
    local x = (i - 1) * 0.35
    out[i] = { p[1] + amp * nz(x), p[2] + amp * nz2(x) }
  end
  return out
end

-- A stem-like curve from p heading `ang`, bending by `bend` radians over its
-- length and curling by `curl` near the end. Returns sample points.
function G.curve(p, ang, len, bend, curl, n)
  n = n or 24
  local pts = { { p[1], p[2] } }
  local x, y = p[1], p[2]
  local step = len / n
  for i = 1, n do
    local t = i / n
    local a = ang + bend * t + (curl or 0) * t ^ 4
    x, y = x + step * cos(a), y + step * sin(a)
    pts[#pts + 1] = { x, y }
  end
  return pts
end

-- A curve grown from p at `heading` whose curvature (radians per pt) at
-- fraction t of its length is kfun(t). Because heading changes only through
-- curvature, the result has no corners: curls tighten and loops close
-- smoothly.
function G.flow(p, heading, len, kfun, n)
  if not n then
    -- Enough steps that no step turns more than about 7 degrees, judged
    -- by the sharpest curvature along the curve.
    local kmax = 0
    for i = 0, 63 do kmax = math.max(kmax, math.abs(kfun((i + 0.5) / 64))) end
    n = math.max(8, math.ceil(len / 1.5), math.ceil(len * kmax / 0.12))
  end
  local step = len / n
  local x, y, a = p[1], p[2], heading
  local pts = { { x, y } }
  for i = 1, n do
    a = a + kfun((i - 0.5) / n) * step
    x, y = x + step * cos(a), y + step * sin(a)
    pts[#pts + 1] = { x, y }
  end
  return pts, a
end

-- Total turning, in turns, of a curvature profile k(t) = c * t^pw over len.
-- Returns c such that the curve turns `turns` full circles.
function G.curl_coefficient(len, turns, pw)
  return 2 * pi * turns * (pw + 1) / len
end

function G.bezier(p0, p1, p2, p3, n)
  n = n or 16
  local out = {}
  for i = 0, n do
    local t = i / n
    local u = 1 - t
    local a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
    out[#out + 1] = {
      a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1],
      a * p0[2] + b * p1[2] + c * p2[2] + d * p3[2],
    }
  end
  return out
end

-- A smooth stem from p0, leaving along heading dir0, to p1, arriving along
-- heading dir1. Handles are a fraction `k` of the chord, so a branch peels off
-- its parent tangentially and sweeps into its target.
function G.link(p0, dir0, p1, dir1, k, n)
  local h = G.dist(p0, p1) * (k or 0.5)
  return G.bezier(p0, G.polar(p0, dir0, h), G.polar(p1, dir1 + pi, h), p1,
    n or math.max(12, math.ceil(G.dist(p0, p1) / 1.2)))
end

-- Smallest signed difference a - b, in (-pi, pi].
function G.turn(a, b)
  local d = (a - b) % (2 * pi)
  if d > pi then d = d - 2 * pi end
  return d
end

-- The heading a branch takes off a stem with tangent `along`: whichever way
-- along the stem faces the target, turned by `bias` toward it, so branches
-- peel away tangentially instead of meeting the stem at an angle.
function G.depart(p, along, target, bias)
  local want = G.angle(p, target)
  local fwd = math.abs(G.turn(want, along)) <= pi / 2 and along or along + pi
  local side = G.turn(want, fwd) >= 0 and 1 or -1
  return fwd + side * (bias or 0.3)
end

-- Grow a stem by steering, as a plant does, rather than by fitting a curve
-- through points. From `p` along `heading`, each step of `o.step` pt turns
-- toward the point target_at(q, s, heading) returns (pure pursuit: the
-- curvature that would arc onto it). Curvature is held to `o.kmax` (1/pt)
-- and changes by at most `o.dk` per pt, so bends build and relax gradually
-- and never stack into kinks. Growth stops after `o.len` pt, when
-- target_at returns nil, or when o.stop(q) is true. Returns the points and
-- the final heading.
function G.pursue(p, heading, target_at, o)
  local step, kmax, dk = o.step or 2, o.kmax or 1 / 30, o.dk or 1 / 900
  local pts = { { p[1], p[2] } }
  local a, k, s = heading, o.k0 or 0, 0
  local x, y = p[1], p[2]
  while s < o.len do
    local t = target_at({ x, y }, s, a)
    if not t then break end
    local d = math.max(1e-6, G.dist({ x, y }, t))
    local want = G.clamp(2 * math.sin(G.turn(G.angle({ x, y }, t), a)) / d, -kmax, kmax)
    k = k + G.clamp(want - k, -dk * step, dk * step)
    a = a + k * step
    x, y = x + step * cos(a), y + step * sin(a)
    if o.stop and o.stop({ x, y }) then break end
    pts[#pts + 1] = { x, y }
    s = s + step
  end
  return pts, a
end

-- A target function for G.pursue that leads along polyline `guide`: the
-- grower's nearest guide point is tracked (never moving backward), and the
-- target lies `ahead` pt further along the guide. Measuring ahead along the
-- guide rather than from the grower keeps the target moving even when the
-- grower is pushed off the guide. Returns nil once the grower is within
-- `finish` pt of the guide's end.
function G.follow(guide, ahead, finish)
  local cum = { 0 }
  for i = 2, #guide do cum[i] = cum[i - 1] + G.dist(guide[i - 1], guide[i]) end
  local j = 1
  local last = guide[#guide]
  return function(q)
    if G.dist(q, last) < (finish or 2) then return nil end
    local best, bd = j, G.dist(guide[j], q)
    for i = j + 1, math.min(#guide, j + 40) do
      local d = G.dist(guide[i], q)
      if d < bd then best, bd = i, d end
    end
    j = best
    local k = j
    while k < #guide and cum[k] - cum[j] < ahead do k = k + 1 end
    return guide[k]
  end
end

G.pi = pi
return G
