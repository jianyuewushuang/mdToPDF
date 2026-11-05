-- An oval as a plant's frame (frames.lua): the plant grows along the curve
-- as it grows up a straight margin. A frame point (x, y) lies at arclength
-- s0 + y along the oval, x - xc along the inward normal; so the frame's
-- left margin wraps round the outside of the oval and its text block lies
-- inside it.
--
-- The oval is walked clockwise from its foot: arclength 0 is the bottom
-- centre, a quarter of the way round is the leftmost point. Positions and
-- normals are taken from the ellipse itself, so the map is smooth; only
-- the arclength-to-angle table is sampled.

local M = {}
local O = {}
O.__index = O
local pi = math.pi
local N = 1440

-- The oval centred at (cx, cy) with half-width a and half-height b.
function M.new(cx, cy, a, b)
  local o = setmetatable({ cx = cx, cy = cy, a = a, b = b, th = {}, s = { 0 } }, O)
  local px, py
  for i = 0, N do
    local th = -pi / 2 - 2 * pi * i / N
    local x, y = cx + a * math.cos(th), cy + b * math.sin(th)
    o.th[i + 1] = th
    if i > 0 then o.s[i + 1] = o.s[i] + math.sqrt((x - px) ^ 2 + (y - py) ^ 2) end
    px, py = x, y
  end
  o.len = o.s[N + 1]
  return o
end

-- The angle at arclength s, any real s.
function O:theta(s)
  s = s % self.len
  local S = self.s
  local lo, hi = 1, N + 1
  while hi - lo > 1 do
    local mid = (lo + hi) // 2
    if S[mid] <= s then lo = mid else hi = mid end
  end
  local u = (s - S[lo]) / (S[hi] - S[lo])
  return self.th[lo] + (self.th[hi] - self.th[lo]) * u
end

-- The arclength at angle th, in [0, len).
function O:arclength(th)
  local k = ((-pi / 2 - th) / (2 * pi) % 1) * N
  local i = math.floor(k)
  return self.s[i + 1] + (self.s[i + 2] - self.s[i + 1]) * (k - i)
end

-- The point and inward unit normal at angle th.
function O:point(th)
  local x, y = self.cx + self.a * math.cos(th), self.cy + self.b * math.sin(th)
  -- Walking clockwise the heading is (a sin, -b cos); inward is its right.
  local tx, ty = self.a * math.sin(th), -self.b * math.cos(th)
  local l = math.sqrt(tx * tx + ty * ty)
  return x, y, ty / l, -tx / l
end

-- The angle of the oval point nearest (px, py).
function O:nearest(px, py)
  local best, bd = 0, math.huge
  for i = 0, 359 do
    local th = -pi / 2 - 2 * pi * i / 360
    local x, y = self.cx + self.a * math.cos(th), self.cy + self.b * math.sin(th)
    local d = (x - px) ^ 2 + (y - py) ^ 2
    if d < bd then best, bd = th, d end
  end
  -- Newton steps on (P - p) . P' = 0.
  local a, b = self.a, self.b
  for _ = 1, 6 do
    local c, s = math.cos(best), math.sin(best)
    local ex, ey = self.cx + a * c - px, self.cy + b * s - py
    local f = ex * (-a * s) + ey * (b * c)
    local df = (a * s) ^ 2 + (b * c) ^ 2 + ex * (-a * c) + ey * (-b * s)
    if math.abs(df) < 1e-9 then break end
    best = best - f / df
  end
  return best
end

-- The maps between a frame laid along the oval and the page: the frame's
-- y = 0 lies at arclength s0, its x = xc on the curve. `mirror` reflects
-- the result about the oval's vertical axis, for the right-hand plant.
-- The inverse returns frame y in (-len/4, 3 len/4], so a point past the
-- frame's foot comes back below it rather than beyond its top.
function O:maps(s0, xc, mirror)
  local cx = self.cx
  local function fn(x, y)
    local px, py, nx, ny = self:point(self:theta(s0 + y))
    local d = x - xc
    px, py = px + nx * d, py + ny * d
    if mirror then px = 2 * cx - px end
    return px, py
  end
  local function inv(px, py)
    if mirror then px = 2 * cx - px end
    local th = self:nearest(px, py)
    local x, y, nx, ny = self:point(th)
    local s = self:arclength(th)
    if s > self.len * 0.75 then s = s - self.len end
    return xc + (px - x) * nx + (py - y) * ny, s - s0
  end
  return fn, inv
end

return M
