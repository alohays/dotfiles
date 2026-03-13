# Rich plugin upgrades for zsh (opt-in via rich profiles).
# Replaces standard zsh-syntax-highlighting with fast-syntax-highlighting when present.

[ -n "${ZSH_VERSION:-}" ] || return 0

case "${TERM:-}" in
    ''|dumb) return 0 ;;
esac

_dotfiles_rich_plugin_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

# Upgrade to fast-syntax-highlighting if available
if [ -r "$_dotfiles_rich_plugin_dir/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]; then
  # Disable standard zsh-syntax-highlighting if it was already loaded
  ZSH_HIGHLIGHT_HIGHLIGHTERS=()
  . "$_dotfiles_rich_plugin_dir/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi

# Add zsh-completions to fpath if present
if [ -d "$_dotfiles_rich_plugin_dir/zsh-completions/src" ]; then
  fpath=("$_dotfiles_rich_plugin_dir/zsh-completions/src" $fpath)
fi

unset _dotfiles_rich_plugin_dir

return 0
