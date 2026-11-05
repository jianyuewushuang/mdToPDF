-- The growth clock for "watch it grow" frames (spec.grow, 0-1).
--
-- Every point of the page gets a birth time: its distance from the plant's
-- root, measured along the stems and then across the page to the nearest
-- stem (a Dijkstra field over the occupancy grid). At frame time T the
-- growth front has reached u = T * span; stems are revealed up to it,
-- leaves unfurl and blooms open as it passes them, and the ornaments and
-- gilt come last.
--
-- Planning never changes with T. Painting does only through clips, scaling
-- about an anchor and leaving whole elements out, and an element left out
-- is still painted and then withdrawn, so every random stream is consumed
-- exactly as in the finished page and nothing changes its look from frame
-- to frame. compose.lua uses the clock only for T < 1, so the last frame is
-- the finished page itself.

local G = require("flora.geom")

local K = {}
K.__index = K

local sqrt, min, max, floor = math.sqrt, math.min, math.max, math.floor
local INF = math.huge

-- A binary min-heap of {key, cell}.
local function heap()
  local h = { n = 0 }
  function h.push(k, v)
    h.n = h.n + 1
    local i = h.n
    h[i] = { k, v }
    while i > 1 do
      local p = i // 2
      if h[p][1] <= h[i][1] then break end
      h[p], h[i] = h[i], h[p]
      i = p
    end
  end
  function h.pop()
    local top = h[1]
    h[1] = h[h.n]
    h[h.n] = nil
    h.n = h.n - 1
    local i = 1
    while true do
      local l, r, s = 2 * i, 2 * i + 1, i
      if l <= h.n and h[l][1] < h[s][1] then s = l end
      if r <= h.n and h[r][1] < h[s][1] then s = r end
      if s == i then break end
      h[s], h[i] = h[i], h[s]
      i = s
    end
    return top
  end
  return h
end

-- Arc length at each point of `pts`.
local function arcs(pts)
  local out, d = { 0 }, 0
  for i = 2, #pts do
    d = d + G.dist(pts[i - 1], pts[i])
    out[i] = d
  end
  return out
end

-- A clock for frame time T over grid g (space.lua) and `stems` (each with
-- pts; the first is rooted at the plant's root). Each stem starts when the
-- growth front reaches its first point along the stems before it.
function K.new(g, stems, T)
  local self = setmetatable({ g = g, T = T }, K)
  local nx, ny, c = g.nx, g.ny, g.c
  self.offset, self.arc = {}, {}
  local reach = 0
  for i, s in ipairs(stems) do
    local a = arcs(s.pts)
    local off = 0
    if i > 1 then
      off = INF
      local p0 = s.pts[1]
      for j = 1, i - 1 do
        local sj, aj = stems[j].pts, self.arc[stems[j]]
        for k = 1, #sj, 2 do
          local d = self.offset[stems[j]] + aj[k] + G.dist(p0, sj[k])
          if d < off then off = d end
        end
      end
    end
    self.offset[s], self.arc[s] = off, a
    reach = max(reach, off + a[#a])
  end
  -- The field: stem points are sources; distance spreads over the grid.
  local f = {}
  for k = 0, nx * ny - 1 do f[k] = INF end
  local h = heap()
  local function seed(x, y, d)
    local i, j = floor(x / c), floor(y / c)
    if i < 0 or j < 0 or i >= nx or j >= ny then return end
    local k = j * nx + i
    if d < f[k] then
      f[k] = d
      h.push(d, k)
    end
  end
  for _, s in ipairs(stems) do
    local off, a = self.offset[s], self.arc[s]
    for k, p in ipairs(s.pts) do seed(p[1], p[2], off + a[k]) end
  end
  local diag = c * sqrt(2)
  local steps = { { 1, 0, c }, { -1, 0, c }, { 0, 1, c }, { 0, -1, c },
    { 1, 1, diag }, { 1, -1, diag }, { -1, 1, diag }, { -1, -1, diag } }
  while h.n > 0 do
    local top = h.pop()
    local d, k = top[1], top[2]
    if d <= f[k] then
      local i, j = k % nx, k // nx
      for _, st in ipairs(steps) do
        local ii, jj = i + st[1], j + st[2]
        if ii >= 0 and jj >= 0 and ii < nx and jj < ny then
          local kk = jj * nx + ii
          local nd = d + st[3]
          if nd < f[kk] then
            f[kk] = nd
            h.push(nd, kk)
          end
        end
      end
    end
  end
  self.f = f
  self.reach = reach
  -- The front sweeps the stems in the first 75% of the clip; blooms open
  -- and the gilt arrives in the rest.
  self.span = reach / 0.75
  self.u = T * self.span
  return self
end

-- Birth time (in pt of growth) at (x, y).
function K:birth(x, y)
  local c, nx = self.g.c, self.g.nx
  local i, j = floor(x / c), floor(y / c)
  i, j = max(0, min(nx - 1, i)), max(0, min(self.g.ny - 1, j))
  local d = self.f[j * nx + i]
  if d == INF then return self.reach end
  return d
end

-- Progress 0-1 of something born at `b` that takes `dur` (share of the
-- span) to complete.
function K:progress(b, dur)
  return max(0, min(1, (self.u - b) / (dur * self.span)))
end

function K:born(x, y)
  return self:birth(x, y) <= self.u
end

-- Paint fn() and withdraw everything it painted: its randomness is spent
-- as in the finished page but nothing shows.
local function withdrawn(pt, fn)
  local n0, c0 = #pt.out, pt.count
  local probe, group = pt.probe, pt.group
  pt.probe, pt.group = nil, nil
  fn()
  for i = #pt.out, n0 + 1, -1 do pt.out[i] = nil end
  pt.count = c0
  pt.probe, pt.group = probe, group
end

-- Paint fn() scaled by k about `anchor`, inside whatever frame is set.
local function scaled(pt, anchor, k, fn)
  local base = pt.frame_fn
  local ax, ay = anchor[1], anchor[2]
  pt:frame(function(x, y)
    x, y = ax + (x - ax) * k, ay + (y - ay) * k
    if base then return base(x, y) end
    return x, y
  end)
  fn()
  pt:frame(base)
end

-- Ease-out: fast start, gentle finish.
local function ease(t)
  return 1 - (1 - t) ^ 3
end

-- Paint element fn(pt) anchored at `at` ({x, y}; nil places it last),
-- growing over `dur` of the span from its birth plus `delay` (pt).
function K:draw(pt, fn, at, dur, delay)
  local b = at and self:birth(at[1], at[2]) + (delay or 0) or self.reach
  local k = self:progress(b, dur or 0.08)
  if k >= 1 then
    fn(pt)
  elseif k <= 0 then
    withdrawn(pt, function() fn(pt) end)
  else
    scaled(pt, at or { 0, 0 }, 0.15 + 0.85 * ease(k), function() fn(pt) end)
  end
end

-- Paint stem s with paint(pt) (a full stem), revealed up to the front.
function K:stem(pt, s, wmax, paint)
  local off, a = self.offset[s], self.arc[s]
  local len = a and a[#a] or 0
  local shown = a and self.u - off or 0
  if shown >= len then
    paint(pt)
  elseif shown <= 0 then
    withdrawn(pt, function() paint(pt) end)
  else
    local prefix = {}
    for i, p in ipairs(s.pts) do
      if a[i] > shown then break end
      prefix[#prefix + 1] = p
    end
    if #prefix < 2 then
      withdrawn(pt, function() paint(pt) end)
      return
    end
    local half = wmax / 2 + 2
    pt:clip_begin(G.smooth(G.ribbon(prefix, function() return half end), true))
    paint(pt)
    pt:clip_end()
  end
end

-- Leaflets {x, y, ang, len}, each unfurling from its base, painted one by
-- one with the shared stream as L.leaflets would paint them together.
function K:leaflets(pt, rng, items, leaflets)
  for _, it in ipairs(items) do
    self:draw(pt, function(p) leaflets(p, rng, { it }) end, { it[1], it[2] }, 0.05)
  end
end

-- Sparkle items born after the stems have finished, in turn.
function K:sparkles(items)
  local out = {}
  local k = self:progress(self.reach, 0.2)
  for i, it in ipairs(items) do
    if i <= #items * k then out[#out + 1] = it end
  end
  return out
end

return K
