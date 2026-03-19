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

_dotfiles_detect_arch() {
  arch=$(uname -m 2>/dev/null || printf 'unknown')
  case "$arch" in
    x86_64|amd64) printf 'x86_64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    *) printf '%s' "$arch" ;;
  esac
}

_dotfiles_install_brew_formula() {
  dotfiles_has_cmd brew || dotfiles_die "brew is required (brew not found)"
  dotfiles_run brew install "$1"
}

_dotfiles_install_brew_cask() {
  dotfiles_has_cmd brew || dotfiles_die "brew is required (brew not found)"
  dotfiles_run brew install --cask "$1"
}

_dotfiles_install_github_binary() {
  # Usage: _dotfiles_install_github_binary <url> <binary_name> [strip_components]
  # Extracts tarball and locates binary by name. Uses direct path first,
  # falls back to find(1) for archives with nested bin/ directories
  # (e.g., slack-cli macOS tarballs use ./bin/slack layout).
  url=$1; binary_name=$2; strip=${3:-0}
  dotfiles_has_cmd curl || dotfiles_die "curl is required for binary download"
  dotfiles_has_cmd tar  || dotfiles_die "tar is required for binary download"
  install_dir="$HOME/.local/bin"
  mkdir -p "$install_dir"
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tool.XXXXXX")
  dotfiles_info "Downloading $binary_name ..."
  if ! curl -fsSL "$url" -o "$tmp_dir/archive.tar.gz"; then
    rm -rf "$tmp_dir"
    dotfiles_die "failed to download $binary_name"
  fi
  if ! tar xzf "$tmp_dir/archive.tar.gz" -C "$tmp_dir" --strip-components="$strip"; then
    rm -rf "$tmp_dir"
    dotfiles_die "failed to extract $binary_name"
  fi
  if [ -f "$tmp_dir/$binary_name" ]; then
    binary_path="$tmp_dir/$binary_name"
  else
    binary_path=$(find "$tmp_dir" -name "$binary_name" -type f | head -1)
  fi
  if [ -z "$binary_path" ] || [ ! -f "$binary_path" ]; then
    rm -rf "$tmp_dir"
    dotfiles_die "binary $binary_name not found in archive"
  fi
  chmod +x "$binary_path"
  mv "$binary_path" "$install_dir/$binary_name"
  rm -rf "$tmp_dir"
}

_dotfiles_install_npm_global() {
  dotfiles_has_cmd npm || dotfiles_die "npm is required to install $1 (install Node.js first)"
  dotfiles_run npm install -g "$1"
}

dotfiles_tools_usage() {
  cat <<USAGE
Usage: bin/dotfiles tools <subcommand> [options]

Manage external agent-oriented tools that help coding agents work well in the
default environment shipped by this repo.

Subcommands:
  list                       Show supported tools
  install <tool>             Install a tool
  install --all              Install all supported tools
  plan <tool>                Print how a tool would be installed
  plan --all                 Print plans for all supported tools

Options for install/plan:
  --all                              Install/plan all supported tools
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
  googleworkspace-cli        Install Google Workspace CLI (brew or binary;
                             conflicts with gws package)
  agent-browser              Install Vercel agent-browser (brew or npm)
  slack-cli                  Install Slack CLI (brew or binary)
USAGE
}

dotfiles_supported_tools() {
  printf '%s\n' rtk zsh-plugins tmux-resurrect powerlevel10k fast-syntax-highlighting fzf-git nvim-plugins googleworkspace-cli agent-browser slack-cli
}

dotfiles_tool_exists() {
  case "${1:-}" in
    rtk|zsh-plugins|tmux-resurrect|powerlevel10k|fast-syntax-highlighting|fzf-git|nvim-plugins|googleworkspace-cli|agent-browser|slack-cli)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

_dotfiles_tool_auth_hint() {
  case "${1:-}" in
    googleworkspace-cli) printf '%s\n' "gws auth login" ;;
    slack-cli)           printf '%s\n' "slack login" ;;
    rtk)                 printf '%s\n' "rtk auth login" ;;
    *)                   return 1 ;;
  esac
}

_dotfiles_show_auth_hint() {
  auth_cmd=$(_dotfiles_tool_auth_hint "$1") || return 0
  dotfiles_info "Authenticate: $auth_cmd"
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
    googleworkspace-cli|agent-browser|slack-cli)
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
      printf '%s\n' 'nvim --headless -c "Lazy load nvim-treesitter" "+TSInstallSync! all" +qa'
      ;;
    googleworkspace-cli:brew)
      printf '%s\n' 'brew install googleworkspace-cli'
      ;;
    googleworkspace-cli:official)
      printf '%s\n' 'download gws binary from GitHub Releases -> ~/.local/bin/gws'
      ;;
    agent-browser:brew)
      printf '%s\n' 'brew install agent-browser'
      ;;
    agent-browser:official)
      printf '%s\n' 'npm install -g agent-browser'
      ;;
    slack-cli:brew)
      printf '%s\n' 'brew install --cask slack-cli'
      ;;
    slack-cli:official)
      printf '%s\n' 'download slack binary from GitHub Releases -> ~/.local/bin/slack'
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
      _dotfiles_install_brew_formula rtk
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
      dotfiles_run nvim --headless -c "Lazy load nvim-treesitter" "+TSInstallSync! all" +qa
      ;;
    googleworkspace-cli:brew)
      _dotfiles_install_brew_formula googleworkspace-cli
      ;;
    googleworkspace-cli:official)
      arch=$(_dotfiles_detect_arch)
      case "$(uname -s):$arch" in
        Darwin:aarch64) _target="gws-aarch64-apple-darwin" ;;
        Darwin:x86_64)  _target="gws-x86_64-apple-darwin" ;;
        Linux:x86_64)   _target="gws-x86_64-unknown-linux-gnu" ;;
        Linux:aarch64)  _target="gws-aarch64-unknown-linux-gnu" ;;
        *) dotfiles_die "unsupported platform for googleworkspace-cli: $(uname -s)/$arch" ;;
      esac
      _dotfiles_install_github_binary \
        "https://github.com/googleworkspace/cli/releases/latest/download/${_target}.tar.gz" \
        "gws" 1
      ;;
    agent-browser:brew)
      _dotfiles_install_brew_formula agent-browser
      ;;
    agent-browser:official)
      _dotfiles_install_npm_global agent-browser
      ;;
    slack-cli:brew)
      _dotfiles_install_brew_cask slack-cli
      ;;
    slack-cli:official)
      arch=$(_dotfiles_detect_arch)
      case "$(uname -s):$arch" in
        Linux:x86_64)   _target="slack_cli_latest_linux_64-bit" ;;
        Darwin:x86_64)  _target="slack_cli_latest_macOS_64-bit" ;;
        Darwin:aarch64) _target="slack_cli_latest_macOS_arm64" ;;
        Linux:aarch64)  dotfiles_die "slack-cli does not provide a Linux arm64 binary" ;;
        *) dotfiles_die "unsupported platform for slack-cli: $(uname -s)/$arch" ;;
      esac
      _dotfiles_install_github_binary \
        "https://github.com/slackapi/slack-cli/releases/latest/download/${_target}.tar.gz" \
        "slack" 0
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

dotfiles_install_all_tools() {
  override_method=${1:-auto}
  _tools_ok=0
  _tools_fail=0
  _tools_total=0
  _tools_need_auth=""

  for _iat_tool in $(dotfiles_supported_tools); do
    _tools_total=$(( _tools_total + 1 ))
    if [ "$override_method" = auto ]; then
      _iat_method=$(dotfiles_detect_tool_method "$_iat_tool")
    else
      _iat_method=$override_method
    fi
    dotfiles_step "Installing $_iat_tool ($_iat_method)"
    if dotfiles_install_tool "$_iat_tool" "$_iat_method"; then
      dotfiles_ok "$_iat_tool"
      _tools_ok=$(( _tools_ok + 1 ))
      _dotfiles_show_auth_hint "$_iat_tool"
      # Build newline-separated list (literal newline inside ${:+} is intentional).
      _tools_auth_cmd=$(_dotfiles_tool_auth_hint "$_iat_tool") && \
        _tools_need_auth="${_tools_need_auth:+$_tools_need_auth
}  $_tools_auth_cmd"
    else
      dotfiles_fail "$_iat_tool"
      _tools_fail=$(( _tools_fail + 1 ))
    fi
  done

  if _dotfiles_is_truthy "${DOTFILES_DRY_RUN:-0}"; then
    dotfiles_header "Tools install dry-run complete"
  else
    dotfiles_header "Tools install complete"
  fi
  if [ -n "${CLR_GREEN:-}" ]; then
    printf '%b  ✓ %d installed%b · %b✗ %d failed%b (of %d)\n' \
      "$CLR_GREEN" "$_tools_ok" "$CLR_RESET" \
      "$CLR_RED" "$_tools_fail" "$CLR_RESET" \
      "$_tools_total"
  else
    printf '  ok %d installed · FAIL %d failed (of %d)\n' \
      "$_tools_ok" "$_tools_fail" "$_tools_total"
  fi

  if [ -n "$_tools_need_auth" ]; then
    printf '\n'
    dotfiles_info "The following tools need authentication:"
    printf '%s\n' "$_tools_need_auth"
  fi

  [ "$_tools_fail" -eq 0 ]
}

dotfiles_plan_all_tools() {
  override_method=${1:-auto}
  for _pat_tool in $(dotfiles_supported_tools); do
    if [ "$override_method" = auto ]; then
      _pat_method=$(dotfiles_detect_tool_method "$_pat_tool")
    else
      _pat_method=$override_method
    fi
    printf '%s (%s):\n' "$_pat_tool" "$_pat_method"
    dotfiles_tool_install_plan "$_pat_tool" "$_pat_method" | sed 's/^/  /'
  done
}

dotfiles_tools_main() {
  subcommand=${1:-list}
  if [ "$#" -gt 0 ]; then
    shift
  fi

  method=auto
  tool=
  all_tools=0
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
      --all)
        all_tools=1
        shift
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
      if [ "$all_tools" -eq 1 ] && [ -n "$tool" ]; then
        dotfiles_die "--all and a tool name are mutually exclusive"
      fi
      if [ "$all_tools" -eq 1 ]; then
        if [ "$subcommand" = plan ]; then
          dotfiles_plan_all_tools "$method"
        else
          dotfiles_install_all_tools "$method"
        fi
      else
        [ -n "$tool" ] || dotfiles_die "$subcommand requires a tool name (or use --all)"
        dotfiles_tool_exists "$tool" || dotfiles_die "unsupported tool: $tool"
        if [ "$method" = auto ]; then
          method=$(dotfiles_detect_tool_method "$tool")
        fi
        if [ "$subcommand" = plan ]; then
          dotfiles_tool_install_plan "$tool" "$method"
        else
          dotfiles_install_tool "$tool" "$method"
          _dotfiles_show_auth_hint "$tool"
        fi
      fi
      ;;
    *)
      dotfiles_die "unknown tools subcommand: $subcommand"
      ;;
  esac
}
