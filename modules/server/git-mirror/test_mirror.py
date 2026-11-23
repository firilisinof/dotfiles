import subprocess
import tempfile
import unittest
from pathlib import Path

from mirror import remove_undeclared


class MirrorCleanupTest(unittest.TestCase):
    def test_cleanup_preserves_packed_mirror_and_removes_obsolete_parents(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mirror = root / "host" / "owner" / "kept.git"
            subprocess.run(["git", "init", "--bare", "-q", str(mirror)], check=True)
            tree = (
                subprocess.check_output(["git", "-C", str(mirror), "mktree"], input=b"")
                .decode()
                .strip()
            )
            for args in (
                ["update-ref", "refs/tags/test", tree],
                ["pack-refs", "--all"],
            ):
                subprocess.run(["git", "-C", str(mirror), *args], check=True)

            obsolete = root / "host" / "old-owner"
            (obsolete / "old.git").mkdir(parents=True)
            (obsolete / "partial.git.tmp").mkdir()
            for _ in range(2):
                remove_undeclared(root, {mirror})
                result = subprocess.check_output(
                    ["git", "-C", str(mirror), "rev-parse", "refs/tags/test"], text=True
                )
                self.assertEqual(result.strip(), tree)
                self.assertFalse(obsolete.exists())
