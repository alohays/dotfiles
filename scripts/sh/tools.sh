#!/bin/sh

if [ "${DOTFILES_TOOLS_SH_LOADED:-0}" = "1" ]; then
  return 0
fi
DOTFILES_TOOLS_SH_LOADED=1

RTK_INSTALL_URL=${RTK_INSTALL_URL:-https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh}

dotfiles_tools_usage() {
  cat <<USAGE
Usage: bin/dotfiles tools <subcommand> [options]

Manage optional external agent-oriented tools without baking them into the
default shell environment.

Subcommands:
  list                       Show supported optional tools
  install <tool>             Install a tool
  plan <tool>                Print how a tool would be installed

Options for install/plan:
  --method <auto|brew|official>   Select install method (default: auto)
  --help, -h                      Show this help

Supported tools:
  rtk                        Install RTK using Homebrew when available or the
                             official install script otherwise
USAGE
}

dotfiles_supported_tools() {
  printf '%s\n' rtk
}

dotfiles_tool_exists() {
  case "${1:-}" in
    rtk)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

dotfiles_detect_tool_method() {
  tool=$1
  case "$tool" in
    rtk)
      if dotfiles_has_cmd brew; then
        printf '%s\n' brew
      else
        printf '%s\n' official
      fi
      ;;
    *)
      dotfiles_die "unsupported tool: $tool"
      ;;
  esac
}

dotfiles_normalize_tool_method() {
  case "${1:-}" in
    auto|'')
      printf '%s\n' auto
      ;;
    brew|official)
      printf '%s\n' "$1"
      ;;
    *)
      return 1
      ;;
  esac
}

dotfiles_tool_install_plan() {
  tool=$1
  method=$2
  case "$tool:$method" in
    rtk:brew)
      printf '%s\n' 'brew install rtk'
      ;;
    rtk:official)
      printf '%s\n' "curl -fsSL $RTK_INSTALL_URL | sh"
      ;;
    *)
      dotfiles_die "no install plan for tool=$tool method=$method"
      ;;
  esac
}

dotfiles_install_tool() {
  tool=$1
  method=$2
  plan=$(dotfiles_tool_install_plan "$tool" "$method")

  if _dotfiles_is_truthy "${DOTFILES_DRY_RUN:-0}"; then
    printf '[dry-run] %s\n' "$plan"
    return 0
  fi

  case "$tool:$method" in
    rtk:brew)
      dotfiles_has_cmd brew || dotfiles_die "brew is required for method=brew"
      dotfiles_run brew install rtk
      ;;
    rtk:official)
      dotfiles_has_cmd curl || dotfiles_die "curl is required for method=official"
      curl -fsSL "$RTK_INSTALL_URL" | sh
      ;;
    *)
      dotfiles_die "unsupported install request tool=$tool method=$method"
      ;;
  esac
}

dotfiles_tools_main() {
  subcommand=${1:-list}
  if [ "$#" -gt 0 ]; then
    shift
  fi

  method=auto
  tool=
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --method)
        [ "$#" -ge 2 ] || dotfiles_die "--method requires a value"
        method=$(dotfiles_normalize_tool_method "$2") || dotfiles_die "unsupported tool install method: $2"
        shift 2
        ;;
      --help|-h)
        dotfiles_tools_usage
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        dotfiles_die "unknown tools option: $1"
        ;;
      *)
        tool=${tool:-$1}
        shift
        ;;
    esac
  done

  case "$subcommand" in
    list)
      dotfiles_supported_tools
      ;;
    install|plan)
      [ -n "$tool" ] || dotfiles_die "$subcommand requires a tool name"
      dotfiles_tool_exists "$tool" || dotfiles_die "unsupported tool: $tool"
      if [ "$method" = auto ]; then
        method=$(dotfiles_detect_tool_method "$tool")
      fi
      if [ "$subcommand" = plan ]; then
        dotfiles_tool_install_plan "$tool" "$method"
      else
        dotfiles_install_tool "$tool" "$method"
      fi
      ;;
    *)
      dotfiles_die "unknown tools subcommand: $subcommand"
      ;;
  esac
}
