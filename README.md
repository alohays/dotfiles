# alohays/dotfiles

Standard-first, agent-friendly dotfiles for macOS, Linux desktops, and SSH/no-sudo servers.

## Philosophy

This repo is meant to be boring in the right places:
- keep defaults close to upstream behavior
- avoid command-shadowing aliases and surprise shell traps
- keep tmux on the stock prefix and keymap
- make visual polish opt-in instead of forcing themes everywhere
- replace older dotfiles installs cleanly, with one confirmation and backups
- keep secrets and host-local overrides outside the tracked repo

## v1 profile baseline

v1 targets three baseline environments:
- **macOS desktop**
- **Ubuntu/Debian-like Linux desktop**
- **SSH/no-sudo server**

The intended install path is `~/.dotfiles`.

Profiles resolve from the manifest/apply engine and choose a safe baseline first. Visual extras stay explicit and optional.

## Repo shape

The planned v1 layout is:

```text
bootstrap/install.sh
bin/dotfiles
scripts/dotfiles.py
manifests/manifest.json
profiles/*.json
modules/core/
modules/tmux/
modules/visual/
modules/ssh-server/
tests/
```

## Install

### Remote bootstrap

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/alohays/dotfiles/main/bootstrap/install.sh)"
```

### Local checkout

```sh
git clone git@github.com:alohays/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap/install.sh
```

The bootstrap flow should clone or update the repo, detect the baseline environment, and apply the selected profile into the current `HOME`.

## Update and re-apply

After the repo is installed in `~/.dotfiles`:

```sh
~/.dotfiles/bin/dotfiles update
~/.dotfiles/bin/dotfiles apply
```

For explicit profile selection, use the apply command with the profile you want, for example:

```sh
~/.dotfiles/bin/dotfiles apply --profile linux-desktop
```

## Replacement behavior

If an older dotfiles checkout or managed config already exists, the installer should:
1. detect the existing state
2. ask once before replacing it
3. create a timestamped backup
4. replace the old checkout with `~/.dotfiles`
5. re-apply managed symlinks from the manifest/profile engine

The goal is clean replacement, not in-place mutation of unknown legacy layouts.

## Package tiers

Package bootstrap is designed around a small default tier plus opt-in extras:
- **default/base**: shell, git, tmux, and other essentials needed for the core experience
- **desktop extras**: convenience packages that make sense on desktop-class machines
- **agent/helpful tools**: opt-in CLI tools that improve search, editing, and automation workflows
- **visual extras**: optional polish that should never be required for a working baseline

Prefer native platform package managers first, and keep unsupported cases explicit instead of guessing.

Inspect or plan package installation with:

```sh
~/.dotfiles/bin/dotfiles packages --list
~/.dotfiles/bin/dotfiles packages --set default --print-plan
~/.dotfiles/bin/dotfiles packages --all --print-plan
```

## Local overlays and secrets

Keep host-specific data outside the repo. Examples include:
- personal git identity
- machine-local shell hooks
- SSH host overrides
- tokens, keys, and any secret material

The expected pattern is: tracked defaults in this repo, local overrides in unmanaged `*.local`-style files or machine-local config paths that the core modules can include without committing secrets.

## Testing

Do not test against live `~/.dotfiles` during development.

Use isolated temp-`HOME` sandboxes for:
- fresh install smoke tests
- replacement/back-up flow tests
- profile application tests
- package bootstrap checks

The test suite under `tests/` should exercise a local repo path/URL and verify that no live home directory state is touched.

## Visual scope

The base config stays standard-first. Optional visual polish is kept in separate modules such as the tmux theme overrides documented in [`docs/visual.md`](docs/visual.md).

## Publishing

See [`docs/publish.md`](docs/publish.md) for the GitHub publish checklist and push steps for `alohays/dotfiles`.

## Quick verification commands

After the first real commit, these are useful sanity checks:

```sh
~/.dotfiles/bin/dotfiles help
python3 ~/.dotfiles/scripts/dotfiles.py profiles --repo-root ~/.dotfiles
python3 -m unittest tests.test_dotfiles_apply tests.test_install_smoke
```
