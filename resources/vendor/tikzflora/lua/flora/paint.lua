-- Paints flora as PDF content, by one of two backends:
--
--   "pdf" (default) writes PDF operators directly. The page's drawing goes
--   into the PDF as one literal node, so TeX never reads it; only the few
--   resource registrations (opacity states and gradient patterns) pass
--   through TeX, into PGF's own page-resource dictionaries. Coordinates are
--   converted from pt to bp, the unit PGF's pictures use in the PDF.
--
--   "pgf" emits PGF basic-layer code (the layer TikZ itself compiles to),
--   with quick path commands (\pgfpathq*) and a \pgfscope per object. TeX
--   expands every command, which is slow at tens of thousands of paths but
--   works with any PGF driver.
--
-- Either way each painted object is isolated (q/Q or \pgfscope), so colour,
-- opacity and blend state never leak.

local Tune = require("flora.tune")

local P = {}
P.__index = P

local fmt, concat = string.format, table.concat
local BP = 72 / 72.27   -- bp per pt

-- Ink, pigment and gilding used throughout. Values are sRGB 0-1.
P.palette = {
  paper  = { 0.976, 0.972, 0.955 },
  white  = { 0.995, 0.993, 0.985 },
  ink    = { 0.050, 0.105, 0.260 },  -- navy line work
  deep   = { 0.045, 0.125, 0.470 },  -- ultramarine, pooled
  blue   = { 0.080, 0.280, 0.780 },  -- ultramarine, open wash
  sky    = { 0.300, 0.470, 0.830 },  -- dilute wash
  mist   = { 0.780, 0.850, 0.950 },  -- ghost wash
  gold   = { 0.700, 0.560, 0.340 },
  copper = { 0.620, 0.330, 0.180 },
  cream  = { 0.960, 0.900, 0.760 },
}

-- Resources registered in this run, shared by every page: PGF writes its
-- resource dictionaries once, at the end of the document.
-- Each list keeps {name, PDF source} so a standalone writer can rebuild them.
local registered = { gs = {}, patterns = 0, gs_list = {}, pattern_list = {}, xobjects = {} }

-- Forget registered resources, as a new document would. Tests use it to
-- compare two renders of one page.
function P.reset_resources()
  registered = { gs = {}, patterns = 0, gs_list = {}, pattern_list = {}, xobjects = {} }
end

-- Every ExtGState, pattern and image registered since the last reset, as
-- {name, source} pairs (images: {name, image}, orn_raster.lua), for
-- writing a standalone PDF (tools/preview.lua).
function P.resources()
  return { gs = registered.gs_list, patterns = registered.pattern_list, xobjects = registered.xobjects }
end

-- Name image `entry` (a table) as XObject resource /flimgN, keep it in
-- P.resources().xobjects and return the name.
function P.register_xobject(entry)
  entry[1] = fmt("flimg%d", #registered.xobjects + 1)
  registered.xobjects[#registered.xobjects + 1] = entry
  return entry[1]
end

-- Write a PDF object; outside LuaTeX (unit tests) objects are only counted.
local function pdf_object(s)
  if pdf and pdf.immediateobj then return pdf.immediateobj(s) end
  registered.fake = (registered.fake or 0) + 1
  return registered.fake
end

function P.new(opts)
  return setmetatable({
    -- FLORA_BACKEND=pgf in the environment selects the PGF backend.
    backend = opts and opts.backend ~= "" and opts.backend or "pdf",
    defs = {},       -- TeX code run before the body: colours or resources
    named = {},      -- rgb key -> color name (pgf backend)
    out = {},        -- body chunks
    count = 0,       -- painted objects, for diagnostics
    boxes = {},      -- recorded extents of tagged groups
    group = nil,     -- the group currently collecting extents
    -- Gilt as "raster" computed gold (pdf only) or "vector" relief.
    gilt = opts and opts.gilt or Tune.gilt or "raster",
  }, P)
end

local function n2(v)
  local s = fmt("%.2f", v)
  if s == "-0.00" then s = "0.00" end
  return s
end

-- A coordinate as a TeX dimension (pgf) or a bp number (pdf).
local function d2(v)
  return n2(v) .. "pt"
end

local function b2(v)
  return n2(v * BP)
end

local function rgb3(c)
  return fmt("%.3f %.3f %.3f", c[1], c[2], c[3])
end

function P:color(rgb)
  local key = fmt("%.3f,%.3f,%.3f", rgb[1], rgb[2], rgb[3])
  local name = self.named[key]
  if not name then
    name = fmt("fl%d", #self.defs + 1)
    self.named[key] = name
    self.defs[#self.defs + 1] = fmt("\\definecolor{%s}{rgb}{%s}", name, key)
  end
  return name
end

-- The ExtGState name for fill opacity `ca`, stroke opacity `CA` and blend
-- mode `bm`, registered with PGF the first time it is used in this run.
function P:gstate(ca, CA, bm)
  local key = fmt("%s/%s/%s", n2(ca or 1), n2(CA or 1), bm or "Normal")
  local name = registered.gs[key]
  if not name then
    local n = 0
    for _ in pairs(registered.gs) do n = n + 1 end
    name = fmt("flgs%d", n + 1)
    registered.gs[key] = name
    local dict = fmt("<< /ca %s /CA %s /BM /%s >>", n2(ca or 1), n2(CA or 1), bm or "Normal")
    registered.gs_list[#registered.gs_list + 1] = { name, dict, ca = ca or 1, CA = CA or 1, bm = bm or "Normal" }
    self.defs[#self.defs + 1] = fmt("\\csname pgfutil@addpdfresource@extgs\\endcsname{/%s %s}", name, dict)
  end
  return name
end

-- Mix two palette colors (t = 0 gives a, 1 gives b).
function P.mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- Any paint flushes raster gilt collected before it (orn_raster.lua), so
-- the gold keeps its place in the painting order.
function P:emit(s)
  if self.gilt_pending then require("flora.orn_raster").flush(self) end
  self.out[#self.out + 1] = s
end

-- Track extents so tests can check where the flora landed.
function P:begin_group(tag)
  self.group = { tag = tag, x0 = math.huge, y0 = math.huge, x1 = -math.huge, y1 = -math.huge }
end

function P:end_group()
  local g = self.group
  if g and g.x0 <= g.x1 then
    self.boxes[#self.boxes + 1] = g
  end
  self.group = nil
end

-- Paint inside a clip cannot leave the clip path, which is itself recorded
-- when the clip begins, so clipped paint is not recorded again.
function P:_extend(x, y, pad)
  if (self.clips or 0) > 0 then return end
  if self.probe then self.probe(x, y, pad or 0, self.group and self.group.tag) end
  local g = self.group
  if not g then return end
  pad = pad or 0
  if x - pad < g.x0 then g.x0 = x - pad end
  if x + pad > g.x1 then g.x1 = x + pad end
  if y - pad < g.y0 then g.y0 = y - pad end
  if y + pad > g.y1 then g.y1 = y + pad end
end

-- Path operators per backend: move, line, curve, close.
local OPS = {
  pgf = {
    m = function(x, y) return fmt("\\pgfpathqmoveto{%s}{%s}", d2(x), d2(y)) end,
    l = function(x, y) return fmt("\\pgfpathqlineto{%s}{%s}", d2(x), d2(y)) end,
    c = function(a, b, c, d, e, f)
      return fmt("\\pgfpathqcurveto{%s}{%s}{%s}{%s}{%s}{%s}", d2(a), d2(b), d2(c), d2(d), d2(e), d2(f))
    end,
    z = "\\pgfpathclose",
  },
  -- One format call per operator: this is the hot path, at hundreds of
  -- thousands of coordinates per page. PDF reads "-0.00" as zero.
  pdf = {
    m = function(x, y) return fmt("%.2f %.2f m", x * BP, y * BP) end,
    l = function(x, y) return fmt("%.2f %.2f l", x * BP, y * BP) end,
    c = function(a, b, c, d, e, f)
      return fmt("%.2f %.2f %.2f %.2f %.2f %.2f c", a * BP, b * BP, c * BP, d * BP, e * BP, f * BP)
    end,
    z = "h",
  },
}

-- While a projection is set (P:project), every coordinate passes through
-- it before it is written or recorded.
function P.projected(cmds, pj)
  local K = 0.5523
  local out = {}
  for _, c in ipairs(cmds) do
    local op = c[1]
    if op == "m" or op == "l" then
      local x, y = pj(c[2], c[3])
      out[#out + 1] = { op, x, y }
    elseif op == "c" then
      local a, b = pj(c[2], c[3])
      local cc, d = pj(c[4], c[5])
      local e, f = pj(c[6], c[7])
      out[#out + 1] = { "c", a, b, cc, d, e, f }
    elseif op == "o" then
      -- A circle's four Bezier quarters, each control point projected.
      local x, y, r = c[2], c[3], c[4]
      local k = r * K
      local function q(px, py) local u, v = pj(px, py) return u, v end
      local mx, my = q(x + r, y)
      out[#out + 1] = { "m", mx, my }
      local arcs = {
        { x + r, y + k, x + k, y + r, x, y + r }, { x - k, y + r, x - r, y + k, x - r, y },
        { x - r, y - k, x - k, y - r, x, y - r }, { x + k, y - r, x + r, y - k, x + r, y },
      }
      for _, a in ipairs(arcs) do
        local a1, a2 = q(a[1], a[2])
        local a3, a4 = q(a[3], a[4])
        local a5, a6 = q(a[5], a[6])
        out[#out + 1] = { "c", a1, a2, a3, a4, a5, a6 }
      end
      out[#out + 1] = { "z" }
    else
      out[#out + 1] = c
    end
  end
  return out
end

-- Set (or with nil, clear) a projection fn(x, y) -> x, y applied to every
-- path and shading painted until it is cleared.
function P:project(fn)
  self.projection = fn
end

-- Set (or with nil, clear) the frame: a map fn(x, y) -> x, y from a layout
-- frame's own coordinates to the page's (frames.lua). It applies after any
-- projection, so elements that project themselves still land in the frame.
function P:frame(fn)
  self.frame_fn = fn
end

-- The map every coordinate passes through, or nil for none.
function P:_pj()
  local pj, fr = self.projection, self.frame_fn
  if pj and fr then
    return function(x, y) return fr(pj(x, y)) end
  end
  return pj or fr
end

-- Append the path commands for `cmds`; circles become four Bezier quarters.
function P:_path(cmds, buf)
  local K = 0.5523
  local ops = OPS[self.backend]
  local pj = self:_pj()
  if pj then cmds = P.projected(cmds, pj) end
  for _, c in ipairs(cmds) do
    local op = c[1]
    if op == "m" then
      buf[#buf + 1] = ops.m(c[2], c[3])
      self:_extend(c[2], c[3])
    elseif op == "l" then
      buf[#buf + 1] = ops.l(c[2], c[3])
      self:_extend(c[2], c[3])
    elseif op == "c" then
      buf[#buf + 1] = ops.c(c[2], c[3], c[4], c[5], c[6], c[7])
      self:_extend(c[6], c[7])
    elseif op == "z" then
      buf[#buf + 1] = ops.z
    elseif op == "o" then
      local x, y, r = c[2], c[3], c[4]
      local k = r * K
      buf[#buf + 1] = ops.m(x + r, y)
      buf[#buf + 1] = ops.c(x + r, y + k, x + k, y + r, x, y + r)
      buf[#buf + 1] = ops.c(x - k, y + r, x - r, y + k, x - r, y)
      buf[#buf + 1] = ops.c(x - r, y - k, x - k, y - r, x, y - r)
      buf[#buf + 1] = ops.c(x + k, y - r, x + r, y - k, x + r, y)
      buf[#buf + 1] = ops.z
      self:_extend(x, y, r)
    end
  end
end

local BLEND = { multiply = "Multiply", normal = "Normal", screen = "Screen" }

-- While `gilding` is set (ornaments.lua sets it round each ornament),
-- gold and copper fills and gold strokes are gilt rather than flat colour:
-- painted as burnished metal by orn_gild.lua. Washes (opacity under 0.5)
-- and blended ink keep their flat colour. A painter with `flat_gilt` set
-- paints all gilt flat, as before there was any.
local function gilt(self, rgb, opacity, opts)
  return self.gilding and not self.flat_gilt and (rgb == P.palette.gold or rgb == P.palette.copper)
    and (opacity or 1) >= 0.5 and not opts.blend
end

-- Fill one path, or a list of paths in a single scope (`many = true`).
function P:fill(cmds, rgb, opacity, opts)
  opts = opts or {}
  if gilt(self, rgb, opacity, opts) then
    self.gilding = false
    require("flora.orn_gild").fill(self, opts.many and cmds or { cmds }, { tone = rgb == P.palette.copper and "shade" or nil })
    self.gilding = true
    return
  end
  local pdf = self.backend == "pdf"
  local buf = { pdf and "q" or "\\pgfscope" }
  if pdf then
    local op = opacity and opacity < 1 and opacity or 1
    if op < 1 or opts.blend then
      buf[#buf + 1] = "/" .. self:gstate(op, 1, BLEND[opts.blend or "normal"]) .. " gs"
    end
    buf[#buf + 1] = rgb3(rgb) .. " rg"
  else
    if opts.blend then buf[#buf + 1] = fmt("\\pgfsetblendmode{%s}", opts.blend) end
    buf[#buf + 1] = fmt("\\pgfsetfillcolor{%s}", self:color(rgb))
    if opacity and opacity < 1 then
      buf[#buf + 1] = fmt("\\pgfsetfillopacity{%s}", n2(opacity))
    end
  end
  if opts.many then
    for _, c in ipairs(cmds) do self:_path(c, buf) end
  else
    self:_path(cmds, buf)
  end
  if pdf then
    buf[#buf + 1] = opts.evenodd and "f* Q" or "f Q"
  else
    buf[#buf + 1] = opts.evenodd and "\\pgfseteorule\\pgfusepathqfill" or "\\pgfusepathqfill"
    buf[#buf + 1] = "\\endpgfscope"
  end
  self:emit(concat(buf, pdf and " " or ""))
  self.count = self.count + 1
end

function P:stroke(cmds, rgb, width, opacity, opts)
  opts = opts or {}
  if rgb == P.palette.gold and gilt(self, rgb, opacity, opts) then
    self.gilding = false
    require("flora.orn_gild").line(self, opts.many and cmds or { cmds }, width)
    self.gilding = true
    return
  end
  local pdf = self.backend == "pdf"
  local buf = { pdf and "q" or "\\pgfscope" }
  if pdf then
    local op = opacity and opacity < 1 and opacity or 1
    if op < 1 or opts.blend then
      buf[#buf + 1] = "/" .. self:gstate(1, op, BLEND[opts.blend or "normal"]) .. " gs"
    end
    buf[#buf + 1] = rgb3(rgb) .. " RG " .. b2(width) .. " w 1 J 1 j"
  else
    if opts.blend then buf[#buf + 1] = fmt("\\pgfsetblendmode{%s}", opts.blend) end
    buf[#buf + 1] = fmt("\\pgfsetstrokecolor{%s}\\pgfsetlinewidth{%spt}", self:color(rgb), n2(width))
    buf[#buf + 1] = "\\pgfsetroundcap\\pgfsetroundjoin"
    if opacity and opacity < 1 then
      buf[#buf + 1] = fmt("\\pgfsetstrokeopacity{%s}", n2(opacity))
    end
  end
  if opts.many then
    for _, c in ipairs(cmds) do self:_path(c, buf) end
  else
    self:_path(cmds, buf)
  end
  buf[#buf + 1] = pdf and "S Q" or "\\pgfusepathqstroke\\endpgfscope"
  self:emit(concat(buf, pdf and " " or ""))
  self.count = self.count + 1
end

-- Declare a gradient once. `stops` lists {position 0-1, rgb}. For the pgf
-- backend this is a horizontal PGF shading spanning 100bp; for the pdf
-- backend the stops are kept and become a pattern when `shade` places them.
function P:shading(name, stops)
  self.shadings = self.shadings or {}
  if self.shadings[name] then return name end
  self.shadings[name] = stops
  if self.backend == "pgf" then
    local parts = {}
    for _, s in ipairs(stops) do
      parts[#parts + 1] = fmt("rgb(%sbp)=(%.3f,%.3f,%.3f)", n2(s[1] * 100), s[2][1], s[2][2], s[2][3])
    end
    self.defs[#self.defs + 1] = fmt("\\pgfdeclarehorizontalshading{%s}{100bp}{%s}", name, concat(parts, "; "))
  end
  return name
end

-- A PDF stitching function through `stops`, linear between them.
local function stitch(stops)
  local fns, bounds, enc = {}, {}, {}
  for i = 1, #stops - 1 do
    fns[#fns + 1] = fmt("<< /FunctionType 2 /Domain [0 1] /C0 [%s] /C1 [%s] /N 1 >>",
      rgb3(stops[i][2]), rgb3(stops[i + 1][2]))
    if i > 1 then bounds[#bounds + 1] = fmt("%.4f", stops[i][1]) end
    enc[#enc + 1] = "0 1"
  end
  return fmt("<< /FunctionType 3 /Domain [0 1] /Functions [%s] /Bounds [%s] /Encode [%s] >>",
    concat(fns, " "), concat(bounds, " "), concat(enc, " "))
end

-- Paint gradient `name` so its start lies at p0 and its end at p1, covering
-- `half` pt to either side of that axis. Use inside a clip.
function P:shade(name, p0, p1, half)
  local pj = self:_pj()
  if pj then
    local a, b = pj(p0[1], p0[2])
    local c, d = pj(p1[1], p1[2])
    p0, p1 = { a, b }, { c, d }
  end
  local dx, dy = p1[1] - p0[1], p1[2] - p0[2]
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.01 then return end
  if self.backend == "pgf" then
    -- \pgfuseshading centres the shading on the low-level origin and ignores
    -- PGF's soft transformations, so they are pushed to the low level first.
    self:emit(fmt("\\pgfscope\\pgftransformshift{\\pgfqpoint{%s}{%s}}\\pgftransformrotate{%s}"
      .. "\\pgftransformxscale{%s}\\pgftransformyscale{%s}\\pgflowlevelsynccm\\pgfuseshading{%s}\\endpgfscope",
      d2((p0[1] + p1[1]) / 2), d2((p0[2] + p1[2]) / 2), n2(math.deg(math.atan(dy, dx))),
      fmt("%.4f", len / 100.375), fmt("%.4f", 2 * half / 100.375), name))
  else
    -- An axial shading pattern. Pattern space is the page's default space,
    -- which is the picture's own: its origin is the paper's lower-left
    -- corner and its unit is the bp.
    registered.patterns = registered.patterns + 1
    local pname = fmt("flpat%d", registered.patterns)
    local src = fmt(
      "<< /PatternType 2 /Shading << /ShadingType 2 /ColorSpace /DeviceRGB /Coords [%s %s %s %s] "
        .. "/Function %s /Extend [true true] >> >>",
      b2(p0[1]), b2(p0[2]), b2(p1[1]), b2(p1[2]), stitch(self.shadings[name]))
    registered.pattern_list[#registered.pattern_list + 1] = {
      pname, src, coords = { p0[1] * BP, p0[2] * BP, p1[1] * BP, p1[2] * BP }, stops = self.shadings[name],
    }
    local obj = pdf_object(src)
    self.defs[#self.defs + 1] = fmt("\\csname pgfutil@addpdfresource@patterns\\endcsname{/%s %d 0 R}", pname, obj)
    -- Fill the band around the axis with the pattern.
    local ux, uy = dx / len, dy / len
    local nx, ny = -uy * half, ux * half
    local ext = len * 0.5
    local a = { p0[1] - ux * ext, p0[2] - uy * ext }
    local b = { p1[1] + ux * ext, p1[2] + uy * ext }
    self:emit(fmt("q /Pattern cs /%s scn %s %s m %s %s l %s %s l %s %s l h f Q", pname,
      b2(a[1] + nx), b2(a[2] + ny), b2(b[1] + nx), b2(b[2] + ny),
      b2(b[1] - nx), b2(b[2] - ny), b2(a[1] - nx), b2(a[2] - ny)))
  end
  self:_extend(p0[1], p0[2])
  self:_extend(p1[1], p1[2])
  self.count = self.count + 1
end

-- Everything painted until clip_end is clipped to `cmds`.
function P:clip_begin(cmds)
  local pdf = self.backend == "pdf"
  local buf = { pdf and "q" or "\\pgfscope" }
  self:_path(cmds, buf)
  buf[#buf + 1] = pdf and "W n" or "\\pgfusepathqclip"
  self:emit(concat(buf, pdf and " " or ""))
  self.clips = (self.clips or 0) + 1
end

function P:clip_end()
  self:emit(self.backend == "pdf" and "Q" or "\\endpgfscope")
  self.clips = self.clips - 1
end

-- A transparency group composites its contents first, so overlapping strokes
-- inside it do not stack their opacity. The pdf backend has no groups and
-- applies the opacity to each object instead.
function P:group_begin(opacity)
  if self.backend == "pdf" then
    self:emit(fmt("q /%s gs", self:gstate(opacity, opacity)))
    return
  end
  self:emit(fmt("\\pgfscope\\pgfsetfillopacity{%s}\\pgfsetstrokeopacity{%s}"
    .. "\\pgftransparencygroup", n2(opacity), n2(opacity)))
end

function P:group_end()
  self:emit(self.backend == "pdf" and "Q" or "\\endpgftransparencygroup\\endpgfscope")
end

-- TeX code to run before the body: colour definitions and shadings (pgf)
-- or resource registrations (pdf).
function P:tex_defs()
  return concat(self.defs, "\n")
end

-- The body: PGF code (pgf) or a PDF content stream (pdf).
function P:body()
  return concat(self.out, "\n")
end

function P:code()
  return self:tex_defs() .. "\n" .. self:body()
end

return P
