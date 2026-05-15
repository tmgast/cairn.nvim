local M = {}

local function plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  source = vim.fn.resolve(source)
  return vim.fn.fnamemodify(source, ":h:h:h")
end

function M.find_binary()
  local bin = plugin_root() .. "/server/cairn-server"
  if vim.fn.executable(bin) == 1 then return bin end
  return nil
end

function M.skills_root()
  return plugin_root() .. "/skills"
end

function M.list_skills()
  local root = M.skills_root()
  local skills = {}
  local entries = vim.fn.readdir(root)
  if type(entries) ~= "table" then return skills end
  for _, name in ipairs(entries) do
    local src = root .. "/" .. name
    if vim.fn.isdirectory(src) == 1 and vim.fn.filereadable(src .. "/SKILL.md") == 1 then
      table.insert(skills, {
        name = name,
        src = src,
        dst = vim.fn.expand("~/.claude/skills/" .. name),
      })
    end
  end
  table.sort(skills, function(a, b) return a.name < b.name end)
  return skills
end

function M.is_mcp_registered()
  if vim.fn.executable("claude") ~= 1 then return false, "claude CLI not on PATH" end
  local out = vim.fn.system({ "claude", "mcp", "list" })
  if vim.v.shell_error ~= 0 then return false, out end
  for line in out:gmatch("[^\n]+") do
    if line:match("^cairn[%s:]") then return true end
  end
  return false
end

function M.is_skill_linked(skill)
  local dst = skill.dst
  return vim.fn.isdirectory(dst) == 1 or vim.fn.filereadable(dst) == 1, dst
end

function M.is_hook_configured()
  local path = vim.fn.expand("~/.claude/settings.json")
  if vim.fn.filereadable(path) ~= 1 then return false, path end
  local content = table.concat(vim.fn.readfile(path), "\n")
  if content:match("cairn%-server.-%-%-drain%-queue") then return true, path end
  return false, path
end

function M.is_claudemd_configured()
  local path = vim.fn.expand("~/.claude/CLAUDE.md")
  if vim.fn.filereadable(path) ~= 1 then return false, path end
  local content = table.concat(vim.fn.readfile(path), "\n")
  if content:match("cairn_status") then return true, path end
  return false, path
end

function M.check()
  local h = vim.health

  h.start("cairn: plugin")
  local server = require("cairn.server")
  local s = server.status()
  if s.listening then
    h.ok("Server listening on " .. s.socket)
  else
    h.error("Server is not listening", { "Try :CairnReload" })
  end
  h.info("Project root: " .. s.root)

  h.start("cairn: binary")
  local bin = M.find_binary()
  if bin then
    h.ok("cairn-server found at " .. bin)
  else
    h.error("cairn-server binary not found", {
      "Run :Lazy build cairn.nvim, or:",
      "  cd " .. plugin_root() .. "/server && go build -o cairn-server .",
    })
  end

  h.start("cairn: Claude integration")
  if vim.fn.executable("claude") == 1 then
    h.ok("claude CLI on PATH")
    local ok = M.is_mcp_registered()
    if ok then
      h.ok("cairn registered with claude mcp")
    else
      h.warn("cairn not registered with claude mcp", { "Run :CairnInstall" })
    end
  else
    h.warn("claude CLI not on PATH", { "Install Claude Code, or skip MCP integration" })
  end

  h.start("cairn: skills")
  local skills = M.list_skills()
  if #skills == 0 then
    h.warn("No skills found under " .. M.skills_root())
  end
  for _, sk in ipairs(skills) do
    local linked, dst = M.is_skill_linked(sk)
    if linked then
      h.ok(sk.name .. ": linked at " .. dst)
    else
      h.warn(sk.name .. ": not linked at " .. dst, { "Run :CairnInstall" })
    end
  end

  h.start("cairn: pair mode")
  local pair = require("cairn.pair")
  if pair.is_enabled() then
    h.info("Pair mode is ON (current session)")
  else
    h.info("Pair mode is OFF (toggle with :CairnPair on)")
  end
  local hook_ok, hook_path = M.is_hook_configured()
  if hook_ok then
    h.ok("UserPromptSubmit hook configured in " .. hook_path)
  else
    h.info("UserPromptSubmit hook not configured (optional)", {
      "Required for pair mode to inject save-diffs into your next Claude turn.",
      "Run :CairnInstall to see the snippet.",
    })
  end

  h.start("cairn: tool-routing rule")
  local cmd_ok, cmd_path = M.is_claudemd_configured()
  if cmd_ok then
    h.ok("Routing rule present in " .. cmd_path)
  else
    h.info("Tool-routing rule not in " .. cmd_path, {
      "Without it, the agent still defaults to Read+quote instead of cairn_open.",
      "Run :CairnInstall to see the snippet to paste.",
    })
  end
end

return M
