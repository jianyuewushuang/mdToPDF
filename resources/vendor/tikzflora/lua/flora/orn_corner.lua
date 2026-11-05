-- Corner pieces after the bookbinder and the flourisher. Each is drawn
-- into the lower-left corner of its box (K.corner mirrors it into the
-- others):
--   cornerpiece  a quarter of a lobed centre medallion, as tooled in gold
--                on 1580-1620 bindings: a gilt lobed field, interlace and
--                leaf tips tooled into it, a dotted (pointillé) border and
--                double fillets running off along the edges
--   pen_corner   two pen rules meeting in a knot, breaking into fleuronnée
--                curls, pearls and dots in two colours
--   fan          a quarter shell: fine rays out of a rosette hub to a
--                scalloped rim, with a dotted arc between

local Orn = require("flora.ornaments")
local K = require("flora.orn_kit")
local G = require("flora.geom")
local Paint = require("flora.paint")
local Pen = require("flora.orn_pen")
local Gild = require("flora.orn_gild")

local pal = Paint.palette
local pi, cos, sin = math.pi, math.cos, math.sin

-- Points along the arc of radius r about c from angle a0 to a1.
local function arc(c, r, a0, a1, n)
  local out = {}
  n = n or 24
  for k = 0, n do out[#out + 1] = G.polar(c, a0 + (a1 - a0) * k / n, r) end
  return out
end

Orn.register({
  name = "cornerpiece", slot = "corner", label = "Binding cornerpiece", reach = 0.03,
  draw = function(pt, rng, b, o)
    K.corner(pt, b, o, function(x0, y0, s)
      local c = { x0 + s * 0.04, y0 + s * 0.04 }
      local R = s * rng:range(0.66, 0.74)
      local lobes = rng:int(2, 3)
      local finial = rng:range(0.1, 0.16)
      -- The field's edge: round lobes between inward cusps, and a pointed
      -- finial on the diagonal.
      local function edge(t, scale)
        local th = t * pi / 2
        local u = (t * (lobes * 2 + 1)) % 1
        local r = R * (0.86 + 0.14 * sin(pi * u) ^ 0.5)
        r = r + R * finial * math.max(0, 1 - math.abs(t - 0.5) * 9) ^ 1.5
        return G.polar(c, th, r * scale)
      end
      -- The field is open work, as gold tooled on leather: a gilt band
      -- round the lobed edge, and within it a quarter interlace of two
      -- arcs, leaf tips on the radii and a fan of small lozenges.
      local band = {}
      for k = 0, 120 do band[#band + 1] = edge(k / 120, 1) end
      for k = 120, 0, -1 do band[#band + 1] = edge(k / 120, 0.86) end
      local pieces = { G.polyline(band, true) }
      for _, a in ipairs({ pi / 8, pi / 4, 3 * pi / 8 }) do
        local tip = G.polar(c, a, R * 0.46)
        pieces[#pieces + 1] = G.smooth(K.lozenge(tip[1], tip[2], R * (a == pi / 4 and 0.32 or 0.24), a), true)
      end
      -- The hub: a quarter disc with a scalloped rim.
      local hub = { c }
      for k = 0, 48 do
        local t = k / 48
        hub[#hub + 1] = G.polar(c, t * pi / 2, R * (0.2 + 0.03 * sin(pi * ((t * 4) % 1)) ^ 0.6))
      end
      pieces[#pieces + 1] = G.polyline(hub, true)
      Gild.fill(pt, pieces, { bevel = s * 0.008, key = 0.18, shadow = s * 0.006 })
      local rings = {}
      for _, r in ipairs({ 0.36, 0.42 }) do rings[#rings + 1] = G.smooth(arc(c, R * r, 0.02, pi / 2 - 0.02)) end
      Gild.line(pt, rings, G.clamp(s * 0.007, 0.18, 0.45))
      -- Pointillé: dots inside the band and just outside the edge.
      local dots = {}
      local m = lobes * 12
      for k = 1, m - 1 do dots[#dots + 1] = edge(k / m, 1.07) end
      Gild.dots(pt, dots, s * 0.009)
      local inner = {}
      for k = 1, m - 1, 2 do inner[#inner + 1] = edge(k / m, 0.78) end
      Gild.dots(pt, inner, s * 0.008)
      -- Double fillets off along each edge, ending in a small leaf.
      local lines = {}
      for _, d in ipairs({ 0.012, 0.035 }) do
        lines[#lines + 1] = G.polyline({ { c[1] + R * 0.95, y0 + s * d }, { x0 + s * 0.98, y0 + s * d } })
        lines[#lines + 1] = G.polyline({ { x0 + s * d, c[2] + R * 0.95 }, { x0 + s * d, y0 + s * 0.98 } })
      end
      Gild.line(pt, lines, G.clamp(s * 0.008, 0.2, 0.5))
      local spokes = {}
      for k = 1, 3 do spokes[#spokes + 1] = G.polyline({ G.polar(c, k * pi / 8, R * 0.05), G.polar(c, k * pi / 8, R * 0.17) }) end
      pt:stroke(spokes, Gild.umber, G.clamp(s * 0.005, 0.12, 0.3), 0.6, { many = true })
    end)
  end,
})

Orn.register({
  name = "pen_corner", slot = "corner", label = "Penwork corner", reach = 0.05,
  draw = function(pt, rng, b, o)
    K.corner(pt, b, o, function(x0, y0, s)
      local line, accent = pal.ink, pal.copper
      if rng:chance(0.35) then line, accent = pal.copper, pal.ink end
      local hw = G.clamp(s * 0.004, 0.15, 0.28)
      local hairs, beads, rings = {}, {}, {}
      local function hair(pts, f) hairs[#hairs + 1] = G.polyline(Pen.hairline(pts, hw, f), true) end
      local k0 = s * 0.1
      -- A thick and a thin rule along each edge, from the knot out.
      local rules = {}
      for _, e in ipairs({ { 1, 0 }, { 0, 1 } }) do
        local function at(t, off) return { x0 + e[1] * t + e[2] * off, y0 + e[2] * t + e[1] * off } end
        rules[#rules + 1] = Pen.hairline({ at(k0 * 1.3, k0 * 0.5), at(s * 0.92, k0 * 0.5) }, hw * 2.6, 0.2)
        hair({ at(k0 * 1.3, k0 * 0.8), at(s * 0.8, k0 * 0.8) }, 0.4)
        -- Sprigs off the rule's inner side, turning in toward the page.
        local n = rng:int(2, 3)
        for k = 1, n do
          local t = k0 * 1.5 + (s * 0.7 - k0 * 1.5) * (k - 0.5) / n
          local p = at(t, k0 * 0.8)
          local away = math.atan(e[1], e[2])
          local dir = e[1] == 1 and 1 or -1
          local sp = Pen.sprig(p, away + dir * 0.6, s * rng:range(0.28, 0.34), -dir, rng:range(0.9, 1.2))
          hair(sp, 0.5)
          local e2 = Pen.echo(sp, -dir * s * 0.025)
          local part = {}
          for i = 2, math.floor(#e2 * 0.5) do part[#part + 1] = e2[i] end
          if #part > 2 then hair(part, 0.2) end
          local q = sp[#sp]
          rings[#rings + 1] = { q[1], q[2], s * 0.018 }
          local m = at(t + s * 0.08, k0 * 0.8 + s * 0.06)
          beads[#beads + 1] = { m[1], m[2], s * 0.012 }
        end
        -- The rule's end breaks into a curl.
        local tipdir = e[1] == 1 and 0 or pi / 2
        local curl = Pen.sprig(at(s * 0.8, k0 * 0.8), tipdir, s * 0.2, e[1] == 1 and 1 or -1, 1.1)
        hair(curl, 0.5)
      end
      -- The knot: a lozenge on the corner, ringed by echo lines, with a
      -- diagonal sprig into the page and three dots beyond it.
      local core = K.lozenge(x0 + k0 * 0.2, y0 + k0 * 0.2, k0 * 1.1, pi / 4)
      local mid = G.centroid(core)
      for _, sc in ipairs({ 1.45, 1.9 }) do
        local e = G.toward(core, mid[1], mid[2], sc)
        e[#e + 1] = e[1]
        hair(e, 1)
      end
      for _, d in ipairs({ -1, 1 }) do
        local sp = Pen.sprig(G.polar(mid, pi / 4, k0 * 1.3), pi / 4 + d * 0.35, s * 0.3, -d, rng:range(1.0, 1.3))
        hair(sp, 0.5)
        local q = sp[#sp]
        rings[#rings + 1] = { q[1], q[2], s * 0.02 }
      end
      local far = G.polar(mid, pi / 4, s * 0.48)
      for j = -1, 1 do
        local q = G.polar(far, pi / 4 + pi / 2, j * s * 0.03)
        beads[#beads + 1] = { q[1] + (j == 0 and s * 0.02 or 0), q[2] + (j == 0 and s * 0.02 or 0), s * 0.013 }
      end
      pt:fill(G.polyline(rules[1], true), line, 0.9, { blend = "multiply" })
      pt:fill(G.polyline(rules[2], true), line, 0.9, { blend = "multiply" })
      pt:fill(hairs, line, 0.92, { many = true, blend = "multiply" })
      local circles, dots = {}, {}
      for _, r in ipairs(rings) do
        circles[#circles + 1] = G.polyline(Pen.hairline(K.ellipse(r[1], r[2], r[3], r[3], 0, 16), hw), true)
        dots[#dots + 1] = K.dot(r[1], r[2], r[3] * 0.45)
      end
      for _, q in ipairs(beads) do dots[#dots + 1] = K.dot(q[1], q[2], q[3]) end
      pt:fill(circles, line, 0.92, { many = true, blend = "multiply" })
      pt:fill(dots, accent, 0.92, { many = true, blend = "multiply" })
      pt:fill(G.smooth(core, true), accent, 0.9, { blend = "multiply" })
    end)
  end,
})

Orn.register({
  name = "fan", slot = "corner", label = "Quarter fan", reach = 0.03,
  draw = function(pt, rng, b, o)
    K.corner(pt, b, o, function(x0, y0, s)
      local c = { x0 + s * 0.04, y0 + s * 0.04 }
      local n = rng:int(5, 7) * 2
      local rim = s * 0.8
      local inner = rim * rng:range(0.8, 0.84)
      local step = pi / 2 / n
      -- The rim: a scallop between each pair of long rays, bulging out
      -- from the inner arc, as one gilt band.
      local band = {}
      for k = 0, n - 1 do
        local a0, a1 = k * step, (k + 1) * step
        for j = 0, 10 do
          local t = j / 10
          local a = a0 + (a1 - a0) * t
          band[#band + 1] = G.polar(c, a, rim * (0.95 + 0.06 * sin(pi * t) ^ 0.7))
        end
      end
      for k = 40, 0, -1 do band[#band + 1] = G.polar(c, k / 40 * pi / 2, inner * 1.04) end
      Gild.fill(pt, { G.polyline(band, true) }, { bevel = s * 0.01, key = 0.18, shadow = s * 0.006 })
      -- Rays from the hub to the rim's inner edge, long and short in turn,
      -- each a slim gilt spindle; the short ones stop at a dotted arc.
      local rays = {}
      local dot_r = inner * 0.78
      for k = 0, n * 2 do
        local a = k * step / 2
        local long = k % 2 == 0
        local r1 = long and inner * 1.02 or dot_r * 0.94
        local half = (long and 0.5 or 0.36) * step * s * 0.18
        local base = G.polar(c, a, s * 0.16)
        local tip = G.polar(c, a, r1)
        local mid = G.polar(c, a, s * 0.16 + (r1 - s * 0.16) * 0.35)
        rays[#rays + 1] = G.smooth({ base, G.polar(mid, a + pi / 2, half), tip, G.polar(mid, a - pi / 2, half) }, true, 0.8)
      end
      Gild.fill(pt, rays, { bevel = s * 0.004, key = 0.1, shadow = 0 })
      local dots = {}
      for k = 0, n - 1 do dots[#dots + 1] = G.polar(c, (k + 0.5) * step, dot_r) end
      Gild.dots(pt, dots, s * 0.014)
      -- A fine arc inside the rim and the hub: a half rosette.
      Gild.line(pt, { G.smooth(arc(c, inner * 0.97, 0, pi / 2, 30)) }, G.clamp(s * 0.004, 0.15, 0.3))
      local hub = arc(c, s * 0.17, 0, pi / 2, 20)
      table.insert(hub, 1, c)
      Gild.fill(pt, { G.polyline(hub, true) }, { bevel = s * 0.01, key = 0.15, shadow = 0 })
      pt:stroke(G.smooth(arc(c, s * 0.11, 0.05, pi / 2 - 0.05, 12)), Gild.umber, 0.25, 0.6)
      pt:fill(K.dot(c[1], c[2], s * 0.05), pal.copper, 0.95)
    end)
  end,
})
