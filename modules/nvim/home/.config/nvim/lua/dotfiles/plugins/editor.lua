return {
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      indent = {
        char = '│',
        tab_char = '│',
      },
      scope = { show_start = false, show_end = false },
      exclude = {
        filetypes = { 'help', 'neo-tree', 'Trouble', 'lazy', 'mason', 'notify' },
      },
    },
  },
  {
    'NvChad/nvim-colorizer.lua',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      user_default_options = {
        names = false,
        tailwind = false,
      },
    },
  },
  {
    'folke/todo-comments.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {},
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {},
  },
  {
    'folke/zen-mode.nvim',
    cmd = 'ZenMode',
    opts = { window = { width = 90 } },
  },
  {
    'dstein64/nvim-scrollview',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      excluded_filetypes = { 'neo-tree', 'Trouble', 'lazy', 'mason', 'notify' },
      current_only = true,
      winblend = 50,
    },
  },
}
