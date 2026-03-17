local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = 'a'
opt.termguicolors = true
opt.signcolumn = 'yes'
opt.splitright = true
opt.splitbelow = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.cursorline = true
opt.laststatus = 3
opt.showmode = false
opt.clipboard = 'unnamedplus'
opt.ignorecase = true
opt.smartcase = true
opt.scrolloff = 6
opt.sidescrolloff = 6
opt.wrap = false
opt.completeopt = { 'menu', 'menuone', 'noselect' }
opt.fillchars = {
  foldopen = '',
  foldclose = '▸',
  fold = ' ',
  diff = '╱',
  eob = ' ',
}

opt.pumheight = 12
opt.list = true
opt.listchars = {
  tab = '» ',
  trail = '·',
  nbsp = '␣',
}

-- Diagnostic configuration with Nerd Font icons
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚',
      [vim.diagnostic.severity.WARN] = '󰀪',
      [vim.diagnostic.severity.INFO] = '󰋽',
      [vim.diagnostic.severity.HINT] = '󰌶',
    },
  },
  virtual_text = {
    spacing = 4,
    prefix = '●',
  },
  float = {
    border = 'rounded',
  },
  severity_sort = true,
})
