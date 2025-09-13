---@diagnostic disable: undefined-doc-param

-- +-------------------------------------------------------+
-- [                       def.nvim                        ]
-- +-------------------------------------------------------+
local M = {}
local config = require("def.config")
local ui = require("def.ui")(config)
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
-- [                   Helper Functions                    ]
-- +-------------------------------------------------------+

---Return the first non-empty value for a given key in a table
---@param tbl table[]
---@param key string
---@param fallback any
---@return any
local function first_nonempty(tbl, key, fallback)
  for _, v in ipairs(tbl or {}) do
    if v[key] and v[key] ~= "" then
      return v[key]
    end
  end
  return fallback
end

---Show a word definition window
---@param word string
local function show_word(word)
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
  M.get_winfo(word, function(def_table)
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

-- +-------------------------------------------------------+
-- [                  Fetch Word Definition               ]
-- +-------------------------------------------------------+
---Fetch word definition
---@param word string
---@param callback fun(result: table|nil)
function M.get_winfo(word, callback)
  if not word or word == "" then
    callback(nil)
    return
  end

  vim.system(
    { "curl", "-s", "https://api.dictionaryapi.dev/api/v2/entries/en/" .. word },
    { text = true },
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          vim.notify(
            "Failed to fetch definition for: " .. word,
            vim.log.levels.WARN
          )
          callback(nil)
          return
        end

        local ok, data = pcall(vim.json.decode, obj.stdout)
        if not ok or type(data) ~= "table" or #data == 0 then
          vim.notify("No definition found for: " .. word, vim.log.levels.WARN)
          callback(nil)
          return
        end

        local ipa = data[1].phonetic
          or first_nonempty(data[1].phonetics, "text")
        local result = {}

        for _, meaning in ipairs(data[1].meanings or {}) do
          local defs = {}
          for _, d in ipairs(meaning.definitions or {}) do
            table.insert(defs, {
              definition = d.definition,
              example = d.example,
              synonyms = d.synonyms or {},
              antonyms = d.antonyms or {},
            })
          end

          table.insert(result, {
            partOfSpeech = meaning.partOfSpeech,
            ipa = ipa,
            definitions = defs,
            synonyms = meaning.synonyms or {},
            antonyms = meaning.antonyms or {},
          })
        end

        callback(#result > 0 and result or nil)
      end)
    end
  )
end

-- +-------------------------------------------------------+
-- [                   Public Lookup                       ]
-- +-------------------------------------------------------+
---@param action? '"lookup"'|'"word"'|'"wotd"'|'"history"'|'"favorites"'
function M.lookup(action)
  action = action or "lookup"

  local actions = {
    word = fn(show_word, vim.fn.expand("<cword>"):lower()),
    lookup = function()
      vim.ui.input({ prompt = "Word to look up: " }, show_word)
    end,
    wotd = function()
      vim.system({
        "curl",
        "-s",
        "https://random-word-api.vercel.app/api?words=1&length="
          .. math.random(3, 9),
      }, { text = true }, function(obj)
        vim.schedule(function()
          local ok, words = pcall(vim.fn.json_decode, obj.stdout)
          if ok and type(words) == "table" and words[1] then
            show_word(words[1])
          else
            vim.notify("Failed to fetch random word", vim.log.levels.WARN)
          end
        end)
      end)
    end,
    history = fn(hh.telescope_picker, show_word),
    favorites = fn(favs.telescope_picker, show_word),
  }

  if actions[action] then
    actions[action]()
  else
    vim.notify("Invalid action: " .. action, vim.log.levels.ERROR)
  end
end

-- +-------------------------------------------------------+
-- [                        Return                         ]
-- +-------------------------------------------------------+
return M
