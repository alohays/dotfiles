from __future__ import annotations

import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "scripts" / "dotfiles.py"


def load_script_module():
    spec = importlib.util.spec_from_file_location("alohays_dotfiles_script", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load scripts/dotfiles.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload), encoding="utf-8")


class ResolveProfileRichUpgradeTests(unittest.TestCase):
    """Unit tests for the DOTFILES_PREFER_RICH upgrade logic in resolve_profile()."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.script = load_script_module()

    def setUp(self) -> None:
        self._tmp = Path(tempfile.mkdtemp(prefix="dotfiles-resolve-profile-"))
        self.addCleanup(lambda: shutil.rmtree(self._tmp, ignore_errors=True))
        self._build_repo(self._tmp)

    def _build_repo(self, root: Path) -> None:
        """Write a minimal repo layout with the profiles needed by the tests."""
        modules = [
            {"name": "core", "source_root": "modules/core"},
            {"name": "tmux", "source_root": "modules/tmux"},
            {"name": "nvim", "source_root": "modules/nvim"},
            {"name": "visual", "source_root": "modules/visual"},
            {"name": "terminal", "source_root": "modules/terminal"},
            {"name": "prompt", "source_root": "modules/prompt"},
            {"name": "ssh-server", "source_root": "modules/ssh-server"},
        ]
        manifest = {
            "schema_version": 1,
            "default_profiles": {
                "darwin": "macos-desktop",
                "linux": "linux-desktop",
                "ssh": "ssh-server",
            },
            "modules": modules,
        }
        _write_json(root / "manifests" / "manifest.json", manifest)

        profiles_dir = root / "profiles"
        _write_json(
            profiles_dir / "base.json",
            {"name": "base", "extends": [], "modules": ["core"]},
        )
        _write_json(
            profiles_dir / "macos-desktop.json",
            {
                "name": "macos-desktop",
                "extends": ["base"],
                "modules": ["tmux", "nvim", "visual"],
            },
        )
        _write_json(
            profiles_dir / "macos-desktop-rich.json",
            {
                "name": "macos-desktop-rich",
                "extends": ["macos-desktop"],
                "modules": ["terminal", "prompt"],
            },
        )
        _write_json(
            profiles_dir / "linux-desktop.json",
            {
                "name": "linux-desktop",
                "extends": ["base"],
                "modules": ["tmux", "nvim", "visual"],
            },
        )
        _write_json(
            profiles_dir / "linux-desktop-rich.json",
            {
                "name": "linux-desktop-rich",
                "extends": ["linux-desktop"],
                "modules": ["terminal", "prompt"],
            },
        )
        _write_json(
            profiles_dir / "ssh-server.json",
            {
                "name": "ssh-server",
                "extends": ["base"],
                "modules": ["ssh-server", "tmux"],
            },
        )

    def _resolve_clean(
        self,
        profile_name: str | None,
        *,
        prefer_rich: str = "0",
        platform_system: str = "Darwin",
        ssh_connection: str | None = None,
        display: str | None = None,
    ) -> dict:
        """Resolve a profile with a fully controlled environment."""
        patch_env: dict[str, str] = {"DOTFILES_PREFER_RICH": prefer_rich}
        remove_keys = {"SSH_CONNECTION", "SSH_TTY", "DISPLAY", "WAYLAND_DISPLAY"}

        if ssh_connection is not None:
            patch_env["SSH_CONNECTION"] = ssh_connection
            remove_keys.discard("SSH_CONNECTION")
        if display is not None:
            patch_env["DISPLAY"] = display
            remove_keys.discard("DISPLAY")

        manifest = self.script.load_manifest(self._tmp)

        import os as _os
        saved = {k: _os.environ.pop(k, None) for k in remove_keys}
        try:
            with mock.patch("platform.system", return_value=platform_system), \
                 mock.patch.dict(_os.environ, patch_env, clear=False):
                return self.script.resolve_profile(self._tmp, manifest, profile_name)
        finally:
            for k, v in saved.items():
                if v is not None:
                    _os.environ[k] = v

    def test_prefer_rich_darwin_resolves_macos_desktop_rich(self) -> None:
        result = self._resolve_clean(None, prefer_rich="1", platform_system="Darwin")
        self.assertEqual(result["name"], "macos-desktop-rich")

    def test_prefer_rich_linux_no_ssh_resolves_linux_desktop_rich(self) -> None:
        result = self._resolve_clean(None, prefer_rich="1", platform_system="Linux")
        self.assertEqual(result["name"], "linux-desktop-rich")

    def test_prefer_rich_ssh_headless_resolves_ssh_server_not_upgraded(self) -> None:
        result = self._resolve_clean(
            None,
            prefer_rich="1",
            platform_system="Linux",
            ssh_connection="10.0.0.1 22 10.0.0.2 54321",
        )
        self.assertEqual(result["name"], "ssh-server")

    def test_prefer_rich_explicit_profile_name_not_upgraded(self) -> None:
        result = self._resolve_clean("macos-desktop", prefer_rich="1", platform_system="Darwin")
        self.assertEqual(result["name"], "macos-desktop")

    def test_no_prefer_rich_does_not_upgrade(self) -> None:
        result = self._resolve_clean(None, prefer_rich="0", platform_system="Darwin")
        self.assertEqual(result["name"], "macos-desktop")

    def test_prefer_rich_missing_rich_profile_returns_base_profile(self) -> None:
        (self._tmp / "profiles" / "macos-desktop-rich.json").unlink()
        result = self._resolve_clean(None, prefer_rich="1", platform_system="Darwin")
        self.assertEqual(result["name"], "macos-desktop")


if __name__ == "__main__":
    unittest.main(verbosity=2)
