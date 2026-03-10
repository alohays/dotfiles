from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SMOKE_SCRIPT = REPO_ROOT / "tests" / "install_smoke.sh"


class InstallSmokeTests(unittest.TestCase):
    def run_smoke(self, scenario: str) -> None:
        completed = subprocess.run(
            ["sh", str(SMOKE_SCRIPT), scenario],
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            completed.returncode,
            0,
            msg=(
                f"smoke scenario {scenario!r} failed\n"
                f"stdout:\n{completed.stdout}\n"
                f"stderr:\n{completed.stderr}"
            ),
        )

    def test_fresh_install_smoke(self) -> None:
        self.run_smoke("fresh")

    def test_replace_existing_smoke(self) -> None:
        self.run_smoke("replace-existing")


if __name__ == "__main__":
    unittest.main(verbosity=2)
