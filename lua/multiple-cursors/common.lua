local M = {}

-- Execute a command with normal!
-- register and motion_cmd may be nil
---@param register? string
---@param count? integer # may be 0
---@param cmd string
---@param motion_cmd? string # may also contain a count
---@param allow_abort? boolean
---@param linewise? boolean
---@param prev_cursor_pos? pos5_1
---@return boolean? revert # `true` if the cursor could not be moved as requested
function M.normal_bang(register, count, cmd, motion_cmd, allow_abort, prev_cursor_pos, linewise)
  -- Command string
  local str = ""

  if register then str = str .. '"' .. register end

  if count ~= 0 then str = str .. count end

  str = str .. cmd

  if motion_cmd then str = str .. motion_cmd end

  if allow_abort then
    local pos0 = vim.fn.getcurpos()
    vim.cmd("normal! " .. str)
    local pos1 = vim.fn.getcurpos()
    if pos0[2] == pos1[2] and pos0[3] == pos1[3] then
      vim.fn.setpos(".", pos0)
      return true
    end
  else
    vim.cmd("normal! " .. str)
  end
end

-- Abstraction of nvim_feedkeys
-- register and motion_cmd may be nil
---@param register? string
---@param count integer # may be 0
---@param cmd string
---@param motion_cmd? string # may also contain a count
function M.feedkeys(register, count, cmd, motion_cmd, allow_abort)
  -- Command string
  local str = ""

  if register then str = str .. '"' .. register end

  if count ~= 0 then str = str .. count end

  str = str .. cmd

  if motion_cmd then str = str .. motion_cmd end

  local tmp = vim.api.nvim_replace_termcodes(str, true, false, true)

  if allow_abort then
    local pos0 = vim.fn.getcurpos()
    vim.api.nvim_feedkeys(tmp, "n", false)
    local pos1 = vim.fn.getcurpos()
    if pos0[1] == pos1[1] and pos0[2] == pos1[2] and pos0[3] == pos1[3] then
      vim.fn.setpos(".", pos0)
      return true
    end
  else
    vim.api.nvim_feedkeys(tmp, "n", false)
  end
end

-- Check if mode is given mode
function M.is_mode(mode) return vim.api.nvim_get_mode().mode == mode end

-- Check if mode is insert or replace
function M.is_mode_insert_replace()
  local mode = vim.api.nvim_get_mode().mode
  return mode == "i" or mode == "ic" or mode == "R" or mode == "Rc"
end

-- Number of characters in a line
function M.get_length_of_line(lnum) return vim.fn.col({ lnum, "$" }) - 1 end

-- Does the 'virtualedit' option include x?
function M.is_ve_opt(opt, ignore_onemore)
  local ve = vim.opt.virtualedit and vim.opt.virtualedit._value
  if ve == nil or ve == "" then return false end
  ve = vim.opt.virtualedit.get and vim.opt.virtualedit:get()
  if ve and #ve > 0 then
    if opt then
      opt = opt[1]
      -- block,insert,onemore,       none,NONE,all
      for _, elem in ipairs(ve) do
        if opt == elem[1] then return true end
      end
      return false
    else
      local mode = vim.fn.mode()
      local all_pos, none_pos, true_pos = 0, 0, 0
      for i, elem in ipairs(ve) do
        if elem[1] == "a" then
          all_pos = i
        elseif elem[1] == "b" then
          if mode == "" then true_pos = i end
        elseif elem[1] == "o" then
          if not ignore_onemore then true_pos = i end
        elseif elem[1] == "i" then
          if mode == "i" then true_pos = i end
        else -- 'none' or 'NONE'
          none_pos = i
        end
      end
      if none_pos > all_pos then
        if true_pos > none_pos then -- true condition applied
          return true
        else -- 'none' came last
          return false
        end
      else -- either 'all' or true condition applies
        return true
      end
    end
  else
    return false
  end
end

-- Maximum column position for a line
function M.get_max_col(lnum)
  -- In normal mode the maximum column position is one less than other modes,
  -- except if the line is empty or virtualedit includes 'onemore'
  if M.is_mode("n") or M.is_ve_opt("onemore") then
    return vim.fn.max({ M.get_length_of_line(lnum), 1 })
  else
    return M.get_length_of_line(lnum) + 1
  end
end

-- Get a column position for a given curswant
---@param lnum integer
---@param curswant integer
---@return integer
function M.get_col(lnum, curswant)
  local max = M.get_max_col(lnum)
  return max < curswant and max or curswant
end

-- Get current visual area
-- Returns v_lnum, v_col, lnum, col, curswant
---@return integer v_lnum, integer v_col, integer lnum, integer col, integer curswant
function M.get_visual_area()
  local vpos = vim.fn.getpos("v")
  local cpos = vim.fn.getcurpos()
  return vpos[2], vpos[3], cpos[2], cpos[3], cpos[5]
end

-- Get current visual area in a forward direction
-- returns lnum1, col1, lnum2, col2
function M.get_normalised_visual_area()
  local v_lnum, v_col, lnum, col = M.get_visual_area()

  -- Normalise
  if v_lnum < lnum then
    return v_lnum, v_col, lnum, col
  elseif lnum < v_lnum then
    return lnum, col, v_lnum, v_col
  else -- v_lnum == lnum
    if v_col <= col then
      return v_lnum, v_col, lnum, col
    else -- col < v_col
      return lnum, col, v_lnum, v_col
    end
  end
end

-- Set visual area marks and apply
---@param v_lnum integer
---@param v_col integer
---@param lnum integer
---@param col integer
function M.set_visual_area(v_lnum, v_col, lnum, col)
  vim.api.nvim_buf_set_mark(0, "<", v_lnum, v_col - 1, {})
  vim.api.nvim_buf_set_mark(0, ">", lnum, col - 1, {})
  vim.cmd("normal! gv")
end

return M
