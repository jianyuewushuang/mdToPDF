-- The border's parts as components, for the tuner and the glossary. Each
-- component names the tune.lua settings it owns (`paths`: whole folders or
-- single settings) and draws a specimen of itself on a small canvas of
-- w x h pt, so a change to its settings can be judged on the part alone
-- before it rolls up into the page. Specimens of parts that vary show
-- several at once. A component without `draw` (the page layout) is judged
-- on the page.

local G = require("flora.geom")
local Tune = require("flora.tune")
local Dist = require("flora.dist")
local F = require("flora.flower")
local L = require("flora.leaf")
local S = require("flora.sprig")
local O = require("flora.ornament")
local Gallery = require("flora.gallery")
local Plant = require("flora.plant")
local Brush = require("flora.brush")

local M = {}
local pi = math.pi

-- Three blooms of one style side by side, so its spread shows.
local function bloom_row(style)
  return function(pt, rng)
    for k = 1, 3 do
      F.bloom(pt, rng:fork("bloom" .. k), 62 + (k - 1) * 118, 62, 44, { style = style })
    end
  end
end

M.list = {
  {
    id = "hero", label = "Hero bloom",
    desc = "The large flower that crowns the main stem.",
    paths = { "hero", "compose.hero", "color.looks.hero", "color.palette.hero", "blooms.wedge" }, w = 200, h = 190,
    draw = function(pt, rng)
      local R = G.clamp(165 * Tune.compose.hero, 28, 80)
      F.hero(pt, rng:fork("hero"), { 100, 95, R })
    end,
  },
  {
    id = "fan", label = "Fan blooms",
    desc = "The reference's flower: broad, round-ended petals, solid blue nearly to the eye, white rays.",
    paths = { "blooms.fan", "color.looks.fan", "color.palette.blooms" }, w = 360, h = 124, draw = bloom_row("fan"),
  },
  {
    id = "round", label = "Round blooms",
    desc = "Rounded vivid blooms that pale toward the eye.",
    paths = { "blooms.round", "color.looks.vivid", "color.palette.blooms" }, w = 360, h = 124, draw = bloom_row("round"),
  },
  {
    id = "soft", label = "Soft blooms",
    desc = "Pale, wide, rounded blooms.",
    paths = { "blooms.soft", "color.looks.soft", "color.palette.blooms" }, w = 360, h = 124, draw = bloom_row("soft"),
  },
  {
    id = "obovate", label = "Obovate blooms",
    desc = "Narrower petals widest past the middle (the earlier hero).",
    paths = { "blooms.obovate", "color.looks.vivid" }, w = 360, h = 124, draw = bloom_row("obovate"),
  },
  {
    id = "wedge", label = "Wedge blooms",
    desc = "The hero's petals: narrow at the eye, opening into broad rounded fans, each separate from the next.",
    paths = { "blooms.wedge", "color.looks.vivid", "color.palette.blooms" }, w = 360, h = 124, draw = bloom_row("wedge"),
  },
  {
    id = "lily", label = "Lily and ghost bloom",
    desc = "The tilted lily and the faint ghost flower behind the stems.",
    paths = { "compose.features", "color.looks.vivid", "color.looks.ghost" }, w = 260, h = 140,
    draw = function(pt, rng)
      F.tilted(pt, rng:fork("lily"), 70, 70, 46, pi / 2 - 0.5, 1.05,
        { kind = "lance", look = "vivid", petals = 6, width = 0.36 })
      F.bloom(pt, rng:fork("ghost"), 190, 70, 46, { kind = "ghost", look = "ghost", width = 0.65 })
    end,
  },
  {
    id = "leaf", label = "Leaves",
    desc = "Large leaves: acanthus, serrated and lance blades, with veins. Their lengths follow the Leaves size curve.",
    paths = { "compose.leaves", "compose.leaf_size", "compose.leaf_width", "compose.leaf_overlap", "compose.leaf_spacing", "sizes.leaf",
      "color.looks.leaf", "color.palette.leaves", "color.grey_chance", "color.grey_share" }, w = 360, h = 150,
    draw = function(pt, rng)
      for k = 1, 4 do
        local r = rng:fork("leaf" .. k)
        local len = 90 * Tune.compose.leaf_size * Dist.sample(r, Tune.sizes.leaf)
        local ang = pi / 2 + (k % 2 == 0 and 0.25 or -0.25)
        L.leaf(pt, r, 45 + (k - 1) * 90, 8, ang, L.options(r, math.min(len, 140), ang))
      end
    end,
  },
  {
    id = "leaflet", label = "Leaflets",
    desc = "Small paired leaves along the stems. Their lengths follow the Leaflets size curve.",
    paths = { "compose.leaflet_size", "compose.leaflet_spacing", "sizes.leaflet", "color.palette.leaflets" }, w = 360, h = 100,
    draw = function(pt, rng)
      local b = S.batch()
      local line = G.curve({ 10, 50 }, 0.05, 340, 0.15, 0, 40)
      b:stem(line, 1.2, 0.6)
      b:paint(pt)
      L.leaflets(pt, rng:fork("leaflets"),
        S.leaflet_items(rng:fork("items"), line, Tune.compose.leaflet_spacing, Tune.compose.leaflet_size))
    end,
  },
  {
    id = "sprays", label = "Sprays",
    desc = "Fine pen work: baby's breath in the sizes its curve gives, a forget-me-not cyme and an umbel.",
    paths = { "compose.sprays", "compose.small_blooms", "compose.hole_min", "sizes.gyps" }, w = 360, h = 130,
    draw = function(pt, rng)
      local b = S.batch()
      for k = 1, 4 do
        local r = rng:fork("gyps" .. k)
        local gap = 26 * Dist.sample(r, Tune.sizes.gyps)
        S.gypsophila(b, r, { 22 + (k - 1) * 58, 8 }, pi / 2 + r:jit(0.15), gap * 0.5 * 2.2,
          gap >= 14 and 5 or (gap >= 8 and 4 or 3))
      end
      S.cyme(b, rng:fork("cyme"), { 255, 10 }, pi / 2 + 0.2, 80, -1)
      S.umbel(b, rng:fork("umbel"), { 325, 70 }, pi / 2, 34)
      b:line(G.curve({ 325, 6 }, pi / 2, 64, 0.05, 0, 8), 1)
      b:paint(pt)
    end,
  },
  {
    id = "stem", label = "Stems",
    desc = "The plant's own stems, painted as brushed washes, thinning where a shoot leaves.",
    paths = { "plant.stem_l", "plant.stem_brush", "plant.root_width", "plant.tip_width", "plant.fork_ratio", "color.palette.stems" },
    w = 360, h = 110,
    draw = function(pt, rng)
      local cfg = Tune.plant
      local main = Plant.stem(G.curve({ 10, 30 }, 0.12, 340, 0.25, 0, 80), cfg.root_width, cfg.root_width * 0.8)
      main.min = cfg.tip_width
      local p0, a0 = Plant.at(main, main.len * 0.35)
      local shoot = Plant.stem(G.curve(p0, a0 + 0.35, 170, -0.5, 0, 50), 1, 0.35)
      local w = Plant.fork(main, 0.35, cfg.root_width * cfg.fork_ratio, 0.75)
      shoot.w0 = w * cfg.fork_ratio
      local sr = rng:fork("stems")
      Brush.stem(pt, sr, main.pts, Plant.width_fn(main), cfg)
      Brush.stem(pt, sr, shoot.pts, Plant.width_fn(shoot), cfg)
    end,
  },
  {
    id = "painting", label = "Painting",
    desc = "The watercolour treatment every petal and leaf gets: glazes, brush marks, rays, granulation and lost edges.",
    paths = { "wash" }, w = 300, h = 150,
    draw = function(pt, rng)
      F.bloom(pt, rng:fork("bloom"), 75, 75, 62, { style = "fan" })
      local r = rng:fork("leaf")
      L.leaf(pt, r, 175, 10, pi / 2 - 0.3, L.options(r, 120, pi / 2 - 0.3))
    end,
  },
  {
    id = "colour", label = "Colour",
    desc = "The shared blue: hue, how far each shape strays from it, and the pale end's shift.",
    paths = { "color.hue", "color.hue_jitter", "color.hue_drift", "color.palette" }, w = 360, h = 110,
    draw = function(pt, rng)
      F.bloom(pt, rng:fork("fan"), 50, 55, 42, { style = "fan" })
      F.bloom(pt, rng:fork("round"), 140, 55, 36, { style = "round" })
      F.bloom(pt, rng:fork("soft"), 220, 55, 34, { style = "soft" })
      local r = rng:fork("leaf")
      L.leaf(pt, r, 300, 6, pi / 2, L.options(r, 95, pi / 2))
    end,
  },
  {
    id = "gilt", label = "Cartouche and gilt",
    desc = "The star cartouche, compass star, edge chain, corner pendant, medallion and sparkles. Placed by the layout; not tuned yet.",
    paths = {}, w = 240, h = 110,
    draw = function(pt, rng)
      O.panel(pt, rng:fork("panel"), 10, 14, 40, 54)
      O.compass(pt, 110, 55, 24)
      O.chain(pt, rng:fork("chain"), 190, 104, 6)
      O.medallion(pt, 225, 20, 9)
      O.pendant(pt, rng:fork("pendant"), 70, 24, 22, 32, 14)
      O.sparkles(pt, { { 150, 20, 4, "plain" }, { 222, 62, 3.5, "dotted" }, { 70, 95, 3.5, "lozenge" } })
    end,
  },
  {
    id = "gilt_look", label = "Gilt look",
    desc = "Raster gilt in each look: a compass rose, a wreath and a fan, in the studio look above and the mirror look below. The page's gilt takes the look gilt_env names.",
    paths = { "gilt_env", "gilt_looks" }, w = 320, h = 236,
    draw = function(pt, rng)
      local Orn = require("flora.ornaments")
      -- Gold at the specimen's own resolution, twice the tuner's 110 dpi.
      pt.gilt_dpi = 220
      for row, look in ipairs({ "studio", "mirror" }) do
        pt.gilt_env = look
        local y = 236 - row * 118
        Orn.draw("compass_rose", pt, rng:fork("compass"), { 0, y + 4, 110, y + 114 })
        Orn.draw("wreath", pt, rng:fork("wreath"), { 110, y + 4, 220, y + 114 })
        Orn.draw("fan", pt, rng:fork("fan"), { 236, y + 22, 308, y + 94 })
      end
    end,
  },
  {
    id = "ornaments", label = "Ornaments",
    desc = "Every ornament kind (ornaments.lua), two seeds each. The weights pick one kind per place on the page; the page shows them in place.",
    paths = { "ornaments" }, w = select(2, Gallery.layout(2, 560)), h = select(3, Gallery.layout(2, 560)),
    draw = function(pt, rng)
      Gallery.sheet(pt, 2, 560, rng:int(0, 9999))
    end,
  },
  {
    id = "layout", label = "Page layout",
    desc = "Where everything grows: the line of action, the plant's stems and shoots, and how much of each part the page gets.",
    paths = { "gesture", "plant", "compose" },
  },
}

-- The component with id `id`, or nil.
function M.get(id)
  for _, c in ipairs(M.list) do
    if c.id == id then return c end
  end
end

return M
