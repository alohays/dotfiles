#!/bin/sh

if [ "${DOTFILES_TOOLS_SH_LOADED:-0}" = "1" ]; then
  return 0
fi
DOTFILES_TOOLS_SH_LOADED=1

RTK_INSTALL_URL=${RTK_INSTALL_URL:-https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh}

_dotfiles_validate_rtk_url() {
  case "$RTK_INSTALL_URL" in
    https://raw.githubusercontent.com/*|https://github.com/*) return 0 ;;
    file://*)
      if _dotfiles_is_truthy "${DOTFILES_ALLOW_FILE_URLS:-0}"; then
        return 0
      fi
      dotfiles_die "RTK_INSTALL_URL must use https (got: $RTK_INSTALL_URL)" ;;
    https://*) dotfiles_die "RTK_INSTALL_URL must point to a trusted GitHub domain (got: $RTK_INSTALL_URL)" ;;
    *) dotfiles_die "RTK_INSTALL_URL must use https (got: $RTK_INSTALL_URL)" ;;
  esac
}

ZSH_PLUGINS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
TMUX_PLUGINS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/plugins"

dotfiles_tools_usage() {
  cat <<USAGE
Usage: bin/dotfiles tools <subcommand> [options]

Manage external agent-oriented tools that help coding agents work well in the
default environment shipped by this repo.

Subcommands:
  list                       Show supported tools
  install <tool>             Install a tool
  plan <tool>                Print how a tool would be installed

Options for install/plan:
  --method <auto|brew|official|git>   Select install method (default: auto)
  --help, -h                          Show this help

Supported tools:
  rtk                        Install RTK using Homebrew when available or the
                             official install script otherwise
  zsh-plugins                Clone zsh-autosuggestions, zsh-syntax-highlighting,
                             and zsh-completions as opt-in interactive extras
  tmux-resurrect             Clone tmux-resurrect for opt-in session persistence
  powerlevel10k              Clone Powerlevel10k zsh prompt theme
  fast-syntax-highlighting   Clone fast-syntax-highlighting (F-Sy-H) for richer
                             syntax coloring
  fzf-git                    Clone fzf-git.sh for git-aware fzf bindings
  nvim-plugins              Bootstrap lazy.nvim, sync plugins, and install
                             treesitter parsers for the deployed Neovim config
USAGE
}

dotfiles_supported_tools() {
  printf '%s\n' rtk zsh-plugins tmux-resurrect powerlevel10k fast-syntax-highlighting fzf-git nvim-plugins
}

dotfiles_tool_exists() {
  case "${1:-}" in
    rtk|zsh-plugins|tmux-resurrect|powerlevel10k|fast-syntax-highlighting|fzf-git|nvim-plugins)
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
      if [ "${DOTFILES_TOOLS_DEFAULT_METHOD:-auto}" = "official" ]; then
        printf '%s\n' official
      elif [ "${DOTFILES_TOOLS_DEFAULT_METHOD:-auto}" = "brew" ]; then
        printf '%s\n' brew
      elif dotfiles_has_cmd brew; then
        printf '%s\n' brew
      else
        printf '%s\n' official
      fi
      ;;
    zsh-plugins|tmux-resurrect|powerlevel10k|fast-syntax-highlighting|fzf-git)
      printf '%s\n' git
      ;;
    nvim-plugins)
      printf '%s\n' nvim
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
    brew|official|git|nvim)
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
    zsh-plugins:git)
      printf '%s\n' "git clone zsh-users/zsh-autosuggestions -> $ZSH_PLUGINS_DIR/zsh-autosuggestions"
      printf '%s\n' "git clone zsh-users/zsh-syntax-highlighting -> $ZSH_PLUGINS_DIR/zsh-syntax-highlighting"
      printf '%s\n' "git clone zsh-users/zsh-completions -> $ZSH_PLUGINS_DIR/zsh-completions"
      ;;
    tmux-resurrect:git)
      printf '%s\n' "git clone tmux-plugins/tmux-resurrect -> $TMUX_PLUGINS_DIR/tmux-resurrect"
      ;;
    powerlevel10k:git)
      printf '%s\n' "git clone romkatv/powerlevel10k -> $ZSH_PLUGINS_DIR/powerlevel10k"
      ;;
    fast-syntax-highlighting:git)
      printf '%s\n' "git clone zdharma-continuum/fast-syntax-highlighting -> $ZSH_PLUGINS_DIR/fast-syntax-highlighting"
      ;;
    fzf-git:git)
      printf '%s\n' "git clone junegunn/fzf-git.sh -> $ZSH_PLUGINS_DIR/fzf-git.sh"
      ;;
    nvim-plugins:nvim)
      printf '%s\n' 'nvim --headless "+Lazy! sync" +qa'
      printf '%s\n' 'nvim --headless -c "Lazy load nvim-treesitter" -c "TSInstall! all" -c "sleep 60" -c qa'
      ;;
    *)
      dotfiles_die "no install plan for tool=$tool method=$method"
      ;;
  esac
}

_dotfiles_git_clone_or_pull() {
  repo_url=$1
  dest=$2
  if [ -d "$dest/.git" ]; then
    dotfiles_info "Updating $(basename "$dest") ..."
    dotfiles_run git -C "$dest" pull --ff-only
  else
    dotfiles_run git clone --depth 1 "$repo_url" "$dest"
  fi
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
      _dotfiles_validate_rtk_url
      curl -fsSL "$RTK_INSTALL_URL" | sh
      ;;
    zsh-plugins:git)
      dotfiles_has_cmd git || dotfiles_die "git is required for zsh-plugins"
      mkdir -p "$ZSH_PLUGINS_DIR"
      _dotfiles_git_clone_or_pull https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_PLUGINS_DIR/zsh-autosuggestions"
      _dotfiles_git_clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting"
      _dotfiles_git_clone_or_pull https://github.com/zsh-users/zsh-completions.git "$ZSH_PLUGINS_DIR/zsh-completions"
      ;;
    tmux-resurrect:git)
      dotfiles_has_cmd git || dotfiles_die "git is required for tmux-resurrect"
      mkdir -p "$TMUX_PLUGINS_DIR"
      _dotfiles_git_clone_or_pull https://github.com/tmux-plugins/tmux-resurrect.git "$TMUX_PLUGINS_DIR/tmux-resurrect"
      ;;
    powerlevel10k:git)
      dotfiles_has_cmd git || dotfiles_die "git is required for powerlevel10k"
      mkdir -p "$ZSH_PLUGINS_DIR"
      _dotfiles_git_clone_or_pull https://github.com/romkatv/powerlevel10k.git "$ZSH_PLUGINS_DIR/powerlevel10k"
      ;;
    fast-syntax-highlighting:git)
      dotfiles_has_cmd git || dotfiles_die "git is required for fast-syntax-highlighting"
      mkdir -p "$ZSH_PLUGINS_DIR"
      _dotfiles_git_clone_or_pull https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_PLUGINS_DIR/fast-syntax-highlighting"
      ;;
    fzf-git:git)
      dotfiles_has_cmd git || dotfiles_die "git is required for fzf-git"
      mkdir -p "$ZSH_PLUGINS_DIR"
      _dotfiles_git_clone_or_pull https://github.com/junegunn/fzf-git.sh.git "$ZSH_PLUGINS_DIR/fzf-git.sh"
      ;;
    nvim-plugins:nvim)
      dotfiles_has_cmd nvim || {
        dotfiles_warn "nvim not found; skipping plugin bootstrap"
        return 0
      }
      nvim_init="$HOME/.config/nvim/init.lua"
      if [ ! -e "$nvim_init" ]; then
        dotfiles_info "No nvim config found at $nvim_init; skipping plugin bootstrap"
        return 0
      fi
      dotfiles_info "Syncing lazy.nvim plugins ..."
      dotfiles_run nvim --headless "+Lazy! sync" +qa
      dotfiles_info "Installing treesitter parsers ..."
      dotfiles_run nvim --headless -c "Lazy load nvim-treesitter" -c "TSInstall! all" -c "sleep 60" -c qa
      ;;
    *)
      dotfiles_die "unsupported install request tool=$tool method=$method"
      ;;
  esac
}

dotfiles_install_default_tools() {
  default_tools=${DOTFILES_DEFAULT_AGENT_TOOLS:-rtk,nvim-plugins}
  [ -n "$default_tools" ] || return 0

  for tool in $(printf '%s' "$default_tools" | tr ',' ' '); do
    [ -n "$tool" ] || continue
    dotfiles_tool_exists "$tool" || dotfiles_die "unsupported default tool: $tool"
    method=$(dotfiles_detect_tool_method "$tool")
    dotfiles_info "Installing default agent tool: $tool ($method)"
    dotfiles_install_tool "$tool" "$method"
  done
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
