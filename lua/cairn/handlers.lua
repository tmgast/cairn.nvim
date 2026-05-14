local util = require("cairn.util")
local state = require("cairn.state")

local M = {}

local function resolve_path(path)
  if not path or path == "" then
    error("path is required")
  end
  if path:sub(1, 1) ~= "/" then
    path = util.project_root() .. "/" .. path
  end
  return vim.fn.fnamemodify(path, ":p")
end

local function get_or_load_buffer(path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr == -1 then
    bufnr = vim.fn.bufadd(path)
    vim.fn.bufload(bufnr)
  end
  return bufnr
end

local function clamp_line(bufnr, line)
  local last = vim.api.nvim_buf_line_count(bufnr)
  if line > last then line = last end
  if line < 1 then line = 1 end
  return line
end

local function focus_buffer(bufnr, line)
  local found = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      vim.api.nvim_set_current_win(win)
      found = true
      break
    end
  end
  if not found then
    vim.cmd("buffer " .. bufnr)
  end
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  vim.cmd("normal! zz")
end

function M.status(_)
  local server = require("cairn.server")
  local pair = require("cairn.pair")
  local s = server.status()
  return {
    connected = true,
    root = s.root,
    socket = s.socket,
    pair_mode = pair.is_enabled(),
    version = "0.0.1",
  }
end

function M.open(params)
  local path = resolve_path(params.path)

  if vim.fn.filereadable(path) ~= 1 then
    return { ok = false, error = "file not readable: " .. path }
  end

  local split = params.split or "none"
  local cmd = "edit"
  if split == "horizontal" then cmd = "split"
  elseif split == "vertical" then cmd = "vsplit" end

  vim.cmd(cmd .. " " .. vim.fn.fnameescape(path))

  local bufnr = vim.api.nvim_get_current_buf()
  local line = params.line and math.floor(params.line) or nil
  if line then
    local last = vim.api.nvim_buf_line_count(bufnr)
    if line > last then line = last end
    if line < 1 then line = 1 end
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    vim.cmd("normal! zz")
  end

  return {
    ok = true,
    file = path,
    bufnr = bufnr,
    line = line or vim.api.nvim_win_get_cursor(0)[1],
    split = split,
  }
end

function M.view(_)
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  return {
    ok = true,
    file = file ~= "" and file or nil,
    bufnr = bufnr,
    line = cursor[1],
    col = cursor[2] + 1,
    viewport_top = vim.fn.line("w0"),
    viewport_bottom = vim.fn.line("w$"),
    modified = vim.bo[bufnr].modified,
    filetype = vim.bo[bufnr].filetype,
  }
end

function M.highlight(params)
  local path = resolve_path(params.path)
  if vim.fn.filereadable(path) ~= 1 then
    return { ok = false, error = "file not readable: " .. path }
  end
  if not params.start_line or not params.end_line then
    return { ok = false, error = "start_line and end_line are required" }
  end

  local bufnr = get_or_load_buffer(path)
  local start_line = clamp_line(bufnr, math.floor(params.start_line))
  local end_line = clamp_line(bufnr, math.floor(params.end_line))
  if end_line < start_line then end_line = start_line end

  local group = params.group or "tour"
  local label = params.label

  local virt_text = nil
  if label and label ~= "" then
    virt_text = { { "  " .. label, "CairnLabel" } }
  end

  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, state.namespace(), start_line - 1, 0, {
    end_row = end_line,
    end_col = 0,
    hl_group = "CairnHighlight",
    hl_eol = true,
    virt_text = virt_text,
    virt_text_pos = "eol",
  })
  state.add(group, bufnr, mark_id)

  if params.focus ~= false then
    focus_buffer(bufnr, start_line)
  end

  return {
    ok = true,
    file = path,
    bufnr = bufnr,
    start_line = start_line,
    end_line = end_line,
    group = group,
    mark_id = mark_id,
    focused = params.focus ~= false,
  }
end

function M.clear(params)
  local count
  if params.group and params.group ~= "" then
    count = state.clear_group(params.group)
  else
    count = state.clear_all()
  end
  return { ok = true, cleared = count }
end

function M.only(params)
  if params.path and params.path ~= "" then
    local path = resolve_path(params.path)
    if vim.fn.filereadable(path) ~= 1 then
      return { ok = false, error = "file not readable: " .. path }
    end
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  end

  pcall(vim.cmd, "diffoff!")
  vim.cmd("only")
  pcall(vim.api.nvim_win_set_hl_ns, 0, 0)

  local cur = vim.api.nvim_get_current_buf()
  local closed = 0
  if params.close_buffers then
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if b ~= cur and vim.bo[b].buflisted then
        if pcall(vim.cmd, "silent bdelete " .. b) then
          closed = closed + 1
        end
      end
    end
  end

  return {
    ok = true,
    current_buffer = cur,
    current_file = vim.api.nvim_buf_get_name(cur),
    buffers_closed = closed,
  }
end

local suggest_ns = nil
local function ensure_suggest_ns()
  if suggest_ns then return suggest_ns end
  suggest_ns = vim.api.nvim_create_namespace("cairn_suggest_diff")
  vim.api.nvim_set_hl(suggest_ns, "DiffAdd", { link = "CairnDiffSuggestAdd" })
  vim.api.nvim_set_hl(suggest_ns, "DiffDelete", { link = "CairnDiffSuggestDelete" })
  vim.api.nvim_set_hl(suggest_ns, "DiffChange", { link = "CairnDiffSuggestChange" })
  vim.api.nvim_set_hl(suggest_ns, "DiffText", { link = "CairnDiffSuggestText" })
  return suggest_ns
end

local function setup_scratch(content_lines, base_ft, name)
  vim.cmd("enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, content_lines)
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = base_ft
  vim.bo.modifiable = false
  if name then pcall(vim.api.nvim_buf_set_name, 0, name) end
end

function M.diff_git(params)
  local path = resolve_path(params.path)
  if vim.fn.filereadable(path) ~= 1 then
    return { ok = false, error = "file not readable: " .. path }
  end
  local ref = (params.ref and params.ref ~= "") and params.ref or "HEAD"
  local root = util.project_root()
  local relpath = path:sub(#root + 2)

  vim.cmd("edit " .. vim.fn.fnameescape(path))
  local base_win = vim.api.nvim_get_current_win()
  local base_ft = vim.bo.filetype
  pcall(vim.api.nvim_win_set_hl_ns, base_win, 0)
  vim.cmd("diffthis")

  local content = vim.fn.systemlist({ "git", "-C", root, "show", ref .. ":" .. relpath })
  if vim.v.shell_error ~= 0 then
    pcall(vim.cmd, "diffoff")
    return { ok = false, error = "git show failed for " .. ref .. ":" .. relpath }
  end

  vim.cmd("vsplit")
  setup_scratch(content, base_ft, relpath .. "@" .. ref)
  vim.cmd("diffthis")

  vim.api.nvim_set_current_win(base_win)
  return {
    ok = true,
    base_file = path,
    ref = ref,
    relpath = relpath,
  }
end

local function make_position_params(path, line, col)
  return {
    textDocument = { uri = vim.uri_from_fname(path) },
    position = { line = line - 1, character = col - 1 },
  }
end

local function wait_for_lsp(bufnr, timeout_ms)
  local deadline = vim.uv.now() + timeout_ms
  while vim.uv.now() < deadline do
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if #clients > 0 then return clients end
    vim.wait(100, function() return false end)
  end
  return vim.lsp.get_clients({ bufnr = bufnr })
end

local function location_to_table(loc, include_preview)
  local uri = loc.uri or loc.targetUri
  local range = loc.range or loc.targetSelectionRange or loc.targetRange
  if not uri or not range then return nil end
  local file = vim.uri_to_fname(uri)
  local line = range.start.line + 1
  local col = range.start.character + 1
  local result = { file = file, line = line, col = col }
  if include_preview then
    local bufnr = vim.fn.bufnr(file)
    if bufnr == -1 then
      bufnr = vim.fn.bufadd(file)
      pcall(vim.fn.bufload, bufnr)
    end
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local lines = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
      result.preview = (lines[1] or ""):gsub("^%s+", "")
    end
  end
  return result
end

local function flatten_hover(contents)
  if type(contents) == "string" then return contents end
  if type(contents) == "table" then
    if type(contents.value) == "string" then return contents.value end
    local parts = {}
    for _, item in ipairs(contents) do
      if type(item) == "string" then
        table.insert(parts, item)
      elseif type(item) == "table" and type(item.value) == "string" then
        table.insert(parts, item.value)
      end
    end
    if #parts > 0 then return table.concat(parts, "\n\n") end
  end
  return ""
end

local function lsp_call(path, method, lsp_params, timeout)
  if vim.fn.filereadable(path) ~= 1 then
    return nil, "file not readable: " .. path
  end
  local bufnr = get_or_load_buffer(path)
  local clients = wait_for_lsp(bufnr, 2000)
  if #clients == 0 then
    return nil, "no LSP client attached to " .. path .. " (filetype: " .. vim.bo[bufnr].filetype .. ")"
  end
  local results, err = vim.lsp.buf_request_sync(bufnr, method, lsp_params, timeout or 8000)
  if not results then
    return nil, err or "no LSP response (timeout)"
  end
  return results, nil
end

function M.lsp_references(params)
  local path = resolve_path(params.path)
  local line = params.line or 1
  local col = params.col or 1
  local lp = make_position_params(path, line, col)
  lp.context = { includeDeclaration = params.include_declaration ~= false }

  local results, err = lsp_call(path, "textDocument/references", lp, params.timeout)
  if err then return { ok = false, error = err } end

  local locations = {}
  for _, res in pairs(results) do
    if res.result then
      for _, loc in ipairs(res.result) do
        local t = location_to_table(loc, true)
        if t then table.insert(locations, t) end
      end
    end
  end
  return { ok = true, locations = locations, count = #locations }
end

function M.lsp_definition(params)
  local path = resolve_path(params.path)
  local line = params.line or 1
  local col = params.col or 1
  local lp = make_position_params(path, line, col)

  local results, err = lsp_call(path, "textDocument/definition", lp, params.timeout)
  if err then return { ok = false, error = err } end

  local locations = {}
  for _, res in pairs(results) do
    local r = res.result
    if r then
      if r.uri or r.targetUri then
        local t = location_to_table(r, true)
        if t then table.insert(locations, t) end
      else
        for _, loc in ipairs(r) do
          local t = location_to_table(loc, true)
          if t then table.insert(locations, t) end
        end
      end
    end
  end
  return { ok = true, locations = locations, count = #locations }
end

function M.lsp_hover(params)
  local path = resolve_path(params.path)
  local line = params.line or 1
  local col = params.col or 1
  local lp = make_position_params(path, line, col)

  local results, err = lsp_call(path, "textDocument/hover", lp, params.timeout)
  if err then return { ok = false, error = err } end

  local text = ""
  for _, res in pairs(results) do
    if res.result and res.result.contents then
      text = flatten_hover(res.result.contents)
      if text ~= "" then break end
    end
  end
  return { ok = true, contents = text }
end

function M.lsp_status(params)
  local target_bufnr = nil
  local detected_ft = nil
  local resolved_path = nil

  if params.path and params.path ~= "" then
    resolved_path = resolve_path(params.path)
    local b = vim.fn.bufnr(resolved_path)
    if b ~= -1 then
      target_bufnr = b
    else
      detected_ft = vim.filetype.match({ filename = resolved_path })
    end
  end

  local clients
  if target_bufnr then
    clients = vim.lsp.get_clients({ bufnr = target_bufnr })
  else
    clients = vim.lsp.get_clients()
  end

  local result_clients = {}
  for _, c in ipairs(clients) do
    local caps = c.server_capabilities or {}
    table.insert(result_clients, {
      id = c.id,
      name = c.name,
      initialized = c.initialized == true,
      capabilities = {
        references = caps.referencesProvider ~= nil and caps.referencesProvider ~= false,
        definition = caps.definitionProvider ~= nil and caps.definitionProvider ~= false,
        hover = caps.hoverProvider ~= nil and caps.hoverProvider ~= false,
        workspace_symbol = caps.workspaceSymbolProvider ~= nil and caps.workspaceSymbolProvider ~= false,
        implementation = caps.implementationProvider ~= nil and caps.implementationProvider ~= false,
        document_symbol = caps.documentSymbolProvider ~= nil and caps.documentSymbolProvider ~= false,
      },
      root_dir = c.config and c.config.root_dir,
    })
  end

  return {
    ok = true,
    path = resolved_path,
    buffer_loaded = target_bufnr ~= nil,
    detected_filetype = detected_ft,
    clients = result_clients,
    count = #result_clients,
  }
end

function M.lsp_workspace_symbol(params)
  local query = params.query
  if type(query) ~= "string" or query == "" then
    return { ok = false, error = "query is required" }
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) then
        local c = vim.lsp.get_clients({ bufnr = b })
        if #c > 0 then bufnr = b; clients = c; break end
      end
    end
  end
  if #clients == 0 then
    return { ok = false, error = "no active LSP client to query" }
  end

  local results, err = vim.lsp.buf_request_sync(bufnr, "workspace/symbol", { query = query }, params.timeout or 8000)
  if not results then return { ok = false, error = err or "no LSP response" } end

  local symbols = {}
  for _, res in pairs(results) do
    if res.result then
      for _, sym in ipairs(res.result) do
        local loc = sym.location
        if loc and loc.uri then
          table.insert(symbols, {
            name = sym.name,
            kind = vim.lsp.protocol.SymbolKind[sym.kind] or "Unknown",
            container = sym.containerName,
            file = vim.uri_to_fname(loc.uri),
            line = loc.range.start.line + 1,
            col = loc.range.start.character + 1,
          })
        end
      end
    end
  end
  return { ok = true, symbols = symbols, count = #symbols }
end

function M.diff_suggest(params)
  local path = resolve_path(params.path)
  if vim.fn.filereadable(path) ~= 1 then
    return { ok = false, error = "file not readable: " .. path }
  end
  local suggestions = params.suggestions
  if type(suggestions) ~= "table" or #suggestions == 0 then
    return { ok = false, error = "suggestions array is required and non-empty" }
  end

  vim.cmd("edit " .. vim.fn.fnameescape(path))
  local base_win = vim.api.nvim_get_current_win()
  local base_ft = vim.bo.filetype
  local ns = ensure_suggest_ns()
  pcall(vim.api.nvim_win_set_hl_ns, base_win, ns)
  vim.cmd("diffthis")

  local opened = {}
  for i, sug in ipairs(suggestions) do
    if type(sug.content) ~= "string" then
      return { ok = false, error = "suggestion " .. i .. " missing string content" }
    end
    local lines = vim.split(sug.content, "\n", { plain = true })
    local label = (type(sug.label) == "string" and sug.label ~= "") and sug.label or ("Suggestion " .. i)
    local name = label .. " - " .. vim.fn.fnamemodify(path, ":t")

    vim.cmd("vsplit")
    setup_scratch(lines, base_ft, name)
    vim.cmd("diffthis")
    pcall(vim.api.nvim_win_set_hl_ns, vim.api.nvim_get_current_win(), ns)
    table.insert(opened, { label = label })
  end

  vim.api.nvim_set_current_win(base_win)
  return {
    ok = true,
    base_file = path,
    suggestions = opened,
  }
end

function M.close(params)
  local target
  if params.path and params.path ~= "" then
    local path = resolve_path(params.path)
    target = vim.fn.bufnr(path)
    if target == -1 then
      return { ok = false, error = "buffer not found: " .. path }
    end
  else
    target = vim.api.nvim_get_current_buf()
  end

  if target == vim.api.nvim_get_current_buf() then
    pcall(vim.cmd, "bprevious")
  end

  local ok, err = pcall(vim.cmd, "bdelete " .. target)
  if not ok then return { ok = false, error = tostring(err) } end

  return { ok = true, closed_bufnr = target }
end

function M.snapshot(params)
  local name = (params.name and params.name ~= "") and params.name or "_last"
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  state.snapshots[name] = {
    bufnr = bufnr,
    file = vim.api.nvim_buf_get_name(bufnr),
    line = cursor[1],
    col = cursor[2],
  }
  return { ok = true, name = name, bufnr = bufnr, line = cursor[1] }
end

function M.restore(params)
  local name = (params.name and params.name ~= "") and params.name or "_last"
  local snap = state.snapshots[name]
  if not snap then
    return { ok = false, error = "no snapshot named: " .. name }
  end

  if vim.api.nvim_buf_is_valid(snap.bufnr) and vim.api.nvim_buf_is_loaded(snap.bufnr) then
    focus_buffer(snap.bufnr, snap.line)
  elseif snap.file and snap.file ~= "" and vim.fn.filereadable(snap.file) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(snap.file))
    vim.api.nvim_win_set_cursor(0, { snap.line, math.max(0, snap.col) })
    vim.cmd("normal! zz")
  else
    return { ok = false, error = "snapshot target unreachable: " .. (snap.file or "no file") }
  end

  return { ok = true, name = name, file = snap.file, line = snap.line }
end

function M.annotate(params)
  local path = resolve_path(params.path)
  if vim.fn.filereadable(path) ~= 1 then
    return { ok = false, error = "file not readable: " .. path }
  end
  if not params.line then
    return { ok = false, error = "line is required" }
  end
  if type(params.text) ~= "string" or params.text == "" then
    return { ok = false, error = "text is required" }
  end

  local bufnr = get_or_load_buffer(path)
  local line = clamp_line(bufnr, math.floor(params.line))
  local group = params.group or "tour"
  local position = params.position or "above"

  local opts = {}
  if position == "eol" then
    opts.virt_text = { { "  " .. params.text, "CairnLabel" } }
    opts.virt_text_pos = "eol"
  else
    opts.virt_lines = { { { params.text, "CairnLabel" } } }
    opts.virt_lines_above = (position ~= "below")
  end

  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, state.namespace(), line - 1, 0, opts)
  state.add(group, bufnr, mark_id)

  return {
    ok = true,
    file = path,
    bufnr = bufnr,
    line = line,
    position = position,
    group = group,
    mark_id = mark_id,
  }
end

function M.diagnostics(params)
  local bufnr = nil
  if params.path and params.path ~= "" then
    local path = resolve_path(params.path)
    bufnr = get_or_load_buffer(path)
  end

  local raw = bufnr and vim.diagnostic.get(bufnr) or vim.diagnostic.get()
  local severity_name = { "ERROR", "WARN", "INFO", "HINT" }
  local out = {}
  for _, d in ipairs(raw) do
    table.insert(out, {
      file = vim.api.nvim_buf_get_name(d.bufnr),
      line = d.lnum + 1,
      col = d.col + 1,
      end_line = d.end_lnum and (d.end_lnum + 1) or nil,
      end_col = d.end_col and (d.end_col + 1) or nil,
      severity = severity_name[d.severity] or tostring(d.severity),
      message = d.message,
      source = d.source,
      code = d.code,
    })
  end
  return { ok = true, diagnostics = out, count = #out }
end

function M.buffer_content(params)
  local path = resolve_path(params.path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr == -1 then
    if vim.fn.filereadable(path) ~= 1 then
      return { ok = false, error = "file not readable and not loaded: " .. path }
    end
    bufnr = get_or_load_buffer(path)
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return { ok = false, error = "buffer invalid for: " .. path }
  end

  local total = vim.api.nvim_buf_line_count(bufnr)
  local start_line = params.start_line and math.max(1, math.floor(params.start_line)) or 1
  local end_line = params.end_line and math.min(total, math.floor(params.end_line)) or total
  if end_line < start_line then end_line = start_line end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  return {
    ok = true,
    file = path,
    bufnr = bufnr,
    modified = vim.bo[bufnr].modified,
    start_line = start_line,
    end_line = end_line,
    total_lines = total,
    content = table.concat(lines, "\n"),
  }
end

function M.clipboard(params)
  local register = params.register
  if not register or register == "" then register = '"' end
  if #register > 1 then
    return { ok = false, error = "register must be a single character (e.g. \", +, *, 0, a)" }
  end
  local content = vim.fn.getreg(register)
  local regtype = vim.fn.getregtype(register)
  return {
    ok = true,
    register = register,
    type = regtype,
    content = content,
    length = #content,
  }
end

function M.selection(_)
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  if start_pos[2] == 0 or end_pos[2] == 0 then
    return { ok = false, error = "no visual selection found" }
  end

  local bufnr = start_pos[1]
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return { ok = false, error = "selection buffer is not loaded" }
  end

  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  if #lines == 0 then
    return { ok = false, error = "selection range produced no lines" }
  end

  if #lines == 1 then
    lines[1] = lines[1]:sub(start_col, end_col)
  else
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
  end

  local file = vim.api.nvim_buf_get_name(bufnr)
  return {
    ok = true,
    file = file ~= "" and file or nil,
    bufnr = bufnr,
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
    line_count = end_line - start_line + 1,
    text = table.concat(lines, "\n"),
  }
end

return M
