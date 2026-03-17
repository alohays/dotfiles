return {
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      current_line_blame = false,
      signs = {
        add = { text = '▎' },
        change = { text = '▎' },
        delete = { text = '' },
        topdelete = { text = '' },
        changedelete = { text = '▎' },
      },
    },
  },
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {},
  },
  {
    'rhysd/git-messenger.vim',
    cmd = 'GitMessenger',
    init = function()
      vim.g['git_messenger_no_default_mappings'] = true
    end,
  },
}
