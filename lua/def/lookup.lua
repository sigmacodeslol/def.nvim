local M = {}

local hh = require("def.history")
local api = require("def.api")
local ui = require("def.ui")(require("def.config"))
local favs = require("def.favorites")
local f = require("def.f")
local fn = f.fn
local first_nonempty = f.first_nonempty

---Show a word definition window
---@param word string
function M.show_word(word)
  if not word or word == "" then
    return vim.notify("No word provided", vim.log.levels.WARN)
  end

  -- Show loading
  local loading_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(
    loading_buf,
    0,
    -1,
    false,
    { "Loading definition for: " .. word .. " ..." }
  )
  local loading_win = vim.api.nvim_open_win(loading_buf, true, {
    relative = "editor",
    width = math.max(40, #word + 20),
    height = 3,
    col = (vim.o.columns - 40) / 2,
    row = (vim.o.lines - 3) / 2,
    style = "minimal",
    border = "rounded",
    title = "[def.nvim]",
  })

  -- Fetch definition asynchronously
  api.get_winfo(word, function(def_table)
    local function close_win(win)
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(loading_win) then
        vim.api.nvim_win_close(loading_win, true)
      end

      if not def_table then
        local error_win = ui.create_float(
          { "(Definition not found)" },
          { { 0, 0, 22, "ErrorMsg" } },
          "word",
          word
        )

        vim.defer_fn(fn(close_win, error_win), 2000)
        return
      end

      local lines, highlights = ui.build_definition_lines(def_table)
      local fav_mark = favs.has(word) and "" or ""
      local win =
        ui.create_float(lines, highlights, "word", word, fav_mark, true)

      local opts = {
        buffer = vim.api.nvim_win_get_buf(win),
        nowait = true,
        noremap = true,
        silent = true,
      }
      for _, key in ipairs({ "q", "<Esc>" }) do
        vim.keymap.set("n", key, fn(close_win, win), opts)
      end
      vim.keymap.set("n", "?", ui.show_remap_help, opts)
      vim.keymap.set("n", "ga", fn(favs.add, word), opts)
      vim.keymap.set("n", "gA", fn(favs.remove, word), opts)

      hh.add(word)
    end)
  end)
end

return M
