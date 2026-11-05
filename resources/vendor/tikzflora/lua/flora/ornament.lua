-- Gilded marginalia: compass stars, sparkles, edge chains, knot lozenges
-- and the inset star panel.

local G = require("flora.geom")
local W = require("flora.wash")
local Paint = require("flora.paint")
local Color = require("flora.color")
local pal = Paint.palette

local O = {}
local pi = math.pi

local function tri(a, b, c)
  return { { "m", a[1], a[2] }, { "l", b[1], b[2] }, { "l", c[1], c[2] }, { "z" } }
end

-- An eight-point compass star. Each ray has a lit and a shaded half.
--   o.hair: length factor of the thin crosshair lines (0 for none)
--   o.ring: number of dots circling the star
function O.compass(pt, x, y, R, o)
  o = o or {}
  local C = { x, y }
  local lit, shade = {}, {}
  for k = 0, 7 do
    local a = k * pi / 4 + pi / 2
    local major = k % 2 == 0
    local len = major and R or R * 0.48
    local half = major and 0.11 or 0.13
    local tip = G.polar(C, a, len)
    local l = G.polar(C, a + pi / 4, len * half)
    local r = G.polar(C, a - pi / 4, len * half)
    lit[#lit + 1] = tri(C, tip, l)
    shade[#shade + 1] = tri(C, tip, r)
  end
  if (o.hair or 1.7) > 0 then
    local h = R * (o.hair or 1.7)
    pt:stroke({ G.polyline({ { x, y - h }, { x, y + h } }), G.polyline({ { x - h, y }, { x + h, y } }) },
      pal.gold, 0.22, 0.75, { many = true })
  end
  pt:fill(shade, pal.copper, 0.95, { many = true })
  pt:fill(lit, pal.gold, 0.95, { many = true })
  pt:fill({ { "o", x, y, R * 0.07 } }, pal.cream, 1)
  pt:stroke({ { "o", x, y, R * 0.07 } }, pal.copper, 0.2, 0.9)
  local ring = o.ring or 8
  if ring > 0 then
    local dots = {}
    for k = 0, ring - 1 do
      local a = (k + 0.5) * 2 * pi / ring + pi / 2
      local p = G.polar(C, a, R * 0.62)
      dots[#dots + 1] = { { "o", p[1], p[2], R * 0.035 } }
    end
    pt:fill(dots, pal.gold, 0.9, { many = true })
  end
end

-- Small four-point sparkles, batched. Items: {x, y, r}.
-- A four-point sparkle of radius r at (x, y), as a path.
local function sparkle(x, y, r)
  local k = r * 0.16
  return {
    { "m", x, y + r }, { "c", x, y + k, x + k, y, x + r, y }, { "c", x + k, y, x, y - k, x, y - r },
    { "c", x, y - k, x - k, y, x - r, y }, { "c", x - k, y, x, y + k, x, y + r }, { "z" },
  }
end

-- Small gilt in the gaps of the foliage. Items {x, y, r, kind}: kind
-- "plain" (a four-point sparkle), "dotted" (a sparkle with four dots on its
-- diagonals), "cross" (a slender sparkle with a dot past each point),
-- "rosette" (four dots round a copper heart) or "lozenge" (a small lozenge
-- on a short dotted thread).
function O.sparkles(pt, items)
  local K = require("flora.orn_kit")
  local paths, dots, hearts, stars = {}, {}, {}, {}
  for _, s in ipairs(items) do
    local x, y, r, kind = s[1], s[2], s[3], s[4] or "plain"
    if kind == "lozenge" then
      O.lozenge(pt, x, y, r * 0.8)
    elseif kind == "rosette" then
      for k = 0, 3 do
        local p = G.polar({ x, y }, k * pi / 2, r * 0.5)
        dots[#dots + 1] = { { "o", p[1], p[2], r * 0.3 } }
      end
      hearts[#hearts + 1] = { { "o", x, y, r * 0.2 } }
    elseif kind == "star5" then
      stars[#stars + 1] = G.polyline(K.star(x, y, r * 0.75, r * 0.3, 5), true)
    elseif kind == "crescent" then
      stars[#stars + 1] = G.smooth(K.crescent(x, y, r * 0.62, 0.62, pi / 4), true)
      dots[#dots + 1] = { { "o", x + r * 0.8, y - r * 0.45, r * 0.1 } }
    elseif kind == "trefoil" then
      for _, p in ipairs(K.trefoil(x, y - r * 0.1, r * 0.8, pi / 2)) do dots[#dots + 1] = p end
      hearts[#hearts + 1] = { { "o", x, y - r * 0.05, r * 0.12 } }
    elseif kind == "cross" then
      paths[#paths + 1] = sparkle(x, y, r)
      for k = 0, 3 do
        local p = G.polar({ x, y }, k * pi / 2, r * 1.4)
        dots[#dots + 1] = { { "o", p[1], p[2], r * 0.13 } }
      end
    else
      paths[#paths + 1] = sparkle(x, y, r)
      if kind == "dotted" then
        for k = 0, 3 do
          local p = G.polar({ x, y }, pi / 4 + k * pi / 2, r * 0.75)
          dots[#dots + 1] = { { "o", p[1], p[2], r * 0.1 } }
        end
      end
    end
  end
  if #paths > 0 then pt:fill(paths, pal.gold, 0.9, { many = true }) end
  if #dots > 0 then pt:fill(dots, pal.gold, 0.85, { many = true }) end
  if #stars > 0 then pt:fill(stars, pal.gold, 0.92, { many = true }) end
  if #hearts > 0 then pt:fill(hearts, pal.copper, 0.85, { many = true }) end
end

-- A lozenge of half-height h at (x, y): a gilt outline round a copper heart,
-- with a dot above and below.
function O.lozenge(pt, x, y, h)
  local w = h * 0.6
  local outline = G.polyline({ { x, y + h }, { x + w, y }, { x, y - h }, { x - w, y } }, true)
  pt:fill(G.polyline({ { x, y + h * 0.45 }, { x + w * 0.45, y }, { x, y - h * 0.45 }, { x - w * 0.45, y } }, true),
    pal.copper, 0.85)
  pt:stroke(outline, pal.gold, 0.25, 0.9)
  pt:fill({ { { "o", x, y + h * 1.5, h * 0.12 } }, { { "o", x, y - h * 1.5, h * 0.12 } } }, pal.gold, 0.9,
    { many = true })
end

-- A dotted cross of size s: four dots round a larger centre dot.
function O.dot_cross(pt, x, y, s)
  local dots = { { { "o", x, y, s * 0.2 } } }
  for k = 0, 3 do
    local p = G.polar({ x, y }, k * pi / 2, s)
    dots[#dots + 1] = { { "o", p[1], p[2], s * 0.11 } }
  end
  pt:fill(dots, pal.gold, 0.9, { many = true })
end

-- A finial of size s: a slender cross, a drop hanging below it.
function O.finial(pt, x, y, s)
  pt:stroke({ G.polyline({ { x, y + s }, { x, y - s * 0.6 } }), G.polyline({ { x - s * 0.45, y + s * 0.35 },
    { x + s * 0.45, y + s * 0.35 } }) }, pal.copper, 0.3, 0.9, { many = true })
  local d = y - s * 0.6
  pt:fill({ { "m", x, d - s * 0.7 }, { "c", x + s * 0.35, d - s * 0.25, x + s * 0.18, d, x, d + s * 0.05 },
    { "c", x - s * 0.18, d, x - s * 0.35, d - s * 0.25, x, d - s * 0.7 }, { "z" } }, pal.gold, 0.9)
end

-- A scroll hook of height s, opening to side `dir` (+1 right): a hairline
-- C that curls in at its foot.
function O.hook(pt, x, y, s, dir)
  local b = -dir * s * 0.62
  local pts = G.spline_points({ { x, y + s }, { x + b, y + s * 0.4 }, { x + b, y - s * 0.4 }, { x, y - s * 0.8 },
    { x - b * 0.35, y - s * 0.55 } }, 6)
  pt:stroke(G.polyline(pts), pal.gold, 0.28, 0.85)
  pt:fill({ { "o", x, y + s, s * 0.09 } }, pal.gold, 0.9)
end

-- A gilt chain down the outer edge at x, from ytop to ybot, broken by
-- small motifs (lozenges, dotted crosses, finials, scroll hooks and knots)
-- about every 40-70 pt. Each stretch between motifs is a row of dots or,
-- now and then, a hairline rod with a dot at either end. With foot "knot"
-- the chain ends in a knot pendant at ybot.
function O.chain(pt, rng, x, ytop, ybot, foot)
  local stops = {}
  local y = ytop - rng:range(10, 24)
  local last = foot and ybot + 34 or ybot + 8
  while y > last do
    local kind = rng:weighted({ lozenge = 3, cross = 2, finial = 2, hook = 1.5, knot = 1.5 })
    local half = kind == "knot" and 8 or (kind == "hook" and 7 or 5.5)
    stops[#stops + 1] = { y = y, kind = kind, half = half }
    y = y - rng:range(40, 70)
  end
  if foot and ytop - ybot >= 18 then stops[#stops + 1] = { y = ybot + 8, kind = "knot", half = 8 } end
  -- The stretches between motifs (and the chain's ends).
  local spans, from = {}, ytop
  for _, s in ipairs(stops) do
    spans[#spans + 1] = { from, s.y + s.half + 2 }
    from = s.y - s.half - 2
  end
  spans[#spans + 1] = { from, ybot }
  local dots, rods = {}, {}
  for _, sp in ipairs(spans) do
    local a, b = sp[1], sp[2]
    if a - b > 3 then
      if a - b > 14 and rng:chance(0.35) then
        rods[#rods + 1] = G.polyline({ { x, a - 1.5 }, { x, b + 1.5 } })
        dots[#dots + 1] = { { "o", x, a, 0.55 } }
        dots[#dots + 1] = { { "o", x, b, 0.55 } }
      else
        for yy = a, b, -4.6 do dots[#dots + 1] = { { "o", x, yy, 0.5 } } end
      end
    end
  end
  if #rods > 0 then pt:stroke(rods, pal.gold, 0.25, 0.8, { many = true }) end
  if #dots > 0 then pt:fill(dots, pal.gold, 0.85, { many = true }) end
  for _, s in ipairs(stops) do
    if s.kind == "lozenge" then
      O.lozenge(pt, x, s.y, 3.6)
    elseif s.kind == "cross" then
      O.dot_cross(pt, x, s.y, 3)
    elseif s.kind == "finial" then
      O.finial(pt, x, s.y, 4.5)
    elseif s.kind == "hook" then
      O.hook(pt, x, s.y, 6, rng:chance(0.5) and 1 or -1)
    else
      O.knot(pt, x, s.y, 4.8, 7.2)
    end
  end
end

-- A large pale knot medallion of radius r at (x, y), where the edge chain
-- meets the foot: an interlaced lozenge and quatrefoil inside a dotted ring.
function O.medallion(pt, x, y, r)
  pt:group_begin(0.55)
  O.knot(pt, x, y, r * 0.62, r * 0.8)
  local dots = {}
  for k = 0, 15 do
    local p = G.polar({ x, y }, k * pi / 8, r)
    dots[#dots + 1] = { { "o", p[1], p[2], r * 0.045 } }
  end
  pt:fill(dots, pal.gold, 0.9, { many = true })
  pt:stroke({ { "o", x, y, r * 0.86 } }, pal.gold, 0.22, 0.7)
  pt:group_end()
end

-- A lozenge knot: a rhombus threaded with four loops and a small core.
function O.knot(pt, x, y, w, h)
  local paths = {
    G.polyline({ { x, y + h }, { x + w, y }, { x, y - h }, { x - w, y } }, true),
    G.polyline({ { x, y + h * 0.45 }, { x + w * 0.45, y }, { x, y - h * 0.45 }, { x - w * 0.45, y } }, true),
  }
  for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
    paths[#paths + 1] = { { "o", x + d[1] * w * 0.5, y + d[2] * h * 0.5, math.min(w, h) * 0.26 } }
  end
  pt:stroke(paths, pal.gold, 0.3, 0.85, { many = true })
  pt:fill({ { "o", x, y, math.min(w, h) * 0.1 } }, pal.copper, 0.85)
end

-- The star cartouche: a square silver frame round a night-blue field seen
-- through drifting cloud, with stars showing in the gaps and a luminous
-- star at its heart.

-- A rectangle (x0, y0)-(x1, y1) with a concave quarter-circle notch of
-- radius c at each corner, as a closed polygon (n points per straight side).
local function notched(x0, y0, x1, y1, c, n)
  local corners = { { x0, y0, pi / 2 }, { x1, y0, pi }, { x1, y1, 3 * pi / 2 }, { x0, y1, 0 } }
  local out = {}
  for k, q in ipairs(corners) do
    for s = 0, 4 do out[#out + 1] = G.polar(q, q[3] - s / 4 * pi / 2, c) end
    local a, b = out[#out], G.polar(corners[k % 4 + 1], corners[k % 4 + 1][3], c)
    for s = 1, n - 1 do out[#out + 1] = G.mix(a, b, s / n) end
  end
  return out
end

-- Cloud banks over the field (x0, y0)-(x1, y1): a few drifting rows of
-- overlapping puffs {x, y, r}, leaving clear sky between them.
local function cloud_puffs(rng, x0, y0, x1, y1)
  local w, h = x1 - x0, y1 - y0
  local puffs = {}
  for _ = 1, rng:int(4, 6) do
    local cx, cy = rng:range(x0 - w * 0.2, x1), rng:range(y0, y1)
    local tilt = rng:range(-0.25, 0.25)
    local size = rng:range(0.11, 0.2) * w
    for _ = 1, rng:int(4, 8) do
      puffs[#puffs + 1] = { cx, cy, size * rng:range(0.6, 1.2) }
      cx, cy = cx + size * rng:range(0.6, 1.1), cy + size * (tilt + rng:jit(0.3))
    end
  end
  return puffs
end

-- How much cloud covers (x, y): 0 in clear sky, 1 inside a puff's core
-- (puffs are drawn as ellipses 1.6 r across and 0.85 r tall).
local function cover(puffs, x, y)
  local c = 0
  for _, p in ipairs(puffs) do
    local dx, dy = (x - p[1]) / (p[3] * 1.6), (y - p[2]) / (p[3] * 0.85)
    c = math.max(c, 1 - G.smoothstep(0.35, 1, math.sqrt(dx * dx + dy * dy)))
  end
  return c
end

-- The night sky behind the cloud: dust-fine stars, a few brighter ones as
-- four-point twinkles, all fading where cloud lies over them.
local function starfield(pt, rng, puffs, x0, y0, x1, y1)
  local dots, twinkles = {}, {}
  local n = math.floor((x1 - x0) * (y1 - y0) * 0.09)
  for _ = 1, n do
    local x, y = rng:range(x0, x1), rng:range(y0, y1)
    local seen = 1 - cover(puffs, x, y)
    if seen > 0.15 then
      local bright = rng:next() ^ 3
      if bright > 0.8 and seen > 0.5 then
        twinkles[#twinkles + 1] = { op = 0.85 * seen, path = sparkle(x, y, 0.7 + bright * 0.8) }
      else
        local band = seen > 0.6 and 1 or 2
        dots[band] = dots[band] or {}
        table.insert(dots[band], { { "o", x, y, 0.14 + bright * 0.4 } })
      end
    end
  end
  if dots[1] then pt:fill(dots[1], pal.white, 0.85, { many = true }) end
  if dots[2] then pt:fill(dots[2], pal.white, 0.4, { many = true }) end
  for _, t in ipairs(twinkles) do pt:fill(t.path, pal.white, t.op) end
end

-- An ellipse at (x, y), rx across and ry tall, as a path.
local function ellipse(x, y, rx, ry)
  local pts = {}
  for k = 0, 15 do pts[#pts + 1] = { x + rx * math.cos(k * pi / 8), y + ry * math.sin(k * pi / 8) } end
  return G.smooth(pts, true)
end

-- Clouds as flattened puffs, each built from many faint shrinking layers so
-- its edge dissolves into the sky; a faint shadow sits under each bank's
-- belly and the tops catch a paler light. `sky` and `deep` are the sky's
-- dilute and pooled colours.
local CLOUD_LAYERS = 6
local function clouds(pt, puffs, sky, deep)
  local shadow = {}
  for _, p in ipairs(puffs) do shadow[#shadow + 1] = ellipse(p[1], p[2] - p[3] * 0.35, p[3] * 1.5, p[3] * 0.6) end
  pt:fill(shadow, deep, 0.1, { many = true })
  local tint = Paint.mix(pal.white, sky, 0.25)
  for k = 1, CLOUD_LAYERS do
    local sc = 1.5 - k / CLOUD_LAYERS
    local layer = {}
    for _, p in ipairs(puffs) do
      layer[#layer + 1] = ellipse(p[1], p[2] + p[3] * 0.06 * k, p[3] * 1.6 * sc, p[3] * 0.85 * sc)
    end
    pt:fill(layer, k > CLOUD_LAYERS - 2 and pal.white or tint, 0.09, { many = true })
  end
end

-- A luminous star at (cx, cy) in light rather than gilt: long needle rays
-- reaching rx across and ry up and down, shorter diagonals, fine rays
-- between, and a soft peach glow at its heart.
local GLOW = { 0.99, 0.86, 0.72 }
local function lit_star(pt, cx, cy, rx, ry)
  local c = { cx, cy }
  local r = math.min(rx, ry)
  local light = Paint.mix(pal.white, pal.sky, 0.18)
  local rays, haze, fine = {}, {}, {}
  for k = 0, 15 do
    local a = k * pi / 8
    local len, half, into
    if k % 4 == 0 then
      len, half, into = (k % 8 == 0) and rx or ry, r * 0.045, rays
    elseif k % 2 == 0 then
      len, half, into = r * 0.82, r * 0.04, rays
    else
      len, half, into = r * 0.4, r * 0.022, fine
    end
    into[#into + 1] = G.polyline({ c, G.polar(c, a + pi / 2, half), G.polar(c, a, len),
      G.polar(c, a - pi / 2, half) }, true)
    if into == rays then
      haze[#haze + 1] = G.polyline({ c, G.polar(c, a + pi / 2, half * 3), G.polar(c, a, len * 0.8),
        G.polar(c, a - pi / 2, half * 3) }, true)
    end
  end
  pt:fill(haze, pal.white, 0.12, { many = true })
  pt:fill(fine, light, 0.55, { many = true })
  pt:fill(rays, light, 0.9, { many = true })
  for k, rr in ipairs({ 0.28, 0.2, 0.13, 0.07 }) do
    pt:fill({ { "o", cx, cy, r * rr } }, k == 4 and pal.cream or GLOW, 0.2 + 0.18 * k)
  end
end

-- The cartouche's frame and sky for the box (x, y, w, h): a square frame
-- with a pale band, round a field with notched corners washed in the sky's
-- ink (palette.cartouche; the gilt stays gold). `sky` = {pigment, pool,
-- light, strength} changes the wash (default: the night blue). Returns the
-- field, for drawing inside it and for O.panel_close.
function O.panel_open(pt, rng, x, y, w, h, sky)
  sky = sky or {}
  local tint = Color.part_ink("cartouche")
  local f = {
    tint = tint, deep = Color.recolor(pal.deep, tint), dilute = Color.recolor(pal.sky, tint),
    ink = Color.recolor(pal.ink, tint),
  }
  local blue = Color.recolor(pal.blue, tint)
  local band = G.clamp(w * 0.065, 1.6, 3)
  f.x0, f.y0, f.x1, f.y1 = x + band, y + band, x + w - band, y + h - band
  f.c = math.min(w, h) * 0.09
  f.frame = G.polyline({ { x, y }, { x + w, y }, { x + w, y + h }, { x, y + h } }, true)
  pt:fill(f.frame, Paint.mix(blue, pal.paper, 0.86), 1)
  f.body = notched(f.x0, f.y0, f.x1, f.y1, f.c, 6)
  W.wash(pt, f.body, {
    rng = rng:fork("sky"), size = math.min(w, h), pigment = sky.pigment or pal.blue, pool = sky.pool or pal.deep,
    ink = tint, light = sky.light or { (f.x0 + f.x1) / 2, (f.y0 + f.y1) / 2 }, strength = sky.strength or 1,
    rings = 10, lift = 0.022, grain = 0.04, outline = 0, lost = 0, lifts = 0,
  })
  return f
end

-- The field's edge, a pale curl in each notch, and the frame's hairline.
function O.panel_close(pt, f)
  pt:stroke(G.polyline(f.body, true), Paint.mix(f.deep, pal.paper, 0.35), 0.35, 0.8)
  local curls = {}
  for _, q in ipairs({ { f.x0, f.y0, 0 }, { f.x1, f.y0, pi / 2 }, { f.x1, f.y1, pi }, { f.x0, f.y1, 3 * pi / 2 } }) do
    local pts = {}
    for s = 0, 6 do pts[#pts + 1] = G.polar(q, q[3] + s / 6 * pi / 2, f.c * 0.55) end
    curls[#curls + 1] = G.polyline(pts)
  end
  pt:stroke(curls, pal.white, 0.35, 0.9, { many = true })
  pt:stroke(f.frame, Paint.mix(f.ink, pal.paper, 0.25), 0.45, 0.9)
end

-- The star cartouche filling the box (x, y, w, h): a night field seen
-- through drifting cloud, stars in the gaps, a luminous star at its heart.
function O.panel(pt, rng, x, y, w, h)
  local f = O.panel_open(pt, rng, x, y, w, h)
  local puffs = cloud_puffs(rng:fork("clouds"), f.x0, f.y0, f.x1, f.y1)
  pt:clip_begin(G.polyline(f.body, true))
  starfield(pt, rng:fork("stars"), puffs, f.x0, f.y0, f.x1, f.y1)
  clouds(pt, puffs, f.dilute, f.deep)
  pt:clip_end()
  O.panel_close(pt, f)
  lit_star(pt, (f.x0 + f.x1) / 2, (f.y0 + f.y1) / 2, (f.x1 - f.x0) * 0.47, (f.y1 - f.y0) * 0.47)
end

-- Pieces of the night cartouche for other ornaments (orn_celestial.lua).
O.sparkle, O.ellipse, O.cloud_puffs, O.starfield, O.clouds, O.lit_star =
  sparkle, ellipse, cloud_puffs, starfield, clouds, lit_star

-- A pendant knot in the foot's corner, as in the reference, filling the box
-- centred at (x, y), w wide and h tall, and hung from a beaded cord running
-- `cord` pt up from its top. The seed picks its outline (an ogee shield,
-- lozenge, drop or roundel, drawn double) and the knot inside it (an
-- interlace, a quatrefoil or a beaded cross). Painted pale, as a group.
-- Returns the outline and knot chosen.
function O.pendant(pt, rng, x, y, w, h, cord)
  local shape = rng:weighted({ ogee = 3, lozenge = 2, drop = 2, roundel = 1.5 })
  local knot = rng:weighted({ interlace = 3, quatrefoil = 2, cross = 2 })
  local hw, hh = w / 2, h / 2 - 2.2
  local cy = y + 1.1
  local half
  if shape == "ogee" then
    half = { { 0, 1 }, { 0.62, 0.86 }, { 1, 0.42 }, { 0.86, -0.12 }, { 0.36, -0.62 }, { 0, -1 } }
  elseif shape == "lozenge" then
    half = { { 0, 1 }, { 0.5, 0.48 }, { 1, 0 }, { 0.5, -0.48 }, { 0, -1 } }
  elseif shape == "drop" then
    half = { { 0, 1 }, { 0.8, 0.72 }, { 1, 0.2 }, { 0.7, -0.4 }, { 0, -1 } }
  else
    half = {}
    for k = 0, 8 do half[#half + 1] = { math.sin(k * pi / 8), math.cos(k * pi / 8) } end
  end
  local function outline(sc)
    local pts = {}
    for _, q in ipairs(half) do pts[#pts + 1] = { x + q[1] * hw * sc, cy + q[2] * hh * sc } end
    for i = #half - 1, 2, -1 do pts[#pts + 1] = { x - half[i][1] * hw * sc, cy + half[i][2] * hh * sc } end
    return pts
  end
  pt:group_begin(0.7)
  local smooth = shape ~= "lozenge"
  local function path(pts) return smooth and G.smooth(pts, true) or G.polyline(pts, true) end
  pt:stroke({ path(outline(0.96)), path(outline(0.8)) }, pal.gold, 0.32, 0.85, { many = true })
  local paths, dots = {}, {}
  local u = math.min(hw, hh)
  if knot == "interlace" then
    paths[#paths + 1] = ellipse(x, cy, u * 0.3, hh * 0.5)
    paths[#paths + 1] = ellipse(x, cy, hw * 0.5, u * 0.3)
    paths[#paths + 1] = { { "o", x, cy, u * 0.14 } }
  elseif knot == "quatrefoil" then
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      paths[#paths + 1] = { { "o", x + d[1] * u * 0.26, cy + d[2] * u * 0.26, u * 0.24 } }
    end
    dots[#dots + 1] = { { "o", x, cy, u * 0.08 } }
  else
    paths[#paths + 1] = G.polyline({ { x, cy + hh * 0.6 }, { x, cy - hh * 0.6 } })
    paths[#paths + 1] = G.polyline({ { x - hw * 0.55, cy }, { x + hw * 0.55, cy } })
    paths[#paths + 1] = G.polyline({ { x, cy + u * 0.2 }, { x + u * 0.2, cy }, { x, cy - u * 0.2 }, { x - u * 0.2, cy } }, true)
    for _, q in ipairs({ { 0, hh * 0.6 }, { 0, -hh * 0.6 }, { hw * 0.55, 0 }, { -hw * 0.55, 0 } }) do
      dots[#dots + 1] = { { "o", x + q[1], cy + q[2], 0.6 } }
    end
  end
  pt:stroke(paths, pal.gold, 0.28, 0.85, { many = true })
  -- A drop under the point, and the cord with its beads.
  dots[#dots + 1] = { { "o", x, y - h / 2 + 0.9, 0.9 } }
  local top = cy + hh * 0.96
  if (cord or 0) > 0 then
    pt:stroke(G.polyline({ { x, top }, { x, top + cord } }), pal.gold, 0.25, 0.8)
    local beads = rng:int(1, 3)
    for k = 1, beads do dots[#dots + 1] = { { "o", x, top + cord * k / (beads + 1), 0.75 } } end
  end
  pt:fill(dots, pal.gold, 0.9, { many = true })
  pt:group_end()
  return shape, knot
end

return O
