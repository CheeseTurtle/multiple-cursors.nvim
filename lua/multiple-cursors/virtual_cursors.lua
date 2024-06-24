local M = {}

local common = require("multiple-cursors.common")
local extmarks = require("multiple-cursors.extmarks")
local behavior = require "multiple-cursors.behavior"

local VirtualCursor = require("multiple-cursors.virtual_cursor")

--- A table of the virtual cursors
---@type VirtualCursor[]
local virtual_cursors = {}

local next_seq = 1

-- Set to true when the cursor is being moved to suppress M.cursor_moved()
local ignore_cursor_movement = false

-- For locking the virtual cursors
local locked = false

-- Remove any virtual cursors marked for deletion
local function clean_up()
  for idx = #virtual_cursors, 1, -1 do
    if virtual_cursors[idx].delete then
      extmarks.delete_virtual_cursor_extmarks(virtual_cursors[idx])
      table.remove(virtual_cursors, idx)
    end
  end
end

--- Check for and solve any collisions between virtual cursors
--- The virtual cursor with the higher mark ID is removed
---@return nil
local function check_for_collisions()
  if #virtual_cursors < 2 then return end

  for idx1 = 1, #virtual_cursors - 1 do
    for idx2 = idx1 + 1, #virtual_cursors do
      if virtual_cursors[idx1] == virtual_cursors[idx2] then virtual_cursors[idx2].delete = true end
    end
  end

  clean_up()
end

--- Get the number of virtual cursors
---@return integer
function M.get_num_virtual_cursors() return #virtual_cursors end

--- Sort virtual cursors by position
function M.sort() table.sort(virtual_cursors) end

--- Add a new virtual cursor with a visual area
--- add_seq indicates that a sequence number should be added to store the order that cursors have being added
---@param lnum integer
---@param col integer
---@param curswant integer
---@param visual_start_lnum integer
---@param visual_start_col integer
---@param add_seq boolean
---@param off? integer
function M.add_with_visual_area(lnum, col, curswant, visual_start_lnum, visual_start_col, add_seq, off)
  -- Check for existing virtual cursor
  for _, vc in ipairs(virtual_cursors) do
    if vc.col == col and vc.lnum == lnum then return end
  end

  local first = set_first and #virtual_cursors == 0

  local seq = 0 -- 0 is ignored for restoring position

  if add_seq then
    seq = next_seq
    next_seq = next_seq + 1
  end

  table.insert(virtual_cursors, VirtualCursor.new(lnum, col, curswant, visual_start_lnum, visual_start_col, seq))

  -- Create an extmark
  extmarks.update_virtual_cursor_extmarks(virtual_cursors[#virtual_cursors])
end

--- Add a new virtual cursor
--- add_seq indicates that a sequence number should be added to store the order that cursors have being added
---@param lnum integer
---@param col integer
---@param curswant integer
---@param add_seq boolean
---@param off? integer
function M.add(lnum, col, curswant, add_seq, off) M.add_with_visual_area(lnum, col, curswant, 0, 0, add_seq, off) end

-- Add a new virtual cursor, or delete if there's already an existing virtual
-- cursor
---@param lnum integer
---@param col integer
---@param ve? boolean
function M.add_or_delete(lnum, col, ve)
  -- Find any existing virtual cursor
  local delete = false

  for _, vc in ipairs(virtual_cursors) do
    if vc.col == col and vc.lnum == lnum then
      vc.delete = true
      delete = true
    end
  end

  if delete then
    clean_up()
  else
    M.add(lnum, col, col, false)
  end
end

-- Get the position that the real cursor should take on exit, i.e. the position
-- of the virtual cursor with the lowest non-zero seq
---@return nil | { [0]: integer, [1]: integer, [2]: integer, [3]: integer } # { lnum, col, curswant, offset }
function M.get_exit_pos()
  local seq = 999999
  local lnum = 0
  local col = 0
  local curswant = 0
  local offset = 0

  for _, vc in ipairs(virtual_cursors) do
    if vc.seq ~= 0 and vc.seq < seq then
      seq = vc.seq
      lnum = vc.lnum
      col = vc.col
      curswant = vc.curswant
      offset = vc.off
    end
  end

  if seq ~= 999999 then
    return { lnum, col, curswant, offset }
  else
    return nil
  end
end

-- Clear all virtual cursors
function M.clear()
  virtual_cursors = {}
  next_seq = 1
  locked = false
end

function M.update_extmarks()
  for _, vc in ipairs(virtual_cursors) do
    extmarks.update_virtual_cursor_extmarks(vc)
  end
end

function M.set_ignore_cursor_movement(_ignore_cursor_movement)
  ignore_cursor_movement = _ignore_cursor_movement
  if not _ignore_cursor_movement then M.last_cursor_pos = vim.fn.getcurpos() end
end

-- Callback for the CursorMoved event
-- Set editable to false for any virtual cursors that collide with the real
-- cursor
---@return nil
function M.cursor_moved()
  if ignore_cursor_movement then return end

  -- Get real cursor position
  local pos = vim.fn.getcurpos() -- [0, lnum, col, off, curswant, offset]

  for idx = #virtual_cursors, 1, -1 do
    local vc = virtual_cursors[idx]

    -- First update the virtual cursor position from the extmark in case there
    -- was a change due to editing
    extmarks.update_virtual_cursor_position(vc)

    -- Mark editable to false if coincident with the real cursor
    vc.editable = not (vc.lnum == pos[2] and vc.col == pos[3])

    -- Update the extmark (extmark is invisible if editable == false)
    extmarks.update_virtual_cursor_extmarks(vc)
  end
  M.last_cursor_pos = vim.fn.getcurpos()
end

function M.toggle_lock() locked = not locked end

-- Visitors --------------------------------------------------------------------

---@param idx integer
---@param vc VirtualCursor
local function revert_virtual_cursor(idx, vc)
  -- TODO: REVERT VIRTUAL CURSORS
end

-- Visit all virtual cursors
---@param func fun(vc: VirtualCursor, idx: integer): boolean?
---@param allow_abort? boolean
---@param prev_cursor_pos? pos5_1
---@return (integer|boolean)? revert # last changed index, or true
function M.visit_all(func, allow_abort, prev_cursor_pos)
  if locked then return end

  -- Save cursor position
  -- This is because changing virtualedit causes curswant to be reset
  local cursor_pos = vim.fn.getcurpos()

  -- Save virtualedit
  local ve, last_changed_idx = vim.wo.ve, nil

  -- Set virtualedit to onemore in insert or replace modes
  if behavior.need_virtual_edit then
    vim.wo.ve = "all"
  elseif vim.wo.ve ~= "all" and common.is_mode_insert_replace() then
    if vim.wo.ve and #vim.wo.ve > 0 then
      if vim.wo.ve[#vim.wo.ve] == "," then
        vim.wo.ve = vim.wo.ve .. "onemore"
      else
        vim.wo.ve = vim.wo.ve .. ",onemore"
      end
    else
      vim.wo.ve = "onemore"
    end
    print("old ve, new ve:", ve, vim.wo.ve)
  end

  local revert = false

  for idx, vc in ipairs(virtual_cursors) do
    -- Set virtual cursor position from extmark in case there were any changes
    extmarks.update_virtual_cursor_position(vc)

    if not vc.delete then
      -- Call the function
      local revert_ = func(vc, idx) and allow_abort

      if not (revert_ and behavior._eol_behavior.virt.stop_self) then
        -- Update extmarks
        extmarks.update_virtual_cursor_extmarks(vc)
      end
      if revert then
        last_changed_idx = idx
      elseif revert_ then
        last_changed_idx = idx
        revert = true
        if behavior._eol_behavior.virt.stop_virt then break end
      end
    end
  end

  -- print("revert: ", revert)

  -- Revert virtualedit in insert or replace modes
  if common.is_mode_insert_replace() then
    if not (behavior.config.autovirtualedit and vim.wo.ve == "all") then
      print("Reverting virtualedit from", vim.wo.virtualedit, "back to", ve)
      vim.wo.ve = ve
    end
  end

  -- Restore cursor
  if revert and behavior._eol_behavior.virt.stop_real then
    if prev_cursor_pos then vim.fn.setpos(".", prev_cursor_pos) end
  else
    vim.fn.cursor({ cursor_pos[2], cursor_pos[3], cursor_pos[4], cursor_pos[5] })
  end

  if revert and behavior._eol_behavior.virt.stop_virt and revert > 0 then
    for idx, vc in ipairs(virtual_cursors) do
      -- TODO: Error handling
      local tf, errmsg = pcall(revert_virtual_cursor, idx, vc)
      if not tf then vim.api.nvim_echo({ { errmsg, "ErrorMsg" } }, true, {}) end
      if idx >= revert then break end
    end
  else
    clean_up()
    check_for_collisions()
  end

  if revert and (behavior._eol_behavior.virt.stop_real or behavior._eol_behavior.virt.stop_virt) then
    return last_changed_idx
  end
end

-- Visit virtual cursors within the buffer with the real cursor
---@param func fun(vc: VirtualCursor, idx: integer): boolean?
---@param allow_abort? boolean
---@param prev_cursor_pos? pos5_1
---@return (boolean|integer)? revert
function M.visit_with_cursor(func, allow_abort, prev_cursor_pos)
  ignore_cursor_movement = true

  local ret = M.visit_all(function(vc, idx)
    vc:set_cursor_position()
    func(vc, idx)
  end, allow_abort, prev_cursor_pos)

  ignore_cursor_movement = false

  return ret
end

-- Visit virtual cursors and execute a normal command to move them
---@param count? integer
---@param cmd string # normal-mode command (executed with `:normal!`)
---@param allow_abort? boolean
---@param linewise? boolean
---@param prev_cursor_pos? pos5_1
---@return (boolean|integer)? revert
function M.move_with_normal_command(count, cmd, allow_abort, prev_cursor_pos, linewise)
  prev_cursor_pos = prev_cursor_pos or vim.fn.getcurpos()
  return M.visit_with_cursor(function(vc)
    if common.normal_bang(nil, count, cmd, nil, allow_abort, prev_cursor_pos, linewise) then return true end
    vc:save_cursor_position()

    -- Fix for $ not setting col correctly in insert mode even with onemore
    if common.is_mode_insert_replace() then
      if vc.curswant == vim.v.maxcol then vc.col = common.get_max_col(vc.lnum) end
    end
  end, allow_abort, prev_cursor_pos)
end

-- Call func to perform an edit at each virtual cursor
-- The virtual cursor position is not set after calling func
---@param func fun(vc: VirtualCursor, idx: integer): boolean?
---@param allow_abort? boolean
---@param prev_cursor_pos? pos5_1
---@return boolean reverted # true or last changed index
function M.edit(func, allow_abort, prev_cursor_pos)
  -- Save cursor position with extmark
  ignore_cursor_movement = true
  extmarks.save_cursor(prev_cursor_pos)

  local revert_movement = M.visit_all(function(vc, idx)
    if vc.editable then return func(vc, idx) end
  end, allow_abort, prev_cursor_pos)

  -- Restore cursor from extmark
  extmarks.restore_cursor(behavior._eol_behavior.virt.stop_real and revert_movement or nil)
  -- if revert_movement and behavior._eol_behavior.virt.stop_virt then
  --   -- Need to revert the virtual cursors that have been changed
  --   revert_movement = revert_movement == true and #virtual_cursors or revert_movement
  --   for i = 1, revert_movement do
  --     -- TODO: REVERT VIRTUAL CURSOR
  --   end
  -- end

  ignore_cursor_movement = false

  return revert_movement and revert_movement ~= 0 or false
end

-- Call func to perform an edit at each virtual cursor using the real cursor
-- The virtual cursor position is not set after calling func
---@param func fun(vc: VirtualCursor, idx: integer): boolean?
---@param allow_abort? boolean
---@param prev_cursor_pos? pos5_1
---@return boolean reverted
function M.edit_with_cursor_no_save(func, allow_abort, prev_cursor_pos)
  return M.edit(function(vc, idx)
    vc:set_cursor_position()
    return func(vc, idx)
  end, allow_abort, prev_cursor_pos)
end

-- Call func to perform an edit at each virtual cursor using the real cursor
---@param func fun(vc: VirtualCursor, idx: integer): boolean?
---@param allow_abort? boolean
---@param prev_cursor_pos? pos5_1
---@return boolean reverted
function M.edit_with_cursor(func, allow_abort, prev_cursor_pos)
  return M.edit_with_cursor_no_save(function(vc, idx)
    if func(vc, idx) then
      return true
    else
      vc:save_cursor_position()
    end
  end, allow_abort, prev_cursor_pos)
end

-- Execute a normal command to perform an edit at each virtual cursor
-- The virtual cursor position is set after calling func
---@param count? integer # can be 0
---@param cmd string # normal-mode command (executed with `:normal!`)
---@param motion_cmd? string
---@param allow_abort? boolean
---@param prev_cursor_pos? pos5_1
---@return boolean reverted
function M.edit_with_normal_command(count, cmd, motion_cmd, allow_abort, prev_cursor_pos)
  return M.edit_with_cursor(
    function(vc) common.normal_bang(nil, count, cmd, motion_cmd) end,
    allow_abort,
    prev_cursor_pos
  )
end

-- Execute a normal command to perform a delete or yank at each virtual cursor
-- The virtual cursor position is set after calling func
---@param register? string
---@param count? integer # can be 0
---@param cmd string
---@param motion_cmd? string
function M.normal_mode_delete_yank(register, count, cmd, motion_cmd)
  -- Delete or yank command
  return M.edit_with_cursor(function(vc, idx)
    common.normal_bang(register, count, cmd, motion_cmd)
    vc:save_register(register)
  end, false)
end

-- Execute a normal command to perform a put at each virtual cursor
-- The register is first saved, the replaced by the virtual cursor register
-- After executing the command the unnamed register is restored
---@param register string
---@param count? integer
---@param cmd string
function M.normal_mode_put(register, count, cmd)
  local use_own_register = true

  for _, vc in ipairs(virtual_cursors) do
    if vc.editable and not vc:has_register(register) then
      use_own_register = false
      break
    end
  end

  -- If not using each virtual cursor's register
  if not use_own_register then
    -- Return if the main register doesn't have data
    local register_info = vim.fn.getreginfo(register)
    if next(register_info) == nil then return end
  end

  M.edit_with_cursor(function(vc, idx)
    local register_info = nil

    -- If the virtual cursor has data for the register
    if use_own_register then
      -- Save the register
      register_info = vim.fn.getreginfo(register)
      -- Set the register from the virtual cursor
      vc:set_register(register)
    end

    -- Put the register
    common.normal_bang(register, count, cmd, nil)

    -- Restore the register
    if register_info then vim.fn.setreg(register, register_info) end
  end, false)
end

-- Visual mode -----------------------------------------------------------------

-- Call func on the visual area of each virtual cursor
---@param func fun(vc: VirtualCursor, idx: integer)
function M.visual_mode(func)
  ignore_cursor_movement = true

  -- Save the visual area to extmarks
  extmarks.save_visual_area()

  M.visit_all(function(vc, idx)
    -- Set visual area
    vc:set_visual_area()

    -- Call func
    if func(vc, idx) then return true end

    -- Did func exit visual mode?
    if common.is_mode("v") then
      -- Save visual area to virtual cursor
      vc:save_visual_area()
    else -- Edit commands will exit visual mode
      -- Save cursor
      vc:save_cursor_position()

      -- Clear the visual area
      vc.visual_start_lnum = 0
      vc.visual_start_col = 0
    end
  end, false)
  -- Restore the visual area from extmarks
  extmarks.restore_visual_area()

  ignore_cursor_movement = false
end

---@param register string
---@param cmd string
function M.visual_mode_delete_yank(register, cmd)
  M.visual_mode(function(vc, idx)
    common.normal_bang(register, 0, cmd, nil)
    vc:save_register(register)
  end)
end

-- Split pasting ---------------------------------------------------------------

-- Does the number of lines match the number of editable cursors + 1 (for the
-- real cursor)
---@param num_lines integer
---@return boolean
function M.can_split_paste(num_lines)
  -- Get the number of editable virtual cursors
  local count = 0

  for _, vc in ipairs(virtual_cursors) do
    if vc.editable then count = count + 1 end
  end

  return count + 1 == num_lines
end

-- Move the line for the real cursor to the end of lines
-- Modifies the lines variable
---@param lines integer[]
function M.reorder_lines_for_split_pasting(lines)
  -- Ensure virtual_cursors is sorted
  M.sort()

  -- Move real cursor line to the end
  local real_cursor_pos = vim.fn.getcurpos() -- [0, lnum, col, off, curswant]

  local cursor_line_idx = 0

  for idx, vc in ipairs(virtual_cursors) do
    if vc.lnum == real_cursor_pos[2] then
      if vc.col > real_cursor_pos[3] then
        cursor_line_idx = idx
        break
      end
    else
      if vc.lnum > real_cursor_pos[2] then
        cursor_line_idx = idx
        break
      end
    end
  end

  if cursor_line_idx ~= 0 then
    -- Move the line for the real cursor to the end
    local real_cursor_line = table.remove(lines, cursor_line_idx)
    table.insert(lines, real_cursor_line)
  end
end

return M
