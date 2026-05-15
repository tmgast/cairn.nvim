local M = {}

local function blend(c1, c2, ratio)
  if type(c1) ~= "number" or type(c2) ~= "number" then return nil end
  local r1, g1, b1 = math.floor(c1 / 65536) % 256, math.floor(c1 / 256) % 256, c1 % 256
  local r2, g2, b2 = math.floor(c2 / 65536) % 256, math.floor(c2 / 256) % 256, c2 % 256
  local r = math.floor(r1 * ratio + r2 * (1 - ratio))
  local g = math.floor(g1 * ratio + g2 * (1 - ratio))
  local b = math.floor(b1 * ratio + b2 * (1 - ratio))
  return r * 65536 + g * 256 + b
end

local function info_source_color()
  local di = vim.api.nvim_get_hl(0, { name = "DiagnosticInfo", link = false })
  if di and di.fg then return di.fg end
  local todo = vim.api.nvim_get_hl(0, { name = "Todo", link = false })
  if todo and todo.fg then return todo.fg end
  if todo and todo.bg then return todo.bg end
  return 0x4080FF
end

local function define_highlights()
  local search = vim.api.nvim_get_hl(0, { name = "Search", link = false })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local bg = blend(search.bg, normal.bg, 0.3)

  if bg then
    vim.api.nvim_set_hl(0, "CairnHighlight", { bg = bg })
  else
    vim.api.nvim_set_hl(0, "CairnHighlight", { link = "ColorColumn" })
  end
  vim.api.nvim_set_hl(0, "CairnLabel", { link = "Comment" })

  local info = info_source_color()
  local nbg = normal.bg or 0x000000
  vim.api.nvim_set_hl(0, "CairnDiffSuggestAdd", { bg = blend(info, nbg, 0.30) })
  vim.api.nvim_set_hl(0, "CairnDiffSuggestDelete", { bg = blend(info, nbg, 0.15) })
  vim.api.nvim_set_hl(0, "CairnDiffSuggestChange", { bg = blend(info, nbg, 0.22) })
  vim.api.nvim_set_hl(0, "CairnDiffSuggestText", { bg = blend(info, nbg, 0.45) })
end

local function setup_keymaps(config)
  if config.clear_on_escape == false then return end

  local function install()
    vim.keymap.set({ "n", "i", "s" }, "<Esc>", function()
      local s = require("cairn.state")
      if s.marks and next(s.marks) then
        s.clear_all()
      end
      vim.cmd("nohlsearch")
      return "<Esc>"
    end, { expr = true, silent = true, desc = "Clear cairn marks, hlsearch, then escape" })
  end

  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      vim.schedule(install)
    end,
  })
end

function M.setup(opts)
  M.config = opts or {}
  if M.config.clear_on_escape == nil then M.config.clear_on_escape = true end

  define_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = define_highlights,
  })

  setup_keymaps(M.config)

  require("cairn.pair").setup()
  require("cairn.server").start()

  vim.api.nvim_create_user_command("CairnPair", function(args)
    require("cairn.pair").toggle(args.args ~= "" and args.args or nil)
  end, {
    nargs = "?",
    complete = function() return { "on", "off", "toggle" } end,
  })

  vim.api.nvim_create_user_command("CairnStatus", function()
    print(vim.inspect(require("cairn.server").status()))
  end, {})

  vim.api.nvim_create_user_command("CairnClear", function()
    local n = require("cairn.state").clear_all()
    vim.notify("cairn: cleared " .. n .. " mark(s)")
  end, {})

  vim.api.nvim_create_user_command("CairnReload", function()
    for name, _ in pairs(package.loaded) do
      if name == "cairn" or name:match("^cairn%.") then
        package.loaded[name] = nil
      end
    end
    require("cairn").setup(M.config)
    vim.notify("cairn: reloaded all modules")
  end, {})

  vim.api.nvim_create_user_command("CairnInstall", function()
    local health = require("cairn.health")
    local lines = {}
    local push = function(s) table.insert(lines, s) end

    local bin = health.find_binary()
    if not bin then
      push("cairn-server binary not found.")
      push("Build it first: :Lazy build cairn.nvim")
      vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR)
      return
    end
    push("cairn-server: " .. bin)

    if vim.fn.executable("claude") == 1 then
      local registered = health.is_mcp_registered()
      if registered then
        push("MCP: already registered")
      else
        local out = vim.fn.system({ "claude", "mcp", "add", "cairn", bin, "-s", "user" })
        if vim.v.shell_error == 0 then
          push("MCP: registered cairn with claude (user scope)")
        else
          push("MCP: registration failed: " .. out)
        end
      end
    else
      push("MCP: claude CLI not on PATH, skipping registration")
    end

    local skills = health.list_skills()
    if #skills == 0 then
      push("Skills: none found under " .. health.skills_root())
    end
    for _, sk in ipairs(skills) do
      local linked, dst = health.is_skill_linked(sk)
      if linked then
        push("Skill " .. sk.name .. ": already linked at " .. dst)
      else
        vim.fn.mkdir(vim.fn.fnamemodify(dst, ":h"), "p")
        local ok, err = pcall(vim.uv.fs_symlink, sk.src, dst)
        if ok then
          push("Skill " .. sk.name .. ": linked " .. dst .. " -> " .. sk.src)
        else
          push("Skill " .. sk.name .. ": link failed: " .. tostring(err))
        end
      end
    end

    local hook_ok = health.is_hook_configured()
    if hook_ok then
      push("Hook: pair-mode UserPromptSubmit hook already in ~/.claude/settings.json")
    else
      push("")
      push("Pair-mode hook (optional): add this to ~/.claude/settings.json,")
      push("merging with any existing 'hooks' block:")
      push("")
      push("  {")
      push("    \"hooks\": {")
      push("      \"UserPromptSubmit\": [")
      push("        { \"hooks\": [{ \"type\": \"command\",")
      push("                      \"command\": \"" .. bin .. " --drain-queue\" }] }")
      push("      ]")
      push("    }")
      push("  }")
      push("")
      push("Then :CairnPair on to enable pair mode per nvim session.")
    end

    local cmd_ok = health.is_claudemd_configured()
    if cmd_ok then
      push("CLAUDE.md: tool-routing rule already present in ~/.claude/CLAUDE.md")
    else
      push("")
      push("Tool-routing rule (recommended): add this to ~/.claude/CLAUDE.md,")
      push("replacing or merging any existing tool-routing block:")
      push("")
      push("  ## Tool Routing")
      push("")
      push("  Route code work through tiers:")
      push("")
      push("  1. cairn (if `cairn_status` is connected) - primary layer when nvim is")
      push("     running with the cairn plugin. Probe `cairn_status` once at the start")
      push("     of code work in a session.")
      push("     - View code: `cairn_open`; do not quote excerpts into chat. Editor")
      push("       carries the visual; chat narrates.")
      push("     - Semantic queries: `cairn_lsp_references`, `cairn_lsp_definition`,")
      push("       `cairn_lsp_hover`, `cairn_lsp_workspace_symbol`.")
      push("     - Syntactic queries: `cairn_ts_node_at`, `cairn_ts_enclosing`.")
      push("     - Diagnostics: `cairn_diagnostics` instead of re-running compilation.")
      push("  2. tree-sitter-mcp - for AST-pattern searches and structural analysis")
      push("     (`search_code`, `analyze_code`), and as semantic fallback when cairn is")
      push("     unreachable (`find_usage`, `check_errors`).")
      push("  3. Basic tools (Glob, Grep, Read) - file discovery, plain content reading,")
      push("     last-resort fallback.")
      push("")
      push("  The `code-tour` and `code-discovery` skills are best-practice frames for")
      push("  cairn-mediated work; cairn primitives can also be used ad hoc outside them.")
    end

    push("")
    push("Run :checkhealth cairn to verify state.")

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, { desc = "Register cairn-server with Claude, symlink cairn skills, and print optional snippets." })
end

return M
