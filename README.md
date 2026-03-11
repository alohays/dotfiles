# alohays/dotfiles

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/73bc2ddc-ae63-4cd5-b210-bcd29fb5dcd8" />

Standard-first, agent-friendly dotfiles for macOS, Linux desktops, and SSH/no-sudo servers — designed for coding agents that want boring defaults and humans who still want a beautiful terminal.

## Why this repo exists

This repo is a fresh AI-era reset with a sincere shoutout to [`wookayin/dotfiles`](https://github.com/wookayin/dotfiles), a beloved long-time inspiration. That style of thoughtful, personal, deeply polished dotfiles is still something I admire.

But the constraints have changed. Many pre-AI-era dotfiles were optimized for one expert human who already knew every alias, every remapped keybinding, every shell hook, and every visual convention by heart. Coding agents such as Claude Code, Codex CLI, and Gemini CLI usually do not. Command-shadowing aliases, custom keymaps, surprise shell traps, and excessive customization are all harder for agents to infer. They add hidden state, consume extra context/tokens, and can reduce agent performance.

So the goal here is simple: optimize for coding agents first, humans second. That means a predictable, upstream-shaped, token-efficient baseline for agents, plus explicit polish and convenience for humans. It also means this repo should install agent-helpful tools by default when they materially improve how agents work.

## What this repo optimizes for

### Priority 1: agents

- default CLI behavior instead of surprising aliases
- stock tmux prefix and keymap
- standard file locations and a predictable bootstrap/apply flow
- token-efficient environments with less hidden state and less explanation overhead
- default installation of agent-helpful tools such as RTK when they materially improve agent performance
- isolated temp-`HOME` testing so development never mutates live `~/.dotfiles`

### Priority 2: humans

- a comfortable, still-beautiful TUI-first experience
- optional visual polish instead of mandatory theme stacks
- one-command bootstrap plus easy re-apply/update flows
- one-command useful-tool installation through explicit package tiers
- local overrides and secrets kept out of the tracked repo

## Philosophy

This repo is meant to be boring in the right places and opinionated in the useful ones:
- keep defaults close to upstream behavior
- avoid command-shadowing aliases and surprise shell traps
- keep tmux on the stock prefix and keymap
- make visual polish opt-in instead of forcing themes everywhere
- install proven agent-helpful tools by default when they measurably help coding agents work better
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
modules/nvim/
modules/visual/
modules/terminal/
modules/prompt/
modules/ssh-server/
tests/
```

## Install

### Remote bootstrap

```sh
curl -fsSL https://raw.githubusercontent.com/alohays/dotfiles/main/bootstrap/install.sh | sh -s --
```

### Local checkout

```sh
git clone git@github.com:alohays/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap/install.sh
```

The bootstrap flow clones or updates the repo, detects the baseline environment, applies the selected profile into the current `HOME`, and installs the default agent-tool set.

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

If an older `~/.zshenv`, `~/.zprofile`, or `~/.zshrc` contained machine-local PATH/tool initialization (for example Homebrew, Volta, or NVM), install/apply now backs the file up and auto-migrates that legacy zsh snippet into the matching unmanaged local overlay under `~/.config/dotfiles/`. Review those generated `local.zsh*` files after the first install/update and trim anything you no longer need.

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

## Default agent tools

The first default external agent helper is [RTK-AI](https://www.rtk-ai.app/). It is included because the primary goal of this repo is an agent-friendly CLI, and RTK is the kind of tool that can improve how agents operate without forcing weird aliases or non-standard shell semantics.

That also means the tool layer stays swappable: if a better tool shows up later, this repo should be able to switch defaults without rewriting the whole shell philosophy.

You can inspect or override the tool flow with:

```sh
~/.dotfiles/bin/dotfiles tools list
~/.dotfiles/bin/dotfiles tools plan rtk
~/.dotfiles/bin/dotfiles tools install rtk
~/.dotfiles/bin/dotfiles install --skip-tools
```

That means RTK can be part of the default agent-first setup today, and later be swapped for a better tool without turning the core dotfiles into a weird non-standard environment.

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

The test suite under `tests/` should exercise a local repo path/URL and verify that no live home directory state is touched. If a test or QA pass cannot prove that it stays inside a temp `HOME`, it is not safe enough.

A stricter QA suite lives in `tests/install_qa.sh` and `tests/test_install_qa.py`. It stress-tests bootstrap, replace-existing backups, package planning, shell startup, and tmux defaults in fully isolated sandboxes.

## Visual scope

The base config stays standard-first, but the desktop layer is now richer:
- `tmux`: safe terminal capability defaults + stock-keymap tmux baseline
- `nvim`: a bounded Neovim UI layer for desktop profiles
- `visual`: tmux theme and monitored status presentation
- `terminal` + `prompt`: richer opt-in polish through the `*-desktop-rich` profiles

See [`docs/visual.md`](docs/visual.md) for the layering model and activation guidance.

## Publishing

See [`docs/publish.md`](docs/publish.md) for the GitHub publish checklist and push steps for `alohays/dotfiles`.

## Quick verification commands

After the first real commit, these are useful sanity checks:

```sh
~/.dotfiles/bin/dotfiles help
python3 ~/.dotfiles/scripts/dotfiles.py profiles --repo-root ~/.dotfiles
python3 -m unittest tests.test_dotfiles_apply tests.test_visual_modules tests.test_install_smoke tests.test_install_qa
~/.dotfiles/bin/dotfiles tools plan rtk
```
