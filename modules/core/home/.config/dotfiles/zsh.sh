# zsh-specific interactive settings.

[ -n "${ZSH_VERSION:-}" ] || return 0

dotfiles_ensure_dir "$XDG_STATE_HOME/zsh"
dotfiles_ensure_dir "$XDG_CACHE_HOME/zsh"

HISTFILE=$XDG_STATE_HOME/zsh/history
: "${HISTSIZE:=5000}"
: "${SAVEHIST:=5000}"
export HISTFILE HISTSIZE SAVEHIST

setopt APPEND_HISTORY HIST_IGNORE_DUPS HIST_REDUCE_BLANKS INTERACTIVE_COMMENTS

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
