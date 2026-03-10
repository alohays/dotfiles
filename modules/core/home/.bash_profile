# Bash login shells should reuse the shared profile and bashrc.
[ -r "$HOME/.profile" ] && . "$HOME/.profile"
case $- in
  *i*) [ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc" ;;
esac
