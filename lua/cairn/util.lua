local M = {}

function M.project_root()
  local cwd = vim.fn.getcwd()
  local result = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and result[1] and result[1] ~= "" then
    return result[1]
  end
  return cwd
end

function M.root_hash(root)
  return vim.fn.sha256(root):sub(1, 16)
end

function M.runtime_dir()
  return os.getenv("XDG_RUNTIME_DIR")
    or os.getenv("TMPDIR")
    or "/tmp"
end

function M.state_dir()
  return os.getenv("XDG_STATE_HOME")
    or (os.getenv("HOME") .. "/.local/state")
end

function M.socket_path()
  return M.runtime_dir() .. "/cairn/" .. M.root_hash(M.project_root()) .. ".sock"
end

function M.queue_path()
  return M.state_dir() .. "/cairn/queue-" .. M.root_hash(M.project_root()) .. ".jsonl"
end

function M.ensure_dirs()
  vim.fn.mkdir(vim.fn.fnamemodify(M.socket_path(), ":h"), "p")
  vim.fn.mkdir(vim.fn.fnamemodify(M.queue_path(), ":h"), "p")
end

return M
