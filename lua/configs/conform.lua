local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "isort", "ruff_format" },
    -- css = { "prettier" },
    -- html = { "prettier" },
  },

  -- Uncomment to enable auto format on save
  --[[ format_on_save = {
    lsp_fallback = true,
    async = false,
    timeout_ms = 500,
  }, ]]

  log_level = vim.log.levels.ERROR,
}

require("conform").setup(options)
