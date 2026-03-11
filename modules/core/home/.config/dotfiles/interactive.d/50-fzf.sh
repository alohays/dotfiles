# FZF shell integration (only if fzf is installed).
# shellcheck shell=sh

command -v fzf >/dev/null 2>&1 || return 0

case "${TERM:-}" in
    ''|dumb) return 0 ;;
esac

[ -t 0 ] || [ -t 1 ] || return 0

# Use fd for file/directory search if available; fall back to rg; fall back to find.
if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
elif command -v rg >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# Source fzf shell integrations (keybindings + completion).
# fzf 0.48+ provides a built-in setup command; older versions use sourced scripts.
if [ -n "${ZSH_VERSION:-}" ]; then
    if fzf --zsh >/dev/null 2>&1; then
        eval "$(fzf --zsh)"
    elif [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf.zsh" ]; then
        . "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf.zsh"
    elif [ -f "$HOME/.fzf.zsh" ]; then
        . "$HOME/.fzf.zsh"
    fi
elif [ -n "${BASH_VERSION:-}" ]; then
    if fzf --bash >/dev/null 2>&1; then
        _dotfiles_fzf_bash=$(fzf --bash 2>/dev/null || true)
        if [ -n "${_dotfiles_fzf_bash:-}" ]; then
            eval "$_dotfiles_fzf_bash" || true
        fi
        unset _dotfiles_fzf_bash
    elif [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf.bash" ]; then
        . "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf.bash"
    elif [ -f "$HOME/.fzf.bash" ]; then
        . "$HOME/.fzf.bash"
    fi
fi
