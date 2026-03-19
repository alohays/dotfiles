# Contributing

Thanks for your interest in contributing to alohays/dotfiles.

## Prerequisites

- macOS 10.15+ or Linux (Debian/Ubuntu)
- Python 3.11+
- git

## Running Tests

All tests use isolated temp-HOME sandboxes — they never touch your live `~/.dotfiles`.

```sh
# Run the full test suite
python3 -m pytest tests/ -v

# Run a specific test file
python3 -m pytest tests/test_dotfiles_apply.py -v

# Run the integration QA suite (slower, tests bootstrap flows)
python3 -m pytest tests/test_install_qa.py -v
```

## Architecture

```
bootstrap/install.sh  ->  Clone/update repo, dispatch to bin/dotfiles
bin/dotfiles          ->  CLI wrapper, routes to Python engine + shell tools
scripts/dotfiles.py   ->  Apply engine: profiles, symlinks, inventory, migration
scripts/sh/cli-lib.sh ->  Shell utilities for the CLI (install-time only)
scripts/sh/tools.sh   ->  Agent tool installer with bulk --all support
scripts/sh/packages.sh -> Package tier installer (default, agents, visual)
scripts/sh/banner.sh  ->  Colored ASCII banner and status output
manifests/            ->  Module registry (manifest.json)
profiles/             ->  Profile definitions with inheritance (*.json)
modules/              ->  Config payloads organized by concern
  core/               ->  Shell, git, base config (always included)
  tmux/               ->  Tmux configuration
  nvim/               ->  Neovim UI layer
  visual/             ->  Tmux theme, status bar
  prompt/             ->  Powerlevel10k, rich plugins
  terminal/           ->  WezTerm, Alacritty configs
  ssh-server/         ->  SSH-specific tweaks
```

### How Profiles Work

1. `manifest.json` defines available modules
2. Profiles in `profiles/*.json` declare which modules to include, with inheritance via `extends`
3. Auto-detection selects a profile based on OS and SSH status
4. The apply engine creates symlinks from module files to `$HOME`

### Environment Variables

The CLI uses `DOTFILES_*` environment variables for cross-layer coordination.
The `--yolo` flag is sugar that sets all four at once:

| Variable | Effect |
|----------|--------|
| `DOTFILES_PREFER_RICH` | Upgrade auto-detected profile to rich variant |
| `DOTFILES_ALL_PACKAGES` | Install all package tiers during install |
| `DOTFILES_ALL_TOOLS` | Install all agent tools during install |
| `DOTFILES_YES` | Auto-approve interactive prompts |

Other flags: `DOTFILES_DRY_RUN`, `DOTFILES_SKIP_APPLY`, `DOTFILES_SKIP_TOOLS`,
`DOTFILES_NONINTERACTIVE`. All default to `0` and follow the pattern
`DOTFILES_VAR=${DOTFILES_VAR:-0}`.

### Adding a New Module

1. Create `modules/<name>/home/` with dotfiles to manage
2. Add an entry in `manifests/manifest.json`
3. Add the module to relevant profiles in `profiles/*.json`
4. Run tests to verify

## Coding Conventions

### Shell Scripts
- Use `#!/bin/sh` with POSIX-compatible syntax (no bash-isms)
- Quote all variable expansions
- Use `set -eu` for scripts that run as entry points
- Prefix internal functions with `_dotfiles_` or `dotfiles_`

### Python
- Target Python 3.11+
- Use `from __future__ import annotations` for modern type syntax
- Raise `DotfilesError` for recoverable errors
- Output JSON to stdout for machine-readable results

### General
- Keep defaults close to upstream behavior
- No command-shadowing aliases in base profiles
- Agent-friendly first, human-friendly second
- All GitHub content (PRs, commits, issues) must be in English

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes
3. Run `python3 -m pytest tests/ -v` — all tests must pass
4. Open a PR with a clear description of what and why
