---@diagnostic disable: undefined-doc-param
local M = {}

-- Path setup
local data_path = vim.fn.stdpath("data") .. "/def.nvim"
local fav_file = data_path .. "/favorites.json"
vim.fn.mkdir(data_path, "p")

-- Config
M.entries = {} -- in-memory favorites

-- Load favorites from disk
function M.load()
  local f = io.open(fav_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, tbl = pcall(vim.fn.json_decode, content)
    if ok and type(tbl) == "table" then
      M.entries = tbl
    end
  end
end

-- Save favorites to disk
function M.save()
  local f = io.open(fav_file, "w")
  if f then
    f:write(vim.fn.json_encode(M.entries))
    f:close()
  end
end

-- Add a word to favorites
---@param word string
function M.add(word)
  if not word or word == "" then
    return
  end

  -- Avoid duplicates
  for _, w in ipairs(M.entries) do
    if w == word then
      return
    end
  end

  table.insert(M.entries, word)
  M.save()
  vim.notify("Added to favorites: " .. word, vim.log.levels.INFO)
end

-- Remove a word from favorites
---@param word string
function M.remove(word)
  for i = #M.entries, 1, -1 do
    if M.entries[i] == word then
      table.remove(M.entries, i)
      M.save()
      vim.notify("Removed from favorites: " .. word, vim.log.levels.INFO)
      return
    end
  end
  vim.notify("Word not in favorites: " .. word, vim.log.levels.WARN)
end

-- Check if a word is in favorites
---@param word string
---@return boolean
function M.has(word)
  return vim.tbl_contains(M.entries, word)
end

-- Clear all favorites
function M.clear()
  M.entries = {}
  M.save()
  vim.notify("Cleared all favorites", vim.log.levels.INFO)
end

-- Get all favorites
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
      prompt_title = "Favorites",
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
