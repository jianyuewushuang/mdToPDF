-- Placement on the clearance field (space.lua), in the order a plant grows:
-- leaves at the stems' nodes, then blooms and sprays on branches grown out
-- to the largest open holes, then small details close to the stems. Every
-- placed element is recorded as proxy discs counted at k < 1 of their
-- radius, so neighbours may tuck a little under each other but never pile
-- up. The hole loop follows Wong, Zongker and Salesin, "Computer-Generated
-- Floral Ornament" (SIGGRAPH 1998): take the largest free disc within reach
-- of a stem, choose a motif that fits it, grow a branch to it.

local G = require("flora.geom")
local L = require("flora.leaf")
local S = require("flora.sprig")
local F = require("flora.flower")
local Fill = require("flora.fill")
local Plant = require("flora.plant")
local Tune = require("flora.tune")
local Dist = require("flora.dist")
local Mix = require("flora.mix")

local Grow = {}
local pi, min, max, floor = math.pi, math.min, math.max, math.floor

local REACH = 70      -- pt: a hole must lie within this distance of a stem

-- A repeatable jitter in [0.85, 1.15) for cell k on pass `iter`, so the
-- largest hole is not always the same shape of choice.
local function jitter(k, iter)
  local v = math.sin(k * 12.9898 + iter * 78.233) * 43758.5453
  return 0.85 + 0.3 * (v - floor(v))
end
local DISC_K = 0.85   -- blooms and sprays count at this share of their radius

-- Do all points (every other one) lie in open space, clear of text?
local function open_path(g, pts)
  for i = 1, #pts, 2 do
    if not g:open_at(pts[i][1], pts[i][2]) then return false end
  end
  return true
end
Grow.open_path = open_path

-- Proxy discs {x, y, r} for leaf `o` based at p heading ang: five along its
-- midrib, each as wide as the blade there.
local function leaf_discs(o, p, ang)
  local spine = G.curve(p, ang, o.len, o.bend, o.hook, 20)
  local out = {}
  for _, t in ipairs({ 0.2, 0.36, 0.52, 0.68, 0.84 }) do
    local q = spine[1 + floor(t * (#spine - 1) + 0.5)]
    out[#out + 1] = { q[1], q[2], 1.1 * o.width * L.profile(o, t) }
  end
  return out
end
Grow.leaf_discs = leaf_discs

-- Do discs fit the field, each allowed to overlap what is there by 1 - k?
local function discs_fit(g, discs, k)
  for _, d in ipairs(discs) do
    if g:room(d[1], d[2]) < k * d[3] then return false end
  end
  return true
end

-- Where a leaf heading `ang` from `p` joins its stem (see Grow.leaf): the
-- attachment for L.attach, drawn from its own fork of `r`, and the point
-- its blade starts from. A leaf joined at the stem's silhouette stands off
-- its edge on a short stalk; one in front of or behind it starts at its
-- centre. Without a stem, no attachment and the blade starts at p.
function Grow.joint(r, p, ang, len, stem)
  if not stem then return nil, p end
  local f = r:fork("attach"):range(-1, 1)
  local w = type(stem.width) == "function" and stem.width(stem.t) or (stem.width or 1.5)
  local _, ta = G.at(stem.pts, stem.t)
  local side = math.sin(ang - ta) >= 0 and 1 or -1
  local seg = {}
  for _, q in ipairs(stem.pts) do
    if G.dist(q, p) < len * 1.1 then seg[#seg + 1] = q end
  end
  local base = p
  if math.abs(f) < L.FRONT then base = G.polar(p, ta + side * pi / 2, w / 2 + 3) end
  return { f = f, p = p, seg = seg, w = w }, base
end

-- Plan a large leaf of length up to `len` at `p`, heading `ang`, drawn with
-- stream `r`. Its whole blade must fit the field, overlapping what is
-- already placed by at most `overlap` of its width, and clear the text;
-- otherwise it shrinks, up to three times. Returns its painter and the
-- proxy discs it recorded, or nil. With `stem` ({pts, t, width}: the
-- strand it grows from, the fraction along it, and its width function) the
-- leaf blends into the stem at its joint (L.attach).
function Grow.leaf(g, r, p, ang, len, overlap, stem)
  local k = 1 - overlap
  local o = L.options(r, len, ang)
  local at, base = Grow.joint(r, p, ang, len, stem)
  for _ = 1, 3 do
    local discs = leaf_discs(o, p, ang)
    if discs_fit(g, discs, k) and open_path(g, G.transform((L.outline(r:clone(), o)), p[1], p[2], ang - pi / 2)) then
      for _, d in ipairs(discs) do g:disc(d[1], d[2], d[3], k) end
      -- Some lance leaves come in pairs, as the reference's stem leaves do:
      -- a smaller one from the same node, turned aside. Its choices come
      -- from a fork, so the main leaf's stream is left untouched.
      local mate
      local mr = r:fork("mate")
      if o.margin == "entire" and o.len < 69 and mr:chance(0.35) then
        local ma = ang + (mr:chance(0.5) and 1 or -1) * mr:range(0.45, 0.7)
        local mo = L.options(mr, o.len * 0.65, ma)
        local md = leaf_discs(mo, p, ma)
        if discs_fit(g, md, k) and open_path(g, G.transform((L.outline(mr:clone(), mo)), p[1], p[2], ma - pi / 2)) then
          for _, d in ipairs(md) do g:disc(d[1], d[2], d[3], k) end
          mate = { ma, mo, mr }
        end
      end
      return function(pt)
        o.attach = at
        if mate then
          mate[2].attach = at
          L.leaf(pt, mate[3], base[1], base[2], mate[1], mate[2])
        end
        L.leaf(pt, r, base[1], base[2], ang, o)
      end, discs
    end
    o.len, o.width = o.len * 0.78, o.width * 0.78
    if o.len < 16 then return nil end
  end
end

-- A stemlet at p heading ang, about `len` long: a short stalk ending in two
-- or three leaflets. Adds its stalk to `ctx.sprays` and its leaflets to
-- `ctx.leaflets`.
local function stemlet(g, rng, ctx, p, ang, len, side)
  local stalk = len * rng:range(0.35, 0.5)
  local curve = G.curve(p, ang, stalk, side * rng:range(0.2, 0.5), 0, 6)
  if not open_path(g, curve) then return false end
  local tip = curve[#curve]
  local ta = G.angle(curve[#curve - 1], tip)
  local size = min((len - stalk) * 0.85, 11)
  ctx.sprays:line(curve, 1)
  local spread = rng:range(0.45, 0.7)
  local fan = rng:chance(0.5) and { -spread, spread } or { -spread, 0, spread }
  for _, da in ipairs(fan) do
    ctx.leaflets[#ctx.leaflets + 1] = { tip[1], tip[2], ta + da, size * (da == 0 and 1 or 0.8) }
  end
  g:disc(tip[1], tip[2], size * 0.6, DISC_K)
  return true
end

-- Leaves at the nodes of each strand, alternating sides. Nodes sit
-- tune.compose.leaf_spacing apart, spread further and holding smaller
-- leaves where the border is quiet (ctx.dens). Where no leaf fits, a
-- stemlet or a single leaflet takes the node if there is room.
--   ctx: cfg, mw, dens, leaves, leaflets, sprays (spray batch)
function Grow.node_leaves(g, rng, strands, ctx)
  local cfg = ctx.cfg
  local sp = cfg.leaf_spacing
  for k, st in ipairs(strands) do
    local pts = st.pts
    local total = G.length(pts)
    local side = rng:chance(0.5) and 1 or -1
    local d = rng:range(sp[1], sp[2]) * 0.5
    local n = 0
    while d < total - 8 and #ctx.leaves < cfg.leaves do
      n = n + 1
      local p, a = G.at(pts, d / total)
      local dn = ctx.dens(p[1], p[2])
      side = -side
      local ang = a + side * rng:range(0.6, 1.05)
      local len = min(130, ctx.mw * 0.85) * cfg.leaf_size * (0.45 + 0.55 * dn) * Dist.sample(rng, Tune.sizes.leaf)
      local paint = len >= 24 and Grow.leaf(g, rng:fork("leaf" .. k .. "." .. n), p, ang, len, cfg.leaf_overlap,
        { pts = pts, t = d / total, width = st.width })
      if paint then
        ctx.leaves[#ctx.leaves + 1] = paint
        if ctx.pos then ctx.pos[paint] = p end
      else
        local q = G.polar(p, ang, 7)
        local room = g:room(q[1], q[2])
        if room >= 7 and rng:chance(0.45) then
          stemlet(g, rng, ctx, p, ang, min(room * 2.2, 26), side)
        elseif room >= 4 then
          local size = min(room * 1.6, cfg.leaflet_size * Dist.sample(rng, Tune.sizes.leaflet))
          ctx.leaflets[#ctx.leaflets + 1] = { p[1], p[2], ang, size }
          local c = G.polar(p, ang, size * 0.5)
          g:disc(c[1], c[2], size * 0.3, DISC_K)
        end
      end
      d = d + rng:range(sp[1], sp[2]) * (1.7 - 0.7 * dn)
    end
  end
end

-- Every shoot ends in something: a leaf where there is room, otherwise a
-- forget-me-not cyme, otherwise a few buds.
function Grow.tips(g, rng, strands, ctx)
  local cfg = ctx.cfg
  for k, st in ipairs(strands) do
    if st.tip then
      local p, a = st.tip[1], st.tip[2]
      local r = rng:fork("tip" .. k)
      local len = min(110, ctx.mw * 0.7) * cfg.leaf_size * Dist.sample(r, Tune.sizes.leaf)
      local paint = len >= 20 and cfg.leaves > 0 and Grow.leaf(g, r, p, a, len, cfg.leaf_overlap, { pts = st.pts, t = 1, width = st.width })
      if paint then
        ctx.leaves[#ctx.leaves + 1] = paint
        if ctx.pos then ctx.pos[paint] = p end
      else
        local tmp = S.batch()
        S.cyme(tmp, r, p, a, r:range(14, 22), r:chance(0.5) and 1 or -1)
        if not Fill.fits(g, tmp) then
          tmp = S.batch()
          tmp:bud(p[1], p[2], a, 4)
        end
        if Fill.fits(g, tmp) then
          ctx.sprays:merge(tmp)
          g:disc(p[1], p[2], 8, DISC_K)
        end
      end
    end
  end
end

-- Stem points within reach of the holes: a list of {x, y, tangent, stem,
-- t} and, per field cell, the distance to the nearest of them. `keys`
-- lists the cells in reach in the order they were first reached, so scans
-- over them are deterministic.
local function reach_map(g)
  local m = { pts = {}, sd = {}, keys = {} }
  function m.add(stem, step)
    local pts = stem.pts
    local c, nx, ny = g.c, g.nx, g.ny
    local sd, keys, sqrt = m.sd, m.keys, math.sqrt
    local nk = #keys
    for i = 2, #pts - 1, step or 3 do
      local p = pts[i]
      local px, py = p[1], p[2]
      m.pts[#m.pts + 1] = { px, py, G.angle(pts[i - 1], pts[i + 1]), stem, (i - 1) / (#pts - 1) }
      local i0, i1 = max(0, floor((px - REACH) / c)), min(nx - 1, floor((px + REACH) / c))
      local j0, j1 = max(0, floor((py - REACH) / c)), min(ny - 1, floor((py + REACH) / c))
      for j = j0, j1 do
        local dy = (j + 0.5) * c - py
        local row = j * nx
        for ii = i0, i1 do
          local dx = (ii + 0.5) * c - px
          local k = row + ii
          local d = sqrt(dx * dx + dy * dy)
          local old = sd[k]
          if not old then
            nk = nk + 1
            keys[nk] = k
            sd[k] = d
          elseif d < old then
            sd[k] = d
          end
        end
      end
    end
  end
  function m.nearest(x, y)
    local best, bd = nil, math.huge
    for _, q in ipairs(m.pts) do
      local d = (q[1] - x) ^ 2 + (q[2] - y) ^ 2
      if d < bd then best, bd = q, d end
    end
    return best, math.sqrt(bd)
  end
  return m
end

-- The motifs a hole may take: weight, cap (nil: limited only by the spray
-- cap), and the radius range it comes in. Feature sizes scale with the
-- margin width and tune.compose.features.
local function motifs(mw, cfg, rng, mix)
  local kr = rng:range(cfg.features[1], cfg.features[2])
  local all = {
    { kind = "bloom", w = 3, cap = cfg.small_blooms, rmin = 9, rmax = mw * 0.13 * kr },
    { kind = "soft", w = 1.5, cap = Mix.motif_cap(2, cfg), rmin = 10, rmax = mw * 0.12 * kr },
    { kind = "lily", w = 1.2, cap = Mix.motif_cap(1, cfg), rmin = 16, rmax = mw * 0.21 * kr },
    { kind = "ghost", w = 1, cap = 1, rmin = 16, rmax = mw * 0.22 * kr, below = 0.4 },
    { kind = "umbel", w = 1.6, cap = Mix.motif_cap(3, cfg), rmin = 12, rmax = mw * 0.19 * kr },
    { kind = "cyme", w = 3, rmin = 7, rmax = 22, spray = true },
    { kind = "gyps", w = 4, rmin = 5, rmax = 30, spray = true },
  }
  -- Each motif's weight and cap follow the page's mix (mix.lua).
  local out = {}
  for _, m in ipairs(all) do out[#out + 1] = Mix.motif(m, mix) end
  return out
end

-- A bloom on a stalk grown from stem point s (distance sd) to centre c.
-- Returns the stalk, or nil if it would cross the text.
local function bloom_stalk(g, s, sd, c, r)
  local chord = G.angle(s, c)
  local dir0 = G.depart(s, s[3], c, 0.35)
  local base = G.polar(s, chord, max(sd - r * 0.45, 3))
  local stalk = G.link(s, dir0, base, chord + G.turn(chord, dir0) * 0.6)
  if open_path(g, stalk) then return stalk end
end

-- Fill the largest holes within reach of a stem, biggest first. A hole
-- counts only while its clearance exceeds tune.compose.hole_min, raised
-- where the border is quiet, so the quiet stretches stop filling first.
--   ctx: cfg, mw, dens, ylo, span, stems, stem_batch, sprays, blooms, back,
--   counts (motifs already placed, by kind; optional)
function Grow.holes(g, rng, ctx)
  local cfg = ctx.cfg
  local reach = reach_map(g)
  for _, st in ipairs(ctx.stems) do reach.add(st) end
  local kinds = motifs(ctx.mw, cfg, rng:fork("motifs"), ctx.mix)
  local counts, sprays, rejected = ctx.counts or {}, 0, {}
  local f, nx, c = g.f, g.nx, g.c
  -- The density field is fixed for the page, so each cell's floor is
  -- worked out once, the first time the scan below asks for it.
  local floors = {}
  local function floor_at(k, x, y)
    local v = floors[k]
    if not v then
      v = cfg.hole_min * (1 + 1.4 * (1 - ctx.dens(x, y)))
      floors[k] = v
    end
    return v
  end
  for iter = 1, 400 do
    local best, bi = -1, nil
    local sdm = reach.sd
    for _, k in ipairs(reach.keys) do
      local fk = f[k]
      if fk * 1.15 > best and sdm[k] <= REACH and not rejected[k] then
        local v = fk * jitter(k, iter)
        if v > best then
          local x, y = (k % nx + 0.5) * c, (k // nx + 0.5) * c
          if fk >= floor_at(k, x, y) then best, bi = v, k end
        end
      end
    end
    if not bi then break end
    local x, y = (bi % nx + 0.5) * c, (bi // nx + 0.5) * c
    local room = f[bi]
    local fy = (y - ctx.ylo) / ctx.span
    local elig, wsum = {}, 0
    for _, m in ipairs(kinds) do
      local n = counts[m.kind] or 0
      local ok = m.rmin <= room * 1.05 and (not m.cap or n < m.cap) and (not m.below or fy < m.below)
        and (not m.spray or sprays < cfg.sprays)
      if ok then
        local wt = m.w / (1 + n / (m.cap or 8))
        elig[#elig + 1] = { m, wt }
        wsum = wsum + wt
      end
    end
    local placed = false
    if #elig > 0 then
      local pick, acc = elig[#elig][1], rng:next() * wsum
      for _, e in ipairs(elig) do
        acc = acc - e[2]
        if acc <= 0 then pick = e[1] break end
      end
      local r = min(pick.rmax, room * 0.95)
      local s, sd = reach.nearest(x, y)
      local fr = rng:fork("hole" .. iter)
      if pick.spray or pick.kind == "umbel" then
        -- Sprays reach past their nominal radius, so each is grown in a
        -- scratch batch and kept only if it clears the text; then smaller.
        for _, t in ipairs({ { 1, fr:jit(0.3) }, { 0.7, 0 } }) do
          local tmp = S.batch()
          local stalk = Fill.grow(tmp, fr, pick.kind, s, s[3], sd, x, y, r, t[1], t[2])
          if Fill.fits(g, tmp) then
            ctx.sprays:merge(tmp)
            reach.add({ pts = stalk }, 2)
            g:disc(x, y, r * t[1], DISC_K)
            placed = true
            break
          end
        end
      else
        local cpt = { x, y }
        local stalk = bloom_stalk(g, s, sd, cpt, r)
        if stalk then
          if s[4].cum then Plant.fork(s[4], s[5], 0.7) end
          ctx.stem_batch:stem(stalk, 0.7, 0.4)
          reach.add({ pts = stalk }, 2)
          g:disc(x, y, r, DISC_K)
          placed = true
          if pick.kind == "lily" then
            local facing = G.angle(stalk[#stalk - 1], stalk[#stalk])
            ctx.blooms[#ctx.blooms + 1] = function(pt)
              F.tilted(pt, fr, x, y, r, facing, 1.0, { kind = "lance", petals = 6, width = 0.36 })
            end
            if ctx.pos then ctx.pos[ctx.blooms[#ctx.blooms]] = { x, y } end
          elseif pick.kind == "ghost" then
            ctx.back[#ctx.back + 1] = function(pt)
              F.bloom(pt, fr, x, y, r, { kind = "ghost", look = "ghost", width = 0.55 })
            end
            if ctx.pos then ctx.pos[ctx.back[#ctx.back]] = { x, y } end
          else
            local style = pick.kind == "soft" and "soft" or F.pick_style(fr, { "fan", "round" })
            ctx.blooms[#ctx.blooms + 1] = function(pt) F.bloom(pt, fr, x, y, r * 0.8, { style = style }) end
            if ctx.pos then ctx.pos[ctx.blooms[#ctx.blooms]] = { x, y } end
          end
        end
      end
      if placed then
        counts[pick.kind] = (counts[pick.kind] or 0) + 1
        if pick.spray or pick.kind == "umbel" then sprays = sprays + 1 end
      end
    end
    if not placed then rejected[bi] = true end
  end
  return counts
end

-- Small details close to the stems: buds, florets and little sprays in the
-- holes too small for the hole loop, and tendrils ending in a leaflet from
-- spare stretches of stem (tune.compose.curls).
function Grow.details(g, rng, ctx)
  local cfg = ctx.cfg
  local reach = reach_map(g)
  for _, st in ipairs(ctx.stems) do reach.add(st, 4) end
  local f, nx, c = g.f, g.nx, g.c
  local rejected, made = {}, 0
  for iter = 1, 300 do
    if made >= cfg.sprays then break end
    local best, bi = -1, nil
    local sdm = reach.sd
    for _, k in ipairs(reach.keys) do
      if f[k] > best and sdm[k] < 22 and not rejected[k] then best, bi = f[k], k end
    end
    if not bi or best < 3.5 then break end
    local x, y = (bi % nx + 0.5) * c, (bi // nx + 0.5) * c
    rejected[bi] = true
    if rng:next() < ctx.dens(x, y) then
      local s, sd = reach.nearest(x, y)
      local fr = rng:fork("detail" .. iter)
      local kind = best >= 6 and fr:weighted({ gyps = 3, bud = 2, cyme = 1 }) or fr:weighted({ gyps = 2, floret = 2 })
      local tmp = S.batch()
      Fill.grow(tmp, fr, kind, s, s[3], sd, x, y, best, 1, 0)
      if Fill.fits(g, tmp) then
        ctx.sprays:merge(tmp)
        g:disc(x, y, best, DISC_K)
        made = made + 1
      end
    end
  end
  -- Tendrils and loop flourishes leave a stem nearly tangentially and are
  -- cut before their tight coil, ending in a leaflet.
  for k, st in ipairs(ctx.strands) do
    local pts = st.pts
    for i = 12, #pts - 12, 14 do
      local p = pts[i]
      if rng:next() < cfg.curls * (0.04 + 0.1 * ctx.dens(p[1], p[2])) then
        local side = rng:chance(0.5) and 1 or -1
        local start = G.angle(pts[i - 1], pts[i + 1]) + side * rng:range(0.25, 0.45)
        local curve
        if rng:chance(0.45) then
          curve = S.flourish(p, start, rng:range(55, 90), side)
          curve = { table.unpack(curve, 1, floor(#curve * 0.8)) }
        else
          curve = S.tendril(p, start, rng:range(30, 55), side)
          curve = { table.unpack(curve, 1, floor(#curve * 0.7)) }
        end
        local n = #curve
        if n >= 4 and open_path(g, curve) then
          local mid, tip = curve[floor(n / 2)], curve[n]
          if g:room(mid[1], mid[2]) >= 3 and g:room(tip[1], tip[2]) >= 5 then
            local tip_a = G.angle(curve[n - 1], tip)
            local size = cfg.leaflet_size * Dist.sample(rng, Tune.sizes.leaflet)
            ctx.sprays:line(curve, 2)
            ctx.leaflets[#ctx.leaflets + 1] = { tip[1], tip[2], tip_a, min(size, g:room(tip[1], tip[2]) * 1.8) }
            g:disc(mid[1], mid[2], 3, 1)
            g:disc(tip[1], tip[2], 4, 1)
          end
        end
      end
    end
  end
end

return Grow
