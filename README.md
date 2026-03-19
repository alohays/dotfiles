# alohays/dotfiles

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) ![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white) ![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black) ![Zsh](https://img.shields.io/badge/Zsh-F15A24?logo=zsh&logoColor=white) ![Neovim](https://img.shields.io/badge/Neovim-57A143?logo=neovim&logoColor=white)

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/73bc2ddc-ae63-4cd5-b210-bcd29fb5dcd8" />

Agent-first dotfiles for macOS, Linux desktops, and SSH servers.
Boring defaults for coding agents, beautiful terminals for humans.

---

## Table of Contents

- [Quick Start](#-quick-start)
- [What You Get](#-what-you-get)
- [Comparison](#-comparison)
- [Why Agent-First?](#-why-agent-first)
- [Profiles](#-profiles)
- [Neovim, Shell & Tools](#%EF%B8%8F-neovim-shell--tools)
- [Update & Maintain](#-update--maintain)
- [Acknowledgments](#-acknowledgments)
- [License](#-license)

---

## ⚡ Quick Start

```sh
curl -fsSL https://raw.githubusercontent.com/alohays/dotfiles/main/bootstrap/install.sh | sh -s --
```

This clones the repo into `~/.dotfiles`, auto-detects your environment
(macOS desktop / Linux desktop / SSH server), applies the matching profile,
installs default agent tools, and backs up existing configs with timestamps.
If an older dotfiles checkout already exists, the installer detects it,
asks once before replacing, and creates a timestamped backup.

**From a local clone:**

```sh
git clone git@github.com:alohays/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap/install.sh
```

**Requirements:**

- macOS 10.15+ or Linux (Debian/Ubuntu)
- Python 3.11+
- git

### Optional: Unlock the Rich Experience

The base install gives you a clean, agent-friendly environment. If you also
want Powerlevel10k prompts, syntax highlighting, and colorized CLI tools,
apply a rich profile and install the extras:

```sh
dotfiles apply --profile macos-desktop-rich   # or linux-desktop-rich
dotfiles tools install powerlevel10k
dotfiles tools install fast-syntax-highlighting
dotfiles tools install fzf-git
dotfiles packages --set visual
```

See [docs/visual.md](docs/visual.md) for the full visual guide, plugin
categories, font guidance, and keybinding reference.

---

## ✨ What You Get

| | Feature | Details |
|---|---|---|
| :rocket: | **One-command bootstrap** | Auto-detects macOS, Linux, or SSH — applies the right profile |
| :brain: | **Agent-first defaults** | Stock keymaps, no aliases, no traps — agents just work |
| :art: | **37 Neovim plugins** | Lazy-loaded, zero custom keybindings, LSP + completion + treesitter |
| :zap: | **Powerlevel10k prompt** | Instant prompt, cloud segments (AWS/GCloud/Azure), transient mode |
| :package: | **10 installable tools** | RTK, agent-browser, slack-cli, googleworkspace-cli, fzf-git, and more |
| :shield: | **Timestamped backups** | Existing configs are backed up before any replacement |
| :test_tube: | **66 isolated tests** | Temp-HOME sandboxing — never touches your live dotfiles |
| :paintbrush: | **Colored CLI** | ASCII banner with status indicators during install/update |
| :lock: | **Secrets stay local** | Git identity, shell overrides, SSH config — never committed |
| :arrows_counterclockwise: | **Auto-migration** | Recovers legacy zsh configs into local overlays automatically |

---

## 🆚 Comparison

| | alohays/dotfiles | chezmoi | yadm | GNU stow |
|---|:---:|:---:|:---:|:---:|
| Agent-first defaults | ✅ | ❌ | ❌ | ❌ |
| Profile-based configs | 6 profiles | Templates | ❌ | ❌ |
| One-command bootstrap | ✅ | ✅ | ✅ | ❌ |
| Auto environment detection | ✅ | ❌ | ❌ | ❌ |
| Neovim plugin layer | 37 plugins | N/A | N/A | N/A |
| Agent tool installer | 10 tools | ❌ | ❌ | ❌ |
| Auto-migration from legacy | ✅ | ❌ | ❌ | ❌ |
| Local override pattern | Built-in | Templates | Alt files | Manual |
| Interactive git identity setup | ✅ | ❌ | ❌ | ❌ |
| Timestamped backups | ✅ | ❌ | ❌ | ❌ |
| Isolated test suite | 66 tests | ✅ | ❌ | ❌ |

---

## 🧠 Why Agent-First?

Pre-AI dotfiles were optimized for one expert human who already knew every
alias, keybinding, and shell hook by heart. Coding agents like Claude Code,
Codex CLI, and Gemini CLI do not share that muscle memory.

Command-shadowing aliases make agents guess what `ls` actually does.
Custom keymaps force agents to discover non-standard bindings.
Shell traps and hidden hooks consume tokens explaining state that
upstream defaults would have made obvious.

This repo keeps the environment predictable and token-efficient for agents:

- Default CLI behavior instead of surprising aliases
- Stock tmux prefix and keymap
- No shell, terminal, or editor shortcut remaps
- Standard file locations and a predictable bootstrap/apply flow
- Proven agent-helpful tools like RTK installed by default

For humans, nothing is sacrificed:

- A comfortable, beautiful TUI-first experience
- Optional visual polish instead of mandatory theme stacks
- One-command bootstrap plus easy re-apply and update flows
- Local overrides and secrets kept out of the tracked repo

---

## 📦 Profiles

| Profile | Extends | Modules | Environment |
|---------|---------|---------|-------------|
| `base` | — | core | Shared baseline |
| `macos-desktop` | base | + tmux, nvim, visual | macOS workstation |
| `macos-desktop-rich` | macos-desktop | + terminal, prompt | Full visual polish |
| `linux-desktop` | base | + tmux, nvim, visual | Linux workstation |
| `linux-desktop-rich` | linux-desktop | + terminal, prompt | Full visual polish |
| `ssh-server` | base | + ssh-server, tmux | Remote / no-sudo |

Profiles are auto-detected on install based on OS and environment. Override
with `dotfiles apply --profile <name>`. Each profile inherits from its
parent and adds modules incrementally, so `macos-desktop-rich` includes
everything in `macos-desktop` plus terminal emulator presets (WezTerm,
Alacritty) and the Powerlevel10k prompt layer. The `ssh-server` profile
skips desktop modules entirely and focuses on a lightweight tmux + core
setup suitable for remote machines without sudo.

---

## 🛠️ Neovim, Shell & Tools

### Neovim

37 lazy-loaded plugins with zero custom keybindings, using stock Neovim
0.10+ keys. All plugins are managed by lazy.nvim with automatic treesitter
parser installation for 21 languages.

| Category | Highlights |
|----------|-----------|
| Colorscheme | kanagawa (dragon theme) |
| Git | gitsigns, diffview, git-messenger |
| LSP | lspconfig, mason, mason-lspconfig, nvim-cmp, lsp_signature |
| UI | neo-tree, telescope, lualine (+ navic breadcrumbs), image.nvim |
| Treesitter | nvim-treesitter with 21 auto-installed language parsers |
| Editor | indent-blankline, nvim-colorizer, todo-comments, which-key |
| Notifications | nvim-notify, noice, dressing, fidget |
| Diagnostics | trouble |
| Markdown | render-markdown |
| AI | claudecode.nvim |

Standard keybindings are all Neovim 0.10+ built-ins: `gd` (go to
definition), `gr` (references), `K` (hover), `[d`/`]d` (diagnostics),
`<C-n>`/`<C-p>` (completion navigation), `<C-y>` (accept), `<C-e>`
(dismiss).

Telescope commands: `:Telescope find_files`, `:Telescope live_grep`,
`:Telescope buffers`. File explorer: `:Neotree toggle left`. Diagnostics:
`:Trouble diagnostics`. Diff: `:DiffviewOpen`, `:DiffviewFileHistory`.

See [docs/visual.md](docs/visual.md) for the full plugin list and
keybinding reference.

### Shell & Prompt

Powerlevel10k with instant prompt, transient mode, and cloud segments for
AWS, GCloud, and Azure. The prompt shows os_icon, directory, and git status
on the left; execution time, background jobs, virtualenv, pyenv, node
version, kubecontext, and clock on the right.

FZF keybindings are enabled in rich profiles:

- **Ctrl-T** -- file search with bat preview (falls back to cat)
- **Ctrl-R** -- history search
- **Alt-C** -- directory cd with eza tree preview (falls back to tree/ls)

fast-syntax-highlighting provides an upgrade path over standard
zsh-syntax-highlighting. When installed, it is detected and activated
automatically.

Shell startup is split into an explicit `zsh/` tree (`zshenv`, `zprofile`,
`zshrc`, `zsh.d/`) that keeps the layout visible in the repo while thin
wrappers in `HOME` delegate into `~/.dotfiles/zsh/`.

Toolchain auto-discovery covers Volta, NVM, FNM, pyenv, Conda, asdf,
nodenv, and mise paths so managed shell startup finds your tools without
manual PATH configuration. If only `python3`/`pip3` exist, interactive
shells expose `python`/`pip` aliases automatically.

### Agent Tools

| Tool | Description | Install |
|------|-------------|---------|
| rtk | AI-powered context for agents | `dotfiles tools install rtk` |
| nvim-plugins | Bootstrap lazy.nvim + treesitter | `dotfiles tools install nvim-plugins` |
| googleworkspace-cli | Google Workspace from terminal | `dotfiles tools install googleworkspace-cli` |
| agent-browser | Headless browser for agents | `dotfiles tools install agent-browser` |
| slack-cli | Slack from terminal | `dotfiles tools install slack-cli` |
| powerlevel10k | Rich zsh prompt theme | `dotfiles tools install powerlevel10k` |
| fast-syntax-highlighting | Enhanced zsh syntax coloring | `dotfiles tools install fast-syntax-highlighting` |
| fzf-git | Git-aware FZF pickers | `dotfiles tools install fzf-git` |
| zsh-plugins | Autosuggestions + completions | `dotfiles tools install zsh-plugins` |
| tmux-resurrect | Session persistence | `dotfiles tools install tmux-resurrect` |

List all tools with `dotfiles tools list`. Preview what an install does
before running it with `dotfiles tools plan <name>`. Skip default tool
installation during bootstrap with `dotfiles install --skip-tools`.

### Package Tiers

| Tier | Contents | Install |
|------|----------|---------|
| `default` | git, neovim, zsh, tmux | `dotfiles packages --set default` |
| `agents` | ripgrep, fd, jq, fzf, git-delta | `dotfiles packages --set agents` |
| `visual` | eza, bat, tree | `dotfiles packages --set visual` |

Preview what a tier installs with `dotfiles packages --set <tier> --print-plan`.
Install all tiers at once with `dotfiles packages --all`.

---

## 🔄 Update & Maintain

```sh
dotfiles update          # sync to origin/main, re-apply, re-check tools
dotfiles update --fast   # sync + re-apply without tool checks
dotfiles apply           # re-apply current profile
```

Local checkout changes are auto-stashed during update and preserved in
`git stash` for manual review. Auto-stashed changes can be inspected with
`git stash list` and restored with `git stash pop`. For branch or remote
overrides, or to disable auto-stashing, see `dotfiles update --help`.

Host-specific data stays outside the repo in local overlay files. See
[docs/local-overrides.md](docs/local-overrides.md) for local customization
patterns including git identity, machine-local shell hooks, SSH host
overrides, and secret management.

Architecture and contribution guidelines are documented in
[CONTRIBUTING.md](CONTRIBUTING.md).

---

## 🙏 Acknowledgments

A sincere shoutout to [wookayin/dotfiles](https://github.com/wookayin/dotfiles),
the long-time inspiration behind much of this repo's structure, shell
startup design, and visual philosophy. That style of thoughtful, deeply
polished, personal dotfiles remains something to admire and aspire to.

---

## 📄 License

[MIT](LICENSE)
