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
    modules = {
      file = function()
        local stbufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
        local path = vim.api.nvim_buf_get_name(stbufnr)
        if path == "" then
          return "%#StText#  󰈚 Empty "
        end

        local cwd = vim.uv.cwd() or ""
        local rel = path:sub(1, #cwd + 1) == cwd .. "/" and path:sub(#cwd + 2) or path

        local name = path:match "([^/\\]+)[/\\]*$"
        local icon = "󰈚"
        local devicons_present, devicons = pcall(require, "nvim-web-devicons")
        if devicons_present then
          local ft_icon = devicons.get_icon(name)
          icon = ft_icon or icon
        end

        return "%#StText# " .. icon .. " " .. rel .. " "
      end,
    },
  },
}

M.nvdash = {
  load_on_startup = true,
}

M.mason = {
  pkgs = { "ty" },
}

return M
