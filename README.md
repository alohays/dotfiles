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
- no default shell, terminal, or editor shortcut remaps
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
- keep shell/editor shortcut remaps and workflow plugins opt-in
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
zsh/
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

After the repo is installed in `~/.dotfiles`, new login shells should have `dotfiles` on `PATH` via `$DOTFILES_HOME/bin`. If you're still in the shell that ran bootstrap, either start a new login shell or keep using `~/.dotfiles/bin/dotfiles` directly:

```sh
dotfiles update
dotfiles apply
```

`dotfiles update` now syncs the checkout to `origin/main` by default (or `$DOTFILES_BRANCH` when set), auto-stashes local checkout changes if needed, and then re-applies the repo. Auto-stashed checkout changes stay in `git stash` for manual review or restore (`git stash list`, `git stash pop`).

If you want the quickest re-sync and do not need to re-check default tool installation, use the upstream-inspired fast path:

```sh
dotfiles update --fast
```

For branch/remote overrides or to disable auto-stashing, see `dotfiles update --help`.

For explicit profile selection, use the apply command with the profile you want, for example:

```sh
dotfiles apply --profile linux-desktop
```

## Replacement behavior

If an older dotfiles checkout or managed config already exists, the installer should:
1. detect the existing state
2. ask once before replacing it
3. create a timestamped backup
4. replace the old checkout with `~/.dotfiles`
5. re-apply managed symlinks from the manifest/profile engine

The goal is clean replacement, not in-place mutation of unknown legacy layouts.

If an older `~/.zshenv`, `~/.zprofile`, or `~/.zshrc` contained machine-local PATH/tool initialization (for example Homebrew, Volta, or NVM), install/apply now backs the file up and auto-migrates that legacy zsh snippet into the matching unmanaged local overlay under `~/.config/dotfiles/`. This also covers legacy symlink-based layouts such as older `~/.dotfiles/zsh/*` installs by recovering the real file contents from the checkout backup when the backed-up shell target itself is only a broken symlink. Review those generated `local.zsh*` files after the first install/update and trim anything you no longer need.

Shell startup is now split into an explicit top-level `zsh/` tree inspired by `wookayin/dotfiles`:

- `zsh/zshenv`
- `zsh/zprofile`
- `zsh/zshrc`
- `zsh/zsh.d/`

The managed home targets `~/.zshenv`, `~/.zprofile`, and `~/.zshrc` remain under `modules/core/home/` for apply/install compatibility, but they are now thin wrappers that delegate straight into `~/.dotfiles/zsh/*`. That keeps the shell layout visible in the repo while preserving the current module/profile system.

The managed shell startup now also performs baseline toolchain discovery inspired by older `wookayin/dotfiles` layouts:

- Node managers / shims: `~/.volta/bin`, `~/.nvm/current/bin`, `~/.nvm/versions/node/*/bin`, common `fnm` current/default/version bins, `~/.asdf/{bin,shims}`, `~/.nodenv/{bin,shims}`, `~/.local/share/mise/shims`, `~/.yarn/bin`
- Python managers / shims: `~/.pyenv/{bin,shims}` plus common Miniforge/Miniconda `condabin` locations
- Interactive compatibility: if only `python3`/`pip3` exist, interactive shells expose `python`/`pip` aliases automatically

Managed startup now discovers common `nvm`/`fnm` install bins directly, and unmanaged local overlays are sourced in relaxed mode so legacy plugin-manager errors do not abort the core shell startup. If you still want manager-specific shell functions or prompts, those can live in the unmanaged local overlay files.

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

Interactive workflow extras that change shortcuts or editor/shell behavior stay opt-in. Examples:

```sh
~/.dotfiles/bin/dotfiles tools install zsh-plugins
~/.dotfiles/bin/dotfiles tools install tmux-resurrect
```

If you enable those extras, wire them up from local override files such as `~/.config/dotfiles/local.interactive.sh`, `~/.config/dotfiles/local.zsh.zsh`, or `~/.config/tmux/local.conf` so the tracked baseline stays standard-first.

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
- `nvim`: a bounded Neovim UI layer for desktop profiles without default key remaps
- `visual`: tmux theme and monitored status presentation
- `terminal` + `prompt`: richer opt-in polish through the `*-desktop-rich` profiles without keyboard-semantic remaps

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
