local M = {}

-- +-------------------------------------------------------+
-- [                        Config                         ]
-- +-------------------------------------------------------+
local config = {
  width = 75,
  height = 36,
}

function M.setup(opts)
  for k, v in pairs(opts or {}) do
    config[k] = v
  end
end

--- Fetch word definition from online dictionary, including IPA
---@param word string
---@return table|nil
function M.get_winfo(word)
  if not word or word == "" then
    return nil
  end

  local ok, resp = pcall(function()
    return vim.fn.systemlist({
      "curl",
      "-s",
      "https://api.dictionaryapi.dev/api/v2/entries/en/" .. word,
    })
  end)
  if not ok or not resp or #resp == 0 then
    vim.notify("Failed to fetch definition for: " .. word, vim.log.levels.WARN)
    return nil
  end

  local ok_json, data = pcall(vim.fn.json_decode, table.concat(resp, "\n"))
  if not ok_json or type(data) ~= "table" or #data == 0 then
    vim.notify("No definition found for: " .. word, vim.log.levels.WARN)
    return nil
  end

  -- Extract IPA
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

  return #result > 0 and result or nil
end

--- Show word definition in floating window
---@param action? string
function M.lookup(action)
  action = action or "lookup"

  local function show_word(word)
    if not word or word == "" then
      vim.notify("No word provided", vim.log.levels.WARN)
      return
    end

    local def_table = M.get_winfo(word)
    local lines, highlights = {}, {}

    if def_table and def_table[1].ipa then
      table.insert(lines, "Pronunciation: " .. def_table[1].ipa)
      table.insert(highlights, { 0, 0, #lines[#lines], "Identifier" })
      table.insert(lines, "")
    end

    if def_table then
      for _, meaning in ipairs(def_table) do
        table.insert(lines, "(" .. meaning.partOfSpeech .. ")")
        table.insert(highlights, { #lines - 1, 0, #lines[#lines], "Keyword" })

        for _, d in ipairs(meaning.definitions) do
          table.insert(lines, "  - " .. d)
          table.insert(highlights, { #lines - 1, 2, 4, "Comment" })
          table.insert(highlights, { #lines - 1, 4, #lines[#lines], "Normal" })
        end
        table.insert(lines, "")
      end
    else
      table.insert(lines, "(Definition not found)")
      table.insert(highlights, { 0, 0, #lines[1], "ErrorMsg" })
    end

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local bufopts = { scope = "local", buf = buf }
    vim.api.nvim_set_option_value("modifiable", false, bufopts)
    vim.api.nvim_set_option_value("bufhidden", "wipe", bufopts)

    -- Add highlights
    local ns = vim.api.nvim_create_namespace("")
    for _, hl in ipairs(highlights) do
      local line, start_col, end_col, group = unpack(hl)
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

    -- Map 'q' to close
    require("utils.map").nmap("q", function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true })
  end

  if action == "word" then
    show_word(vim.fn.expand("<cword>"))
  else
    vim.ui.input({ prompt = "Word to look up: " }, show_word)
  end
end

return M
