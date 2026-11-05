-- A small software rasteriser for computed bitmaps (raster gilt,
-- orn_raster.lua). A grid covers a page rectangle at `s` pt per pixel,
-- rows top to bottom as a PDF image stores them; values live in flat
-- arrays indexed (row - 1) * w + col. Everything is plain arithmetic, so
-- texlua (Lua 5.3) and Lua 5.4 compute identical pixels.

local R = {}

local floor, ceil, sqrt, min, max = math.floor, math.ceil, math.sqrt, math.min, math.max
local K = 0.5523  -- circle quarter as a Bezier, as paint.lua draws circles of 2 pt radius and more

-- A grid over page rectangle x0..x1, y0..y1 (pt) at `s` pt per pixel,
-- grown to whole pixels.
function R.grid(x0, y0, x1, y1, s)
  local w, h = max(1, ceil((x1 - x0) / s)), max(1, ceil((y1 - y0) / s))
  return { x0 = x0, y1 = y0 + h * s, w = w, h = h, s = s, n = w * h }
end

-- A flat array of n zeros.
function R.zeros(n)
  local a = {}
  for i = 1, n do a[i] = 0 end
  return a
end

-- Paint path commands as polylines in pixel coordinates (x right, y down;
-- pixel col spans x in [col - 1, col]). Curves become chords no longer
-- than about 1.5 px.
function R.flatten(g, cmds)
  local s, gx, gy = g.s, g.x0, g.y1
  local polys, cur = {}, nil
  local function px(x, y) return (x - gx) / s, (gy - y) / s end
  local function curve(ax, ay, bx, by, cx, cy, dx, dy)
    local len = sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) + sqrt((cx - bx) ^ 2 + (cy - by) ^ 2)
      + sqrt((dx - cx) ^ 2 + (dy - cy) ^ 2)
    local n = max(2, min(96, ceil(len / 1.5)))
    for i = 1, n do
      local t = i / n
      local u = 1 - t
      local a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
      cur[#cur + 1] = a * ax + b * bx + c * cx + d * dx
      cur[#cur + 1] = a * ay + b * by + c * cy + d * dy
    end
  end
  for _, c in ipairs(cmds) do
    local op = c[1]
    if op == "m" then
      cur = {}
      polys[#polys + 1] = cur
      cur[1], cur[2] = px(c[2], c[3])
    elseif op == "l" then
      local x, y = px(c[2], c[3])
      cur[#cur + 1], cur[#cur + 2] = x, y
    elseif op == "c" then
      local ax, ay = cur[#cur - 1], cur[#cur]
      local bx, by = px(c[2], c[3])
      local cx, cy = px(c[4], c[5])
      local dx, dy = px(c[6], c[7])
      curve(ax, ay, bx, by, cx, cy, dx, dy)
    elseif op == "z" then
      if cur and #cur >= 2 then cur[#cur + 1], cur[#cur + 2] = cur[1], cur[2] end
      cur = nil
    elseif op == "o" then
      local x, y, r = c[2], c[3], c[4]
      local k = r * K
      cur = {}
      polys[#polys + 1] = cur
      cur[1], cur[2] = px(x + r, y)
      local q = {
        { x + r, y + k, x + k, y + r, x, y + r }, { x - k, y + r, x - r, y + k, x - r, y },
        { x - r, y - k, x - k, y - r, x, y - r }, { x + k, y - r, x + r, y - k, x + r, y },
      }
      for _, a in ipairs(q) do
        local bx, by = px(a[1], a[2])
        local cx, cy = px(a[3], a[4])
        local dx, dy = px(a[5], a[6])
        curve(cur[#cur - 1], cur[#cur], bx, by, cx, cy, dx, dy)
      end
      cur = nil
    end
  end
  return polys
end

-- Exact horizontal coverage, at SUB sample rows per pixel row.
local SUB = 5

-- Anti-aliased coverage (0-1 per pixel) of closed polylines `polys`,
-- filled by the nonzero rule (or even-odd with `evenodd`), as a flat array
-- over grid g. Each subpath closes itself, as a PDF fill does.
function R.fill(g, polys, evenodd)
  local w, h = g.w, g.h
  local cov = R.zeros(g.n)
  -- Edges as {ytop, ybottom, x at ytop, dx/dy, winding}.
  local edges = {}
  for _, p in ipairs(polys) do
    local n = #p
    if n >= 4 then
      for i = 1, n, 2 do
        local ax, ay = p[i], p[i + 1]
        local j = i + 2 > n and 1 or i + 2
        local bx, by = p[j], p[j + 1]
        if ay ~= by then
          if ay < by then
            edges[#edges + 1] = { ay, by, ax, (bx - ax) / (by - ay), 1 }
          else
            edges[#edges + 1] = { by, ay, bx, (ax - bx) / (ay - by), -1 }
          end
        end
      end
    end
  end
  table.sort(edges, function(a, b) return a[1] < b[1] end)
  local ne, next_e, active = #edges, 1, {}
  local xs, ws, d = {}, {}, {}
  local wsub = 1 / SUB
  local r0 = ne > 0 and max(1, floor(edges[1][1]) + 1) or h + 1
  for row = r0, h do
    for i = 1, w + 1 do d[i] = 0 end
    local base = (row - 1) * w
    for k = 1, SUB do
      local y = row - 1 + (k - 0.5) * wsub
      while next_e <= ne and edges[next_e][1] <= y do
        active[#active + 1] = edges[next_e]
        next_e = next_e + 1
      end
      -- Crossings of this sample row, sorted by x (insertion sort: few).
      local nc, j = 0, 1
      while j <= #active do
        local e = active[j]
        if e[2] <= y then
          active[j] = active[#active]
          active[#active] = nil
        else
          if e[1] <= y then
            local x, wd = e[3] + (y - e[1]) * e[4], e[5]
            nc = nc + 1
            local m = nc
            while m > 1 and xs[m - 1] > x do
              xs[m], ws[m] = xs[m - 1], ws[m - 1]
              m = m - 1
            end
            xs[m], ws[m] = x, wd
          end
          j = j + 1
        end
      end
      local wind = 0
      for c = 1, nc - 1 do
        wind = wind + ws[c]
        local inside = evenodd and (wind % 2 == 1) or (not evenodd and wind ~= 0)
        if inside then
          local a, b = max(0, xs[c]), min(w, xs[c + 1])
          if b > a then
            local ia, ib = floor(a) + 1, floor(b) + 1
            if ia == ib then
              cov[base + ia] = cov[base + ia] + (b - a) * wsub
            else
              cov[base + ia] = cov[base + ia] + (ia - a) * wsub
              if ib <= w then cov[base + ib] = cov[base + ib] + (b - ib + 1) * wsub end
              d[ia + 1] = d[ia + 1] + wsub
              d[ib] = d[ib] - wsub
            end
          end
        end
      end
    end
    local run = 0
    for i = 1, w do
      run = run + d[i]
      local v = cov[base + i] + run
      cov[base + i] = v > 1 and 1 or (v < 0 and 0 or v)
    end
    if next_e > ne and #active == 0 then break end
  end
  return cov
end

-- A stroke `r` px half-wide along open polylines `polys`, with round caps
-- and joins. Returns coverage and, per pixel, the distance in px inside
-- the stroke's edge (r minus the distance to the centre line; negative
-- outside), each a flat array over grid g.
function R.stroke(g, polys, r)
  local w, h = g.w, g.h
  local cov, din = R.zeros(g.n), {}
  for i = 1, g.n do din[i] = -1e9 end
  local reach = r + 1
  for _, p in ipairs(polys) do
    local n = #p
    if n == 2 then p = { p[1], p[2], p[1], p[2] } n = 4 end
    for i = 1, n - 2, 2 do
      local ax, ay, bx, by = p[i], p[i + 1], p[i + 2], p[i + 3]
      local vx, vy = bx - ax, by - ay
      local ll = vx * vx + vy * vy
      local c0, c1 = max(1, floor(min(ax, bx) - reach) + 1), min(w, floor(max(ax, bx) + reach) + 1)
      local q0, q1 = max(1, floor(min(ay, by) - reach) + 1), min(h, floor(max(ay, by) + reach) + 1)
      for row = q0, q1 do
        local py, base = row - 0.5, (row - 1) * w
        for col = c0, c1 do
          local px = col - 0.5
          local t = ll > 0 and ((px - ax) * vx + (py - ay) * vy) / ll or 0
          t = t < 0 and 0 or (t > 1 and 1 or t)
          local dx, dy = px - ax - t * vx, py - ay - t * vy
          local e = r - sqrt(dx * dx + dy * dy)
          local k = base + col
          if e > din[k] then
            din[k] = e
            local c = e + 0.5
            cov[k] = c > 1 and 1 or (c < 0 and 0 or c)
          end
        end
      end
    end
  end
  return cov, din
end

-- Squared distance in px from pixel centres of grid g to the nearest of
-- segments `segs` (flat list x0, y0, x1, y1, ... in px), written into flat
-- array `d2` wherever it is smaller, for pixels within `band` px of a
-- segment. Exact: no pixel staircase.
function R.segment_distance(g, segs, band, d2)
  local w, h = g.w, g.h
  for i = 1, #segs, 4 do
    local ax, ay, bx, by = segs[i], segs[i + 1], segs[i + 2], segs[i + 3]
    local vx, vy = bx - ax, by - ay
    local ll = vx * vx + vy * vy
    local c0, c1 = max(1, floor(min(ax, bx) - band) + 1), min(w, floor(max(ax, bx) + band) + 1)
    local q0, q1 = max(1, floor(min(ay, by) - band) + 1), min(h, floor(max(ay, by) + band) + 1)
    for row = q0, q1 do
      local py, base = row - 0.5, (row - 1) * w
      for col = c0, c1 do
        local px = col - 0.5
        local t = ll > 0 and ((px - ax) * vx + (py - ay) * vy) / ll or 0
        t = t < 0 and 0 or (t > 1 and 1 or t)
        local dx, dy = px - ax - t * vx, py - ay - t * vy
        local e = dx * dx + dy * dy
        local k = base + col
        if e < d2[k] then d2[k] = e end
      end
    end
  end
  return d2
end

-- One dimension of the exact squared Euclidean distance transform
-- (Felzenszwalb and Huttenlocher): f holds squared distances along a line
-- of n samples read at f[o + i * step], rewritten in place.
local function dt1(f, o, step, n, v, z, tmp)
  for i = 0, n - 1 do tmp[i] = f[o + i * step] end
  local k = 0
  v[0], z[0], z[1] = 0, -1e30, 1e30
  for q = 1, n - 1 do
    local fq = tmp[q] + q * q
    local p = v[k]
    local s = (fq - (tmp[p] + p * p)) / (2 * (q - p))
    while s <= z[k] do
      k = k - 1
      p = v[k]
      s = (fq - (tmp[p] + p * p)) / (2 * (q - p))
    end
    k = k + 1
    v[k], z[k], z[k + 1] = q, s, 1e30
  end
  k = 0
  for q = 0, n - 1 do
    while z[k + 1] < q do k = k + 1 end
    local p = v[k]
    f[o + q * step] = (q - p) * (q - p) + tmp[p]
  end
end

-- Distance in px from each pixel inside coverage `cov` to the shape's
-- edge: the Euclidean distance to the nearest outside pixel, refined at
-- the edge by the coverage itself. Outside pixels get cov - 0.5 (<= 0).
function R.inside_distance(g, cov)
  local w, h, n = g.w, g.h, g.n
  local f = {}
  local INF = 1e20
  for i = 1, n do f[i] = cov[i] >= 0.5 and INF or 0 end
  local v, z, tmp = {}, {}, {}
  for col = 1, w do dt1(f, col, w, h, v, z, tmp) end
  for row = 1, h do dt1(f, (row - 1) * w + 1, 1, w, v, z, tmp) end
  for i = 1, n do
    local c = cov[i]
    if c < 0.5 then
      f[i] = c - 0.5
    else
      -- Clamped to the grid's edge when no outside pixel exists.
      local dd = f[i] >= INF and (w + h) * (w + h) or f[i]
      f[i] = dd <= 1 and c - 0.5 or sqrt(dd) - 0.5
    end
  end
  return f
end

-- A 3x3 box blur of flat array a over grid g, `passes` times, in place.
function R.blur(g, a, passes)
  local w, h = g.w, g.h
  local t = {}
  for _ = 1, passes or 1 do
    for row = 1, h do
      local base = (row - 1) * w
      for col = 1, w do
        local l = col > 1 and a[base + col - 1] or a[base + col]
        local r = col < w and a[base + col + 1] or a[base + col]
        t[base + col] = (l + a[base + col] + r) / 3
      end
    end
    for row = 1, h do
      local base = (row - 1) * w
      local up = row > 1 and base - w or base
      local dn = row < h and base + w or base
      for col = 1, w do
        a[base + col] = (t[up + col] + t[base + col] + t[dn + col]) / 3
      end
    end
  end
  return a
end

-- A 32-bit integer hash of integer lattice point (x, y) and `seed`.
function R.hash(x, y, seed)
  local hh = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xffffffff
  hh = ((hh ~ (hh >> 13)) * 1274126177) & 0xffffffff
  return hh ~ (hh >> 16)
end

-- Smooth value noise in [-1, 1] at real point (x, y).
function R.noise(x, y, seed)
  local ix, iy = floor(x), floor(y)
  local fx, fy = x - ix, y - iy
  fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
  local H = R.hash
  local a, b = H(ix, iy, seed), H(ix + 1, iy, seed)
  local c, d = H(ix, iy + 1, seed), H(ix + 1, iy + 1, seed)
  local top = a + (b - a) * fx
  local bot = c + (d - c) * fx
  return (top + (bot - top) * fy) / 2147483647.5 - 1
end

return R
