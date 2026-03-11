# FZF shell integration (only if fzf is installed).
# shellcheck shell=sh

command -v fzf >/dev/null 2>&1 || return 0

case "${TERM:-}" in
    ''|dumb) return 0 ;;
esac

[ -t 0 ] || [ -t 1 ] || return 0

# Use fd for file/directory search if available; fall back to rg; fall back to find.
if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
elif command -v rg >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# Intentionally do not auto-enable fzf shell integrations here.
# The stock fzf bindings/completion (Ctrl-T, Ctrl-R, Alt-C, completion hooks)
# move the base shell away from upstream behavior. Keep the command usable with
# sensible defaults, and let users opt into shell widgets from local overrides.
