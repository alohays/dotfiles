#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
HOME_DIR=
BACKUP_ROOT=
SOURCE_REPO=

log() {
  printf '%s\n' "install-smoke: $*"
}

die() {
  printf '%s\n' "install-smoke: error: $*" >&2
  exit 1
}

cleanup() {
  [ -n "${HOME_DIR:-}" ] && rm -rf "$HOME_DIR"
  [ -n "${BACKUP_ROOT:-}" ] && rm -rf "$BACKUP_ROOT"
  [ -n "${SOURCE_REPO:-}" ] && rm -rf "$SOURCE_REPO"
}

assert_exists() {
  [ -e "$1" ] || die "expected path to exist: $1"
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
with path.open(encoding="utf-8") as handle:
    payload = json.load(handle)
if payload.get("profile") != expected:
    raise SystemExit(f"inventory profile mismatch: {payload.get('profile')} != {expected}")
PY
}

make_temp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/alohays-dotfiles-smoke.XXXXXX"
}

make_source_repo() {
  snapshot=$(make_temp_dir)
  for item in bin bootstrap manifests modules profiles scripts README.md .gitignore; do
    if [ -e "$REPO_ROOT/$item" ]; then
      cp -R "$REPO_ROOT/$item" "$snapshot/$item"
    fi
  done
  git -C "$snapshot" init >/dev/null 2>&1
  git -C "$snapshot" checkout -B main >/dev/null 2>&1
  git -C "$snapshot" add -A
  git -C "$snapshot" -c user.name='Smoke Test' -c user.email='smoke@example.com' commit -m 'snapshot' >/dev/null 2>&1
  printf '%s\n' "$snapshot"
}

setup_case() {
  HOME_DIR=$(make_temp_dir)
  BACKUP_ROOT=$(make_temp_dir)
  SOURCE_REPO=$(make_source_repo)
  trap cleanup EXIT HUP INT TERM
}

run_bootstrap_install() {
  SSH_CONNECTION= \
  SSH_TTY= \
  HOME="$HOME_DIR" \
  XDG_STATE_HOME="$HOME_DIR/.local/state" \
  "$REPO_ROOT/bootstrap/install.sh" \
    --repo "$SOURCE_REPO" \
    --target "$HOME_DIR/.dotfiles" \
    --backup-root "$BACKUP_ROOT" \
    --yes \
    --non-interactive \
    install \
    --profile linux-desktop
}

smoke_fresh() {
  setup_case
  run_bootstrap_install

  assert_exists "$HOME_DIR/.dotfiles/.git"
  assert_symlink_target "$HOME_DIR/.zshrc" "$HOME_DIR/.dotfiles/modules/core/home/.zshrc"
  assert_symlink_target "$HOME_DIR/.tmux.conf" "$HOME_DIR/.dotfiles/modules/tmux/home/.tmux.conf"
  assert_inventory_profile "$HOME_DIR/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop
  log "fresh install smoke passed"
}

smoke_replace_existing() {
  setup_case
  mkdir -p "$HOME_DIR/.dotfiles"
  printf '%s\n' legacy > "$HOME_DIR/.dotfiles/legacy.txt"

  run_bootstrap_install

  backup_dir=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'checkout-*' | head -n 1)
  [ -n "${backup_dir:-}" ] || die "expected checkout backup directory under $BACKUP_ROOT"
  assert_exists "$backup_dir/legacy.txt"
  assert_exists "$HOME_DIR/.dotfiles/.git"
  assert_symlink_target "$HOME_DIR/.zshrc" "$HOME_DIR/.dotfiles/modules/core/home/.zshrc"
  assert_inventory_profile "$HOME_DIR/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop
  log "replace-existing smoke passed"
}

case "${1:-all}" in
  fresh)
    smoke_fresh
    ;;
  replace-existing)
    smoke_replace_existing
    ;;
  all)
    smoke_fresh
    smoke_replace_existing
    ;;
  *)
    die "unknown scenario: $1"
    ;;
esac
