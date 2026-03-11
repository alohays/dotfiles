#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
HOME_DIR=
BACKUP_ROOT=
SOURCE_REPO=
RTK_INSTALLER=

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
  [ -n "${RTK_INSTALLER:-}" ] && rm -f "$RTK_INSTALLER"
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

make_fake_rtk_installer() {
  script_path=$(make_temp_dir)/install-rtk.sh
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

setup_case() {
  HOME_DIR=$(make_temp_dir)
  BACKUP_ROOT=$(make_temp_dir)
  SOURCE_REPO=$(make_source_repo)
  RTK_INSTALLER=$(make_fake_rtk_installer)
  trap cleanup EXIT HUP INT TERM
}

run_bootstrap_install() {
  profile=${1:-linux-desktop}
  SSH_CONNECTION= \
  SSH_TTY= \
  HOME="$HOME_DIR" \
  XDG_STATE_HOME="$HOME_DIR/.local/state" \
  RTK_INSTALL_URL="file://$RTK_INSTALLER" \
  DOTFILES_DEFAULT_AGENT_TOOLS=rtk \
  DOTFILES_TOOLS_DEFAULT_METHOD=official \
  "$REPO_ROOT/bootstrap/install.sh" \
    --repo "$SOURCE_REPO" \
    --target "$HOME_DIR/.dotfiles" \
    --backup-root "$BACKUP_ROOT" \
    --yes \
    --non-interactive \
    install \
    --profile "$profile"
}

smoke_fresh() {
  setup_case
  run_bootstrap_install linux-desktop

  assert_exists "$HOME_DIR/.dotfiles/.git"
  assert_symlink_target "$HOME_DIR/.zshrc" "$HOME_DIR/.dotfiles/modules/core/home/.zshrc"
  assert_symlink_target "$HOME_DIR/.tmux.conf" "$HOME_DIR/.dotfiles/modules/tmux/home/.tmux.conf"
  assert_symlink_target "$HOME_DIR/.config/nvim/init.lua" "$HOME_DIR/.dotfiles/modules/nvim/home/.config/nvim/init.lua"
  assert_symlink_target "$HOME_DIR/.config/tmux/theme.conf" "$HOME_DIR/.dotfiles/modules/visual/home/.config/tmux/theme.conf"
  assert_inventory_profile "$HOME_DIR/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop
  assert_exists "$HOME_DIR/.local/bin/rtk"
  assert_exists "$HOME_DIR/.local/bin/.rtk-installed"
  log "fresh install smoke passed"
}

smoke_replace_existing() {
  setup_case
  mkdir -p "$HOME_DIR/.dotfiles"
  printf '%s\n' legacy > "$HOME_DIR/.dotfiles/legacy.txt"

  run_bootstrap_install linux-desktop

  backup_dir=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'checkout-*' | head -n 1)
  [ -n "${backup_dir:-}" ] || die "expected checkout backup directory under $BACKUP_ROOT"
  assert_exists "$backup_dir/legacy.txt"
  assert_exists "$HOME_DIR/.dotfiles/.git"
  assert_symlink_target "$HOME_DIR/.zshrc" "$HOME_DIR/.dotfiles/modules/core/home/.zshrc"
  assert_symlink_target "$HOME_DIR/.tmux.conf" "$HOME_DIR/.dotfiles/modules/tmux/home/.tmux.conf"
  assert_symlink_target "$HOME_DIR/.config/nvim/init.lua" "$HOME_DIR/.dotfiles/modules/nvim/home/.config/nvim/init.lua"
  assert_symlink_target "$HOME_DIR/.config/tmux/theme.conf" "$HOME_DIR/.dotfiles/modules/visual/home/.config/tmux/theme.conf"
  assert_inventory_profile "$HOME_DIR/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop
  assert_exists "$HOME_DIR/.local/bin/rtk"
  log "replace-existing smoke passed"
}

smoke_rich_profile() {
  setup_case
  run_bootstrap_install linux-desktop-rich

  assert_exists "$HOME_DIR/.dotfiles/.git"
  assert_symlink_target "$HOME_DIR/.config/nvim/init.lua" "$HOME_DIR/.dotfiles/modules/nvim/home/.config/nvim/init.lua"
  assert_symlink_target "$HOME_DIR/.config/tmux/theme.conf" "$HOME_DIR/.dotfiles/modules/visual/home/.config/tmux/theme.conf"
  assert_symlink_target "$HOME_DIR/.config/wezterm/wezterm.lua" "$HOME_DIR/.dotfiles/modules/terminal/home/.config/wezterm/wezterm.lua"
  assert_symlink_target "$HOME_DIR/.config/alacritty/alacritty.toml" "$HOME_DIR/.dotfiles/modules/terminal/home/.config/alacritty/alacritty.toml"
  assert_symlink_target "$HOME_DIR/.config/dotfiles/interactive.d/80-prompt.sh" "$HOME_DIR/.dotfiles/modules/prompt/home/.config/dotfiles/interactive.d/80-prompt.sh"
  assert_inventory_profile "$HOME_DIR/.local/state/alohays-dotfiles/managed-targets.json" linux-desktop-rich
  log "rich profile smoke passed"
}

case "${1:-all}" in
  fresh)
    smoke_fresh
    ;;
  replace-existing)
    smoke_replace_existing
    ;;
  rich)
    smoke_rich_profile
    ;;
  all)
    smoke_fresh
    smoke_replace_existing
    smoke_rich_profile
    ;;
  *)
    die "unknown scenario: $1"
    ;;
esac
