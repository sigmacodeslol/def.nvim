local M = {}

function M.fn(f, ...)
  local args = { ... }
  return function(...)
    f(unpack(args), ...)
  end
end

return M
