# P10k instant prompt — must be sourced before any console output.
[ -n "${ZSH_VERSION:-}" ] || return 0
dotfiles_term_capable || return 0
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
