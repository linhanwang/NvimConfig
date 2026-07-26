# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal Neovim configuration built on **NvChad v2.5**, tuned for Python and C++ development plus an
aerial.nvim code outline. Plugin management is **lazy.nvim** (bootstrapped in `init.lua`). Leader key is `<Space>`.

**Requires Neovim ≥ 0.12.** NvChad v2.5 itself only needs 0.11, but `aerial.nvim` dropped support for
<0.12 in `dd80db7` (2026-05-14) — on 0.11 its `setup()` returns before creating commands, so `<leader>a`
fails with `E492: Not an editor command: AerialToggle` and nothing else in the config reveals why.

## Commands

There is no test suite — this is a config repo. The equivalent of "run the tests" is the verification
pass in the `nvim-env-setup` skill, which opens real buffers and asserts LSP attach, treesitter
highlighting, formatter availability, aerial, and lint diagnostics:

```bash
bash .claude/skills/nvim-env-setup/scripts/bootstrap.sh --verify-only   # verify a working install
bash .claude/skills/nvim-env-setup/scripts/bootstrap.sh                 # full provision (idempotent)
bash .claude/skills/nvim-env-setup/scripts/bootstrap.sh --skip-system   # plugins/Mason/parsers only
```

Format this repo's Lua (settings in `.stylua.toml`, 120 cols, no call parens):

```bash
stylua .            # mason binary: ~/.local/share/nvim/mason/bin/stylua
stylua --check .
```

Inside Neovim: `:Lazy sync` (plugins), `:Mason` (tool UI), `:TSInstallSync <parser>` (parsers),
`:checkhealth`.

Install Mason packages non-interactively — `:MasonInstallAll` does **not** exist in current NvChad:

```bash
nvim --headless -c "luafile .claude/skills/nvim-env-setup/scripts/mason_install.lua"
```

## Architecture

- `init.lua` — bootstraps lazy.nvim, loads NvChad v2.5 (`import = "nvchad.plugins"`), `dofile`s the
  base46 theme cache, then autocmds and (scheduled) mappings
- `lua/chadrc.lua` — NvChad settings: theme, statusline (incl. a custom `file` module rendering
  cwd-relative paths), nvdash. Must mirror NvChad's `nvconfig` structure
- `lua/options.lua` — extends `nvchad.options`; relative numbers, colorcolumn 120, mouse, treesitter
  folding, and the nvim-lint autocmd
- `lua/mappings.lua` — extends `nvchad.mappings`; `;` → command mode, `jk` → escape
- `lua/plugins/init.lua` — all plugin specs (conform, nvim-lint, lspconfig, mason, treesitter, aerial,
  diffview, nvim-cmp override)
- `lua/configs/` — `lspconfig.lua`, `conform.lua`, `lazy.lua`

Runtime state lives outside the repo: plugins in `~/.local/share/nvim/lazy/`, Mason tools in
`~/.local/share/nvim/mason/` (NvChad prepends `mason/bin` to `vim.env.PATH` in `nvchad/options.lua`),
base46 cache in `~/.local/share/nvim/nvchad/base46/`.

## Key configuration details

- **Theme:** `gruvchad` with the `vscode_colored` statusline
- **LSP servers:** html, cssls, ts_ls, ty (Python type checker), clangd (`--header-insertion=never`)
- **Formatters (conform):** stylua (Lua), isort + ruff_format (Python), clang-format (C++), prettier
  (CSS/HTML/JS/JSON/YAML/Markdown). Format-on-save is commented out in both `plugins/init.lua` and `configs/conform.lua`
- **Linters (nvim-lint):** ruff for Python, triggered on BufEnter/BufWritePost/InsertLeave
- Python tooling is `ty` + `ruff` — **not** pyright, and not black

## Important patterns

- LSP uses the modern `vim.lsp.config()` / `vim.lsp.enable()` API. Do **not** reintroduce the deprecated
  `require("lspconfig").<server>.setup()` pattern
- Prefer non-deprecated Neovim APIs that still exist on 0.11, since machines running this config may lag
  (e.g. `vim.lsp.log.set_level`, not `vim.lsp.set_log_level`)
- nvim-treesitter is pinned to `branch = "master"` and configured through `require("nvim-treesitter.configs").setup()`.
  The `main` branch has an incompatible API — see gotchas
- The nvim-cmp spec strips NvChad's `async_path` source and substitutes `path`, working around a crash
  from passing a uv handle across threads. Keep that override if touching cmp sources
- aerial is lazy-loaded by both `keys` (`<leader>a`) and `cmd`; adding a new aerial command means adding
  it to `cmd` or it will not trigger a load

## Gotchas

These cost real debugging time; check here before diagnosing.

- **`ensure_installed` on the `mason.nvim` spec is inert.** NvChad declares mason with a *function-valued*
  `opts`, which replaces a child table on merge, and mason has no `ensure_installed` support of its own.
  The list in `plugins/init.lua` documents intent only — actual installs go through the skill's
  `mason_install.lua`, which also scans `configs/lspconfig.lua` and `configs/conform.lua` (that is how
  `ts_ls` → `typescript-language-server` and `clang-format`, both absent from `ensure_installed`, get installed)
- **`:TSInstallAll` errors.** NvChad's implementation calls `require("nvim-treesitter").install(...)`, a
  `main`-branch API; this config pins `master`. Use `:TSInstall` / `:TSInstallSync`
- **`E492: Not an editor command: <Plugin>Cmd`** has two causes here: the plugin's `setup()` bailed (check
  `:messages` for a version-deprecation notice), or the lazy spec has `keys` but no `cmd`
- **Testing changes headlessly is misleading.** NvChad lazy-loads nvim-lspconfig on its `User FilePost`
  event, gated on `vim.g.ui_entered`, which never becomes true under plain `nvim --headless` — LSP will
  appear broken when it is fine. Drive a pty instead and defer assertions a few seconds:
  `script -qec "nvim -c 'luafile check.lua'" /dev/null`. Also, `nvim -l script.lua` does not source
  `init.lua`, so `require "lazy"` fails there; use `nvim --headless -c "luafile <script>"`
- **`lazy-lock.json` is tracked and shared across machines.** Update deliberately: `:Lazy update` →
  commit the lock. On another machine, `git pull` then `:Lazy restore` — pulling alone does not move
  installed plugins to the locked commits. Plugin drift between machines is otherwise invisible in the repo
