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

  # Check each value individually to avoid overwriting partial config.
  existing_name=$(git config --file "$git_config_local" user.name 2>/dev/null || true)
  existing_email=$(git config --file "$git_config_local" user.email 2>/dev/null || true)

  if [ -n "$existing_name" ] && [ -n "$existing_email" ]; then
    return 0
  fi

  # Build a human-readable list of what's missing.
  if [ -z "$existing_name" ] && [ -z "$existing_email" ]; then
    missing_desc="user.name/email"
  elif [ -z "$existing_name" ]; then
    missing_desc="user.name"
  else
    missing_desc="user.email"
  fi

  if _dotfiles_is_truthy "${DOTFILES_DRY_RUN:-0}"; then
    dotfiles_info "[dry-run] Would prompt for git $missing_desc to write $git_config_local"
    return 0
  fi

  if _dotfiles_is_truthy "${DOTFILES_NONINTERACTIVE:-0}" || [ ! -t 0 ] || [ ! -t 1 ]; then
    dotfiles_warn "~/.config/git/config.local is missing git $missing_desc"
    if [ -z "$existing_name" ] && [ -z "$existing_email" ]; then
      dotfiles_warn "Run:  git config --file ~/.config/git/config.local user.name \"(YOUR NAME)\""
      dotfiles_warn "      git config --file ~/.config/git/config.local user.email \"(YOUR EMAIL)\""
    elif [ -z "$existing_name" ]; then
      dotfiles_warn "Run:  git config --file ~/.config/git/config.local user.name \"(YOUR NAME)\""
    else
      dotfiles_warn "Run:  git config --file ~/.config/git/config.local user.email \"(YOUR EMAIL)\""
    fi
    return 0
  fi

  # Bold yellow warning with manual instructions (matches wookayin/dotfiles UX).
  printf '\033[1;33m[!!!] Please configure git %s:\033[0m\n' "$missing_desc"
  [ -n "$existing_name" ]  || printf '    git config --file %s user.name "(YOUR NAME)"\n' "$git_config_local"
  [ -n "$existing_email" ] || printf '    git config --file %s user.email "(YOUR EMAIL)"\n' "$git_config_local"
  printf '\n'

  # Yellow-colored interactive prompts — only for missing values.
  git_user_name=$existing_name
  git_user_email=$existing_email

  if [ -z "$git_user_name" ]; then
    printf '\033[0;33m(git config user.name)  Please input your name  : \033[0m'
    read -r git_user_name || return 1
    if [ -z "$git_user_name" ]; then
      dotfiles_warn "git user.name is required"
      return 1
    fi
  fi

  if [ -z "$git_user_email" ]; then
    printf '\033[0;33m(git config user.email) Please input your email : \033[0m'
    read -r git_user_email || return 1
    if [ -z "$git_user_email" ]; then
      dotfiles_warn "git user.email is required"
      return 1
    fi
  fi

  mkdir -p "$(dirname "$git_config_local")"
  [ -n "$existing_name" ]  || git config --file "$git_config_local" user.name "$git_user_name"
  [ -n "$existing_email" ] || git config --file "$git_config_local" user.email "$git_user_email"

  # Green confirmation.
  printf '\n\033[0;32muser.name  : %s\033[0m\n' "$git_user_name"
  printf '\033[0;32muser.email : %s\033[0m\n' "$git_user_email"
}
