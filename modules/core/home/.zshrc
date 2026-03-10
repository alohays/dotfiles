# zsh interactive shell configuration.
[ -r "$HOME/.config/dotfiles/lib.sh" ] && . "$HOME/.config/dotfiles/lib.sh"
dotfiles_source_optional "$HOME/.config/dotfiles/env.sh"
[[ -o interactive ]] || return 0
dotfiles_source_optional "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/interactive.sh"
dotfiles_source_optional "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/zsh.sh"
dotfiles_source_optional "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.zsh.zsh"
