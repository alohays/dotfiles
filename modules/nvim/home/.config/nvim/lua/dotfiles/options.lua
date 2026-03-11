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
  foldopen = '',
  foldclose = '',
  fold = ' ',
  diff = '╱',
  eob = ' ',
}
