local M = {}

local common = require("multiple-cursors.common")
local virtual_cursors = require("multiple-cursors.virtual_cursors")
local insert_mode_completion = require("multiple-cursors.insert_mode.completion")

local function normal_command_and_feedkeys(cmd, key)
  insert_mode_completion.complete_if_selected()
  virtual_cursors.move_with_normal_command(0, cmd)
  common.feedkeys(nil, 0, key, nil)
end

function M.up(cmd,key)
  normal_command_and_feedkeys(cmd or "k", key or "<Up>")
end

function M.down(cmd,key)
  normal_command_and_feedkeys(cmd or "j", key or "<Down>")
end

function M.left(cmd,key)
  normal_command_and_feedkeys(cmd or "h", key or "<Left>")
end

function M.right(cmd,key)
  normal_command_and_feedkeys(cmd or "l", key or "<Right>")
end

function M.home(cmd,key)
  normal_command_and_feedkeys(cmd or "0", key or "<Home>")
end

function M.eol(cmd,key)
  normal_command_and_feedkeys(cmd or "$", key or "<End>")
end

function M.word_left(cmd,key)
  normal_command_and_feedkeys(cmd or "b", key or "<C-Left>")
end

function M.word_right(cmd,key)
  normal_command_and_feedkeys(cmd or "w", key or "<C-Right>")
end

return M
