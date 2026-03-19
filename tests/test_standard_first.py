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
NVIM_PLUGINS_DIR = REPO_ROOT / "modules" / "nvim" / "home" / ".config" / "nvim" / "lua" / "dotfiles" / "plugins"
WEZTERM_CONFIG = REPO_ROOT / "modules" / "terminal" / "home" / ".config" / "wezterm" / "wezterm.lua"
ALACRITTY_CONFIG = REPO_ROOT / "modules" / "terminal" / "home" / ".config" / "alacritty" / "alacritty.toml"
TOOLS_SH = REPO_ROOT / "scripts" / "sh" / "tools.sh"
RICH_ALIASES = (
    REPO_ROOT
    / "modules"
    / "prompt"
    / "home"
    / ".config"
    / "dotfiles"
    / "interactive.d"
    / "84-rich-aliases.sh"
)
SCRIPT_PATH = REPO_ROOT / "scripts" / "dotfiles.py"


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

        socket_dir = Path(tempfile.mkdtemp(prefix="tmux-"))
        self.addCleanup(lambda: shutil.rmtree(socket_dir, ignore_errors=True))
        socket_path = socket_dir / "s.sock"
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
        for plugin_file in NVIM_PLUGINS_DIR.glob("*.lua"):
            plugin_text = plugin_file.read_text(encoding="utf-8")
            self.assertNotIn(
                "mappings =",
                plugin_text,
                f"{plugin_file.name} contains 'mappings ='",
            )
        self.assertNotIn("<leader>", readme_text)

    def test_terminal_configs_do_not_remap_keyboard_semantics(self) -> None:
        wezterm = WEZTERM_CONFIG.read_text(encoding="utf-8")
        alacritty = ALACRITTY_CONFIG.read_text(encoding="utf-8")

        self.assertNotIn("use_dead_keys = false", wezterm)
        self.assertNotIn("option_as_alt", alacritty)

    def test_default_tool_install_set_includes_rtk_and_nvim_plugins(self) -> None:
        content = TOOLS_SH.read_text(encoding="utf-8")
        self.assertIn("default_tools=${DOTFILES_DEFAULT_AGENT_TOOLS:-rtk,nvim-plugins}", content)

    def test_rich_aliases_only_shadow_expected_commands(self) -> None:
        content = RICH_ALIASES.read_text(encoding="utf-8")
        self.assertIn("alias ls=", content)
        self.assertNotIn("alias cat=", content)
        self.assertNotIn("alias top=", content)
        self.assertNotIn("alias grep=", content)

    def test_agent_cli_tools_are_registered_and_opt_in(self) -> None:
        """Agent CLI tools are registered but not in the default install set."""
        content = TOOLS_SH.read_text(encoding="utf-8")
        for tool in ("googleworkspace-cli", "agent-browser", "slack-cli"):
            with self.subTest(tool=tool):
                self.assertIn(tool, content)
        self.assertIn(
            "default_tools=${DOTFILES_DEFAULT_AGENT_TOOLS:-rtk,nvim-plugins}", content
        )

    def test_agent_cli_tool_plans_show_correct_methods(self) -> None:
        """Agent CLI tool plans show brew and official install commands."""
        content = TOOLS_SH.read_text(encoding="utf-8")
        self.assertIn("brew install googleworkspace-cli", content)
        self.assertIn("brew install agent-browser", content)
        self.assertIn("brew install --cask slack-cli", content)
        self.assertIn("npm install -g agent-browser", content)
        self.assertIn("download gws binary", content)
        self.assertIn("download slack binary", content)

    def test_zsh_plugins_tool_includes_completions(self) -> None:
        content = TOOLS_SH.read_text(encoding="utf-8")
        self.assertIn("zsh-completions", content)

    def test_tools_install_all_is_supported(self) -> None:
        """The tools subcommand supports --all for install and plan."""
        content = TOOLS_SH.read_text(encoding="utf-8")
        self.assertIn("dotfiles_install_all_tools", content)
        self.assertIn("dotfiles_plan_all_tools", content)

    def test_tools_auth_hints_are_defined(self) -> None:
        """Tools that need auth have hints defined."""
        content = TOOLS_SH.read_text(encoding="utf-8")
        self.assertIn("_dotfiles_tool_auth_hint", content)
        for cmd in ("gws auth login", "slack login", "rtk auth login"):
            self.assertIn(cmd, content)

    def test_new_nvim_plugins_exist(self) -> None:
        for name in ("bufferline.lua", "format.lua", "ai.lua"):
            path = NVIM_PLUGINS_DIR / name
            self.assertTrue(path.exists(), f"Missing plugin file: {name}")

    def test_base_profile_has_no_rich_extras(self) -> None:
        home = self.make_temp_home()
        subprocess.run(
            [
                os.environ.get("PYTHON", "python3"),
                str(SCRIPT_PATH),
                "apply",
                "--repo-root",
                str(REPO_ROOT),
                "--home",
                str(home),
                "--profile",
                "base",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertFalse(
            (home / ".config" / "dotfiles" / "p10k.zsh").exists()
        )
        self.assertFalse(
            (home / ".config" / "dotfiles" / "interactive.d" / "81-completion.zsh").exists()
        )
        self.assertFalse(
            (home / ".config" / "dotfiles" / "interactive.d" / "82-rich-plugins.zsh").exists()
        )
        self.assertFalse(
            (home / ".config" / "dotfiles" / "interactive.d" / "83-rich-fzf.sh").exists()
        )
        self.assertFalse(
            (home / ".config" / "dotfiles" / "interactive.d" / "84-rich-aliases.sh").exists()
        )
        self.assertFalse(
            (home / ".config" / "dotfiles" / "interactive.d" / "00-p10k-instant-prompt.zsh").exists()
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
