#!/bin/sh

if [ "${DOTFILES_PACKAGES_SH_LOADED:-0}" = "1" ]; then
  return 0
fi
DOTFILES_PACKAGES_SH_LOADED=1

_dotfiles_package_manifest() {
  cat <<'MANIFEST'
default|brew|git
default|brew|neovim
default|brew|zsh
default|brew|tmux
agents|brew|ripgrep
agents|brew|fd
agents|brew|jq
agents|brew|fzf
agents|brew|git-delta
default|apt|git
default|apt|neovim
default|apt|zsh
default|apt|tmux
agents|apt|ripgrep
agents|apt|fd-find
agents|apt|jq
agents|apt|fzf
agents|apt|git-delta
visual|brew|eza
visual|brew|bat
visual|brew|tree
visual|apt|eza
visual|apt|bat
visual|apt|tree
MANIFEST
}

dotfiles_packages_usage() {
  cat <<USAGE
Usage: bin/dotfiles packages [options]

Install package sets using supported native package managers.

Options:
  --set <name[,name...]>     Package set(s): default, agents, visual (default: default)
  --manager <brew|apt>       Override package manager detection
  --list                     Show resolved package sets instead of installing
  --print-plan               Print the install plan and exit
  --all                      Equivalent to --set default,agents
  --help, -h                 Show this help
USAGE
}

dotfiles_supported_package_managers() {
  printf '%s\n' brew apt
}

dotfiles_normalize_package_manager() {
  case "${1:-}" in
    brew|homebrew)
      printf '%s' brew
      ;;
    apt|apt-get)
      printf '%s' apt
      ;;
    *)
      return 1
      ;;
  esac
}

dotfiles_detect_package_manager() {
  os_name=$(uname -s 2>/dev/null || printf unknown)
  if [ "$os_name" = Darwin ] && dotfiles_has_cmd brew; then
    printf '%s' brew
    return 0
  fi
  if dotfiles_has_cmd apt-get; then
    printf '%s' apt
    return 0
  fi
  if dotfiles_has_cmd brew; then
    printf '%s' brew
    return 0
  fi
  return 1
}

dotfiles_package_set_exists() {
  case "$1" in
    default|agents|visual)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

dotfiles_iter_package_sets() {
  set_csv=$1
  [ -n "$set_csv" ] || set_csv=default
  printf '%s' "$set_csv" | tr ',' ' '
}

dotfiles_packages_for_set() {
  manager=$1
  set_name=$2
  _dotfiles_package_manifest | awk -F'|' -v want_set="$set_name" -v want_manager="$manager" '
    $1 == want_set && $2 == want_manager { print $3 }
  '
}

dotfiles_join_lines() {
  awk 'NF { if (out) out = out " " $0; else out = $0 } END { print out }'
}

dotfiles_resolve_package_list() {
  manager=$1
  set_csv=$2

  for set_name in $(dotfiles_iter_package_sets "$set_csv"); do
    dotfiles_package_set_exists "$set_name" || dotfiles_die "unknown package set: $set_name"
  done

  for set_name in $(dotfiles_iter_package_sets "$set_csv"); do
    dotfiles_packages_for_set "$manager" "$set_name"
  done | awk 'NF && !seen[$0]++ { print $0 }'
}

dotfiles_print_package_sets() {
  manager_filter=${1:-}
  set_csv=${2:-}
  if [ -n "$manager_filter" ]; then
    managers=$manager_filter
  else
    managers=$(dotfiles_supported_package_managers)
  fi
  [ -n "$set_csv" ] || set_csv=default,agents

  for manager in $managers; do
    printf '%s\n' "$manager:"
    for set_name in $(dotfiles_iter_package_sets "$set_csv"); do
      dotfiles_package_set_exists "$set_name" || dotfiles_die "unknown package set: $set_name"
      pkgs=$(dotfiles_packages_for_set "$manager" "$set_name" | dotfiles_join_lines)
      printf '  %s: %s\n' "$set_name" "${pkgs:-<none>}"
    done
  done
}

dotfiles_print_package_plan() {
  manager=$1
  shift
  printf 'package-manager: %s\n' "$manager"
  printf '%s\n' 'packages:'
  for pkg in "$@"; do
    printf '  - %s\n' "$pkg"
  done
}

dotfiles_install_packages() {
  manager=$1
  shift
  [ "$#" -gt 0 ] || dotfiles_die "no packages resolved for manager $manager"

  case "$manager" in
    brew)
      dotfiles_has_cmd brew || dotfiles_die "brew is required for package installation"
      dotfiles_run brew install "$@"
      ;;
    apt)
      if [ "$(id -u)" -eq 0 ]; then
        dotfiles_run apt-get update
        dotfiles_run apt-get install -y "$@"
      elif dotfiles_has_cmd sudo; then
        dotfiles_run sudo apt-get update
        dotfiles_run sudo apt-get install -y "$@"
      else
        dotfiles_die "apt package installation requires root or sudo; use --print-plan on no-sudo hosts"
      fi
      ;;
    *)
      dotfiles_die "unsupported package manager: $manager"
      ;;
  esac
}

dotfiles_packages_main() {
  package_sets=
  manager=
  list_only=0
  print_plan=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --set)
        [ "$#" -ge 2 ] || dotfiles_die "--set requires a value"
        if [ -n "$package_sets" ]; then
          package_sets="$package_sets,$2"
        else
          package_sets=$2
        fi
        shift 2
        ;;
      --manager)
        [ "$#" -ge 2 ] || dotfiles_die "--manager requires a value"
        manager=$(dotfiles_normalize_package_manager "$2") || dotfiles_die "unsupported package manager: $2"
        shift 2
        ;;
      --list)
        list_only=1
        shift
        ;;
      --print-plan)
        print_plan=1
        shift
        ;;
      --all)
        package_sets=default,agents,visual
        shift
        ;;
      --help|-h)
        dotfiles_packages_usage
        return 0
        ;;
      --)
        shift
        break
        ;;
      *)
        dotfiles_die "unknown packages option: $1"
        ;;
    esac
  done

  if [ "$#" -gt 0 ]; then
    dotfiles_die "unexpected trailing arguments for packages command: $*"
  fi

  if [ "$list_only" -eq 1 ]; then
    dotfiles_print_package_sets "$manager" "$package_sets"
    return 0
  fi

  if [ -z "$manager" ]; then
    manager=$(dotfiles_detect_package_manager) || dotfiles_die "no supported native package manager detected (supported: brew, apt-get)"
  fi

  package_list=$(dotfiles_resolve_package_list "$manager" "$package_sets")
  [ -n "$package_list" ] || dotfiles_die "no packages resolved for manager $manager"
  # shellcheck disable=SC2086
  set -- $package_list

  if [ "$print_plan" -eq 1 ] || _dotfiles_is_truthy "${DOTFILES_DRY_RUN:-0}"; then
    dotfiles_print_package_plan "$manager" "$@"
    return 0
  fi

  dotfiles_install_packages "$manager" "$@"
}
