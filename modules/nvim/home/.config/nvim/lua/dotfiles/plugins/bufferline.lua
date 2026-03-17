return {
  'akinsho/bufferline.nvim',
  version = '*',
  event = 'VeryLazy',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  opts = {
    options = {
      diagnostics = 'nvim_lsp',
      offsets = {
        { filetype = 'neo-tree', text = 'File Explorer', highlight = 'Directory', separator = true },
      },
      show_buffer_close_icons = false,
      show_close_icon = false,
      separator_style = 'thin',
    },
  },
}
