# Lightweight zsh plugin loader (autosuggestions + syntax highlighting).
# Plugins are expected in $XDG_DATA_HOME/zsh/plugins/; silently skipped if absent.

[ -n "${ZSH_VERSION:-}" ] || return 0

dotfiles_term_capable || return 0

_dotfiles_zsh_plugin_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

_dotfiles_try_source() {
    [ -r "$1" ] || return 0
    . "$1"
}

_dotfiles_try_source "$_dotfiles_zsh_plugin_dir/zsh-autosuggestions/zsh-autosuggestions.zsh"
_dotfiles_try_source "$_dotfiles_zsh_plugin_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

unset _dotfiles_zsh_plugin_dir
unfunction _dotfiles_try_source 2>/dev/null || unset -f _dotfiles_try_source 2>/dev/null || true

return 0
