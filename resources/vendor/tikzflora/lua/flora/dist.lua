-- Size distributions drawn as curves. A curve is
--   { range = { lo, hi }, points = { { x1, w1 }, ..., { xn, wn } } }
-- with control points at x (0-1 across the range, increasing) and weight w.
-- The density between them is a monotone cubic spline (Fritsch-Carlson):
-- smooth, but never overshooting its points, so it stays non-negative and
-- peaks only where a point is placed. The older form
--   { range = { lo, hi }, weights = { w1, ..., wn } }
-- places the weights evenly with straight lines between them. The tuner's
-- curve editor (tuner/src/lib/spline.js) draws the same spline.

local D = {}

-- Slopes for a monotone cubic through (xs[i], ys[i]).
local function slopes(xs, ys)
  local n = #xs
  local d, m = {}, {}
  for i = 1, n - 1 do d[i] = (ys[i + 1] - ys[i]) / math.max(1e-9, xs[i + 1] - xs[i]) end
  m[1], m[n] = d[1], d[n - 1]
  for i = 2, n - 1 do
    m[i] = (d[i - 1] * d[i] <= 0) and 0 or (d[i - 1] + d[i]) / 2
  end
  for i = 1, n - 1 do
    if d[i] == 0 then
      m[i], m[i + 1] = 0, 0
    else
      local a, b = m[i] / d[i], m[i + 1] / d[i]
      local s = a * a + b * b
      if s > 9 then
        local t = 3 / math.sqrt(s)
        m[i], m[i + 1] = t * a * d[i], t * b * d[i]
      end
    end
  end
  return m
end

-- The spline through `points` ({x, w} pairs, x increasing) as a function
-- of x in [0, 1]; flat beyond the end points.
function D.spline(points)
  local xs, ys = {}, {}
  for i, p in ipairs(points) do xs[i], ys[i] = p[1], math.max(0, p[2]) end
  local n = #xs
  if n == 1 then return function() return ys[1] end end
  local m = slopes(xs, ys)
  return function(x)
    if x <= xs[1] then return ys[1] end
    if x >= xs[n] then return ys[n] end
    local i = 1
    while xs[i + 1] < x do i = i + 1 end
    local h = xs[i + 1] - xs[i]
    local t = (x - xs[i]) / h
    local t2, t3 = t * t, t * t * t
    return (2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h * m[i]
      + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h * m[i + 1]
  end
end

-- Evenly spaced weights for a curve: its own, or the spline sampled finely.
local function weights_of(c)
  if c.weights then return c.weights end
  local f = D.spline(c.points)
  local w = {}
  for i = 0, 64 do w[i + 1] = math.max(0, f(i / 64)) end
  return w
end

-- Draw one value from curve `c`.
function D.sample(rng, c)
  local lo, hi = c.range[1], c.range[2]
  local w = weights_of(c)
  local n = #w
  if n < 2 then return lo + (hi - lo) * rng:next() end
  local total = 0
  for i = 1, n - 1 do total = total + (math.max(0, w[i]) + math.max(0, w[i + 1])) / 2 end
  if total <= 0 then return lo + (hi - lo) * rng:next() end
  local r = rng:next() * total
  for i = 1, n - 1 do
    local a, b = math.max(0, w[i]), math.max(0, w[i + 1])
    local mass = (a + b) / 2
    if r <= mass or i == n - 1 then
      r = math.min(r, mass)
      -- Inverse of the segment's CDF, a t + (b - a) t^2 / 2 = r.
      local t
      if math.abs(b - a) < 1e-9 then
        t = a > 0 and r / a or 0.5
      else
        t = (-a + math.sqrt(math.max(0, a * a + 2 * (b - a) * r))) / (b - a)
      end
      t = math.min(1, math.max(0, t))
      return lo + (hi - lo) * ((i - 1) + t) / (n - 1)
    end
    r = r - mass
  end
  return hi
end

return D
