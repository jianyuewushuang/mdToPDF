-- Watercolor rendering of a closed shape.
--
-- A shape is painted as glazes rather than a flat fill:
--   1. two jittered underwash layers that bleed slightly past the contour;
--   2. the pigment body, multiplied onto the paper;
--   3. a base-to-tip gradient generated per shape (color.lua) with
--      variegated glazes, back-runs and a tideline on top; or, without a
--      ramp, nested lightening layers that shrink toward a light point;
--   4. a wide inner band stroked along the clipped contour (the wet edge);
--   5. streaks: tapered white and dark hairlines fanning from the light point;
--   6. granulation: speckle of dark and pale dots;
--   7. an optional ink contour;
-- with lost and found edges: along part of the contour the rim, the ink and
-- the wash itself give way to the paper, and the eye completes the form.

local G = require("flora.geom")
local Paint = require("flora.paint")
local Color = require("flora.color")
local Tune = require("flora.tune")
local Brush = require("flora.brush")
local Rng = require("flora.rng")
local pal = Paint.palette

local W = {}
local MULT = { blend = "multiply" }

-- Shade the clipped shape along base -> tip with a ramp generated for look
-- `look` (see color.lua). The ramp is stretched by a random factor, so how
-- far the deep tone reaches and how large the pale base is differ from shape
-- to shape. Returns the ramp's description for matching glazes.
local function ramp_fill(pt, rng, look, base, tip, half, part)
  local stops, info = Color.ramp(rng, look, part)
  pt._ramps = (pt._ramps or 0) + 1
  local name = pt:shading("flramp" .. pt._ramps, stops)
  -- A shading stops at its ends; a hooked tip that curls past the end
  -- would show bare paper, so lay the tip colour underneath first.
  pt:fill({ { "o", (base[1] + tip[1]) / 2, (base[2] + tip[2]) / 2, half } }, stops[#stops][2], 1)
  local reach = rng:range(0.82, 1.12)
  local start = G.mix(base, tip, -rng:range(0.0, 0.18))
  local stop = G.mix(base, tip, reach)
  pt:shade(name, start, stop, half)
  return info
end

-- A random point inside `poly`, or its centroid if sampling misses.
local function inside_point(rng, poly)
  local x0, y0, x1, y1 = G.bbox(poly)
  for _ = 1, 30 do
    local x, y = rng:range(x0, x1), rng:range(y0, y1)
    if G.inside(poly, x, y) then return { x, y } end
  end
  return G.centroid(poly)
end

-- An irregular blot of radius r around c.
local function blot(rng, c, r)
  local pts = {}
  for k = 0, 23 do
    local a = k * math.pi / 12
    pts[#pts + 1] = { c[1] + r * math.cos(a), c[2] + r * math.sin(a) }
  end
  return G.smooth(G.deform(pts, rng, r * 0.28), true)
end

-- Variegation inside a clipped shape, after its ramp: glazes of a
-- neighbouring hue that pool unevenly (wet-on-wet), pale back-runs whose
-- edges darken where the lifted pigment dried, and a tideline of pooled
-- pigment along part of the contour.
local function variegate(pt, rng, poly, size, info, lifts)
  local cfg = Tune.wash
  for _ = 1, rng:int(cfg.blotches[1], cfg.blotches[2]) do
    local c = inside_point(rng, poly)
    local h = info.h + rng:jit(cfg.blotch_hue)
    local L = rng:range(math.max(0.35, info.L - 0.05), 0.82)
    local col = Color.oklch(L, info.share * rng:range(0.6, 1.0) * Color.max_chroma(L, h), h)
    pt:fill(blot(rng, c, size * rng:range(0.16, 0.40)), col, rng:range(cfg.blotch_opacity[1], cfg.blotch_opacity[2]), MULT)
  end
  for _ = 1, math.floor(rng:int(cfg.lifts[1], cfg.lifts[2]) * (lifts or 1)) do
    local c = inside_point(rng, poly)
    local b = blot(rng, c, size * rng:range(0.10, 0.22))
    pt:fill(b, pal.white, rng:range(cfg.lift_opacity[1], cfg.lift_opacity[2]))
    local edge = Color.oklch(info.L + 0.15, 0.6 * Color.max_chroma(info.L + 0.15, info.h), info.h)
    pt:stroke(b, edge, size * 0.012, 0.22, MULT)
  end
  if rng:chance(cfg.tideline_chance) then
    local n = #poly
    local i0 = rng:int(1, n)
    local run = {}
    for k = 0, math.floor(n * rng:range(0.25, 0.5)) do run[#run + 1] = poly[(i0 + k - 1) % n + 1] end
    if #run >= 3 then
      local col = Color.oklch(info.L * 0.85, Color.max_chroma(info.L * 0.85, info.h) * 0.8, info.h)
      pt:stroke(G.smooth(run, false), col, size * 0.03, 0.35, MULT)
    end
  end
end

-- Tapered stroke outline along `line`, widest near the start.
function W.taper(line, wmax, head)
  head = head or 0.12
  return G.ribbon(line, function(t)
    return wmax * G.smoothstep(0, head, t) * (1 - t) ^ 1.1 + 0.02
  end)
end

-- Fill a batch of tapered hairlines in one scope.
function W.hairlines(pt, lines, rgb, wmax, opacity, opts)
  if #lines == 0 then return end
  local paths = {}
  for i, line in ipairs(lines) do
    paths[i] = G.smooth(W.taper(line, wmax, opts and opts.head), true)
  end
  pt:fill(paths, rgb, opacity, { many = true, blend = opts and opts.blend })
end

-- Speckle inside `poly`. Dots crowd toward the rim when `rim` > 0. A share
-- `clump` of them settle in small clumps around a seed dot, and `mottle`
-- lays faint dark and pale patches a few points across beneath them, so the
-- pigment reads as granulated rather than sprinkled.
function W.grain(pt, rng, poly, density, opts)
  opts = opts or {}
  local x0, y0, x1, y1 = G.bbox(poly)
  local area = math.abs(G.area(poly))
  local n = math.min(math.floor(area * density), opts.cap or 1600)
  local c = G.centroid(poly)
  local reach = math.max(x1 - x0, y1 - y0) / 2
  local scale = opts.scale or 1
  local clump = opts.clump or 0
  local dark, pale = {}, {}
  -- Dots are drawn inside the clip, so they are sampled from the shape's
  -- row spans rather than tested point by point. The attempt budget is the
  -- number of in-shape points that bounding-box sampling would have found.
  local sample = G.span_sampler(poly, math.max(0.3, (y1 - y0) / 150))
  local budget = sample and n * 4 * area / math.max(1e-9, (x1 - x0) * (y1 - y0)) or 0
  local mottle = opts.mottle or 0
  if sample and mottle > 0 then
    local blots_dark, blots_pale = {}, {}
    for _ = 1, math.min(60, math.floor(area / 30 * mottle + 0.5)) do
      local x, y = sample(rng)
      local b = blot(rng, { x, y }, rng:range(0.8, 2.6) * scale)
      if rng:chance(0.6) then blots_dark[#blots_dark + 1] = b else blots_pale[#blots_pale + 1] = b end
    end
    if #blots_dark > 0 then
      pt:fill(blots_dark, opts.dark_rgb or pal.deep, 0.10 * math.min(1.5, mottle), { many = true, blend = "multiply" })
    end
    if #blots_pale > 0 then
      pt:fill(blots_pale, pal.white, 0.10 * math.min(1.5, mottle), { many = true })
    end
  end
  local function dot(x, y, is_dark)
    local r = rng:range(0.10, 0.32) * scale
    if is_dark then
      dark[#dark + 1] = { { "o", x, y, r } }
    else
      pale[#pale + 1] = { { "o", x, y, r * 0.9 } }
    end
  end
  local tries = 0
  while #dark + #pale < n and tries < budget do
    tries = tries + 1
    local x, y = sample(rng)
    local edge = G.dist(c, { x, y }) / reach
    if rng:next() < 0.35 + (opts.rim or 0.6) * edge then
      local is_dark = rng:next() < (opts.dark or 0.6)
      -- A clump of k dots (5 on average) is seeded with probability p, so
      -- p 5 / (p 5 + 1 - p) = clump of the dots are clumped; clumps count
      -- against the total, so the density stays as asked.
      if clump > 0 and rng:next() < clump / (5 - 4 * math.min(1, clump)) then
        local k, cr = rng:int(3, 7), rng:range(0.5, 1.4) * scale
        for _ = 1, math.min(k, n - #dark - #pale) do
          dot(x + rng:jit(1) * cr, y + rng:jit(1) * cr, is_dark)
        end
      else
        dot(x, y, is_dark)
      end
    end
  end
  if #dark > 0 then
    pt:fill(dark, opts.dark_rgb or pal.deep, opts.dark_op or 0.38, { many = true, blend = "multiply" })
  end
  if #pale > 0 then
    pt:fill(pale, pal.white, opts.pale_op or 0.45, { many = true })
  end
end

-- Streak centerlines fanning from `from` toward the contour vertices.
function W.fan(rng, poly, from, count, reach0, reach1)
  local lines = {}
  for _ = 1, count do
    local v = poly[rng:int(1, #poly)]
    local t0 = rng:range(0.02, 0.18)
    local t1 = rng:range(reach0 or 0.55, reach1 or 0.95)
    local a = G.mix(from, v, t0)
    local b = G.mix(from, v, t1)
    local m = G.mix(a, b, 0.5)
    local bow = rng:jit(0.06) * G.dist(a, b)
    local ang = G.angle(a, b) + math.pi / 2
    m = G.polar(m, ang, bow)
    lines[#lines + 1] = G.spline_points({ a, m, b }, 6)
  end
  return lines
end

-- Lost and found edges. The contour is split into runs where the edge is
-- found (rim and ink drawn) and runs where it is lost (the wash fades into
-- the paper). Edges are lost mostly where `pale_at` (0-1 at a point) says the
-- shape is palest, so light washes meet the page without a boundary while
-- the deep end keeps a crisp edge. `share` is the fraction of the contour
-- lost. Returns found and lost runs as open polylines that share their end
-- points, or nil when nothing is lost.
function W.edge_runs(rng, poly, pale_at, share)
  if share <= 0 then return nil end
  local N = 96
  local ring = { table.unpack(poly) }
  ring[#ring + 1] = poly[1]
  local pts = G.resample(ring, N + 1)
  pts[#pts] = nil
  -- Noise with a period of the whole contour, so the ends agree.
  local nz, ph = G.noise(rng, 6), rng:int(0, 5)
  local score = {}
  for i, p in ipairs(pts) do
    score[i] = 0.3 * pale_at(p) + 0.7 * (0.5 + 0.5 * nz(ph + (i - 1) / N * 6))
  end
  local sorted = { table.unpack(score) }
  table.sort(sorted)
  local k = math.floor(N * (1 - share) + 0.5)
  if k >= N then return nil end
  local cut = k >= 1 and sorted[k] or -math.huge
  local lost = {}
  for i = 1, N do lost[i] = score[i] > cut end
  -- Start the walk at a change from found to lost.
  local start
  for i = 1, N do
    if lost[i] and not lost[(i - 2) % N + 1] then start = i break end
  end
  if not start then return nil end
  local found_runs, lost_runs = {}, {}
  local run, state = { pts[(start - 2) % N + 1] }, true
  for j = 0, N - 1 do
    local i = (start + j - 1) % N + 1
    if lost[i] ~= state then
      local into = state and lost_runs or found_runs
      into[#into + 1] = run
      run, state = { run[#run] }, lost[i]
    end
    run[#run + 1] = pts[i]
  end
  run[#run + 1] = pts[(start - 2) % N + 1]
  local into = state and lost_runs or found_runs
  into[#into + 1] = run
  return found_runs, lost_runs
end

-- A filled band of half-width `w` along open polyline `run`, tapering to
-- nothing over the first and last `taper` of its length. With `rng` and
-- `wobble` the band's edges are displaced by up to `wobble` pt.
local function band(run, w, taper, rng, wobble, scale_at)
  local line = G.resample(run, math.max(4, #run))
  local poly = G.ribbon(line, function(t)
    local s = scale_at and scale_at(line[1 + math.floor(t * (#line - 1) + 0.5)]) or 1
    return w * s * G.smoothstep(0, taper, t) * G.smoothstep(0, taper, 1 - t)
  end)
  if rng then poly = G.deform(poly, rng, wobble) end
  return G.smooth(poly, true)
end

local function bands(runs, w, taper, rng, wobble, scale_at)
  local out = {}
  for _, r in ipairs(runs) do
    if #r >= 2 then out[#out + 1] = band(r, w, taper, rng, wobble, scale_at) end
  end
  return out
end

-- Paint `poly` as a watercolor glaze. See the module comment for the layers.
--   o.rng       random stream (required)
--   o.size      characteristic length of the shape, in pt
--   o.pigment   body color; o.pool the darker rim color
--   o.light     {x, y} point the wash lightens toward (defaults to centroid)
--   o.strength  overall pigment load, 0-1
--   o.knockout  opacity of the paper laid under the shape (0 to glaze through)
--   o.bleed     how far the underwash strays past the contour, in pt
--   o.rings     number of lightening layers; o.lift their white opacity
--   o.streaks   number of white streaks; o.dark_streaks dark ones
--   o.rays      white rays from o.light: {count, reach = {lo, hi} (share of
--               the way to the rim), contrast = {lo, hi} (opacity)}
--   o.grain     dots per square pt
--   o.outline   contour opacity, 0 for none
--   o.lost      share of the contour whose edge is lost (default
--               tune.wash.lost_edges)
--   o.eye_fade  0-1: how far a lost edge's fade is kept to the pale end
--   o.lifts     multiplier on the number of back-runs (default 1)
--   o.pale_scale  multiplier on the number of pale brush strokes (default 1)
--   o.fade_scale  multiplier on how far a lost edge fades in (default 1)
--   o.part      tune.color.palette part whose ink paints the ramp
--               (default: the look's own part)
--   o.ink       an ink that recolours the fixed blue pigment, pool, grain
--               and contour (default: o.part's ink, if any)
--   o.simple    for small shapes: no brushwork, glazes or back-runs, and a
--               lost-edge fade of 3 layers instead of 7
--   o.inner     function(pt) called while clipped, for veins and the like
--   o.brush_lines  function(rng, n) returning n centrelines for brushwork
--               (default: a fan from o.light toward the contour)
--   o.ramp      look for color.ramp; with o.axis = {base, tip} the body is a
--               continuous gradient instead of lightening layers
function W.wash(pt, poly, o)
  local rng = o.rng
  local size = o.size
  local s = o.strength or 1
  -- A part painted in a non-blue ink takes that ink for its fixed blue
  -- pigments too, so its bleed and pooled rim are not ultramarine.
  local part = o.part or (o.ramp and Color.part_of(o.ramp))
  local tint = o.ink or Color.part_ink(part)
  local pig = Color.recolor(o.pigment or pal.blue, tint)
  local pool = Color.recolor(o.pool or pal.deep, tint)
  local line = Color.recolor(pal.ink, tint)
  local grain = Color.recolor(pal.deep, tint)
  local light = o.light or G.centroid(poly)
  local body = G.smooth(poly, true)
  local cfg = Tune.wash
  local axis = o.axis
  local pale_at
  if o.ramp and axis then
    local dx, dy = axis[2][1] - axis[1][1], axis[2][2] - axis[1][2]
    local dd = math.max(1e-9, dx * dx + dy * dy)
    pale_at = function(p)
      return 1 - G.clamp(((p[1] - axis[1][1]) * dx + (p[2] - axis[1][2]) * dy) / dd, 0, 1)
    end
  else
    local far = 1e-9
    for _, p in ipairs(poly) do far = math.max(far, G.dist(p, light)) end
    pale_at = function(p) return 1 - G.dist(p, light) / far end
  end
  local erng = Rng.new(rng:int(1, 2 ^ 30))
  local found, lost = W.edge_runs(erng, poly, pale_at, o.lost or cfg.lost_edges)

  -- Knock out what lies beneath so a front petal covers the one behind it
  -- instead of glazing over it.
  if (o.knockout or 0.9) > 0 then
    pt:fill(body, pal.paper, o.knockout or 0.9)
  end
  local bleed = o.bleed or size * 0.022
  for _ = 1, 2 do
    pt:fill(G.smooth(G.deform(poly, rng, bleed), true), pig, 0.10 * s, MULT)
  end
  if o.ramp then
    -- A continuous base-to-tip gradient: the full range from paper white to
    -- deep ultramarine within one shape.
    pt:clip_begin(body)
    local info = ramp_fill(pt, rng, o.ramp, o.axis[1], o.axis[2], size * 1.5, o.part)
    -- An ink group picks one ink per shape; the rim pools in that ink.
    if info.ink then
      pool, line = Color.recolor(o.pool or pal.deep, info.ink), Color.recolor(pal.ink, info.ink)
      grain = Color.recolor(pal.deep, info.ink)
    end
    -- Broken brushwork along the growth direction, then the glazes over it.
    local k = G.clamp(size / 30, 0.3, 1.3)
    local nd = math.floor(rng:range(cfg.brush_bands[1], cfg.brush_bands[2]) * k + 0.5)
    local np = math.floor(rng:range(cfg.brush_pale[1], cfg.brush_pale[2]) * k * (o.pale_scale or 1) + 0.5)
    local dark, pale
    if o.brush_lines then
      dark, pale = o.brush_lines(rng, nd), o.brush_lines(rng, np)
    else
      dark, pale = W.fan(rng, poly, light, nd, 0.6, 1.0), W.fan(rng, poly, light, np, 0.5, 0.98)
    end
    if not o.simple then
      Brush.paint(pt, rng, dark, pale, size, info, cfg)
      variegate(pt, rng, poly, size, info, o.lifts)
    end
  else
    pt:fill(body, pig, math.min(0.95, 0.85 * s), MULT)
    pt:clip_begin(body)
    -- Many faint layers read as a gradient; few strong ones read as rings.
    local rings = o.rings or 12
    for k = 1, rings do
      local sc = 1 - (k / (rings + 1)) ^ 0.75 * 0.97
      local layer = G.deform(G.toward(poly, light[1], light[2], sc), rng, size * 0.018 * sc)
      pt:fill(G.smooth(layer, true), pal.white, o.lift or 0.10)
    end
  end

  -- The wet edge: pigment pools at the rim, heaviest toward the tip.
  if found then
    pt:fill(bands(found, size * 0.08, 0.2), pool, (o.ramp and 0.12 or 0.16) * s, { many = true, blend = "multiply" })
    pt:fill(bands(found, size * 0.025, 0.2), pool, (o.ramp and 0.26 or 0.30) * s, { many = true, blend = "multiply" })
  else
    pt:stroke(body, pool, size * 0.16, (o.ramp and 0.12 or 0.16) * s, MULT)
    pt:stroke(body, pool, size * 0.05, (o.ramp and 0.26 or 0.30) * s, MULT)
  end

  local streaks = math.floor((o.streaks or 0) * (o.ramp and Tune.wash.streak_scale or 1))
  if streaks > 0 then
    local lines = W.fan(rng, poly, light, streaks)
    local half = math.floor(#lines / 2)
    W.hairlines(pt, { table.unpack(lines, 1, half) }, pal.white, size * 0.022, 0.75)
    W.hairlines(pt, { table.unpack(lines, half + 1) }, pal.white, size * 0.013, 0.55)
  end
  -- Rays: fine white lines fanning from the light point (a flower's eye)
  -- partway along the shape, each with its own contrast.
  if o.rays and o.rays.count > 0 then
    local lines = W.fan(rng, poly, light, o.rays.count, o.rays.reach[1], o.rays.reach[2])
    local lo, hi = o.rays.contrast[1], o.rays.contrast[2]
    local thirds = math.max(1, math.floor(#lines / 3))
    for k = 0, 2 do
      local part = { table.unpack(lines, k * thirds + 1, k == 2 and #lines or (k + 1) * thirds) }
      W.hairlines(pt, part, pal.white, size * (0.007 + 0.004 * k), lo + (hi - lo) * k / 2)
    end
  end
  if (o.dark_streaks or 0) > 0 then
    local lines = W.fan(rng, poly, light, o.dark_streaks, 0.4, 0.98)
    W.hairlines(pt, lines, pool, size * 0.010, cfg.vein_opacity * s, { blend = "multiply" })
  end

  if o.inner then o.inner(pt) end

  if (o.grain or 0) > 0 then
    W.grain(pt, rng, poly, o.grain, { scale = o.grain_scale or 1, dark_op = 0.30 * s + 0.08,
      clump = cfg.grain_clump, mottle = cfg.grain_mottle, dark_rgb = grain })
  end

  -- Lost edges: the wash fades into the paper through faint, uneven layers
  -- that reach in from the contour, so the white of the page runs into the
  -- shape without a boundary of its own.
  if lost and cfg.lost_fade > 0 then
    -- Depth follows the shape's thickness (2 area / perimeter, about the
    -- width of a thin blade), not its length, so a long leaf keeps its body.
    local ring = { table.unpack(poly) }
    ring[#ring + 1] = poly[1]
    local thick = 2 * math.abs(G.area(poly)) / math.max(1e-9, G.length(ring))
    local d = math.min(size, 1.6 * thick) * cfg.lost_fade * (o.fade_scale or 1)
    -- With o.eye_fade (0-1) the fade narrows away from the pale end, so a
    -- petal pales toward its eye and keeps its blue up the sides and tip.
    local ef = o.eye_fade or 0
    local scale_at = ef > 0 and function(p) return 1 - ef + ef * G.smoothstep(0.35, 0.9, pale_at(p)) end or nil
    local layers = o.simple and 3 or 7
    for k = 1, layers do
      local w = d * (0.36 - 0.045 * (k - 1) * 7 / layers)
      pt:fill(bands(lost, w, 0.4 - 0.03 * k, erng, w * 0.25, scale_at), pal.white, 0.22, { many = true })
    end
  end

  pt:clip_end()

  if (o.outline or 0) > 0 then
    if found then
      pt:fill(bands(found, (o.outline_w or 0.28) / 2, 0.25), line, o.outline, { many = true, blend = "multiply" })
    else
      pt:stroke(body, line, o.outline_w or 0.28, o.outline, MULT)
    end
  end
end

return W
