import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRY_POINT_BY_KIND = {
    "bar": "bar",
    "bar-widget": "barWidget",
    "menu": "menu",
    "overlay": "overlay",
    "panel": "panel",
    "service": "service",
}
LACUNA_BUNDLES = {"standalone", "core", "theme", "ambience", "legacy"}
LACUNA_STABILITIES = {"stable", "beta", "experimental", "deprecated"}
SUITE_VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()


def manifest_paths():
    return sorted(ROOT.glob("lacuna.*/manifest.json"))


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


class ManifestContractTests(unittest.TestCase):
    def test_manifest_ids_match_directory_names(self):
        for path in manifest_paths():
            manifest = read_json(path)
            self.assertEqual(path.parent.name, manifest.get("id"), str(path))

    def test_kinds_have_required_entry_points(self):
        for path in manifest_paths():
            manifest = read_json(path)
            entry_points = manifest.get("entryPoints")
            self.assertIsInstance(entry_points, dict, str(path))

            for kind in manifest.get("kinds", []):
                key = ENTRY_POINT_BY_KIND.get(kind)
                self.assertIsNotNone(key, f"{path}: unknown kind {kind}")
                self.assertIn(key, entry_points, f"{path}: missing entryPoints.{key}")
                self.assertTrue((path.parent / entry_points[key]).exists(), f"{path}: missing {entry_points[key]}")

    def test_lacuna_metadata_references_existing_plugins(self):
        plugin_ids = {read_json(path)["id"] for path in manifest_paths()}

        for path in manifest_paths():
            manifest = read_json(path)
            meta = manifest.get("lacuna")
            self.assertIsInstance(meta, dict, str(path))
            self.assertIsInstance(meta.get("standalone"), bool, str(path))
            self.assertIn(meta.get("bundle"), LACUNA_BUNDLES, str(path))

            for key in ("requires", "recommends"):
                self.assertIsInstance(meta.get(key), list, f"{path}: lacuna.{key}")
                for plugin_id in meta[key]:
                    self.assertIn(plugin_id, plugin_ids, f"{path}: unknown lacuna.{key} {plugin_id}")

    def test_manifest_stability_is_explicit_and_independent_from_suite_channel(self):
        for path in manifest_paths():
            manifest = read_json(path)
            stability = manifest.get("lacuna", {}).get("stability")
            self.assertIn(stability, LACUNA_STABILITIES, str(path))
            if manifest["id"] == "lacuna.script-pill":
                self.assertEqual("experimental", stability, str(path))
            elif manifest["id"] == "lacuna.compact-pill":
                self.assertEqual("deprecated", stability, str(path))
            else:
                self.assertIn(stability, {"beta", "stable"}, str(path))

    def test_workspace_active_only_setting_defaults_to_false(self):
        manifest = read_json(ROOT / "lacuna.workspaces" / "manifest.json")
        widget = manifest["barWidget"]
        schema = {field["key"]: field for field in widget["schema"]}

        self.assertIs(widget["defaults"]["activeWorkspaceOnly"], False)
        self.assertEqual("boolean", schema["activeWorkspaceOnly"]["type"])
        self.assertIs(schema["activeWorkspaceOnly"]["defaultValue"], False)

    def test_manifest_versions_match_suite_version(self):
        self.assertRegex(
            SUITE_VERSION,
            r"^\d+\.\d+\.\d+(?:-(?:(?:alpha|beta|rc)\.\d+|(?:beta|rc)\.\d+\.dev\.0))?$",
        )
        for path in manifest_paths():
            manifest = read_json(path)
            self.assertEqual(SUITE_VERSION, manifest.get("version"), str(path))


if __name__ == "__main__":
    unittest.main()
