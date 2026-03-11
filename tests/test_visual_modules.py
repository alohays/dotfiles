from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "scripts" / "dotfiles.py"
PROMPT_SCRIPT = (
    REPO_ROOT
    / "modules"
    / "prompt"
    / "home"
    / ".config"
    / "dotfiles"
    / "interactive.d"
    / "80-prompt.sh"
)
WEZTERM_CONFIG = REPO_ROOT / "modules" / "terminal" / "home" / ".config" / "wezterm" / "wezterm.lua"
ALACRITTY_CONFIG = (
    REPO_ROOT / "modules" / "terminal" / "home" / ".config" / "alacritty" / "alacritty.toml"
)


class VisualModulesTests(unittest.TestCase):
    def make_temp_home(self) -> Path:
        path = Path(tempfile.mkdtemp(prefix="alohays-dotfiles-visual-"))
        self.addCleanup(lambda: shutil.rmtree(path, ignore_errors=True))
        return path

    def shell_env(self, home: Path, **extra: str) -> dict[str, str]:
        env = os.environ.copy()
        env.update(
            {
                "HOME": str(home),
                "TERM": "xterm-256color",
                "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_CACHE_HOME": str(home / ".cache"),
                "XDG_STATE_HOME": str(home / ".local" / "state"),
                "XDG_DATA_HOME": str(home / ".local" / "share"),
            }
        )
        env.update(extra)
        return env

    def run_shell(self, argv: list[str], env: dict[str, str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(argv, check=True, capture_output=True, text=True, env=env)

    def apply_profile(self, home: Path, profile: str) -> None:
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
                profile,
            ],
            check=True,
            capture_output=True,
            text=True,
        )

    def test_terminal_visual_payloads_include_expected_defaults(self) -> None:
        wezterm = WEZTERM_CONFIG.read_text(encoding="utf-8")
        alacritty = ALACRITTY_CONFIG.read_text(encoding="utf-8")

        self.assertIn("config.term = 'wezterm'", wezterm)
        self.assertIn("JetBrainsMono Nerd Font Mono", wezterm)
        self.assertIn("config.scrollback_lines = 10000", wezterm)
        self.assertIn('program = "/bin/zsh"', alacritty)
        self.assertIn('family = "JetBrainsMono Nerd Font Mono"', alacritty)
        self.assertIn('background = "#111111"', alacritty)

    @unittest.skipUnless(shutil.which("bash"), "bash is required")
    def test_prompt_module_sets_bash_prompt_and_default_host_color(self) -> None:
        home = self.make_temp_home()
        completed = self.run_shell(
            [
                "bash",
                "--noprofile",
                "--norc",
                "-ic",
                (
                    f"PS1='base> '; unset COLORTERM; . '{PROMPT_SCRIPT}'; "
                    "printf '%s\n%s\n%s' \"$PROMPT_HOST_COLOR\" \"${COLORTERM-}\" \"$PS1\""
                ),
            ],
            self.shell_env(home),
        )

        host_color, colorterm, prompt = completed.stdout.splitlines()
        self.assertEqual(host_color, "6")
        self.assertEqual(colorterm, "truecolor")
        self.assertIn("\\u", prompt)
        self.assertIn("\\h", prompt)
        self.assertIn("\\w", prompt)
        self.assertIn("❯", prompt)

    @unittest.skipUnless(shutil.which("bash"), "bash is required")
    def test_prompt_module_respects_bash_host_color_override(self) -> None:
        home = self.make_temp_home()
        completed = self.run_shell(
            [
                "bash",
                "--noprofile",
                "--norc",
                "-ic",
                (
                    f"PS1='base> '; . '{PROMPT_SCRIPT}'; "
                    "printf '%s\n%s' \"$PROMPT_HOST_COLOR\" \"$PS1\""
                ),
            ],
            self.shell_env(home, PROMPT_HOST_COLOR="202"),
        )

        host_color, prompt = completed.stdout.splitlines()
        self.assertEqual(host_color, "202")
        self.assertIn("38;5;202m", prompt)

    @unittest.skipUnless(shutil.which("zsh"), "zsh is required")
    def test_prompt_module_sets_zsh_prompt_and_respects_host_color(self) -> None:
        home = self.make_temp_home()
        completed = self.run_shell(
            [
                "zsh",
                "-f",
                "-i",
                "-c",
                (
                    f"PROMPT='base> '; . '{PROMPT_SCRIPT}'; "
                    "print -r -- \"$PROMPT_HOST_COLOR\"; print -r -- \"${COLORTERM-}\"; print -r -- \"$PROMPT\""
                ),
            ],
            self.shell_env(home, PROMPT_HOST_COLOR="202"),
        )

        host_color, colorterm, prompt = completed.stdout.splitlines()
        self.assertEqual(host_color, "202")
        self.assertEqual(colorterm, "truecolor")
        self.assertIn("%F{cyan}%n%f", prompt)
        self.assertIn("%F{202}%m%f", prompt)
        self.assertIn("%F{magenta}❯%f", prompt)

    @unittest.skipUnless(shutil.which("zsh"), "zsh is required")
    def test_prompt_module_leaves_colorterm_unset_for_dumb_term(self) -> None:
        home = self.make_temp_home()
        completed = self.run_shell(
            [
                "zsh",
                "-f",
                "-i",
                "-c",
                f"unset COLORTERM; . '{PROMPT_SCRIPT}'; print -r -- \"${{COLORTERM-unset}}\"",
            ],
            self.shell_env(home, TERM="dumb"),
        )
        self.assertEqual(completed.stdout.strip(), "unset")

    @unittest.skipUnless(shutil.which("bash"), "bash is required")
    def test_rich_profile_bash_startup_activates_prompt_in_temp_home(self) -> None:
        home = self.make_temp_home()
        self.apply_profile(home, "linux-desktop-rich")

        completed = self.run_shell(
            [
                "bash",
                "--noprofile",
                "--norc",
                "-ic",
                (
                    'set -eu; . "$HOME/.bash_profile"; '
                    'printf "%s\n%s\n%s\n" "${COLORTERM-}" "$PROMPT_HOST_COLOR" "$PS1"'
                ),
            ],
            self.shell_env(home),
        )

        colorterm, host_color, prompt = completed.stdout.splitlines()
        self.assertEqual(colorterm, "truecolor")
        self.assertEqual(host_color, "6")
        self.assertIn("\\u", prompt)
        self.assertIn("\\h", prompt)
        self.assertIn("❯", prompt)

    @unittest.skipUnless(shutil.which("zsh"), "zsh is required")
    def test_rich_profile_zsh_startup_activates_prompt_in_temp_home(self) -> None:
        home = self.make_temp_home()
        self.apply_profile(home, "linux-desktop-rich")

        completed = self.run_shell(
            [
                "zsh",
                "-f",
                "-i",
                "-c",
                (
                    '. "$HOME/.zshenv"; . "$HOME/.zprofile"; . "$HOME/.zshrc"; '
                    'print -r -- "${COLORTERM-}"; print -r -- "$PROMPT_HOST_COLOR"; print -r -- "$PROMPT"'
                ),
            ],
            self.shell_env(home, ZDOTDIR=str(home)),
        )

        colorterm, host_color, prompt = completed.stdout.splitlines()
        self.assertEqual(colorterm, "truecolor")
        self.assertEqual(host_color, "6")
        self.assertIn("%F{cyan}%n%f", prompt)
        self.assertIn("%F{blue}%~%f", prompt)
        self.assertIn("%F{magenta}❯%f", prompt)


if __name__ == "__main__":
    unittest.main(verbosity=2)
