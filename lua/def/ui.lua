local M = {}
local config

---Get the maximum UTF-8 line length
---@param lines string[]
---@return integer
function M.get_max_line_length(lines)
  local max_len = 0
  for _, line in ipairs(lines) do
    local len = vim.str_utfindex(line, "utf-8")
    if len > max_len then
      max_len = len
    end
  end
  return max_len
end

---Build lines and highlights from API definition data
---@param def_table table
---@return string[] lines
---@return table[] highlights
function M.build_definition_lines(def_table)
  local lines, highlights = {}, {}
  local ns = vim.api.nvim_create_namespace("def_lookup")

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
      table.insert(highlights, { #lines - 1, 4, #lines[#lines], "Normal" })

      if defi.example then
        table.insert(lines, "    Example: " .. defi.example)
        table.insert(highlights, { #lines - 1, 4, 12, "Keyword" })
        table.insert(highlights, { #lines - 1, 12, #lines[#lines], "String" })
      end

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
    table.insert(lines, "")
  end

  local syn = def_table[1].synonyms
  if syn and #syn > 0 then
    table.insert(lines, "synonyms: " .. table.concat(syn, ", "))
    table.insert(highlights, { #lines - 1, 0, 10, "Keyword" })
    table.insert(highlights, { #lines - 1, 10, #lines[#lines], "Identifier" })
  end

  local ant = def_table[1].antonyms
  if ant and #ant > 0 then
    table.insert(lines, "antonyms: " .. table.concat(ant, ", "))
    table.insert(highlights, { #lines - 1, 4, 12, "Keyword" })
    table.insert(highlights, { #lines - 1, 12, #lines[#lines], "Identifier" })
  end

  return lines, highlights
end

---Display help keymaps
function M.show_remap_help()
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

---Create a floating window with content
---@param lines string[]
---@param highlights table[]
---@param title string
---@param word string
---@param fav_mark string?
---@param enter boolean?
---@return integer win
function M.create_float(lines, highlights, title, word, fav_mark, enter)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local bufopts = { scope = "local", buf = buf }
  vim.api.nvim_set_option_value("modifiable", false, bufopts)
  vim.api.nvim_set_option_value("bufhidden", "wipe", bufopts)

  local ns = vim.api.nvim_create_namespace("def_lookup")
  for _, hl in ipairs(highlights) do
    local line, s, e, group = unpack(hl)
    local _opts = { end_col = e, hl_group = group }
    vim.api.nvim_buf_set_extmark(buf, ns, line, s, _opts)
  end

  local max_line_len = M.get_max_line_length(lines)
  local width = math.min(config.width, math.max(40, max_line_len + 4))
  local height = math.min(config.height, #lines + 2)
  local win_title = fav_mark and "[" .. fav_mark .. " " .. title .. "]"
    or "[" .. title .. "]"

  win_title = win_title .. " " .. word

  local win = vim.api.nvim_open_win(buf, enter == true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = win_title,
  })

  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true

  return win
end

return function(opts)
  config = opts
  return M
end
