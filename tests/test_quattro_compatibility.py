import importlib.machinery
import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "quattro-compatibility"


def load_module():
    loader = importlib.machinery.SourceFileLoader("quattro_compatibility", str(SCRIPT))
    spec = importlib.util.spec_from_loader("quattro_compatibility", loader)
    module = importlib.util.module_from_spec(spec)
    sys.modules["quattro_compatibility"] = module
    spec.loader.exec_module(module)
    return module


class QuattroCompatibilityTests(unittest.TestCase):
    def test_repo_only_report_is_deterministic_and_checkable(self):
        module = load_module()

        result = module.report(repo_only=True)

        self.assertEqual("declared", result["status"])
        self.assertEqual("unknown", result["omarchyVersion"])
        self.assertEqual("unknown", result["quickshellVersion"])
        self.assertIsNone(result["vendoredParity"])
        self.assertEqual([], result["upstreamReviewRequired"])
        self.assertEqual([], result["hostVersionReviewRequired"])
        self.assertTrue(all(state == "skipped" for state in result["corePluginValidation"].values()))
        self.assertRegex(result["reviewedQuickshellVersion"], r"^0\.3\.0")
        self.assertTrue(any(row["suiteVersion"] == (ROOT / "VERSION").read_text().strip() for row in result["releaseTests"]))

    def test_json_cli_exposes_explicit_live_result(self):
        result = subprocess.run(
            [str(SCRIPT), "--json"],
            cwd=ROOT,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        self.assertEqual(0, result.returncode, result.stderr)
        report = json.loads(result.stdout)
        self.assertIn(report["status"], {"compatible", "unknown", "review-required", "incompatible"})
        self.assertIn("upstreamBarFiles", report)
        self.assertIn("shell.qml", report["upstreamBarFiles"])
        self.assertIn("Ui/BarWidget.qml", report["upstreamBarFiles"])
        self.assertRegex(report["reviewedOmarchyCommit"], r"^[0-9a-f]{40}$")
        self.assertIn("upstreamReviewRequired", report)
        self.assertIn("hostVersionReviewRequired", report)
        self.assertIn("lacuna.bar", report["corePluginValidation"])

    def test_unreviewed_quickshell_version_is_reported(self):
        module = load_module()
        review = json.loads(module.REVIEW_FILE.read_text(encoding="utf-8"))
        with mock.patch.object(
            module,
            "package_version",
            side_effect=lambda name: review["reviewedOmarchyVersion"] if name == "omarchy" else "9.9.9",
        ):
            result = module.report(repo_only=False)
        self.assertIn("Quickshell", result["hostVersionReviewRequired"])

    def test_changed_reviewed_upstream_hash_requires_review(self):
        module = load_module()
        original = module.REVIEW_FILE
        try:
            module.REVIEW_FILE = ROOT / "tests/fixtures/quattro-compatibility-mismatch.json"
            result = module.report(repo_only=False)
        finally:
            module.REVIEW_FILE = original

        self.assertIn(result["status"], {"review-required", "incompatible"})
        self.assertIn("Bar.qml", result["upstreamReviewRequired"])


if __name__ == "__main__":
    unittest.main()
