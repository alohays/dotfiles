# Keep zshenv minimal; it is sourced for every zsh invocation.
[ -r "$HOME/.config/dotfiles/lib.sh" ] && . "$HOME/.config/dotfiles/lib.sh"
dotfiles_source_optional "$HOME/.config/dotfiles/env.sh"
dotfiles_source_optional "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.zshenv.sh"
