-- Framed cartouches on the bare page: an oval in pierced scrollwork and a
-- shield in flat strapwork, each round a small gilt vignette on a pale
-- wash. The wash takes palette.cartouche.

local Orn = require("flora.ornaments")
local K = require("flora.orn_kit")
local G = require("flora.geom")
local Paint = require("flora.paint")
local Color = require("flora.color")

local pal = Paint.palette
local pi = math.pi

-- The pale ground's colour: the cartouche ink, much diluted.
local function ground()
  return Color.recolor(pal.sky, Color.part_ink("cartouche"))
end

-- A gilt vignette of size s at (x, y): a small sun, crescent, compass star
-- or rosette, picked by rng.
local function vignette(pt, rng, x, y, s)
  local kind = rng:weighted({ sun = 3, moon = 2, star = 2, rosette = 2 })
  if kind == "sun" then
    local lit, shade = K.rays(x, y, s * 0.42, s, 12, { flames = true })
    K.gilt(pt, lit, shade)
    pt:fill(K.dot(x, y, s * 0.42), pal.gold, 0.95)
    pt:fill(K.dot(x - s * 0.08, y + s * 0.08, s * 0.28), pal.cream, 0.5)
  elseif kind == "moon" then
    pt:fill(G.smooth(K.crescent(x, y, s * 0.8, 0.6, rng:range(-0.4, 0.4)), true), pal.gold, 0.95)
    pt:fill(K.ring(x, y, s * 1.05, 5, s * 0.06, rng:range(0, pi)), pal.gold, 0.8, { many = true })
  elseif kind == "star" then
    local lit, shade = K.rays(x, y, s * 0.12, s, 8, { short = 0.5, width = 0.28 })
    K.gilt(pt, lit, shade)
    pt:fill(K.dot(x, y, s * 0.1), pal.cream, 1)
  else
    local petals = {}
    for k = 0, 7 do
      local p = G.polar({ x, y }, k * pi / 4, s * 0.52)
      petals[#petals + 1] = G.smooth(K.ellipse(p[1], p[2], s * 0.42, s * 0.2, k * pi / 4, 16), true)
    end
    pt:fill(petals, pal.gold, 0.7, { many = true })
    pt:fill(K.dot(x, y, s * 0.24), pal.copper, 0.9)
  end
  return kind
end

-- A gilt scroll: a copper shadow under a gold tapered ribbon.
local function scroll(pt, p, ang, s, dir, w)
  local pts = K.scroll(p, ang, s, dir)
  local shadow = {}
  for i, q in ipairs(pts) do shadow[i] = { q[1] + w * 0.25, q[2] - w * 0.25 } end
  pt:fill(K.taper(shadow, w, 0.25), pal.copper, 0.7)
  pt:fill(K.taper(pts, w, 0.25), pal.gold, 0.95)
end

Orn.register({
  name = "scrolled", slot = "cartouche", label = "Scrolled oval", reach = 0.02,
  draw = function(pt, rng, b)
    local cx, cy, w, h = K.measure(b)
    local rx, ry = w * 0.27, h * 0.27
    local s = math.min(w, h)
    local oval = G.smooth(K.ellipse(cx, cy, rx, ry, 0, 40), true)
    pt:fill(oval, ground(), 0.3)
    pt:fill(G.smooth(K.ellipse(cx, cy + ry * 0.15, rx * 0.8, ry * 0.7, 0, 32), true), pal.white, 0.35)
    -- Scrolls: a pair at the head and the foot, curling outward, and one
    -- at each side.
    local sw = s * 0.05
    for _, d in ipairs({ -1, 1 }) do
      scroll(pt, { cx + d * rx * 0.25, cy + ry * 0.98 }, pi / 2 + d * -0.9, s * 0.34, -d, sw)
      scroll(pt, { cx + d * rx * 0.25, cy - ry * 0.98 }, -pi / 2 + d * 0.9, s * 0.34, d, sw)
      scroll(pt, { cx + d * rx * 0.98, cy + ry * 0.2 }, d > 0 and -0.3 or pi + 0.3, s * 0.26, d, sw * 0.9)
    end
    pt:stroke({ oval, G.smooth(K.ellipse(cx, cy, rx * 0.9, ry * 0.92, 0, 40), true) }, pal.gold, 0.55, 0.95, { many = true })
    -- Beads between the two rims, a trefoil crest and a drop below.
    local beads = {}
    for k = 0, 31 do
      local a = k * pi / 16
      beads[#beads + 1] = K.dot(cx + rx * 0.95 * math.cos(a), cy + ry * 0.96 * math.sin(a), s * 0.012)
    end
    pt:fill(beads, pal.gold, 0.9, { many = true })
    pt:fill(K.trefoil(cx, cy + ry + s * 0.17, s * 0.13, pi / 2), pal.gold, 0.95, { many = true })
    pt:fill(G.smooth(K.leaf(cx, cy - ry - s * 0.06, s * 0.15, -pi / 2), true), pal.gold, 0.95)
    vignette(pt, rng, cx, cy, s * 0.17)
  end,
})

-- A heater shield: flat top, sides curving into a point at the foot.
local function shield(cx, top, w, h, k)
  local pts = {}
  for i = 0, 10 do
    local t = i / 10
    pts[#pts + 1] = { cx + w / 2 * k * (1 - t ^ 2.2), top - h * k * t }
  end
  local out = { { cx - w / 2 * k, top } }
  for i = 1, #pts do out[#out + 1] = pts[i] end
  for i = #pts - 1, 1, -1 do out[#out + 1] = { 2 * cx - pts[i][1], pts[i][2] } end
  return out
end

Orn.register({
  name = "strapwork", slot = "cartouche", label = "Strapwork shield", reach = 0.02,
  draw = function(pt, rng, b)
    local cx, cy, w, h = K.measure(b)
    local s = math.min(w, h)
    local top, sw, sh = cy + h * 0.27, w * 0.62, h * 0.6
    local outer = G.polyline(shield(cx, top, sw, sh, 1), true)
    local inner = G.polyline(shield(cx, top - s * 0.05, sw, sh - s * 0.06, 0.84), true)
    pt:fill(outer, ground(), 0.3)
    -- The strap: a flat band between two rims, rolled into a loop at each
    -- top corner and pierced with an oval at each side.
    local band = {}
    for _, d in ipairs({ -1, 1 }) do
      local corner = { cx + d * sw / 2, top }
      band[#band + 1] = G.smooth(K.ellipse(corner[1] + d * s * 0.07, corner[2] + s * 0.06, s * 0.1, s * 0.07, d * 0.5, 20), true)
      local side = { cx + d * sw * 0.52, top - sh * 0.38 }
      band[#band + 1] = G.smooth(K.ellipse(side[1] + d * s * 0.05, side[2], s * 0.06, s * 0.11, 0, 20), true)
    end
    pt:stroke(band, pal.copper, 1.6, 0.55, { many = true })
    pt:stroke(band, pal.gold, 1.0, 0.95, { many = true })
    pt:stroke({ outer, inner }, pal.copper, 0.9, 0.5, { many = true })
    pt:stroke({ outer, inner }, pal.gold, 0.55, 0.95, { many = true })
    -- Rivets along the strap.
    local rivets = {}
    local mid = shield(cx, top - s * 0.025, sw, sh - s * 0.03, 0.92)
    for i = 1, #mid, 2 do rivets[#rivets + 1] = K.dot(mid[i][1], mid[i][2], s * 0.016) end
    pt:fill(rivets, pal.cream, 0.95, { many = true })
    -- A cresting of three trefoils above the flat top.
    for k = -1, 1 do
      pt:fill(K.trefoil(cx + k * sw * 0.3, top + s * 0.12, s * (k == 0 and 0.12 or 0.08), pi / 2), pal.gold, 0.9, { many = true })
    end
    vignette(pt, rng, cx, top - sh * 0.42, s * 0.16)
  end,
})

return { vignette = vignette, scroll = scroll }
