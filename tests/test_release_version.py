import importlib.machinery
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/release-version"


def load_module():
    loader = importlib.machinery.SourceFileLoader("release_version", str(SCRIPT))
    spec = importlib.util.spec_from_loader("release_version", loader)
    module = importlib.util.module_from_spec(spec)
    sys.modules["release_version"] = module
    loader.exec_module(module)
    return module


class ReleaseVersionTests(unittest.TestCase):
    def test_supported_versions_map_to_arch_versions_and_publishability(self):
        module = load_module()
        cases = {
            "0.1.0-beta.12": "0.1.0beta.12",
            "0.1.0-beta.12.dev.0": "0.1.0beta.12.dev.0",
            "0.1.0-rc.2": "0.1.0rc.2",
            "0.1.0-rc.2.dev.0": "0.1.0rc.2.dev.0",
            "0.2.0-alpha.0": "0.2.0alpha.0",
            "0.1.0": "0.1.0",
            "0.1.1": "0.1.1",
        }
        for version, expected in cases.items():
            with self.subTest(version=version):
                self.assertEqual(expected, module.arch_version(version))

        for version in ["0.1.0-beta.12", "0.1.0-rc.2", "0.1.0", "0.1.1"]:
            self.assertTrue(module.is_publishable(version), version)
        for version in ["0.1.0-beta.12.dev.0", "0.1.0-rc.2.dev.0", "0.2.0-alpha.0"]:
            self.assertFalse(module.is_publishable(version), version)

        self.assertLess(module.version_key("0.1.0-beta.5"), module.version_key("0.1.0-beta.5.dev.0"))
        self.assertLess(module.version_key("0.1.0-beta.5.dev.0"), module.version_key("0.1.0-beta.6"))
        self.assertLess(module.version_key("0.1.0-rc.1"), module.version_key("0.1.0"))

        for invalid in [
            "0.1",
            "0.1.0-dev.1",
            "0.1.0-alpha.1.dev.0",
            "0.1.0+build",
            "v0.1.0",
            "01.1.0",
            "0.01.0",
            "0.1.00",
            "0.1.0-beta.01",
        ]:
            with self.assertRaises(ValueError):
                module.arch_version(invalid)

    def test_version_bump_resets_checksum_and_pkgrel(self):
        module = load_module()
        content = "_upstream_version=0.1.0\n_source_sha256=deadbeef\npkgrel=4\n"
        updated = module.updated_pkgbuild(content, "0.2.0-rc.1")
        self.assertIn("_upstream_version=0.2.0-rc.1", updated)
        self.assertIn("_source_sha256=SKIP", updated)
        self.assertIn("pkgrel=1", updated)

    def test_failed_update_restores_every_metadata_file(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            version_file = root / "VERSION"
            manifest = root / "lacuna.test" / "manifest.json"
            supplemental_version = root / "lacuna.test" / "VERSION"
            pkgbuild = root / "PKGBUILD"
            srcinfo = root / ".SRCINFO"
            manifest.parent.mkdir()
            version_file.write_text("0.1.0\n", encoding="utf-8")
            manifest.write_text('{"id":"lacuna.test","version":"0.1.0"}\n', encoding="utf-8")
            supplemental_version.write_text("0.1.0\n", encoding="utf-8")
            pkgbuild.write_text("_upstream_version=0.1.0\n_source_sha256=SKIP\npkgrel=1\n", encoding="utf-8")
            srcinfo.write_text("pkgver = 0.1.0\n", encoding="utf-8")
            files = [version_file, manifest, supplemental_version, pkgbuild, srcinfo]
            before = {path: path.read_bytes() for path in files}
            with (
                mock.patch.object(module, "ROOT", root),
                mock.patch.object(module, "VERSION_FILE", version_file),
                mock.patch.object(module, "PKGBUILD", pkgbuild),
                mock.patch.object(module, "SRCINFO", srcinfo),
                mock.patch.object(module, "manifest_paths", return_value=[manifest]),
                mock.patch.object(module, "supplemental_version_paths", return_value=[supplemental_version]),
                mock.patch.object(module.json, "dumps", side_effect=RuntimeError("injected")),
            ):
                self.assertEqual(module.set_version("0.2.0", False), 1)
            self.assertEqual(before, {path: path.read_bytes() for path in files})

    def test_check_and_dry_run_do_not_change_metadata(self):
        before = subprocess.run(["git", "diff", "--", "VERSION", "lacuna.*", "packaging/aur"], cwd=ROOT, text=True, stdout=subprocess.PIPE, check=True).stdout
        check = subprocess.run([str(SCRIPT), "check"], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        dry_run = subprocess.run([str(SCRIPT), "set", "0.1.0-beta.1", "--dry-run"], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        after = subprocess.run(["git", "diff", "--", "VERSION", "lacuna.*", "packaging/aur"], cwd=ROOT, text=True, stdout=subprocess.PIPE, check=True).stdout
        self.assertEqual(check.returncode, 0, check.stderr)
        self.assertEqual(dry_run.returncode, 0, dry_run.stderr)
        self.assertIn("update packaging/aur/.SRCINFO", dry_run.stdout)
        self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
