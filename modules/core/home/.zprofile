# zsh login shells should share the POSIX profile flow.
[ -r "$HOME/.profile" ] && . "$HOME/.profile"
dotfiles_source_optional "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.zprofile.sh"
