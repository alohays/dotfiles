from __future__ import annotations

import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "scripts" / "dotfiles.py"
STATE_PATH = Path(".local/state/alohays-dotfiles/managed-targets.json")


def load_script_module():
    spec = importlib.util.spec_from_file_location("alohays_dotfiles_script", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load scripts/dotfiles.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class DotfilesApplyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.script = load_script_module()

    def make_temp_dir(self) -> Path:
        path = Path(tempfile.mkdtemp(prefix="alohays-dotfiles-"))
        self.addCleanup(lambda: shutil.rmtree(path, ignore_errors=True))
        return path

    def make_temp_repo(self) -> Path:
        repo_root = self.make_temp_dir()
        shutil.copytree(REPO_ROOT / "manifests", repo_root / "manifests")
        shutil.copytree(REPO_ROOT / "profiles", repo_root / "profiles")
        return repo_root

    def write_file(self, path: Path, content: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def write_module_file(
        self,
        repo_root: Path,
        module_name: str,
        relative_path: str,
        content: str,
    ) -> None:
        self.write_file(repo_root / "modules" / module_name / "home" / relative_path, content)

    def run_cli(self, *args: str, env: dict[str, str] | None = None) -> dict[str, object]:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), *args],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        return json.loads(completed.stdout)

    def assert_symlink_to(self, link_path: Path, target_path: Path) -> None:
        self.assertTrue(link_path.is_symlink(), f"expected symlink at {link_path}")
        self.assertEqual(link_path.resolve(strict=False), target_path.resolve(strict=False))

    def test_profile_resolution_inherits_base_modules(self) -> None:
        manifest = self.script.load_manifest(REPO_ROOT)
        resolved = self.script.resolve_profile(REPO_ROOT, manifest, "linux-desktop")
        self.assertEqual(resolved["modules"], ["core", "tmux", "nvim", "visual"])
        self.assertEqual(resolved["lineage"], ["base", "linux-desktop"])

    def test_profiles_command_lists_shipped_profiles(self) -> None:
        result = self.run_cli("profiles", "--repo-root", str(REPO_ROOT))
        self.assertTrue(result["ok"])
        names = [profile["name"] for profile in result["profiles"]]
        self.assertEqual(
            names,
            [
                "base",
                "linux-desktop-rich",
                "linux-desktop",
                "macos-desktop-rich",
                "macos-desktop",
                "ssh-server",
            ],
        )

    def test_apply_creates_symlinks_and_inventory(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_file(repo_root / "modules/core/.zshrc", "export TEST_PROFILE=1\n")
        self.write_file(repo_root / "modules/tmux/.tmux.conf", "set -g status on\n")
        self.write_file(repo_root / "modules/nvim/.config/nvim/init.lua", "vim.o.number = true\n")

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "linux-desktop",
        )

        self.assertTrue(result["ok"])
        self.assert_symlink_to(home / ".zshrc", repo_root / "modules/core/.zshrc")
        self.assert_symlink_to(home / ".tmux.conf", repo_root / "modules/tmux/.tmux.conf")
        self.assert_symlink_to(home / ".config/nvim/init.lua", repo_root / "modules/nvim/.config/nvim/init.lua")
        inventory = json.loads((home / STATE_PATH).read_text(encoding="utf-8"))
        self.assertEqual(inventory["profile"], "linux-desktop")
        self.assertEqual(
            [entry["target"] for entry in inventory["entries"]],
            [".config/nvim/init.lua", ".tmux.conf", ".zshrc"],
        )

    def test_apply_backs_up_existing_target_and_records_metadata(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_file(repo_root / "modules/core/.zshrc", "export MANAGED=1\n")
        self.write_file(home / ".zshrc", "legacy config\n")

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        self.assertTrue(result["ok"])
        self.assertIsNotNone(result["backup_metadata_path"])
        metadata_path = Path(str(result["backup_metadata_path"]))
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        self.assertEqual(metadata["entries"][0]["target"], ".zshrc")
        backup_file = metadata_path.parent / metadata["entries"][0]["backup_path"]
        self.assertEqual(backup_file.read_text(encoding="utf-8"), "legacy config\n")
        self.assert_symlink_to(home / ".zshrc", repo_root / "modules/core/.zshrc")

    def test_apply_auto_migrates_legacy_zprofile_into_local_overlay(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".profile", "# managed profile\n")
        self.write_module_file(repo_root, "core", ".zprofile", "# managed zprofile\n")
        legacy = 'export PATH="$HOME/.volta/bin:$PATH"\n'
        self.write_file(home / ".zprofile", legacy)

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        self.assertTrue(result["ok"])
        migrated = home / ".config/dotfiles/local.zprofile.sh"
        self.assertTrue(migrated.exists(), "expected legacy zprofile migration file to be created")
        migrated_text = migrated.read_text(encoding="utf-8")
        self.assertIn('export PATH="$HOME/.volta/bin:$PATH"', migrated_text)
        self.assertTrue(any("auto-migrated legacy .zprofile" in note for note in result["notes"]))
        self.assert_symlink_to(home / ".zprofile", repo_root / "modules/core/home/.zprofile")

    def test_apply_does_not_overwrite_existing_local_zprofile_overlay(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".profile", "# managed profile\n")
        self.write_module_file(repo_root, "core", ".zprofile", "# managed zprofile\n")
        self.write_file(home / ".zprofile", 'export PATH="$HOME/.legacy/bin:$PATH"\n')
        existing_overlay = home / ".config/dotfiles/local.zprofile.sh"
        self.write_file(existing_overlay, "# keep me\n")

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        self.assertTrue(result["ok"])
        self.assertEqual(existing_overlay.read_text(encoding="utf-8"), "# keep me\n")
        self.assertTrue(
            any("skipped auto-migration because .config/dotfiles/local.zprofile.sh already exists" in note for note in result["notes"])
        )

    def test_apply_restores_legacy_zprofile_from_prior_backup_when_overlay_is_missing(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".profile", "# managed profile\n")
        self.write_module_file(repo_root, "core", ".zprofile", "# managed zprofile\n")
        self.write_file(home / ".zprofile", 'export PATH="$HOME/.volta/bin:$PATH"\n')

        self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        migrated = home / ".config/dotfiles/local.zprofile.sh"
        migrated.unlink()

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        self.assertTrue(result["ok"])
        self.assertTrue(migrated.exists(), "expected apply to recover local.zprofile.sh from backup history")
        self.assertIn('export PATH="$HOME/.volta/bin:$PATH"', migrated.read_text(encoding="utf-8"))

    def test_apply_restores_legacy_zprofile_from_checkout_backup_when_history_has_broken_symlink(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".profile", "# managed profile\n")
        self.write_module_file(repo_root, "core", ".zprofile", "# managed zprofile\n")

        backups_root = home / ".local/state/alohays-dotfiles/backups"
        target_backup_root = backups_root / "20260311T000000Z"
        checkout_backup_root = backups_root / "checkout-20260311T000000Z"
        target_backup = target_backup_root / "targets/.zprofile"
        target_backup.parent.mkdir(parents=True, exist_ok=True)
        target_backup.symlink_to(home / ".dotfiles/zsh/zprofile")
        self.write_file(
            target_backup_root / "metadata.json",
            json.dumps(
                {
                    "schema_version": 1,
                    "created_at": "2026-03-11T00:00:00Z",
                    "repo_root": str(home / ".dotfiles"),
                    "profile": "macos-desktop",
                    "entries": [
                        {
                            "target": ".zprofile",
                            "backup_path": "targets/.zprofile",
                            "original_kind": "symlink",
                            "replaced_by": "modules/core/home/.zprofile",
                        }
                    ],
                }
            ),
        )
        self.write_file(
            checkout_backup_root / "zsh/zprofile",
            'export PATH="$HOME/.volta/bin:$PATH"\n',
        )

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        migrated = home / ".config/dotfiles/local.zprofile.sh"
        self.assertTrue(result["ok"])
        self.assertTrue(migrated.exists(), "expected checkout backup recovery to recreate local.zprofile.sh")
        self.assertIn('export PATH="$HOME/.volta/bin:$PATH"', migrated.read_text(encoding="utf-8"))

    def test_apply_prefers_checkout_backup_over_current_repo_file_for_symlink_history(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".profile", "# managed profile\n")
        self.write_module_file(repo_root, "core", ".zprofile", '# managed wrapper\n. "$HOME/.dotfiles/zsh/zprofile"\n')

        backups_root = home / ".local/state/alohays-dotfiles/backups"
        target_backup_root = backups_root / "20260311T000000Z"
        checkout_backup_root = backups_root / "checkout-20260311T000000Z"
        target_backup = target_backup_root / "targets/.zprofile"
        target_backup.parent.mkdir(parents=True, exist_ok=True)
        target_backup.symlink_to(home / ".dotfiles/zsh/zprofile")
        self.write_file(
            target_backup_root / "metadata.json",
            json.dumps(
                {
                    "schema_version": 1,
                    "created_at": "2026-03-11T00:00:00Z",
                    "repo_root": str(home / ".dotfiles"),
                    "profile": "macos-desktop",
                    "entries": [
                        {
                            "target": ".zprofile",
                            "backup_path": "targets/.zprofile",
                            "original_kind": "symlink",
                            "replaced_by": "modules/core/home/.zprofile",
                        }
                    ],
                }
            ),
        )
        self.write_file(
            checkout_backup_root / "zsh/zprofile",
            'export PATH="$HOME/.volta/bin:$PATH"\n',
        )
        self.write_file(
            home / ".dotfiles/zsh/zprofile",
            '[ -r "$HOME/.profile" ] && . "$HOME/.profile"\n',
        )

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        migrated = home / ".config/dotfiles/local.zprofile.sh"
        self.assertTrue(result["ok"])
        self.assertTrue(migrated.exists())
        migrated_text = migrated.read_text(encoding="utf-8")
        self.assertIn('export PATH="$HOME/.volta/bin:$PATH"', migrated_text)
        self.assertNotIn('. "$HOME/.profile"', migrated_text)

    def test_plan_is_a_true_dry_run(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_file(repo_root / "modules/core/.zshrc", "export MANAGED=1\n")
        self.write_file(home / ".zshrc", "legacy config\n")

        result = self.run_cli(
            "plan",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        self.assertTrue(result["ok"])
        self.assertTrue(result["dry_run"])
        self.assertEqual((home / ".zshrc").read_text(encoding="utf-8"), "legacy config\n")
        self.assertFalse((home / STATE_PATH).exists())
        action_kinds = [action["kind"] for action in result["actions"]]
        self.assertIn("backup-and-link", action_kinds)

    def test_apply_removes_stale_managed_symlink_when_profile_changes(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_file(repo_root / "modules/core/.zshrc", "export MANAGED=1\n")
        self.write_file(repo_root / "modules/tmux/.tmux.conf", "set -g mouse on\n")
        self.write_file(repo_root / "modules/nvim/.config/nvim/init.lua", "vim.o.relativenumber = true\n")

        self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "linux-desktop",
        )
        self.assertTrue((home / ".tmux.conf").is_symlink())

        self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        self.assertFalse((home / ".tmux.conf").exists() or (home / ".tmux.conf").is_symlink())
        self.assertFalse((home / ".config/nvim/init.lua").exists() or (home / ".config/nvim/init.lua").is_symlink())
        inventory = json.loads((home / STATE_PATH).read_text(encoding="utf-8"))
        self.assertEqual([entry["target"] for entry in inventory["entries"]], [".zshrc"])

    def test_desktop_profiles_include_visual_module(self) -> None:
        manifest = self.script.load_manifest(REPO_ROOT)
        linux_desktop = self.script.resolve_profile(REPO_ROOT, manifest, "linux-desktop")
        macos_desktop = self.script.resolve_profile(REPO_ROOT, manifest, "macos-desktop")
        linux_desktop_rich = self.script.resolve_profile(REPO_ROOT, manifest, "linux-desktop-rich")
        macos_desktop_rich = self.script.resolve_profile(REPO_ROOT, manifest, "macos-desktop-rich")
        ssh_server = self.script.resolve_profile(REPO_ROOT, manifest, "ssh-server")

        self.assertEqual(linux_desktop["modules"], ["core", "tmux", "nvim", "visual"])
        self.assertEqual(macos_desktop["modules"], ["core", "tmux", "nvim", "visual"])
        self.assertEqual(
            linux_desktop_rich["modules"],
            ["core", "tmux", "nvim", "visual", "terminal", "prompt"],
        )
        self.assertEqual(
            macos_desktop_rich["modules"],
            ["core", "tmux", "nvim", "visual", "terminal", "prompt"],
        )
        self.assertEqual(ssh_server["modules"], ["core", "ssh-server", "tmux"])

    def test_apply_links_visual_theme_for_desktop_profile(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".zshrc", "export MANAGED=1\n")
        self.write_module_file(repo_root, "tmux", ".tmux.conf", "set -g status on\n")
        self.write_module_file(repo_root, "nvim", ".config/nvim/init.lua", "vim.o.number = true\n")
        self.write_module_file(
            repo_root,
            "visual",
            ".config/tmux/theme.conf",
            "set -g status-style fg=colour255,bg=colour235\n",
        )

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "linux-desktop",
        )

        self.assertTrue(result["ok"])
        self.assert_symlink_to(
            home / ".config/nvim/init.lua",
            repo_root / "modules/nvim/home/.config/nvim/init.lua",
        )
        self.assert_symlink_to(
            home / ".config/tmux/theme.conf",
            repo_root / "modules/visual/home/.config/tmux/theme.conf",
        )
        inventory = json.loads((home / STATE_PATH).read_text(encoding="utf-8"))
        self.assertIn(
            ".config/nvim/init.lua",
            [entry["target"] for entry in inventory["entries"]],
        )
        self.assertIn(
            ".config/tmux/theme.conf",
            [entry["target"] for entry in inventory["entries"]],
        )

    def test_apply_base_removes_visual_theme_symlink(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".zshrc", "export MANAGED=1\n")
        self.write_module_file(repo_root, "tmux", ".tmux.conf", "set -g status on\n")
        self.write_module_file(repo_root, "nvim", ".config/nvim/init.lua", "vim.o.number = true\n")
        self.write_module_file(
            repo_root,
            "visual",
            ".config/tmux/theme.conf",
            "set -g status-style fg=colour255,bg=colour235\n",
        )

        self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "linux-desktop",
        )
        self.assertTrue((home / ".config/nvim/init.lua").is_symlink())
        self.assertTrue((home / ".config/tmux/theme.conf").is_symlink())

        self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "base",
        )

        self.assertFalse((home / ".config/nvim/init.lua").exists())
        self.assertFalse((home / ".config/tmux/theme.conf").exists())
        inventory = json.loads((home / STATE_PATH).read_text(encoding="utf-8"))
        self.assertNotIn(
            ".config/nvim/init.lua",
            [entry["target"] for entry in inventory["entries"]],
        )
        self.assertNotIn(
            ".config/tmux/theme.conf",
            [entry["target"] for entry in inventory["entries"]],
        )

    def test_apply_ssh_server_does_not_link_visual_theme(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".zshrc", "export MANAGED=1\n")
        self.write_module_file(repo_root, "tmux", ".tmux.conf", "set -g status on\n")
        self.write_module_file(repo_root, "nvim", ".config/nvim/init.lua", "vim.o.number = true\n")
        self.write_module_file(
            repo_root,
            "visual",
            ".config/tmux/theme.conf",
            "set -g status-style fg=colour255,bg=colour235\n",
        )

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "ssh-server",
        )

        self.assertTrue(result["ok"])
        self.assert_symlink_to(home / ".tmux.conf", repo_root / "modules/tmux/home/.tmux.conf")
        self.assertFalse((home / ".config/nvim/init.lua").exists())
        self.assertFalse((home / ".config/tmux/theme.conf").exists())

    def test_apply_rich_profile_links_terminal_and_prompt_layers(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".zshrc", "export MANAGED=1\n")
        self.write_module_file(repo_root, "tmux", ".tmux.conf", "set -g status on\n")
        self.write_module_file(repo_root, "nvim", ".config/nvim/init.lua", "vim.o.number = true\n")
        self.write_module_file(repo_root, "visual", ".config/tmux/theme.conf", "set -g status on\n")
        self.write_module_file(
            repo_root,
            "terminal",
            ".config/wezterm/wezterm.lua",
            "return { term = 'wezterm' }\n",
        )
        self.write_module_file(
            repo_root,
            "terminal",
            ".config/alacritty/alacritty.toml",
            "[window]\npadding = { x = 1, y = 1 }\n",
        )
        self.write_module_file(
            repo_root,
            "prompt",
            ".config/dotfiles/interactive.d/80-prompt.sh",
            "case $- in *i*) ;; *) return 0 ;; esac\n",
        )

        result = self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "linux-desktop-rich",
        )

        self.assertTrue(result["ok"])
        self.assert_symlink_to(
            home / ".config/wezterm/wezterm.lua",
            repo_root / "modules/terminal/home/.config/wezterm/wezterm.lua",
        )
        self.assert_symlink_to(
            home / ".config/alacritty/alacritty.toml",
            repo_root / "modules/terminal/home/.config/alacritty/alacritty.toml",
        )
        self.assert_symlink_to(
            home / ".config/dotfiles/interactive.d/80-prompt.sh",
            repo_root / "modules/prompt/home/.config/dotfiles/interactive.d/80-prompt.sh",
        )
        inventory = json.loads((home / STATE_PATH).read_text(encoding="utf-8"))
        self.assertEqual(inventory["profile"], "linux-desktop-rich")
        self.assertIn(
            ".config/wezterm/wezterm.lua",
            [entry["target"] for entry in inventory["entries"]],
        )
        self.assertIn(
            ".config/alacritty/alacritty.toml",
            [entry["target"] for entry in inventory["entries"]],
        )
        self.assertIn(
            ".config/dotfiles/interactive.d/80-prompt.sh",
            [entry["target"] for entry in inventory["entries"]],
        )

    def test_apply_standard_desktop_after_rich_removes_terminal_and_prompt_layers(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_module_file(repo_root, "core", ".zshrc", "export MANAGED=1\n")
        self.write_module_file(repo_root, "tmux", ".tmux.conf", "set -g status on\n")
        self.write_module_file(repo_root, "nvim", ".config/nvim/init.lua", "vim.o.number = true\n")
        self.write_module_file(repo_root, "visual", ".config/tmux/theme.conf", "set -g status on\n")
        self.write_module_file(
            repo_root,
            "terminal",
            ".config/wezterm/wezterm.lua",
            "return { term = 'wezterm' }\n",
        )
        self.write_module_file(
            repo_root,
            "terminal",
            ".config/alacritty/alacritty.toml",
            "[window]\npadding = { x = 1, y = 1 }\n",
        )
        self.write_module_file(
            repo_root,
            "prompt",
            ".config/dotfiles/interactive.d/80-prompt.sh",
            "case $- in *i*) ;; *) return 0 ;; esac\n",
        )

        self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "linux-desktop-rich",
        )
        self.assertTrue((home / ".config/wezterm/wezterm.lua").is_symlink())
        self.assertTrue((home / ".config/alacritty/alacritty.toml").is_symlink())
        self.assertTrue((home / ".config/dotfiles/interactive.d/80-prompt.sh").is_symlink())

        self.run_cli(
            "apply",
            "--repo-root",
            str(repo_root),
            "--home",
            str(home),
            "--profile",
            "linux-desktop",
        )

        self.assertFalse((home / ".config/wezterm/wezterm.lua").exists())
        self.assertFalse((home / ".config/alacritty/alacritty.toml").exists())
        self.assertFalse((home / ".config/dotfiles/interactive.d/80-prompt.sh").exists())
        self.assertTrue((home / ".config/nvim/init.lua").is_symlink())
        self.assertTrue((home / ".config/tmux/theme.conf").is_symlink())


if __name__ == "__main__":
    unittest.main(verbosity=2)
