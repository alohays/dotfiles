# Bash interactive shell configuration.
[ -r "$HOME/.config/dotfiles/lib.sh" ] && . "$HOME/.config/dotfiles/lib.sh"
dotfiles_source_optional "$HOME/.config/dotfiles/env.sh"
case $- in
  *i*) ;;
  *) return 0 ;;
esac
dotfiles_source_optional "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/interactive.sh"
dotfiles_source_optional "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/bash.sh"
dotfiles_source_optional "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.bash.sh"
