---@class Register

---@class VirtualCursorState
---@field lnum integer
---@field col integer
---@field curswant integer
---@field off? integer
---@field seq integer
---@field visual_start_lnum integer
---@field visual_start_col integer
---@field mark_id integer
---@field visual_start_mark_id integer
---@field visual_empty_line_mark_ids integer[]
---@field editable boolean
---@field delete boolean
---@field registers Register[]

---@class VirtualCursor : VirtualCursorState
local VirtualCursor = {
  ---@type VirtualCursorState
  prev_state = nil,
}

local common = require("multiple-cursors.common")

---@param lnum integer
---@param col integer
---@param visual_start_lnum integer
---@param visual_start_col integer
---@param seq integer
---@param off? integer
---@return VirtualCursor
function VirtualCursor.new(lnum, col, curswant, visual_start_lnum, visual_start_col, seq, off)
  local self = setmetatable({}, VirtualCursor)

  self.lnum = lnum
  self.col = col
  self.curswant = curswant
  self.off = off or 0

  self.seq = seq -- Sequence number to store the order that cursors were added
  -- When cursors are added with an up/down motion, at exit the
  -- real cursor is returned to the position of the oldest
  -- virtual cursor

  self.visual_start_lnum = visual_start_lnum -- lnum for the start of the visual area
  self.visual_start_col = visual_start_col -- col for the start of the visual area

  self.mark_id = 0 -- extmark ID
  self.visual_start_mark_id = 0 -- ID of the hidden extmark that stores the start of the visual area
  self.visual_multiline_mark_id = 0 -- ID of the visual area extmark then spans multiple lines
  self.visual_empty_line_mark_ids = {} -- IDs of the visual area extmarks for empty lines

  self.editable = true -- To disable editing the virtual cursor when
  -- in collision with the real cursor
  self.delete = false -- To mark the virtual cursor for deletion

  self.registers = {}

  -- local prev = vim.fn.deepcopy(self, true)
  ---@type VirtualCursorState
  self.prev_state = {
    col = self.col,
    curswant = self.curswant,
    delete = false,
    lnum = self.lnum,
    editable = true,
    registers = {},
    mark_id = 0,
    visual_empty_line_mark_ids = {},
    visual_start_col = self.visual_start_col,
    seq = self.seq,
    visual_start_lnum = self.visual_start_lnum,
    visual_start_mark_id = self.visual_start_mark_id,
    off = self.off,
  }
  return self
end

---@param self VirtualCursor
---@param key any
---@return integer
---@diagnostic disable-next-line:unused-local
VirtualCursor.__index = function(self, key) return VirtualCursor[key] end

--- Are cursors coincident?
---@param a VirtualCursor
---@param b VirtualCursor
---@return boolean
VirtualCursor.__eq = function(a, b) return a.lnum == b.lnum and a.col == b.col end

--- Is the visual area valid?
---@return boolean
function VirtualCursor:is_visual_area_valid()
  if self.visual_start_lnum == 0 or self.visual_start_col == 0 then return false end

  if self.visual_start_lnum > vim.fn.line("$") then return false end

  return true
end

--- Is the visual area defined in a forward direction?
---@return boolean
function VirtualCursor:is_visual_area_forward()
  if self.visual_start_lnum == self.lnum then
    return self.visual_start_col <= self.col
  else
    return self.visual_start_lnum <= self.lnum
  end
end

--- Get the positions of the visual area in a forward direction
--- offset is true when getting a visual area for creating extmarks
---@param offset? boolean # (false by default)
---@return integer lnum, integer col1, integer lnum2, integer col2
function VirtualCursor:get_normalised_visual_area(offset)
  -- offset is false by default
  offset = offset or false

  -- Get start and end positions for the extmarks representing the visual area
  local lnum1 = self.visual_start_lnum
  local col1 = self.visual_start_col
  local lnum2 = self.lnum
  local col2 = self.col

  if not self:is_visual_area_forward() then
    lnum1 = self.lnum
    col1 = self.col
    lnum2 = self.visual_start_lnum
    col2 = self.visual_start_col

    if offset then
      -- Add 1 to col2 to include the cursor position
      col2 = vim.fn.min({ col2 + 1, common.get_max_col(lnum2) })
    end
  end

  return lnum1, col1, lnum2, col2
end

-- Less than for sorting
VirtualCursor.__lt = function(a, b)
  -- If either visual area isn't valid
  if not a:is_visual_area_valid() or not b:is_visual_area_valid() then
    -- Compare cursor position
    if a.lnum == b.lnum then
      return a.col < b.col
    else
      return a.lnum < b.lnum
    end
  else -- Visual mode
    -- Normalise first
    local a_lnum, a_col = a:get_normalised_visual_area()
    local b_lnum, b_col = b:get_normalised_visual_area()

    -- Compare the normalised start
    if a_lnum == b_lnum then
      return a_col < b_col
    else
      return a_lnum < b_lnum
    end
  end
end

-- Save the real cursor position to the virtual cursor
function VirtualCursor:save_cursor_position()
  local pos = vim.fn.getcurpos()

  self.lnum = pos[2]
  self.col = pos[3]
  self.off = pos[4]
  self.curswant = pos[5]

  ---@type VirtualCursorState
  self.prev_state = {
    col = self.col,
    curswant = self.curswant,
    delete = self.delete,
    lnum = self.lnum,
    editable = self.editable,
    registers = self.registers,
    mark_id = self.mark_id,
    visual_empty_line_mark_ids = self.visual_empty_line_mark_ids,
    visual_start_col = self.visual_start_col,
    seq = self.seq,
    visual_start_lnum = self.visual_start_lnum,
    visual_start_mark_id = self.visual_start_mark_id,
    off = self.off,
  }
  -- self.prev_state = {}
end

-- Set the real cursor position from the virtual cursor
function VirtualCursor:set_cursor_position() vim.fn.cursor({ self.lnum, self.col, 0, self.curswant }) end

-- Save the current visual area to the virtual cursor
function VirtualCursor:save_visual_area()
  -- Save the current visual area start position
  local visual_start_pos = vim.fn.getpos("v")
  self.visual_start_lnum = visual_start_pos[2]
  self.visual_start_col = visual_start_pos[3]

  -- Save the cursor position
  self:save_cursor_position()
end

-- Set the visual area from the virtual cursor
function VirtualCursor:set_visual_area()
  common.set_visual_area(self.visual_start_lnum, self.visual_start_col, self.lnum, self.col)
end

-- Save the register to the virtual cursor
-- returns the number of lines saved
function VirtualCursor:save_register(register)
  local register_info = vim.fn.getreginfo(register)
  self.registers[register] = register_info
  return #register_info.regcontents
end

-- Does the virtual cursor have the register?
---@param register string
---@return boolean
function VirtualCursor:has_register(register) return self.registers[register] ~= nil end

-- Set the register from the virtual cursor
---@param register string
function VirtualCursor:set_register(register)
  local register_info = self.registers[register]

  if register_info then vim.fn.setreg(register, register_info) end
end

return VirtualCursor
