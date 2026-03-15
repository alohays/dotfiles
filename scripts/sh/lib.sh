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

dotfiles_setup_git_config_local() {
  dotfiles_has_cmd git || return 0

  git_config_local="$HOME/.config/git/config.local"

  # Check if BOTH user.name and user.email are already set (not just file existence).
  if git config --file "$git_config_local" user.name >/dev/null 2>&1 &&
     git config --file "$git_config_local" user.email >/dev/null 2>&1; then
    return 0
  fi

  if _dotfiles_is_truthy "${DOTFILES_DRY_RUN:-0}"; then
    dotfiles_info "[dry-run] Would prompt for git user.name/email to create $git_config_local"
    return 0
  fi

  if _dotfiles_is_truthy "${DOTFILES_NONINTERACTIVE:-0}" || [ ! -t 0 ] || [ ! -t 1 ]; then
    dotfiles_warn "~/.config/git/config.local is missing git user identity"
    dotfiles_warn "Run:  git config --file ~/.config/git/config.local user.name \"(YOUR NAME)\""
    dotfiles_warn "      git config --file ~/.config/git/config.local user.email \"(YOUR EMAIL)\""
    return 0
  fi

  # Bold yellow warning with manual instructions (matches wookayin/dotfiles UX).
  printf '\033[1;33m[!!!] Please configure git user name and email:\033[0m\n'
  printf '    git config --file %s user.name "(YOUR NAME)"\n' "$git_config_local"
  printf '    git config --file %s user.email "(YOUR EMAIL)"\n\n' "$git_config_local"

  # Yellow-colored interactive prompts.
  printf '\033[0;33m(git config user.name)  Please input your name  : \033[0m'
  read git_user_name || return 1
  printf '\033[0;33m(git config user.email) Please input your email : \033[0m'
  read git_user_email || return 1

  if [ -z "$git_user_name" ] || [ -z "$git_user_email" ]; then
    dotfiles_warn "git user.name and user.email are required"
    return 1
  fi

  mkdir -p "$(dirname "$git_config_local")"
  git config --file "$git_config_local" user.name "$git_user_name"
  git config --file "$git_config_local" user.email "$git_user_email"

  # Green confirmation.
  printf '\n\033[0;32muser.name  : %s\033[0m\n' "$git_user_name"
  printf '\033[0;32muser.email : %s\033[0m\n' "$git_user_email"
}
