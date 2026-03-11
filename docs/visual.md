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
- installs `~/.config/dotfiles/interactive.d/80-prompt.sh`
- is enabled only when the `prompt` module is applied
- adds only colorized `user@host`, cwd, and prompt-char styling; no aliases, shell traps, or command wrappers

## Font guidance

Recommended fonts for the terminal presets:

1. `JetBrainsMono Nerd Font` (primary default)
2. `SauceCodePro Nerd Font`
3. `Hack Nerd Font`
4. `Symbols Nerd Font Mono` for fallback glyph coverage

Nerd Font v3 is preferred so terminal tab icons, prompt glyphs, and Neovim UI icons stay consistent.

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
