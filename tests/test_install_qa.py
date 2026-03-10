from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
QA_SCRIPT = REPO_ROOT / "tests" / "install_qa.sh"


class InstallQaTests(unittest.TestCase):
    def run_qa(self, scenario: str) -> None:
        completed = subprocess.run(
            ["sh", str(QA_SCRIPT), scenario],
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            completed.returncode,
            0,
            msg=(
                f"QA scenario {scenario!r} failed\n"
                f"stdout:\n{completed.stdout}\n"
                f"stderr:\n{completed.stderr}"
            ),
        )

    def test_end_to_end_flows(self) -> None:
        self.run_qa("flows")

    def test_replace_dirty_checkout(self) -> None:
        self.run_qa("replace-dirty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
