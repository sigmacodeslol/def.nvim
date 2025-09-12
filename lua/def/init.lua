---@diagnostic disable: undefined-doc-param
local M = {}

-- +-------------------------------------------------------+
-- [                        Config                         ]
-- +-------------------------------------------------------+
local config = {
  width = 75,
  height = 36,
}

function M.setup(opts)
  if opts then
    for k, v in pairs(opts) do
      config[k] = v
    end
  end
end

--- Show remap help inside the buffer
---@param _win number
---@param _buf number
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

--- Fetch word definition from online dictionary, including IPA
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
            definitions = vim.tbl_map(function(def)
              return def.definition
            end, meaning.definitions or {}),
            ipa = ipa,
          })
        end

        callback(#result > 0 and result or nil)
      end)
    end
  )
end

--- Show word definition in floating window
---@param action? string
function M.lookup(action)
  action = action or "lookup"

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

        -- IPA
        if def_table and def_table[1].ipa then
          table.insert(lines, "Pronunciation: " .. def_table[1].ipa)
          table.insert(highlights, { 0, 0, #lines[#lines], "String" })
          table.insert(lines, "")
        end

        -- Definitions
        if def_table then
          for _, meaning in ipairs(def_table) do
            table.insert(lines, "(" .. meaning.partOfSpeech .. ")")
            table.insert(
              highlights,
              { #lines - 1, 0, #lines[#lines], "Keyword" }
            )

            for _, def in ipairs(meaning.definitions) do
              table.insert(lines, "  - " .. def)
              table.insert(highlights, { #lines - 1, 2, 4, "Comment" })
              table.insert(
                highlights,
                { #lines - 1, 4, #lines[#lines], "Normal" }
              )
            end
            table.insert(lines, "")
          end
        else
          lines = { "(Definition not found)" }
          highlights = { { 0, 0, #lines[1], "ErrorMsg" } }
        end

        -- Create buffer and set options
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
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

        -- Apply highlights
        for _, hl in ipairs(highlights) do
          local line, start_col, end_col, group = unpack(hl)
          ---@cast line integer
          ---@cast start_col integer
          ---@cast end_col integer
          vim.api.nvim_buf_set_extmark(
            buf,
            ns,
            line,
            start_col,
            { end_col = end_col, hl_group = group }
          )
        end

        -- Open floating window
        local width, height = config.width, math.min(config.height, #lines + 2)
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

        -- Keymaps: close window
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

        -- Show help
        vim.keymap.set(
          "n",
          "?",
          show_remap_help,
          { buffer = buf, nowait = true, noremap = true, silent = true }
        )
      end)
    end)
  end

  if action == "word" then
    show_word(vim.fn.expand("<cword>"))
  else
    vim.ui.input({ prompt = "Word to look up: " }, show_word)
  end
end

return M
