{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [
      ripgrep
      fd
      tree-sitter
      nixd
      pyright
      clang-tools
    ];
    plugins = with pkgs.vimPlugins; [
      github-nvim-theme
      mini-icons
      plenary-nvim
      nvim-web-devicons
      telescope-nvim
      (nvim-treesitter.withPlugins (plugins: [
        plugins.nix
        plugins.python
        plugins.c
        plugins.cpp
      ]))
      nvim-lspconfig
      mason-nvim
      mason-lspconfig-nvim
      nvim-cmp
      cmp-buffer
      cmp-nvim-lsp
      cmp-path
      which-key-nvim
      nvim-autopairs
      indent-blankline-nvim
      bufferline-nvim
    ];
    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      vim.opt.termguicolors = true
      require("github-theme").setup({})
      vim.cmd.colorscheme("github_light_default")

      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.cursorline = true
      vim.opt.signcolumn = "yes"
      vim.opt.showtabline = 2

      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.tabstop = 2
      vim.opt.smartindent = true

      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.incsearch = true
      vim.opt.hlsearch = false

      vim.opt.splitright = true
      vim.opt.splitbelow = true

      vim.opt.wrap = false
      vim.opt.scrolloff = 8
      vim.opt.sidescrolloff = 8

      vim.opt.mouse = "a"
      vim.opt.clipboard = "unnamedplus"
      vim.opt.undofile = true
      vim.opt.updatetime = 250
      vim.opt.timeout = true
      vim.opt.timeoutlen = 300
      vim.opt.completeopt = { "menu", "menuone", "noselect" }

      vim.opt.list = true
      vim.opt.listchars = { tab = ">> ", trail = ".", nbsp = "+" }

      local telescope = require("telescope")
      local telescope_builtin = require("telescope.builtin")
      local cmp = require("cmp")
      local cmp_lsp = require("cmp_nvim_lsp")
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local wk = require("which-key")

      telescope.setup({
        defaults = {
          path_display = { "smart" },
        },
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "nix", "python", "c", "cpp" },
        callback = function()
          vim.treesitter.start()
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })

      wk.setup({})
      wk.add({
        { "<leader>f", group = "find" },
        { "<leader>b", group = "buffer" },
        { "<leader>l", group = "lsp" },
        { "<leader>m", group = "mason" },
      })

      require("nvim-autopairs").setup({})

      require("ibl").setup({
        indent = {
          char = "│",
        },
        scope = {
          enabled = false,
        },
      })

      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          always_show_bufferline = true,
        },
      })

      cmp.setup({
        snippet = {
          expand = function(args)
            vim.snippet.expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
      })

      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())

      require("mason").setup({
        PATH = "append",
      })

      require("mason-lspconfig").setup({
        ensure_installed = {},
        automatic_enable = false,
      })

      local capabilities = cmp_lsp.default_capabilities()

      vim.lsp.config("nixd", {
        capabilities = capabilities,
        settings = {
          nixd = {
            formatting = {
              command = { "nixfmt" },
            },
          },
        },
      })

      vim.lsp.config("pyright", {
        capabilities = capabilities,
      })

      vim.lsp.config("clangd", {
        capabilities = capabilities,
      })

      for _, server in ipairs({ "nixd", "pyright", "clangd" }) do
        vim.lsp.enable(server)
      end

      vim.diagnostic.config({
        severity_sort = true,
        float = {
          border = "rounded",
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, desc = desc })
          end

          map("n", "K", vim.lsp.buf.hover, "Hover")
          map("n", "gd", telescope_builtin.lsp_definitions, "Go to definition")
          map("n", "gr", telescope_builtin.lsp_references, "Go to references")
          map("n", "gI", telescope_builtin.lsp_implementations, "Go to implementation")
          map("n", "<leader>la", vim.lsp.buf.code_action, "Code action")
          map("v", "<leader>la", vim.lsp.buf.code_action, "Code action")
          map("n", "<leader>ld", telescope_builtin.diagnostics, "Diagnostics")
          map("n", "<leader>lf", function()
            vim.lsp.buf.format({ async = true })
          end, "Format buffer")
          map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol")
          map("n", "<leader>ls", telescope_builtin.lsp_document_symbols, "Document symbols")
        end,
      })

      vim.keymap.set("n", "<leader>?", function()
        wk.show({ global = false })
      end, { desc = "Buffer local keymaps" })

      vim.keymap.set("n", "<leader>ff", telescope_builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", telescope_builtin.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", telescope_builtin.buffers, { desc = "Find buffers" })
      vim.keymap.set("n", "<leader>fh", telescope_builtin.help_tags, { desc = "Help tags" })

      vim.keymap.set("n", "<leader>bn", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
      vim.keymap.set("n", "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
      vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

      vim.keymap.set("n", "<leader>mm", "<cmd>Mason<cr>", { desc = "Open Mason" })
    '';
  };
}
