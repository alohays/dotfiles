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

# --- Color support ---

_dotfiles_use_color() {
  # Respect NO_COLOR (https://no-color.org/)
  [ -z "${NO_COLOR:-}" ] || return 1
  # TERM=dumb has no color support
  [ "${TERM:-dumb}" != "dumb" ] || return 1
  # Only colorize when stdout is a terminal
  [ -t 1 ] || return 1
  return 0
}

# Set color variables — empty when color is disabled.
_dotfiles_init_colors() {
  if _dotfiles_use_color; then
    CLR_RED='\033[0;31m'
    CLR_GREEN='\033[0;32m'
    CLR_YELLOW='\033[0;33m'
    CLR_CYAN='\033[0;36m'
    CLR_BOLD='\033[1m'
    CLR_BOLD_YELLOW='\033[1;33m'
    CLR_RESET='\033[0m'
    # Accent color: ANSI 256 color 61 (#5f5faf) with 16-color fallback
    _tput_colors=$(tput colors 2>/dev/null) || _tput_colors=0
    if [ "${_tput_colors:-0}" -ge 256 ] 2>/dev/null; then
      CLR_ACCENT='\033[38;5;61m'
    else
      CLR_ACCENT='\033[0;34m'
    fi
  else
    CLR_RED='' CLR_GREEN='' CLR_YELLOW=''
    CLR_CYAN='' CLR_BOLD='' CLR_BOLD_YELLOW='' CLR_RESET=''
    CLR_ACCENT=''
  fi
}

_dotfiles_init_colors

# --- Colored output helpers ---

dotfiles_header() {
  if [ -n "$CLR_CYAN" ]; then
    printf '%b── %b%s%b ──%b\n' "$CLR_CYAN" "$CLR_BOLD" "$*" "$CLR_CYAN" "$CLR_RESET"
  else
    printf '%s\n' "-- $* --"
  fi
}

dotfiles_ok() {
  if [ -n "$CLR_GREEN" ]; then
    printf '%b  ✓%b %s\n' "$CLR_GREEN" "$CLR_RESET" "$*"
  else
    printf '  ok  %s\n' "$*"
  fi
}

dotfiles_fail() {
  if [ -n "$CLR_RED" ]; then
    printf '%b  ✗%b %s\n' "$CLR_RED" "$CLR_RESET" "$*" >&2
  else
    printf '  FAIL  %s\n' "$*" >&2
  fi
}

dotfiles_skip() {
  if [ -n "$CLR_YELLOW" ]; then
    printf '%b  ⚠%b %s\n' "$CLR_YELLOW" "$CLR_RESET" "$*"
  else
    printf '  WARN  %s\n' "$*"
  fi
}

dotfiles_step() {
  if [ -n "$CLR_CYAN" ]; then
    printf '%b  →%b %s\n' "$CLR_CYAN" "$CLR_RESET" "$*"
  else
    printf '  ..  %s\n' "$*"
  fi
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
  printf '%b[!!!] Please configure git %s:%b\n' "$CLR_BOLD_YELLOW" "$missing_desc" "$CLR_RESET"
  [ -n "$existing_name" ]  || printf '    git config --file %s user.name "(YOUR NAME)"\n' "$git_config_local"
  [ -n "$existing_email" ] || printf '    git config --file %s user.email "(YOUR EMAIL)"\n' "$git_config_local"
  printf '\n'

  # Yellow-colored interactive prompts — only for missing values.
  git_user_name=$existing_name
  git_user_email=$existing_email

  if [ -z "$git_user_name" ]; then
    printf '%b(git config user.name)  Please input your name  : %b' "$CLR_YELLOW" "$CLR_RESET"
    read -r git_user_name || return 1
    if [ -z "$git_user_name" ]; then
      dotfiles_warn "git user.name is required"
      return 1
    fi
  fi

  if [ -z "$git_user_email" ]; then
    printf '%b(git config user.email) Please input your email : %b' "$CLR_YELLOW" "$CLR_RESET"
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
  printf '\n%buser.name  : %s%b\n' "$CLR_GREEN" "$git_user_name" "$CLR_RESET"
  printf '%buser.email : %s%b\n' "$CLR_GREEN" "$git_user_email" "$CLR_RESET"
}
