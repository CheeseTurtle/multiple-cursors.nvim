local M = {}

local common = require("multiple-cursors.common")
local virtual_cursors = require("multiple-cursors.virtual_cursors")
local input = require("multiple-cursors.input")

local function normal_command_and_feedkeys(cmd)
	local count = vim.v.count
	virtual_cursors.move_with_normal_command(count, cmd)
	common.feedkeys(nil, count, cmd, nil)
end


local LEFT, RIGHT, UP, DOWN =
		vim.keycode'<Left>', vim.keycode'<Right>',
		vim.keycode'<Up>', vim.keycode'<Down>'

function M.left(key) normal_command_and_feedkeys(key or LEFT) end
function M.right(key) normal_command_and_feedkeys(key or RIGHT) end
function M.up(key) normal_command_and_feedkeys(key or UP) end
function M.down(key) normal_command_and_feedkeys(key or DOWN) end
function M.k(key) normal_command_and_feedkeys(key or "k") end
function M.j(key) normal_command_and_feedkeys(key or "j") end
function M.minus(key) normal_command_and_feedkeys(key or "-") end
function M.plus(key) normal_command_and_feedkeys(key or "+") end
function M.underscore(key) normal_command_and_feedkeys(key or "_") end

function M.h(key) normal_command_and_feedkeys(key or "h") end
function M.l(key) normal_command_and_feedkeys(key or "l") end
function M.zero(key) normal_command_and_feedkeys(key or "0") end
function M.caret(key) normal_command_and_feedkeys(key or "^") end
function M.dollar(key) normal_command_and_feedkeys(key or "$") end
function M.bar(key) normal_command_and_feedkeys(key or "|") end

-- For f, F, t, or T commands
local function fFtT(cmd)

	local count = vim.v.count
	local char = input.get_char()

	if char ~= nil then
		virtual_cursors.move_with_normal_command(count, cmd .. char)
		common.feedkeys(nil, count, cmd .. char, nil)
	end

end

function M.f(key) fFtT(key or "f") end
function M.F(key) fFtT(key or "F") end
function M.t(key) fFtT(key or "t") end
function M.T(key) fFtT(key or "T") end

function M.w(key) normal_command_and_feedkeys(key or "w") end
function M.W(key) normal_command_and_feedkeys(key or "W") end
function M.e(key) normal_command_and_feedkeys(key or "e") end
function M.E(key) normal_command_and_feedkeys(key or "E") end
function M.b(key) normal_command_and_feedkeys(key or "b") end
function M.B(key) normal_command_and_feedkeys(key or "B") end
function M.ge(key) normal_command_and_feedkeys(key or "ge") end
function M.gE(key) normal_command_and_feedkeys(key or "gE") end

-- Percent
function M.percent(key)
	-- Count is ignored, match command only
	virtual_cursors.move_with_normal_command(0, key or "%")
	common.feedkeys(nil, 0, key or "%", nil)
end

return M
