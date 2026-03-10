# Visual module notes

The base tmux module stays standard-first: default prefix, stock keymap, and only low-risk quality-of-life settings.

The optional visual module provides `~/.config/tmux/theme.conf`, which is sourced automatically by `~/.tmux.conf` when present. It changes only colors and status-line presentation.

Scope intentionally stays narrow for v1:
- no tmux prefix remap or custom keybindings
- no shell prompt/theme integration
- no terminal-emulator-specific settings

This keeps the default experience predictable while leaving a clean opt-in path for light polish.
