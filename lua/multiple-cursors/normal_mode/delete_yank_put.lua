local M = {}

local common = require("multiple-cursors.common")
local virtual_cursors = require("multiple-cursors.virtual_cursors")
local input = require("multiple-cursors.input")

-- Delete and yank
local function normal_mode_delete_yank_and_feedkeys(cmd)
  local register = vim.v.register
  local count = vim.v.count
  virtual_cursors.normal_mode_delete_yank(register, count, cmd, nil)
  common.feedkeys(register, count, cmd, nil)
end

function M.x(key) normal_mode_delete_yank_and_feedkeys(key or "x") end
function M.X(key) normal_mode_delete_yank_and_feedkeys(key or "X") end
function M.dd(key) normal_mode_delete_yank_and_feedkeys(key or "dd") end
function M.D(key) normal_mode_delete_yank_and_feedkeys(key or "D") end
function M.yy(key) normal_mode_delete_yank_and_feedkeys(key or "yy") end

-- For d and y
local function normal_mode_delete_yank_and_feedkeys_with_motion(cmd)

  local register = vim.v.register
  local count = vim.v.count

  local motion_cmd = input.get_motion_cmd()

  if motion_cmd ~= nil then
    virtual_cursors.normal_mode_delete_yank(register, count, cmd, motion_cmd)
    common.feedkeys(register, count, cmd, motion_cmd)
  end

end

function M.d(key) normal_mode_delete_yank_and_feedkeys_with_motion(key or "d") end
function M.y(key) normal_mode_delete_yank_and_feedkeys_with_motion(key or "y") end

-- Put
local function normal_mode_put_and_feedkeys(cmd)
  local register = vim.v.register
  local count = vim.v.count
  virtual_cursors.normal_mode_put(register, count, cmd)
  common.feedkeys(register, count, cmd, nil)
end

function M.p(key) normal_mode_put_and_feedkeys(key or "p") end
function M.P(key) normal_mode_put_and_feedkeys(key or "P") end

return M
