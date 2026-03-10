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
        self.assertEqual(resolved["modules"], ["core", "tmux", "visual"])
        self.assertEqual(resolved["lineage"], ["base", "linux-desktop"])

    def test_profiles_command_lists_shipped_profiles(self) -> None:
        result = self.run_cli("profiles", "--repo-root", str(REPO_ROOT))
        self.assertTrue(result["ok"])
        names = [profile["name"] for profile in result["profiles"]]
        self.assertEqual(names, ["base", "linux-desktop", "macos-desktop", "ssh-server"])

    def test_apply_creates_symlinks_and_inventory(self) -> None:
        repo_root = self.make_temp_repo()
        home = self.make_temp_dir()
        self.write_file(repo_root / "modules/core/.zshrc", "export TEST_PROFILE=1\n")
        self.write_file(repo_root / "modules/tmux/.tmux.conf", "set -g status on\n")

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
        inventory = json.loads((home / STATE_PATH).read_text(encoding="utf-8"))
        self.assertEqual(inventory["profile"], "linux-desktop")
        self.assertEqual([entry["target"] for entry in inventory["entries"]], [".tmux.conf", ".zshrc"])

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
        inventory = json.loads((home / STATE_PATH).read_text(encoding="utf-8"))
        self.assertEqual([entry["target"] for entry in inventory["entries"]], [".zshrc"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
