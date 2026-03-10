#!/bin/sh

if [ "${DOTFILES_SH_LIB_LOADED:-0}" = "1" ]; then
  return 0
fi
DOTFILES_SH_LIB_LOADED=1

_dotfiles_is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

dotfiles_info() {
  printf '%s\n' "dotfiles: $*"
}

dotfiles_warn() {
  printf '%s\n' "dotfiles: warning: $*" >&2
}

dotfiles_die() {
  printf '%s\n' "dotfiles: error: $*" >&2
  exit 1
}

dotfiles_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

dotfiles_run() {
  if _dotfiles_is_truthy "${DOTFILES_DRY_RUN:-0}"; then
    printf '%s' '[dry-run]'
    for arg in "$@"; do
      printf ' %s' "$arg"
    done
    printf '\n'
    return 0
  fi
  "$@"
}

dotfiles_repo_root_from_bin() {
  script_path=$1
  script_dir=$(CDPATH= cd -- "$(dirname -- "$script_path")" && pwd -P)
  CDPATH= cd -- "$script_dir/.." && pwd -P
}

dotfiles_invoke_apply_engine() {
  repo_root=$1
  shift
  engine="$repo_root/scripts/dotfiles.py"
  [ -f "$engine" ] || return 2
  dotfiles_has_cmd python3 || dotfiles_die "python3 is required to run $engine"
  DOTFILES_REPO_ROOT="$repo_root" python3 "$engine" "$@"
}
