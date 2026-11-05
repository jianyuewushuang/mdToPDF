-- The page's mix: how much of each kind of growth a page gets, as weights
-- (1 = the usual amount, 0 = none, 2 = about twice as much). Set from
-- \florasetup{mix={lily=2, umbel=0}, density=0.8, visitors=1}; defaults in
-- tune.mix. With every weight at 1 a page is exactly the unmixed page.
--
--   bloom, soft, lily, ghost, umbel, cyme, gyps   motifs in the holes
--                                                 (grow.lua): weight and cap
--   leaves, leaflets                              spacing along the stems
--   feather, acanthus, lance                      how often a large leaf
--                                                 takes each shape (leaf.lua)
--   fan, round                                    how often a small bloom
--                                                 takes each style (flower.lua)
--   sprays, curls                                 the spray cap, curl chance
--   density                                       the gesture's density field,
--                                                 spacing and smallest hole
--   bee, butterfly, bird, snail                   visitors (visitor.lua)

local Tune = require("flora.tune")

local M = {}

M.motifs = { "bloom", "soft", "lily", "ghost", "umbel", "cyme", "gyps" }
M.visitors = { "bee", "butterfly", "bird", "snail" }
M.shapes = { "feather", "acanthus", "lance" }
M.styles = { "fan", "round" }

-- The weight of `kind` in `mix` (a table of overrides; nil for defaults).
function M.weight(mix, kind)
  local w = mix and mix[kind]
  if w == nil then w = Tune.mix[kind] end
  return w or 1
end

-- Is every growth weight at its neutral 1?
local function neutral(mix)
  for _, k in ipairs({ "leaves", "leaflets", "sprays", "curls", "density" }) do
    if M.weight(mix, k) ~= 1 then return false end
  end
  return true
end

local function scaled(range, k)
  return { range[1] * k, range[2] * k }
end

-- Tune.compose (`base`) adjusted by the mix's leaves, leaflets, sprays and
-- curls weights; `base` itself when they are all 1.
-- `c` with its caps on how much grows (large leaves, fine sprays, small
-- blooms, and the soft blooms, lilies and umbels, M.motif_cap) scaled by
-- `b`, for a plant longer than a page, which would otherwise run out of
-- growth part way along; `c` itself when b is nil or 1. Spacing is
-- unchanged, so a longer plant is as full as a page's, not fuller.
function M.budget(c, b)
  if b == nil or b == 1 then return c end
  local out = {}
  for k, v in pairs(c) do out[k] = v end
  local function r(n) return math.max(0, math.floor(n * b + 0.5)) end
  out.leaves, out.sprays, out.small_blooms, out.budget = r(c.leaves), r(c.sprays), r(c.small_blooms), b
  return out
end

-- A hole motif's cap `n` under cfg's budget (M.budget).
function M.motif_cap(n, c)
  if c.budget == nil then return n end
  return math.max(1, math.floor(n * c.budget + 0.5))
end

function M.cfg(base, mix)
  if neutral(mix) then return base end
  local c = {}
  for k, v in pairs(base) do c[k] = v end
  -- Density also widens the spacing of everything and the smallest hole
  -- worth filling, so a low density reads as airier, not just paler.
  local k = math.max(M.weight(mix, "density"), 0.05)
  c.hole_min = base.hole_min / k
  local w = M.weight(mix, "leaves")
  if w <= 0 then
    c.leaves = 0
  else
    c.leaf_spacing = scaled(base.leaf_spacing, 1 / (w * k))
    c.leaves = math.floor(base.leaves * math.max(1, w) + 0.5)
  end
  w = M.weight(mix, "leaflets")
  c.no_leaflets = w <= 0
  if w > 0 then c.leaflet_spacing = scaled(base.leaflet_spacing, 1 / (w * k)) end
  c.sprays = math.floor(base.sprays * M.weight(mix, "sprays") * math.min(1, k) + 0.5)
  c.curls = base.curls * M.weight(mix, "curls")
  return c
end

-- The density field `dens` scaled by the mix's density weight, or `dens`
-- itself at weight 1.
function M.density(dens, mix)
  local k = M.weight(mix, "density")
  if k == 1 then return dens end
  return function(x, y) return math.min(1, dens(x, y) * k) end
end

-- A hole motif with its weight and cap scaled by the mix, or nil when its
-- weight is 0. At weight 1 the motif is returned unchanged.
function M.motif(m, mix)
  local w = M.weight(mix, m.kind)
  if w == 1 then return m end
  if w <= 0 then return nil end
  local out = {}
  for k, v in pairs(m) do out[k] = v end
  out.w = m.w * w
  if m.cap then out.cap = math.max(1, math.floor(m.cap * w + 0.5)) end
  return out
end

-- `palette` with each "random" part replaced by one ink, drawn from its own
-- stream for page seed `seed` and colour spin `spin`. Shapes never draw
-- from that stream, and a single ink spends no shape randomness, so
-- spinning changes the colours and nothing else.
function M.resolve(palette, seed, spin)
  if not palette then return nil end
  local Rng = require("flora.rng")
  local order = require("flora.inks").order
  local out = {}
  for part, v in pairs(palette) do
    if v == "random" then
      local r = Rng.new((tonumber(seed) or 1) + (tonumber(spin) or 0) * 104723):fork("ink " .. part)
      v = order[r:int(1, #order)]
    end
    out[part] = v
  end
  return out
end

-- Run fn() with tune.color.palette overridden by `palette` (part -> ink,
-- group or "look"), restoring it afterwards even if fn fails.
function M.with_palette(palette, fn)
  if not palette or next(palette) == nil then return fn() end
  local cur = Tune.color.palette
  local tmp = {}
  for k, v in pairs(cur) do tmp[k] = v end
  for k, v in pairs(palette) do tmp[k] = v end
  Tune.color.palette = tmp
  local ok, res = pcall(fn)
  Tune.color.palette = cur
  if not ok then error(res, 0) end
  return res
end

-- The mix of the page being grown (M.with_mix), for choices made deep in
-- the drawing code, such as a leaf's shape; nil outside a page.
M.active = nil

-- Run fn() with `mix` as the active mix, then restore the previous one.
function M.with_mix(mix, fn)
  local prev = M.active
  M.active = mix
  local ok, res = pcall(fn)
  M.active = prev
  if not ok then error(res, 0) end
  return res
end

-- The active mix's weight for `kind` (1 outside a page).
function M.factor(kind)
  return M.weight(M.active, kind)
end

return M
