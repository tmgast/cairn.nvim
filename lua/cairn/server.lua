local uv = vim.uv or vim.loop
local util = require("cairn.util")

local M = {
  server = nil,
  socket_path = nil,
}

local function dispatch(method, params)
  local handlers = require("cairn.handlers")
  local h = handlers[method]
  if not h then
    return nil, { code = -32601, message = "method not found: " .. tostring(method) }
  end
  local ok, result = pcall(h, params or {})
  if not ok then
    return nil, { code = -32603, message = tostring(result) }
  end
  return result, nil
end

local function handle_line(client, line)
  local ok, msg = pcall(vim.json.decode, line)
  if not ok or type(msg) ~= "table" then return end

  local response = { id = msg.id }
  local result, err = dispatch(msg.method, msg.params)
  if err then
    response.error = err
  else
    response.result = result
  end

  local encoded = vim.json.encode(response) .. "\n"
  client:write(encoded)
end

local function accept_client(server)
  local client = uv.new_pipe(false)
  server:accept(client)
  local buffer = ""
  client:read_start(function(err, data)
    if err or not data then
      client:close()
      return
    end
    buffer = buffer .. data
    while true do
      local nl = buffer:find("\n", 1, true)
      if not nl then break end
      local line = buffer:sub(1, nl - 1)
      buffer = buffer:sub(nl + 1)
      vim.schedule(function() handle_line(client, line) end)
    end
  end)
end

function M.start()
  if M.server then
    pcall(function() M.server:close() end)
    M.server = nil
  end

  util.ensure_dirs()
  M.socket_path = util.socket_path()
  pcall(os.remove, M.socket_path)

  local server = uv.new_pipe(false)
  local ok, err = pcall(function() server:bind(M.socket_path) end)
  if not ok then
    vim.notify("cairn: bind failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  server:listen(16, function() accept_client(server) end)
  M.server = server

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if M.server then M.server:close() end
      pcall(os.remove, M.socket_path)
    end,
  })
end

function M.status()
  return {
    socket = M.socket_path,
    listening = M.server ~= nil,
    root = util.project_root(),
  }
end

return M
