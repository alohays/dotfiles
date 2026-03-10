#!/bin/sh
set -eu

log() {
  printf '%s\n' "dotfiles-bootstrap: $*"
}

warn() {
  printf '%s\n' "dotfiles-bootstrap: warning: $*" >&2
}

die() {
  printf '%s\n' "dotfiles-bootstrap: error: $*" >&2
  exit 1
}

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

run() {
  if is_truthy "${DOTFILES_DRY_RUN:-0}"; then
    printf '%s' '[dry-run]'
    for arg in "$@"; do
      printf ' %s' "$arg"
    done
    printf '\n'
    return 0
  fi
  "$@"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

now_utc() {
  date -u +%Y%m%dT%H%M%SZ
}

canonical_git_remote() {
  input=$1
  case "$input" in
    git@*:* )
      host=${input#git@}
      host=${host%%:*}
      path=${input#*:}
      ;;
    ssh://*|https://*|http://*|git://*)
      rest=${input#*://}
      rest=${rest#*@}
      host=${rest%%/*}
      path=${rest#*/}
      ;;
    *)
      printf '%s' "$input"
      return 0
      ;;
  esac
  path=${path%.git}
  printf '%s/%s' "$host" "$path"
}

canonical_source() {
  input=${1:-}
  case "$input" in
    file://*)
      input=${input#file://}
      ;;
  esac

  case "$input" in
    git@*:*|ssh://*|https://*|http://*|git://*)
      canonical_git_remote "$input"
      ;;
    '')
      printf '%s' "$input"
      ;;
    *)
      if [ -e "$input" ]; then
        (
          CDPATH= cd -- "$input" 2>/dev/null && pwd -P
        ) || printf '%s' "$input"
      else
        printf '%s' "$input"
      fi
      ;;
  esac
}

same_source() {
  [ "$(canonical_source "$1")" = "$(canonical_source "$2")" ]
}

git_checkout_clean() {
  path=$1
  [ -d "$path/.git" ] || return 1
  status=$(git -C "$path" status --porcelain 2>/dev/null || printf 'dirty')
  [ -z "$status" ]
}

confirm_replace() {
  target=$1
  backup_path=$2
  reason=$3

  if is_truthy "${DOTFILES_YES:-0}"; then
    return 0
  fi

  if is_truthy "${DOTFILES_NONINTERACTIVE:-0}" || [ ! -t 0 ] || [ ! -t 1 ]; then
    die "refusing to replace $target in non-interactive mode (${reason}). Re-run with --yes to approve backup + replacement."
  fi

  printf '%s' "Replace existing checkout at $target? (${reason}) Backup: $backup_path [y/N] " >&2
  read answer || die "failed to read confirmation"
  case "$answer" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      die "aborted by user"
      ;;
  esac
}

backup_existing_checkout() {
  target=$1
  backup_root=$2
  timestamp=$(now_utc)
  backup_path="$backup_root/checkout-$timestamp"

  confirm_replace "$target" "$backup_path" "$3"
  run mkdir -p "$backup_root"
  run mv "$target" "$backup_path"
  log "Backed up existing checkout to $backup_path"
}

clone_checkout() {
  source_repo=$1
  target=$2
  branch=$3

  run mkdir -p "$(dirname "$target")"
  if [ -n "$branch" ]; then
    run git clone --origin origin --branch "$branch" --single-branch "$source_repo" "$target"
  else
    run git clone --origin origin "$source_repo" "$target"
  fi
}

update_checkout() {
  target=$1
  branch=$2

  run git -C "$target" fetch --all --prune
  if [ -n "$branch" ]; then
    run git -C "$target" checkout "$branch"
    run git -C "$target" pull --ff-only origin "$branch"
  else
    run git -C "$target" pull --ff-only
  fi
}

usage() {
  cat <<USAGE
Usage: bootstrap/install.sh [options] [command] [command args...]

Clone or update the dotfiles repo, optionally back up + replace an existing
checkout, then dispatch to bin/dotfiles inside the checkout.

Options:
  --repo <url-or-path>       Source repo (default: https://github.com/alohays/dotfiles.git)
  --target <path>            Checkout path (default: ~/.dotfiles)
  --branch <name>            Branch to clone/update (default: main)
  --backup-root <path>       Backup root for replaced checkouts
  --dry-run                  Print actions without changing anything
  --yes, -y                  Approve replacement without prompting
  --non-interactive          Fail instead of prompting
  --skip-apply               Skip the post-checkout apply step
  --help, -h                 Show this help

Commands:
  install (default)          Clone/update and run "bin/dotfiles install"
  apply                      Clone/update and run "bin/dotfiles apply"
  update                     Clone/update and run "bin/dotfiles update"
  packages                   Clone/update and run "bin/dotfiles packages"
  checkout-only              Clone/update only; do not run bin/dotfiles
USAGE
}

DOTFILES_DRY_RUN=${DOTFILES_DRY_RUN:-0}
DOTFILES_YES=${DOTFILES_YES:-0}
DOTFILES_NONINTERACTIVE=${DOTFILES_NONINTERACTIVE:-0}
DOTFILES_SKIP_APPLY=${DOTFILES_SKIP_APPLY:-0}
DOTFILES_REPO_URL=${DOTFILES_REPO_URL:-https://github.com/alohays/dotfiles.git}
DOTFILES_TARGET=${DOTFILES_TARGET:-${HOME:?HOME must be set}/.dotfiles}
DOTFILES_BRANCH=${DOTFILES_BRANCH:-main}
DOTFILES_BACKUP_ROOT=${DOTFILES_BACKUP_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/alohays-dotfiles/backups}
command=install

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      [ "$#" -ge 2 ] || die "--repo requires a value"
      DOTFILES_REPO_URL=$2
      shift 2
      ;;
    --target)
      [ "$#" -ge 2 ] || die "--target requires a value"
      DOTFILES_TARGET=$2
      shift 2
      ;;
    --branch)
      [ "$#" -ge 2 ] || die "--branch requires a value"
      DOTFILES_BRANCH=$2
      shift 2
      ;;
    --backup-root)
      [ "$#" -ge 2 ] || die "--backup-root requires a value"
      DOTFILES_BACKUP_ROOT=$2
      shift 2
      ;;
    --dry-run)
      DOTFILES_DRY_RUN=1
      shift
      ;;
    --yes|-y)
      DOTFILES_YES=1
      shift
      ;;
    --non-interactive)
      DOTFILES_NONINTERACTIVE=1
      shift
      ;;
    --skip-apply)
      DOTFILES_SKIP_APPLY=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      command=$1
      shift
      break
      ;;
  esac
done

export DOTFILES_DRY_RUN DOTFILES_YES DOTFILES_NONINTERACTIVE DOTFILES_SKIP_APPLY
require_cmd git

needs_clone=1
if [ -e "$DOTFILES_TARGET" ]; then
  if [ -d "$DOTFILES_TARGET/.git" ]; then
    existing_remote=$(git -C "$DOTFILES_TARGET" remote get-url origin 2>/dev/null || true)
    if [ -n "$existing_remote" ] && same_source "$existing_remote" "$DOTFILES_REPO_URL" && git_checkout_clean "$DOTFILES_TARGET"; then
      needs_clone=0
      log "Updating existing checkout at $DOTFILES_TARGET"
      update_checkout "$DOTFILES_TARGET" "$DOTFILES_BRANCH"
    else
      reason="existing checkout differs from requested source"
      if [ -n "$existing_remote" ] && ! same_source "$existing_remote" "$DOTFILES_REPO_URL"; then
        reason="existing checkout points at $existing_remote"
      elif ! git_checkout_clean "$DOTFILES_TARGET"; then
        reason="existing checkout has local changes"
      fi
      backup_existing_checkout "$DOTFILES_TARGET" "$DOTFILES_BACKUP_ROOT" "$reason"
    fi
  else
    backup_existing_checkout "$DOTFILES_TARGET" "$DOTFILES_BACKUP_ROOT" "target path already exists"
  fi
fi

if [ "$needs_clone" -eq 1 ]; then
  log "Cloning $DOTFILES_REPO_URL into $DOTFILES_TARGET"
  clone_checkout "$DOTFILES_REPO_URL" "$DOTFILES_TARGET" "$DOTFILES_BRANCH"
fi

if [ "$command" = "checkout-only" ]; then
  log "Checkout-only run complete"
  exit 0
fi

repo_cmd="$DOTFILES_TARGET/bin/dotfiles"
if is_truthy "$DOTFILES_DRY_RUN"; then
  printf '%s' '[dry-run]'
  printf ' %s' "$repo_cmd" "$command"
  for arg in "$@"; do
    printf ' %s' "$arg"
  done
  printf '\n'
  exit 0
fi

[ -x "$repo_cmd" ] || die "expected executable command at $repo_cmd"
DOTFILES_CHECKOUT_ALREADY_UPDATED=0
if [ "$command" = "update" ]; then
  DOTFILES_CHECKOUT_ALREADY_UPDATED=1
fi
log "Dispatching to $repo_cmd $command"
DOTFILES_TARGET="$DOTFILES_TARGET" \
DOTFILES_REPO_ROOT="$DOTFILES_TARGET" \
DOTFILES_SOURCE="$DOTFILES_REPO_URL" \
DOTFILES_BRANCH="$DOTFILES_BRANCH" \
DOTFILES_CHECKOUT_ALREADY_UPDATED="$DOTFILES_CHECKOUT_ALREADY_UPDATED" \
exec "$repo_cmd" "$command" "$@"
