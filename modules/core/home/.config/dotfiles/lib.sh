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

dotfiles_source_optional_relaxed() {
    [ -n "${1:-}" ] || return 0
    [ -r "$1" ] || return 0
    # shellcheck disable=SC1090
    . "$1" || return 0
}

dotfiles_source_dir() {
    dir=${1:-}
    [ -n "$dir" ] || return 0
    [ -d "$dir" ] || return 0

    if [ -n "${ZSH_VERSION:-}" ]; then
        setopt localoptions nonomatch
    fi

    for file in "$dir"/*.sh "$dir"/*.zsh; do
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

dotfiles_prepend_first_path() {
    while [ "$#" -gt 0 ]; do
        dir=$1
        shift
        [ -n "$dir" ] || continue
        [ -d "$dir" ] || continue
        dotfiles_prepend_path "$dir"
        return 0
    done
    return 0
}

dotfiles_prepend_prefix_bins() {
    prefixes=${1:-}
    [ -n "$prefixes" ] || return 0

    reversed_prefixes=
    while [ -n "$prefixes" ]; do
        case $prefixes in
            *:*)
                prefix=${prefixes%%:*}
                prefixes=${prefixes#*:}
                ;;
            *)
                prefix=$prefixes
                prefixes=
                ;;
        esac
        [ -n "$prefix" ] || continue
        reversed_prefixes=$prefix${reversed_prefixes:+":$reversed_prefixes"}
    done

    while [ -n "$reversed_prefixes" ]; do
        case $reversed_prefixes in
            *:*)
                prefix=${reversed_prefixes%%:*}
                reversed_prefixes=${reversed_prefixes#*:}
                ;;
            *)
                prefix=$reversed_prefixes
                reversed_prefixes=
                ;;
        esac
        [ -n "$prefix" ] || continue
        dotfiles_prepend_path "$prefix/sbin"
        dotfiles_prepend_path "$prefix/bin"
    done
}

dotfiles_version_gt() {
    # Return 0 if $1 > $2 using dot-separated numeric comparison.
    # Strips leading 'v' prefix and pre-release suffix (e.g. v22.0.0-rc.1 -> 22.0.0).
    # Pre-release versions are considered less than their release counterpart.
    _a=${1#v}; _b=${2#v}
    _a_pre=; _b_pre=
    case $_a in *-*) _a_pre=${_a#*-}; _a=${_a%%-*} ;; esac
    case $_b in *-*) _b_pre=${_b#*-}; _b=${_b%%-*} ;; esac
    while [ -n "$_a" ] || [ -n "$_b" ]; do
        _pa=${_a%%.*}; _pb=${_b%%.*}
        : "${_pa:=0}" "${_pb:=0}"
        [ "$_pa" -gt "$_pb" ] 2>/dev/null && return 0
        [ "$_pa" -lt "$_pb" ] 2>/dev/null && return 1
        case $_a in *.*) _a=${_a#*.} ;; *) _a= ;; esac
        case $_b in *.*) _b=${_b#*.} ;; *) _b= ;; esac
    done
    # Numeric parts equal: pre-release < release.
    [ -n "$_a_pre" ] && [ -z "$_b_pre" ] && return 1
    [ -z "$_a_pre" ] && [ -n "$_b_pre" ] && return 0
    return 1
}

dotfiles_os_name() {
    if [ -n "${DOTFILES_OS_NAME:-}" ]; then
        printf '%s\n' "$DOTFILES_OS_NAME"
    else
        uname -s 2>/dev/null || printf '%s\n' unknown
    fi
}

dotfiles_ensure_dir() {
    dir=${1:-}
    [ -n "$dir" ] || return 0
    [ -d "$dir" ] || mkdir -p "$dir"
}
