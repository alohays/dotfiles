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
        return Path(tempfile.mkdtemp(prefix="dotfiles-bin-test-"))

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
