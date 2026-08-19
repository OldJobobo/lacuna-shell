import importlib.machinery
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / "config/release-inventory.json"


class ReleaseInventoryTests(unittest.TestCase):
    def test_checked_inventory_is_current_and_complete(self):
        result = subprocess.run(
            [str(ROOT / "scripts/release-inventory"), "--check"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(INVENTORY.read_text(encoding="utf-8"))
        manifest_ids = {
            json.loads(path.read_text(encoding="utf-8"))["id"]
            for path in ROOT.glob("lacuna.*/manifest.json")
        }
        inventory_ids = {plugin["id"] for plugin in data["plugins"]}
        self.assertEqual(manifest_ids, inventory_ids)
        manifest_stability = {
            json.loads(path.read_text(encoding="utf-8"))["id"]: json.loads(path.read_text(encoding="utf-8"))["lacuna"]["stability"]
            for path in ROOT.glob("lacuna.*/manifest.json")
        }
        inventory_stability = {plugin["id"]: plugin["stability"] for plugin in data["plugins"]}
        self.assertEqual(manifest_stability, inventory_stability)
        self.assertTrue(set(inventory_stability.values()) <= {"stable", "beta", "experimental", "deprecated"})
        self.assertEqual(data["package"]["requiredPackages"], ["omarchy", "quickshell", "python", "qt6-multimedia"])
        self.assertIn("omakase-profile.json", data["package"]["configFiles"])

    def test_generator_accepts_stable_and_rejects_missing_or_invalid_stability(self):
        loader = importlib.machinery.SourceFileLoader("release_inventory_test", str(ROOT / "scripts/release-inventory"))
        spec = importlib.util.spec_from_loader("release_inventory_test", loader)
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        loader.exec_module(module)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plugin_dir = root / "lacuna.fake"
            plugin_dir.mkdir()
            (plugin_dir / "manifest.json").write_text(
                json.dumps({"id": "lacuna.fake", "lacuna": {"stability": "stable"}}),
                encoding="utf-8",
            )
            with (
                mock.patch.object(module, "ROOT", root),
                mock.patch.object(module, "payload_files", return_value=["manifest.json"]),
            ):
                generated = module.generate()
            self.assertEqual("stable", generated["plugins"][0]["stability"])

        for stability in (None, "preview"):
            with self.subTest(stability=stability), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                plugin_dir = root / "lacuna.fake"
                plugin_dir.mkdir()
                manifest = {"id": "lacuna.fake", "lacuna": {}}
                if stability is not None:
                    manifest["lacuna"]["stability"] = stability
                (plugin_dir / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
                with mock.patch.object(module, "ROOT", root):
                    with self.assertRaises(SystemExit):
                        module.generate()

    def test_inventory_entry_points_and_files_exist(self):
        data = json.loads(INVENTORY.read_text(encoding="utf-8"))
        for plugin in data["plugins"]:
            plugin_dir = ROOT / plugin["id"]
            self.assertIn("manifest.json", plugin["files"])
            for relative in plugin["entryPoints"].values():
                self.assertTrue((plugin_dir / relative).is_file(), f"{plugin['id']}: {relative}")
            for relative in plugin["files"]:
                self.assertTrue((plugin_dir / relative).is_file(), f"{plugin['id']}: {relative}")


if __name__ == "__main__":
    unittest.main()
