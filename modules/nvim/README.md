# nvim module

Opt-in Neovim UI layer for desktop profiles.

## Included UI pieces
- Kanagawa truecolor theme
- Neo-tree file explorer
- Lualine statusline + winbar
- Gitsigns gutter markers
- Telescope pickers for files, grep, buffers, and help tags

## Commands
- `:Neotree toggle left`
- `:Neotree float reveal`
- `:Neotree git_status right`
- `:Telescope find_files hidden=true`
- `:Telescope live_grep`
- `:Telescope buffers`
- `:Telescope help_tags`

## Notes
- Uses `lazy.nvim` bootstrap on first launch.
- Keeps Neovim semantics close to upstream defaults.
- Installs no default leader remaps or plugin keybinding overrides.
