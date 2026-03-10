# Shared login-shell entrypoint.
[ -r "$HOME/.config/dotfiles/lib.sh" ] && . "$HOME/.config/dotfiles/lib.sh"
dotfiles_source_optional "$HOME/.config/dotfiles/env.sh"
dotfiles_source_dir "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile.d"
dotfiles_source_optional "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.profile.sh"
