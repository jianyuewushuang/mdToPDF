-- Every option the package offers, as data read from the modules that
-- define them: the settings (settings.lua), layouts (frames.lua), the
-- mix's kinds, leaf shapes and bloom styles (mix.lua, tune.lua's docs),
-- ornaments by place (ornaments.lua), palette parts, inks and colourways
-- (inks.lua), the gilt looks and their keys (gilt_look.lua) and the
-- lettering's styles and inks (letters.lua). The site's mixer and the
-- guide's reference are made from it, so they list what the code accepts.

local Tune = require("flora.tune")

local M = {}

local function doc(path)
  local d = Tune._doc[path] or {}
  return d[1] or path, d[2] or ""
end

local function hex(rgb)
  local function b(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
  return string.format("#%02x%02x%02x", b(rgb[1]), b(rgb[2]), b(rgb[3]))
end

-- The mix's kinds in the groups the mixer shows them.
M.mix_groups = {
  { "Blooms", { "bloom", "soft", "lily", "ghost", "umbel" } },
  { "Sprays and foliage", { "cyme", "gyps", "sprays", "curls", "leaves", "leaflets" } },
  { "Leaf shapes", { "feather", "acanthus", "lance" } },
  { "Bloom styles", { "fan", "round" } },
  { "Visitors", { "bee", "butterfly", "bird", "snail" } },
  { "Overall", { "density" } },
}

function M.build()
  local Settings = require("flora.settings")
  local Frames = require("flora.frames")
  local Inks = require("flora.inks")
  local Orn = require("flora.ornaments")
  local Look = require("flora.gilt_look")
  local Letters = require("flora.letters")
  local Mix = require("flora.mix")
  local c = {}

  c.settings = {}
  for _, a in ipairs(Settings.about) do c.settings[#c.settings + 1] = { key = a[1], values = a[2], about = a[3] } end

  c.layouts = {}
  for _, k in ipairs(Frames.order) do c.layouts[#c.layouts + 1] = { name = k, about = Frames.about[k] } end

  c.mix = {}
  for _, g in ipairs(M.mix_groups) do
    local kinds = {}
    for _, k in ipairs(g[2]) do
      local label, about = doc("mix." .. k)
      kinds[#kinds + 1] = { key = k, label = label, about = about, default = Mix.weight(nil, k) }
    end
    c.mix[#c.mix + 1] = { group = g[1], kinds = kinds }
  end

  c.ornaments = {}
  for _, slot in ipairs(Orn.slot_order) do
    local s, kinds = Orn.slots[slot], {}
    for _, k in ipairs(Orn.of(slot)) do kinds[#kinds + 1] = { key = k.name, label = k.label, default = Orn.weight(nil, k.name) } end
    c.ornaments[#c.ornaments + 1] = { slot = slot, label = s.label, about = s.desc, kinds = kinds }
  end

  c.parts = {}
  for _, p in ipairs({ "hero", "blooms", "leaves", "leaflets", "stems", "sprays", "ghost", "cartouche" }) do
    c.parts[#c.parts + 1] = { key = p, default = Tune.color.palette[p] }
  end
  c.ink_groups = {}
  for _, g in ipairs(Inks.group_order) do c.ink_groups[#c.ink_groups + 1] = { name = g, inks = Inks.groups[g] } end
  c.inks = Inks.order
  c.colourways = {}
  for _, name in ipairs(Inks.colourway_order) do
    c.colourways[#c.colourways + 1] = { name = name, inks = Inks.colourways[name] or {} }
  end

  local keys = {}
  for k in pairs(Look.keys) do keys[#keys + 1] = k end
  table.sort(keys)
  c.gilt = { modes = { "raster", "vector" }, default = Tune.gilt, env = Tune.gilt_env,
    dpi = { 50, 1200, Tune.gilt_dpi }, looks = {}, keys = {} }
  for _, name in ipairs({ "studio", "mirror" }) do
    local label, about = doc("gilt_looks." .. name)
    c.gilt.looks[#c.gilt.looks + 1] = { name = name, label = label, about = about }
  end
  for _, k in ipairs(keys) do
    local r = Look.keys[k]
    local label, about = doc(k)
    local defaults = {}
    for _, look in ipairs({ "studio", "mirror" }) do defaults[look] = Tune.gilt_looks[look][k] end
    c.gilt.keys[#c.gilt.keys + 1] = { key = k, label = label, about = about, min = r[1], max = r[2], step = r[3],
      look = r[4], defaults = defaults }
  end

  c.backdrop = { default = "light", dark = hex(require("flora.color").DARK_GROUND) }

  c.letters = { styles = {}, default = "shaded", arch = Letters.ARCH, inks = { black = hex(Letters.ink_rgb(nil)) } }
  for _, s in ipairs(Letters.style_order) do c.letters.styles[#c.letters.styles + 1] = { name = s, about = Letters.about[s] } end
  for _, n in ipairs(Inks.order) do c.letters.inks[n] = hex(Letters.ink_rgb(n)) end
  return c
end

-- `v` as JSON: tables with a sequence part as arrays (an empty table is
-- an object), the rest as objects with sorted keys.
function M.json(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return tostring(v) end
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if math.type(v) == "integer" then return tostring(v) end
    return string.format("%.10g", v)
  end
  if t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(ch)
      local esc = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t" }
      return esc[ch] or string.format("\\u%04x", ch:byte())
    end) .. '"'
  end
  assert(t == "table", "cannot write a " .. t .. " as JSON")
  if #v > 0 then
    local out = {}
    for i = 1, #v do out[i] = M.json(v[i]) end
    return "[" .. table.concat(out, ",") .. "]"
  end
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = tostring(k) end
  table.sort(ks)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = M.json(k) .. ":" .. M.json(v[k]) end
  return "{" .. table.concat(out, ",") .. "}"
end

return M
