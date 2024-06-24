local M = {}

local common = require("multiple-cursors.common")
local virtual_cursors = require("multiple-cursors.virtual_cursors")
local input = require("multiple-cursors.input")

-- Replace char
function M.r(key)
  local count = vim.v.count
  local char = input.get_char()

  if char ~= nil then
    virtual_cursors.edit_with_normal_command(count, (key or "r") .. char, nil)
    common.feedkeys(nil, count, (key or "r") .. char, nil)
  end
end

local function normal_command_and_feedkeys(cmd)
  local count = vim.v.count
  virtual_cursors.edit_with_normal_command(count, cmd, nil)
  common.feedkeys(nil, count, cmd, nil)
end

function M.indent(key) normal_command_and_feedkeys(key or ">>") end
function M.deindent(key) normal_command_and_feedkeys(key or "<<") end
function M.J(key) normal_command_and_feedkeys(key or "J") end
function M.gJ(key) normal_command_and_feedkeys(key or "gJ") end
function M.dot(key) normal_command_and_feedkeys(key or ".") end

local function normal_command_and_feedkeys_with_motion(cmd)

  local count = vim.v.count

  local motion_cmd = input.get_motion_cmd()

  if motion_cmd ~= nil then
    virtual_cursors.edit_with_normal_command(count, cmd, motion_cmd)
    common.feedkeys(nil, count, cmd, motion_cmd)
  end

end

function M.gu(key) normal_command_and_feedkeys_with_motion(key or "gu") end
function M.gU(key) normal_command_and_feedkeys_with_motion(key or "gU") end
function M.g_tilde(key) normal_command_and_feedkeys_with_motion(key or "g~") end

return M
