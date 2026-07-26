-- Verification pass for this config. Opens a real buffer per language and
-- asserts: LSP attaches, treesitter highlighting is active, conform formatters
-- are available, nvim-lint produces diagnostics.
--
-- MUST run inside a pty with a real UI, because NvChad lazy-loads nvim-lspconfig
-- on `User FilePost`, which is gated on `vim.g.ui_entered` (never true under a
-- plain `nvim --headless`). The bootstrap script runs this via:
--   script -qec "nvim -c 'luafile verify.lua'" /dev/null
--
-- Results are written to $NVIM_VERIFY_OUT (default /tmp/nvim-verify.txt) since
-- stdout in a pty is full of escape codes.

local OUT = vim.env.NVIM_VERIFY_OUT or "/tmp/nvim-verify.txt"

vim.defer_fn(function()
  local log, failures = {}, 0
  local function record(ok, line)
    if not ok then
      failures = failures + 1
    end
    log[#log + 1] = (ok and "[ok]   " or "[FAIL] ") .. line
  end

  log[#log + 1] = "neovim " .. tostring(vim.version())
  -- 0.12 floor comes from aerial.nvim, not NvChad; see SKILL.md
  record(vim.version().minor >= 12 or vim.version().major > 0, "neovim >= 0.12")

  -- external tools on nvim's PATH (NvChad prepends the mason bin dir)
  for _, tool in ipairs { "git", "gcc", "make", "node", "npm", "tree-sitter", "rg" } do
    local path = vim.fn.exepath(tool)
    record(path ~= "", ("tool %-14s %s"):format(tool, path ~= "" and path or "MISSING"))
  end

  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")

  local cases = {
    { file = "a.py", lsp = "ty", lines = { "import os", "def f(x: int) -> int:", "    return x + 1" } },
    { file = "b.lua", lsp = "lua_ls", lines = { "local M = {}", "function M.go() return 1 end", "return M" } },
    {
      file = "c.cpp",
      lsp = "clangd",
      lines = { "#include <vector>", "int main() { std::vector<int> v; return v.size(); }" },
    },
    { file = "d.html", lsp = "html", lines = { "<html><body><p>hi</p></body></html>" } },
    { file = "e.css", lsp = "cssls", lines = { "body { color: red; }" } },
  }

  for _, case in ipairs(cases) do
    local path = tmp .. "/" .. case.file
    vim.fn.writefile(case.lines, path)
    vim.cmd.edit(path)
    local buf = vim.api.nvim_get_current_buf()
    local attached = vim.wait(30000, function()
      return #vim.lsp.get_clients { bufnr = buf, name = case.lsp } > 0
    end, 200)
    local ts = vim.treesitter.highlighter.active[buf] ~= nil
    record(attached, ("lsp %-8s -> %s"):format(case.lsp, case.file))
    record(ts, ("treesitter highlight -> %s (ft=%s)"):format(case.file, vim.bo[buf].filetype))
  end

  -- formatters resolvable
  local wanted = { stylua = true, isort = true, ruff_format = true, ["clang-format"] = true, prettier = true }
  for _, fmt in ipairs(require("conform").list_all_formatters()) do
    if wanted[fmt.name] then
      record(fmt.available, ("formatter %-13s available"):format(fmt.name))
      wanted[fmt.name] = nil
    end
  end
  for name in pairs(wanted) do
    record(false, ("formatter %-13s not configured"):format(name))
  end

  -- end-to-end format of a python buffer (isort + ruff_format)
  local py = tmp .. "/fmt.py"
  vim.fn.writefile({ "import sys", "import os", "x   =   1", "print(os, sys)" }, py)
  vim.cmd.edit(py)
  require("conform").format { bufnr = 0, async = false, timeout_ms = 20000 }
  local formatted = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  record(
    formatted[1] == "import os" and vim.tbl_contains(formatted, "x = 1"),
    "conform formats python: " .. table.concat(formatted, " | ")
  )

  -- aerial: regression guard. On nvim < 0.12 aerial's setup() returns before
  -- create_commands(), so <leader>a dies with E492 and nothing else reveals it.
  vim.cmd.edit(tmp .. "/a.py")
  local toggled = pcall(vim.cmd, "AerialToggle!")
  local aerial_win = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "aerial" then
      aerial_win = true
    end
  end
  record(toggled and aerial_win, "aerial :AerialToggle opens a window")
  if aerial_win then
    pcall(vim.cmd, "AerialClose")
  end

  -- linter produces diagnostics (unused import)
  vim.cmd.edit(tmp .. "/a.py")
  require("lint").try_lint()
  local linted = vim.wait(20000, function()
    return #vim.diagnostic.get(0, { severity = nil }) > 0
  end, 250)
  record(linted, "ruff lint diagnostics on a.py")

  log[#log + 1] = failures == 0 and "ALL CHECKS PASSED" or (failures .. " CHECK(S) FAILED")
  vim.fn.writefile(log, OUT)
  vim.cmd "qa!"
end, 3000)
