# Visual module notes

The repo now splits visual polish into small, opt-in layers so desktop installs can look coherent without making the base shell or tmux behavior surprising for agents.

## Palette and coordination

The shared visual palette stays close to the tmux theme accents already used in `modules/visual/home/.config/tmux/theme.conf`:

- background: `#262626`
- session / identity accent: `#5f5faf`
- prompt / active accent: `#5fd7ff`
- status / selection accent: `#005f87`
- muted secondary text: `#87afaf`

That keeps tmux, prompt, and terminal tabs visually aligned while preserving stock tmux keybindings and plain shell semantics.

## Modules

### `visual`
- optional tmux theme overrides only
- sourced automatically by `~/.tmux.conf` when `~/.config/tmux/theme.conf` exists
- no prefix remap or workflow changes

### `nvim`
- installs `~/.config/nvim/init.lua`
- keeps the plugin set bounded and UI-focused:
  - `neo-tree`
  - `lualine`
  - `gitsigns`
  - `kanagawa`
- gives desktop profiles a richer editor screen without default leader remaps or plugin keybinding overrides

### `terminal`
- opt-in terminal presets for WezTerm and Alacritty
- installs:
  - `~/.config/wezterm/wezterm.lua`
  - `~/.config/alacritty/alacritty.toml`
- defaults to Nerd Font-friendly settings, truecolor-safe `xterm-256color`, comfortable padding, and a palette that matches tmux accents
- avoids terminal-level keyboard remaps such as Option-as-Alt or disabled dead-key handling

### `prompt`
- installs `~/.config/dotfiles/interactive.d/80-prompt.sh` plus rich interactive extras
- is enabled only when the `prompt` module is applied
- adds colorized `user@host`, cwd, and prompt-char styling; no aliases, shell traps, or command wrappers
- rich profiles get additional interactive scripts: completions, FZF bindings, rich plugins, and CLI aliases

## Font guidance

Recommended fonts for the terminal presets:

1. `JetBrainsMono Nerd Font` (primary default)
2. `SauceCodePro Nerd Font`
3. `Hack Nerd Font`
4. `Symbols Nerd Font Mono` for fallback glyph coverage

Nerd Font v3 is preferred so terminal tab icons, prompt glyphs, and Neovim UI icons stay consistent.

## Rich prompt (Powerlevel10k)

Rich profiles detect [Powerlevel10k](https://github.com/romkatv/powerlevel10k) and activate it automatically. When P10k is absent, the existing simple prompt is used as a fallback.

Install P10k:

```sh
dotfiles tools install powerlevel10k
```

P10k is configured via `~/.config/dotfiles/p10k.zsh` with:
- Two-line prompt with transient prompt support
- `❯` prompt character (green on success, red on failure)
- Left: os_icon, dir, vcs (git status)
- Right: status, execution time (>3s), background jobs, virtualenv, pyenv, node, kubecontext, time

To customize, run `p10k configure` or edit `~/.config/dotfiles/p10k.zsh` directly.

## Rich plugins (fast-syntax-highlighting)

When installed, [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) replaces the standard `zsh-syntax-highlighting` for richer, more accurate coloring:

```sh
dotfiles tools install fast-syntax-highlighting
```

The upgrade is automatic — `82-rich-plugins.zsh` detects F-Sy-H and disables the standard highlighter.

## Rich FZF integration

Rich profiles enable FZF shell keybindings that the core module intentionally leaves disabled:

- **Ctrl-T**: File search with bat preview (falls back to cat)
- **Ctrl-R**: History search
- **Alt-C**: Directory cd with eza tree preview (falls back to tree/ls)
- **Ctrl-/**: Toggle preview in any FZF picker

Install the fzf-git plugin for git-aware FZF pickers:

```sh
dotfiles tools install fzf-git
```

## Rich CLI tools

Install visual CLI tool upgrades:

```sh
dotfiles packages --set visual
```

This installs `eza`, `bat`, and `tree`. Rich profiles then activate these aliases:

| Alias | Command |
|-------|---------|
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza -l --group --git --icons --group-directories-first` |
| `la` | `eza -la --group --git --icons --group-directories-first` |
| `lt` | `eza --tree --level=2 --icons --group-directories-first` |
| `preview` | `bat --color=always --style=numbers` |

## Rich neovim

Rich profiles ship ~28 neovim plugins for wookayin-level visual richness. All plugins use lazy loading and **zero custom keybindings** — only stock neovim 0.10+ defaults.

### Plugin categories

| Category | Plugins |
|----------|---------|
| Colorscheme | kanagawa (dragon theme) |
| Git | gitsigns, diffview |
| UI | lualine (+ navic breadcrumbs), neo-tree, telescope |
| Treesitter | nvim-treesitter (26 languages, auto-install) |
| Editor | indent-blankline, nvim-colorizer, todo-comments, which-key |
| Markdown | render-markdown |
| Notifications | nvim-notify, noice, dressing, fidget |
| LSP | nvim-lspconfig, mason, mason-lspconfig, nvim-navic, lsp_signature |
| Completion | nvim-cmp, cmp-nvim-lsp, cmp-buffer, cmp-path, lspkind |
| Diagnostics | trouble |

### Standard keybindings (neovim 0.10+ built-in)

- `gd`: Go to definition
- `gr`: References
- `K`: Hover documentation
- `[d` / `]d`: Previous/next diagnostic
- `<C-n>` / `<C-p>`: Next/previous completion item
- `<C-y>`: Accept completion
- `<C-e>`: Dismiss completion

### Commands

- `:Telescope find_files`, `:Telescope live_grep`, `:Telescope buffers`
- `:Neotree toggle left`, `:Neotree float reveal`
- `:Trouble diagnostics`
- `:DiffviewOpen`, `:DiffviewFileHistory`
- `:LspInfo`, `:Mason`

## Full setup one-liner

For maximum richness from a fresh install:

```sh
dotfiles apply --profile macos-desktop-rich && \
dotfiles tools install powerlevel10k && \
dotfiles tools install fast-syntax-highlighting && \
dotfiles tools install fzf-git && \
dotfiles packages --set visual
```

## Opt-in prompt activation

Apply the rich desktop profile when you want terminal + prompt polish:

```sh
~/.dotfiles/bin/dotfiles apply --profile macos-desktop-rich
~/.dotfiles/bin/dotfiles apply --profile linux-desktop-rich
```

The base desktop profiles keep the heavier terminal-emulator and prompt choices separate from the standard-first default.

## Validation

Use isolated temp-`HOME` flows for visual verification:

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
sh tests/install_smoke.sh fresh
sh tests/install_qa.sh flows
```

Expected profile behavior:
- `linux-desktop` / `macos-desktop`: tmux + nvim visual layers are managed
- `linux-desktop-rich` / `macos-desktop-rich`: terminal and prompt layers are added on top
- `base` / `ssh-server`: desktop visual extras stay absent
