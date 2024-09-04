return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    config = function()
      require "configs.conform"
    end,
  },
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require "lint"
      lint.linters_by_ft = {
        python = { "ruff" },
      }
    end,
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("nvchad.configs.lspconfig").defaults()
      require "configs.lspconfig"
    end,
  },

  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "lua-language-server",
        "stylua",
        "html-lsp",
        "css-lsp",
        "prettier",
        "pyright",
        "isort",
        "ruff",
        "clangd",
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim",
        "lua",
        "vimdoc",
        "html",
        "css",
        "python",
        "cpp",
        "c",
      },
    },
  },

  {
    "stevearc/aerial.nvim",
    lazy = true,
    opts = {
      lazy_load = true,
      backends = { ["_"] = { "treesitter", "lsp", "markdown", "man" } },
      layout = {
        max_width = { 40, 0.3 },
        width = nil,
        min_width = { 10, 0.2 },

        -- key-value pairs of window-local options for aerial window (e.g. winhl)
        win_opts = {},

        -- Determines the default direction to open the aerial window. The 'prefer'
        -- options will open the window in the other direction *if* there is a
        -- different buffer in the way of the preferred direction
        -- Enum: prefer_right, prefer_left, right, left, float
        default_direction = "right",

        -- Determines where the aerial window will be opened
        -- edge - open aerial at the far right/left of the editor
        placement = "edge",

        -- When the symbols change, resize the aerial window (within min/max constraints) to fit
        resize_to_content = false,

        -- Preserve window size equality with (:help CTRL-W_=)
        preserve_equality = false,
      },
      -- Determines how the aerial window decides which buffer to display symbols for
      -- global - aerial window will display symbols for the current window
      attach_mode = "global",
      close_automatic_events = { "unfocus", "unsupported" },
      -- A list of all symbols to display. Set to false to display all symbols.
      -- This can be a filetype map (see :help aerial-filetype-map)
      -- To see all available values, see :help SymbolKind
      filter_kind = false,
      -- filter_kind = {
      --   "Class",
      --   "Constructor",
      --   "Enum",
      --   "Function",
      --   "Interface",
      --   "Module",
      --   "Method",
      --   "Struct",
      -- },
      -- Jump to symbol in source window when the cursor moves
      autojump = false,
      -- Use symbol tree for folding. Set to true or false to enable/disable
      -- Set to "auto" to manage folds if your previous foldmethod was 'manual'
      -- This can be a filetype map (see :help aerial-filetype-map)
      manage_folds = true,

      -- When you fold code with za, zo, or zc, update the aerial tree as well.
      -- Only works when manage_folds = true
      link_folds_to_tree = false,

      -- Fold code when you open/collapse symbols in the tree.
      -- Only works when manage_folds = true
      link_tree_to_folds = false,

      -- Call this function when aerial attaches to a buffer.
      on_attach = function(bufnr)
        local aerial = require "aerial"
        -- make sure source code is unfolded
        aerial.open_all()
        aerial.sync_folds(bufnr)
        -- set default fold level to 1
        aerial.tree_set_collapse_level(bufnr, 1)
      end,

      show_trailing_blankline_indent = false,
      use_treesitter = true,
      char = "▏",
      context_char = "▏",
      show_current_context = true,
      buftype_exclude = {
        "nofile",
        "terminal",
      },
      filetype_exclude = {
        "help",
        "startify",
        "aerial",
        "alpha",
        "dashboard",
        "lazy",
        "neogitstatus",
        "NvimTree",
        "neo-tree",
        "Trouble",
      },
      context_patterns = {
        "class",
        "return",
        "function",
        "method",
        "^if",
        "^while",
        "jsx_element",
        "^for",
        "^object",
        "^table",
        "block",
        "arguments",
        "if_statement",
        "else_clause",
        "jsx_element",
        "jsx_self_closing_element",
        "try_statement",
        "catch_clause",
        "import_statement",
        "operation_type",
      },
    },
    -- Optional dependencies
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    keys = { { "<leader>a", "<cmd>AerialToggle!<cr>", desc = "Tag Outline" } },
  },
}
