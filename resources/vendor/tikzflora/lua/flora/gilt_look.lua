-- The looks of raster gilt (orn_raster.lua): tune.lua's gilt_looks holds
-- each look as a full set of named parameters. \florasetup{giltenv=...}
-- picks a look and giltlook={key=value, ...} changes single keys of it for
-- a document; this module checks those keys and resolves the set used.

local Tune = require("flora.tune")

local M = {}

-- Each numeric key: lowest and highest value, the tuner's slider step,
-- and the one look it belongs to (none: every look has it).
M.keys = {
  light = { 0, 360, 1 },
  eye = { 0.3, 3, 0.05 },
  relief = { 0, 1, 0.01 },
  cushion = { 0, 0.5, 0.01 },
  facet = { 0, 1, 0.01 },
  highlight = { 0, 1, 0.01 },
  highlight_size = { 0.01, 0.4, 0.005 },
  grain = { 0, 0.2, 0.005 },
  grain_scale = { 0.25, 4, 0.05 },
  sparkle = { 0, 40, 1 },
  sparkle_glint = { 0, 1, 0.01 },
  shadow = { 0, 1, 0.01 },
  shadow_offset = { 0, 3, 0.05 },
  horizon = { -0.5, 0.5, 0.005 },
  horizon_soft = { 0.005, 0.3, 0.005 },
  sky = { 0, 1, 0.01 },
  sky_glow = { 0, 0.6, 0.01 },
  ground = { 0, 0.8, 0.01 },
  horizon_dip = { 0, 0.6, 0.01, "studio" },
  sky_lit = { 0, 0.5, 0.01, "studio" },
  sky_far = { 0, 0.5, 0.01, "studio" },
  window = { 0, 0.6, 0.01, "studio" },
  window_top = { 0.2, 1, 0.01, "studio" },
  window_foot = { 0, 0.5, 0.01, "studio" },
  ground_fall = { 0, 0.5, 0.01, "studio" },
  ground_lit = { 0, 0.3, 0.01, "studio" },
  band = { 0, 0.6, 0.01, "mirror" },
  band_width = { 0.01, 0.3, 0.005, "mirror" },
  ground_far = { 0, 0.6, 0.01, "mirror" },
  front = { 0, 1, 0.01, "mirror" },
}

local function names(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out)
  return table.concat(out, ", ")
end

-- Check key k's value v (a string or number): the number, or nil and a
-- message naming the key.
function M.check(k, v)
  local r = M.keys[k]
  if not r then return nil, "no gilt look key \"" .. tostring(k) .. "\" (keys: " .. names(M.keys) .. ")" end
  local n = tonumber(v)
  if n and n >= r[1] and n <= r[2] then return n end
  return nil, string.format("%s must be a number from %g to %g", k, r[1], r[2])
end

-- The parameters of look `name` (a key of tune.lua's gilt_looks) with
-- keys `over` changed. Errors name a key that is out of range or that
-- the look does not have.
function M.resolve(name, over)
  local base = Tune.gilt_looks[name]
  if not base then error("no gilt look \"" .. tostring(name) .. "\" (looks: " .. names(Tune.gilt_looks) .. ")") end
  local L = base
  if over and next(over) then
    L = {}
    for k, v in pairs(base) do L[k] = v end
    for k, v in pairs(over) do
      local n, msg = M.check(k, v)
      if not n then error("giltlook: " .. msg) end
      if base[k] == nil then error(string.format("giltlook: %s belongs to the %s look, not %s", k, M.keys[k][4], name)) end
      L[k] = n
    end
  end
  if name == "studio" and L.window_foot >= L.window_top then
    error(string.format("giltlook: window_foot (%g) must be below window_top (%g)", L.window_foot, L.window_top))
  end
  return L
end

return M
