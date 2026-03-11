# shellcheck shell=sh

if [ "${DOTFILES_INTERACTIVE_SH_LOADED:-0}" = "1" ]; then
    return 0
fi
DOTFILES_INTERACTIVE_SH_LOADED=1

case $- in
    *i*) ;;
    *) return 0 ;;
esac

dotfiles_ensure_dir "$XDG_STATE_HOME"
dotfiles_ensure_dir "$XDG_CACHE_HOME"
dotfiles_ensure_dir "$XDG_STATE_HOME/less"

: "${LESSHISTFILE:=$XDG_STATE_HOME/less/history}"
export LESSHISTFILE

dotfiles_source_dir "$XDG_CONFIG_HOME/dotfiles/interactive.d"
dotfiles_source_optional "$XDG_CONFIG_HOME/dotfiles/local.interactive.sh"
