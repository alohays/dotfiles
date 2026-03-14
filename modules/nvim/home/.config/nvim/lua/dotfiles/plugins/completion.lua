return {
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'onsails/lspkind.nvim',
    },
    config = function()
      local cmp = require('cmp')
      local lspkind = require('lspkind')

      cmp.setup({
        window = {
          completion = cmp.config.window.bordered({
            winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel',
          }),
          documentation = cmp.config.window.bordered({
            winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder',
          }),
        },
        formatting = {
          format = lspkind.cmp_format({
            mode = 'symbol_text',
            maxwidth = 50,
            ellipsis_char = '…',
          }),
        },
        mapping = {
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-p>'] = cmp.mapping.select_prev_item(),
          ['<C-y>'] = cmp.mapping.confirm({ select = true }),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<C-d>'] = cmp.mapping.scroll_docs(4),
          ['<C-u>'] = cmp.mapping.scroll_docs(-4),
        },
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'path' },
        }, {
          { name = 'buffer' },
        }),
        experimental = {
          ghost_text = true,
        },
      })
    end,
  },
}
