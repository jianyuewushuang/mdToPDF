-- Document settings from \florasetup and \florathispage: a key=value list,
-- parsed and checked here so mistakes are reported with the key's name.
--
--   layout    left, right, centered, split, title or surround (frames.lua)
--   seed      a number, or random
--   mix       weights per kind of growth, e.g. mix={lily=2, umbel=0}
--             (mix.lua lists the kinds)
--   density   how full the border grows (mix.density); below 1 is airier
--   visitors  the weight of every visitor at once (bee, butterfly, bird,
--             snail); mix={bee=0} after it still turns one off
--   palette   what paints each part, e.g. palette={leaves=green,
--             hero=kon-peki}: look, an ink group, one ink (inks.lua), or
--             random for one ink picked per page
--   colourway a whole palette at once: original, spring, summer, autumn
--             (or fall), winter, ember, plum or rose (inks.lua); a
--             palette={...} after it changes single parts
--   spin      a number that re-picks the random inks; the shapes stay
--   ornaments weights per ornament kind, e.g. ornaments={moon=2, night=0}
--             (ornaments.lua registers the kinds; each slot picks one)
--   gilt      how ornament gold is painted: vector or raster (tune.lua)
--   giltdpi   pixels per inch of raster gilt, 50 to 1200
--   giltenv   which look raster gilt takes: studio or mirror
--   giltlook  keys of that look changed, e.g. giltlook={horizon=0.1,
--             grain=0} (tune.lua's gilt_looks; gilt_look.lua lists the
--             keys and their ranges)

local M = {}

local Frames = require("flora.frames")
local Tune = require("flora.tune")
local Inks = require("flora.inks")
local Mix = require("flora.mix")
local Orn = require("flora.ornaments")
local Look = require("flora.gilt_look")

-- Key name -> function(value string) returning the parsed value, or nil
-- and a message.
local keys = {}

function M.define(name, parse)
  keys[name] = parse
end

M.define("layout", function(v)
  if Frames.layouts[v] then return v end
  return nil, "layout must be one of left, right, centered, split, title, surround"
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
