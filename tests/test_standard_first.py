from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
FZF_SCRIPT = REPO_ROOT / "modules" / "core" / "home" / ".config" / "dotfiles" / "interactive.d" / "50-fzf.sh"
ZSH_SCRIPT = REPO_ROOT / "modules" / "core" / "home" / ".config" / "dotfiles" / "zsh.sh"
TMUX_CONFIG = REPO_ROOT / "modules" / "tmux" / "home" / ".tmux.conf"
NVIM_INIT = REPO_ROOT / "modules" / "nvim" / "home" / ".config" / "nvim" / "init.lua"
NVIM_LAZY = REPO_ROOT / "modules" / "nvim" / "home" / ".config" / "nvim" / "lua" / "dotfiles" / "lazy.lua"
NVIM_README = REPO_ROOT / "modules" / "nvim" / "README.md"
NVIM_KEYMAPS = REPO_ROOT / "modules" / "nvim" / "home" / ".config" / "nvim" / "lua" / "dotfiles" / "keymaps.lua"
WEZTERM_CONFIG = REPO_ROOT / "modules" / "terminal" / "home" / ".config" / "wezterm" / "wezterm.lua"
ALACRITTY_CONFIG = REPO_ROOT / "modules" / "terminal" / "home" / ".config" / "alacritty" / "alacritty.toml"
TOOLS_SH = REPO_ROOT / "scripts" / "sh" / "tools.sh"


class StandardFirstTests(unittest.TestCase):
    def make_temp_home(self) -> Path:
        path = Path(tempfile.mkdtemp(prefix="alohays-dotfiles-standard-"))
        self.addCleanup(lambda: shutil.rmtree(path, ignore_errors=True))
        return path

    def test_fzf_module_does_not_auto_source_shell_bindings(self) -> None:
        content = FZF_SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("fzf --zsh", content)
        self.assertNotIn("fzf --bash", content)
        self.assertNotIn(". \"$HOME/.fzf.zsh\"", content)
        self.assertNotIn(". \"$HOME/.fzf.bash\"", content)

    def test_zsh_module_avoids_completion_workflow_overrides(self) -> None:
        content = ZSH_SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("matcher-list", content)
        self.assertNotIn("menu select", content)
        self.assertNotIn("list-colors", content)

    @unittest.skipUnless(shutil.which("tmux"), "tmux is required")
    def test_tmux_config_does_not_auto_load_tmux_resurrect(self) -> None:
        home = self.make_temp_home()
        plugin = home / ".local" / "share" / "tmux" / "plugins" / "tmux-resurrect" / "resurrect.tmux"
        plugin.parent.mkdir(parents=True, exist_ok=True)
        plugin.write_text("set -g @resurrect_loaded on\nset -g prefix C-a\n", encoding="utf-8")

        socket_path = home / ".tmp" / "standard-first.sock"
        socket_path.parent.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env["HOME"] = str(home)

        show = subprocess.run(
            [
                "tmux",
                "-S",
                str(socket_path),
                "-f",
                str(TMUX_CONFIG),
                "start-server",
                ";",
                "show-options",
                "-g",
                "prefix",
                ";",
                "show-options",
                "-gqv",
                "@resurrect_loaded",
            ],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        self.addCleanup(
            lambda: subprocess.run(
                ["tmux", "-S", str(socket_path), "kill-server"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
        )

        lines = [line.strip() for line in show.stdout.splitlines() if line.strip()]
        self.assertIn("prefix C-b", lines)
        self.assertNotIn("on", lines)

    def test_nvim_module_has_no_default_custom_keymaps(self) -> None:
        init_text = NVIM_INIT.read_text(encoding="utf-8")
        lazy_text = NVIM_LAZY.read_text(encoding="utf-8")
        readme_text = NVIM_README.read_text(encoding="utf-8")

        self.assertNotIn("require('dotfiles.keymaps')", init_text)
        self.assertFalse(NVIM_KEYMAPS.exists())
        self.assertNotIn("mappings =", lazy_text)
        self.assertNotIn("<leader>", readme_text)

    def test_terminal_configs_do_not_remap_keyboard_semantics(self) -> None:
        wezterm = WEZTERM_CONFIG.read_text(encoding="utf-8")
        alacritty = ALACRITTY_CONFIG.read_text(encoding="utf-8")

        self.assertNotIn("use_dead_keys = false", wezterm)
        self.assertNotIn("option_as_alt", alacritty)

    def test_default_tool_install_set_is_rtk_only(self) -> None:
        content = TOOLS_SH.read_text(encoding="utf-8")
        self.assertIn("default_tools=${DOTFILES_DEFAULT_AGENT_TOOLS:-rtk}", content)


if __name__ == "__main__":
    unittest.main(verbosity=2)
