# shellcheck shell=sh

if [ "${DOTFILES_LIB_SH_LOADED:-0}" = "1" ]; then
    return 0
fi
DOTFILES_LIB_SH_LOADED=1

dotfiles_source_optional() {
    [ -n "${1:-}" ] || return 0
    [ -r "$1" ] || return 0
    # shellcheck disable=SC1090
    . "$1"
}

dotfiles_source_dir() {
    dir=${1:-}
    [ -n "$dir" ] || return 0
    [ -d "$dir" ] || return 0

    for file in "$dir"/*.sh; do
        [ -r "$file" ] || continue
        # shellcheck disable=SC1090
        . "$file"
    done
}

dotfiles_prepend_path() {
    dir=${1:-}
    [ -n "$dir" ] || return 0
    [ -d "$dir" ] || return 0

    case ":${PATH:-}:" in
        *":$dir:"*) ;;
        *) PATH=$dir${PATH:+":$PATH"} ;;
    esac
}

dotfiles_ensure_dir() {
    dir=${1:-}
    [ -n "$dir" ] || return 0
    [ -d "$dir" ] || mkdir -p "$dir"
}
