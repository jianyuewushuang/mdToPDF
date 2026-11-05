-- Entry points called from TeX.

local M = {}

-- Send a painted page to TeX. PGF code goes through TeX one chunk at a
-- time (each chunk begins with a control sequence, so concatenating them
-- without line ends is safe). A PDF content stream is held until TeX reaches
-- M.flush, which must run inside the picture, after the resource
-- registrations; it never passes through TeX's input.
function M.typeset(pt)
  for _, d in ipairs(pt.defs) do tex.sprint(d) end
  if pt.backend == "pdf" then
    M._pending = pt:body()
    tex.sprint("\\directlua{flora.flush()}")
  else
    for _, c in ipairs(pt.out) do tex.sprint(c) end
  end
  texio.write_nl("log", string.format("flora: %d painted objects", pt.count))
end

-- Write the held PDF content as one literal, in the same coordinate mode
-- PGF's own literals use, so it shares the picture's origin.
function M.flush()
  local n = node.new("whatsit", "pdf_literal")
  n.mode = 0
  n.data = M._pending or ""
  M._pending = nil
  node.write(n)
end

-- Settings from \florasetup (the document's) and \florathispage (the next
-- page shipped only); see settings.lua for the keys.
M.settings = {}
M.once = nil

local function report(err)
  tex.error("tikzflora: " .. tostring(err):gsub("^.-:%d+: ", ""))
end

function M.setup(s, once)
  local Settings = require("flora.settings")
  local ok, t = pcall(Settings.parse, s)
  if not ok then return report(t) end
  if once then
    M.once = Settings.merge(M.once, t)
  else
    M.settings = Settings.merge(M.settings, t)
  end
end

-- Leave a named mark at this point of the page (measure.lua).
function M.mark(name)
  require("flora.measure").mark(name)
end

function M.specimens(seed)
  local spec = require("flora.specimen")
  tex.sprint(string.format(
    "\\pgfpathrectangle{\\pgfpointorigin}{\\pgfqpoint{%dpt}{%dpt}}\\pgfusepath{use as bounding box}",
    spec.width, spec.height))
  M.typeset(spec.draw(seed))
end

-- The ornament gallery (gallery.lua): every kind for `seeds` seeds, each
-- labelled with its name and the key that weighs it. FLORA_GALLERY (slot
-- and kind names, comma-separated) limits the kinds and FLORA_GALLERY_SEEDS
-- overrides `seeds`.
function M.gallery(seeds)
  local only
  for name in (os.getenv("FLORA_GALLERY") or ""):gmatch("[%w_]+") do
    only = only or {}
    only[name] = true
  end
  seeds = tonumber(os.getenv("FLORA_GALLERY_SEEDS")) or tonumber(seeds) or 3
  local pt = require("flora.paint").new({ backend = os.getenv("FLORA_BACKEND"), gilt = M.settings.gilt })
  pt.gilt_dpi, pt.gilt_env, pt.gilt_look = M.settings.giltdpi, M.settings.giltenv, M.settings.giltlook
  local cells, w, h
  pt, cells, w, h = require("flora.gallery").sheet(pt, seeds, nil, nil, only)
  tex.sprint(string.format(
    "\\pgfpathrectangle{\\pgfpointorigin}{\\pgfqpoint{%.2fpt}{%.2fpt}}\\pgfusepath{use as bounding box}", w, h))
  M.typeset(pt)
  for _, c in ipairs(cells) do
    if c.seed == 1 then
      tex.sprint(string.format(
        "\\pgftext[left,base,at=\\pgfqpoint{%.2fpt}{%.2fpt}]{\\footnotesize %s \\texttt{\\color{gray}%s}}",
        c.box[1], c.box[4] + 5 + c.lift, c.label, (c.name:gsub("_", "\\_"))))
    end
  end
end

local function pt_of(s)
  return tonumber((tostring(s):gsub("pt$", "")))
end

-- The seed for a page: a fixed document seed varied by page number, or the
-- clock when the document asks for "random".
function M.seed(base, page)
  if base == "random" then
    M._clock = M._clock or os.time()
    base = M._clock
  end
  return (tonumber(base) or 1) * 7919 + page * 104729
end

-- Draw the flora for one page as a page-sized pgfpicture whose origin is the
-- lower-left corner of the paper. Dimensions arrive as TeX "<n>pt" strings.
--   a.width, a.height, a.text_x0, a.text_y0, a.text_x1, a.text_y1,
--   a.header_y, a.seed, a.page, a.box (the register holding the page,
--   whose ink is measured so flora can grow into space the text leaves),
--   and a.only (a page number; other pages are left bare)
--
-- With FLORA_SPEC_DIR set, each page's measured layout (everything but the
-- seed) is also written to <dir>/spec-<page>.lua, for tools/preview.lua.
function M.page(a)
  local dump = os.getenv("FLORA_SPEC_DIR")
  local skip = a.only and a.only ~= "" and tonumber(a.only) ~= a.page
  if skip and not (dump and dump ~= "") then return end
  local set = require("flora.settings").merge(M.settings, M.once)
  M.once = nil
  local lines, marks
  if a.box then lines, marks = require("flora.measure").boxes(a.box, pt_of(a.height)) end
  local spec = {
    width = pt_of(a.width), height = pt_of(a.height),
    text = { x0 = pt_of(a.text_x0), y0 = pt_of(a.text_y0), x1 = pt_of(a.text_x1), y1 = pt_of(a.text_y1) },
    header_y = a.header_y and pt_of(a.header_y),
    seed = M.seed(set.seed or a.seed, a.page),
    lines = lines, layout = set.layout, page = a.page, mix = set.mix, ornaments = set.ornaments, palette = set.palette, spin = set.spin,
    gilt = set.gilt, gilt_dpi = set.giltdpi, gilt_env = set.giltenv, gilt_look = set.giltlook,
    doc_seed = tostring(set.seed or a.seed),
  }
  if marks and marks["title-start"] and lines then
    spec.title = require("flora.frames").between(lines, marks["title-start"], marks["title-end"] or 0)
  end
  if dump and dump ~= "" then
    local f = assert(io.open(string.format("%s/spec-%d.lua", dump, a.page), "w"))
    local saved = {}
    for k, v in pairs(spec) do if k ~= "seed" then saved[k] = v end end
    f:write(require("flora.serial").encode(saved), "\n")
    f:close()
  end
  if skip then return end
  local pt = require("flora.compose").page(spec)
  tex.sprint("\\begin{pgfpicture}")
  tex.sprint(string.format(
    "\\pgfpathrectangle{\\pgfpointorigin}{\\pgfqpoint{%.2fpt}{%.2fpt}}\\pgfusepath{use as bounding box}",
    spec.width, spec.height))
  M.typeset(pt)
  tex.sprint("\\end{pgfpicture}")
  texio.write_nl("log", string.format("flora: page %d coverage %.2f", a.page, pt.coverage or 0))
end

return M
