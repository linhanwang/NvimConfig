---
name: nvim-env-setup
description: Provision a machine so this NvChad-based Neovim config works end to end — installs Neovim 0.12+, Node.js, tree-sitter-cli, ripgrep and build tools, then syncs lazy.nvim plugins, Mason LSP/formatter/linter packages and treesitter parsers, and verifies everything attaches. Use when setting up this config on a new machine, after "make my nvim config work", or when plugins/LSP/formatters are missing or broken (including E492 "not an editor command" from a plugin).
---

# Neovim env setup (NvChad v2.5)

Brings a fresh machine to a state where `nvim` starts clean with this config and
LSP, treesitter, formatting and linting all work. Every step is idempotent — safe
to re-run.

## Prerequisites this config needs

Per <https://nvchad.com/docs/quickstart/install>, plus what this repo's own specs pull in:

| Requirement | Why |
| --- | --- |
| **Neovim ≥ 0.12** | NvChad v2.5 itself only needs 0.11, but `aerial.nvim` dropped <0.12 in `dd80db7` (2026-05-14). On 0.11 its `setup()` returns before `create_commands()`, so `<leader>a` fails with `E492: Not an editor command: AerialToggle`. Config also uses the `vim.lsp.config()` / `vim.lsp.enable()` API (0.11+) |
| **git, curl, gcc/cc, make, unzip** | lazy.nvim cloning, treesitter parser compilation, Mason downloads |
| **Node.js + npm** | `tree-sitter-cli`, and Mason's npm-backed packages (prettier, ts_ls, html-lsp, css-lsp) |
| **tree-sitter-cli** | nvim-treesitter parser generation |
| **ripgrep** | Telescope live grep (`<leader>fw`) |
| **Python 3 with `venv`** | Mason installs `ruff`, `isort`, `ty` into a venv |
| **A Nerd Font** | Icons. Installed on the *terminal emulator's* machine, not the server — see below |

## Run it

```bash
bash .claude/skills/nvim-env-setup/scripts/bootstrap.sh
```

Flags:

- `--skip-system` — only do the Neovim-side work (plugins, Mason, parsers); no apt/downloads
- `--verify-only` — run the verification pass and nothing else
- `NVIM_VERSION=v0.11.7 NODE_VERSION=v24.18.0 bash ... ` — pin different versions

The script installs Neovim and Node as self-contained tarballs under `/opt` with
symlinks in `/usr/local/bin`, so it never fights the distro's package manager.
`sudo` is used only for those two steps and for `apt-get install` of build tools.

## What it does, in order

1. **System deps** — verifies/installs git, curl, gcc, make, unzip, ripgrep, python3-venv (apt on Debian/Ubuntu, Homebrew on macOS).
2. **Neovim** — if `nvim` is missing or < 0.11, downloads the official release tarball to `/opt/nvim-<arch>` and symlinks `/usr/local/bin/nvim`.
3. **Node.js** — if missing or < 20, installs the LTS tarball to `/opt/node-*` and symlinks `node`, `npm`, `npx`. Sets npm's global prefix to `~/.local` so `npm i -g` needs no sudo.
4. **tree-sitter-cli** — `npm install -g tree-sitter-cli`.
5. **Plugins** — `nvim --headless "+Lazy! sync" +qa`. This also writes the base46 theme cache that `init.lua` `dofile`s.
6. **Mason packages** — `scripts/mason_install.lua`, which derives the package list from *this repo* (see below) and blocks until every install finishes, then prints a summary.
7. **Treesitter parsers** — `TSInstallSync!` for the union of NvChad's defaults and this repo's `ensure_installed`.
8. **Verify** — `scripts/verify.lua` opens a real buffer per language in a pty and asserts LSP attach, treesitter highlighting, formatter availability, and linter diagnostics.

## How the Mason package list is derived

`scripts/mason_install.lua` reads, in this order:

1. `ensure_installed` from the `mason.nvim` spec in `lua/plugins/init.lua`
2. `M.mason.pkgs` from `lua/chadrc.lua`
3. names it finds in `lua/configs/lspconfig.lua` and `lua/configs/conform.lua`, mapped
   through `LSP_TO_PKG` / `FMT_TO_PKG` (e.g. `ts_ls` → `typescript-language-server`,
   `clang-format` → `clang-format`)

Step 3 matters: servers enabled in `lspconfig.lua` and formatters named in
`conform.lua` are **not** all listed in `ensure_installed`, so a naive read of that
list alone leaves `ts_ls` and `clang-format` missing.

Override entirely with `MASON_PKGS="pkg1,pkg2" nvim --headless -c "luafile .../mason_install.lua"`.

## Gotchas worth knowing

- **`ensure_installed` on `mason.nvim` is inert.** NvChad v2.5 declares `mason.nvim`
  with `opts = function() return require "nvchad.configs.mason" end`; a function-valued
  parent `opts` replaces the child table, so this repo's `ensure_installed` never
  reaches Mason. There is also no `:MasonInstallAll` command in current NvChad. That
  is exactly why this skill drives installs through the Mason registry API instead.
- **`:TSInstallAll` errors on this config.** NvChad's version calls
  `require("nvim-treesitter").install(...)`, which only exists on nvim-treesitter's
  `main` branch; this repo pins `master`. Use `:TSInstall`/`:TSInstallSync` instead.
- **Headless `-c` runs before `UIEnter`.** NvChad lazy-loads `nvim-lspconfig` on its
  `User FilePost` event, which is gated on `vim.g.ui_entered`. A plain
  `nvim --headless -c '...'` will therefore *never* see an LSP client attach. Verify
  LSP inside a pty (`script -qec "nvim ..." /dev/null`) and defer the assertions a
  few seconds — that is what `verify.lua` does. Missing clients in headless mode are
  a test artifact, not a broken config.
- **`nvim -l script.lua` does not source `init.lua`**, so `require "lazy"` fails.
  Use `nvim --headless -c "luafile <script>"`.
- **`E492: Not an editor command: <Plugin>Cmd` has two causes here.** Either the
  plugin's `setup()` bailed (aerial does this below Neovim 0.12 — check `:messages`
  for a deprecation notice), or the lazy spec has `keys` but no `cmd`, so typing the
  command never triggers the load. Both applied to aerial; the spec now carries
  `cmd = { "AerialToggle", "AerialOpen", "AerialNavToggle" }`.
- **`lazy-lock.json` is gitignored in this repo, so machines drift.** A fresh clone
  gets plugin HEAD, an older machine keeps whatever it locked. That is how a config
  can work on Neovim 0.11.6 on one box and fail on another with the same commit.
  When diagnosing "works on my other machine", compare
  `git -C ~/.local/share/nvim/lazy/<plugin> log -1` on both, not just the config.
- **Nerd Font is client-side.** On a headless/remote box, installing fonts does
  nothing — the font must be set in the terminal emulator you connect *from*
  (iTerm2, Windows Terminal, Ghostty, Alacritty, …). Pick a non-"Mono" variant from
  <https://www.nerdfonts.com/font-downloads> or icons render at the wrong width.
- Distro Neovim is often too old (Ubuntu 24.04 ships 0.9.5). `/usr/local/bin`
  precedes `/usr/bin` on a default PATH, so the tarball install wins without
  removing the apt package.

## Verifying by hand

```bash
nvim --version | head -1                    # expect >= 0.11
nvim --headless +qa                         # expect zero output
nvim +checkhealth                           # lazy, mason, treesitter, lspconfig sections
bash .claude/skills/nvim-env-setup/scripts/bootstrap.sh --verify-only
```
