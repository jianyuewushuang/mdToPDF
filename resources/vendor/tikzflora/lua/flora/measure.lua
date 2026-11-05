-- Measures where ink sits on a page about to be shipped out.
--
-- Walks the page box's node list, tracking positions the way TeX lays them
-- out, and returns one box per hlist that directly holds glyphs or rules.
-- Boxes are in pt with the origin at the paper's lower-left corner.

local M = {}

local SP = 65536
local RUNNING = -1073741824  -- a rule dimension that stretches to its box
local ONE_INCH = 4736286

local id = node.id
local HLIST, VLIST, GLYPH, RULE = id("hlist"), id("vlist"), id("glyph"), id("rule")
local GLUE, KERN, MATH, DISC = id("glue"), id("kern"), id("math"), id("disc")
local WHATSIT, USER = id("whatsit"), node.subtype("user_defined")

-- user_id of the marks \begin{floratitle} and \end{floratitle} leave.
M.MARK_ID = 0x464c
-- The mark's name that makes its hlist count as ink, box and all.
M.INK = "ink"

-- Leave a named mark in the current list; M.boxes reports its height.
function M.mark(name)
  local n = node.new(WHATSIT, USER)
  -- One field at a time: setting the type resets the value, and a
  -- multiple assignment may set them in any order.
  n.user_id = M.MARK_ID
  n.type = 115
  n.value = name
  node.write(n)
end

local function is_mark(n)
  return n.id == WHATSIT and n.subtype == USER and n.user_id == M.MARK_ID
end

-- Width a node advances along an hlist.
local function advance(n, parent)
  local t = n.id
  if t == GLYPH or t == HLIST or t == VLIST or t == RULE then
    return n.width or 0
  elseif t == KERN then
    return n.kern
  elseif t == GLUE then
    return node.effective_glue(n, parent) or 0
  elseif t == MATH then
    return n.surround or 0
  elseif t == DISC and n.replace then
    return node.dimensions(n.replace)
  end
  return 0
end

local walk_v

-- Walk an hlist whose reference point is at (x, y); y grows downward.
local function walk_h(box, x, y, out)
  local x0, x1, top, bot
  local cx = x
  for n in node.traverse(box.head) do
    local t = n.id
    if t == GLYPH or (t == RULE and n.width ~= RUNNING) then
      local w, h, d = n.width, n.height or 0, n.depth or 0
      if t == RULE then
        if h == RUNNING then h = box.height end
        if d == RUNNING then d = box.depth end
      end
      if w > 0 and h + d > 0 then
        x0 = math.min(x0 or cx, cx)
        x1 = math.max(x1 or cx + w, cx + w)
        top = math.min(top or y - h, y - h)
        bot = math.max(bot or y + d, y + d)
      end
    elseif is_mark(n) and n.value == M.INK then
      -- A drawing that stands for text (\floraletters): its whole box is
      -- ink.
      out[#out + 1] = { x0 = x, x1 = x + box.width, top = y - box.height, bot = y + box.depth }
    elseif is_mark(n) then
      out.marks[n.value] = y
    elseif t == HLIST then
      walk_h(n, cx, y + (n.shift or 0), out)
    elseif t == VLIST then
      walk_v(n, cx, y + (n.shift or 0) - n.height, out)
    end
    cx = cx + advance(n, box)
  end
  if x0 then
    out[#out + 1] = { x0 = x0, x1 = x1, top = top, bot = bot }
  end
end

-- Walk a vlist whose top-left corner is at (x, top).
function walk_v(box, x, top, out)
  local cy = top
  for n in node.traverse(box.head) do
    local t = n.id
    if t == HLIST then
      cy = cy + n.height
      walk_h(n, x + (n.shift or 0), cy, out)
      cy = cy + n.depth
    elseif t == VLIST then
      walk_v(n, x + (n.shift or 0), cy, out)
      cy = cy + n.height + n.depth
    elseif t == RULE then
      local w = n.width == RUNNING and box.width or n.width
      if n.height + n.depth > 0 and w > 0 then
        out[#out + 1] = { x0 = x, x1 = x + w, top = cy, bot = cy + n.height + n.depth }
      end
      cy = cy + n.height + n.depth
    elseif t == GLUE then
      cy = cy + (node.effective_glue(n, box) or 0)
    elseif t == KERN then
      cy = cy + n.kern
    elseif is_mark(n) then
      out.marks[n.value] = cy
    end
  end
end

-- Ink boxes of box register `reg` as shipped on a page of height `paper_h`
-- (pt), and the heights of the marks on the page by name. TeX places the
-- box's top-left corner at (1in + \hoffset, 1in + \voffset) from the
-- paper's top-left corner.
function M.boxes(reg, paper_h)
  local b = tex.box[reg]
  if not b then return {}, {} end
  local ox = ONE_INCH + tex.hoffset
  local oy = ONE_INCH + tex.voffset
  local raw = { marks = {} }
  if b.id == VLIST then
    walk_v(b, 0, 0, raw)
  else
    walk_h(b, 0, b.height, raw)
  end
  local out = {}
  for _, r in ipairs(raw) do
    out[#out + 1] = {
      x0 = (ox + r.x0) / SP, x1 = (ox + r.x1) / SP,
      y0 = paper_h - (oy + r.bot) / SP, y1 = paper_h - (oy + r.top) / SP,
    }
  end
  local marks = {}
  for name, y in pairs(raw.marks) do marks[name] = paper_h - (oy + y) / SP end
  return out, marks
end

return M
