-- Celestial cartouches: the night cartouche's frame and sky round a sun
-- in splendour, a crescent moon, a constellation, a ringed planet or an
-- armillary sphere. The sky takes palette.cartouche; gilt stays gold.

local Orn = require("flora.ornaments")
local O = require("flora.ornament")
local K = require("flora.orn_kit")
local G = require("flora.geom")
local Paint = require("flora.paint")

local pal = Paint.palette
local pi, sin, cos = math.pi, math.sin, math.cos

-- Open a cartouche on box b, run inner(f, w, h, cx, cy) clipped to its
-- field, close the frame, then run over(f, ...) on top of it.
local function cartouche(pt, rng, b, sky, inner, over)
  local f = O.panel_open(pt, rng, b[1], b[2], b[3] - b[1], b[4] - b[2], sky)
  local w, h = f.x1 - f.x0, f.y1 - f.y0
  local cx, cy = (f.x0 + f.x1) / 2, (f.y0 + f.y1) / 2
  pt:clip_begin(G.polyline(f.body, true))
  inner(f, w, h, cx, cy)
  pt:clip_end()
  O.panel_close(pt, f)
  if over then over(f, w, h, cx, cy) end
end

-- Dust stars over the whole field, with no cloud.
local function stars(pt, rng, f)
  O.starfield(pt, rng, {}, f.x0, f.y0, f.x1, f.y1)
end

Orn.register({
  name = "sun", slot = "cartouche", label = "Sun in splendour",
  draw = function(pt, rng, b)
    -- A pale dawn sky; the sun's flames and rays fill most of it.
    cartouche(pt, rng, b, { pigment = pal.sky, strength = 0.45, light = { (b[1] + b[3]) / 2, b[2] } },
      function(f, w, h, cx, cy)
        local r = math.min(w, h) * 0.2
        pt:fill(K.ring(cx, cy, r * 2.05, 24, r * 0.05), pal.white, 0.7, { many = true })
        for k, rr in ipairs({ 1.9, 1.5, 1.2 }) do
          pt:fill({ K.dot(cx, cy, r * rr)[1] }, pal.cream, 0.18 + 0.08 * k)
        end
      end,
      function(f, w, h, cx, cy)
        local r = math.min(w, h) * 0.2
        local lit, shade = K.rays(cx, cy, r * 1.02, math.min(w, h) * 0.47, 16, { flames = true, rot = rng:range(0, pi / 8) })
        K.gilt(pt, lit, shade)
        pt:fill(K.dot(cx, cy, r), pal.gold, 0.95)
        pt:fill(K.dot(cx - r * 0.18, cy + r * 0.2, r * 0.7), pal.cream, 0.55)
        pt:stroke(K.dot(cx, cy, r), pal.copper, 0.3, 0.9)
        pt:stroke(K.dot(cx, cy, r * 0.82), pal.copper, 0.18, 0.6)
      end)
  end,
})

Orn.register({
  name = "moon", slot = "cartouche", label = "Crescent moon",
  draw = function(pt, rng, b)
    cartouche(pt, rng, b, nil, function(f, w, h, cx, cy)
      stars(pt, rng:fork("stars"), f)
      local r = math.min(w, h) * 0.3
      local x, y = cx + rng:jit(w * 0.06), cy + h * 0.06
      local rot = rng:range(-0.5, 0.2)
      -- Earthshine on the dark disc, then the lit crescent and its shading.
      pt:fill(K.dot(x, y, r), pal.white, 0.08)
      local moon = G.smooth(K.crescent(x, y, r, 0.62, rot), true)
      pt:fill(moon, pal.white, 0.95)
      pt:fill(G.smooth(K.crescent(x, y, r * 0.98, 0.42, rot), true), f.dilute, 0.16)
      local seas = {}
      for _ = 1, 5 do
        local a = rot + pi + rng:jit(1.1)
        local p = G.polar({ x, y }, a, r * rng:range(0.62, 0.86))
        seas[#seas + 1] = K.dot(p[1], p[2], r * rng:range(0.05, 0.11))
      end
      pt:fill(seas, f.dilute, 0.16, { many = true })
      pt:fill(K.dot(x, y, r * 1.35), pal.white, 0.06)
    end, function(f, w, h, cx, cy)
      -- A gilt star below the horns.
      local s = math.min(w, h) * 0.08
      local p = { cx - w * 0.22, f.y0 + h * 0.2 }
      pt:fill(G.polyline(K.star(p[1], p[2], s, s * 0.38, 5), true), pal.gold, 0.9)
    end)
  end,
})

Orn.register({
  name = "constellation", slot = "cartouche", label = "Constellation",
  draw = function(pt, rng, b)
    cartouche(pt, rng, b, { strength = 1.2 }, function(f, w, h, cx, cy)
      stars(pt, rng:fork("stars"), f)
      -- A band of denser dust across the field, as the Milky Way.
      local band = {}
      local br = rng:fork("band")
      local a = br:range(0.5, 1.1)
      for _ = 1, math.floor(w * h * 0.12) do
        local t, u = br:range(-0.7, 0.7), br:jit(1) * br:next()
        local p = G.polar({ cx + t * w * cos(a), cy + t * h * sin(a) }, a + pi / 2, u * w * 0.18)
        band[#band + 1] = K.dot(p[1], p[2], br:range(0.08, 0.22))
      end
      pt:fill(band, pal.white, 0.45, { many = true })
    end, function(f, w, h, cx, cy)
      -- Six to eight stars joined in a chain, with one branch.
      local cr = rng:fork("figure")
      local pts = {}
      local p = { f.x0 + w * cr:range(0.15, 0.3), f.y0 + h * cr:range(0.15, 0.3) }
      for _ = 1, cr:int(6, 8) do
        pts[#pts + 1] = p
        p = { G.clamp(p[1] + cr:range(-0.15, 0.32) * w, f.x0 + w * 0.12, f.x1 - w * 0.12),
          G.clamp(p[2] + cr:range(0.06, 0.2) * h, f.y0 + h * 0.1, f.y1 - h * 0.1) }
      end
      local lines = { G.polyline(pts) }
      local j = cr:int(2, #pts - 1)
      local spur = { pts[j][1] + w * 0.18, pts[j][2] - h * 0.08 }
      lines[#lines + 1] = G.polyline({ pts[j], spur })
      pts[#pts + 1] = spur
      pt:stroke(lines, pal.gold, 0.25, 0.75, { many = true })
      local glints = {}
      for i, q in ipairs(pts) do
        local s = math.min(w, h) * (i % 3 == 1 and 0.06 or 0.04)
        glints[#glints + 1] = G.polyline(K.star(q[1], q[2], s, s * 0.32, 4), true)
      end
      pt:fill(glints, pal.gold, 0.95, { many = true })
    end)
  end,
})

Orn.register({
  name = "planet", slot = "cartouche", label = "Ringed planet",
  draw = function(pt, rng, b)
    cartouche(pt, rng, b, nil, function(f, w, h, cx, cy)
      stars(pt, rng:fork("stars"), f)
      local r = math.min(w, h) * 0.24
      local tilt = rng:range(-0.45, -0.2)
      local ring = function(k) return K.ellipse(cx, cy, r * k, r * k * 0.28, tilt, 48) end
      -- The ring's far half behind the planet, its near half in front.
      local function half(k, front)
        local pts = ring(k)
        local out = {}
        for i = front and 1 or 25, front and 25 or 49 do out[#out + 1] = pts[(i - 1) % 48 + 1] end
        return G.polyline(out)
      end
      pt:stroke({ half(2.0, false), half(1.65, false) }, pal.gold, 0.5, 0.8, { many = true })
      local disc = K.dot(cx, cy, r)
      pt:fill(disc, pal.cream, 1)
      pt:clip_begin(disc)
      -- Cloud bands across the globe, alternating copper and cream.
      for k = -4, 4 do
        local pts = K.ellipse(cx, cy + k * r * 0.24, r * 1.3, r * 0.07, tilt * 0.6, 24)
        pt:fill(G.smooth(pts, true), k % 2 == 0 and pal.copper or pal.gold, 0.22 + 0.04 * (k % 3))
      end
      pt:fill(G.smooth(K.crescent(cx, cy, r * 1.02, 0.7, tilt + pi * 0.8), true), f.deep, 0.45)
      pt:clip_end()
      pt:stroke({ half(2.0, true), half(1.65, true) }, pal.gold, 0.5, 0.9, { many = true })
      local m = G.polar({ cx, cy }, rng:range(0.6, 1.2), r * 2.15)
      pt:fill(K.dot(m[1], m[2], r * 0.12), pal.white, 0.9)
    end)
  end,
})

Orn.register({
  name = "armillary", slot = "cartouche", label = "Armillary sphere",
  draw = function(pt, rng, b)
    cartouche(pt, rng, b, { pigment = pal.sky, strength = 0.55 }, function(f)
      stars(pt, rng:fork("stars"), f)
    end, function(f, w, h, cx, cy)
      K.armillary(pt, cx, cy + h * 0.06, math.min(w, h) * 0.32, rng:range(0.35, 0.5), f.y0 + h * 0.05)
    end)
  end,
})
