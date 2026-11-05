-- Engraved display lettering for title pages, drawn from the font's own
-- outlines: \floraletters[style=shaded, arch=40, ink=tsuki-yo]{FLORA'S}.
-- The text is set in a box as usual, so kerning and ligatures are the
-- font's; each glyph's outline is then read from the font file
-- (luaotfload's shape reader) and painted in one of three engravers'
-- styles, optionally along an arc. The result takes the box's place.
--
--   style   outline   the letter drawn round, its face left paper
--           shaded    outlined, with a hatched shadow to the lower right
--                     (the default)
--           engraved  the face ruled with fine horizontal lines over a
--                     solid shadow
--   arch    the angle in degrees the baseline bends through: positive
--           arches it up in the middle, negative sags it; 0 (the
--           default) keeps it straight
--   ink     an iroshizuku ink by name (inks.lua) for the line work, or
--           black (the default)
--
-- Needs an OpenType or TrueType font (fontspec's, or LuaLaTeX's default
-- Latin Modern); with any other the text is left as set, with a warning.

local G = require("flora.geom")
local Inks = require("flora.inks")

local M = {}

M.styles = { outline = true, shaded = true, engraved = true }
M.style_order = { "outline", "shaded", "engraved" }
M.about = {
  outline = "The letter drawn round, its face left paper.",
  shaded = "Outlined, with a hatched shadow to the lower right. The default.",
  engraved = "The face ruled with fine horizontal lines over a solid shadow.",
}
M.ARCH = { -180, 180 }
local SP = 65536
local PAPER = { 0.995, 0.993, 0.985 }
local BLACK = { 0.11, 0.095, 0.085 }

-- The colour of the line work in `ink` (an iroshizuku ink name), or
-- black for nil.
function M.ink_rgb(ink)
  return ink and require("flora.color").ink_rgb(ink, 0.36) or BLACK
end

-- Parse and check the option list; returns the options or nil and an
-- error message.
function M.options(s)
  local o = { style = "shaded", arch = 0 }
  for item in (s or ""):gmatch("[^,]+") do
    local k, v = item:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if not k then return nil, "expected key=value, got \"" .. item:gsub("^%s+", "") .. "\"" end
    if k == "style" then
      if not M.styles[v] then return nil, "style must be one of outline, shaded, engraved" end
      o.style = v
    elseif k == "arch" then
      local n = tonumber(v)
      if not n or n < M.ARCH[1] or n > M.ARCH[2] then return nil, string.format("arch must be a number of degrees from %d to %d", M.ARCH[1], M.ARCH[2]) end
      o.arch = n
    elseif k == "ink" then
      if v ~= "black" and not Inks.ramps[v] then return nil, "ink must be black or an iroshizuku ink name, not " .. v end
      o.ink = v ~= "black" and v or nil
    else
      return nil, "unknown key " .. k .. " (style, arch, ink)"
    end
  end
  return o
end

-- Each font file's glyph outlines, read once.
local shapes = {}
local function outlines(filename)
  if shapes[filename] == nil then
    local R = fonts and fonts.handlers and fonts.handlers.otf and fonts.handlers.otf.readers
    local ok, s = pcall(function() return R and R.loadshapes and R.loadshapes(filename) end)
    shapes[filename] = ok and s and s.glyphs and s or false
  end
  return shapes[filename] or nil
end

-- The glyphs of hlist `b`, left to right: {font, char, x, y, w} in pt from
-- the box's reference point.
local function glyphs(b, x, y, out)
  local GLYPH, KERN, GLUE, HLIST, DISC = node.id("glyph"), node.id("kern"), node.id("glue"), node.id("hlist"), node.id("disc")
  for n in node.traverse(b.head) do
    if n.id == GLYPH then
      out[#out + 1] = { font = n.font, char = n.char, x = x + (n.xoffset or 0) / SP, y = y + (n.yoffset or 0) / SP, w = n.width / SP }
      x = x + n.width / SP
    elseif n.id == KERN then
      x = x + n.kern / SP
    elseif n.id == GLUE then
      x = x + (node.effective_glue(n, b) or 0) / SP
    elseif n.id == HLIST then
      glyphs(n, x, y - (n.shift or 0) / SP, out)
      x = x + n.width / SP
    elseif n.id == DISC and n.replace then
      x = x + node.dimensions(n.replace) / SP
    elseif n.width then
      x = x + n.width / SP
    end
  end
  return out
end

-- The paint commands of glyph `g` (glyphs) through map(x, y), or nil when
-- its font has no outlines to read.
local function glyph_path(g, map)
  local f = font.getfont(g.font)
  local sh = f and f.filename and outlines(f.filename)
  local ch = f and f.characters and f.characters[g.char]
  if not (sh and ch and ch.index) then return nil end
  local gl = sh.glyphs[ch.index]
  if not gl or not gl.segments then return {} end
  local k = f.size / SP / (sh.units or 1000)
  local function p(u, v) return map(g.x + u * k, g.y + v * k) end
  local cmds, cx, cy = {}, 0, 0
  for _, s in ipairs(gl.segments) do
    local op = s[#s]
    if op == "m" then
      if #cmds > 0 then cmds[#cmds + 1] = { "z" } end
      local x, y = p(s[1], s[2])
      cmds[#cmds + 1] = { "m", x, y }
      cx, cy = s[1], s[2]
    elseif op == "l" then
      local x, y = p(s[1], s[2])
      cmds[#cmds + 1] = { "l", x, y }
      cx, cy = s[1], s[2]
    elseif op == "c" then
      local a, b = p(s[1], s[2])
      local c, d = p(s[3], s[4])
      local e, h = p(s[5], s[6])
      cmds[#cmds + 1] = { "c", a, b, c, d, e, h }
      cx, cy = s[5], s[6]
    elseif op == "q" then
      -- A quadratic (TrueType) curve, raised to a cubic.
      local qx, qy, x, y = s[1], s[2], s[3], s[4]
      local a, b = p(cx + 2 / 3 * (qx - cx), cy + 2 / 3 * (qy - cy))
      local c, d = p(x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y))
      local e, h = p(x, y)
      cmds[#cmds + 1] = { "c", a, b, c, d, e, h }
      cx, cy = x, y
    end
  end
  if #cmds > 0 then cmds[#cmds + 1] = { "z" } end
  return cmds
end

-- The map placing a glyph centred at c along the baseline: straight, or
-- along an arc through `arch` degrees over the text's width L. Returns
-- map(x, y) for that glyph.
local function placer(L, arch, c)
  if math.abs(arch) < 0.01 then return function(x, y) return x, y end end
  local A = math.rad(arch)
  local R = L / A
  local phi = (c - L / 2) / R
  local px, py = L / 2 + R * math.sin(phi), R * math.cos(phi) - R * math.cos(A / 2)
  local cs, sn = math.cos(-phi), math.sin(-phi)
  return function(x, y)
    local u = x - c
    return px + u * cs - y * sn, py + u * sn + y * cs
  end
end

-- Hatching: lines at angle `ang`, `gap` apart, over box b, clipped to
-- `clip` (paint commands).
local function hatch(pt, clip, b, ang, gap, rgb, w)
  local cx, cy = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  local r = math.sqrt((b[3] - b[1]) ^ 2 + (b[4] - b[2]) ^ 2) / 2 + 1
  local ux, uy = math.cos(ang), math.sin(ang)
  local lines = {}
  for k = -r, r, gap do
    local mx, my = cx - uy * k, cy + ux * k
    lines[#lines + 1] = G.polyline({ { mx - ux * r, my - uy * r }, { mx + ux * r, my + uy * r } })
  end
  pt:clip_begin(clip)
  pt:stroke(lines, rgb, w, 1, { many = true })
  pt:clip_end()
end

local function shifted(cmds, dx, dy)
  local out = {}
  for i, c in ipairs(cmds) do
    if c[1] == "z" then
      out[i] = c
    else
      local d = { c[1] }
      for j = 2, #c, 2 do d[j], d[j + 1] = c[j] + dx, c[j + 1] + dy end
      out[i] = d
    end
  end
  return out
end

local function bounds(cmds, b)
  for _, c in ipairs(cmds) do
    for j = 2, #c, 2 do
      b[1], b[2] = math.min(b[1], c[j]), math.min(b[2], c[j + 1])
      b[3], b[4] = math.max(b[3], c[j]), math.max(b[4], c[j + 1])
    end
  end
  return b
end

-- Paint the lettering of hlist `box` onto pt. Returns the painted extent
-- {x0, y0, x1, y1} (pt, from the box's reference point), or nil when a
-- glyph's font has no readable outlines.
function M.paint(pt, box, o)
  local L = box.width / SP
  local gs = glyphs(box, 0, 0, {})
  local em = 0
  local face = {}
  for _, g in ipairs(gs) do
    local f = font.getfont(g.font)
    em = math.max(em, f and f.size / SP or 0)
    local cmds = glyph_path(g, placer(L, o.arch, g.x + g.w / 2))
    if not cmds then return nil end
    for _, c in ipairs(cmds) do face[#face + 1] = c end
  end
  if #face == 0 then return { 0, 0, L, 0 } end
  local ink = M.ink_rgb(o.ink)
  local b = bounds(face, { math.huge, math.huge, -math.huge, -math.huge })
  local lw = em * 0.02
  if o.style == "shaded" then
    local d = em * 0.05
    local shadow = shifted(face, d, -d)
    local sb = bounds(shadow, { b[1], b[2], b[3], b[4] })
    hatch(pt, shadow, sb, math.pi / 4, em * 0.032, ink, em * 0.011)
    pt:stroke(shadow, ink, lw * 0.5, 1)
    pt:fill(face, PAPER, 1)
    pt:stroke(face, ink, lw, 1)
    b = sb
  elseif o.style == "engraved" then
    local d = em * 0.03
    local shadow = shifted(face, d, -d)
    pt:fill(shadow, ink, 1)
    pt:fill(face, PAPER, 1)
    hatch(pt, face, b, 0, em * 0.038, ink, em * 0.013)
    pt:stroke(face, ink, lw * 0.9, 1)
    b = bounds(shadow, b)
  else
    pt:fill(face, PAPER, 1)
    pt:stroke(face, ink, lw * 1.1, 1)
  end
  local pad = lw
  return { b[1] - pad, b[2] - pad, b[3] + pad, b[4] + pad }
end

return M
