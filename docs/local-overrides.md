# Local Overrides

This repo follows a strict pattern: **tracked defaults in the repo, local customizations in unmanaged files**. Override files are gitignored and never committed, keeping secrets and machine-specific configuration safe.

## Available Override Files

### Shell Environment

| File | Sourced by | When | Purpose |
|------|-----------|------|---------|
| `~/.config/dotfiles/local.env.sh` | `env.sh` | Every shell (login + non-login) | PATH additions, env vars, tool config |
| `~/.config/dotfiles/local.interactive.sh` | `interactive.sh` | Interactive shells only | Aliases, custom functions, tool hooks |
| `~/.config/dotfiles/local.zshenv.sh` | `zsh/zshenv` | Every zsh shell | Zsh-specific env overrides |
| `~/.config/dotfiles/local.zprofile.sh` | `zsh/zprofile` | Zsh login shells | Login-time setup |
| `~/.config/dotfiles/local.zsh.zsh` | `zsh/zshrc` | Interactive zsh | Zsh-specific interactive config |
| `~/.config/dotfiles/local.profile.sh` | `.profile` | POSIX login shells | Bash/sh login env |

### Git

| File | Included by | Purpose |
|------|------------|---------|
| `~/.config/git/config.local` | `.gitconfig` (`[include]`) | `user.name`, `user.email`, signing keys |

The install flow prompts for git identity and writes this file automatically.

### Tmux

| File | Included by | Purpose |
|------|------------|---------|
| `~/.config/tmux/local.conf` | `.tmux.conf` (`source-file -q`) | Custom keybindings, status bar tweaks |

### SSH

| File | Included by | Purpose |
|------|------------|---------|
| `~/.ssh/config.local` | `.ssh/config` (`Include`) | Host-specific SSH config, jump hosts, keys |

### SSH Server

| File | Sourced by | Purpose |
|------|-----------|---------|
| `~/.config/dotfiles/local.server.sh` | `60-ssh-server.sh` | Server-specific environment |

## Using Example Files

Each override has a `.example` template in the repo:

```sh
# Copy and customize
cp ~/.config/git/config.local.example ~/.config/git/config.local
cp ~/.config/tmux/local.conf.example ~/.config/tmux/local.conf
cp ~/.ssh/config.local.example ~/.ssh/config.local
```

## Debugging

If an override file is not loading:

1. **Check the file is readable**: `ls -la ~/.config/dotfiles/local.env.sh`
2. **Check the exact filename**: Override files use the `local.*` naming convention (not `*.local`)
3. **Check which shell phase**: `env.sh` runs for all shells, `interactive.sh` only for interactive ones
4. **Source errors are suppressed**: Override files are sourced with `dotfiles_source_optional_relaxed`, which catches errors silently. Add `echo "loaded"` at the top to verify.
5. **Check shell type**: `.zsh` files only load in zsh, `.sh` files load in both bash and zsh
