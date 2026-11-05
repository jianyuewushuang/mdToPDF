-- Document settings from \florasetup and \florathispage: a key=value list,
-- parsed and checked here so mistakes are reported with the key's name.
-- M.about describes every key; the guide's table of settings is made
-- from it (catalog.lua).

local M = {}

local Frames = require("flora.frames")
local Tune = require("flora.tune")
local Inks = require("flora.inks")
local Mix = require("flora.mix")
local Orn = require("flora.ornaments")
local Look = require("flora.gilt_look")

-- Every key, in the order the guide lists them: {key, values, effect}.
M.about = {
  { "layout", "left, right, centered, split, title, surround, flank, wreath, bouquet, scrollwork",
    "Where the flora grows (see Layouts)." },
  { "seed", "a number, or random", "Which garden. Each page varies it, so pages differ." },
  { "mix", "{kind=weight, ...}, weights 0 to 10",
    "How much of each kind of growth, and how often each leaf shape and bloom style is drawn: 1 the usual amount, 0 none, 2 about twice as much." },
  { "density", "0 to 10", "How full the border grows: fuller above 1, airier below." },
  { "visitors", "0 to 10", "The weight of every visitor at once: bees, butterflies, birds and snails. mix={bee=0} after it still turns one off." },
  { "palette", "{part=ink, ...}",
    "What paints each part: look (the original blue gradients), an ink group, one iroshizuku ink by name, or random for one ink picked per page." },
  { "colourway", "original, spring, summer, autumn (or fall), winter, ember, plum, rose",
    "A whole palette at once. A palette={...} after it changes single parts." },
  { "spin", "a whole number", "Picks the random inks again. The shapes stay where they are." },
  { "ornaments", "{kind=weight, ...}, weights 0 to 10",
    "How often each ornament kind is picked for its place on the page, against the other kinds for that place: 0 never." },
  { "gilt", "raster, vector", "How ornament gold is painted: raster, gold computed per pixel; or vector, gold in relief built of flat strips." },
  { "giltdpi", "50 to 1200", "Pixels per inch of raster gilt." },
  { "giltenv", "studio, mirror", "Which look raster gilt takes (see Gilt)." },
  { "giltlook", "{key=value, ...}", "Changes keys of that look, such as giltlook={horizon=0.1, grain=0} (see Gilt)." },
  { "backdrop", "light, dark, or a dark colour as #rrggbb",
    "What the flora is painted over: light, white paper (the default); dark, a near-black page; or that colour. On a dark backdrop every ink is painted light, as if lit, and gold stays gold." },
  { "cache", "true, false",
    "true (the default) keeps each page's flora in a folder <jobname>-flora beside the PDF, so a later compile reuses it; false grows every page afresh." },
}

-- Key name -> function(value string) returning the parsed value, or nil
-- and a message.
local keys = {}

function M.define(name, parse)
  keys[name] = parse
end

-- The names of every defined key, sorted.
function M.defined()
  local out = {}
  for k in pairs(keys) do out[#out + 1] = k end
  table.sort(out)
  return out
end

M.define("layout", function(v)
  if Frames.layouts[v] then return v end
  return nil, "layout must be one of " .. table.concat(Frames.order, ", ")
end)

M.define("seed", function(v)
  if v == "random" or tonumber(v) then return v end
  return nil, "seed must be a number or random"
end)

local function weight(v)
  local n = tonumber(v)
  if n and n >= 0 and n <= 10 then return n end
end

local function known(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out)
  return table.concat(out, ", ")
end

M.define("density", function(v)
  local n = weight(v)
  if n then return n end
  return nil, "density must be a number from 0 to 10"
end)

-- A shorthand for every visitor's weight.
M.define("visitors", function(v)
  local n = weight(v)
  if n then return n end
  return nil, "visitors must be a number from 0 to 10"
end)

M.define("mix", function(v)
  local t = {}
  for _, kv in ipairs(M.parse_list(v)) do
    local k, w = kv[1], weight(kv[2])
    if Tune.mix[k] == nil then return nil, "no kind \"" .. k .. "\" (kinds: " .. known(Tune.mix) .. ")" end
    if not w then return nil, k .. " needs a weight from 0 to 10" end
    t[k] = w
  end
  return t
end)

M.define("ornaments", function(v)
  local t = {}
  for _, kv in ipairs(M.parse_list(v)) do
    local k, w = kv[1], weight(kv[2])
    if not Orn.kinds[k] then return nil, "no ornament \"" .. k .. "\" (kinds: " .. known(Orn.kinds) .. ")" end
    if not w then return nil, k .. " needs a weight from 0 to 10" end
    t[k] = w
  end
  return t
end)

M.define("cache", function(v)
  if v == "true" then return true end
  if v == "false" then return false end
  return nil, "cache must be true or false"
end)

M.define("backdrop", function(v)
  local rgb, msg = require("flora.color").backdrop(v)
  if rgb ~= nil or v == "light" then return v:lower() end
  return nil, msg
end)

M.define("gilt", function(v)
  if v == "vector" or v == "raster" then return v end
  return nil, "gilt must be vector or raster"
end)

M.define("giltdpi", function(v)
  local n = tonumber(v)
  if n and n >= 50 and n <= 1200 then return n end
  return nil, "giltdpi must be a number from 50 to 1200"
end)

M.define("giltenv", function(v)
  if v == "studio" or v == "mirror" then return v end
  return nil, "giltenv must be studio or mirror"
end)

M.define("giltlook", function(v)
  local t = {}
  for _, kv in ipairs(M.parse_list(v)) do
    local n, msg = Look.check(kv[1], kv[2])
    if not n then return nil, msg end
    t[kv[1]] = n
  end
  return t
end)

M.define("palette", function(v)
  local t = {}
  for _, kv in ipairs(M.parse_list(v)) do
    local part, ink = kv[1], kv[2]
    if Tune.color.palette[part] == nil then
      return nil, "no part \"" .. part .. "\" (parts: " .. known(Tune.color.palette) .. ")"
    end
    if not (ink == "look" or ink == "random" or Inks.groups[ink] or Inks.ramps[ink]) then
      return nil, "\"" .. tostring(ink) .. "\" is not look, random, an ink group or an ink name"
    end
    t[part] = ink
  end
  return t
end)

M.define("colourway", function(v)
  v = Inks.colourway_alias[v] or v
  local src = v == "original" and Tune.color.palette or Inks.colourways[v]
  if not src then return nil, "colourway must be one of " .. table.concat(Inks.colourway_order, ", ") end
  local t = {}
  for part in pairs(Tune.color.palette) do t[part] = src[part] or Tune.color.palette[part] end
  return t
end)

M.define("spin", function(v)
  local n = tonumber(v)
  if n and n == math.floor(n) and n >= 0 then return n end
  return nil, "spin must be a whole number"
end)

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Split "a=1, b={x=2, y=3}" at top-level commas into {name, value} pairs;
-- braces around a value are removed. A key without "=" has value nil.
function M.parse_list(s)
  local out, depth, start = {}, 0, 1
  local function take(piece)
    piece = trim(piece)
    if piece == "" then return end
    local k, v = piece:match("^([^=]-)%s*=%s*(.*)$")
    if not k then
      out[#out + 1] = { trim(piece), nil }
      return
    end
    v = trim(v)
    local inner = v:match("^{(.*)}$")
    out[#out + 1] = { trim(k), inner and trim(inner) or v }
  end
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch == "{" then depth = depth + 1
    elseif ch == "}" then depth = depth - 1
      if depth < 0 then error("unbalanced braces in \"" .. s .. "\"") end
    elseif ch == "," and depth == 0 then
      take(s:sub(start, i - 1))
      start = i + 1
    end
  end
  if depth ~= 0 then error("unbalanced braces in \"" .. s .. "\"") end
  take(s:sub(start))
  return out
end

-- Parse a key=value list into a settings table. Errors name the key.
function M.parse(s)
  local t = {}
  for _, kv in ipairs(M.parse_list(s)) do
    local k, v = kv[1], kv[2]
    local parse = keys[k]
    if not parse then
      local known = {}
      for name in pairs(keys) do known[#known + 1] = name end
      table.sort(known)
      error(string.format("unknown key \"%s\" (known keys: %s)", k, table.concat(known, ", ")))
    end
    if v == nil then error(string.format("key \"%s\" needs a value", k)) end
    local val, msg = parse(v)
    if val == nil then error(string.format("%s: %s (got \"%s\")", k, msg, v)) end
    if k == "density" then
      t.mix = M.merge({ mix = t.mix }, { mix = { density = val } }).mix
    elseif k == "colourway" then
      t.palette = M.merge({ palette = t.palette }, { palette = val }).palette
    elseif k == "visitors" then
      local m = {}
      for _, name in ipairs(Mix.visitors) do m[name] = val end
      t.mix = M.merge({ mix = t.mix }, { mix = m }).mix
    else
      t[k] = M.merge({ [k] = t[k] }, { [k] = val })[k]
    end
  end
  return t
end

-- Merge settings table `over` onto `base`, returning a new table. Table
-- values (such as mix) merge key by key.
function M.merge(base, over)
  local t = {}
  for k, v in pairs(base or {}) do t[k] = v end
  for k, v in pairs(over or {}) do
    if type(v) == "table" and type(t[k]) == "table" then
      local m = {}
      for a, b in pairs(t[k]) do m[a] = b end
      for a, b in pairs(v) do m[a] = b end
      t[k] = m
    else
      t[k] = v
    end
  end
  return t
end

return M
