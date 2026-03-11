# nvim module

Opt-in Neovim UI layer for desktop profiles.

## Included UI pieces
- Kanagawa truecolor theme
- Neo-tree file explorer
- Lualine statusline + winbar
- Gitsigns gutter markers
- Telescope pickers for files, grep, buffers, and help tags

## Keymaps
- `<leader>e` — toggle file tree
- `<leader>E` — reveal current file in floating tree
- `<leader>gg` — open git-status tree
- `<leader>ff` — find files
- `<leader>fg` — live grep
- `<leader>fb` — list buffers
- `<leader>fh` — search help tags

## Notes
- Uses `lazy.nvim` bootstrap on first launch.
- Keeps Neovim semantics close to upstream defaults; this module adds explicit UI plugins and keymaps only.
