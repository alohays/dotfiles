# shellcheck shell=bash

[ -n "${BASH_VERSION:-}" ] || return 0

dotfiles_ensure_dir "$XDG_STATE_HOME/bash"

HISTFILE=$XDG_STATE_HOME/bash/history
: "${HISTSIZE:=50000}"
: "${HISTFILESIZE:=100000}"
HISTCONTROL=ignoreboth:erasedups
export HISTFILE HISTSIZE HISTFILESIZE HISTCONTROL

shopt -s histappend checkwinsize cmdhist

if ! shopt -oq posix; then
    if [ -r /etc/bash_completion ]; then
        . /etc/bash_completion
    elif [ -r /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    fi
fi
