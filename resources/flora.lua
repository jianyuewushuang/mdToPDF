-- flora.lua -- map Front Matter `flora-*` keys to tikzflora's \florasetup.
--
-- Why a Lua filter instead of plain template variables: pandoc LaTeX-escapes
-- metadata interpolated with $var$ (sun_crest -> sun\_crest), which breaks
-- tikzflora's key=value parser. RawBlock("latex", ...) is emitted verbatim,
-- the same mechanism resources/alerts.lua uses for its tcolorbox preamble.
--
-- This filter is only attached for the `tikzflora` style (declared via
-- LUA_FILTERS in resources/styles/tikzflora.conf), so other styles are
-- completely unaffected.
--
-- Every \florasetup key documented by tikzflora is supported. Map-like keys
-- are written as a plain "k=v, k=v" string in Front Matter and wrapped in
-- braces here; scalar keys are emitted as "key=value".
--
-- Defaults live in the template (resources/styles/tikzflora.latex); overrides
-- emitted here are appended later in the preamble, so they win (flora.setup
-- merges keys). The two per-page setups mirror example.tex's title/TOC pages.
--
-- Besides the raw LaTeX, Meta() also exposes template variables:
--   flora-centered       true when the effective global layout needs a centred
--                        text block; the template then picks symmetric margins.
--   flora-header         validated running-head text (falls back to $title$).
--   flora-title-<name>   one true flag for the chosen title-page layout, so
--                        the template can pick that layout's title block.
--   flora-backdrop-dark  true for backdrop=dark / #rrggbb (template sets the
--                        page colour); flora-backdrop-html is the HTML colour.
-- The template must decide geometry early in the preamble, before the
-- header-includes injected below, and doctemplates cannot compare strings,
-- so the layout decision is made here instead.

local SCALAR_KEYS = {
  { meta = "flora-layout",    key = "layout" },
  { meta = "flora-seed",      key = "seed" },
  { meta = "flora-density",   key = "density" },
  { meta = "flora-visitors",  key = "visitors" },
  { meta = "flora-colourway", key = "colourway" },
  { meta = "flora-spin",      key = "spin" },
  { meta = "flora-gilt",      key = "gilt" },
  { meta = "flora-giltdpi",   key = "giltdpi" },
  { meta = "flora-giltenv",   key = "giltenv" },
  { meta = "flora-cache",     key = "cache" },
}

local MAP_KEYS = {
  { meta = "flora-mix",       key = "mix" },
  { meta = "flora-palette",   key = "palette" },
  { meta = "flora-ornaments", key = "ornaments" },
  { meta = "flora-giltlook",  key = "giltlook" },
}

local MAX_LEN = 2048

-- Layouts whose text block must be centred on the page. `split`, `left` and
-- `right` keep tikzflora's original two-sided inner/outer margins; the
-- template defaults to split, so no variable is set unless one of these is
-- chosen explicitly. The four new title-page layouts all build symmetric
-- frames around W/2, so they belong here too. See lua/flora/frames.lua.
local CENTERED_LAYOUTS = {
  centered    = true,
  surround    = true,
  title       = true,
  flank       = true,
  wreath      = true,
  bouquet     = true,
  scrollwork  = true,
}
local DEFAULT_LAYOUT = "split"

-- Title-page layouts the template can typeset, mirroring example.tex (title)
-- and titles.tex (flank / wreath / bouquet / scrollwork).
local TITLE_LAYOUTS = { "title", "flank", "wreath", "bouquet", "scrollwork" }
local TITLE_LAYOUT_SET = {}
for _, name in ipairs(TITLE_LAYOUTS) do TITLE_LAYOUT_SET[name] = true end
local DEFAULT_TITLE_LAYOUT = "flank"

-- Characters that would either break \florasetup's detokenize/Lua parsing,
-- inject LaTeX commands, or corrupt the log. Underscores, commas, '=', '-',
-- '.' and spaces are intentionally allowed (they are key names / separators).
-- '#' is excluded here but permitted for flora-backdrop (#rrggbb) and the
-- flora-setup escape hatch; both are validated separately below.
local FORBIDDEN = '[\r\n"\\{}#%%$&^~<>|%c]'
local FORBIDDEN_ALLOW_HASH = '[\r\n"\\{}%%$&^~<>|%c]'

local function stringify(value)
  if type(value) == "string" then
    return value
  end
  if value == nil then
    return nil
  end
  local ok, text = pcall(pandoc.utils.stringify, value)
  if ok then
    return text
  end
  return nil
end

-- Returns a validated string, or nil when the key is absent. Aborts the build
-- with a message naming the offending key instead of silently emitting broken
-- LaTeX (fail-fast: a wrong style must never look like it worked).
local function read_key(meta, name, allow_braces, allow_hash)
  local value = meta[name]
  if value == nil then
    return nil
  end
  local text = stringify(value)
  if text == nil or text == "" then
    return nil
  end
  if #text > MAX_LEN then
    error(string.format(
      "flora.lua: Front Matter key '%s' is too long (%d chars, max %d)",
      name, #text, MAX_LEN), 0)
  end
  local forbidden = FORBIDDEN
  if allow_braces then
    -- flora-setup is a raw \florasetup argument, so it may contain {k=v,...}.
    forbidden = allow_hash and '[\r\n"\\%%$&^~<>|%c]'
      or '[\r\n"\\#%%$&^~<>|%c]'
  elseif allow_hash then
    forbidden = FORBIDDEN_ALLOW_HASH
  end
  if text:find(forbidden) then
    error(string.format(
      "flora.lua: Front Matter key '%s' contains unsupported characters. " ..
      "Write map-like values as a plain string, e.g. %s: 'k=v, k=v' " ..
      "(no braces, quotes, newlines or LaTeX commands).",
      name, name), 0)
  end
  return text
end

-- tikzflora accepts light, dark, or a dark #rrggbb (color.lua:86-94). Keep
-- the same shape here so an invalid value fails in Lua with a clear message
-- instead of producing a confusing tex.error from deep inside the package.
local function validate_backdrop(name, value)
  local v = value:lower()
  if v == "light" or v == "dark" then return v end
  if v:match("^#%x%x%x%x%x%x$") then return v end
  error(string.format(
    "flora.lua: '%s' must be light, dark or a dark colour as #rrggbb (got '%s')",
    name, value), 0)
end

-- A boolean-ish switch for \floraletters. Default is on (matching titles.tex).
local function validate_switch(name, value)
  local v = value:lower()
  if v == "true" or v == "yes" or v == "on" or v == "1" then return true end
  if v == "false" or v == "no" or v == "off" or v == "0" then return false end
  error(string.format(
    "flora.lua: '%s' must be true or false (got '%s')", name, value), 0)
end

-- The effective global layout. `flora-setup` is emitted after `flora-layout`
-- (both become \florasetup calls, and tikzflora merges keys), so a layout=
-- inside it wins. Per-page keys (flora-title-layout / flora-toc-layout) are
-- deliberately excluded: they only affect one shipped page.
local function effective_layout(layout_key, raw_setup)
  local function normalize(value)
    if type(value) ~= "string" then return nil end
    local v = value:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if v == "" then return nil end
    return v
  end

  local layout = normalize(layout_key)
  if raw_setup then
    local from_setup = raw_setup:match("layout%s*=%s*([%w_]+)")
    if from_setup then
      layout = normalize(from_setup)
    end
  end
  return layout or DEFAULT_LAYOUT
end

function Meta(meta)
  local parts = {}
  local layout_key

  for _, entry in ipairs(SCALAR_KEYS) do
    local value = read_key(meta, entry.meta, false)
    if entry.meta == "flora-layout" then
      layout_key = value
    end
    if value then
      parts[#parts + 1] = entry.key .. "=" .. value
    end
  end
  for _, entry in ipairs(MAP_KEYS) do
    local value = read_key(meta, entry.meta, false)
    if value then
      parts[#parts + 1] = entry.key .. "={" .. value .. "}"
    end
  end

  -- backdrop may contain '#', so it needs the relaxed validator and an
  -- explicit shape check matching tikzflora's color.lua.
  local backdrop_value
  local backdrop = read_key(meta, "flora-backdrop", false, true)
  if backdrop then
    backdrop_value = validate_backdrop("flora-backdrop", backdrop)
    parts[#parts + 1] = "backdrop=" .. backdrop_value
  end

  -- Escape hatch for tikzflora keys added in future releases: a raw
  -- \florasetup argument, e.g. flora-setup: 'layout=left, seed=9'.
  -- '#' is allowed so backdrop=#rrggbb can be used here too.
  local raw_setup = read_key(meta, "flora-setup", true, true)

  local title_layout = read_key(meta, "flora-title-layout", false)
    or DEFAULT_TITLE_LAYOUT
  title_layout = title_layout:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if not TITLE_LAYOUT_SET[title_layout] then
    error(string.format(
      "flora.lua: flora-title-layout must be one of %s (got '%s')",
      table.concat(TITLE_LAYOUTS, ", "), title_layout), 0)
  end

  -- example.tex weights the crest and tailpiece for title/flank; titles.tex
  -- leaves the other three layouts at tikzflora's default ornament weights.
  local title_ornaments = read_key(meta, "flora-title-ornaments", false)
  if not title_ornaments and (title_layout == "title" or title_layout == "flank") then
    title_ornaments = "sun_crest=6, cul_de_lampe=3"
  end
  local toc_layout = read_key(meta, "flora-toc-layout", false) or "surround"

  local letters_value = read_key(meta, "flora-title-letters", false)
  local letters_on = letters_value == nil
    or validate_switch("flora-title-letters", letters_value)

  -- Template variables. `nil` removes any stale value so $if(...)$ is false.
  if CENTERED_LAYOUTS[effective_layout(layout_key, raw_setup)] then
    meta["flora-centered"] = pandoc.MetaBool(true)
  else
    meta["flora-centered"] = nil
  end

  -- Exactly one title-layout flag is set; the template uses $elseif$ to pick
  -- that layout's own title block (example.tex / titles.tex).
  for _, name in ipairs(TITLE_LAYOUTS) do
    meta["flora-title-" .. name] = nil
  end
  meta["flora-title-" .. title_layout] = pandoc.MetaBool(true)

  -- A dark backdrop needs a matching page colour; tikzflora only recolours
  -- the flora itself (README settings table).
  if backdrop_value and backdrop_value ~= "light" then
    meta["flora-backdrop-dark"] = pandoc.MetaBool(true)
    meta["flora-backdrop-html"] = backdrop_value == "dark"
      and "0A1014" or backdrop_value:sub(2):upper()
  else
    meta["flora-backdrop-dark"] = nil
    meta["flora-backdrop-html"] = nil
  end

  -- Running-head text: validated like every other flora-* value, then handed
  -- to the template as a plain string (pandoc LaTeX-escapes $flora-header$).
  local header_text = read_key(meta, "flora-header", false)
  if header_text then
    meta["flora-header"] = header_text
  else
    meta["flora-header"] = nil
  end

  local latex = {
    "% flora.lua: Front Matter flora-* overrides (raw LaTeX, not escaped)",
  }
  if #parts > 0 then
    latex[#latex + 1] = "\\florasetup{" .. table.concat(parts, ", ") .. "}"
  end
  if raw_setup then
    latex[#latex + 1] = "\\florasetup{" .. raw_setup .. "}"
  end

  -- \floraTitleLine renders a display line with \floraletters (titles.tex),
  -- or as ordinary text when flora-title-letters is off. The template has a
  -- matching \providecommand fallback for documents built without this filter.
  latex[#latex + 1] = letters_on
    and "\\providecommand{\\floraTitleLine}[2][]{\\floraletters[#1]{#2}}"
    or "\\providecommand{\\floraTitleLine}[2][]{#2}"

  -- Per-page setups are macros so the template can call them at exactly the
  -- right point (before the title page / before the table of contents).
  -- \providecommand keeps a missing filter from breaking compilation: the
  -- template defines the same defaults with \providecommand later.
  local title_setup = "layout=" .. title_layout
  if title_ornaments then
    title_setup = title_setup .. ", ornaments={" .. title_ornaments .. "}"
  end
  latex[#latex + 1] = "\\providecommand{\\floraTitlePageSetup}{%"
  latex[#latex + 1] = "  \\florathispage{" .. title_setup .. "}%"
  latex[#latex + 1] = "}"
  latex[#latex + 1] = "\\providecommand{\\floraTocPageSetup}{%"
  latex[#latex + 1] = "  \\florathispage{layout=" .. toc_layout .. "}%"
  latex[#latex + 1] = "}"

  local raw = pandoc.RawBlock("latex", table.concat(latex, "\n") .. "\n")

  -- alerts.lua appends to header-includes too; keep whatever it created.
  local includes = meta["header-includes"]
  if includes == nil then
    meta["header-includes"] = pandoc.MetaList({ raw })
  elseif pandoc.utils.type(includes) == "List" then
    table.insert(includes, raw)
  else
    -- An Inlines value from Front Matter (e.g. header-includes: '\usepackage{x}'):
    -- promote it into a list so both preambles survive.
    meta["header-includes"] = pandoc.MetaList({ includes, raw })
  end

  return meta
end
