-- The relief of raster gilt (orn_raster.lua): every painted piece's
-- surface slope, from its own shape alone, laid down in painting order.
--
-- A piece rises from its edge: a thin piece rounds right across, as wire;
-- a broad one takes a rounded bevel and a low cushion. Distance to the
-- edge is exact within the bevel, where the surface turns fastest, and
-- comes from a distance transform beyond it, where the surface is nearly
-- flat. A later piece covers an earlier one completely: nothing beneath a
-- piece, or beside it, shapes its surface. The one exception is a gold
-- face and a copper face, painted one after the other, that meet edge to
-- edge (the lit and shaded halves of one ray): each is a plane rising to
-- the ridge they share. A face has one such partner, the face it shares
-- its longest edge with.

local Raster = require("flora.raster")

local M = {}

local sqrt, floor, max, min, abs, sin, pi = math.sqrt, math.floor, math.max, math.min, math.abs, math.sin, math.pi

-- A rounded profile: height (px) over inside distance dd (px) for an edge
-- rr px wide, with a low cushion rising over r2 px. Both ease to flat;
-- `tilt` sets how steeply the edge leaves the page (at 0.45 it rises at
-- about 43 degrees, so it mirrors the horizon) and `cushion` the
-- cushion's height as a share of r2.
local function profile(dd, rr, r2, tilt, cushion)
  if dd <= 0 then return 0 end
  local t = (dd < rr and dd or rr) / rr
  local t2 = (dd < r2 and dd or r2) / r2
  return tilt * rr * sin(t * pi / 2) + cushion * r2 * sin(t2 * pi / 2)
end

-- The part of grid g that px rectangle x0..x1, y0..y1 covers, plus a
-- pixel, aligned to g's pixels: {c0, r0, w, h} (offsets in g).
local function window(g, x0, y0, x1, y1)
  local c0, r0 = max(0, floor(x0) - 1), max(0, floor(y0) - 1)
  local c1, r1 = min(g.w, floor(x1) + 2), min(g.h, floor(y1) + 2)
  return { c0 = c0, r0 = r0, w = max(1, c1 - c0), h = max(1, r1 - r0) }
end

-- Window `win` of grid g as a grid of its own.
local function grid_of(g, win)
  return { x0 = g.x0 + win.c0 * g.s, y1 = g.y1 - win.r0 * g.s, w = win.w, h = win.h, s = g.s, n = win.w * win.h }
end

-- Polylines `polys` (px in g) moved into window `win`.
local function shifted(polys, win)
  local out = {}
  for i, p in ipairs(polys) do
    local q = {}
    for j = 1, #p, 2 do q[j], q[j + 1] = p[j] - win.c0, p[j + 1] - win.r0 end
    out[i] = q
  end
  return out
end

-- The points of polyline p (flat x, y list) from point i to point j that
-- a chord from i to j passes within `tol` px of all the way (Ramer,
-- Douglas and Peucker), appended to `out` (i itself excluded).
local function simplify(p, i, j, tol, out)
  local ax, ay, bx, by = p[2 * i - 1], p[2 * i], p[2 * j - 1], p[2 * j]
  local vx, vy = bx - ax, by - ay
  local ll = vx * vx + vy * vy
  local far, at = -1, nil
  for k = i + 1, j - 1 do
    local px, py = p[2 * k - 1] - ax, p[2 * k] - ay
    local t = ll > 0 and (px * vx + py * vy) / ll or 0
    t = t < 0 and 0 or (t > 1 and 1 or t)
    local dx, dy = px - t * vx, py - t * vy
    local e = dx * dx + dy * dy
    if e > far then far, at = e, k end
  end
  if at and far > tol * tol then
    simplify(p, i, at, tol, out)
    simplify(p, at, j, tol, out)
  else
    out[#out + 1] = j
  end
end

-- Edge segments {x0, y0, x1, y1} (px in g) of closed polylines, curves
-- kept within 0.05 px with as few chords as that allows.
local function segments(polys)
  local segs = {}
  for _, p in ipairs(polys) do
    local n = #p // 2
    if n >= 2 then
      local keep = { 1 }
      simplify(p, 1, n, 0.05, keep)
      for k = 1, #keep - 1 do
        local a, b = keep[k], keep[k + 1]
        segs[#segs + 1] = { p[2 * a - 1], p[2 * a], p[2 * b - 1], p[2 * b] }
      end
      if p[2 * n - 1] ~= p[1] or p[2 * n] ~= p[2] then segs[#segs + 1] = { p[2 * n - 1], p[2 * n], p[1], p[2] } end
    end
  end
  return segs
end

-- Whether point (x, y) lies within 1e-3 px of a segment in `segs`.
local function on_edge(segs, x, y)
  for _, s in ipairs(segs) do
    local vx, vy = s[3] - s[1], s[4] - s[2]
    local ll = vx * vx + vy * vy
    local t = ll > 0 and ((x - s[1]) * vx + (y - s[2]) * vy) / ll or 0
    t = t < 0 and 0 or (t > 1 and 1 or t)
    local dx, dy = x - s[1] - t * vx, y - s[2] - t * vy
    if dx * dx + dy * dy < 1e-6 then return true end
  end
  return false
end

-- Whether point (x, y) lies inside the closed edges `segs` (even-odd).
local function inside(segs, x, y)
  local odd = false
  for _, s in ipairs(segs) do
    if (s[2] > y) ~= (s[4] > y) and x < s[1] + (y - s[2]) * (s[3] - s[1]) / (s[4] - s[2]) then
      odd = not odd
    end
  end
  return odd
end

-- The segments of piece a that lie along piece b's edge (both ends and
-- the middle on it) with b on the other side of them: a and b meet there
-- edge to edge. A face of one ray whose edge merely runs along a
-- neighbouring ray's edge, overlapping it, does not count.
local function share(a, b)
  local out = {}
  for _, s in ipairs(a.segs) do
    local mx, my = (s[1] + s[3]) / 2, (s[2] + s[4]) / 2
    if on_edge(b.segs, s[1], s[2]) and on_edge(b.segs, s[3], s[4]) and on_edge(b.segs, mx, my) then
      local vx, vy = s[3] - s[1], s[4] - s[2]
      local l = sqrt(vx * vx + vy * vy)
      if l > 0 then
        local nx, ny = -vy / l * 0.25, vx / l * 0.25
        local ap, an = inside(a.segs, mx + nx, my + ny), inside(a.segs, mx - nx, my - ny)
        if ap ~= an and inside(b.segs, mx + nx, my + ny) == an and inside(b.segs, mx - nx, my - ny) == ap then
          out[#out + 1] = s
        end
      end
    end
  end
  return out
end

local function overlap(a, b)
  return a.win.c0 < b.win.c0 + b.win.w and b.win.c0 < a.win.c0 + a.win.w
    and a.win.r0 < b.win.r0 + b.win.h and b.win.r0 < a.win.r0 + a.win.h
end

-- Pieces that rise together: the faces of one ray (see the top). Returns
-- a list of groups, each a list of pieces.
function M.groups(pieces)
  local parent = {}
  for i = 1, #pieces do parent[i] = i end
  local function root(i)
    while parent[i] ~= i do i = parent[i] end
    return i
  end
  -- Only pieces of the next call can pair with a piece.
  local by_call = {}
  for j, b in ipairs(pieces) do
    by_call[b.call] = by_call[b.call] or {}
    table.insert(by_call[b.call], j)
  end
  local pairs_ = {}
  for i, a in ipairs(pieces) do
    for _, j in ipairs(a.kind == "fill" and by_call[a.call + 1] or {}) do
      local b = pieces[j]
      if b.kind == "fill" and a.tone ~= b.tone and overlap(a, b) then
        local ab, ba = share(a, b), share(b, a)
        if #ab > 0 and #ba > 0 then
          local len = 0
          for _, s in ipairs(ab) do len = len + sqrt((s[3] - s[1]) ^ 2 + (s[4] - s[2]) ^ 2) end
          pairs_[#pairs_ + 1] = { i = i, j = j, len = len, ab = ab, ba = ba }
        end
      end
    end
  end
  -- Each face has one partner, the one it shares the longest edge with:
  -- the halves of a ray share its whole length, while opposite rays of a
  -- star also meet edge to edge, but only along their short bases.
  table.sort(pairs_, function(x, y)
    if x.len ~= y.len then return x.len > y.len end
    if x.i ~= y.i then return x.i < y.i end
    return x.j < y.j
  end)
  local taken = {}
  for _, q in ipairs(pairs_) do
    if not taken[q.i] and not taken[q.j] then
      taken[q.i], taken[q.j] = true, true
      for _, s in ipairs(q.ab) do s.shared = true end
      for _, s in ipairs(q.ba) do s.shared = true end
      parent[root(q.j)] = root(q.i)
    end
  end
  local out, at = {}, {}
  for i, p in ipairs(pieces) do
    local r = root(i)
    if not at[r] then
      at[r] = #out + 1
      out[#out + 1] = {}
    end
    table.insert(out[at[r]], p)
  end
  return out
end

-- Slopes (dh/dx, dh/dy per px, y down) of heights h over a group's
-- window G, smoothed within the group alone: neighbours outside it carry
-- no weight.
local function slopes(G, win, cov, tone, h, thick)
  local W, H = G.w, G.h
  local hs = {}
  for row = 1, H do
    for col = 1, W do
      local k = (row - 1) * W + col
      if cov[k] > 0 then
        local sum, wt = 0, 0
        for r = max(1, row - 1), min(H, row + 1) do
          for c = max(1, col - 1), min(W, col + 1) do
            local q = (r - 1) * W + c
            local cw = cov[q]
            sum, wt = sum + h[q] * cw, wt + cw
          end
        end
        hs[k] = sum / wt
      else
        hs[k] = 0
      end
    end
  end
  local sx, sy = {}, {}
  for row = 1, H do
    local base = (row - 1) * W
    local up = row > 1 and base - W or base
    local dn = row < H and base + W or base
    for col = 1, W do
      local k = base + col
      sx[k] = ((col < W and hs[k + 1] or hs[k]) - (col > 1 and hs[k - 1] or hs[k])) * 0.5
      sy[k] = (hs[dn + col] - hs[up + col]) * 0.5
    end
  end
  return { win = win, cov = cov, tone = tone, sx = sx, sy = sy, thick = thick }
end

-- The relief of faces that share an edge (the halves of one ray): each
-- face is a plane, level with the page along its longest outer edge and
-- rising evenly toward the ridge, as a cut facet does. Each face keeps its
-- own slope right up to the ridge, so the ridge stays a crisp line: the
-- layer carries both faces' surfaces, weighted by their coverage.
local function roof(g, grp, G, win, cov, L)
  local W, n = G.w, G.n
  local far = 0
  local face = {}
  for f, p in ipairs(grp) do
    local best, bl = nil, 0
    for _, s in ipairs(p.segs) do
      local l = (s[3] - s[1]) ^ 2 + (s[4] - s[2]) ^ 2
      if not s.shared and l > bl then best, bl = s, l end
    end
    -- The edge's unit normal, turned into the face (toward the face's
    -- point furthest from the edge's line).
    local l = sqrt(bl)
    local nx, ny = -(best[4] - best[2]) / l, (best[3] - best[1]) / l
    local top = 0
    for _, s in ipairs(p.segs) do
      local e = (s[1] - best[1]) * nx + (s[2] - best[2]) * ny
      if abs(e) > abs(top) then top = e end
    end
    if top < 0 then nx, ny = -nx, -ny end
    far = max(far, abs(top))
    local fc = Raster.zeros(n)
    local pw = p.win
    for row = 1, pw.h do
      local src, dst = (row - 1) * pw.w, (row + pw.r0 - win.r0 - 1) * W + pw.c0 - win.c0
      for col = 1, pw.w do fc[dst + col] = p.cov[src + col] end
    end
    face[f] = { cov = fc, sx = L.facet * nx, sy = L.facet * ny, tone = p.tone }
  end
  local a, b = face[1], face[2]
  local sx, sy, tone, bx, by, bt, wa = {}, {}, {}, {}, {}, {}, {}
  for i = 1, n do
    local ca, cb = a.cov[i], b.cov[i]
    sx[i], sy[i], tone[i] = a.sx, a.sy, a.tone
    bx[i], by[i], bt[i] = b.sx, b.sy, b.tone
    wa[i] = ca + cb > 0 and ca / (ca + cb) or 1
  end
  return { win = win, cov = cov, sx = sx, sy = sy, tone = tone, bx = bx, by = by, bt = bt, wa = wa, thick = far * g.s }
end

-- The slopes (dh/dx, dh/dy per px, y down) of one group of pieces over
-- its own window, and its half-thickness in pt.
local function group_relief(g, grp, L)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(grp) do
    local w = p.win
    x0, y0 = min(x0, w.c0), min(y0, w.r0)
    x1, y1 = max(x1, w.c0 + w.w), max(y1, w.r0 + w.h)
  end
  local win = { c0 = x0, r0 = y0, w = x1 - x0, h = y1 - y0 }
  local G = grid_of(g, win)
  local n = G.n
  -- Coverage of the whole group: faces meet edge to edge, so their
  -- coverage adds up across the edge they share.
  local cov, tone = Raster.zeros(n), Raster.zeros(n)
  for _, p in ipairs(grp) do
    local pw = p.win
    for row = 1, pw.h do
      local src, dst = (row - 1) * pw.w, (row + pw.r0 - y0 - 1) * G.w + pw.c0 - x0
      for col = 1, pw.w do
        local c = p.cov[src + col]
        cov[dst + col] = cov[dst + col] + c
        tone[dst + col] = tone[dst + col] + c * p.tone
      end
    end
  end
  for i = 1, n do
    local c = cov[i]
    if c > 0 then tone[i] = tone[i] / c end
    cov[i] = c > 1 and 1 or c
  end
  if #grp > 1 then return roof(g, grp, G, win, cov, L) end
  local d, bev
  local single = grp[1]
  if single.kind == "stroke" then
    d = single.din
    bev = single.half / g.s
  else
    -- The exact distance to the piece's edges within its bevel, where the
    -- surface turns fastest. Pixels further in, which only broad pieces
    -- have, take the distance transform.
    bev = (single.bevel and single.bevel * 2.2 or 0.9) / g.s
    local band = bev + 2
    local segs = {}
    for _, s in ipairs(single.segs) do
      local m = #segs
      segs[m + 1], segs[m + 2], segs[m + 3], segs[m + 4] = s[1] - x0, s[2] - y0, s[3] - x0, s[4] - y0
    end
    local d2 = {}
    for i = 1, n do d2[i] = math.huge end
    Raster.segment_distance(G, segs, band, d2)
    d = {}
    local e
    for i = 1, n do
      local c = cov[i]
      if c < 0.5 then
        d[i] = c - 0.5
      else
        local exact = sqrt(d2[i])
        if exact <= band then
          d[i] = exact
        else
          e = e or Raster.inside_distance(G, cov)
          d[i] = max(e[i], band)
        end
      end
    end
  end
  local dmax = 0
  for i = 1, n do if d[i] > dmax then dmax = d[i] end end
  local rr = max(0.5, min(bev, dmax))
  local r2 = max(rr, min(dmax, rr * 5))
  -- Small pieces (under about a point thick) slope more gently, so their
  -- far edges catch sky rather than ground and do not turn to a dark rim.
  local thick = dmax * g.s
  local tilt = L.relief * (thick >= 1 and 1 or max(0.55, thick))
  local h = {}
  for i = 1, n do h[i] = profile(d[i], rr, r2, tilt, L.cushion) end
  return slopes(G, win, cov, tone, h, thick)
end

-- Rasterise `shapes` (orn_raster.lua's pending shapes) over grid g and lay
-- them down in painting order, cut as look L (gilt_look.lua; default the
-- tuned one) sets. Returns flat arrays over g: coverage C; the first
-- surface's slopes SX, SY (dh/dx, dh/dy per px, y down) and tone T (1
-- copper); the half-thickness Z (pt) of the piece on top; the first
-- surface's share W of the pixel's gold; and the second surface's slopes
-- BX, BY and tone BT.
function M.layers(g, shapes, L)
  L = L or require("flora.gilt_look").resolve(require("flora.tune").gilt_env)
  local pieces = {}
  for i, sh in ipairs(shapes) do
    local polys = {}
    for _, cmds in ipairs(sh.paths) do
      for _, poly in ipairs(Raster.flatten(g, cmds)) do polys[#polys + 1] = poly end
    end
    local hp = sh.half / g.s
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, p in ipairs(polys) do
      for j = 1, #p, 2 do
        x0, x1 = min(x0, p[j]), max(x1, p[j])
        y0, y1 = min(y0, p[j + 1]), max(y1, p[j + 1])
      end
    end
    if x0 <= x1 then
      local win = window(g, x0 - hp, y0 - hp, x1 + hp, y1 + hp)
      local sg, local_polys = grid_of(g, win), shifted(polys, win)
      local pc = { kind = sh.kind, tone = sh.tone, call = sh.call, bevel = sh.bevel, half = sh.half, win = win, order = i }
      if sh.kind == "stroke" then
        pc.cov, pc.din = Raster.stroke(sg, local_polys, hp)
      else
        pc.cov = Raster.fill(sg, local_polys, sh.evenodd)
        pc.segs = segments(polys)
      end
      pieces[#pieces + 1] = pc
    end
  end
  -- Each group is one layer, laid down where its last piece was painted;
  -- the faces of a group meet edge to edge, so their coverage adds up and
  -- leaves no seam along the edge they share.
  local layers = {}
  for _, grp in ipairs(M.groups(pieces)) do
    local rel = group_relief(g, grp, L)
    local last = 0
    for _, p in ipairs(grp) do last = max(last, p.order) end
    rel.top = last
    layers[#layers + 1] = rel
  end
  table.sort(layers, function(a, b) return a.top < b.top end)
  -- Each pixel keeps the two surfaces that cover most of it (their slopes
  -- and tones, and the first one's share W of the gold there), so the
  -- edge between two surfaces shades as a mix of their colours rather
  -- than as one surface tilted between them.
  local N = g.n
  local C, Z, W = Raster.zeros(N), Raster.zeros(N), Raster.zeros(N)
  local SX, SY, T, BX, BY, BT = Raster.zeros(N), Raster.zeros(N), Raster.zeros(N), Raster.zeros(N), Raster.zeros(N), Raster.zeros(N)
  local GW = g.w
  for _, rel in ipairs(layers) do
    local rw = rel.win
    local bx, wa = rel.bx, rel.wa
    for row = 1, rw.h do
      local src = (row - 1) * rw.w
      local dst = (row + rw.r0 - 1) * GW + rw.c0
      for col = 1, rw.w do
        local q = src + col
        local c = rel.cov[q]
        if c > 0 then
          local k = dst + col
          local co = C[k]
          local cn = c + (1 - c) * co
          -- Weights of the old pair and the new pair of surfaces.
          local keep = (1 - c) * co / cn
          local o1, o2 = keep * W[k], keep * (1 - W[k])
          local fa = bx and wa[q] or 1
          local n1, n2 = c / cn * fa, c / cn * (1 - fa)
          local ax, ay, at = rel.sx[q], rel.sy[q], rel.tone[q]
          -- The new layer's first surface stays; the other slot goes to
          -- whichever of the rest weighs most.
          local w2, x2, y2, t2 = n2, 0, 0, 0
          if bx then x2, y2, t2 = bx[q], rel.by[q], rel.bt[q] end
          if o1 > w2 then w2, x2, y2, t2 = o1, SX[k], SY[k], T[k] end
          if o2 > w2 then w2, x2, y2, t2 = o2, BX[k], BY[k], BT[k] end
          -- The heavier of the two comes first.
          if w2 > n1 then ax, ay, at, x2, y2, t2, n1, w2 = x2, y2, t2, ax, ay, at, w2, n1 end
          SX[k], SY[k], T[k] = ax, ay, at
          BX[k], BY[k], BT[k] = x2, y2, t2
          W[k] = n1 / (n1 + w2)
          Z[k] = Z[k] * (1 - c) + rel.thick * c
          C[k] = cn
        end
      end
    end
  end
  return C, SX, SY, T, Z, W, BX, BY, BT
end

return M
