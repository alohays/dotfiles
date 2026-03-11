# zsh-specific interactive settings.

[ -n "${ZSH_VERSION:-}" ] || return 0

dotfiles_ensure_dir "$XDG_STATE_HOME/zsh"
dotfiles_ensure_dir "$XDG_CACHE_HOME/zsh"

HISTFILE=$XDG_STATE_HOME/zsh/history
: "${HISTSIZE:=50000}"
: "${SAVEHIST:=50000}"
export HISTFILE HISTSIZE SAVEHIST

setopt APPEND_HISTORY EXTENDED_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_VERIFY
setopt INTERACTIVE_COMMENTS

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

# Case-insensitive and partial-word completion.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ''
