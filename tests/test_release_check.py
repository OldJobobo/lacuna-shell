import importlib.machinery
import importlib.util
import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "release-check"


def load_module():
    loader = importlib.machinery.SourceFileLoader("release_check", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    sys.modules[loader.name] = module
    loader.exec_module(module)
    return module


class ReleaseCheckTests(unittest.TestCase):
    def test_current_tree_has_consistent_release_authority(self):
        result = subprocess.run(
            [str(SCRIPT)],
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn((ROOT / "VERSION").read_text().strip(), result.stdout)

    def test_current_version_has_expected_publishability(self):
        module = load_module()
        version = (ROOT / "VERSION").read_text().strip()
        result = subprocess.run(
            [str(SCRIPT), "--publish", "--tag", f"v{version}"],
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )
        if module.load_release_version().is_publishable(version):
            self.assertEqual(0, result.returncode, result.stderr)
        else:
            self.assertNotEqual(0, result.returncode)
            self.assertIn("development version and cannot be published", result.stderr)

    def test_branch_ci_ref_is_not_treated_as_a_release_tag(self):
        env = dict(os.environ)
        env.update({"GITHUB_REF_TYPE": "branch", "GITHUB_REF_NAME": "master"})
        result = subprocess.run(
            [str(SCRIPT)],
            cwd=ROOT,
            env=env,
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)

    def test_changelog_section_is_bounded_to_one_release(self):
        module = load_module()
        text = (
            "# Changelog\n\n## [Unreleased]\n\n"
            "## [1.2.3] - 2026-01-02\n\n- Fixed A.\n\n"
            "## [1.2.2] - 2026-01-01\n\n- Fixed B.\n"
        )
        section = module.changelog_section(text, "1.2.3")
        self.assertIn("Fixed A", section)
        self.assertNotIn("Fixed B", section)
        self.assertEqual(
            "1.2.3", module.latest_published_version(text, module.load_release_version())
        )

    def test_publish_mode_rejects_development_version(self):
        module = load_module()
        release_version = module.load_release_version()
        self.assertFalse(release_version.is_publishable("0.1.0-beta.5.dev.0"))
        self.assertFalse(release_version.is_publishable("0.2.0-alpha.0"))


if __name__ == "__main__":
    unittest.main()
