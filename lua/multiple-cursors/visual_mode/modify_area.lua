local M = {}

local common = require("multiple-cursors.common")
local virtual_cursors = require("multiple-cursors.virtual_cursors")
local input = require("multiple-cursors.input")

local function modify_area(cmd)
	local count = vim.v.count

	virtual_cursors.visual_mode(function()
		common.normal_bang(nil, count, cmd, nil)
	end)

	common.feedkeys(nil, count, cmd, nil)
end

-- o command
function M.o(key)
	modify_area(key or "o")
end

-- "a" text object selection commands
function M.a(key)
	local char2 = input.get_text_object_sel_second_char()

	if char2 then
		modify_area((key or "a") .. char2)
	end

	return
end

-- "i" text object selection commands
function M.i(key)
	local char2 = input.get_text_object_sel_second_char()

	if char2 then
		modify_area((key or "i") .. char2)
	end

	return
end

return M
