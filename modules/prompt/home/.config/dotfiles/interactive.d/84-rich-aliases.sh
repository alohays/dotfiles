# Rich CLI aliases: colorized tool upgrades for human-facing rich profiles.
# shellcheck shell=sh

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l --group --git --icons --group-directories-first'
  alias la='eza -la --group --git --icons --group-directories-first'
  alias lt='eza --tree --level=2 --icons --group-directories-first'
fi

if command -v bat >/dev/null 2>&1; then
  alias preview='bat --color=always --style=numbers'
fi
