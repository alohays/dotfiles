return {
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'SmiteshP/nvim-navic',
    },
    opts = function()
      local navic_ok, navic = pcall(require, 'nvim-navic')
      local winbar_c = {
        {
          'filename',
          path = 1,
          symbols = { modified = ' ●', readonly = ' ', unnamed = ' [No Name]' },
        },
      }
      if navic_ok then
        table.insert(winbar_c, {
          function() return navic.get_location() end,
          cond = function() return navic.is_available() end,
        })
      end
      return {
        options = {
          theme = 'auto',
          globalstatus = true,
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = {
            'branch',
            { 'diff', cond = function() return vim.fn.winwidth(0) > 80 end },
          },
          lualine_c = { { 'filename', path = 1 } },
          lualine_x = {
            'diagnostics',
            { 'filetype', cond = function() return vim.fn.winwidth(0) > 70 end },
          },
          lualine_y = {
            { 'progress', cond = function() return vim.fn.winwidth(0) > 60 end },
          },
          lualine_z = { 'location' },
        },
        winbar = {
          lualine_c = winbar_c,
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
      source_selector = {
        winbar = true,
        sources = {
          { source = 'filesystem', display_name = ' Files' },
          { source = 'git_status', display_name = ' Git' },
          { source = 'buffers', display_name = '󰈙 Bufs' },
        },
      },
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = { force_visible_in_empty_folder = true },
        use_libuv_file_watcher = true,
        window = { width = 30 },
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
            ignored = '',
            unstaged = '*',
            staged = '✓',
            conflict = '',
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
      return {
        defaults = {
          prompt_prefix = '  ',
          selection_caret = ' ',
          layout_strategy = 'horizontal',
          sorting_strategy = 'ascending',
          layout_config = {
            prompt_position = 'top',
            preview_width = 0.55,
          },
          path_display = { 'truncate' },
          winblend = 8,
          borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
          file_ignore_patterns = { '%.git/', 'node_modules/' },
        },
        pickers = {
          find_files = {
            hidden = true,
          },
        },
      }
    end,
  },
}
