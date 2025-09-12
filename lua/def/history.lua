---@diagnostic disable: undefined-doc-param
local M = {}

-- Path setup
local data_path = vim.fn.stdpath("data") .. "/def.nvim"
local history_file = data_path .. "/history.json"
vim.fn.mkdir(data_path, "p")

-- Config
M.max_size = 50
M.entries = {} -- in-memory history

-- Load history from disk
function M.load()
  local f = io.open(history_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, tbl = pcall(vim.fn.json_decode, content)
    if ok and type(tbl) == "table" then
      M.entries = tbl
    end
  end
end

-- Save history to disk
function M.save()
  local f = io.open(history_file, "w")
  if f then
    f:write(vim.fn.json_encode(M.entries))
    f:close()
  end
end

-- Add a word to history
---@param word string
function M.add(word)
  if not word or word == "" then
    return
  end

  -- Remove duplicates
  for i = #M.entries, 1, -1 do
    if M.entries[i] == word then
      table.remove(M.entries, i)
    end
  end

  table.insert(M.entries, 1, word) -- newest first

  -- Enforce max size
  if #M.entries > M.max_size then
    table.remove(M.entries)
  end

  M.save()
end

-- Clear history
function M.clear()
  M.entries = {}
  M.save()
end

-- Get a copy of the current history
---@return string[]
function M.get()
  return vim.tbl_deep_extend("force", {}, M.entries)
end

-- Telescope picker integration
function M.telescope_picker(show_word)
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    vim.notify("Telescope not found", vim.log.levels.WARN)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = "Word History",
      finder = finders.new_table({
        results = M.entries,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and show_word then
            show_word(selection[1])
          end
        end)
        return true
      end,
    })
    :find()
end

-- Initialize
M.load()

return M
