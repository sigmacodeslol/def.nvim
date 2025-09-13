local M = {}

function M.fn(f, ...)
  local args = { ... }
  return function(...)
    f(unpack(args), ...)
  end
end

---Return the first non-empty value for a given key in a table
---@param tbl table[]
---@param key string
---@param fallback any
---@return any
function M.first_nonempty(tbl, key, fallback)
  for _, v in ipairs(tbl or {}) do
    if v[key] and v[key] ~= "" then
      return v[key]
    end
  end
  return fallback
end
return M
