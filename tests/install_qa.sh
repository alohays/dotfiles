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
  mktemp -d "${TMPDIR:-/tmp}/alohays-dotfiles-qa.XXXXXX"
}

make_scenario_root() {
  root=$(make_temp_dir)
  track_cleanup_dir "$root"
  printf '%s\n' "$root"
}

make_source_repo() {
  root=$1
  snapshot="$root/source-repo"
  git clone --quiet --no-hardlinks "$REPO_ROOT" "$snapshot" >/dev/null 2>&1
  git -C "$snapshot" branch -M main >/dev/null 2>&1
  git -C "$snapshot" config user.name 'QA Test'
  git -C "$snapshot" config user.email 'qa@example.com'
  printf '%s\n' "$snapshot"
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
  for pkg in git zsh tmux ripgrep jq fzf; do
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

assert_no_shell_wrappers() {
  shell_name=$1
  home_dir=$2
  expected_marker=${3:-}
  case "$shell_name" in
    bash)
      env -i HOME="$home_dir" PATH="$PATH" TERM=dumb EXPECT_QA_UPDATE_MARKER="$expected_marker" bash --noprofile --norc -i <<'EOF_BASH'
set -eu
. "$HOME/.bash_profile"
[ "$DOTFILES_HOME" = "$HOME/.dotfiles" ] || { echo 'unexpected DOTFILES_HOME' >&2; exit 1; }
[ -d "$XDG_STATE_HOME/bash" ] || { echo 'missing bash state dir' >&2; exit 1; }
[ -d "$XDG_STATE_HOME/less" ] || { echo 'missing less state dir' >&2; exit 1; }
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
    echo 'missing DOTFILES_QA_UPDATE_MARKER in bash startup' >&2
    exit 1
  }
fi
EOF_BASH
      ;;
    zsh)
      env -i HOME="$home_dir" PATH="$PATH" TERM=dumb EXPECT_QA_UPDATE_MARKER="$expected_marker" ZDOTDIR="$home_dir" zsh -f -i <<'EOF_ZSH'
set -eu
. "$HOME/.zshenv"
. "$HOME/.zprofile"
. "$HOME/.zshrc"
[[ "$DOTFILES_HOME" == "$HOME/.dotfiles" ]] || { print -u2 'unexpected DOTFILES_HOME'; exit 1; }
[[ -d "$XDG_STATE_HOME/zsh" ]] || { print -u2 'missing zsh state dir'; exit 1; }
[[ -d "$XDG_STATE_HOME/less" ]] || { print -u2 'missing less state dir'; exit 1; }
for name in git tmux ls rm mv cp grep; do
  alias "$name" >/dev/null 2>&1 && { print -u2 "unexpected alias: $name"; exit 1; }
  typeset -f "$name" >/dev/null 2>&1 && { print -u2 "unexpected function: $name"; exit 1; }
done
if [[ -n "${EXPECT_QA_UPDATE_MARKER:-}" ]]; then
  [[ "${DOTFILES_QA_UPDATE_MARKER:-}" == "$EXPECT_QA_UPDATE_MARKER" ]] || {
    print -u2 'missing DOTFILES_QA_UPDATE_MARKER in zsh startup'
    exit 1
  }
fi
EOF_ZSH
      ;;
    *)
      die "unknown shell for wrapper check: $shell_name"
      ;;
  esac
}

assert_tmux_prefix_default() {
  home_dir=$1
  socket_name="dotfiles-qa-$$"
  output=$(TMUX_TMPDIR="$home_dir/.tmp" tmux -L "$socket_name" -f "$home_dir/.tmux.conf" start-server \; show-options -g prefix)
  printf '%s\n' "$output" | grep -q '^prefix C-b$' || die "expected tmux prefix C-b, got: $output"
  TMUX_TMPDIR="$home_dir/.tmp" tmux -L "$socket_name" kill-server >/dev/null 2>&1 || true
}

run_bootstrap_pipe() {
  home_dir=$1
  backup_root=$2
  source_repo=$3
  shift 3
  cat "$source_repo/bootstrap/install.sh" | HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" sh -s -- --repo "$source_repo" --target "$home_dir/.dotfiles" --backup-root "$backup_root" --yes --non-interactive "$@"
}

scenario_end_to_end_flows() {
  root=$(make_scenario_root)
  home_dir="$root/home"
  backup_root="$root/backups"
  mkdir -p "$home_dir" "$backup_root" "$home_dir/.tmp"
  source_repo=$(make_source_repo "$root")

  run_bootstrap_pipe "$home_dir" "$backup_root" "$source_repo" install --profile linux-desktop

  assert_exists "$home_dir/.dotfiles/.git"
  assert_symlink_target "$home_dir/.zshrc" "$home_dir/.dotfiles/modules/core/home/.zshrc"
  assert_symlink_target "$home_dir/.bashrc" "$home_dir/.dotfiles/modules/core/home/.bashrc"
  assert_symlink_target "$home_dir/.profile" "$home_dir/.dotfiles/modules/core/home/.profile"
  assert_symlink_target "$home_dir/.tmux.conf" "$home_dir/.dotfiles/modules/tmux/home/.tmux.conf"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop
  assert_package_plan "$home_dir"
  assert_tool_plan "$home_dir"
  assert_no_shell_wrappers bash "$home_dir"
  assert_no_shell_wrappers zsh "$home_dir"
  assert_tmux_prefix_default "$home_dir"

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile base >/dev/null
  assert_not_exists "$home_dir/.tmux.conf"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" base

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" apply --profile linux-desktop >/dev/null
  assert_symlink_target "$home_dir/.tmux.conf" "$home_dir/.dotfiles/modules/tmux/home/.tmux.conf"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop

  mkdir -p "$source_repo/modules/core/home/.config/dotfiles/profile.d"
  cat > "$source_repo/modules/core/home/.config/dotfiles/profile.d/90-qa-update.sh" <<'EOF_UPDATE'
# QA-only marker for update verification.
export DOTFILES_QA_UPDATE_MARKER=updated
EOF_UPDATE
  git -C "$source_repo" add modules/core/home/.config/dotfiles/profile.d/90-qa-update.sh
  git -C "$source_repo" commit -m 'qa: add update marker' >/dev/null
  expected_head=$(git -C "$source_repo" rev-parse HEAD)

  HOME="$home_dir" XDG_STATE_HOME="$home_dir/.local/state" "$home_dir/.dotfiles/bin/dotfiles" update --profile linux-desktop >/dev/null
  actual_head=$(git -C "$home_dir/.dotfiles" rev-parse HEAD)
  [ "$actual_head" = "$expected_head" ] || die "update did not pull latest commit: $actual_head != $expected_head"
  assert_inventory_has_target "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" .config/dotfiles/profile.d/90-qa-update.sh
  assert_symlink_target "$home_dir/.config/dotfiles/profile.d/90-qa-update.sh" "$home_dir/.dotfiles/modules/core/home/.config/dotfiles/profile.d/90-qa-update.sh"
  assert_no_shell_wrappers bash "$home_dir" updated
  assert_no_shell_wrappers zsh "$home_dir" updated
  assert_tmux_prefix_default "$home_dir"
  log 'end-to-end flow scenario passed'
}

scenario_replace_dirty_checkout() {
  root=$(make_scenario_root)
  home_dir="$root/home"
  backup_root="$root/backups"
  mkdir -p "$home_dir" "$backup_root"
  source_repo=$(make_source_repo "$root")

  git clone --quiet --no-hardlinks "$source_repo" "$home_dir/.dotfiles" >/dev/null 2>&1
  printf '%s\n' '# dirty checkout marker' >> "$home_dir/.dotfiles/README.md"

  run_bootstrap_pipe "$home_dir" "$backup_root" "$source_repo" install --profile linux-desktop

  backup_dir=$(find "$backup_root" -mindepth 1 -maxdepth 1 -type d -name 'checkout-*' | head -n 1)
  [ -n "${backup_dir:-}" ] || die "expected checkout backup directory under $backup_root"
  grep -q '# dirty checkout marker' "$backup_dir/README.md" || die 'backup did not preserve dirty checkout contents'
  assert_git_clean "$home_dir/.dotfiles"
  assert_symlink_target "$home_dir/.zshrc" "$home_dir/.dotfiles/modules/core/home/.zshrc"
  assert_inventory_profile "$home_dir/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop
  log 'replace-dirty-checkout scenario passed'
}

case "${1:-all}" in
  flows)
    scenario_end_to_end_flows
    ;;
  replace-dirty)
    scenario_replace_dirty_checkout
    ;;
  all)
    scenario_end_to_end_flows
    scenario_replace_dirty_checkout
    ;;
  *)
    die "unknown scenario: ${1:-}"
    ;;
esac
