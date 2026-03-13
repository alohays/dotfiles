# Prompt polish that keeps shell semantics standard.
# shellcheck shell=sh

case $- in
  *i*) ;;
  *) return 0 ;;
esac

: "${PROMPT_HOST_COLOR:=6}"
export PROMPT_HOST_COLOR

case "${TERM:-}" in
  ''|dumb) ;;
  *) : "${COLORTERM:=truecolor}"; export COLORTERM ;;
esac

if [ -n "${ZSH_VERSION:-}" ]; then
  # --- P10k path ---
  _p10k_theme="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/powerlevel10k/powerlevel10k.zsh-theme"
  if [ -r "$_p10k_theme" ]; then
    [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/p10k.zsh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/p10k.zsh"
    . "$_p10k_theme"
    unset _p10k_theme
    return 0
  fi
  unset _p10k_theme
  # --- Fallback: simple prompt ---
  autoload -Uz colors vcs_info add-zsh-hook
  colors
  zstyle ':vcs_info:git:*' formats ' %b'
  add-zsh-hook precmd vcs_info 2>/dev/null || true
  setopt PROMPT_SUBST
  PROMPT='%F{cyan}%n%f@%F{'"$PROMPT_HOST_COLOR"'}%m%f %F{blue}%~%f ${vcs_info_msg_0_:+%F{yellow}${vcs_info_msg_0_}%f }%F{magenta}❯%f '
elif [ -n "${BASH_VERSION:-}" ]; then
  __dotfiles_prompt_branch() {
    git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
  }
  PS1='\[\e[36m\]\u\[\e[0m\]@\[\e[38;5;'"$PROMPT_HOST_COLOR"'m\]\h\[\e[0m\] \[\e[34m\]\w\[\e[0m\]$(branch=$(__dotfiles_prompt_branch); [ -n "$branch" ] && printf " \[\\e[33m\\] %s\[\\e[0m\\]" "$branch") \[\e[35m\]❯\[\e[0m\] '
fi
