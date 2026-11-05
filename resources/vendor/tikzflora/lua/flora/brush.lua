-- Broken, directional brushwork: pigment bands and pale striations that
-- follow a shape's growth direction. Each mark swells and pinches, breaks
-- into pieces with gaps between them, and sometimes splits into thin
-- parallel threads, as a dry brush skips over the paper's grain. Marks are
-- drawn inside a shape's clip and under its glazes, so they read as part of
-- the wash rather than as lines drawn over it.

local G = require("flora.geom")
local Color = require("flora.color")
local Paint = require("flora.paint")
local Tune = require("flora.tune")
local pal = Paint.palette

local B = {}

-- Path commands for an outline as a plain polygon. Brush marks are a few
-- points wide with ten points a side, so straight segments read as smooth
-- and cost a third of the bytes of a spline.
function B.polygon(poly)
  local cmds = { { "m", poly[1][1], poly[1][2] } }
  for i = 2, #poly do cmds[i] = { "l", poly[i][1], poly[i][2] } end
  cmds[#cmds + 1] = { "z" }
  return cmds
end

-- The part of `pts` (uniformly resampled) between fractions t0 and t1.
local function slice(pts, t0, t1)
  local n = #pts
  local i0 = math.max(1, math.floor(t0 * (n - 1)) + 1)
  local i1 = math.min(n, math.ceil(t1 * (n - 1)) + 1)
  local out = {}
  for i = i0, i1 do out[#out + 1] = pts[i] end
  return out
end

-- `pts` shifted sideways by d (positive: to the left of travel).
local function offset(pts, d)
  local out = {}
  for i = 1, #pts do
    local a = G.angle(pts[math.max(1, i - 1)], pts[math.min(#pts, i + 1)]) + math.pi / 2
    out[i] = G.polar(pts[i], a, d)
  end
  return out
end

-- Points to resample a line `len` pt long at: at least `least`, and one
-- every BROKEN_STEP pt, so a long stroke follows its curve rather than
-- cutting chords across it. Taken a hair above the boundary, as in stem.
local BROKEN_STEP = 6
local function steps(len, least)
  return math.max(least, math.floor(len / BROKEN_STEP + 1e-6))
end

-- Outlines of one broken stroke along polyline `line`, at most `wmax` pt
-- wide. `gap` (0-1) sets how much of the length is left unpainted; `dry`
-- (0-1) is the chance a piece splits into threads.
function B.broken(rng, line, wmax, gap, dry)
  local pts = G.resample(line, steps(G.length(line), 32))
  local nz = G.noise(rng, 16)
  local phase = rng:range(0, 16)
  local out = {}
  local t = rng:range(0, 0.12)
  while t < 0.95 do
    local t1 = math.min(1, t + rng:range(0.14, 0.5) * (1 - 0.6 * gap))
    local seg = slice(pts, t, t1)
    if #seg >= 2 then
      seg = G.resample(seg, steps(G.length(seg), 10))
      local a, b = t, t1
      local function w(u)
        local tt = a + (b - a) * u
        local taper = G.smoothstep(0, 0.12, tt) * (1 - tt) ^ 0.7
        local ends = math.sin(math.pi * G.clamp(u, 0, 1)) ^ 0.6
        local swell = 0.5 + 0.5 * nz(phase + tt * 9)
        return wmax * taper * ends * (0.2 + swell)
      end
      if rng:chance(dry) then
        local k = rng:int(2, 3)
        for j = 1, k do
          local d = (j - (k + 1) / 2) * wmax * 0.9
          out[#out + 1] = G.ribbon(offset(seg, d), function(u) return w(u) * rng:range(0.25, 0.45) end)
        end
      else
        out[#out + 1] = G.ribbon(seg, w)
      end
    end
    t = t1 + rng:range(0.02, 0.12) * gap * 2.5
  end
  return out
end

-- Paint brushwork inside a clipped shape of characteristic length `size`.
-- `dark` and `pale` are centrelines running in the shape's growth
-- direction; `info` describes the shape's ramp (color.ramp). `cfg` is
-- tune.wash.
function B.paint(pt, rng, dark, pale, size, info, cfg)
  local MULT = { many = true, blend = "multiply" }
  for _, line in ipairs(dark) do
    local pieces = B.broken(rng, line, size * rng:range(0.025, 0.06) * cfg.brush_width, cfg.brush_gap, cfg.brush_dry)
    if #pieces > 0 then
      local L = G.clamp(info.L + rng:range(0, 0.25), 0.25, 0.9)
      local h = info.h + rng:jit(6)
      local col = Color.oklch(L, info.share * Color.max_chroma(L, h), h)
      local cmds = {}
      for i, p in ipairs(pieces) do cmds[i] = B.polygon(p) end
      pt:fill(cmds, col, rng:range(cfg.band_opacity[1], cfg.band_opacity[2]), MULT)
    end
  end
  for _, line in ipairs(pale) do
    local pieces = B.broken(rng, line, size * rng:range(0.012, 0.036) * cfg.brush_width, cfg.brush_gap, cfg.brush_dry)
    if #pieces > 0 then
      local cmds = {}
      for i, p in ipairs(pieces) do cmds[i] = B.polygon(p) end
      -- Contrast varies per streak: some are barely lighter than the wash.
      pt:fill(cmds, pal.white, rng:range(cfg.pale_contrast[1], cfg.pale_contrast[2]), { many = true })
    end
  end
end

-- `pts` shifted sideways by f(i) * w(t) at each point i (t its fraction of
-- the length), for lines that keep a place across a tapering stem.
local function offset_by(pts, wfn, f)
  local out, n = {}, #pts
  for i = 1, n do
    local a = G.angle(pts[math.max(1, i - 1)], pts[math.min(n, i + 1)]) + math.pi / 2
    out[i] = G.polar(pts[i], a, f * wfn((i - 1) / math.max(1, n - 1)))
  end
  return out
end

-- The stem body's colour, as B.stem lays it, for shapes that blend into a
-- stem. Where tune.color.palette.stems names an ink group, its first ink.
function B.stem_tone(cfg)
  local h = Tune.color.hue
  local choice = Tune.color.palette and Tune.color.palette.stems
  local first = { int = function(_, a) return a end }
  local ink = Color.ink_for(first, choice)
  if ink then return Color.ink_rgb(ink, cfg.stem_l) end
  return Color.oklch(cfg.stem_l, 0.85 * Color.max_chroma(cfg.stem_l, h), h)
end

-- Paint a stem of full width wfn(t) along `pts` as a brushed wash rather
-- than an inked ribbon: a body glaze, a broken darker band down its shadow
-- side, a broken pale streak down its lit side, and an ink line along the
-- shadow edge that breaks off in places, where the stem melts into the
-- paper. `cfg` is tune.plant.
function B.stem(pt, rng, pts, wfn, cfg)
  local MULT = { many = true, blend = "multiply" }
  local h = Tune.color.hue
  local L = cfg.stem_l
  -- tune.color.palette.stems may name an ink (or group) for the stems.
  local ink = Color.ink_for(rng, Tune.color.palette and Tune.color.palette.stems)
  local function tone(l, k)
    if ink then return Color.ink_rgb(ink, l) end
    return Color.oklch(l, k * Color.max_chroma(l, h), h)
  end
  local body = tone(L, 0.85)
  local half = function(t) return wfn(t) / 2 end
  local outline = G.smooth(G.ribbon(pts, half), true)
  pt:fill(outline, body, 0.55 + 0.35 * (1 - cfg.stem_brush), { blend = "multiply" })
  if cfg.stem_brush <= 0 then return end
  -- A point every 3 pt. Stems are often a whole number of steps long, and
  -- runtimes sum that length an ulp apart, so the count is taken a hair
  -- above the boundary to come out the same everywhere.
  local line = G.resample(pts, math.max(8, math.floor(G.length(pts) / 3 + 1e-6)))
  local wmax = 0
  for i = 0, 10 do wmax = math.max(wmax, wfn(i / 10)) end
  pt:clip_begin(outline)
  local dark = tone(L * 0.7, 0.9)
  local pieces = B.broken(rng, offset_by(line, wfn, -0.22), wmax * 0.32, 0.3, 0.2)
  local cmds = {}
  for i, p in ipairs(pieces) do cmds[i] = B.polygon(p) end
  if #cmds > 0 then pt:fill(cmds, dark, 0.65 * cfg.stem_brush, MULT) end
  pieces = B.broken(rng, offset_by(line, wfn, 0.24), wmax * 0.16, 0.45, 0.3)
  cmds = {}
  for i, p in ipairs(pieces) do cmds[i] = B.polygon(p) end
  if #cmds > 0 then pt:fill(cmds, pal.white, 0.55 * cfg.stem_brush, { many = true }) end
  -- Lost stretches: the lit edge dissolves into the paper.
  pieces = B.broken(rng, offset_by(line, wfn, 0.5), wmax * 0.3, 0.75, 0)
  cmds = {}
  for i, p in ipairs(pieces) do cmds[i] = B.polygon(p) end
  if #cmds > 0 then pt:fill(cmds, pal.white, 0.6 * cfg.stem_brush, { many = true }) end
  pt:clip_end()
  pieces = B.broken(rng, offset_by(line, wfn, -0.5), math.max(0.25, wmax * 0.09), 0.2, 0)
  cmds = {}
  for i, p in ipairs(pieces) do cmds[i] = B.polygon(p) end
  if #cmds > 0 then pt:fill(cmds, pal.ink, 0.7 * cfg.stem_brush, MULT) end
end

return B
