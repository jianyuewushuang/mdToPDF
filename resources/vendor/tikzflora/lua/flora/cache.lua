-- The page cache. A page's flora depends only on its measured layout and
-- settings (the spec init.lua builds), the tuning table and this code, so
-- each page's flora is written once as a one-page PDF (pdfout.lua) under
-- <output directory>/<jobname>-flora/, named by a hash of all four, and
-- embedded as the page's background. A later compile that asks for the
-- same page embeds the file again instead of growing it: LuaTeX copies an
-- embedded page's streams as they are, so a cached page costs neither
-- growing nor compressing. LaTeX documents are compiled two or three
-- times over, and an edit reflows only the pages after it, so most pages
-- of most compiles are found here.
--
-- index.lua in the folder lists each file's paint count and the layout
-- that last used it, a layout being the set of pages one run embedded.
-- It keeps the last KEEP distinct layouts; a file no kept layout used is
-- deleted. A run that embeds the same pages as the run before leaves the
-- index byte for byte as it was, so latexmk, which reruns LaTeX until the
-- files it read stop changing, settles as soon as the document does.

local Serial = require("flora.serial")

-- require passes a module the file it was loaded from.
local _, self_path = ...

local M = {}
local KEEP = 3

-- md5 of the generator's own source: every .lua file beside this one; nil
-- when this file's folder is unknown, which turns the cache off rather
-- than risk reusing pages drawn by other code.
local code
local function code_hash()
  if code ~= nil then return code or nil end
  local here = type(self_path) == "string" and self_path:match("^(.*)[/\\][^/\\]*$")
  if not (here and lfs.isdir(here)) then
    code = false
    return nil
  end
  local names = {}
  for name in lfs.dir(here) do
    if name:match("%.lua$") then names[#names + 1] = name end
  end
  table.sort(names)
  local parts = {}
  for _, name in ipairs(names) do
    local f = assert(io.open(here .. "/" .. name, "rb"))
    parts[#parts + 1] = name .. "\0" .. f:read("a")
    f:close()
  end
  code = md5.sumhexa(table.concat(parts, "\0"))
  return code
end

-- The folder, its index and this run's number, loaded on first use.
local state
local function load()
  if state then return state end
  local out = status.output_directory
  local dir = ((out and out ~= "") and out .. "/" or "") .. tex.jobname .. "-flora"
  if not lfs.isdir(dir) then lfs.mkdir(dir) end
  local index, text = { layouts = {}, entries = {} }, nil
  local f = io.open(dir .. "/index.lua", "rb")
  if f then
    text = f:read("a")
    f:close()
    local ok, t = pcall(Serial.decode, text)
    if ok and type(t) == "table" and type(t.entries) == "table" and type(t.layouts) == "table" then index = t end
  end
  state = { dir = dir, index = index, text = text, used = {}, ok = lfs.isdir(dir) }
  luatexbase.add_to_callback("finish_pdffile", M.finish, "flora.cache")
  return state
end

-- Write `data` to `path` whole or not at all: to a temporary file first,
-- renamed into place, so a compile stopped part way (a time limit, as on
-- Overleaf) leaves no half-written file. Returns true on success.
local function write_whole(path, data)
  local tmp = path .. ".tmp"
  local fh = io.open(tmp, "wb")
  if not fh then return false end
  local ok = fh:write(data)
  fh:close()
  if not ok then os.remove(tmp) return false end
  os.remove(path)
  return os.rename(tmp, path) and true or false
end

-- Save the index, unless it would be written exactly as it stands.
local function save_index(st)
  local text = Serial.encode(st.index) .. "\n"
  if text == st.text then return end
  if write_whole(st.dir .. "/index.lua", text) then st.text = text end
end

-- The key for a page: everything its flora depends on; nil when the
-- code cannot be identified.
function M.key(spec, set)
  local c = code_hash()
  return c and md5.sumhexa(Serial.encode({ spec = spec, set = set or {}, tune = require("flora.tune"), code = c }))
end

-- The cached file for `spec`, grown and written first when there is none
-- (compose.lua, at zlib `level`), its index entry {count, coverage}, and
-- whether it was found rather than grown.
-- Returns nil when the folder cannot be written; the caller then paints
-- the page itself. The index is saved after each page grown, so pages
-- finished by a compile that is stopped part way are found by the next.
function M.page(spec, set, level)
  local key = M.key(spec, set)
  if not key then return nil end
  local st = load()
  if not st.ok then return nil end
  local file = st.dir .. "/" .. key .. ".pdf"
  local e = st.index.entries[key]
  local hit = e and lfs.isfile(file)
  if not hit then
    local Paint, Pdf = require("flora.paint"), require("flora.pdfout")
    local bytes, pt = Paint.isolated(function()
      local p = require("flora.compose").page(spec)
      return Pdf.encode(p, spec.width, spec.height, level), p
    end)
    if not write_whole(file, bytes) then
      st.ok = false
      return nil
    end
    e = { count = pt.count, coverage = pt.coverage or 0 }
    st.index.entries[key] = e
    save_index(st)
  end
  st.used[key] = true
  return file, e, hit and true or false
end

-- At the end of the run: record this run's layout, drop entries no kept
-- layout used, delete every file the index no longer lists (and any left
-- half-written), and save the index if it changed.
function M.finish()
  local st = state
  if not st or not st.ok then return end
  local keys = {}
  for key in pairs(st.used) do keys[#keys + 1] = key end
  table.sort(keys)
  if #keys > 0 then
    local layout = md5.sumhexa(table.concat(keys, " "))
    local layouts = { layout }
    for _, l in ipairs(st.index.layouts) do
      if l ~= layout and #layouts < KEEP then layouts[#layouts + 1] = l end
    end
    st.index.layouts = layouts
    for _, key in ipairs(keys) do st.index.entries[key].layout = layout end
  end
  local kept = {}
  for _, l in ipairs(st.index.layouts) do kept[l] = true end
  local keep = {}
  for key, e in pairs(st.index.entries) do
    if kept[e.layout] then keep[key] = e end
  end
  st.index.entries = keep
  for name in lfs.dir(st.dir) do
    local key = name:match("^(%x+)%.pdf$")
    if (key and not keep[key]) or name:match("%.tmp$") then os.remove(st.dir .. "/" .. name) end
  end
  save_index(st)
end

return M
