local M = {}

local key_maps = require("multiple-cursors.key_maps")
local common = require("multiple-cursors.common")
local extmarks = require("multiple-cursors.extmarks")
local virtual_cursors = require("multiple-cursors.virtual_cursors")
local behavior = require("multiple-cursors.behavior")

local normal_mode_motion = require("multiple-cursors.normal_mode.motion")
local normal_mode_backspace = require("multiple-cursors.normal_mode.backspace")
local normal_mode_delete_yank_put = require("multiple-cursors.normal_mode.delete_yank_put")
local normal_mode_edit = require("multiple-cursors.normal_mode.edit")
local normal_mode_mode_change = require("multiple-cursors.normal_mode.mode_change")

local insert_mode_motion = require("multiple-cursors.insert_mode.motion")
local insert_mode_character = require("multiple-cursors.insert_mode.character")
local insert_mode_nonprinting = require("multiple-cursors.insert_mode.nonprinting")
local insert_mode_special = require("multiple-cursors.insert_mode.special")
local insert_mode_completion = require("multiple-cursors.insert_mode.completion")
local insert_mode_escape = require("multiple-cursors.insert_mode.escape")

local visual_mode_modify_area = require("multiple-cursors.visual_mode.modify_area")
local visual_mode_delete_yank_change = require("multiple-cursors.visual_mode.delete_yank_change")
local visual_mode_edit = require("multiple-cursors.visual_mode.edit")
local visual_mode_escape = require("multiple-cursors.visual_mode.escape")

local paste = require("multiple-cursors.paste")
local search = require("multiple-cursors.search")

local initialised = false
local autocmd_group_id = nil
local buf_enter_autocmd_id = nil

local pre_hook = nil
local post_hook = nil

local bufnr = nil

local match_visible_only = nil

---@class pos5_1
---@field [1] integer bufnr
---@field [2] integer line num in buffer (from 1)
---@field [3] integer col num (byte pos in buffer line) (from 1)
---@field [4] integer offset (i.e. when virtualedit is active)
---@field [5] integer curswant (= col + off when ve is active)

---@class keymap_entry
---@field [1] string|string[]
---@field [2] string|string[]
---@field [3] function
---@field [4]? string
---@field [5]? string

---@alias keymap_section keymap_entry[]

---@type table<string,keymap_section>
default_key_maps = {
  -- Normal and visual mode motion ---------------------------------------------
  -- Up/down
  normal_visual = {
    k = { { "n", "x" }, { "k", "<Up>" }, normal_mode_motion.k },
    j = { { "n", "x" }, { "j", "<Down>" }, normal_mode_motion.j },
    minus = { { "n", "x" }, "-", normal_mode_motion.minus },
    plus = { { "n", "x" }, { "+", "<CR>", "<kEnter>" }, normal_mode_motion.plus },
    underscore = { { "n", "x" }, "_", normal_mode_motion.underscore },

    -- Left/right
    h = { { "n", "x" }, { "h", "<Left>" }, normal_mode_motion.h },
    bs = { { "n", "x" }, "<BS>", normal_mode_backspace.bs },
    l = { { "n", "x" }, { "l", "<Right>", "<Space>" }, normal_mode_motion.l },
    zero = { { "n", "x" }, { "0", "<Home>" }, normal_mode_motion.zero },
    caret = { { "n", "x" }, "^", normal_mode_motion.caret },
    dollar = { { "n", "x" }, { "$", "<End>" }, normal_mode_motion.dollar },
    bar = { { "n", "x" }, "|", normal_mode_motion.bar },
    f = { { "n", "x" }, "f", normal_mode_motion.f },
    F = { { "n", "x" }, "F", normal_mode_motion.F },
    t = { { "n", "x" }, "t", normal_mode_motion.t },
    T = { { "n", "x" }, "T", normal_mode_motion.T },

    -- Text object motion
    w = { { "n", "x" }, { "w", "<S-Right>", "<C-Right>" }, normal_mode_motion.w },
    W = { { "n", "x" }, "W", normal_mode_motion.W },
    e = { { "n", "x" }, "e", normal_mode_motion.e },
    E = { { "n", "x" }, "E", normal_mode_motion.E },
    b = { { "n", "x" }, { "b", "<S-Left>", "<C-Left>" }, normal_mode_motion.b },
    B = { { "n", "x" }, "B", normal_mode_motion.B },
    ge = { { "n", "x" }, "ge", normal_mode_motion.ge },
    gE = { { "n", "x" }, "gE", normal_mode_motion.gE },

    -- Other
    percent = { { "n", "x" }, "%", normal_mode_motion.percent },
  },

  -- Normal mode edit ----------------------------------------------------------
  normal = {
    -- Delete, yank, put
    x = { "n", { "x", "<Del>" }, normal_mode_delete_yank_put.x },
    X = { "n", "X", normal_mode_delete_yank_put.X },
    d = { "n", "d", normal_mode_delete_yank_put.d },
    dd = { "n", "dd", normal_mode_delete_yank_put.dd },
    D = { "n", "D", normal_mode_delete_yank_put.D },
    y = { "n", "y", normal_mode_delete_yank_put.y },
    yy = { "n", "yy", normal_mode_delete_yank_put.yy },
    p = { "n", "p", normal_mode_delete_yank_put.p },
    P = { "n", "P", normal_mode_delete_yank_put.P },

    -- Replace characters
    r = { "n", "r", normal_mode_edit.r },

    -- Indentation
    indent = { "n", ">>", normal_mode_edit.indent },
    dedent = { "n", "<<", normal_mode_edit.deindent },

    -- Join lines
    J = { "n", "J", normal_mode_edit.J },
    gJ = { "n", "gJ", normal_mode_edit.gJ },

    -- Change case
    gu = { "n", "gu", normal_mode_edit.gu },
    gU = { "n", "gU", normal_mode_edit.gU },
    g_tilde = { "n", "g~", normal_mode_edit.g_tilde },

    -- Repeat
    dot = { "n", ".", normal_mode_edit.dot },

    -- Normal mode exit ----------------------------------------------------------
    { "n", "u", function() M.normal_undo() end },
    { "n", "<Esc>", function() M.normal_escape() end },

    -- Normal mode mode change ---------------------------------------------------
    -- To insert mode
    a = { "n", "a", normal_mode_mode_change.a },
    A = { "n", "A", normal_mode_mode_change.A },
    i = { "n", { "i", "<Insert>" }, normal_mode_mode_change.i },
    I = { "n", "I", normal_mode_mode_change.I },
    o = { "n", "o", normal_mode_mode_change.o },
    O = { "n", "O", normal_mode_mode_change.O },
    c = { "n", "c", normal_mode_mode_change.c },
    cc = { "n", "cc", normal_mode_mode_change.cc },
    C = { "n", "C", normal_mode_mode_change.C },
    s = { "n", "s", normal_mode_mode_change.s },

    -- To visual mode
    v = { "n", "v", normal_mode_mode_change.v },
    -- What about V and ^V?
  },

  -- Insert (and replace) mode -------------------------------------------------
  insert = {
    -- Motion
    up = { "i", "<Up>", insert_mode_motion.up },
    down = { "i", "<Down>", insert_mode_motion.down },
    left = { "i", "<Left>", insert_mode_motion.left },
    right = { "i", "<Right>", insert_mode_motion.right },
    home = { "i", "<Home>", insert_mode_motion.home },
    eol = { "i", "<End>", insert_mode_motion.eol },
    word_left = { "i", "<C-Left>", insert_mode_motion.word_left },
    word_right = { "i", "<C-Right>", insert_mode_motion.word_right },

    -- Non-printing characters
    bs = { "i", { "<BS>", "<C-h>" }, insert_mode_nonprinting.bs },
    del = { "i", "<Del>", insert_mode_nonprinting.del },
    cr = { "i", { "<CR>", "<kEnter>" }, insert_mode_nonprinting.cr },
    tab = { "i", "<Tab>", insert_mode_nonprinting.tab },

    -- Special
    c_w = { "i", "<C-w>", insert_mode_special.c_w },
    c_t = { "i", "<C-t>", insert_mode_special.c_t },
    c_d = { "i", "<C-d>", insert_mode_special.c_d },

    -- Exit
    escape = { "i", "<Esc>", insert_mode_escape.escape },
  },

  -- Visual mode ---------------------------------------------------------------
  visual = {
    -- Modify area
    o = { "x", "o", visual_mode_modify_area.o },
    a = { "x", "a", visual_mode_modify_area.a },
    i = { "x", "i", visual_mode_modify_area.i },

    -- Delete, yank, change
    d = { "x", { "d", "<Del>" }, visual_mode_delete_yank_change.d },
    y = { "x", "y", visual_mode_delete_yank_change.y },
    c = { "x", "c", visual_mode_delete_yank_change.c },

    -- Indentation
    indent = { "x", ">", visual_mode_edit.indent },
    deindent = { "x", "<", visual_mode_edit.deindent },

    -- Join lines
    J = { "x", "J", visual_mode_edit.J },
    gJ = { "x", "gJ", visual_mode_edit.gJ },

    -- Change case
    u = { "x", "u", visual_mode_edit.u },
    U = { "x", "U", visual_mode_edit.U },
    tilde = { "x", "~", visual_mode_edit.tilde },
    gu = { "x", "gu", visual_mode_edit.gu },
    gU = { "x", "gU", visual_mode_edit.gU },
    g_tilde = { "x", "g~", visual_mode_edit.g_tilde },

    -- Exit
    escape = { "x", { "<Esc>", "v" }, visual_mode_escape.escape },
  },
}

local function buf_delete() M.deinit(true) end

local function buf_leave()
  -- Deinitialise without clearing virtual cursors
  M.deinit(false)
end

local function buf_enter()
  -- Returning to buffer with multiple cursors
  if vim.fn.bufnr() == bufnr then
    M.init()
    virtual_cursors.update_extmarks()
  end
end

-- Create autocmds used by this plug-in
local function create_autocmds()
  -- Monitor cursor movement to check for virtual cursors colliding with the real cursor
  vim.api.nvim_create_autocmd(
    { "CursorMoved", "CursorMovedI" },
    { group = autocmd_group_id, callback = virtual_cursors.cursor_moved }
  )

  -- Insert characters
  vim.api.nvim_create_autocmd(
    { "InsertCharPre" },
    { group = autocmd_group_id, callback = insert_mode_character.insert_char_pre }
  )

  vim.api.nvim_create_autocmd(
    { "TextChangedI" },
    { group = autocmd_group_id, callback = insert_mode_character.text_changed_i }
  )

  vim.api.nvim_create_autocmd(
    { "CompleteDonePre" },
    { group = autocmd_group_id, callback = insert_mode_completion.complete_done_pre }
  )

  -- Mode changed from normal to insert or visual
  vim.api.nvim_create_autocmd({ "ModeChanged" }, {
    group = autocmd_group_id,
    pattern = "n:{i,v}",
    callback = normal_mode_mode_change.mode_changed,
  })

  -- If there are custom key maps, reset the custom key maps on the LazyLoad
  -- event (when a plugin has been loaded)
  -- This is to fix an issue with using a command from a plugin that was lazy
  -- loaded while multi-cursors is active
  if key_maps.has_custom_keys_maps() then
    vim.api.nvim_create_autocmd({ "User" }, {
      group = autocmd_group_id,
      pattern = "LazyLoad",
      callback = key_maps.set_custom,
    })
  end

  vim.api.nvim_create_autocmd({ "BufLeave" }, { group = autocmd_group_id, callback = buf_leave })

  vim.api.nvim_create_autocmd({ "BufDelete" }, { group = autocmd_group_id, callback = buf_delete })
end

--- Initialise
function M.init()
  if not initialised then
    behavior.need_virtual_edit = vim.fn.getcurpos()[4] > 0
    behavior.initial_virtualedit = vim.wo.virtualedit
    if pre_hook then pre_hook() end

    key_maps.save_existing()
    key_maps.set()

    create_autocmds()

    paste.override_handler()

    -- Initialising in a new buffer
    if not bufnr or vim.fn.bufnr() ~= bufnr then
      extmarks.clear()
      virtual_cursors.clear()
      bufnr = vim.fn.bufnr()
      buf_enter_autocmd_id = vim.api.nvim_create_autocmd({ "BufEnter" }, { callback = buf_enter })
    end

    initialised = true
  end
end

--- Deinitialise
---@param clear_virtual_cursors? boolean
function M.deinit(clear_virtual_cursors)
  if initialised then
    if clear_virtual_cursors then
      -- Restore cursor to the position of the oldest virtual cursor
      local pos = virtual_cursors.get_exit_pos()

      if pos then vim.fn.cursor({ pos[1], pos[2], 0, pos[3] }) end

      virtual_cursors.clear()
      bufnr = nil
      ---@cast buf_enter_autocmd_id -nil
      vim.api.nvim_del_autocmd(buf_enter_autocmd_id)
      buf_enter_autocmd_id = nil
    end

    extmarks.clear()

    key_maps.delete()
    key_maps.restore_existing()

    vim.api.nvim_clear_autocmds({ group = autocmd_group_id }) -- Clear autocmds

    paste.revert_handler()

    if post_hook then post_hook() end

    if behavior.initial_virtualedit and behavior.initial_virtualedit ~= vim.wo.virtualedit then
      print("Reverting virtualedit during deinit from", vim.wo.virtualedit, "back to", behavior.initial_virtualedit)
      vim.wo.virtualedit = behavior.initial_virtualedit
    end

    initialised = false
  end
end

--- Normal mode undo will exit because cursor positions can't be restored
function M.normal_undo()
  M.deinit(true)
  common.feedkeys(nil, vim.v.count, "u", nil)
end

--- Escape key
function M.normal_escape()
  M.deinit(true)
  common.feedkeys(nil, 0, "<Esc>", nil)
end

---@return pos5_1?
local function determine_cursor_pos__conceal(down, skip_short, pos0, linebound)
  local short, last_pos = skip_short, pos0
  local goal_col = pos0[3] + pos0[4]
  vim.print("pos0 (goal: " .. tostring(goal_col) .. "): ", pos0)
  while short and line ~= linebound do
    if down then
      vim.cmd("normal! j")
    else
      vim.cmd("normal! k")
    end
    local new_pos = vim.fn.getcurpos()
    if new_pos[2] == last_pos[2] then
      vim.print("Didn't change lines -- new_pos:", new_pos)
      -- Didn't change lines -- reached boundary
      return nil
    elseif new_pos[3] + new_pos[4] == goal_col then
      short = false
    end
    vim.print("new_pos: ", new_pos)
    last_pos = new_pos
  end
  if not short then print("Returning pos") end
  return not short and last_pos or nil
end

--- TODO: Use virtcol2col + virtcol instead
---@return pos5_1?
local function determine_cursor_pos__no_conceal(down, skip_short, pos0, linebound)
  local short, last_col = skip_short, vim.fn.virtcol({ line, col, offset })
  local line, col, offset = pos0[2], pos0[3], pos0[4]
  local goal = pos0[3] + pos0[4]
  local incr = down and 1 or -1
  print(string.format("(curswant: %d) line %d, col %d+%d ==> virtcol %d", pos0[5], line, pos0[3], pos0[4], last_col))
  while short and line ~= linebound do
    line = line + incr
    local new_col = vim.fn.virtcol({ line, goal }) -- col, offset })
    if new_col == 0 then
      -- Invalid line
      print(string.format("line %d, col %d+%d ==> virtcol %d", line, col, offset, new_col))
      return nil
    elseif new_col == last_col and new_col == vim.fn.virtcol({ line, col }) then
      short = false
    end
    print(
      string.format(
        "line %d, col %d+%d ==> virtcol %d (%d without offset)",
        line,
        col,
        offset,
        new_col,
        vim.fn.virtcol({ line, col })
      )
    )
    -- last_col = new_col
  end
  if not short then
    print("Returning: ", pos0[1], line, col, offset, pos0[5])
    return { pos0[1], line, col, offset, pos0[5] }
  end
end

--- Add a virtual cursor then move the real cursor up or down
---@param down boolean
---@param skip_short? boolean
---@param force_virtual_edit? boolean
local function add_virtual_cursor_at_real_cursor(down, skip_short, force_virtual_edit)
  -- Initialise if this is the first cursor
  M.init()
  if skip_short == nil then skip_short = behavior.config.skipshort end
  if force_virtual_edit == nil then force_virtual_edit = behavior.config.autovirtualedit end
  -- vim.print("skip_short, force_ve:", skip_short, force_virtual_edit)
  -- If visual mode
  if common.is_mode("v") then
    -- Add count1 virtual cursors
    local count1 = vim.v.count1

    for _ = 1, count1 do
      -- Get the current visual area
      local v_lnum, v_col, lnum, col, curswant = common.get_visual_area()

      -- Add a virtual cursor with the visual area
      virtual_cursors.add_with_visual_area(lnum, col, curswant, v_lnum, v_col, true)

      -- Move the real cursor visual area
      if down then
        common.set_visual_area(v_lnum + 1, v_col, lnum + 1, col)
      else
        common.set_visual_area(v_lnum - 1, v_col, lnum - 1, col)
      end
    end
  elseif common.is_mode("n") then -- If normal mode
    -- Add count1 virtual cursors
    for _ = 1, vim.v.count1 do
      -- Add virtual cursor at the real cursor position
      -- pos: [1]: bufnr, [2]: row (from 1), [3]: col (from 1), [4]: offset, [5]: curswant
      local pos00 = vim.fn.getcurpos()

      if force_virtual_edit or skip_short then
        local pos0 = pos00

        if pos0[5] == vim.v.maxcol then
          pos0[5] = pos0[3] + pos0[4]
          vim.fn.setpos(".", pos0)
        else
          local sum = pos0[3] + pos0[4]
          if sum ~= pos0[5] then
            pos0[5] = pos0[3] + pos0[4]
            vim.fn.setpos(".", pos0)
          end
        end

        local last_line_nr = vim.fn.line("$")
        -- Impossible to add a cursor above/below if there is only 1 line
        if last_line_nr <= 1 then return end
        local linebound = down and last_line_nr or 1

        local no_conceal, old_ve, func = vim.o.conceallevel == 0, vim.wo.virtualedit, nil
        if no_conceal then
          vim.wo.virtualedit = "all"
          func = determine_cursor_pos__no_conceal
        else
          vim.wo.virtualedit = "block,onemore"
          func = determine_cursor_pos__conceal
        end

        local tf, newpos_or_errmsg = pcall(func, down, skip_short, pos0, linebound)

        if not (tf and newpos_or_errmsg) then
          -- Error occurred, or no acceptable position is available
          print("(failure to move cursor) Reverting virtualedit from", vim.wo.virtualedit, "back to old_ve", old_ve)
          vim.wo.virtualedit = old_ve
          vim.fn.setpos(".", pos00)
          if newpos_or_errmsg then
            vim.api.nvim_echo({ { newpos_or_errmsg, "ErrorMsg" } }, true, {})
          else
            vim.cmd.echom("'Returning false'")
          end

          return -- return without adding virtual cursor
        end

        ---@type pos5_1
        local newpos = newpos_or_errmsg

        -- if not force_ve then local new_cols1 = vim.fn.virtcol({ line, new_pos[5] }, true) end
        local need_ve = newpos[4] > 0
        vim.print("newpos, need_ve, force_ve: ", newpos, need_ve, force_virtual_edit)
        if not (need_ve and force_virtual_edit) then
          print("Reverting virtualedit from", vim.wo.virtualedit, "back to old_ve", old_ve)
          vim.wo.virtualedit = old_ve
        end

        if need_ve and not force_virtual_edit then
          -- Virtual column with offset taken into account
          -- local virtcols_1, virtcols_2 =
          -- virtcol({ newpos[2], newpos[3], newpos[4] }, true), virtcol({ newpos[2], newpos[3] })
          local virtcols = vim.fn.virtcol({ newpos[2], newpos[3], newpos[4] }, true)
          vim.print("virtcols, newpos, ve: '" .. vim.wo.virtualedit .. "'", virtcols, newpos)
          vim.print("newpos 1: ", { newpos[2], virtcols[1], 0, newpos[5] })
          vim.print("newpos 2: ", { newpos[2], virtcols[1], newpos[5] - virtcols[1] })
          if virtcols[1] ~= virtcols[2] or virtcols[2] > newpos[5] then
            print("(pos 1)")
            vim.fn.cursor({ newpos[2], virtcols[1], 0, newpos[5] })
          else
            print("(pos 2)")
            vim.fn.cursor(newpos[2], virtcols[1], newpos[5] - virtcols[1])
          end
        end
        virtual_cursors.add(pos0[2], pos0[3], pos0[5], true, pos0[4])
      else -- Not skipping short lines
        virtual_cursors.add(pos00[2], pos00[3], pos00[5], true)
        -- Move the real cursor
        if down then
          vim.cmd("normal! j")
        else
          vim.cmd("normal! k")
        end
      end
    end
  else -- Insert or replace mode
    -- Add one virtual cursor at the real cursor position
    local pos = vim.fn.getcurpos()
    virtual_cursors.add(pos[2], pos[3], pos[5], true)

    -- Move the real cursor
    if down then
      common.feedkeys(nil, 0, "<Down>", nil)
    else
      common.feedkeys(nil, 0, "<Up>", nil)
    end
  end
end

--- Add a virtual cursor at the real cursor position, then move the real cursor up
---@param skip_short? boolean
function M.add_cursor_up(skip_short, force_ve) return add_virtual_cursor_at_real_cursor(false, skip_short, force_ve) end

--- Add a virtual cursor at the real cursor position, then move the real cursor down
---@param skip_short? boolean
function M.add_cursor_down(skip_short, force_ve) return add_virtual_cursor_at_real_cursor(true, skip_short, force_ve) end

--- Add or delete a virtual cursor at the mouse position
---@param allow_virtual_pos? boolean
function M.mouse_add_delete_cursor(allow_virtual_pos)
  M.init() -- Initialise if this is the first cursor

  local mouse_pos = vim.fn.getmousepos()
  ---@diagnostic disable-next-line:undefined-field
  if allow_virtual_pos and vim.opt.virtualedit and mouse_pos.coladd and mouse_pos.coladd > 0 then
    local ve = vim.opt.virtualedit.get(vim.opt.virtualedit)
    if vim.tbl_contains(ve, "none") then
      allow_virtual_pos = false
    elseif not vim.tbl_contains(ve, "all") then
      local m = vim.fn.mode(true)
      if m[1] == "i" then
        allow_virtual_pos = vim.tbl_contains(ve, "insert")
      --elseif m[1] == "R" then
      elseif m[1] == "V" then
        allow_virtual_pos = vim.tbl_contains(ve, "block")
      elseif vim.tbl_contains(ve, "onemore") then
        ---@diagnostic disable-next-line:undefined-field
        allow_virtual_pos = mouse_pos.coladd == 1
      else
        allow_virtual_pos = false
      end
    else
      allow_virtual_pos = false
    end
  end

  -- Add a virtual cursor to the mouse click position, or delete an existing one
  ---@diagnostic disable-next-line:undefined-field
  virtual_cursors.add_or_delete(mouse_pos.line, mouse_pos.column) --, allow_virtual_pos and mouse_pos.coladd)

  if virtual_cursors.get_num_virtual_cursors() == 0 then
    M.deinit(true) -- Deinitialise if there are no more cursors
  end
end

local function get_visual_area_text()
  local lnum1, col1, lnum2, col2 = common.get_normalised_visual_area()

  if lnum1 ~= lnum2 then
    vim.print("Search pattern must be a single line")
    return nil
  end

  local line = vim.fn.getline(lnum1)
  return line:sub(col1, col2)
end

-- Get a search pattern
-- Returns cword in normal mode and the visual area text in visual mode
local function get_search_pattern()
  local pattern = nil

  if common.is_mode("v") then
    pattern = get_visual_area_text()
  else -- Normal mode
    pattern = vim.fn.expand("<cword>")
  end

  if pattern == "" then
    return nil
  else
    return pattern
  end
end

--- Get the normalise visual area if in visual mode
--- returns is_v, lnum1, col1, lnum2, col2
---@overload fun(): true, integer, integer, integer, integer
---@overload fun(): false
---@return boolean is_v, integer? lnum1, integer? col1, integer? lnum2, integer? col2
local function maybe_get_normalised_visual_area()
  if not common.is_mode("v") then return false end

  local lnum1, col1, lnum2, col2 = common.get_normalised_visual_area()

  return true, lnum1, col1, lnum2, col2
end

--- Add cursors by searching for the word under the cursor or visual area
---@param use_prev_visual_area boolean
local function _add_cursors_to_matches(use_prev_visual_area)
  -- Get the visual area if in visual mode
  local is_v, lnum1, col1, lnum2, col2 = maybe_get_normalised_visual_area()

  -- Get the search pattern: either the cursor under the word in normal mode or the visual area in
  -- visual mode
  local pattern = get_search_pattern()

  if pattern == nil then return end

  -- Find matches (without the one for the cursor) and move the cursor to its match
  local matches = search.get_matches_and_move_cursor(pattern, match_visible_only, use_prev_visual_area)

  if matches == nil then return end

  -- Initialise if not already initialised
  M.init()

  -- Create a virtual cursor at every match
  for _, match in ipairs(matches) do
    local match_lnum1 = match[1]
    local match_col1 = match[2]

    -- If normal mode
    if not is_v then
      virtual_cursors.add(match_lnum1, match_col1, match_col1, false)
    else -- Visual mode
      local match_col2 = match_col1 + string.len(pattern) - 1
      virtual_cursors.add_with_visual_area(match_lnum1, match_col2, match_col2, match_lnum1, match_col1, false)
    end
  end

  vim.print(#matches .. " cursors added")

  -- Restore visual area
  if is_v then common.set_visual_area(lnum1, col1, lnum2, col2) end
end

--- Add cursors to each match of cword or visual area
function M.add_cursors_to_matches() _add_cursors_to_matches(false) end

--- Add cursors to each match of cword or visual area, but only within the previous visual area
function M.add_cursors_to_matches_v() _add_cursors_to_matches(true) end

--- Add a virtual cursor to the start of the word under the cursor (or visual area), then move the
--- cursor to to the next match
function M.add_cursor_and_jump_to_next_match()
  -- Get the visual area if in visual mode
  local is_v, lnum1, col1, lnum2, col2 = maybe_get_normalised_visual_area()

  -- Get the search pattern
  local pattern = get_search_pattern()

  -- Get a match without moving the cursor if there are already virtual cursors
  local match = search.get_next_match(pattern, not initialised)

  if match == nil then return end

  -- Initialise if not already initialised
  M.init()

  local match_lnum1 = match[1]
  local match_col1 = match[2]

  -- Normal mode
  if not is_v then
    -- Add virtual cursor to cursor position
    local pos = vim.fn.getcurpos()
    virtual_cursors.add(pos[2], pos[3], pos[5], true)

    -- Move cursor to match
    vim.fn.cursor({ match_lnum1, match_col1, 0, match_col1 })
  else -- Visual mode
    -- Add virtual cursor to cursor position
    virtual_cursors.add_with_visual_area(lnum2, col2, col2, lnum1, col1, true)

    -- Move cursor to match
    ---@cast pattern -nil
    local match_col2 = match_col1 + string.len(pattern) - 1
    common.set_visual_area(match_lnum1, match_col1, match_lnum1, match_col2)
  end
end

--- Move the cursor to the next match of the word under the cursor (or saved visual area, if any)
function M.jump_to_next_match()
  -- Get the search pattern
  local pattern = get_search_pattern()

  -- Get a match without moving the cursor
  local match = search.get_next_match(pattern, false)

  if match == nil then return end

  local match_lnum1 = match[1]
  local match_col1 = match[2]

  -- Move cursor to match
  if not common.is_mode("v") then
    vim.fn.cursor({ match[1], match[2], 0, match[2] })
  else
    ---@cast pattern -nil
    local match_col2 = match_col1 + string.len(pattern) - 1
    common.set_visual_area(match_lnum1, match_col1, match_lnum1, match_col2)
  end
end

--- Add a new cursor at given position
---@param lnum integer
---@param col integer
---@param curswant integer
function M.add_cursor(lnum, col, curswant)
  -- Initialise if this is the first cursor
  M.init()

  -- Add a virtual cursor
  virtual_cursors.add(lnum, col, curswant, false)
end

--- Insert spaces before each cursor to align them all to the rightmost cursor
function M.align()
  -- This function should only be used when there are multiple cursors
  if not initialised then return end

  -- Find the column of the rightmost cursor
  local col = vim.fn.col(".")

  virtual_cursors.visit_all(function(vc) col = vim.fn.max({ col, vc.col }) end, false)

  -- For each virtual cursor, insert spaces to move the cursor to col
  virtual_cursors.edit_with_cursor(function(vc)
    local num = col - vc.col
    for _ = 1, num do
      vim.api.nvim_put({ " " }, "c", false, true)
    end
  end)

  -- Insert spaces for the real cursor
  local num = col - vim.fn.col(".")
  for _ = 1, num do
    vim.api.nvim_put({ " " }, "c", false, true)
  end
end

--- Toggle locking the virtual cursors if initialised
function M.lock()
  if initialised then virtual_cursors.toggle_lock() end
end

function M.set_options(tbl)
  if #tbl.fargs == 0 then
    -- Print all options
    local strs, first, val = {}, true, nil
    for k, v in pairs(behavior.defaults) do
      if first then
        first = false
      else
        strs[#strs + 1] = { " " }
      end
      strs[#strs + 1] = { k, "Bold" }
      strs[#strs + 1] = { "=" }
      if behavior.config[k] ~= nil then
        val = behavior.config[k]
      else
        val = v
      end
      strs[#strs + 1] = { (val == true and "on") or (val == false and "off") or tostring(val) }
    end
    vim.api.nvim_echo(strs, false, {})
  else
    for _, assignment in ipairs(tbl.fargs) do
      local idx_eql = string.find(assignment, "=", 1, true)
      if idx_eql then
        local opt_name = string.sub(assignment, 1, idx_eql - 1)
        ---@type string?
        local opt_val = string.sub(assignment, idx_eql + 1)
        if #opt_name == 0 then
          vim.api.nvim_echo({
            {
              "Attempted to assign value '" .. opt_val .. "' to an option, but did not specify the option name.",
              "ErrorMsg",
            },
          }, true, {})
          opt_val = nil
        elseif behavior.config[opt_name] == nil then
          vim.api.nvim_echo({
            { "'Unrecognized option name: ''" .. tostring(opt_name) .. "''", "ErrorMsg" },
          }, true, {})
          opt_val = nil
        elseif opt_val then
          if #opt_val == 0 then -- Resetting option
            ---@cast opt_val string
            opt_val = behavior.defaults[opt_name]
          end
        else -- This shouldn't occur!
          error("Nil option value")
        end
        if opt_val then
          if opt_val == "on" then
            behavior.config[opt_name] = true
          elseif opt_val == "off" then
            behavior.config[opt_name] = false
          else
            behavior.config[opt_name] = opt_val
          end
        elseif opt_val == false then -- opt_val is false
          behavior.config[opt_name] = opt_val
        else -- opt_val is nil
          error("Unexpected nil option value")
        end
      else -- No equals sign
        vim.cmd.echo("'" .. opt_name .. "=" .. tostring(opt_val) .. "'")
      end
    end
  end
end

local function set_options_complete(arglead)
  print(arglead)
  local n = #arglead
  if n == 0 then return vim.fn.keys(behavior.spec) end
  local opt_name, idx_eql = nil, string.find(arglead, "=", 1, true)

  if idx_eql then
    opt_name = string.sub(arglead, 1, idx_eql - 1) -- opt_val = string.sub(arglead, idx_eql + 1)
  else
    opt_name = arglead
  end

  local spec = #opt_name > 0 and behavior.spec[opt_name]
  if not spec then return {} end
  local pfx = opt_name .. "="
  return vim.fn.mapnew(spec, function(_, x) return pfx .. x end)
end

function M.setup(opts)
  -- Options
  opts = opts or {}

  local custom_key_maps, custom_key_remaps = opts.custom_key_maps or {}, opts.custom_key_remaps or {}

  local enable_split_paste = opts.enable_split_paste or true

  match_visible_only = opts.match_visible_only or true

  pre_hook = opts.pre_hook or nil
  post_hook = opts.post_hook or nil

  -- Set up extmarks
  extmarks.setup()

  -- Set up key maps
  key_maps.setup(default_key_maps, custom_key_maps, custom_key_remaps)

  -- Set up paste
  paste.setup(enable_split_paste)

  -- Autocmds
  autocmd_group_id = vim.api.nvim_create_augroup("MultipleCursors", {})

  vim.api.nvim_create_user_command("MultipleCursorsAddDown", function(_) M.add_cursor_down() end, { bar = true })
  vim.api.nvim_create_user_command("MultipleCursorsAddUp", function() M.add_cursor_up() end, { bar = true })

  vim.api.nvim_create_user_command(
    "MultipleCursorsMouseAddDelete",
    function(tbl) M.mouse_add_delete_cursor(tbl.bang) end,
    { bar = true }
  )

  vim.api.nvim_create_user_command("MultipleCursorsAddMatches", M.add_cursors_to_matches, { bar = true })
  vim.api.nvim_create_user_command("MultipleCursorsAddMatchesV", M.add_cursors_to_matches_v, { bar = true })

  vim.api.nvim_create_user_command(
    "MultipleCursorsAddJumpNextMatch",
    M.add_cursor_and_jump_to_next_match,
    { bar = true }
  )
  vim.api.nvim_create_user_command("MultipleCursorsJumpNextMatch", M.jump_to_next_match, { bar = true })

  vim.api.nvim_create_user_command("MultipleCursorsLock", M.lock, { bar = true })

  vim.api.nvim_create_user_command(
    "MultipleCursorsOptions",
    M.set_options,
    { bar = true, nargs = "*", complete = set_options_complete }
  )
end

return M
