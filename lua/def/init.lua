---@diagnostic disable: undefined-doc-param

-- +-------------------------------------------------------+
-- [                       def.nvim                        ]
-- +-------------------------------------------------------+
local M = {}
local hh = require("def.history")
local fn = require("def.f").fn

-- +-------------------------------------------------------+
-- [                        Config                         ]
-- +-------------------------------------------------------+
local config = {
  width = 75,
  height = 36,
}

-- +-------------------------------------------------------+
-- [                        Setup                          ]
-- +-------------------------------------------------------+
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
local function get_max_line_length(lines)
  local max_len = 0
  for _, line in ipairs(lines) do
    local len = vim.str_utfindex(line, "utf-8")
    if len > max_len then
      max_len = len
    end
  end
  return max_len
end

-- +-------------------------------------------------------+
-- [                  Show Remap Help                      ]
-- +-------------------------------------------------------+
local function show_remap_help()
  local help_lines = {
    "keymaps:",
    "",
    "  q / <Esc>  → Close the window",
    "  ?          → Show this help",
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
  vim.api.nvim_set_option_value(
    "modifiable",
    false,
    { scope = "local", buf = buf }
  )
  vim.api.nvim_set_option_value(
    "bufhidden",
    "wipe",
    { scope = "local", buf = buf }
  )

  local width, height = 40, #help_lines + 2
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = "[ Help ]",
  })

  local map = vim.keymap.set
  for _, key in ipairs({ "q", "<Esc>" }) do
    map("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, noremap = true, silent = true })
  end
end

-- +-------------------------------------------------------+
-- [                   Show Word Window                    ]
-- +-------------------------------------------------------+
local function show_word(word)
  if not word or word == "" then
    return vim.notify("No word provided", vim.log.levels.WARN)
  end

  -- Loading window
  local loading_buf = vim.api.nvim_create_buf(false, true)
  local loading_msg = "Loading definition for: " .. word .. " ..."
  vim.api.nvim_buf_set_lines(loading_buf, 0, -1, false, { loading_msg })

  local loading_width = math.max(40, #loading_msg + 2)
  local loading_win = vim.api.nvim_open_win(loading_buf, true, {
    relative = "editor",
    width = loading_width,
    height = 3,
    col = (vim.o.columns - loading_width) / 2,
    row = (vim.o.lines - 3) / 2,
    style = "minimal",
    border = "rounded",
    title = "[def.nvim]",
  })

  -- Fetch definition asynchronously
  M.get_winfo(word, function(def_table)
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(loading_win) then
        vim.api.nvim_win_close(loading_win, true)
      end

      local lines, highlights = {}, {}
      local ns = vim.api.nvim_create_namespace("def_lookup")

      if def_table then
        if def_table[1].ipa then
          table.insert(lines, "Pronunciation: " .. def_table[1].ipa)
          table.insert(highlights, { 0, 0, #lines[#lines], "String" })
          table.insert(lines, "")
        end
        for _, meaning in ipairs(def_table) do
          table.insert(lines, "(" .. meaning.partOfSpeech .. ")")
          table.insert(highlights, { #lines - 1, 0, #lines[#lines], "Keyword" })

          for _, defi in ipairs(meaning.definitions) do
            table.insert(lines, "  - " .. defi.definition)
            table.insert(highlights, { #lines - 1, 2, 4, "Comment" })
            table.insert(
              highlights,
              { #lines - 1, 4, #lines[#lines], "Normal" }
            )

            -- Example
            if defi.example then
              table.insert(lines, "    Example: " .. defi.example)
              table.insert(highlights, { #lines - 1, 4, 12, "Keyword" })
              table.insert(
                highlights,
                { #lines - 1, 12, #lines[#lines], "String" }
              )
            end

            -- Definition Synonyms
            if defi.synonyms and #defi.synonyms > 0 then
              table.insert(
                lines,
                "    Synonyms: " .. table.concat(defi.synonyms, ", ")
              )
              table.insert(highlights, { #lines - 1, 4, 13, "Keyword" })
              table.insert(
                highlights,
                { #lines - 1, 13, #lines[#lines], "Identifier" }
              )
            end

            -- Definition Antonyms
            if defi.antonyms and #defi.antonyms > 0 then
              table.insert(
                lines,
                "    Antonyms: " .. table.concat(defi.antonyms, ", ")
              )
              table.insert(highlights, { #lines - 1, 4, 12, "Keyword" })
              table.insert(
                highlights,
                { #lines - 1, 12, #lines[#lines], "Identifier" }
              )
            end
          end
        end
        if def_table[1].synonyms and #def_table[1].synonyms > 0 then
          table.insert(lines, "")
          table.insert(
            lines,
            "synonyms: " .. table.concat(def_table[1].synonyms, ", ")
          )
          table.insert(highlights, { #lines - 1, 0, 8, "Keyword" })
          table.insert(
            highlights,
            { #lines - 1, 10, #lines[#lines], "Identifier" }
          )
        end
        if def_table[1].antonyms and #def_table[1].antonyms > 0 then
          table.insert(
            lines,
            "antonyms: " .. table.concat(def_table[1].antonyms, ", ")
          )
          table.insert(highlights, { #lines - 1, 0, 8, "Keyword" })
          table.insert(
            highlights,
            { #lines - 1, 10, #lines[#lines], "Identifier" }
          )
        end
        table.insert(lines, "")
      else
        lines = { "(Definition not found)" }
        highlights = { { 0, 0, #lines[1], "ErrorMsg" } }

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local bufopts = { scope = "local", buf = buf }
        vim.api.nvim_set_option_value("modifiable", false, bufopts)
        vim.api.nvim_set_option_value("bufhidden", "wipe", bufopts)

        local width = math.min(config.width, math.max(40, #lines[1] + 4))
        local height = 3
        local win = vim.api.nvim_open_win(buf, false, {
          relative = "editor",
          width = width,
          height = height,
          col = (vim.o.columns - width) / 2,
          row = (vim.o.lines - height) / 2,
          style = "minimal",
          border = "rounded",
          title = "[word] " .. word,
        })
        ---@diagnostic disable-next-line: redefined-local
        local bufopts = { scope = "local", buf = buf }
        vim.api.nvim_set_option_value("modifiable", false, bufopts)
        vim.api.nvim_set_option_value("bufhidden", "wipe", bufopts)

        vim.defer_fn(function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end, 2000) -- 2000 ms = 2 seconds
        return
      end

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      local bufopts = { scope = "local", buf = buf }
      vim.api.nvim_set_option_value("modifiable", false, bufopts)
      vim.api.nvim_set_option_value("bufhidden", "wipe", bufopts)

      for _, hl in ipairs(highlights) do
        local line, s, e, group = unpack(hl)
        ---@cast line integer
        ---@cast s integer
        local _opts = { end_col = e, hl_group = group }
        vim.api.nvim_buf_set_extmark(buf, ns, line, s, _opts)
      end

      local max_line_len = get_max_line_length(lines)
      local width = math.min(config.width, math.max(40, max_line_len + 4))
      local height = math.min(config.height, #lines + 2)

      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = (vim.o.columns - width) / 2,
        row = (vim.o.lines - height) / 2,
        style = "minimal",
        border = "rounded",
        title = "[word] " .. word,
      })
      vim.wo[win].wrap = true
      vim.wo[win].linebreak = true
      vim.wo[win].breakindent = true

      local map = vim.keymap.set
      local opts = {
        buffer = buf,
        nowait = true,
        noremap = true,
        silent = true,
      }
      for _, key in ipairs({ "q", "<Esc>" }) do
        map("n", key, function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end, opts)
      end

      map("n", "?", show_remap_help, opts)

      hh.add(word)
    end)
  end)
end

-- +-------------------------------------------------------+
-- [                  Fetch Word Definition               ]
-- +-------------------------------------------------------+
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

        -- Get IPA if available
        local ipa
        if data[1].phonetics then
          for _, ph in ipairs(data[1].phonetics) do
            if ph.text and ph.text ~= "" then
              ipa = ph.text
              break
            end
          end
        end

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
---@param action? '"lookup"'|'"word"'|'"wotd"'|'"history"'
function M.lookup(action)
  action = action or "lookup"

  local actions = {
    word = function()
      show_word(vim.fn.expand("<cword>"))
    end,
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
