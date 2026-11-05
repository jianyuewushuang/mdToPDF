-- Shared shapes for the ornament kinds: gilt fills, rays, crescents,
-- scrolls and fleurons. Shapes return paths (paint.lua commands) or point
-- lists; painting stays with the kinds. Angles are radians, y points up.

local G = require("flora.geom")
local Paint = require("flora.paint")

local K = {}
local pal = Paint.palette
local pi, sin, cos = math.pi, math.sin, math.cos

K.gold, K.copper, K.cream, K.white = pal.gold, pal.copper, pal.cream, pal.white

-- Centre, width, height and smaller side of box {x0, y0, x1, y1}.
function K.measure(b)
  local w, h = b[3] - b[1], b[4] - b[2]
  return (b[1] + b[3]) / 2, (b[2] + b[4]) / 2, w, h, math.min(w, h)
end

function K.dot(x, y, r)
  return { { "o", x, y, r } }
end

-- n dots of radius r on a circle of radius R about (x, y), from angle a0.
function K.ring(x, y, R, n, r, a0)
  local out = {}
  for k = 0, n - 1 do
    local p = G.polar({ x, y }, (a0 or pi / 2) + k * 2 * pi / n, R)
    out[#out + 1] = K.dot(p[1], p[2], r)
  end
  return out
end

-- Points of an ellipse about (x, y), turned by `rot`.
function K.ellipse(x, y, rx, ry, rot, n)
  n = n or 32
  local c, s = cos(rot or 0), sin(rot or 0)
  local out = {}
  for k = 0, n - 1 do
    local a = k * 2 * pi / n
    local u, v = rx * cos(a), ry * sin(a)
    out[#out + 1] = { x + u * c - v * s, y + u * s + v * c }
  end
  return out
end

-- An n-pointed star polygon, outer radius R and inner r.
function K.star(x, y, R, r, n, rot)
  local out = {}
  for k = 0, 2 * n - 1 do
    out[#out + 1] = G.polar({ x, y }, (rot or pi / 2) + k * pi / n, k % 2 == 0 and R or r)
  end
  return out
end

-- Rays round (x, y) from radius r0 to r1, each split into a lit and a
-- shaded half as the compass's are. Every other ray is a flame (wavy) when
-- `flames` is set, as in a sun in splendour. Returns lit and shade paths.
function K.rays(x, y, r0, r1, n, o)
  o = o or {}
  local lit, shade = {}, {}
  for k = 0, n - 1 do
    local a = (o.rot or pi / 2) + k * 2 * pi / n
    local long = k % 2 == 0
    local len = long and r1 or r0 + (r1 - r0) * (o.short or 0.62)
    local half = (o.width or 0.18) * 2 * pi / n * r0
    local base = G.polar({ x, y }, a, r0)
    local tip = G.polar({ x, y }, a, len)
    local l, r = G.polar(base, a + pi / 2, half), G.polar(base, a - pi / 2, half)
    if o.flames and not long then
      -- A flame: the ray's spine waves twice on its way out.
      local spine = {}
      for i = 0, 8 do
        local t = i / 8
        local p = G.polar({ x, y }, a, r0 + (len - r0) * t)
        spine[#spine + 1] = G.polar(p, a + pi / 2, half * 0.7 * sin(t * 2 * pi) * (1 - t))
      end
      local left, right = {}, {}
      for i, p in ipairs(spine) do
        local w = half * (1 - (i - 1) / 8)
        left[#left + 1] = G.polar(p, a + pi / 2, w)
        right[#right + 1] = G.polar(p, a - pi / 2, w)
      end
      local poly = {}
      for i = 1, #left do poly[#poly + 1] = left[i] end
      for i = #right, 1, -1 do poly[#poly + 1] = right[i] end
      lit[#lit + 1] = G.smooth(poly, true)
    else
      lit[#lit + 1] = G.polyline({ base, tip, l }, true)
      shade[#shade + 1] = G.polyline({ base, tip, r }, true)
    end
  end
  return lit, shade
end

-- Paint gilt: shaded halves in copper under lit ones in gold.
function K.gilt(pt, lit, shade, opacity)
  if shade and #shade > 0 then pt:fill(shade, pal.copper, opacity or 0.95, { many = true }) end
  if lit and #lit > 0 then pt:fill(lit, pal.gold, opacity or 0.95, { many = true }) end
end

-- A crescent of radius r about (x, y): the circle less a second one
-- shifted by `bite` (share of r) toward angle `rot`. Points, closed.
function K.crescent(x, y, r, bite, rot)
  local out = {}
  local d = r * bite
  -- The two circles meet where |p| = r and |p - d e| = r: at angle
  -- acos(d / 2r) either side of the bite's direction.
  local m = math.acos(G.clamp(d / (2 * r), -1, 1))
  local n = 24
  for k = 0, n do
    local a = rot + m + (2 * pi - 2 * m) * k / n
    out[#out + 1] = G.polar({ x, y }, a, r)
  end
  -- Back along the second circle's arc inside the first: seen from its
  -- centre the ends sit at rot +- (pi - m), and the arc passes rot + pi.
  local c2 = { x + d * cos(rot), y + d * sin(rot) }
  for k = 1, n - 1 do
    out[#out + 1] = G.polar(c2, rot + pi + m - 2 * m * k / n, r)
  end
  return out
end

-- A C-scroll: a spiral from `p` heading `ang`, of size s, curling to the
-- left (dir 1) or right (dir -1) for `turns` turns. Points.
function K.scroll(p, ang, s, dir, turns)
  turns = turns or 1.15
  local out = {}
  local n = 28
  local x, y, a = p[1], p[2], ang
  for i = 0, n do
    out[#out + 1] = { x, y }
    local t = i / n
    local step = s * 0.11 * (1 - 0.82 * t)
    a = a + dir * turns * 2 * pi / n * (0.55 + 0.9 * t)
    x, y = x + step * cos(a), y + step * sin(a)
  end
  return out
end

-- A tapered ribbon along `pts`, w wide at its start, as a filled path.
function K.taper(pts, w, tail)
  return G.smooth(G.ribbon(pts, function(t) return w * (1 - (1 - (tail or 0.15)) * t) / 2 end), true)
end

-- A heart-shaped leaf (a hedera, the printers' fleuron) of size s: the
-- notch at the stalk sits at (x, y) and the tip lies s away toward `ang`.
-- The outline is the classic heart curve, point outward, narrowed by
-- `wide` (default 1). Points, closed.
function K.leaf(x, y, s, ang, wide)
  local pts = {}
  for k = 0, 39 do
    local t = k * 2 * pi / 40
    local hx = 16 * sin(t) ^ 3
    local hy = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
    pts[#pts + 1] = { hx / 22 * 0.9, (5 - hy) / 22 }
  end
  return G.transform(pts, x, y, ang - pi / 2, s * (wide or 1), s)
end

-- A pointed lozenge (a fleuron's petal) of length s from (x, y) toward
-- `ang`, widest just behind its middle. Points, closed.
function K.lozenge(x, y, s, ang)
  local right, pts = {}, {}
  for k = 0, 12 do
    local t = k / 12
    right[#right + 1] = { 0.34 * sin(pi * t) ^ 1.3 * (1 - 0.25 * t), t }
  end
  for _, q in ipairs(right) do pts[#pts + 1] = q end
  for k = #right - 1, 2, -1 do pts[#pts + 1] = { -right[k][1], right[k][2] } end
  return G.transform(pts, x, y, ang - pi / 2, s, s)
end

-- Three round lobes (a trefoil) of size s, pointing `ang`. Paths.
function K.trefoil(x, y, s, ang)
  local out = {}
  for k = -1, 1 do
    local p = G.polar({ x, y }, ang + k * 2 * pi / 3, s * 0.42)
    out[#out + 1] = K.dot(p[1], p[2], s * 0.36)
  end
  return out
end

-- A gilt armillary sphere of radius r about (x, y): the outer ring, a
-- tilted equator and ecliptic, a meridian, the axis and a small sun at the
-- centre, standing on a short stem whose foot is no lower than `floor`.
function K.armillary(pt, x, y, r, tilt, floor)
  local rings = {
    G.smooth(K.ellipse(x, y, r, r, 0, 40), true),
    G.smooth(K.ellipse(x, y, r, r * 0.3, -tilt, 40), true),
    G.smooth(K.ellipse(x, y, r * 0.32, r, 0, 40), true),
    G.smooth(K.ellipse(x, y, r, r * 0.24, tilt * 0.6, 40), true),
  }
  local w = math.max(0.3, r * 0.025)
  pt:stroke(rings, pal.copper, w * 1.7, 0.55, { many = true })
  pt:stroke(rings, pal.gold, w, 0.95, { many = true })
  pt:stroke(G.smooth(K.ellipse(x, y, r * 0.93, r * 0.22, -tilt, 40), true), pal.gold, w * 0.55, 0.7)
  local a = pi / 2 - tilt * 0.6
  pt:stroke(G.polyline({ G.polar({ x, y }, a, r * 1.22), G.polar({ x, y }, a + pi, r * 1.22) }), pal.copper, w * 0.9, 0.9)
  pt:fill(K.dot(x, y, r * 0.13), pal.gold, 0.95)
  pt:fill(K.dot(x - r * 0.03, y + r * 0.03, r * 0.06), pal.cream, 0.9)
  local foot = math.max(floor or -math.huge, y - r * 1.45)
  pt:stroke(G.polyline({ { x, y - r }, { x, foot } }), pal.gold, w * 1.2, 0.9)
  pt:fill(G.smooth(K.ellipse(x, foot, r * 0.42, r * 0.09, 0, 20), true), pal.gold, 0.9)
end

-- Run draw(x0, y0, s) for the lower-left corner of box b, mirrored into
-- another corner by o.flip = {fx, fy} (each 1 or -1).
function K.corner(pt, b, o, draw)
  local cx, cy, _, _, s = K.measure(b)
  local fx, fy = (o.flip or {})[1] or 1, (o.flip or {})[2] or 1
  local base = pt.frame_fn
  pt:frame(function(x, y)
    x, y = cx + fx * (x - cx), cy + fy * (y - cy)
    if base then return base(x, y) end
    return x, y
  end)
  draw(cx - s / 2, cy - s / 2, s)
  pt:frame(base)
end

return K
