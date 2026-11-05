-- Colour in OKLCH. Ramps are generated per shape from the ranges in
-- tune.lua, so neighbouring petals and leaves differ in hue, depth and
-- saturation instead of repeating one gradient.

local Tune = require("flora.tune")
local Inks = require("flora.inks")

local C = {}
local cbrt = function(x) return x < 0 and -((-x) ^ (1 / 3)) or x ^ (1 / 3) end

local function encode(c)
  if c <= 0.0031308 then return 12.92 * c end
  return 1.055 * c ^ (1 / 2.4) - 0.055
end

-- OKLCH (hue in degrees) to unclipped linear sRGB.
local function linear(L, Ch, h)
  local a, b = Ch * math.cos(math.rad(h)), Ch * math.sin(math.rad(h))
  local l = (L + 0.3963377774 * a + 0.2158037573 * b) ^ 3
  local m = (L - 0.1055613458 * a - 0.0638541728 * b) ^ 3
  local s = (L - 0.0894841775 * a - 1.2914855480 * b) ^ 3
  return 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
end

local function in_gamut(L, Ch, h)
  local r, g, b = linear(L, Ch, h)
  local e = 1e-4
  return r >= -e and r <= 1 + e and g >= -e and g <= 1 + e and b >= -e and b <= 1 + e
end

-- The largest chroma at lightness L and hue h that sRGB can show.
function C.max_chroma(L, h)
  local lo, hi = 0, 0.4
  for _ = 1, 24 do
    local mid = (lo + hi) / 2
    if in_gamut(L, mid, h) then lo = mid else hi = mid end
  end
  return lo
end

-- OKLCH to gamma-encoded sRGB {r, g, b}, chroma reduced into gamut.
function C.oklch(L, Ch, h)
  Ch = math.min(Ch, C.max_chroma(L, h))
  local r, g, b = linear(L, Ch, h)
  local function clamp(v) return math.max(0, math.min(1, encode(math.max(0, v)))) end
  return { clamp(r), clamp(g), clamp(b) }
end

-- sRGB {r, g, b} to OKLab L, for tests and measurement.
function C.lightness(rgb)
  local function dec(c)
    if c <= 0.04045 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  local r, g, b = dec(rgb[1]), dec(rgb[2]), dec(rgb[3])
  local l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
  local m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
  local s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
  return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
end

-- sRGB {r, g, b} to OKLCH L, chroma and hue in degrees.
function C.lch(rgb)
  local function dec(c)
    if c <= 0.04045 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  local r, g, b = dec(rgb[1]), dec(rgb[2]), dec(rgb[3])
  local l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
  local m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
  local s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
  local L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
  local A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
  local B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
  return L, math.sqrt(A * A + B * B), math.deg(math.atan(B, A)) % 360
end

-- The backdrop `backdrop=dark` paints for: the near-black of a dark web page.
C.DARK_GROUND = C.oklch(0.17, 0.012, 230)

-- The colour {r, g, b} of backdrop setting `v` ("light", "dark" or
-- "#rrggbb"), or nil for light (white paper). Returns nil and a message
-- for anything else, or a colour too light to paint light ink over.
function C.backdrop(v)
  if v == nil or v == "light" then return nil end
  if v == "dark" then return C.DARK_GROUND end
  local r, g, b = tostring(v):lower():match("^#(%x%x)(%x%x)(%x%x)$")
  if not r then return nil, "backdrop must be light, dark or a colour as #rrggbb" end
  local rgb = { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 }
  if C.lightness(rgb) > 0.5 then return nil, "a backdrop colour must be dark; use light for pale paper" end
  return rgb
end

-- The lightness the darkest ink reaches on a dark ground.
local GLOW = 0.94
-- Under 1, pale tints are lifted further off the ground than a straight
-- turn-over puts them, since the eye tells dark tones apart less well.
local LIFT = 0.7

-- `rgb`, painted for paper `paper`, repainted for dark ground `ground`:
-- lightness turned over so the paper's own lightness lands on the
-- ground's and the darkest ink on GLOW, with hue and chroma kept, so a
-- dilute wash stays near the ground and a pooled one shines most.
function C.on_ground(rgb, ground, paper)
  local Lp = C.lightness(paper)
  local Lg = C.lightness(ground)
  local L, Ch, h = C.lch(rgb)
  local t = math.max(0, math.min(1, (Lp - L) / Lp)) ^ LIFT
  return C.oklch(Lg + t * (GLOW - Lg), Ch, h)
end

local function pick(rng, range) return rng:range(range[1], range[2]) end

-- Index of the most chromatic stop of each ink's ramp. Darker than that
-- stop the colour is held there: the densest strokes of some scans turn
-- off-hue (sheen), and dark stems would otherwise pick that up.
local richest = {}
for name, r in pairs(Inks.ramps) do
  local best, bi = -1, 1
  for i, s in ipairs(r) do
    local c = s[2] * s[2] + s[3] * s[3]
    if c > best then best, bi = c, i end
  end
  richest[name] = bi
end

-- The ink `name`'s colour where its wash has lightness L, as OKLCH chroma
-- and hue: its measured ramp interpolated by lightness from its richest
-- stop to its palest, held at either end beyond that.
function C.ink_at(name, L)
  local all = Inks.ramps[name]
  local r = { table.unpack(all, richest[name]) }
  local lo, hi = r[1], r[#r]
  local a, b
  if L <= lo[1] then
    a, b = lo[2], lo[3]
  elseif L >= hi[1] then
    a, b = hi[2], hi[3]
  else
    for i = 1, #r - 1 do
      local p, q = r[i], r[i + 1]
      if L >= p[1] and L <= q[1] then
        local t = (L - p[1]) / math.max(1e-9, q[1] - p[1])
        a, b = p[2] + (q[2] - p[2]) * t, p[3] + (q[3] - p[3]) * t
        break
      end
    end
  end
  return math.sqrt(a * a + b * b), math.deg(math.atan(b, a)) % 360
end

-- The ink a shape is painted with, for palette `choice` (a value of
-- tune.color.palette): nil for "look" (the look's own gradient), an ink
-- group's member picked with `rng`, or the named ink.
function C.ink_for(rng, choice)
  if not choice or choice == "look" then return nil end
  local g = Inks.groups[choice]
  if g then return g[rng:int(1, #g)] end
  if Inks.ramps[choice] then return choice end
  return nil
end

-- sRGB for ink `name` at lightness L, its chroma scaled by `share`.
function C.ink_rgb(name, L, share)
  local ch, h = C.ink_at(name, L)
  return C.oklch(L, ch * (share or 1), h)
end

-- Which tune.color.palette part a look paints by default.
local PART = { leaf = "leaves", hero = "hero", vivid = "blooms", fan = "blooms", soft = "blooms", ghost = "ghost" }

function C.part_of(look)
  return PART[look]
end

-- The one ink that recolours part `part`'s fixed pigments (rim pools,
-- florets, the cartouche), without spending randomness: the named ink, or
-- the first ink of a group. nil for "look" and for the blue group, whose
-- inks the fixed blue pigments already match.
function C.part_ink(part)
  local choice = part and Tune.color.palette and Tune.color.palette[part]
  if not choice or choice == "look" or choice == "blue" then return nil end
  if Inks.ramps[choice] then return choice end
  local g = Inks.groups[choice]
  return g and g[1] or nil
end

local BLUE = {}
for _, n in ipairs(Inks.groups.blue) do BLUE[n] = true end

-- `rgb` repainted in ink `ink` at the same lightness, or `rgb` itself when
-- there is no ink or the ink is one of the blues.
function C.recolor(rgb, ink)
  if not ink or BLUE[ink] then return rgb end
  return C.ink_rgb(ink, C.lightness(rgb), 1)
end

-- A base-to-tip ramp for one shape of look `look` ("vivid", "soft",
-- "ghost" or "leaf"). Lightness falls from base to tip along t^curve;
-- chroma is a fixed share of what sRGB allows at each step, so pale tones
-- stay blue rather than grey; hue drifts from cerulean at the base to the
-- shape's own hue at the tip. When tune.color.palette names an ink (or ink
-- group) for `part` (default: the look's own part), lightness still follows
-- the look but colour comes from the ink's measured ramp at each lightness,
-- so the hue and saturation shift as the ink thins, as a real wash does.
-- Returns the stops and a description {h, L = tip lightness, share} for
-- matching glazes.
function C.ramp(rng, look, part)
  local cfg = Tune.color
  local lk = cfg.looks[look] or cfg.looks.vivid
  local h = cfg.hue + rng:jit(cfg.hue_jitter)
  local base_l, tip_l = pick(rng, lk.base_l), pick(rng, lk.tip_l)
  local share, curve = pick(rng, lk.chroma), pick(rng, lk.curve)
  local grey = 1
  if look == "leaf" and rng:chance(cfg.grey_chance) then
    grey = cfg.grey_share
    share = share * cfg.grey_share
  end
  local stops = {}
  local n = 8
  local ink = C.ink_for(rng, cfg.palette and cfg.palette[part or PART[look]])
  if ink then
    for i = 0, n - 1 do
      local t = i / (n - 1)
      local L = base_l + (tip_l - base_l) * t ^ curve
      stops[#stops + 1] = { t, C.ink_rgb(ink, L, grey) }
    end
    local ch, ih = C.ink_at(ink, tip_l)
    return stops, { h = ih, L = tip_l, share = math.min(1, ch * grey / math.max(1e-6, C.max_chroma(tip_l, ih))), ink = ink }
  end
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local L = base_l + (tip_l - base_l) * t ^ curve
    local hh = h + cfg.hue_drift * (1 - t)
    local s = share * (0.55 + 0.45 * t)
    stops[#stops + 1] = { t, C.oklch(L, s * C.max_chroma(L, hh), hh) }
  end
  return stops, { h = h, L = tip_l, share = share }
end

return C
