-- Pieces for a title page, after the printed book's ornaments: flourishes
-- to set under a title (a fleuron rule, a headpiece band of printers'
-- flowers; pen and rule flourishes are in orn_flourish.lua), tailpieces to
-- close it (a cul-de-lampe, a hedera leaf, a garland) and corner pieces
-- (more are in orn_corner.lua).

local Orn = require("flora.ornaments")
local K = require("flora.orn_kit")
local G = require("flora.geom")
local Paint = require("flora.paint")
local Scroll = require("flora.orn_scroll")

local pal = Paint.palette
local pi = math.pi

-- Flourishes ---------------------------------------------------------------

Orn.register({
  name = "fleuron_rule", slot = "flourish", label = "Fleuron rule",
  draw = function(pt, _, b)
    local cx, cy, w, h = K.measure(b)
    -- Two hedera leaves back to back, and rules tapering away from them.
    local s = h * 0.38
    local leaves = { G.smooth(K.lozenge(cx - s * 0.62, cy, s, pi), true), G.smooth(K.lozenge(cx + s * 0.62, cy, s, 0), true) }
    local rules = {}
    for _, d in ipairs({ -1, 1 }) do
      rules[#rules + 1] = K.taper({ { cx + d * s * 1.45, cy }, { cx + d * w * 0.47, cy } }, h * 0.05, 0.1)
    end
    pt:fill(rules, pal.gold, 0.9, { many = true })
    pt:fill(leaves, pal.copper, 0.6, { many = true })
    pt:fill(G.smooth(K.lozenge(cx - s * 0.6, cy + s * 0.04, s * 0.92, pi), true), pal.gold, 0.95)
    pt:fill(G.smooth(K.lozenge(cx + s * 0.6, cy + s * 0.04, s * 0.92, 0), true), pal.gold, 0.95)
    pt:fill(K.dot(cx, cy, s * 0.14), pal.copper, 0.95)
    local dots = {}
    for _, d in ipairs({ -1, 1 }) do
      for k = 0, 2 do dots[#dots + 1] = K.dot(cx + d * (w * 0.485 - k * h * 0.12), cy, h * (0.045 - k * 0.01)) end
    end
    pt:fill(dots, pal.gold, 0.9, { many = true })
  end,
})

Orn.register({
  name = "headpiece", slot = "flourish", label = "Headpiece band",
  draw = function(pt, rng, b)
    local cx, cy, w, h = K.measure(b)
    local bh = h * 0.5
    local x0, x1 = b[1] + h * 0.35, b[3] - h * 0.35
    -- Printers' flowers along a band between two rules: hedera leaves
    -- turning up and down in turn.
    local n = math.max(5, math.floor((x1 - x0) / (bh * 0.9)))
    local up, down = {}, {}
    for k = 0, n - 1 do
      local x = x0 + (k + 0.5) * (x1 - x0) / n
      local into = k % 2 == 0 and up or down
      into[#into + 1] = G.smooth(K.lozenge(x, cy - (k % 2 == 0 and 0.32 or -0.32) * bh, bh * 0.58, k % 2 == 0 and pi / 2 or -pi / 2), true)
    end
    pt:fill(up, pal.gold, 0.92, { many = true })
    pt:fill(down, pal.copper, 0.8, { many = true })
    local rules = {}
    for _, y in ipairs({ cy + bh * 0.62, cy - bh * 0.62 }) do rules[#rules + 1] = G.polyline({ { x0, y }, { x1, y } }) end
    pt:stroke(rules, pal.gold, 0.45, 0.95, { many = true })
    local roundel = require("flora.orn_roundel")
    for _, x in ipairs({ b[1] + h * 0.3, b[3] - h * 0.3 }) do roundel.rosette(pt, x, cy, h * 0.3, 8, rng:range(0, pi / 8)) end
  end,
})

-- Tailpieces ---------------------------------------------------------------

Orn.register({
  name = "cul_de_lampe", slot = "tailpiece", label = "Cul-de-lampe",
  draw = function(pt, rng, b)
    local cx, _, w, h = K.measure(b)
    -- Rows of fleurons narrowing to a point, then a hanging drop.
    local rows = { 7, 5, 3, 1 }
    local rh = h * 0.18
    local s = math.min(w / 8, rh) * 0.95
    local gold, copper = {}, {}
    for i, n in ipairs(rows) do
      local y = b[4] - rh * (i - 0.5)
      for k = 0, n - 1 do
        local x = cx + (k - (n - 1) / 2) * s * 1.05
        if (k + i) % 2 == 0 then
          for _, p in ipairs(K.trefoil(x, y, s * 0.82, -pi / 2)) do gold[#gold + 1] = p end
        else
          copper[#copper + 1] = G.smooth(K.leaf(x, y, s * 0.6, -pi / 2), true)
        end
      end
    end
    pt:fill(gold, pal.gold, 0.92, { many = true })
    pt:fill(copper, pal.copper, 0.85, { many = true })
    local tip = b[4] - rh * #rows
    pt:fill(G.smooth(K.leaf(cx, tip - h * 0.08, h * 0.12, -pi / 2), true), pal.gold, 0.95)
    pt:fill({ K.dot(cx, b[2] + h * 0.04, h * 0.025)[1] }, pal.gold, 0.9)
    pt:stroke(G.polyline({ { cx, tip - h * 0.2 }, { cx, b[2] + h * 0.07 } }), pal.gold, 0.3, 0.8)
    if rng:chance(0.5) then
      pt:stroke(G.polyline({ { cx - s * 4, b[4] + h * 0.01 }, { cx + s * 4, b[4] + h * 0.01 } }), pal.gold, 0.35, 0.85)
    end
  end,
})

Orn.register({
  name = "hedera", slot = "tailpiece", label = "Hedera leaf",
  draw = function(pt, rng, b)
    local cx, cy, w, h = K.measure(b)
    local s = math.min(w * 0.3, h * 0.5)
    cy = cy + s * 0.4
    local leaf = K.leaf(cx, cy - s * 0.2, s, -pi / 2)
    local shadow = {}
    for i, q in ipairs(leaf) do shadow[i] = { q[1] + s * 0.03, q[2] - s * 0.03 } end
    pt:fill(G.smooth(shadow, true), pal.copper, 0.7)
    pt:fill(G.smooth(leaf, true), pal.gold, 0.95)
    -- The stalk curls up and over from the leaf's notch.
    local d = rng:chance(0.5) and 1 or -1
    Scroll.scroll(pt, { cx, cy - s * 0.2 + s * 0.15 }, pi / 2 + d * 0.3, s * 1.1, -d, s * 0.08)
    pt:stroke(G.polyline({ { cx, cy - s * 0.1 }, { cx, cy - s * 0.85 } }), pal.copper, 0.35, 0.8)
    pt:fill({ K.dot(cx - s * 1.1, cy - s * 0.4, s * 0.06), K.dot(cx + s * 1.1, cy - s * 0.4, s * 0.06) }, pal.gold, 0.9, { many = true })
  end,
})

Orn.register({
  name = "garland", slot = "tailpiece", label = "Garland",
  draw = function(pt, rng, b)
    local cx, cy, w, h = K.measure(b)
    local x0, x1 = b[1] + w * 0.12, b[3] - w * 0.12
    local top, sag = cy + h * 0.25, h * 0.45
    -- A swag hanging between two rosettes: a cord with paired leaves
    -- along it, alternately gold and copper, largest at the low point.
    local cord, gold, copper = {}, {}, {}
    for k = 0, 24 do
      local t = k / 24
      cord[#cord + 1] = { x0 + (x1 - x0) * t, top - sag * math.sin(pi * t) }
    end
    pt:stroke(G.smooth(cord), pal.copper, 0.4, 0.8)
    for k = 1, 9 do
      local t = k / 10
      local x, y = x0 + (x1 - x0) * t, top - sag * math.sin(pi * t)
      local along = math.atan(-sag * pi * math.cos(pi * t), x1 - x0)
      local size = h * 0.17 * (0.65 + 0.45 * math.sin(pi * t))
      for _, sd in ipairs({ -1, 1 }) do
        local leaf = G.smooth(K.leaf(x, y, size, along + sd * 1.05, 0.55), true)
        local into = (k + (sd > 0 and 1 or 0)) % 2 == 0 and gold or copper
        into[#into + 1] = leaf
      end
    end
    pt:fill(copper, pal.copper, 0.8, { many = true })
    pt:fill(gold, pal.gold, 0.92, { many = true })
    local roundel = require("flora.orn_roundel")
    for _, x in ipairs({ x0, x1 }) do
      roundel.rosette(pt, x, top, h * 0.13, 8, rng:range(0, pi / 8))
      pt:fill(G.smooth(K.leaf(x, top - h * 0.3, h * 0.12, -pi / 2), true), pal.copper, 0.85)
    end
  end,
})

-- Corners ------------------------------------------------------------------

local corner = K.corner

Orn.register({
  name = "bracket", slot = "corner", label = "Scrolled bracket",
  draw = function(pt, _, b, o)
    corner(pt, b, o, function(x0, y0, s)
      local w = s * 0.05
      pt:fill({ K.taper({ { x0 + s * 0.08, y0 + s * 0.08 }, { x0 + s * 0.85, y0 + s * 0.08 } }, w, 0.2),
        K.taper({ { x0 + s * 0.08, y0 + s * 0.08 }, { x0 + s * 0.08, y0 + s * 0.85 } }, w, 0.2) }, pal.gold, 0.92, { many = true })
      Scroll.scroll(pt, { x0 + s * 0.6, y0 + s * 0.08 }, pi / 2, s * 0.32, 1, w * 0.8)
      Scroll.scroll(pt, { x0 + s * 0.08, y0 + s * 0.6 }, 0, s * 0.32, -1, w * 0.8)
      require("flora.orn_roundel").rosette(pt, x0 + s * 0.08, y0 + s * 0.08, s * 0.08, 8)
      pt:fill({ K.dot(x0 + s * 0.93, y0 + s * 0.08, s * 0.025), K.dot(x0 + s * 0.08, y0 + s * 0.93, s * 0.025) }, pal.gold, 0.9, { many = true })
    end)
  end,
})

Orn.register({
  name = "corner_leaf", slot = "corner", label = "Corner fleuron",
  draw = function(pt, _, b, o)
    corner(pt, b, o, function(x0, y0, s)
      local c = { x0 + s * 0.42, y0 + s * 0.42 }
      local leaf = K.leaf(c[1], c[2], s * 0.36, -3 * pi / 4)
      pt:fill(G.smooth(leaf, true), pal.gold, 0.95)
      Scroll.scroll(pt, G.polar(c, pi / 4, s * 0.08), pi / 4 + 0.9, s * 0.42, 1, s * 0.04)
      Scroll.scroll(pt, G.polar(c, pi / 4, s * 0.08), pi / 4 - 0.9, s * 0.42, -1, s * 0.04)
      pt:fill(K.dot(x0 + s * 0.06, y0 + s * 0.06, s * 0.035), pal.gold, 0.9)
    end)
  end,
})
