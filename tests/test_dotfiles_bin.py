from __future__ import annotations

import subprocess
import tempfile
import unittest
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DOTFILES_BIN = REPO_ROOT / "bin" / "dotfiles"


class DotfilesBinTests(unittest.TestCase):
    def make_temp_dir(self) -> Path:
        return Path(tempfile.mkdtemp(prefix="dotfiles-bin-test-")).resolve()

    def test_symlinked_launcher_resolves_repo_root(self) -> None:
        home = self.make_temp_dir()
        launcher_dir = home / ".local" / "bin"
        launcher_dir.mkdir(parents=True)
        launcher = launcher_dir / "dotfiles"
        launcher.symlink_to(DOTFILES_BIN)

        completed = subprocess.run(
            [str(launcher), "help"],
            capture_output=True,
            text=True,
        )

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"symlinked launcher failed\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn(f"Usage: {launcher} [global-options] <command> [command-args]", completed.stdout)

    def test_relative_symlinked_launcher_resolves_repo_root(self) -> None:
        home = self.make_temp_dir()
        launcher_dir = home / ".local" / "bin"
        launcher_dir.mkdir(parents=True)
        launcher = launcher_dir / "dotfiles"
        relative_target = Path(os.path.relpath(DOTFILES_BIN, launcher_dir))
        launcher.symlink_to(relative_target)

        completed = subprocess.run(
            [str(launcher), "help"],
            capture_output=True,
            text=True,
        )

        self.assertEqual(
            completed.returncode,
            0,
            msg=(
                "relative symlinked launcher failed\n"
                f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
            ),
        )
        self.assertIn(f"Usage: {launcher} [global-options] <command> [command-args]", completed.stdout)


class YoloFlagTests(unittest.TestCase):
    def run_bin(self, *args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        base_env = {**os.environ, "NO_COLOR": "1"}
        if env:
            base_env.update(env)
        return subprocess.run(
            [str(DOTFILES_BIN), *args],
            capture_output=True,
            text=True,
            env=base_env,
        )

    def test_yolo_in_help(self) -> None:
        completed = self.run_bin("--help")

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"--help failed\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn("--yolo", completed.stdout)

    def test_yolo_dry_run_all_phases(self) -> None:
        completed = self.run_bin("--yolo", "--dry-run", "install")

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"--yolo --dry-run install failed\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn("ALL agent tools", completed.stdout)
        self.assertIn("ALL packages", completed.stdout)

    def test_yolo_skip_tools_wins(self) -> None:
        completed = self.run_bin("--yolo", "--skip-tools", "--dry-run", "install")

        self.assertEqual(
            completed.returncode,
            0,
            msg=(
                "--yolo --skip-tools --dry-run install failed\n"
                f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
            ),
        )
        self.assertIn("agent tools (--skip-tools)", completed.stdout)
        self.assertNotIn("ALL agent tools", completed.stdout)

    def test_yolo_after_install_subcommand(self) -> None:
        completed = self.run_bin("install", "--yolo", "--dry-run")

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"install --yolo --dry-run failed\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn("ALL agent tools", completed.stdout)
        self.assertIn("ALL packages", completed.stdout)

    def test_yolo_after_update_subcommand(self) -> None:
        completed = self.run_bin(
            "update", "--yolo", "--dry-run",
            env={"DOTFILES_CHECKOUT_ALREADY_UPDATED": "1"},
        )

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"update --yolo --dry-run failed\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn("ALL agent tools", completed.stdout)
        self.assertIn("ALL packages", completed.stdout)

    def test_yolo_skip_tools_after_install(self) -> None:
        completed = self.run_bin("install", "--yolo", "--skip-tools", "--dry-run")

        self.assertEqual(
            completed.returncode,
            0,
            msg=(
                "install --yolo --skip-tools --dry-run failed\n"
                f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
            ),
        )
        self.assertIn("agent tools (--skip-tools)", completed.stdout)
        self.assertNotIn("ALL agent tools", completed.stdout)
        self.assertIn("ALL packages", completed.stdout)

    def test_yolo_fast_after_update(self) -> None:
        completed = self.run_bin(
            "update", "--fast", "--yolo", "--dry-run",
            env={"DOTFILES_CHECKOUT_ALREADY_UPDATED": "1"},
        )

        self.assertEqual(
            completed.returncode,
            0,
            msg=(
                "update --fast --yolo --dry-run failed\n"
                f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
            ),
        )
        self.assertIn("agent tools (--skip-tools)", completed.stdout)
        self.assertNotIn("ALL agent tools", completed.stdout)
        self.assertIn("ALL packages", completed.stdout)

    def test_yolo_skip_apply(self) -> None:
        completed = self.run_bin("--yolo", "--skip-apply", "--dry-run", "install")

        self.assertEqual(
            completed.returncode,
            0,
            msg=(
                "--yolo --skip-apply --dry-run install failed\n"
                f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
            ),
        )
        self.assertIn("ALL agent tools", completed.stdout)
        self.assertIn("ALL packages", completed.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
