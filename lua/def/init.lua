---@diagnostic disable: undefined-doc-param
local M = {}

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

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
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

      if def_table and def_table[1].ipa then
        table.insert(lines, "Pronunciation: " .. def_table[1].ipa)
        table.insert(highlights, { 0, 0, #lines[#lines], "String" })
        table.insert(lines, "")
      end

      if def_table then
        for _, meaning in ipairs(def_table) do
          table.insert(lines, "(" .. meaning.partOfSpeech .. ")")
          table.insert(highlights, { #lines - 1, 0, #lines[#lines], "Keyword" })

          for _, def in ipairs(meaning.definitions) do
            table.insert(lines, "  - " .. def)
            table.insert(highlights, { #lines - 1, 2, 4, "Comment" })
            table.insert(
              highlights,
              { #lines - 1, 4, #lines[#lines], "Normal" }
            )

            -- Example
            if def.example then
              table.insert(lines, "    Example: " .. def.example)
              table.insert(highlights, { #lines - 1, 4, 12, "Keyword" })
              table.insert(
                highlights,
                { #lines - 1, 12, #lines[#lines], "String" }
              )
            end

            -- Synonyms
            if def.synonyms and #def.synonyms > 0 then
              table.insert(
                lines,
                "    Synonyms: " .. table.concat(def.synonyms, ", ")
              )
              table.insert(highlights, { #lines - 1, 4, 13, "Keyword" })
              table.insert(
                highlights,
                { #lines - 1, 13, #lines[#lines], "Identifier" }
              )
            end

            -- Antonyms
            if def.antonyms and #def.antonyms > 0 then
              table.insert(
                lines,
                "    Antonyms: " .. table.concat(def.antonyms, ", ")
              )
              table.insert(highlights, { #lines - 1, 4, 12, "Keyword" })
              table.insert(
                highlights,
                { #lines - 1, 12, #lines[#lines], "Identifier" }
              )
            end
          end
          table.insert(lines, "")
        end
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

      for _, key in ipairs({ "q", "<Esc>" }) do
        vim.keymap.set("n", key, function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end, {
          buffer = buf,
          nowait = true,
          noremap = true,
          silent = true,
        })
      end

      vim.keymap.set(
        "n",
        "?",
        show_remap_help,
        { buffer = buf, nowait = true, noremap = true, silent = true }
      )
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
          table.insert(result, {
            partOfSpeech = meaning.partOfSpeech,
            definitions = meaning.definitions or {},
            ipa = ipa,
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
---@param action? string
function M.lookup(action)
  action = action or "lookup"

  if action == "word" then
    show_word(vim.fn.expand("<cword>"))
  else
    vim.ui.input({ prompt = "Word to look up: " }, show_word)
  end
end

-- +-------------------------------------------------------+
-- [                        Return                         ]
-- +-------------------------------------------------------+
return M
