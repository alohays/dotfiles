return {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'SmiteshP/nvim-navic',
      'ray-x/lsp_signature.nvim',
    },
    config = function()
      local lspconfig = require('lspconfig')
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local cmp_ok, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
      if cmp_ok then
        capabilities = vim.tbl_deep_extend('force', capabilities, cmp_lsp.default_capabilities())
      end

      local navic_ok, navic = pcall(require, 'nvim-navic')

      local on_attach = function(client, bufnr)
        if navic_ok and client.server_capabilities.documentSymbolProvider then
          navic.attach(client, bufnr)
        end
        local sig_ok, sig = pcall(require, 'lsp_signature')
        if sig_ok then
          sig.on_attach({ bind = true, handler_opts = { border = 'rounded' } }, bufnr)
        end
      end

      require('mason').setup()
      require('mason-lspconfig').setup({
        ensure_installed = { 'lua_ls', 'pyright', 'ts_ls', 'jsonls', 'yamlls', 'bashls' },
        handlers = {
          function(server_name)
            lspconfig[server_name].setup({
              capabilities = capabilities,
              on_attach = on_attach,
            })
          end,
          ['lua_ls'] = function()
            lspconfig.lua_ls.setup({
              capabilities = capabilities,
              on_attach = on_attach,
              settings = {
                Lua = {
                  workspace = { checkThirdParty = false },
                  telemetry = { enable = false },
                  diagnostics = { globals = { 'vim' } },
                },
              },
            })
          end,
        },
      })
    end,
  },
  {
    'SmiteshP/nvim-navic',
    lazy = true,
    opts = {
      lsp = { auto_attach = false },
      highlight = true,
    },
  },
  {
    'ray-x/lsp_signature.nvim',
    lazy = true,
    opts = {},
  },
}
