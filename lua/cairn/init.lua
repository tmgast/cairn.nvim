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
end

return M
