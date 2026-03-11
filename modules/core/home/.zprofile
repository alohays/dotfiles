# Managed wrapper; canonical repo-owned zsh startup lives under $DOTFILES_HOME/zsh/zprofile.
_dotfiles_wrapper_path=${(%):-%x}
_dotfiles_wrapper_repo=$(cd "${${_dotfiles_wrapper_path}:A:h}/../../.." 2>/dev/null && pwd -P)
if [ -n "$_dotfiles_wrapper_repo" ] && [ -r "$_dotfiles_wrapper_repo/zsh/zprofile" ]; then
  DOTFILES_HOME=$_dotfiles_wrapper_repo
else
  : "${DOTFILES_HOME:=$HOME/.dotfiles}"
fi
[ -r "$DOTFILES_HOME/zsh/zprofile" ] && . "$DOTFILES_HOME/zsh/zprofile"
unset _dotfiles_wrapper_path _dotfiles_wrapper_repo
