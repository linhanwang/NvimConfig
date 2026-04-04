# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal Neovim configuration built on **NvChad v2.5**. Plugin management uses **lazy.nvim** (bootstrapped in `init.lua`). The leader key is `<Space>`.

## Architecture

- `init.lua` — Entry point: bootstraps lazy.nvim, loads NvChad core, applies theme cache, loads autocmds and mappings
- `lua/chadrc.lua` — NvChad configuration (theme, statusline, dashboard, mason packages). Must follow `nvconfig.lua` structure
- `lua/options.lua` — Vim options (extends `nvchad.options`): relative numbers, colorcolumn at 120, treesitter folding, nvim-lint autocmd
- `lua/mappings.lua` — Custom keymaps (extends `nvchad.mappings`): `;` for command mode, `jk` for escape
- `lua/plugins/init.lua` — Plugin specs for lazy.nvim (conform, nvim-lint, lspconfig, mason, treesitter, aerial)
- `lua/configs/lspconfig.lua` — LSP server setup using `vim.lsp.config()`/`vim.lsp.enable()` (modern API, not the deprecated `lspconfig.setup()`)
- `lua/configs/conform.lua` — Formatter configuration per filetype
- `lua/configs/lazy.lua` — lazy.nvim settings (defaults to lazy-loading, disables many built-in plugins)

## Key Configuration Details

**LSP servers:** html, cssls, ts_ls, ty (Python type checker), clangd (with `--header-insertion=never`)

**Formatters (conform.nvim):** stylua (Lua), isort + ruff_format (Python), clang-format (C++), prettier (CSS/HTML/JS/JSON/YAML/Markdown). Format-on-save is commented out.

**Linters (nvim-lint):** ruff for Python. Linting triggers on BufEnter, BufWritePost, InsertLeave.

**Mason-installed tools:** lua-language-server, stylua, html-lsp, css-lsp, prettier, ty, isort, ruff, clangd

**Theme:** gruvbox with vscode_colored statusline

## Important Patterns

- LSP config uses the modern `vim.lsp.config()` + `vim.lsp.enable()` API — do NOT use the deprecated `require("lspconfig").server.setup()` pattern
- Python uses `ty` for type checking (not pyright) and `ruff` for linting/formatting
- Aerial.nvim is lazy-loaded, toggled with `<leader>a`
- NvChad base46 theme cache is stored in `stdpath("data")/nvchad/base46/`
