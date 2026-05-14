local M = {
  ns = nil,
  marks = {},
  snapshots = {},
}

function M.namespace()
  if not M.ns then
    M.ns = vim.api.nvim_create_namespace("cairn")
  end
  return M.ns
end

function M.add(group, bufnr, mark_id)
  M.marks[group] = M.marks[group] or {}
  M.marks[group][bufnr] = M.marks[group][bufnr] or {}
  table.insert(M.marks[group][bufnr], mark_id)
end

function M.clear_group(group)
  if not M.marks[group] then return 0 end
  local ns = M.namespace()
  local count = 0
  for bufnr, ids in pairs(M.marks[group]) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      for _, id in ipairs(ids) do
        pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, id)
        count = count + 1
      end
    end
  end
  M.marks[group] = nil
  return count
end

function M.clear_all()
  local ns = M.namespace()
  local total = 0
  for group, _ in pairs(M.marks) do
    total = total + M.clear_group(group)
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
      local orphans = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      for _, m in ipairs(orphans) do
        pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, m[1])
        total = total + 1
      end
    end
  end
  return total
end

return M
