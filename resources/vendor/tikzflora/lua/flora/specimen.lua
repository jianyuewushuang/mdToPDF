-- A sheet showing each element once, for judging them against the reference.

local G = require("flora.geom")
local Rng = require("flora.rng")
local Paint = require("flora.paint")
local F = require("flora.flower")
local L = require("flora.leaf")
local S = require("flora.sprig")
local O = require("flora.ornament")
local V = require("flora.visitor")

local M = {}
M.width, M.height = 620, 520

function M.draw(seed)
  local rng = Rng.new(seed or 1)
  local pt = Paint.new({ backend = os.getenv("FLORA_BACKEND") })
  local pi = math.pi

  -- Stems first so blooms sit on top.
  local b = S.batch()
  b:stem(G.curve({ 110, 150 }, pi / 2 + 0.25, 150, -0.3, 0, 20), 1.6, 0.7)
  b:stem(G.curve({ 260, 180 }, pi / 2, 120, -0.4, 0, 20), 1.0, 0.5)
  S.umbel(b, rng:fork("umbel"), { 455, 225 }, pi / 2, 52)
  b:line(G.curve({ 455, 120 }, pi / 2, 105, 0.05, 0, 8), 1)
  S.cyme(b, rng:fork("cyme"), { 520, 40 }, pi / 2 + 0.15, 120, -1)
  S.gypsophila(b, rng:fork("gyps"), { 585, 30 }, pi / 2 + 0.1, 26, 6)
  b:line(S.tendril({ 20, 250 }, pi / 2, 70, -1), 1)
  b:paint(pt)

  local hc = require("flora.tune").hero
  F.bloom(pt, rng:fork("hero"), 110, 315, 68, { style = hc.style, look = "hero", petals = hc.petals, width = hc.petal_width })
  F.tilted(pt, rng:fork("lily"), 265, 330, 50, pi / 2 - 0.5, 1.05, { kind = "lance", look = "vivid", petals = 6, width = 0.36 })
  F.bloom(pt, rng:fork("soft"), 365, 345, 28, { style = "soft" })
  F.bloom(pt, rng:fork("ghost"), 375, 250, 46, { kind = "ghost", look = "ghost", width = 0.65 })

  L.leaf(pt, rng:fork("acanthus"), 30, 20, pi / 2 - 0.35, {
    len = 130, width = 21, bend = 0.9, hook = 1.6, margin = "acanthus", teeth = 3, depth = 0.4,
    sides = "right", look = "vivid", veins = 7,
  })
  L.leaf(pt, rng:fork("serrate"), 150, 15, pi / 2 + 0.3, {
    len = 100, width = 16, bend = -0.7, hook = -1.4, margin = "serrate", teeth = 11, depth = 0.3,
    sides = "both", look = "deep", veins = 6,
  })
  L.leaf(pt, rng:fork("lance"), 215, 20, pi / 2 - 0.2, {
    len = 110, width = 12, bend = 0.6, hook = 0.9, margin = "entire", shape = "lance",
    look = "vivid", veins = 5,
  })
  L.leaf(pt, rng:fork("oak"), 290, 20, pi / 2, {
    len = 85, width = 24, bend = -0.25, hook = 0, margin = "acanthus", teeth = 3, depth = 0.25,
    look = "vivid", veins = 6, lightning = true,
  })
  L.leaflets(pt, rng:fork("leaflets"),
    S.leaflet_items(rng:fork("li"), G.curve({ 455, 120 }, pi / 2, 105, 0.05, 0, 8), 14, 9))

  O.compass(pt, 590, 400, 24)
  O.panel(pt, rng:fork("panel"), 395, 30, 34, 50)
  O.chain(pt, rng:fork("chain"), 600, 300, 210)
  O.sparkles(pt, { { 520, 400, 4 }, { 540, 300, 3 }, { 330, 410, 3.5 }, { 20, 410, 2.5 } })

  -- The visitors along the top: a bee on its trail, a butterfly, a bird on
  -- a twig and a snail on a stem.
  local trail = V.trail(rng:fork("trail"), 70, 475, -0.2, 18, function() return true end)
  V.paint_trail(pt, trail)
  V.bee(pt, rng:fork("bee"), 70, 475, -0.2, 18)
  V.butterfly(pt, rng:fork("butterfly"), 190, 478, math.pi / 2 + 0.25, 40, 0.9)
  local twig = S.batch()
  twig:stem(G.link({ 270, 445 }, 0.2, { 340, 452 }, 0.1, 0.5), 1.2, 0.5)
  twig:stem(G.curve({ 420, 446 }, 0.05, 110, 0.1, 0, 12), 1.4, 1.0)
  twig:paint(pt)
  V.bird(pt, rng:fork("bird"), 322, 451, 1, 46)
  V.snail(pt, rng:fork("snail"), 460, 449, 0.08, 1, 28)

  return pt
end

return M
