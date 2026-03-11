local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
  if vim.v.shell_error ~= 0 or not vim.uv.fs_stat(lazypath) then
    vim.schedule(function()
      vim.notify(
        'lazy.nvim bootstrap failed; Neovim visual plugins are unavailable until network/bootstrap succeeds.',
        vim.log.levels.WARN
      )
    end)
    return
  end
end
vim.opt.rtp:prepend(lazypath)

local ok, lazy = pcall(require, 'lazy')
if not ok then
  vim.schedule(function()
    vim.notify('lazy.nvim is unavailable; skipping visual plugin setup.', vim.log.levels.WARN)
  end)
  return
end

lazy.setup({
  {
    'rebelot/kanagawa.nvim',
    priority = 1000,
    config = function()
      require('kanagawa').setup({
        transparent = false,
        theme = 'dragon',
      })
      vim.cmd.colorscheme('kanagawa')
    end,
  },
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      current_line_blame = false,
      signs = {
        add = { text = '▎' },
        change = { text = '▎' },
        delete = { text = '' },
        topdelete = { text = '' },
        changedelete = { text = '▎' },
      },
    },
  },
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = function()
      return {
        options = {
          theme = 'auto',
          globalstatus = true,
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff' },
          lualine_c = {
            { 'filename', path = 1 },
          },
          lualine_x = { 'diagnostics', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
        winbar = {
          lualine_c = {
            {
              'filename',
              path = 1,
              symbols = { modified = ' ●', readonly = ' ', unnamed = ' [No Name]' },
            },
          },
        },
        inactive_winbar = {
          lualine_c = { { 'filename', path = 1 } },
        },
      }
    end,
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    cmd = 'Neotree',
    opts = {
      close_if_last_window = true,
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = { force_visible_in_empty_folder = true },
        use_libuv_file_watcher = true,
        window = {
          width = 30,
          mappings = {
            ['I'] = 'toggle_hidden',
            ['z'] = 'none',
            ['/'] = 'fuzzy_finder',
          },
        },
      },
      default_component_configs = {
        indent = {
          indent_size = 2,
          padding = 0,
          with_markers = true,
          indent_marker = '│',
          last_indent_marker = '└',
        },
        icon = {
          folder_closed = '󰉋',
          folder_open = '󰝰',
          folder_empty = '󰉖',
          default = '󰈙',
        },
        git_status = {
          symbols = {
            added = '✚',
            modified = '●',
            deleted = '✖',
            renamed = '󰁕',
            untracked = '?',
            ignored = '',
            unstaged = '*',
            staged = '✓',
            conflict = '',
          },
        },
      },
    },
  },
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    opts = function()
      local actions = require('telescope.actions')

      return {
        defaults = {
          prompt_prefix = '  ',
          selection_caret = ' ',
          layout_strategy = 'horizontal',
          sorting_strategy = 'ascending',
          layout_config = {
            prompt_position = 'top',
            preview_width = 0.55,
          },
          path_display = { 'truncate' },
          winblend = 6,
          mappings = {
            i = {
              ['<Esc>'] = actions.close,
            },
          },
        },
        pickers = {
          find_files = {
            hidden = true,
          },
        },
      }
    end,
  },
}, {
  install = {
    colorscheme = { 'kanagawa' },
  },
  change_detection = {
    notify = false,
  },
})
