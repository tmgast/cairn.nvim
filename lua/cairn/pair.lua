local util = require("cairn.util")

local M = {
  enabled = false,
  last_seen = {},
  queue_path = nil,
  setup_done = false,
}

local function snapshot(bufnr)
  if not vim.api.nvim_buf_is_loaded(bufnr) then return nil end
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

local function compute_diff(old, new)
  local ok, result = pcall(vim.diff, old, new, { result_type = "unified", ctxlen = 3 })
  if ok then return result end
  return nil
end

local function refresh_baseline(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  M.last_seen[bufnr] = snapshot(bufnr) or ""
end

local function on_save(bufnr)
  if not M.enabled then return end
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" or not vim.api.nvim_buf_is_valid(bufnr) then return end

  local current = snapshot(bufnr) or ""
  local old = M.last_seen[bufnr]
  if not old then
    M.last_seen[bufnr] = current
    return
  end

  local diff = compute_diff(old, current)
  M.last_seen[bufnr] = current
  if not diff or diff == "" then return end

  local cursor_line = 0
  local win = vim.fn.bufwinid(bufnr)
  if win ~= -1 then
    cursor_line = vim.api.nvim_win_get_cursor(win)[1]
  end

  local entry = {
    timestamp = os.time(),
    file = path,
    cursor_line = cursor_line,
    diff = diff,
  }

  local fd = io.open(M.queue_path, "a")
  if fd then
    fd:write(vim.json.encode(entry) .. "\n")
    fd:close()
  end
end

function M.setup()
  if M.setup_done then return end
  M.setup_done = true
  M.queue_path = util.queue_path()

  local group = vim.api.nvim_create_augroup("cairn_pair", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      vim.schedule(function() on_save(args.buf) end)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufReadPost", "FileChangedShellPost" }, {
    group = group,
    callback = function(args)
      vim.schedule(function() refresh_baseline(args.buf) end)
    end,
  })
end

function M.is_enabled()
  return M.enabled
end

function M.toggle(arg)
  if arg == "on" then
    M.enabled = true
  elseif arg == "off" then
    M.enabled = false
  else
    M.enabled = not M.enabled
  end
  vim.notify("cairn: pair mode " .. (M.enabled and "ON" or "OFF"))
  return M.enabled
end

return M
