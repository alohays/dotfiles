# Visual module notes

The base tmux module stays standard-first: default prefix, stock keymap, and only low-risk quality-of-life settings. That keeps the default environment predictable for coding agents while still leaving room for humans to opt into a nicer-looking terminal.

The optional visual module provides `~/.config/tmux/theme.conf`, which is sourced automatically by `~/.tmux.conf` when present. It changes only colors and status-line presentation, so the repo can stay boring in the agent-facing path and still feel beautiful when a human wants the extra polish.

Scope intentionally stays narrow for v1:
- no tmux prefix remap or custom keybindings
- no shell prompt/theme integration
- no terminal-emulator-specific settings

This keeps the default experience predictable, token-efficient, and easy for agents to reason about while leaving a clean opt-in path for light polish.
