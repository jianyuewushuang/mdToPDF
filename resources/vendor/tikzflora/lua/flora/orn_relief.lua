-- Gold in relief, shaded by which way its surface faces. Metal shows no
-- colour of its own, only what it mirrors, so a shape reads as gold when
-- its brightness follows its form: each shape is given a rounded bevel of
-- a few rings just inside its edge, each short piece of ring tilted out
-- toward the edge it runs along, and every piece takes the colour of what
-- it would mirror from a studio lit from the page's upper left: bright sky
-- on the lit side, a sharp bright horizon, dark ground below it and a warm
-- bounce at the far side. The flat top mirrors the viewer and stays a mid
-- gold. Thin shapes are all bevel, so a stroke reads as round wire.
--
-- Everything is worked in page coordinates (after the painter's frame and
-- projection), so light falls the same way on a mirrored corner, and is
-- painted as plain fills grouped by colour level: vector, at any zoom.

local G = require("flora.geom")

local M = {}
local pi, cos, sin, sqrt, exp = math.pi, math.cos, math.sin, math.sqrt, math.exp

local LEVELS = 28            -- colour levels the bevel pieces are grouped into
local TILT = 1.32            -- tilt of the outermost ring, radians (~75 degrees)
local LX, LY = -0.6, 0.8     -- the light's side of the page, a unit vector

-- Gold by mirrored brightness v (0-1), dark to white-hot; the shaded tone
-- (copper faces) is redder and a step darker.
local RAMP = {
  { 0.00, { 0.240, 0.130, 0.050 } },
  { 0.20, { 0.420, 0.270, 0.100 } },
  { 0.45, { 0.680, 0.500, 0.220 } },
  { 0.62, { 0.840, 0.670, 0.330 } },
  { 0.80, { 0.950, 0.840, 0.520 } },
  { 1.00, { 1.000, 0.970, 0.840 } },
}

function M.color(v, tone)
  v = G.clamp(v, 0, 1)
  local c
  for i = 2, #RAMP do
    if v <= RAMP[i][1] then
      local a, b = RAMP[i - 1], RAMP[i]
      local t = (v - a[1]) / (b[1] - a[1])
      c = { a[2][1] + (b[2][1] - a[2][1]) * t, a[2][2] + (b[2][2] - a[2][2]) * t, a[2][3] + (b[2][3] - a[2][3]) * t }
      break
    end
  end
  c = c or RAMP[#RAMP][2]
  if tone == "shade" then c = { c[1] * 0.9, c[2] * 0.68, c[3] * 0.6 } end
  return c
end

-- What a surface whose outward edge faces (nx, ny) on the page, tilted
-- `th` from facing the viewer, mirrors: brightness 0-1.
function M.mirror(nx, ny, th)
  local st, ct = sin(th), cos(th)
  -- The viewer's line of sight (0, 0, 1) reflected about the normal.
  local rx, ry = 2 * ct * st * nx, 2 * ct * st * ny
  local u = rx * LX + ry * LY
  local v = 0.14 + 0.22 * G.smoothstep(-0.3, -1, u)
  v = v + (0.8 + 0.2 * G.smoothstep(0.25, 0.95, u) - v) * G.smoothstep(-0.02, 0.06, u)
  v = v + 0.22 * exp(-((u - 0.08) / 0.05) ^ 2)
  local front = 0.52
  return front + (v - front) * G.smoothstep(0.05, 0.6, sqrt(rx * rx + ry * ry))
end

-- Closed polygons (page coordinates) for paint commands `cmds`, through
-- the painter's map `pj` (nil for none). Curves and circles are sampled
-- about every 0.9pt, and points closer than 0.45pt to the last kept one
-- are skipped (pen ribbons arrive far denser than a bevel needs).
-- Subpaths of fewer than `least` points (default 3) are dropped.
function M.flatten(cmds, pj, least)
  local polys, cur = {}, nil
  local function put(x, y)
    if pj then x, y = pj(x, y) end
    local last = cur[#cur]
    if not last or math.abs(last[1] - x) + math.abs(last[2] - y) > 0.45 then cur[#cur + 1] = { x, y } end
  end
  local function finish()
    if cur and #cur >= (least or 3) then polys[#polys + 1] = cur end
    cur = nil
  end
  local px, py = 0, 0
  for _, c in ipairs(cmds) do
    local op = c[1]
    if op == "m" then
      finish()
      cur = {}
      put(c[2], c[3])
      px, py = c[2], c[3]
    elseif op == "l" then
      put(c[2], c[3])
      px, py = c[2], c[3]
    elseif op == "c" then
      local len = G.dist({ px, py }, { c[2], c[3] }) + G.dist({ c[2], c[3] }, { c[4], c[5] }) + G.dist({ c[4], c[5] }, { c[6], c[7] })
      local n = G.clamp(math.ceil(len / 0.9), 1, 24)
      local pts = G.bezier({ px, py }, { c[2], c[3] }, { c[4], c[5] }, { c[6], c[7] }, n)
      for i = 2, #pts do put(pts[i][1], pts[i][2]) end
      px, py = c[6], c[7]
    elseif op == "o" then
      finish()
      cur = {}
      local n = G.clamp(math.ceil(2 * pi * c[4] / 0.9), 8, 48)
      for k = 0, n - 1 do put(c[2] + c[4] * cos(2 * pi * k / n), c[3] + c[4] * sin(2 * pi * k / n)) end
      finish()
    elseif op == "z" then
      finish()
    end
  end
  finish()
  -- A closing point repeating the first adds nothing.
  for _, p in ipairs(polys) do
    if #p > 3 and math.abs(p[1][1] - p[#p][1]) + math.abs(p[1][2] - p[#p][2]) < 0.45 then p[#p] = nil end
  end
  return polys
end

function M.area(p)
  local a = 0
  for i = 1, #p do
    local q, r = p[i], p[i % #p + 1]
    a = a + q[1] * r[2] - r[1] * q[2]
  end
  return a / 2
end

-- The bevel of polygon `p` (page coordinates) as quads sorted into colour
-- levels `buckets` (level -> list of point lists). Returns the polygon's
-- inner top (points), or nil when the shape is too small to bevel.
function M.bevel(p, buckets, depth_cap, tilt)
  local n = #p
  local A = M.area(p)
  local per = 0
  for i = 1, n do per = per + G.dist(p[i], p[i % n + 1]) end
  if math.abs(A) < 0.01 or per < 0.1 then return nil end
  local s = A > 0 and 1 or -1
  -- Thickness: twice the area over the perimeter, a ribbon's width.
  local T = 2 * math.abs(A) / per
  local depth = math.min(0.45 * T, 0.5 + 0.16 * T, depth_cap or 4)
  local rings = G.clamp(math.ceil(depth / 0.35), 2, 5)
  -- Outward normal of each edge, and each vertex's mitred offset.
  local en, off = {}, {}
  for i = 1, n do
    local a, b = p[i], p[i % n + 1]
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local l = sqrt(dx * dx + dy * dy)
    en[i] = l > 0 and { s * dy / l, -s * dx / l } or { 0, 0 }
  end
  for i = 1, n do
    local n1, n2 = en[(i - 2) % n + 1], en[i]
    local mx, my = n1[1] + n2[1], n1[2] + n2[2]
    local l = sqrt(mx * mx + my * my)
    if l < 1e-6 then mx, my, l = n2[1], n2[2], 1 end
    mx, my = mx / l, my / l
    local k = 1 / math.max(0.4, mx * n2[1] + my * n2[2])
    off[i] = { mx * k, my * k }
  end
  local function ring(d)
    local out = {}
    for i = 1, n do out[i] = { p[i][1] - off[i][1] * d, p[i][2] - off[i][2] * d } end
    return out
  end
  local outer = p
  for r = 1, rings do
    local inner = ring(depth * r / rings)
    local th = (tilt or TILT) * (1 - (r - 0.5) / rings) ^ 1.4
    -- Runs of edges at one colour level become one strip: the outer
    -- ring's run forward, the inner ring's back.
    local level = {}
    for i = 1, n do
      level[i] = math.floor(G.clamp(M.mirror(en[i][1], en[i][2], th), 0, 1) * (LEVELS - 1) + 0.5)
    end
    local i = 1
    while i <= n do
      local j = i
      while j < n and level[j + 1] == level[i] do j = j + 1 end
      local strip = {}
      for k = i, j + 1 do strip[#strip + 1] = outer[(k - 1) % n + 1] end
      for k = j + 1, i, -1 do strip[#strip + 1] = inner[(k - 1) % n + 1] end
      -- One winding for every strip, so overlaps never cancel.
      if M.area(strip) < 0 then
        local rev = {}
        for k = #strip, 1, -1 do rev[#rev + 1] = strip[k] end
        strip = rev
      end
      local q = level[i]
      buckets[q] = buckets[q] or {}
      table.insert(buckets[q], strip)
      i = j + 1
    end
    outer = inner
  end
  return outer
end

-- Paint closed polygons `polys`, in page coordinates, as gold in relief
-- onto pt. Options:
--   tone    "shade" for the darker, redder gold of shaded faces
--   shadow  drop-shadow offset, pt (0 for none)
--   key     keyline width, pt (0 for none)
--   depth   the deepest bevel, pt (default 4; thin shapes bevel less)
--   tilt    the outermost ring's tilt, radians (default about 75 degrees);
--           shallower keeps fine wire bright
function M.paint_polys(pt, polys, o)
  o = o or {}
  if #polys == 0 then return end
  -- Paint in page coordinates: the frame is already applied.
  local proj, frame = pt.projection, pt.frame_fn
  pt.projection, pt.frame_fn = nil, nil
  local all = {}
  for i, poly in ipairs(polys) do all[i] = G.polyline(poly, true) end
  local shadow = o.shadow or 0
  if shadow > 0 then
    local sh = {}
    for i, poly in ipairs(polys) do
      local q = {}
      for k, v in ipairs(poly) do q[k] = { v[1] - LX * shadow, v[2] - LY * shadow } end
      sh[i] = G.polyline(q, true)
    end
    pt:fill(sh, { 0.45, 0.28, 0.14 }, 0.35, { many = true })
  end
  -- The top mirrors the room straight ahead: a soft sheen, brightest a
  -- little toward the light, a darker band past the middle and a lift at
  -- the far side, under everything.
  local b = { math.huge, math.huge, -math.huge, -math.huge }
  for _, poly in ipairs(polys) do
    for _, v in ipairs(poly) do
      b[1], b[2], b[3], b[4] = math.min(b[1], v[1]), math.min(b[2], v[2]), math.max(b[3], v[1]), math.max(b[4], v[2])
    end
  end
  local name = o.tone == "shade" and "flreliefshade" or "flrelief"
  pt:shading(name, { { 0, M.color(0.62, o.tone) }, { 0.3, M.color(0.7, o.tone) }, { 0.62, M.color(0.42, o.tone) },
    { 0.85, M.color(0.5, o.tone) }, { 1, M.color(0.46, o.tone) } })
  local cx, cy = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  local half = (math.abs(LX) * (b[3] - b[1]) + math.abs(LY) * (b[4] - b[2])) / 2 + 0.5
  local clip = {}
  for _, cmds in ipairs(all) do for _, c in ipairs(cmds) do clip[#clip + 1] = c end end
  pt:clip_begin(clip)
  pt:shade(name, { cx + LX * half, cy + LY * half }, { cx - LX * half, cy - LY * half }, (b[3] - b[1]) + (b[4] - b[2]) + 2)
  pt:clip_end()
  local buckets = {}
  for _, poly in ipairs(polys) do M.bevel(poly, buckets, o.depth, o.tilt) end
  for q = 0, LEVELS - 1 do
    local quads = buckets[q]
    if quads then
      local cmds = {}
      for i, strip in ipairs(quads) do cmds[i] = G.polyline(strip, true) end
      pt:fill(cmds, M.color(q / (LEVELS - 1), o.tone), 1, { many = true })
    end
  end
  local key = o.key or 0.14
  if key > 0 then pt:stroke(all, { 0.30, 0.18, 0.07 }, key, 0.7, { many = true }) end
  pt.projection, pt.frame_fn = proj, frame
end

-- Paint `paths` (paint commands, in pt's own coordinates) as gold in
-- relief; options as paint_polys.
function M.paint(pt, paths, o)
  local pj = pt:_pj()
  local polys = {}
  for _, cmds in ipairs(paths) do
    for _, poly in ipairs(M.flatten(cmds, pj)) do polys[#polys + 1] = poly end
  end
  M.paint_polys(pt, polys, o)
end

-- Ribbon outlines `w` wide along each path of `paths` (open or closed
-- paint commands), as closed polygons in page coordinates, for gilding a
-- stroke with paint_polys.
function M.ribbons(pt, paths, w)
  local pj = pt:_pj()
  local out = {}
  for _, cmds in ipairs(paths) do
    -- Flatten without closing, then close loops by repeating the start.
    local closed = false
    for _, c in ipairs(cmds) do if c[1] == "z" or c[1] == "o" then closed = true end end
    for _, poly in ipairs(M.flatten(cmds, nil, 2)) do
      if closed then poly[#poly + 1] = poly[1] end
      if #poly >= 2 then
        local rib = G.ribbon(poly, function() return w / 2 end)
        if pj then for i, v in ipairs(rib) do local x, y = pj(v[1], v[2]) rib[i] = { x, y } end end
        out[#out + 1] = rib
      end
    end
  end
  return out
end

return M
