{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      github-nvim-theme
    ];
    initLua = ''
      vim.opt.termguicolors = true
      require("github-theme").setup({})
      vim.cmd.colorscheme("github_light_default")

      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.cursorline = true
      vim.opt.signcolumn = "yes"

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
      vim.opt.timeoutlen = 300

      vim.opt.list = true
      vim.opt.listchars = { tab = ">> ", trail = ".", nbsp = "+" }
    '';
  };
}
