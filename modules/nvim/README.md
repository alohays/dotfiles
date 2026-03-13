# nvim module

Opt-in Neovim UI layer for desktop profiles with ~28 plugins for rich visual editing.

## Included UI pieces
- Kanagawa truecolor theme (dragon variant)
- Neo-tree file explorer with git status icons
- Lualine statusline + navic breadcrumb winbar
- Gitsigns gutter markers + diffview for git diffs
- Telescope fuzzy pickers for files, grep, buffers, and help tags
- nvim-treesitter for syntax highlighting and indentation (26 languages)
- indent-blankline for visual indent guides
- nvim-colorizer for inline color preview
- todo-comments for highlighted TODO/FIXME/HACK markers
- which-key for discovering available keybindings
- render-markdown for rendered markdown previews
- nvim-notify + noice for rich notifications and command palette UI
- dressing for improved vim.ui.select/input
- fidget for LSP progress indicators
- nvim-lspconfig + mason for auto-installed language servers
- nvim-cmp for completion with LSP, buffer, and path sources
- trouble for structured diagnostics list

## Commands
- `:Neotree toggle left`
- `:Neotree float reveal`
- `:Neotree git_status right`
- `:Telescope find_files hidden=true`
- `:Telescope live_grep`
- `:Telescope buffers`
- `:Telescope help_tags`
- `:Trouble diagnostics`
- `:DiffviewOpen`
- `:DiffviewFileHistory`
- `:LspInfo`
- `:Mason`

## Notes
- Uses `lazy.nvim` bootstrap on first launch.
- Keeps Neovim semantics close to upstream defaults.
- Installs no default leader remaps or plugin keybinding overrides.
- Completion uses only stock vim keys: `C-n`, `C-p`, `C-y`, `C-e`, `C-d`, `C-u`.
- LSP uses neovim 0.10+ built-in mappings: `gd`, `gr`, `K`, `[d`/`]d`.
