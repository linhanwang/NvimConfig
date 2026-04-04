-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "gruvbox",
}

M.ui = {
  statusline = {
    theme = "vscode_colored",
  },
}

M.nvdash = {
  load_on_startup = true,
}

M.mason = {
  pkgs = { "ty" },
}

return M
