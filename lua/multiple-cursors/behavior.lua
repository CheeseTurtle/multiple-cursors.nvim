local M = {}

---@type string?
M.initial_virtualedit = nil

---@type boolean
M.need_virtual_edit = nil

---@alias MultipleCursors.Behavior.WrapBehavior
---| "'wrap'"
---| "'stop_all'"
---| "'stop_virt'"
---| "'stop_self'"
---| "'stop_real'"

---@class MultipleCursors.Behavior.BehaviorConfig
M.config = {
  ---@type boolean
  skipshort = true,
  -- skipleadingspace = false,
  ---@type boolean
  autovirtualedit = true,
  ---@type MultipleCursors.Behavior.WrapBehavior
  realeol = "wrap",
  ---@typ MultipleCursors.Behavior.WrapBehavior
  virteol = "wrap",
}

---@class MultipleCursors.Behavior._EolBehavior

M._eol_behavior = {
  ---@type {stop_real: boolean, stop_virt: boolean, stop_self: boolean}
  virt = {},
  ---@type {stop_real: boolean, stop_virt: boolean, stop_self: boolean}
  real = {},
}

function M.set_eol_behavior(real, virt)
  real = real or M.config.realeol
  virt = virt or M.config.virteol

  M._eol_behavior = { real = {}, wrap = {} }
  if real == "wrap" then
    M._eol_behavior.real = { stop_real = false, stop_virt = false, stop_self = false }
  elseif real[6] == "a" then
    M._eol_behavior.real = { stop_real = true, stop_virt = true, stop_self = true }
  elseif real[6] == "v" then
    M._eol_behavior.real = { stop_real = false, stop_virt = true, stop_self = false }
  else
    M._eol_behavior.real = { stop_real = true, stop_virt = false, stop_self = true }
  end
  if virt == "wrap" then
    M._eol_behavior.virt = { stop_real = false, stop_virt = false, stop_self = false }
  elseif virt[6] == "r" then
    M._eol_behavior.virt = { stop_real = true, stop_virt = false, stop_self = false }
  elseif virt[6] == "v" then
    M._eol_behavior.virt = { stop_real = false, stop_virt = true, stop_self = true }
  else -- if virt[6] == 's'
    M._eol_behavior.virt = { stop_real = false, stop_virt = false, stop_self = true }
  end
end

M.set_eol_behavior()

---@type table<string,string[]|string>
M.spec = {
  skipshort = { "on", "off" },
  -- skipleadingspace = { "on", "off" },
  autovirtualedit = { "on", "off" },
  realeol = { "wrap", "stop_all", "stop_virt", "stop_self", "stop_real" },
  virteol = { "wrap", "stop_all", "stop_virt", "stop_self", "stop_real" },
}

---@type table<string,string|integer>
M.defaults = {
  skipshort = "on",
  -- skipleadingspace = "off",
  autovirtualedit = "on",
  realeol = "wrap",
  virteol = "wrap",
}

return M
