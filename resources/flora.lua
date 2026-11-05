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
}

local MAP_KEYS = {
  { meta = "flora-mix",       key = "mix" },
  { meta = "flora-palette",   key = "palette" },
  { meta = "flora-ornaments", key = "ornaments" },
  { meta = "flora-giltlook",  key = "giltlook" },
}

local MAX_LEN = 2048

-- Characters that would either break \florasetup's detokenize/Lua parsing,
-- inject LaTeX commands, or corrupt the log. Underscores, commas, '=', '-',
-- '.' and spaces are intentionally allowed (they are key names / separators).
local FORBIDDEN = '[\r\n"\\{}#%%$&^~<>|%c]'

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
local function read_key(meta, name, allow_braces)
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
    forbidden = '[\r\n"\\#%%$&^~<>|%c]'
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

function Meta(meta)
  local parts = {}

  for _, entry in ipairs(SCALAR_KEYS) do
    local value = read_key(meta, entry.meta, false)
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

  -- Escape hatch for tikzflora keys added in future releases: a raw
  -- \florasetup argument, e.g. flora-setup: 'layout=left, seed=9'.
  local raw_setup = read_key(meta, "flora-setup", true)

  local title_layout = read_key(meta, "flora-title-layout", false) or "title"
  local title_ornaments = read_key(meta, "flora-title-ornaments", false)
    or "sun_crest=6, cul_de_lampe=3"
  local toc_layout = read_key(meta, "flora-toc-layout", false) or "surround"

  local latex = {
    "% flora.lua: Front Matter flora-* overrides (raw LaTeX, not escaped)",
  }
  if #parts > 0 then
    latex[#latex + 1] = "\\florasetup{" .. table.concat(parts, ", ") .. "}"
  end
  if raw_setup then
    latex[#latex + 1] = "\\florasetup{" .. raw_setup .. "}"
  end

  -- Per-page setups are macros so the template can call them at exactly the
  -- right point (before the title page / before the table of contents).
  -- \providecommand keeps a missing filter from breaking compilation: the
  -- template defines the same defaults with \providecommand later.
  latex[#latex + 1] = "\\providecommand{\\floraTitlePageSetup}{%"
  latex[#latex + 1] = "  \\florathispage{layout=" .. title_layout
    .. ", ornaments={" .. title_ornaments .. "}}%"
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
