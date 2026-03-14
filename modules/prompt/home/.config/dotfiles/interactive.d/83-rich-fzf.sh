# Rich FZF integration: shell keybindings + preview commands.
# Enables Ctrl-T, Ctrl-R, Alt-C that the core 50-fzf.sh intentionally omits.
# shellcheck shell=sh

command -v fzf >/dev/null 2>&1 || return 0

case "${TERM:-}" in
    ''|dumb) return 0 ;;
esac

[ -t 0 ] || [ -t 1 ] || return 0

# Enable FZF shell keybindings
if [ -n "${ZSH_VERSION:-}" ]; then
  eval "$(fzf --zsh 2>/dev/null)" || true
elif [ -n "${BASH_VERSION:-}" ]; then
  eval "$(fzf --bash 2>/dev/null)" || true
fi

# Rich preview for Ctrl-T (file search)
if command -v bat >/dev/null 2>&1; then
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --bind 'ctrl-/:toggle-preview'"
else
  export FZF_CTRL_T_OPTS="--preview 'cat {}' --bind 'ctrl-/:toggle-preview'"
fi

# Rich preview for Alt-C (cd)
if command -v eza >/dev/null 2>&1; then
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"
elif command -v tree >/dev/null 2>&1; then
  export FZF_ALT_C_OPTS="--preview 'tree -C -L 2 {}'"
else
  export FZF_ALT_C_OPTS="--preview 'ls -la {}'"
fi

# Extend default opts with color palette matching the visual theme
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=fg:#c8c093,bg:#181616,hl:#5fd7ff --color=fg+:#dcd7ba,bg+:#223249,hl+:#5fd7ff --color=info:#7e9cd8,prompt:#e46876,pointer:#957fb8 --color=marker:#98bb6c,spinner:#957fb8,header:#7e9cd8 --bind 'ctrl-/:toggle-preview'"

# Source fzf-git.sh plugin if installed
_dotfiles_fzf_git="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/fzf-git.sh/fzf-git.sh"
if [ -r "$_dotfiles_fzf_git" ]; then
  . "$_dotfiles_fzf_git"
fi
unset _dotfiles_fzf_git
