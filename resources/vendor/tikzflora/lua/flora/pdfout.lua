-- Writes a painter's output as a standalone one-page PDF, without TeX. The
-- page holds the painted content alone, with the opacity states, gradient
-- patterns and images it registered (paint.lua, orn_raster.lua) as page
-- resources.

local Paint = require("flora.paint")

local M = {}
local BP = 72 / 72.27

local HEX = {}
for i = 0, 255 do HEX[string.char(i)] = string.format("%02x", i) end

-- A stream object: Flate-compressed where zlib exists (texlua has it),
-- else hex, so the PDF stays ASCII text (the site hands it to pdf.js as a
-- JavaScript string).
local function stream(attr, data)
  if zlib and zlib.compress then
    data = zlib.compress(data, 6)
    attr = attr .. " /Filter /FlateDecode"
  else
    data = data:gsub(".", HEX) .. ">"
    attr = attr .. " /Filter /ASCIIHexDecode"
  end
  return string.format("<< %s /Length %d >>\nstream\n%s\nendstream", attr, #data, data)
end

-- Painter `pt` as the bytes of a PDF page `width` x `height` pt (TeX
-- points).
function M.encode(pt, width, height)
  local res = Paint.resources()
  -- Objects: 1 catalog, 2 page tree, 3 page, 4 content, 5.. patterns.
  local objects = {}
  local gs, pats = {}, {}
  for _, g in ipairs(res.gs) do gs[#gs + 1] = string.format("/%s %s", g[1], g[2]) end
  for i, p in ipairs(res.patterns) do
    objects[4 + i] = p[2]
    pats[#pats + 1] = string.format("/%s %d 0 R", p[1], 4 + i)
  end
  -- Each image: its soft mask, then the image.
  local xobj = {}
  for _, x in ipairs(res.xobjects or {}) do
    local im, n = x.image, 4 + #res.patterns + 2 * #xobj
    local head = string.format("/Type /XObject /Subtype /Image /Width %d /Height %d /BitsPerComponent 8", im.w, im.h)
    objects[n + 1] = stream(head .. " /ColorSpace /DeviceGray", im.alpha)
    objects[n + 2] = stream(head .. string.format(" /ColorSpace /DeviceRGB /SMask %d 0 R", n + 1), im.rgb)
    xobj[#xobj + 1] = string.format("/%s %d 0 R", x[1], n + 2)
  end
  local content = pt:body()
  objects[1] = "<< /Type /Catalog /Pages 2 0 R >>"
  objects[2] = "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"
  objects[3] = string.format("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] "
    .. "/Resources << /ExtGState << %s >> /Pattern << %s >> /XObject << %s >> >> /Contents 4 0 R >>",
    width * BP, height * BP, table.concat(gs, " "), table.concat(pats, " "), table.concat(xobj, " "))
  objects[4] = string.format("<< /Length %d >>\nstream\n%s\nendstream", #content, content)

  local parts, pos = {}, 0
  local function put(s) parts[#parts + 1] = s; pos = pos + #s end
  put("%PDF-1.5\n")
  local offsets = {}
  for i = 1, #objects do
    offsets[i] = pos
    put(string.format("%d 0 obj\n%s\nendobj\n", i, objects[i]))
  end
  local xref = pos
  put(string.format("xref\n0 %d\n0000000000 65535 f \n", #objects + 1))
  for i = 1, #objects do put(string.format("%010d 00000 n \n", offsets[i])) end
  put(string.format("trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", #objects + 1, xref))
  return table.concat(parts)
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64 = {}
for i = 0, 63 do b64[i] = B64:sub(i + 1, i + 1) end

-- Image `im` (orn_raster.lua) as base64 RGBA, rows top down, for a canvas
-- ImageData.
local function rgba64(im)
  local rgb, a = im.rgb, im.alpha
  local out, buf, nb = {}, {}, 0
  local acc, bits = 0, 0
  local function put(v)
    acc, bits = (acc << 8) | v, bits + 8
    if bits == 24 then
      nb = nb + 4
      buf[nb - 3], buf[nb - 2] = b64[acc >> 18], b64[(acc >> 12) & 63]
      buf[nb - 1], buf[nb] = b64[(acc >> 6) & 63], b64[acc & 63]
      acc, bits = 0, 0
      if nb >= 4000 then out[#out + 1] = table.concat(buf, "", 1, nb) nb = 0 end
    end
  end
  for i = 1, #a do
    local r, g, b = rgb:byte(3 * i - 2, 3 * i)
    put(r) put(g) put(b) put(a:byte(i))
  end
  out[#out + 1] = table.concat(buf, "", 1, nb)
  if bits == 8 then
    out[#out + 1] = b64[acc >> 2] .. b64[(acc & 3) << 4] .. "=="
  elseif bits == 16 then
    out[#out + 1] = b64[acc >> 10] .. b64[(acc >> 4) & 63] .. b64[(acc & 15) << 2] .. "="
  end
  return table.concat(out)
end
M.rgba64 = rgba64

-- Painter `pt` as a scene for the site's canvas renderer
-- (site/src/lib/scene.js): JSON holding the page size in bp, the content
-- stream exactly as the PDF page carries it, and its resources as data —
-- each opacity state's ca, CA and blend mode, each pattern's axis (bp)
-- and colour stops, and each image's size and base64 RGBA pixels. The
-- canvas replays the same operators the PDF holds.
function M.scene(pt, width, height)
  local res = Paint.resources()
  local function num(v) return string.format("%.4f", v) end
  local gs, pats = {}, {}
  for _, g in ipairs(res.gs) do
    gs[#gs + 1] = string.format('"%s":[%s,%s,"%s"]', g[1], num(g.ca), num(g.CA), g.bm)
  end
  for _, p in ipairs(res.patterns) do
    local stops = {}
    for _, s in ipairs(p.stops) do
      stops[#stops + 1] = string.format("[%s,%s,%s,%s]", num(s[1]), num(s[2][1]), num(s[2][2]), num(s[2][3]))
    end
    local c = p.coords
    pats[#pats + 1] = string.format('"%s":{"coords":[%s,%s,%s,%s],"stops":[%s]}', p[1],
      num(c[1]), num(c[2]), num(c[3]), num(c[4]), table.concat(stops, ","))
  end
  local ims = {}
  for _, x in ipairs(res.xobjects or {}) do
    ims[#ims + 1] = string.format('"%s":{"w":%d,"h":%d,"rgba":"%s"}', x[1], x.image.w, x.image.h, rgba64(x.image))
  end
  local body = pt:body():gsub('[\\"]', "\\%0"):gsub("\n", "\\n")
  return string.format('{"width":%s,"height":%s,"gs":{%s},"patterns":{%s},"images":{%s},"content":"%s"}',
    num(width * BP), num(height * BP), table.concat(gs, ","), table.concat(pats, ","), table.concat(ims, ","), body)
end

-- Write painter `pt` to `path` as a PDF page `width` x `height` pt.
function M.write(path, pt, width, height)
  local fh = assert(io.open(path, "wb"))
  fh:write(M.encode(pt, width, height))
  fh:close()
end

return M
