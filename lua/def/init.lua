-- +-------------------------------------------------------+
-- [                       def.nvim                        ]
-- +-------------------------------------------------------+
local M = {}
local config = require("def.config")
local api = require("def.api")
local lookup = require("def.lookup")
local hh = require("def.history")
local favs = require("def.favorites")
local fn = require("def.f").fn

-- +-------------------------------------------------------+
-- [                        Setup                          ]
-- +-------------------------------------------------------+
---Setup the plugin configuration
---@param opts table?
function M.setup(opts)
  if opts then
    for k, v in pairs(opts) do
      config[k] = v
    end
  end
end

-- +-------------------------------------------------------+
-- [                   Public Lookup                       ]
-- +-------------------------------------------------------+
---@param action? '"lookup"'|'"word"'|'"wotd"'|'"history"'|'"favorites"'
function M.lookup(action)
  action = action or "lookup"

  local actions = {
    word = fn(lookup.show_word, vim.fn.expand("<cword>"):lower()),
    lookup = function()
      vim.ui.input({ prompt = "Word to look up: " }, lookup.show_word)
    end,
    wotd = fn(lookup.show_word, api.wotd()),
    history = fn(hh.telescope_picker, lookup.show_word),
    favorites = fn(favs.telescope_picker, lookup.show_word),
  }

  if actions[action] then
    actions[action]()
  else
    vim.notify("Invalid action: " .. action, vim.log.levels.ERROR)
  end
end

return M
