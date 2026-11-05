-- Composes one page of flora, in the order the plant grows: the stems
-- (layout.lua, plant.lua), then leaves at their nodes, blooms and sprays
-- on branches grown to the largest holes, and small details (grow.lua),
-- then ornaments. Painting runs back to front in fixed layers.

local G = require("flora.geom")
local Rng = require("flora.rng")
local Paint = require("flora.paint")
local Layout = require("flora.layout")
local Fill = require("flora.fill")
local Grow = require("flora.grow")
local F = require("flora.flower")
local L = require("flora.leaf")
local S = require("flora.sprig")
local O = require("flora.ornament")
local Orn = require("flora.ornaments")
local Title = require("flora.orn_title")
local Tune = require("flora.tune")
local Plant = require("flora.plant")
local Brush = require("flora.brush")
local Frames = require("flora.frames")
local Mix = require("flora.mix")
local Visitor = require("flora.visitor")
local Clock = require("flora.clock")
local pal = Paint.palette

local C = {}
local pi = math.pi
local HERO_TOP = 8

-- Plan and paint one plant in its frame's left margin (frames.lua), onto
-- `pt` when given, else onto a new painter.
local function plant(spec, pt)
  local rng = Rng.new(spec.seed or 1)
  local W = spec.width
  local edge = spec.edge or 16
  local g, m = Layout.region(spec)
  local mw = m.x1 - m.x0
  local top = spec.header_y or spec.text.y1

  local cfg = Mix.cfg(Tune.compose, spec.mix)
  local R = G.clamp(mw * cfg.hero, 28, 80)
  -- As in the reference, the hero's heart sits just below the running-head
  -- rule, so the bloom fills the top corner of the page up to the paper's
  -- edge (its projected top kept HERO_TOP pt inside it).
  local _, rh = F.tilt(0, 0, R, Tune.hero.tilt)
  local hy = math.min(top - R * 0.32, spec.height - HERO_TOP - rh)
  local hero = { G.clamp(m.x0 + mw * 0.5, m.x0 + R * 0.75, m.x1 - R * 0.95), hy, R }
  -- The clearance field sees the text and the region's edges from here on.
  g:field()
  -- The hero leans back, so its petals cover a flattened oval; it is
  -- recorded as three discs across that oval, counted at 0.85 of their
  -- radius so foliage may tuck under the rim of its petals.
  do
    local _, rh = F.tilt(hero[1], hero[2], R, Tune.hero.tilt)
    g:disc(hero[1], hero[2], rh, 0.85)
    for _, sx in ipairs({ -1, 1 }) do g:disc(hero[1] + sx * R * 0.45, hero[2], R * 0.55, 0.85) end
  end

  local gest = Layout.gesture(rng:fork("gesture"), m, hero)
  local dens = Mix.density(gest.density, spec.mix)
  -- The cartouche's place, at the reference's size, is kept clear before
  -- the plant grows, so the stems bend around it as the reference's do.
  local ylo, span = m.y0, hero[2] - m.y0
  local py = gest.quiet[1] or ylo + span * 0.5
  local pw, ph = Layout.cartouche_size(mw)
  local strands, root = Layout.strands(rng:fork("strands"), m, hero, W, gest,
    { m.x0, py - ph / 2 - 3, m.x0 + pw + 5, py + ph / 2 + 3 })
  local excursion = not spec.frame_only and Layout.excursion(rng:fork("excursion"), spec, root)
  if excursion then strands[#strands + 1] = excursion end
  local runners = Layout.runners(rng:fork("runners"), m, strands[1].pts[1], W, edge)
  Plant.fork(strands[1], 0.005, 0.8)
  local stems = {}
  local stem_batch, spray_batch = S.batch(), S.batch()
  for _, list in ipairs({ strands, runners }) do
    for _, s in ipairs(list) do
      g:reserve_line(s.pts, 2, 4)
      stems[#stems + 1] = s
    end
  end

  local orn, panel = {}, nil
  -- Each slot's kind is drawn by weight (ornaments.lua) from a stream of
  -- its own; a slot whose kinds all weigh 0 is left empty.
  local cartouche = Orn.pick(rng:fork("choose cartouche"), "cartouche", spec.ornaments)
  if cartouche then
    -- The star cartouche sits in a quiet stretch, where the stems hug the
    -- outer edge and bend around it.
    -- The panel sits against the outer edge, so its own rectangle (with a
    -- small pad) is tested rather than a disk around its centre. It is
    -- tried at the reference's size first, then smaller.
    for _, k in ipairs({ 1.0, 0.82, 0.66 }) do
      local w, h = Layout.cartouche_size(mw, k)
      local cx = m.x0 + w / 2 + 2
      local fits = true
      for x = cx - w / 2 - 1, cx + w / 2 + 3, 2 do
        for y = py - h / 2 - 3, py + h / 2 + 3, 2 do
          if not g:free(x, y) then fits = false end
        end
      end
      if fits then
        g:box(cx - w / 2, py - h / 2, cx + w / 2, py + h / 2)
        local r = rng:fork("panel")
        orn[#orn + 1] = function(pt) Orn.draw(cartouche, pt, r, { cx - w / 2, py - h / 2, cx + w / 2, py + h / 2 }) end
        panel = { cx, py, w, h }
        break
      end
    end
  end
  local back, blooms, leaves, leaflet_items = {}, {}, {}, {}
  local ghost
  local ctx = {
    cfg = cfg, mix = spec.mix, pos = spec.grow and setmetatable({}, { __mode = "k" }), mw = mw, dens = dens, ylo = ylo, span = span, strands = strands, stems = stems,
    stem_batch = stem_batch, sprays = spray_batch, blooms = blooms, back = back,
    leaves = leaves, leaflets = leaflet_items,
  }
  -- As in the reference, a large ghost bloom usually sits low in the outer
  -- margin, just above the foot, behind the stems that cross it. It is
  -- recorded at 0.8 of its radius, so leaves and sprays may overlap only
  -- its petals' rims, and it takes the hole loop's one ghost.
  ctx.counts = {}
  do
    local gr = rng:fork("ghost")
    local gw = Mix.weight(spec.mix, "ghost")
    if gw > 0 and gr:chance(0.85 * math.min(1, gw)) then
      for _ = 1, 8 do
        local r = mw * gr:range(0.23, 0.28)
        local x = m.x0 + mw * gr:range(0.35, 0.5)
        local y = m.foot + gr:range(35, 75)
        local ok = true
        for k = 0, 11 do
          local q = G.polar({ x, y }, k * pi / 6, r * 0.9)
          local in_panel = panel and math.abs(q[1] - panel[1]) < panel[3] / 2 + 2
            and math.abs(q[2] - panel[2]) < panel[4] / 2 + 2
          if not g:open_at(q[1], q[2]) or in_panel then ok = false end
        end
        if ok then
          g:disc(x, y, r, 0.8)
          local fr = gr:fork("bloom")
          back[#back + 1] = function(pt) F.bloom(pt, fr, x, y, r, { kind = "ghost", look = "ghost", width = 0.55 }) end
          if ctx.pos then ctx.pos[back[#back]] = { x, y } end
          ctx.counts.ghost = 1
          ghost = { x, y, r }
          break
        end
      end
    end
  end
  local grow_rng = rng:fork("grow")
  Grow.node_leaves(g, grow_rng:fork("nodes"), strands, ctx)
  Grow.tips(g, grow_rng:fork("tips"), strands, ctx)
  -- Visitors claim their space before the holes fill (visitor.lua).
  Visitor.place(g, rng:fork("visitors"), ctx, strands)

  -- Gilt ornaments claim their space before the sprays fill in.
  if spec.header_y then
    local hx, hy = spec.text.x0 - 6, spec.header_y - 3
    local mark = Orn.pick(rng:fork("choose header"), "header", spec.ornaments)
    orn[#orn + 1] = function(pt)
      pt:stroke(G.polyline({ { hx + 4, hy }, { spec.text.x1, hy } }), pal.ink, 0.4, 0.9)
      if mark then Orn.draw(mark, pt, rng:fork("header"), { hx - 13, hy - 13, hx + 13, hy + 13 }) end
    end
  end
  -- A pendant knot hangs in the foot's corner on a cord from the foliage
  -- above, at the lowest place with room for it; its size and place vary
  -- with the seed.
  local pendant = Orn.pick(rng:fork("choose pendant"), "pendant", spec.ornaments)
  if pendant then
    local r = rng:fork("pendant")
    local w = G.clamp(mw * r:range(0.15, 0.19), 14, 30)
    local h = w * r:range(1.3, 1.5)
    local x = m.x0 + w / 2 + r:range(3, 10)
    for y = m.y0 + h / 2 + 1, m.y0 + 90, 3 do
      local clear = g:room(x, y) >= w * 0.3
      for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        if not g:open_at(x + q[1] * w / 2, y + q[2] * h / 2) then clear = false end
      end
      if clear then
        g:box(x - w / 2, y - h / 2, x + w / 2, y + h / 2)
        local cord = 0
        while cord < 40 and g:free(x, y + h / 2 + cord + 2) do cord = cord + 2 end
        if cord >= 6 then g:box(x - 1, y + h / 2, x + 1, y + h / 2 + cord) else cord = 0 end
        orn[#orn + 1] = function(pt) Orn.draw(pendant, pt, r, { x - w / 2, y - h / 2, x + w / 2, y + h / 2 }, { cord = cord }) end
        break
      end
    end
  end

  -- A dotted gilt chain runs down the outer edge wherever the foliage
  -- leaves it clear, from below the hero to the foot.
  local px = m.x0 + 2.5
  local runs, run = {}, nil
  local _, hero_rh = F.tilt(0, 0, R, Tune.hero.tilt)
  for y = hero[2] - hero_rh - 6, m.y0 + 6, -2 do
    if g:free(px, y) and g:free(px - 1.5, y) and g:free(px + 1.5, y) then
      if run then run[2] = y else run = { y, y } end
    else
      if run and run[1] - run[2] >= 28 then runs[#runs + 1] = run end
      run = nil
    end
  end
  if run and run[1] - run[2] >= 28 then runs[#runs + 1] = run end
  for k, rn in ipairs(runs) do
    for y = rn[1], rn[2], -5 do g:reserve(px, y, 5) end
    local r = rng:fork("chain" .. k)
    -- A run stopped by the cartouche's top hangs a knot over it.
    local foot = panel and math.abs(px - panel[1]) < panel[3] / 2
      and rn[2] - (panel[2] + panel[4] / 2) < 8 and rn[2] > panel[2] and "knot" or nil
    orn[#orn + 1] = function(pt) O.chain(pt, r, px, rn[1], rn[2], foot) end
  end

  -- Blooms and sprays on branches to the largest holes, then details.
  Grow.holes(g, grow_rng:fork("holes"), ctx)
  Grow.details(g, grow_rng:fork("details"), ctx)
  for _, s in ipairs(cfg.no_leaflets and {} or strands) do
    for _, it in ipairs(S.leaflet_items(rng, s.pts, cfg.leaflet_spacing, cfg.leaflet_size)) do
      if g:room(it[1], it[2]) >= it[4] * 0.3 and rng:next() < dens(it[1], it[2]) then
        leaflet_items[#leaflet_items + 1] = it
      end
    end
  end
  local sparkles = Fill.sparkles(rng:fork("sparkles"), g, 40, spec.ornaments)
  local midfoot = { W * 0.66, m.y0 + 10 }

  -- The plant's stems are drawn once every fork is known, so each narrows
  -- where its shoots leave.
  -- The plant's own stems are brushed washes (brush.stem); the corner
  -- sprig and the excursion stay pen work.
  local painted = {}
  for _, s in ipairs(strands) do
    if s.cum then painted[#painted + 1] = s else stem_batch:stem_by(s.pts, s.width) end
  end
  for _, s in ipairs(runners) do stem_batch:stem_by(s.pts, s.width) end

  -- Paint back to front.
  if not pt then
    pt = Paint.new({ backend = os.getenv("FLORA_BACKEND"), gilt = spec.gilt })
    pt.probe = spec.probe
    pt.gilt_dpi, pt.gilt_env, pt.gilt_look = spec.gilt_dpi, spec.gilt_env, spec.gilt_look
  end
  local function layer(tag, fn)
    pt:begin_group(tag)
    fn()
    pt:end_group()
  end
  -- A "watch it grow" frame (spec.grow below 1) paints only what the growth
  -- front has reached (clock.lua); otherwise every element paints in full.
  local clock = spec.grow and spec.grow < 1 and Clock.new(g, stems, spec.grow) or nil
  pt.clock = clock
  local function draw(f, dur, delay)
    if clock then clock:draw(pt, f, ctx.pos[f], dur, delay) else f(pt) end
  end
  layer("back", function()
    for _, f in ipairs(back) do draw(f, 0.1) end
  end)
  -- Bottom to top, as in the reference: stems and sprays, then leaflets,
  -- then leaves, then blooms. Each leaf knocks out what lies under it.
  layer("stems", function()
    local sr = rng:fork("stem paint")
    for _, s in ipairs(painted) do
      if clock then
        clock:stem(pt, s, Tune.plant.root_width, function(p) Brush.stem(p, sr, s.pts, s.width, Tune.plant) end)
      else
        Brush.stem(pt, sr, s.pts, s.width, Tune.plant)
      end
    end
    stem_batch:paint(pt)
  end)
  -- Fine sprays are pen work in a diluted ink, lighter than the stems.
  layer("sprays", function() spray_batch:paint(pt, Paint.mix(pal.ink, pal.sky, 0.4)) end)
  layer("leaflets", function()
    if clock then
      clock:leaflets(pt, rng:fork("leaflets"), leaflet_items, L.leaflets)
    else
      L.leaflets(pt, rng:fork("leaflets"), leaflet_items)
    end
  end)
  layer("leaves", function()
    for _, f in ipairs(leaves) do draw(f, 0.06) end
  end)
  layer("blooms", function()
    for _, f in ipairs(blooms) do draw(f, 0.1, 10) end
    local hf = function(p) F.hero(p, rng:fork("hero"), hero) end
    if clock then clock:draw(pt, hf, hero, 0.15) else hf(pt) end
  end)
  if ctx.visitors then
    layer("visitors", function()
      for _, f in ipairs(ctx.visitors) do draw(f, 0.08, clock and clock.reach * 0.25) end
    end)
  end
  layer("ornaments", function()
    for _, f in ipairs(orn) do draw(f, 0.15) end
    O.sparkles(pt, clock and clock:sparkles(sparkles) or sparkles)
    draw(function(p) O.compass(p, midfoot[1], midfoot[2], 7, { hair = 0.9, ring = 0 }) end, 0.15)
  end)
  pt.clock = nil
  pt.coverage = g:coverage()
  pt.panel = panel
  pt.ghost = ghost
  -- Motifs placed by kind (grow.lua), and the large leaves, for tests.
  pt.counts = ctx.counts
  pt.counts.leaves = #leaves
  pt.sparkles = sparkles
  return pt
end

-- Plan and paint a page. spec: width, height, text = {x0, y0, x1, y1},
-- optional lines, header_y, seed, edge, layout (frames.lua) with page and
-- title, and probe(x, y, r), which sees every painted point in page
-- coordinates (tests use it to check nothing lands on text); on_frame(f),
-- when given, is told each frame before its plant is painted.
function C.page(spec)
  local palette = Mix.resolve(spec.palette, spec.seed, spec.spin)
  return Mix.with_palette(palette, function() return C.frames(spec) end)
end

-- C.page, after the page's palette is in place.
function C.frames(spec)
  local frames = Frames.of(spec)
  if #frames == 1 and not frames[1].map then return plant(spec) end
  local pt = Paint.new({ backend = os.getenv("FLORA_BACKEND"), gilt = spec.gilt })
  pt.probe = spec.probe
  pt.gilt_dpi, pt.gilt_env, pt.gilt_look = spec.gilt_dpi, spec.gilt_env, spec.gilt_look
  local cover = 0
  for _, f in ipairs(frames) do
    local m = f.map
    if spec.on_frame then spec.on_frame(f) end
    pt:frame(function(x, y) return Frames.apply(m, x, y) end)
    plant(f.spec, pt)
    cover = cover + pt.coverage / #frames
  end
  pt:frame(nil)
  -- Title furniture paints over the finished crowns, in page coordinates;
  -- while the page grows it waits for the plants.
  if frames.title and (spec.grow or 1) >= 0.9 then
    pt:begin_group("title")
    Title.paint(pt, spec, frames.title)
    pt:end_group()
  end
  pt.title = frames.title
  pt.coverage = cover
  pt.frames = frames
  return pt
end

return C
