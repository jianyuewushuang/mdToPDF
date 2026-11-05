-- Visitors to the border: a bee on a dotted flight path, a butterfly, a
-- songbird perched on its own twig and a snail climbing the main stem.
-- They follow Kevin Raymond's florilegium (github.com/kevinraymond/
-- florilegium), drawn here in this package's washes and pen work.
--
-- How many come is the page's mix (mix.lua): each visitor's weight scales
-- its chance per page. They are placed after the leaves and before the
-- holes fill, on their own random stream, and nothing is touched when every
-- visitor's weight is 0, so such a page is exactly a page without them.

local G = require("flora.geom")
local W = require("flora.wash")
local Paint = require("flora.paint")
local Color = require("flora.color")
local Mix = require("flora.mix")

local V = {}
local pi, cos, sin, min, max, floor = math.pi, math.cos, math.sin, math.min, math.max, math.floor
local pal = Paint.palette
local MULT = { blend = "multiply" }

-- Chance per page at weight 1, the most per page, and the radius each
-- needs clear around it (pt).
V.kinds = {
  bee = { chance = 0.6, most = 3, room = 14 },
  butterfly = { chance = 0.7, most = 3, room = 20 },
  bird = { chance = 0.5, most = 1, room = 28 },
  snail = { chance = 0.45, most = 1, room = 12 },
}

-- An ellipse of radii rx, ry around (cx, cy), as a polygon.
local function ellipse(cx, cy, rx, ry, n)
  local out = {}
  n = n or 18
  for i = 0, n - 1 do
    local a = 2 * pi * i / n
    out[#out + 1] = { cx + rx * cos(a), cy + ry * sin(a) }
  end
  return out
end

local function place(pts, x, y, ang, s)
  return G.transform(pts, x, y, ang, s, s)
end

local function hair(pt, pts, w, op)
  pt:stroke(G.polyline(pts), pal.ink, w, op or 0.85, MULT)
end

-- A bee at (x, y) heading `ang`, about `L` pt long.
function V.bee(pt, rng, x, y, ang, L)
  local s = L / 13
  local function at(pts) return place(pts, x, y, ang, s) end
  -- Wings first, so the body lies over their roots: pale and glassy.
  for _, w in ipairs({ { 1.5, 4.2, 0.55 }, { -0.5, 3.6, 0.95 } }) do
    local wing = at(G.transform(ellipse(0, 0, 4.4, 2.0), w[1], w[2], w[3]))
    pt:fill(G.smooth(wing, true), pal.white, 0.75)
    pt:fill(G.smooth(wing, true), pal.sky, 0.10, MULT)
    pt:stroke(G.smooth(wing, true), pal.ink, 0.25 * s, 0.55, MULT)
  end
  -- Legs under the thorax.
  for k = -1, 1 do
    hair(pt, at({ { 1.8 + k * 1.2, -1.6 }, { 1.2 + k * 1.6, -3.4 }, { 0.6 + k * 1.8, -4.2 } }), 0.3 * s)
  end
  -- The abdomen: a gold wash crossed by ink bands.
  local abd = at(ellipse(-2.6, 0, 4.8, 3.2))
  W.wash(pt, abd, { rng = rng, size = 6 * s, pigment = pal.gold, pool = pal.copper,
    simple = true, rings = 5, lift = 0.12, grain = 0.4, outline = 0.6, outline_w = 0.3 * s })
  pt:clip_begin(G.smooth(abd, true))
  for _, bx in ipairs({ -4.6, -2.4, -0.2 }) do
    pt:stroke(G.polyline(at({ { bx + 0.4, -4 }, { bx - 0.4, 4 } })), pal.ink, 1.1 * s, 0.8, MULT)
  end
  pt:clip_end()
  hair(pt, at({ { -7.4, 0 }, { -8.6, -0.3 } }), 0.4 * s)
  -- Thorax and head in ink, with antennae.
  pt:fill(G.smooth(at(ellipse(2.3, 0, 2.6, 2.4)), true), pal.ink, 0.85, MULT)
  pt:fill(G.smooth(at(ellipse(5.2, 0.2, 1.7, 1.6)), true), pal.ink, 0.9, MULT)
  hair(pt, at({ { 6.2, 1.2 }, { 7.6, 2.8 }, { 8.8, 3.1 } }), 0.25 * s)
  hair(pt, at({ { 6.3, 0.8 }, { 8.0, 1.8 }, { 9.1, 1.6 } }), 0.25 * s)
end

-- The bee's dotted flight path: a loop behind it, ending at its tail.
-- Points must satisfy ok(x, y); the path stops at the first that does not.
function V.trail(rng, x, y, ang, L, ok)
  local pts = {}
  local turn = rng:chance(0.5) and 1 or -1
  local loop_at = rng:range(0.35, 0.6)
  local n = 70
  local back = ang + pi
  local px, py = x + cos(back) * L * 0.6, y + sin(back) * L * 0.6
  local h = back + turn * rng:range(-0.3, 0.3)
  for i = 1, n do
    local u = i / n
    -- A gentle wander with one full loop partway.
    local k = 0.04 * sin(u * 7) + (math.abs(u - loop_at) < 0.12 and turn * 0.55 or 0)
    h = h + k
    px, py = px + cos(h) * 2.2, py + sin(h) * 2.2
    if not ok(px, py) then break end
    pts[#pts + 1] = { px, py }
  end
  return pts
end

function V.paint_trail(pt, pts)
  for i = 1, #pts, 2 do
    pt:fill({ { "o", pts[i][1], pts[i][2], 0.6 } }, pal.ink, 0.6, MULT)
  end
end

-- One wing from the body's root: points in units of the span, right side.
local FORE = { { 0, 1 }, { 4, 7 }, { 10, 12 }, { 14, 12.5 }, { 14.5, 8.5 }, { 10, 3.5 }, { 3, 0.5 } }
local HIND = { { 0, -0.5 }, { 6, -1.5 }, { 10.5, -5 }, { 9, -10.5 }, { 4, -11 }, { 1, -6 } }

-- A butterfly at (x, y), body along `ang` (head forward), wings open by
-- `open` (1 flat open, toward 0 folded), about `S` pt across.
function V.butterfly(pt, rng, x, y, ang, S, open)
  local s = S / 29
  local rot = ang - pi / 2
  local ink = Color.ink_for(rng, rng:pick({ "blue", "violet", "teal" }))
  for _, side in ipairs({ 1, -1 }) do
    for wi, shape in ipairs({ HIND, FORE }) do
      local w = {}
      for i, p in ipairs(shape) do w[i] = { side * p[1] * open, p[2] } end
      local poly = place(w, x, y, rot, s)
      local tipi = wi == 2 and 4 or 4
      local tip = place({ { side * shape[tipi][1] * open, shape[tipi][2] } }, x, y, rot, s)[1]
      W.wash(pt, poly, { rng = rng:fork("wing" .. side .. wi), size = 12 * s,
        ramp = "vivid", part = "blooms", axis = { { x, y }, tip },
        pigment = ink and Color.ink_rgb(ink, 0.5) or pal.blue, pool = pal.deep,
        simple = true, outline = 0.55, outline_w = 0.3 * s, grain = 0.15 })
      -- Pale eyespots near the wing's outer edge.
      local c = place({ { side * (shape[tipi][1] - 3) * open, shape[tipi][2] - 1.5 } }, x, y, rot, s)[1]
      pt:fill({ { "o", c[1], c[2], 1.1 * s } }, pal.white, 0.8)
    end
  end
  local body = place(ellipse(0, -1, 1.1, 7), x, y, rot, s)
  pt:fill(G.smooth(body, true), pal.ink, 0.85, MULT)
  for _, side in ipairs({ 1, -1 }) do
    local a = place({ { 0, 5.5 }, { side * 2.5, 10 }, { side * 4, 12.5 } }, x, y, rot, s)
    hair(pt, a, 0.3 * s)
    pt:fill({ { "o", a[3][1], a[3][2], 0.6 * s } }, pal.ink, 0.85, MULT)
  end
end

-- A songbird in profile perched at (x, y) (its feet), facing right when
-- dir is 1 and left when -1, about `L` pt from tail to beak.
local BIRD = { { -17, -1 }, { -13, 1.5 }, { -6, 6.5 }, { 2, 8.5 }, { 8, 12 }, { 12, 12.5 }, { 15, 10 },
  { 14.5, 6.5 }, { 11, 3 }, { 7, -2.5 }, { 0, -6 }, { -6, -5.5 }, { -12, -2.5 } }
local WING = { { -11, 1 }, { -4, 6 }, { 4, 6.5 }, { 7, 2.5 }, { 0, -1.5 }, { -7, -1 } }

function V.bird(pt, rng, x, y, dir, L)
  local s = L / 32
  local function at(pts)
    local out = {}
    for i, p in ipairs(pts) do out[i] = { x + dir * p[1] * s, y + (p[2] + 9) * s } end
    return out
  end
  -- Legs and toes gripping the twig.
  for _, lx in ipairs({ -1.5, 1.5 }) do
    hair(pt, at({ { lx, -5.5 }, { lx + 0.5, -8 }, { lx, -9 } }), 0.45 * s)
    hair(pt, at({ { lx - 1.6, -9 }, { lx + 1.8, -9 } }), 0.4 * s)
  end
  local ink = Color.ink_for(rng, rng:pick({ "blue", "blue-grey", "teal" }))
  local body = at(BIRD)
  W.wash(pt, body, { rng = rng:fork("body"), size = 18 * s, ramp = "soft", part = "blooms",
    axis = { at({ { 6, -4 } })[1], at({ { -4, 8 } })[1] },
    pigment = ink and Color.ink_rgb(ink, 0.55) or pal.blue, pool = pal.deep,
    simple = true, outline = 0.6, outline_w = 0.35 * s, grain = 0.12 })
  local wing = at(WING)
  W.wash(pt, wing, { rng = rng:fork("wing"), size = 12 * s, ramp = "vivid", part = "blooms",
    axis = { at({ { 5, 3 } })[1], at({ { -11, 1 } })[1] },
    pigment = pal.blue, pool = pal.deep, simple = true, outline = 0.5, outline_w = 0.3 * s })
  -- Feather lines along the wing.
  for k = 0, 2 do
    hair(pt, at({ { 3 - k * 2, 4 - k * 1.2 }, { -4 - k * 2, 3 - k * 1.5 }, { -9 - k, 0.5 - k * 0.6 } }), 0.2 * s, 0.5)
  end
  -- Beak, eye.
  local beak = at({ { 14.6, 10.5 }, { 19.5, 9.2 }, { 14.6, 8 } })
  pt:fill(G.polyline(beak, true), pal.gold, 0.9, MULT)
  pt:stroke(G.polyline(beak, true), pal.ink, 0.25 * s, 0.8, MULT)
  local eye = at({ { 11.4, 9.6 } })[1]
  pt:fill({ { "o", eye[1], eye[2], 0.95 * s } }, pal.ink, 0.95, MULT)
  pt:fill({ { "o", eye[1] + dir * 0.3 * s, eye[2] + 0.3 * s, 0.3 * s } }, pal.white, 0.9)
end

-- A snail at (x, y) on a stem heading `ang`, its shell to side `side`
-- (1 left of the heading, -1 right), about `L` pt long.
function V.snail(pt, rng, x, y, ang, side, L)
  local s = L / 18
  local function at(pts)
    local out = {}
    for i, p in ipairs(pts) do out[i] = p end
    return G.transform(out, x, y, ang, s, s * side)
  end
  local foot = at({ { -9, 0.4 }, { -4, 2.2 }, { 4, 2.6 }, { 8, 3.4 }, { 10, 2.6 }, { 9.5, 0.8 }, { 4, 0.2 }, { -4, -0.2 } })
  W.wash(pt, foot, { rng = rng:fork("foot"), size = 8 * s, pigment = pal.mist or pal.sky, pool = pal.sky,
    simple = true, rings = 4, lift = 0.1, outline = 0.5, outline_w = 0.25 * s })
  for _, t in ipairs({ { 9, 3 }, { 9.8, 2.6 } }) do
    local tip = { t[1] + 2.4, t[2] + 3.2 }
    hair(pt, at({ t, { t[1] + 1.2, t[2] + 1.8 }, tip }), 0.3 * s)
    local q = at({ tip })[1]
    pt:fill({ { "o", q[1], q[2], 0.45 * s } }, pal.ink, 0.85, MULT)
  end
  local earth = Color.ink_for(rng, rng:pick({ "earth", "gold", "warm" }))
  local shell = at(ellipse(-1, 7, 6.2, 5.8, 22))
  W.wash(pt, shell, { rng = rng:fork("shell"), size = 9 * s, ramp = "soft", part = "leaves",
    axis = { at({ { 1, 10 } })[1], at({ { -4, 3 } })[1] },
    pigment = earth and Color.ink_rgb(earth, 0.55) or pal.gold, pool = pal.copper,
    simple = true, outline = 0.6, outline_w = 0.3 * s, grain = 0.25 })
  -- The whorl.
  local spiral = {}
  for i = 0, 40 do
    local a = i / 40 * 2.6 * pi
    local r = 5.4 * (1 - i / 46)
    spiral[#spiral + 1] = { -1 + r * cos(a + 0.6), 7 + r * sin(a + 0.6) }
  end
  hair(pt, at(spiral), 0.35 * s, 0.7)
end

-- How many of `kind` come to a page with mix weight w.
local function count(rng, kind, w)
  local k = V.kinds[kind]
  local e = k.chance * w
  local n = floor(e)
  if rng:next() < e - n then n = n + 1 end
  return min(n, k.most)
end

-- Open cells with at least `need` clearance, as {x, y, room}.
local function open_spots(g, need)
  local out = {}
  local f, nx, c = g.f, g.nx, g.c
  for k = 0, g.nx * g.ny - 1 do
    if f[k] and f[k] >= need then
      out[#out + 1] = { (k % nx + 0.5) * c, (k // nx + 0.5) * c, f[k] }
    end
  end
  return out
end

-- Place the page's visitors. ctx.visitors collects their painters; ctx.mix
-- is the page's mix; strands are the plant's stems, the main one first.
-- Returns at once, touching nothing, when no visitor has weight.
function V.place(g, rng, ctx, strands)
  local want = {}
  local any = false
  for _, kind in ipairs(Mix.visitors) do
    local w = Mix.weight(ctx.mix, kind)
    want[kind] = w > 0 and count(rng:fork(kind), kind, w) or 0
    any = any or want[kind] > 0
  end
  if not any then return end
  ctx.visitors = ctx.visitors or {}
  local placed = {}
  local function add(kind, fn, x, y)
    ctx.visitors[#ctx.visitors + 1] = fn
    if ctx.pos then ctx.pos[fn] = { x, y } end
    placed[kind] = (placed[kind] or 0) + 1
  end
  local main = strands[1]

  -- The snail climbs the main stem, low down, on the side with more room.
  if want.snail > 0 and main then
    local r = rng:fork("snail")
    for _ = 1, 8 do
      local t = r:range(0.15, 0.45)
      local p, a = G.at(main.pts, t)
      local L = r:range(26, 31)
      local best, side = -1, 1
      for _, sd in ipairs({ 1, -1 }) do
        local q = G.polar(p, a + sd * pi / 2, L * 0.45)
        local rm = g:room(q[1], q[2])
        if rm > best then best, side = rm, sd end
      end
      if best >= V.kinds.snail.room * 0.6 then
        local c = G.polar(p, a + side * pi / 2, L * 0.4)
        g:disc(c[1], c[2], L * 0.55, 1)
        local fr = r:fork("paint")
        add("snail", function(pt) V.snail(pt, fr, p[1], p[2], a, side, L) end, p[1], p[2])
        break
      end
    end
  end

  -- The bird perches at the end of its own twig from one of the stems,
  -- the main one first, where there is room for it.
  if want.bird > 0 and main then
    local r = rng:fork("bird")
    for try = 1, 40 do
      local st = try <= 15 and main or strands[r:int(1, #strands)]
      local t = r:range(0.25, 0.75)
      local p, a = G.at(st.pts, t)
      local sd = r:chance(0.5) and 1 or -1
      local out = a + sd * r:range(0.7, 1.1)
      local len = r:range(22, 34)
      local tip = G.polar(p, out, len)
      local L = r:range(40, 50)
      local body = { tip[1], tip[2] + L * 0.35 }
      if g:room(body[1], body[2]) >= L * 0.38 and g:open_at(tip[1], tip[2]) then
        local twig = G.link(p, a, tip, out + sd * 0.4, 0.5)
        local clear = true
        for i = 2, #twig do if not g:open_at(twig[i][1], twig[i][2]) then clear = false end end
        if clear then
          ctx.stem_batch:stem(twig, 0.9, 0.5)
          g:reserve_line(twig, 2, 4)
          g:disc(body[1], body[2], L * 0.5, 1)
          local dir = math.cos(out) >= 0 and 1 or -1
          local fr = r:fork("paint")
          add("bird", function(pt) V.bird(pt, fr, tip[1], tip[2], dir, L) end, tip[1], tip[2])
          break
        end
      end
    end
  end

  -- Bees and butterflies take open spaces away from the stems.
  for _, kind in ipairs({ "butterfly", "bee" }) do
    local r = rng:fork(kind .. " place")
    for n = 1, want[kind] do
      local need = V.kinds[kind].room
      local spots = open_spots(g, need)
      if #spots == 0 then break end
      local sp = spots[r:int(1, #spots)]
      local x, y = sp[1], sp[2]
      local fr = r:fork(kind .. n)
      if kind == "butterfly" then
        local S = min(sp[3] * 1.7, r:range(32, 42))
        local ang = pi / 2 + r:range(-0.7, 0.7)
        local open = r:range(0.7, 1)
        g:disc(x, y, S * 0.55, 1)
        add(kind, function(pt) V.butterfly(pt, fr, x, y, ang, S, open) end, x, y)
      else
        local L = r:range(16, 20)
        local ang = r:range(0, 2 * pi)
        g:disc(x, y, L * 0.7, 1)
        local trail = V.trail(fr:fork("trail"), x, y, ang, L, function(px, py) return g:free(px, py) end)
        if #trail > 4 then g:reserve_line(trail, 1.2, 4) end
        add(kind, function(pt)
          V.paint_trail(pt, trail)
          V.bee(pt, fr, x, y, ang, L)
        end, x, y)
      end
    end
  end
  ctx.counts = ctx.counts or {}
  for k, v in pairs(placed) do ctx.counts[k] = v end
end

return V
