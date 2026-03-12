#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
CLEANUP_DIRS=

log() {
  printf '%s\n' "install-qa: $*"
}

die() {
  printf '%s\n' "install-qa: error: $*" >&2
  exit 1
}

cleanup() {
  for dir in $CLEANUP_DIRS; do
    [ -n "$dir" ] || continue
    rm -rf "$dir"
  done
}
trap cleanup EXIT HUP INT TERM

track_cleanup_dir() {
  CLEANUP_DIRS="$CLEANUP_DIRS $1"
}

make_temp_dir() {
  dir=$(mktemp -d "${TMPDIR:-/tmp}/alohays-dotfiles-qa.XXXXXX")
  # Canonicalize to avoid /var vs /private/var mismatch on macOS.
  cd "$dir" && pwd -P
}

make_scenario_root() {
  root=$(make_temp_dir)
  track_cleanup_dir "$root"
  printf '%s\n' "$root"
}

make_source_repo() {
  root=$1
  snapshot="$root/source-repo"
  mkdir -p "$snapshot"
  for item in bin bootstrap docs manifests modules profiles scripts tests zsh README.md .gitignore; do
    if [ -e "$REPO_ROOT/$item" ]; then
      cp -R "$REPO_ROOT/$item" "$snapshot/$item"
    fi
  done
  git -C "$snapshot" init >/dev/null 2>&1
  git -C "$snapshot" checkout -B main >/dev/null 2>&1
  git -C "$snapshot" config user.name 'QA Test'
  git -C "$snapshot" config user.email 'qa@example.com'
  git -C "$snapshot" add -A
  git -C "$snapshot" commit -m 'qa snapshot' >/dev/null 2>&1
  printf '%s\n' "$snapshot"
}

make_fake_rtk_installer() {
  root=$1
  script_path="$root/fake-rtk-install.sh"
  cat > "$script_path" <<'EOF'
#!/bin/sh
set -eu
mkdir -p "${HOME:?HOME must be set}/.local/bin"
printf '%s\n' '#!/bin/sh' > "${HOME}/.local/bin/rtk"
printf '%s\n' 'printf "fake-rtk\n"' >> "${HOME}/.local/bin/rtk"
chmod +x "${HOME}/.local/bin/rtk"
printf '%s\n' 'installed' > "${HOME}/.local/bin/.rtk-installed"
EOF
  chmod +x "$script_path"
  printf '%s\n' "$script_path"
}

make_fake_command() {
  command_path=$1
  command_name=$2
  mkdir -p "$(dirname "$command_path")"
  cat > "$command_path" <<EOF
#!/bin/sh
printf '%s\n' '$command_name'
EOF
  chmod +x "$command_path"
}

setup_command_resolution_fixture() {
  root=$1
  home_dir=$2
  fake_brew_primary="$root/fake-homebrew-primary"
  fake_brew_secondary="$root/fake-homebrew-secondary"

  make_fake_command "$fake_brew_primary/bin/brew" brew-primary
  make_fake_command "$fake_brew_primary/bin/qa-brew-tool" qa-brew-tool-primary
  make_fake_command "$fake_brew_secondary/bin/brew" brew-secondary
  make_fake_command "$fake_brew_secondary/bin/qa-brew-tool" qa-brew-tool-secondary
  make_fake_command "$home_dir/.local/bin/qa-local-tool" qa-local-tool
  make_fake_command "$home_dir/.npm-global/bin/qa-npm-tool" qa-npm-tool
  make_fake_command "$home_dir/.volta/bin/node" node-via-volta
  make_fake_command "$home_dir/.volta/bin/npm" npm-via-volta
  make_fake_command "$home_dir/.pyenv/shims/python3" python3-via-pyenv
  make_fake_command "$home_dir/.pyenv/shims/pip3" pip3-via-pyenv
  make_fake_command "$home_dir/.miniforge3/condabin/conda" conda-via-miniforge
  make_fake_command "$home_dir/.miniforge3/bin/conda" conda-exe-via-miniforge
  mkdir -p "$home_dir/.config/dotfiles"
  cat > "$home_dir/.config/dotfiles/local.env.sh" <<'EOF'
if [ -n "${DOTFILES_QA_LOCAL_ENV_COUNT_FILE:-}" ]; then
  count=0
  if [ -r "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE" ]; then
    count=$(cat "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE")
  fi
  count=$((count + 1))
  mkdir -p "$(dirname "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE")"
  printf '%s\n' "$count" > "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE"
  export DOTFILES_QA_LOCAL_ENV_RUNS=$count
fi
EOF

  printf '%s\n' "$fake_brew_primary:$fake_brew_secondary"
}

assert_exists() {
  [ -e "$1" ] || die "expected path to exist: $1"
}

assert_not_exists() {
  [ ! -e "$1" ] || die "expected path to be absent: $1"
}

assert_symlink_target() {
  link_path=$1
  expected_target=$2
  [ -L "$link_path" ] || die "expected symlink: $link_path"
  actual=$(python3 - "$link_path" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve(strict=False))
PY
)
  expected=$(python3 - "$expected_target" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve(strict=False))
PY
)
  [ "$actual" = "$expected" ] || die "symlink mismatch for $link_path: $actual != $expected"
}

assert_inventory_profile() {
  inventory_path=$1
  expected_profile=$2
  python3 - "$inventory_path" "$expected_profile" <<'PY'
from pathlib import Path
import json
import sys
path = Path(sys.argv[1])
expected = sys.argv[2]
payload = json.loads(path.read_text(encoding='utf-8'))
if payload.get('profile') != expected:
    raise SystemExit(f"inventory profile mismatch: {payload.get('profile')} != {expected}")
PY
}

assert_inventory_has_target() {
  inventory_path=$1
  expected_target=$2
  python3 - "$inventory_path" "$expected_target" <<'PY'
from pathlib import Path
import json
import sys
path = Path(sys.argv[1])
expected = sys.argv[2]
payload = json.loads(path.read_text(encoding='utf-8'))
targets = {entry.get('target') for entry in payload.get('entries', [])}
if expected not in targets:
    raise SystemExit(f"inventory missing target: {expected}")
PY
}

assert_git_clean() {
  path=$1
  status=$(git -C "$path" status --porcelain)
  [ -z "$status" ] || die "expected clean git checkout at $path, found: $status"
}

assert_git_stash_contains() {
  path=$1
  expected_pattern=$2
  stash_list=$(git -C "$path" stash list)
  printf '%s\n' "$stash_list" | grep -Eq "$expected_pattern" || {
    die "expected git stash at $path to match $expected_pattern, got: $stash_list"
  }
}

assert_git_branch_contains() {
  path=$1
  expected_pattern=$2
  branch_list=$(git -C "$path" branch --list)
  printf '%s\n' "$branch_list" | grep -Eq "$expected_pattern" || {
    die "expected git branch at $path to match $expected_pattern, got: $branch_list"
  }
}

resolve_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    printf '%s\n' apt
  elif command -v brew >/dev/null 2>&1; then
    printf '%s\n' brew
  else
    die 'expected apt-get or brew to be available for package dry-run test'
  fi
}

assert_package_plan() {
  home_dir=$1
  manager=$(resolve_package_manager)
  plan_output=$(HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" packages --all --manager "$manager" --print-plan)
  printf '%s\n' "$plan_output" | grep -q "^package-manager: $manager$" || die "package plan did not report manager $manager"
  for pkg in git neovim zsh tmux ripgrep jq fzf; do
    printf '%s\n' "$plan_output" | grep -q "  - $pkg$" || die "package plan missing package $pkg"
  done
  case "$manager" in
    apt)
      printf '%s\n' "$plan_output" | grep -q '  - fd-find$' || die 'package plan missing apt package fd-find'
      ;;
    brew)
      printf '%s\n' "$plan_output" | grep -q '  - fd$' || die 'package plan missing brew package fd'
      ;;
  esac
}

assert_tool_plan() {
  home_dir=$1
  plan_output=$(HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" tools plan rtk)
  printf '%s\n' "$plan_output" | grep -Eq '^(brew install rtk|curl -fsSL .+/install\.sh \| sh)$' || {
    die "unexpected RTK tool plan output: $plan_output"
  }
}

assert_default_tool_installed() {
  home_dir=$1
  assert_exists "$home_dir/.local/bin/rtk"
  assert_exists "$home_dir/.local/bin/.rtk-installed"
}

assert_shell_command_resolution() {
  shell_name=$1
  home_dir=$2
  fake_brew_prefixes=$3
  expected_brew_prefix=${fake_brew_prefixes%%:*}
  expected_brew="$expected_brew_prefix/bin/brew"
  expected_brew_tool="$expected_brew_prefix/bin/qa-brew-tool"
  local_env_count_file="$home_dir/.local/state/qa-local-env-$shell_name.count"
  rm -f "$local_env_count_file"

  assert_exists "$home_dir/.dotfiles/zsh/zshenv"
  assert_exists "$home_dir/.dotfiles/zsh/zprofile"
  assert_exists "$home_dir/.dotfiles/zsh/zshrc"
  grep -Eq '(\$DOTFILES_HOME|\.dotfiles)/zsh/zshenv' "$home_dir/.dotfiles/modules/core/home/.zshenv" || die 'managed .zshenv wrapper should delegate to top-level zsh/zshenv'
  grep -Eq '(\$DOTFILES_HOME|\.dotfiles)/zsh/zprofile' "$home_dir/.dotfiles/modules/core/home/.zprofile" || die 'managed .zprofile wrapper should delegate to top-level zsh/zprofile'
  grep -Eq '(\$DOTFILES_HOME|\.dotfiles)/zsh/zshrc' "$home_dir/.dotfiles/modules/core/home/.zshrc" || die 'managed .zshrc wrapper should delegate to top-level zsh/zshrc'
  case "$shell_name" in
    bash)
      env -i HOME="$home_dir" PATH=/usr/bin:/bin TERM=dumb DOTFILES_OS_NAME=Darwin DOTFILES_HOMEBREW_PREFIXES="$fake_brew_prefixes" EXPECT_BREW="$expected_brew" EXPECT_BREW_TOOL="$expected_brew_tool" DOTFILES_QA_LOCAL_ENV_COUNT_FILE="$local_env_count_file" bash --noprofile --norc -i <<'EOF_BASH_PATH'
set -eu
. "$HOME/.bash_profile"
assert_command() {
  name=$1
  expected=$2
  actual=$(command -v "$name" || true)
  [ "$actual" = "$expected" ] || {
    echo "unexpected resolution for $name: $actual != $expected" >&2
    exit 1
  }
}
assert_local_env_once() {
  actual=$(cat "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE" 2>/dev/null || printf '%s' 0)
  [ "${DOTFILES_QA_LOCAL_ENV_RUNS:-0}" = "1" ] || {
    echo "local.env.sh should have run once in bash, got ${DOTFILES_QA_LOCAL_ENV_RUNS:-0}" >&2
    exit 1
  }
  [ "$actual" = "1" ] || {
    echo "local.env.sh counter should be 1 in bash, got $actual" >&2
    exit 1
  }
}
assert_command dotfiles "$HOME/.dotfiles/bin/dotfiles"
assert_command rtk "$HOME/.local/bin/rtk"
assert_command qa-local-tool "$HOME/.local/bin/qa-local-tool"
assert_command qa-npm-tool "$HOME/.npm-global/bin/qa-npm-tool"
assert_command node "$HOME/.volta/bin/node"
assert_command npm "$HOME/.volta/bin/npm"
assert_command python3 "$HOME/.pyenv/shims/python3"
assert_command conda "$HOME/.miniforge3/condabin/conda"
assert_command brew "$EXPECT_BREW"
assert_command qa-brew-tool "$EXPECT_BREW_TOOL"
[ "${CONDA_EXE:-}" = "$HOME/.miniforge3/bin/conda" ] || {
  echo "unexpected CONDA_EXE: ${CONDA_EXE:-}" >&2
  exit 1
}
assert_local_env_once
EXPECT_BREW="$EXPECT_BREW" EXPECT_BREW_TOOL="$EXPECT_BREW_TOOL" DOTFILES_QA_LOCAL_ENV_COUNT_FILE="$DOTFILES_QA_LOCAL_ENV_COUNT_FILE" bash --noprofile --rcfile "$HOME/.bashrc" -ic '
set -eu
assert_command() {
  name=$1
  expected=$2
  actual=$(command -v "$name" || true)
  [ "$actual" = "$expected" ] || {
    echo "unexpected nested resolution for $name: $actual != $expected" >&2
    exit 1
  }
}
assert_local_env_once() {
  actual=$(cat "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE" 2>/dev/null || printf "%s" 0)
  [ "${DOTFILES_QA_LOCAL_ENV_RUNS:-0}" = "1" ] || {
    echo "local.env.sh should stay at one run in nested bash, got ${DOTFILES_QA_LOCAL_ENV_RUNS:-0}" >&2
    exit 1
  }
  [ "$actual" = "1" ] || {
    echo "local.env.sh counter should stay at 1 in nested bash, got $actual" >&2
    exit 1
  }
}
assert_command dotfiles "$HOME/.dotfiles/bin/dotfiles"
assert_command rtk "$HOME/.local/bin/rtk"
assert_command qa-local-tool "$HOME/.local/bin/qa-local-tool"
assert_command qa-npm-tool "$HOME/.npm-global/bin/qa-npm-tool"
assert_command node "$HOME/.volta/bin/node"
assert_command npm "$HOME/.volta/bin/npm"
assert_command python3 "$HOME/.pyenv/shims/python3"
assert_command conda "$HOME/.miniforge3/condabin/conda"
assert_command brew "$EXPECT_BREW"
assert_command qa-brew-tool "$EXPECT_BREW_TOOL"
[ "${CONDA_EXE:-}" = "$HOME/.miniforge3/bin/conda" ] || {
  echo "unexpected nested CONDA_EXE: ${CONDA_EXE:-}" >&2
  exit 1
}
assert_local_env_once
'
      actual=$(cat "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE" 2>/dev/null || printf '%s' 0)
      [ "$actual" = "1" ] || die "local.env.sh counter should remain 1 after nested bash, got $actual"
EOF_BASH_PATH
      ;;
    zsh)
      env -i HOME="$home_dir" PATH=/usr/bin:/bin TERM=dumb DOTFILES_OS_NAME=Darwin DOTFILES_HOMEBREW_PREFIXES="$fake_brew_prefixes" EXPECT_BREW="$expected_brew" EXPECT_BREW_TOOL="$expected_brew_tool" DOTFILES_QA_LOCAL_ENV_COUNT_FILE="$local_env_count_file" ZDOTDIR="$home_dir" zsh -f -i <<'EOF_ZSH_PATH'
set -eu
PROMPT=
PS1=
. "$HOME/.zshenv"
PATH=/usr/bin:/bin
export PATH
. "$HOME/.zprofile"
. "$HOME/.zshrc"
assert_command() {
  name=$1
  expected=$2
  actual=$(command -v "$name" || true)
  [ "$actual" = "$expected" ] || {
    print -u2 "unexpected resolution for $name: $actual != $expected"
    exit 1
  }
}
assert_local_env_once() {
  actual=$(cat "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE" 2>/dev/null || printf '%s' 0)
  [[ "${DOTFILES_QA_LOCAL_ENV_RUNS:-0}" == "1" ]] || {
    print -u2 "local.env.sh should have run once in zsh, got ${DOTFILES_QA_LOCAL_ENV_RUNS:-0}"
    exit 1
  }
  [[ "$actual" == "1" ]] || {
    print -u2 "local.env.sh counter should be 1 in zsh, got $actual"
    exit 1
  }
}
assert_command dotfiles "$HOME/.dotfiles/bin/dotfiles"
assert_command rtk "$HOME/.local/bin/rtk"
assert_command qa-local-tool "$HOME/.local/bin/qa-local-tool"
assert_command node "$HOME/.volta/bin/node"
assert_command npm "$HOME/.volta/bin/npm"
assert_command python3 "$HOME/.pyenv/shims/python3"
assert_command conda "$HOME/.miniforge3/condabin/conda"
assert_command brew "$EXPECT_BREW"
assert_command qa-brew-tool "$EXPECT_BREW_TOOL"
assert_command qa-npm-tool "$HOME/.npm-global/bin/qa-npm-tool"
[[ "${CONDA_EXE:-}" == "$HOME/.miniforge3/bin/conda" ]] || {
  print -u2 "unexpected CONDA_EXE: ${CONDA_EXE:-}"
  exit 1
}
assert_local_env_once
zsh -f -i <<'EOF_NESTED_ZSH'
set -eu
PROMPT=
PS1=
. "$HOME/.zshenv"
. "$HOME/.zshrc"
assert_command() {
  name=$1
  expected=$2
  actual=$(command -v "$name" || true)
  [ "$actual" = "$expected" ] || {
    print -u2 "unexpected nested resolution for $name: $actual != $expected"
    exit 1
  }
}
assert_local_env_once() {
  actual=$(cat "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE" 2>/dev/null || printf '%s' 0)
  [[ "${DOTFILES_QA_LOCAL_ENV_RUNS:-0}" == "1" ]] || {
    print -u2 "local.env.sh should stay at one run in nested zsh, got ${DOTFILES_QA_LOCAL_ENV_RUNS:-0}"
    exit 1
  }
  [[ "$actual" == "1" ]] || {
    print -u2 "local.env.sh counter should stay at 1 in nested zsh, got $actual"
    exit 1
  }
}
assert_command dotfiles "$HOME/.dotfiles/bin/dotfiles"
assert_command rtk "$HOME/.local/bin/rtk"
assert_command qa-local-tool "$HOME/.local/bin/qa-local-tool"
assert_command node "$HOME/.volta/bin/node"
assert_command npm "$HOME/.volta/bin/npm"
assert_command python3 "$HOME/.pyenv/shims/python3"
assert_command conda "$HOME/.miniforge3/condabin/conda"
assert_command brew "$EXPECT_BREW"
assert_command qa-brew-tool "$EXPECT_BREW_TOOL"
assert_command qa-npm-tool "$HOME/.npm-global/bin/qa-npm-tool"
[[ "${CONDA_EXE:-}" == "$HOME/.miniforge3/bin/conda" ]] || {
  print -u2 "unexpected nested CONDA_EXE: ${CONDA_EXE:-}"
  exit 1
}
assert_local_env_once
EOF_NESTED_ZSH
      actual=$(cat "$DOTFILES_QA_LOCAL_ENV_COUNT_FILE" 2>/dev/null || printf '%s' 0)
      [ "$actual" = "1" ] || die "local.env.sh counter should remain 1 after nested zsh, got $actual"
EOF_ZSH_PATH
      ;;
    *)
      die "unknown shell for command resolution check: $shell_name"
      ;;
  esac
}

assert_legacy_zsh_init_preserved() {
  home_dir=$1
  env -i HOME="$home_dir" PATH=/usr/bin:/bin TERM=dumb ZDOTDIR="$home_dir" zsh -f -i <<'EOF_LEGACY_ZSH'
set -eu
PROMPT=
PS1=
. "$HOME/.zshenv"
PATH=/usr/bin:/bin
export PATH
. "$HOME/.zprofile"
. "$HOME/.zshrc"
legacy_file="$HOME/.config/dotfiles/local.zprofile.sh"
[[ -f "$legacy_file" ]] || {
  print -u2 "missing auto-migrated local.zprofile.sh"
  exit 1
}
legacy_zshenv="$HOME/.config/dotfiles/local.zshenv.sh"
[[ -f "$legacy_zshenv" ]] || {
  print -u2 "missing auto-migrated local.zshenv.sh"
  exit 1
}
legacy_zshrc="$HOME/.config/dotfiles/local.zsh.zsh"
[[ -f "$legacy_zshrc" ]] || {
  print -u2 "missing auto-migrated local.zsh.zsh"
  exit 1
}
grep -q 'export PATH="$HOME/.volta/bin:$PATH"' "$legacy_file" || {
  print -u2 "legacy PATH export was not preserved in local.zprofile.sh"
  exit 1
}
grep -q 'export DOTFILES_QA_LEGACY_ZSHENV=1' "$legacy_zshenv" || {
  print -u2 "legacy zshenv content was not preserved"
  exit 1
}
grep -q 'export DOTFILES_QA_LEGACY_ZSHRC=1' "$legacy_zshrc" || {
  print -u2 "legacy zshrc content was not preserved"
  exit 1
}
[[ "${DOTFILES_QA_LEGACY_ZSHENV:-0}" == "1" ]] || {
  print -u2 "legacy zshenv overlay did not load"
  exit 1
}
[[ "${DOTFILES_QA_LEGACY_ZSHRC:-0}" == "1" ]] || {
  print -u2 "legacy zshrc overlay did not load"
  exit 1
}
actual=$(command -v qa-legacy-node-tool || true)
[[ "$actual" == "$HOME/.volta/bin/qa-legacy-node-tool" ]] || {
  print -u2 "legacy qa-legacy-node-tool did not resolve after install: $actual"
  exit 1
}
EOF_LEGACY_ZSH
}

assert_nvm_survives_broken_local_zsh_overlay() {
  home_dir=$1
  env -i HOME="$home_dir" PATH=/usr/bin:/bin TERM=xterm-256color ZDOTDIR="$home_dir" zsh -f -i <<'EOF_NVM_ZSH'
set -eu
PROMPT=
PS1=
. "$HOME/.zshenv"
. "$HOME/.zprofile"
. "$HOME/.zshrc"
assert_command() {
  name=$1
  expected=$2
  actual=$(command -v "$name" || true)
  [ "$actual" = "$expected" ] || {
    print -u2 "unexpected resolution for $name: $actual != $expected"
    exit 1
  }
}
assert_command node "$HOME/.nvm/versions/node/v20.18.0/bin/node"
assert_command npm "$HOME/.nvm/versions/node/v20.18.0/bin/npm"
assert_command qa-nvm-tool "$HOME/.nvm/versions/node/v20.18.0/bin/qa-nvm-tool"
EOF_NVM_ZSH
}

assert_no_shell_wrappers() {
  shell_name=$1
  home_dir=$2
  expected_marker=${3:-}
  case "$shell_name" in
    bash)
      env -i HOME="$home_dir" PATH="$PATH" TERM=dumb EXPECT_QA_UPDATE_MARKER="$expected_marker" HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 bash --noprofile --norc -ic '
        set -eu
        . "$HOME/.bash_profile"
        [ "$DOTFILES_HOME" = "$HOME/.dotfiles" ] || { echo "unexpected DOTFILES_HOME" >&2; exit 1; }
        [ -d "$XDG_STATE_HOME/bash" ] || { echo "missing bash state dir" >&2; exit 1; }
        [ -d "$XDG_STATE_HOME/less" ] || { echo "missing less state dir" >&2; exit 1; }
        for name in git tmux ls rm mv cp grep; do
          if alias "$name" >/dev/null 2>&1; then
            echo "unexpected alias: $name" >&2
            exit 1
          fi
          if declare -F "$name" >/dev/null 2>&1; then
            echo "unexpected function: $name" >&2
            exit 1
          fi
        done
        if [ -n "${EXPECT_QA_UPDATE_MARKER:-}" ]; then
          [ "${DOTFILES_QA_UPDATE_MARKER:-}" = "$EXPECT_QA_UPDATE_MARKER" ] || {
            echo "missing DOTFILES_QA_UPDATE_MARKER in bash startup" >&2
            exit 1
          }
        fi
        bash --noprofile --rcfile "$HOME/.bashrc" -ic "echo nested-bash:PASS" >/dev/null
      '
      ;;
    zsh)
      env -i HOME="$home_dir" PATH="$PATH" TERM=dumb EXPECT_QA_UPDATE_MARKER="$expected_marker" HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 ZDOTDIR="$home_dir" zsh -f -i -c '
        set -eu
        . "$HOME/.zshenv"
        . "$HOME/.zprofile"
        . "$HOME/.zshrc"
        [[ "$DOTFILES_HOME" == "$HOME/.dotfiles" ]] || { print -u2 "unexpected DOTFILES_HOME"; exit 1; }
        [[ -d "$XDG_STATE_HOME/zsh" ]] || { print -u2 "missing zsh state dir"; exit 1; }
        [[ -d "$XDG_STATE_HOME/less" ]] || { print -u2 "missing less state dir"; exit 1; }
        for name in git tmux ls rm mv cp grep; do
          alias "$name" >/dev/null 2>&1 && { print -u2 "unexpected alias: $name"; exit 1; }
          typeset -f "$name" >/dev/null 2>&1 && { print -u2 "unexpected function: $name"; exit 1; }
        done
        if [[ -n "${EXPECT_QA_UPDATE_MARKER:-}" ]]; then
          [[ "${DOTFILES_QA_UPDATE_MARKER:-}" == "$EXPECT_QA_UPDATE_MARKER" ]] || {
            print -u2 "missing DOTFILES_QA_UPDATE_MARKER in zsh startup"
            exit 1
          }
        fi
        zsh -f -i -c "echo nested-zsh:PASS" >/dev/null
      '
      ;;
    *)
      die "unknown shell for wrapper check: $shell_name"
      ;;
  esac
}

assert_rich_prompt_startup() {
  shell_name=$1
  home_dir=$2
  case "$shell_name" in
    bash)
      env -i HOME="$home_dir" PATH="$PATH" TERM=xterm-256color bash --noprofile --norc -ic '
        set -eu
        . "$HOME/.bash_profile"
        [ "${COLORTERM:-}" = "truecolor" ] || { echo "missing COLORTERM in rich bash startup" >&2; exit 1; }
        [ "${PROMPT_HOST_COLOR:-}" = "6" ] || { echo "unexpected PROMPT_HOST_COLOR in rich bash startup" >&2; exit 1; }
        [ -L "$HOME/.config/wezterm/wezterm.lua" ] || { echo "missing wezterm rich symlink" >&2; exit 1; }
        [ -L "$HOME/.config/alacritty/alacritty.toml" ] || { echo "missing alacritty rich symlink" >&2; exit 1; }
        [ -L "$HOME/.config/dotfiles/interactive.d/80-prompt.sh" ] || { echo "missing rich prompt symlink" >&2; exit 1; }
        printf "%s" "$PS1" | grep -q "❯" || { echo "bash prompt was not enriched" >&2; exit 1; }
      '
      ;;
    zsh)
      env -i HOME="$home_dir" PATH="$PATH" TERM=xterm-256color ZDOTDIR="$home_dir" zsh -f -i -c '
        set -eu
        . "$HOME/.zshenv"
        . "$HOME/.zprofile"
        . "$HOME/.zshrc"
        [[ "${COLORTERM:-}" == "truecolor" ]] || { print -u2 "missing COLORTERM in rich zsh startup"; exit 1; }
        [[ "${PROMPT_HOST_COLOR:-}" == "6" ]] || { print -u2 "unexpected PROMPT_HOST_COLOR in rich zsh startup"; exit 1; }
        [[ -L "$HOME/.config/wezterm/wezterm.lua" ]] || { print -u2 "missing wezterm rich symlink"; exit 1; }
        [[ -L "$HOME/.config/alacritty/alacritty.toml" ]] || { print -u2 "missing alacritty rich symlink"; exit 1; }
        [[ -L "$HOME/.config/dotfiles/interactive.d/80-prompt.sh" ]] || { print -u2 "missing rich prompt symlink"; exit 1; }
        print -r -- "$PROMPT" | grep -q "❯" || { print -u2 "zsh prompt was not enriched"; exit 1; }
      '
      ;;
    *)
      die "unknown shell for rich prompt check: $shell_name"
      ;;
  esac
}

assert_rich_prompt_loaded() {
  shell_name=$1
  home_dir=$2
  case "$shell_name" in
    bash)
      output=$(env -i HOME="$home_dir" PATH="$PATH" TERM=xterm-256color HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 bash --noprofile --norc -ic '
        set -eu
        . "$HOME/.bash_profile"
        printf "%s\n%s\n" "$PROMPT_HOST_COLOR" "$PS1"
      ')
      host_color=$(printf '%s\n' "$output" | sed -n '1p')
      prompt_line=$(printf '%s\n' "$output" | sed -n '2p')
      [ "$host_color" = 6 ] || die "unexpected rich bash PROMPT_HOST_COLOR: $host_color"
      printf '%s\n' "$prompt_line" | grep -q '\\u' || die 'rich bash prompt missing user segment'
      printf '%s\n' "$prompt_line" | grep -q '❯' || die 'rich bash prompt missing prompt glyph'
      ;;
    zsh)
      output=$(env -i HOME="$home_dir" PATH="$PATH" TERM=xterm-256color HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 ZDOTDIR="$home_dir" zsh -f -i -c '
        set -eu
        . "$HOME/.zshenv"
        . "$HOME/.zprofile"
        . "$HOME/.zshrc"
        print -r -- "$PROMPT_HOST_COLOR"
        print -r -- "$PROMPT"
      ')
      host_color=$(printf '%s\n' "$output" | sed -n '1p')
      prompt_line=$(printf '%s\n' "$output" | sed -n '2p')
      [ "$host_color" = 6 ] || die "unexpected rich zsh PROMPT_HOST_COLOR: $host_color"
      printf '%s\n' "$prompt_line" | grep -q '%F{cyan}%n%f' || die 'rich zsh prompt missing user segment'
      printf '%s\n' "$prompt_line" | grep -q '%F{magenta}❯%f' || die 'rich zsh prompt missing prompt glyph'
      ;;
    *)
      die "unknown shell for rich prompt check: $shell_name"
      ;;
  esac
}

assert_tmux_prefix_default() {
  home_dir=$1
  socket_dir=$(mktemp -d "${TMPDIR:-/tmp}/tmux.XXXXXX")
  track_cleanup_dir "$socket_dir"
  socket_path="$socket_dir/s.sock"
  if ! output=$(tmux -S "$socket_path" -f "$home_dir/.tmux.conf" start-server \; show-options -g prefix 2>/dev/null); then
    log "skipping tmux prefix assertion because tmux sockets are unavailable in this environment"
    return 0
  fi
  [ -n "$output" ] || {
    log "skipping tmux prefix assertion because tmux returned no observable output in this environment"
    return 0
  }
  if printf '%s\n' "$output" | grep -q '^prefix C-b$'; then
    tmux -S "$socket_path" kill-server >/dev/null 2>&1 || true
    return 0
  fi
  grep -Eq '(^|[[:space:]])(set|set-option)[[:space:]]+-g[[:space:]]+prefix[[:space:]]' "$home_dir/.tmux.conf" \
    && die "tmux config overrides prefix despite fallback static check"
  grep -Eq '(^|[[:space:]])unbind-key[[:space:]]+C-b' "$home_dir/.tmux.conf" \
    && die "tmux config unbinds stock prefix C-b despite fallback static check"
  grep -q 'tmux-resurrect/resurrect.tmux' "$home_dir/.tmux.conf" \
    && die "tmux config auto-loads tmux-resurrect despite standard-first baseline"
  tmux -S "$socket_path" kill-server >/dev/null 2>&1 || true
}

run_bootstrap_pipe() {
  home_dir=$1
  backup_root=$2
  source_repo=$3
  rtk_installer=$4
  shift 4
  cat "$source_repo/bootstrap/install.sh" | HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" RTK_INSTALL_URL="file://$rtk_installer" DOTFILES_DEFAULT_AGENT_TOOLS=rtk DOTFILES_TOOLS_DEFAULT_METHOD=official sh -s -- --repo "$source_repo" --target "$home_dir/.dotfiles" --backup-root "$backup_root" --yes --non-interactive "$@"
}

scenario_end_to_end_flows() {
  root=$(make_scenario_root)
  home_dir="$root/home"
  backup_root="$root/backups"
  mkdir -p "$home_dir" "$backup_root"
  source_repo=$(make_source_repo "$root")
  rtk_installer=$(make_fake_rtk_installer "$root")
  fake_brew_prefix=$(setup_command_resolution_fixture "$root" "$home_dir")

  run_bootstrap_pipe "$home_dir" "$backup_root" "$source_repo" "$rtk_installer" install --profile linux-desktop

  assert_exists "$home_dir/.dotfiles/.git"
  assert_symlink_target "$home_dir/.zshrc" "$home_dir/.dotfiles/modules/core/home/.zshrc"
  assert_symlink_target "$home_dir/.bashrc" "$home_dir/.dotfiles/modules/core/home/.bashrc"
  assert_symlink_target "$home_dir/.profile" "$home_dir/.dotfiles/modules/core/home/.profile"
  assert_symlink_target "$home_dir/.tmux.conf" "$home_dir/.dotfiles/modules/tmux/home/.tmux.conf"
  assert_symlink_target "$home_dir/.config/nvim/init.lua" "$home_dir/.dotfiles/modules/nvim/home/.config/nvim/init.lua"
  assert_symlink_target "$home_dir/.config/tmux/theme.conf" "$home_dir/.dotfiles/modules/visual/home/.config/tmux/theme.conf"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop
  assert_package_plan "$home_dir"
  assert_tool_plan "$home_dir"
  assert_default_tool_installed "$home_dir"
  assert_shell_command_resolution bash "$home_dir" "$fake_brew_prefix"
  assert_shell_command_resolution zsh "$home_dir" "$fake_brew_prefix"
  assert_no_shell_wrappers bash "$home_dir"
  assert_no_shell_wrappers zsh "$home_dir"
  assert_tmux_prefix_default "$home_dir"

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile base >/dev/null
  assert_not_exists "$home_dir/.tmux.conf"
  assert_not_exists "$home_dir/.config/nvim/init.lua"
  assert_not_exists "$home_dir/.config/tmux/theme.conf"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" base

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile linux-desktop >/dev/null
  assert_symlink_target "$home_dir/.tmux.conf" "$home_dir/.dotfiles/modules/tmux/home/.tmux.conf"
  assert_symlink_target "$home_dir/.config/nvim/init.lua" "$home_dir/.dotfiles/modules/nvim/home/.config/nvim/init.lua"
  assert_symlink_target "$home_dir/.config/tmux/theme.conf" "$home_dir/.dotfiles/modules/visual/home/.config/tmux/theme.conf"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile linux-desktop-rich >/dev/null
  assert_symlink_target "$home_dir/.config/wezterm/wezterm.lua" "$home_dir/.dotfiles/modules/terminal/home/.config/wezterm/wezterm.lua"
  assert_symlink_target "$home_dir/.config/alacritty/alacritty.toml" "$home_dir/.dotfiles/modules/terminal/home/.config/alacritty/alacritty.toml"
  assert_symlink_target "$home_dir/.config/dotfiles/interactive.d/80-prompt.sh" "$home_dir/.dotfiles/modules/prompt/home/.config/dotfiles/interactive.d/80-prompt.sh"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop-rich
  assert_rich_prompt_startup bash "$home_dir"
  assert_rich_prompt_startup zsh "$home_dir"

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile linux-desktop >/dev/null
  assert_not_exists "$home_dir/.config/wezterm/wezterm.lua"
  assert_not_exists "$home_dir/.config/alacritty/alacritty.toml"
  assert_not_exists "$home_dir/.config/dotfiles/interactive.d/80-prompt.sh"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop

  mkdir -p "$source_repo/modules/core/home/.config/dotfiles/profile.d"
  cat > "$source_repo/modules/core/home/.config/dotfiles/profile.d/90-qa-update.sh" <<'EOF_UPDATE'
# QA-only marker for update verification.
export DOTFILES_QA_UPDATE_MARKER=updated
EOF_UPDATE
  git -C "$source_repo" add modules/core/home/.config/dotfiles/profile.d/90-qa-update.sh
  git -C "$source_repo" commit -m 'qa: add update marker' >/dev/null
  expected_head=$(git -C "$source_repo" rev-parse HEAD)

  printf '%s\n' '# qa dirty checkout marker' >> "$home_dir/.dotfiles/README.md"
  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" DOTFILES_DEFAULT_AGENT_TOOLS=rtk DOTFILES_TOOLS_DEFAULT_METHOD=official "$home_dir/.dotfiles/bin/dotfiles" update --fast --profile linux-desktop >/dev/null
  actual_head=$(git -C "$home_dir/.dotfiles" rev-parse HEAD)
  [ "$actual_head" = "$expected_head" ] || die "update did not pull latest commit: $actual_head != $expected_head"
  assert_git_stash_contains "$home_dir/.dotfiles" 'dotfiles-update-'
  assert_inventory_has_target "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" .config/dotfiles/profile.d/90-qa-update.sh
  assert_symlink_target "$home_dir/.config/dotfiles/profile.d/90-qa-update.sh" "$home_dir/.dotfiles/modules/core/home/.config/dotfiles/profile.d/90-qa-update.sh"
  assert_symlink_target "$home_dir/.config/nvim/init.lua" "$home_dir/.dotfiles/modules/nvim/home/.config/nvim/init.lua"
  assert_symlink_target "$home_dir/.config/tmux/theme.conf" "$home_dir/.dotfiles/modules/visual/home/.config/tmux/theme.conf"
  assert_shell_command_resolution bash "$home_dir" "$fake_brew_prefix"
  assert_shell_command_resolution zsh "$home_dir" "$fake_brew_prefix"
  assert_no_shell_wrappers bash "$home_dir" updated
  assert_no_shell_wrappers zsh "$home_dir" updated
  assert_tmux_prefix_default "$home_dir"

  git -C "$home_dir/.dotfiles" config user.name 'QA Local'
  git -C "$home_dir/.dotfiles" config user.email 'qa-local@example.com'
  printf '%s\n' '# qa local ahead commit' >> "$home_dir/.dotfiles/README.md"
  git -C "$home_dir/.dotfiles" add README.md
  git -C "$home_dir/.dotfiles" commit -m 'qa: local ahead commit' >/dev/null
  local_ahead_head=$(git -C "$home_dir/.dotfiles" rev-parse HEAD)
  [ "$local_ahead_head" != "$expected_head" ] || die 'expected local branch to move ahead of origin/main'

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" DOTFILES_DEFAULT_AGENT_TOOLS=rtk DOTFILES_TOOLS_DEFAULT_METHOD=official "$home_dir/.dotfiles/bin/dotfiles" update --fast --profile linux-desktop >/dev/null
  actual_head=$(git -C "$home_dir/.dotfiles" rev-parse HEAD)
  [ "$actual_head" = "$expected_head" ] || die "update did not reset local branch to origin/main: $actual_head != $expected_head"
  assert_git_branch_contains "$home_dir/.dotfiles" 'dotfiles-update-backup-main-'
  ! grep -q '# qa local ahead commit' "$home_dir/.dotfiles/README.md" || die 'local ahead commit should not remain on synced main checkout'
  log 'end-to-end flow scenario passed'
}

scenario_replace_dirty_checkout() {
  root=$(make_scenario_root)
  home_dir="$root/home"
  backup_root="$root/backups"
  mkdir -p "$home_dir" "$backup_root"
  source_repo=$(make_source_repo "$root")
  rtk_installer=$(make_fake_rtk_installer "$root")
  fake_brew_prefix=$(setup_command_resolution_fixture "$root" "$home_dir")

  git clone --quiet --no-hardlinks "$source_repo" "$home_dir/.dotfiles" >/dev/null 2>&1
  printf '%s\n' '# dirty checkout marker' >> "$home_dir/.dotfiles/README.md"

  run_bootstrap_pipe "$home_dir" "$backup_root" "$source_repo" "$rtk_installer" install --profile linux-desktop

  backup_dir=$(find "$backup_root" -mindepth 1 -maxdepth 1 -type d -name 'checkout-*' | head -n 1)
  [ -n "${backup_dir:-}" ] || die "expected checkout backup directory under $backup_root"
  grep -q '# dirty checkout marker' "$backup_dir/README.md" || die 'backup did not preserve dirty checkout contents'
  assert_git_clean "$home_dir/.dotfiles"
  assert_symlink_target "$home_dir/.zshrc" "$home_dir/.dotfiles/modules/core/home/.zshrc"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop
  assert_default_tool_installed "$home_dir"
  assert_shell_command_resolution bash "$home_dir" "$fake_brew_prefix"
  assert_shell_command_resolution zsh "$home_dir" "$fake_brew_prefix"
  log 'replace-dirty-checkout scenario passed'
}

scenario_preserve_legacy_zsh_init() {
  root=$(make_scenario_root)
  home_dir="$root/home"
  backup_root="$home_dir/.local/state/alohays-dotfiles/backups"
  mkdir -p "$home_dir" "$backup_root" "$home_dir/.volta/bin" "$home_dir/.dotfiles/zsh"
  source_repo=$(make_source_repo "$root")
  rtk_installer=$(make_fake_rtk_installer "$root")

  make_fake_command "$home_dir/.volta/bin/qa-legacy-node-tool" qa-legacy-node-tool
  cat > "$home_dir/.dotfiles/zsh/zprofile" <<'EOF_ZPROFILE'
export PATH="$HOME/.volta/bin:$PATH"
EOF_ZPROFILE
  cat > "$home_dir/.dotfiles/zsh/zshenv" <<'EOF_ZSHENV'
export DOTFILES_QA_LEGACY_ZSHENV=1
EOF_ZSHENV
  cat > "$home_dir/.dotfiles/zsh/zshrc" <<'EOF_ZSHRC'
export DOTFILES_QA_LEGACY_ZSHRC=1
EOF_ZSHRC
  ln -s "$home_dir/.dotfiles/zsh/zprofile" "$home_dir/.zprofile"
  ln -s "$home_dir/.dotfiles/zsh/zshenv" "$home_dir/.zshenv"
  ln -s "$home_dir/.dotfiles/zsh/zshrc" "$home_dir/.zshrc"

  run_bootstrap_pipe "$home_dir" "$backup_root" "$source_repo" "$rtk_installer" install --profile macos-desktop

  assert_symlink_target "$home_dir/.zprofile" "$home_dir/.dotfiles/modules/core/home/.zprofile"
  assert_legacy_zsh_init_preserved "$home_dir"
  rm -f "$home_dir/.config/dotfiles/local.zprofile.sh"
  rm -f "$home_dir/.config/dotfiles/local.zshenv.sh"
  rm -f "$home_dir/.config/dotfiles/local.zsh.zsh"
  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile macos-desktop >/dev/null
  assert_legacy_zsh_init_preserved "$home_dir"
  log 'preserve-legacy-zsh-init scenario passed'
}

scenario_nvm_survives_antidote_overlay() {
  root=$(make_scenario_root)
  home_dir="$root/home"
  backup_root="$root/backups"
  mkdir -p "$home_dir" "$backup_root" "$home_dir/.nvm/versions/node/v20.18.0/bin" "$home_dir/.config/dotfiles"
  source_repo=$(make_source_repo "$root")
  rtk_installer=$(make_fake_rtk_installer "$root")

  make_fake_command "$home_dir/.nvm/versions/node/v20.18.0/bin/node" node-via-nvm
  make_fake_command "$home_dir/.nvm/versions/node/v20.18.0/bin/npm" npm-via-nvm
  make_fake_command "$home_dir/.nvm/versions/node/v20.18.0/bin/qa-nvm-tool" qa-nvm-tool

  cat > "$home_dir/.config/dotfiles/local.zsh.zsh" <<'EOF_ANTIDOTE'
echo 'antidote is not installed' >&2
return 1
EOF_ANTIDOTE

  run_bootstrap_pipe "$home_dir" "$backup_root" "$source_repo" "$rtk_installer" install --profile macos-desktop
  assert_nvm_survives_broken_local_zsh_overlay "$home_dir"

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile macos-desktop >/dev/null
  assert_nvm_survives_broken_local_zsh_overlay "$home_dir"
  log 'nvm-survives-antidote-overlay scenario passed'
}

scenario_rich_profile_flows() {
  root=$(make_scenario_root)
  home_dir="$root/home"
  backup_root="$root/backups"
  mkdir -p "$home_dir" "$backup_root"
  source_repo=$(make_source_repo "$root")
  rtk_installer=$(make_fake_rtk_installer "$root")

  run_bootstrap_pipe "$home_dir" "$backup_root" "$source_repo" "$rtk_installer" install --profile linux-desktop-rich

  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop-rich
  assert_symlink_target "$home_dir/.config/nvim/init.lua" "$home_dir/.dotfiles/modules/nvim/home/.config/nvim/init.lua"
  assert_symlink_target "$home_dir/.config/tmux/theme.conf" "$home_dir/.dotfiles/modules/visual/home/.config/tmux/theme.conf"
  assert_symlink_target "$home_dir/.config/wezterm/wezterm.lua" "$home_dir/.dotfiles/modules/terminal/home/.config/wezterm/wezterm.lua"
  assert_symlink_target "$home_dir/.config/alacritty/alacritty.toml" "$home_dir/.dotfiles/modules/terminal/home/.config/alacritty/alacritty.toml"
  assert_symlink_target "$home_dir/.config/dotfiles/interactive.d/80-prompt.sh" "$home_dir/.dotfiles/modules/prompt/home/.config/dotfiles/interactive.d/80-prompt.sh"
  assert_no_shell_wrappers bash "$home_dir"
  assert_no_shell_wrappers zsh "$home_dir"
  assert_rich_prompt_loaded bash "$home_dir"
  assert_rich_prompt_loaded zsh "$home_dir"

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile linux-desktop >/dev/null
  assert_not_exists "$home_dir/.config/wezterm/wezterm.lua"
  assert_not_exists "$home_dir/.config/alacritty/alacritty.toml"
  assert_not_exists "$home_dir/.config/dotfiles/interactive.d/80-prompt.sh"
  assert_symlink_target "$home_dir/.config/nvim/init.lua" "$home_dir/.dotfiles/modules/nvim/home/.config/nvim/init.lua"
  assert_symlink_target "$home_dir/.config/tmux/theme.conf" "$home_dir/.dotfiles/modules/visual/home/.config/tmux/theme.conf"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile ssh-server >/dev/null
  assert_not_exists "$home_dir/.config/nvim/init.lua"
  assert_not_exists "$home_dir/.config/tmux/theme.conf"
  assert_not_exists "$home_dir/.config/wezterm/wezterm.lua"
  assert_not_exists "$home_dir/.config/alacritty/alacritty.toml"
  assert_not_exists "$home_dir/.config/dotfiles/interactive.d/80-prompt.sh"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" ssh-server
  log 'rich-profile scenario passed'
}

case "${1:-all}" in
  flows)
    scenario_end_to_end_flows
    ;;
  replace-dirty)
    scenario_replace_dirty_checkout
    ;;
  preserve-legacy-zsh-init)
    scenario_preserve_legacy_zsh_init
    ;;
  nvm-survives-antidote-overlay)
    scenario_nvm_survives_antidote_overlay
    ;;
  rich)
    scenario_rich_profile_flows
    ;;
  all)
    scenario_end_to_end_flows
    scenario_replace_dirty_checkout
    scenario_preserve_legacy_zsh_init
    scenario_nvm_survives_antidote_overlay
    scenario_rich_profile_flows
    ;;
  *)
    die "unknown scenario: ${1:-}"
    ;;
esac
