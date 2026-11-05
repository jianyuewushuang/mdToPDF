-- LuaTeX resolves `require` through kpathsea only. Register a searcher for
-- the generator's lua/ directory so it needs no installation. It is looked
-- for in $FLORA_LUA, then ./lua (the repository root or a project folder),
-- then beside tikzflora.sty wherever TeX found it (a texmf tree, or a
-- subfolder on TEXINPUTS).

local function dir_of(path)
  return path and path:match("^(.*)[/\\][^/\\]*$")
end

local roots = {}
if os.getenv("FLORA_LUA") then roots[#roots + 1] = os.getenv("FLORA_LUA") end
roots[#roots + 1] = "./lua"
local sty = dir_of(kpse.find_file("tikzflora.sty", "tex"))
if sty then roots[#roots + 1] = sty .. "/lua" end

table.insert(package.searchers, 2, function(name)
  local tried = {}
  for _, root in ipairs(roots) do
    local file = root .. "/" .. name:gsub("%.", "/") .. ".lua"
    local chunk, err = loadfile(file)
    if chunk then
      return chunk, file
    end
    if err and not err:find("No such file") and not err:find("cannot open") then
      error(err)
    end
    tried[#tried + 1] = "\n\tno file '" .. file .. "'"
  end
  return table.concat(tried)
end)

flora = require("flora.init")
