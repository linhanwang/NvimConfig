-- Headless Mason installer for this config.
--
-- Derives the package list from the repo itself, installs anything missing via
-- the Mason registry API, blocks until every install settles, prints a summary
-- and exits non-zero-ish (message) if something failed.
--
-- Run with:  nvim --headless -c "luafile <this file>"
-- Override:  MASON_PKGS="ruff,stylua" nvim --headless -c "luafile <this file>"
--
-- Note: `nvim -l <file>` does NOT source init.lua, so lazy/mason are absent.
-- Always use `-c luafile`.

local config_dir = vim.fn.stdpath "config"

-- lspconfig server name -> mason package name (only where they differ or are
-- not implied by the mason spec)
local LSP_TO_PKG = {
  html = "html-lsp",
  cssls = "css-lsp",
  ts_ls = "typescript-language-server",
  ty = "ty",
  clangd = "clangd",
  lua_ls = "lua-language-server",
  pyright = "pyright",
  jsonls = "json-lsp",
  yamlls = "yaml-language-server",
  bashls = "bash-language-server",
  gopls = "gopls",
  rust_analyzer = "rust-analyzer",
}

-- conform/nvim-lint tool name -> mason package name
local FMT_TO_PKG = {
  stylua = "stylua",
  isort = "isort",
  ruff = "ruff",
  ruff_format = "ruff",
  ruff_fix = "ruff",
  ["clang-format"] = "clang-format",
  prettier = "prettier",
  prettierd = "prettierd",
  black = "black",
  shfmt = "shfmt",
}

local seen, pkgs = {}, {}
local function add(name)
  if type(name) == "string" and name ~= "" and not seen[name] then
    seen[name] = true
    pkgs[#pkgs + 1] = name
  end
end

local function read(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local text = fd:read "*a"
  fd:close()
  return text
end

if vim.env.MASON_PKGS and vim.env.MASON_PKGS ~= "" then
  for _, name in ipairs(vim.split(vim.env.MASON_PKGS, ",", { trimempty = true })) do
    add(vim.trim(name))
  end
else
  -- 1. ensure_installed from the mason.nvim spec in lua/plugins/init.lua.
  --    Read from the file rather than the merged lazy spec: NvChad declares
  --    mason.nvim with a function-valued `opts`, which replaces this table.
  local ok, spec = pcall(dofile, config_dir .. "/lua/plugins/init.lua")
  if ok and type(spec) == "table" then
    for _, plugin in ipairs(spec) do
      if type(plugin) == "table" and type(plugin[1]) == "string" and plugin[1]:match "mason%.nvim$" then
        for _, name in ipairs((type(plugin.opts) == "table" and plugin.opts.ensure_installed) or {}) do
          add(name)
        end
      end
    end
  end

  -- 2. M.mason.pkgs from chadrc
  local ok_chad, chadrc = pcall(dofile, config_dir .. "/lua/chadrc.lua")
  if ok_chad and type(chadrc) == "table" and type(chadrc.mason) == "table" then
    for _, name in ipairs(chadrc.mason.pkgs or {}) do
      add(name)
    end
  end

  -- 3. servers/formatters actually referenced by the configs
  local lsp_src = read(config_dir .. "/lua/configs/lspconfig.lua") or ""
  for server, pkg in pairs(LSP_TO_PKG) do
    if lsp_src:find('"' .. server .. '"', 1, true) or lsp_src:find("'" .. server .. "'", 1, true) then
      add(pkg)
    end
  end
  local fmt_src = (read(config_dir .. "/lua/configs/conform.lua") or "")
    .. (read(config_dir .. "/lua/plugins/init.lua") or "")
  for tool, pkg in pairs(FMT_TO_PKG) do
    if fmt_src:find('"' .. tool .. '"', 1, true) or fmt_src:find("'" .. tool .. "'", 1, true) then
      add(pkg)
    end
  end
end

table.sort(pkgs)
print("packages: " .. table.concat(pkgs, " "))

require("lazy").load { plugins = { "mason.nvim" } }
local registry = require "mason-registry"

local refreshed = false
registry.refresh(function()
  refreshed = true
end)
vim.wait(120000, function()
  return refreshed
end, 100)

local done, failed = {}, {}
for _, name in ipairs(pkgs) do
  local ok, pkg = pcall(registry.get_package, name)
  if not ok then
    failed[name], done[name] = "not in mason registry", true
  elseif pkg:is_installed() then
    done[name] = true
    print("[skip]   " .. name)
  else
    pkg:once("install:success", function()
      done[name] = true
      print("[ok]     " .. name)
    end)
    pkg:once("install:failed", function()
      done[name], failed[name] = true, "install failed"
      print("[FAILED] " .. name)
    end)
    pkg:install()
  end
end

vim.wait(1800000, function()
  for _, name in ipairs(pkgs) do
    if not done[name] then
      return false
    end
  end
  return true
end, 500)

print "---- mason summary ----"
local missing = 0
for _, name in ipairs(pkgs) do
  local ok, pkg = pcall(registry.get_package, name)
  local installed = ok and pkg:is_installed()
  if not installed then
    missing = missing + 1
  end
  print(("%-30s %s"):format(name, installed and "installed" or ("MISSING (" .. (failed[name] or "timed out") .. ")")))
end
print(missing == 0 and "all mason packages installed" or (missing .. " mason package(s) missing"))

vim.cmd "qa!"
