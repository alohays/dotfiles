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
  { import = 'dotfiles.plugins' },
}, {
  install = {
    colorscheme = { 'kanagawa' },
  },
  change_detection = {
    notify = false,
  },
})
