import argparse
import importlib.machinery
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "scripts" / "dev"


def run_dev(args, config_home=None):
    if config_home is None:
        with tempfile.TemporaryDirectory() as tmp:
            return run_dev(args, config_home=Path(tmp) / "config")

    env = os.environ.copy()
    env["XDG_CONFIG_HOME"] = str(config_home)
    env["LACUNA_OMARCHY_CONFIG_HOME"] = str(config_home)
    return subprocess.run(
        [str(DEV), *args],
        check=True,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def load_dev_module():
    loader = importlib.machinery.SourceFileLoader("lacuna_dev_tool", str(DEV))
    spec = importlib.util.spec_from_loader("lacuna_dev_tool", loader)
    module = importlib.util.module_from_spec(spec)
    sys.modules["lacuna_dev_tool"] = module
    spec.loader.exec_module(module)
    return module


class DevToolTests(unittest.TestCase):
    def test_rescan_command_is_non_quiet_for_transaction_failures(self):
        module = load_dev_module()

        self.assertEqual(
            module.PLUGIN_RESCAN_COMMAND,
            ["omarchy", "shell", "shell", "rescanPlugins"],
        )
        self.assertNotIn("-q", module.PLUGIN_RESCAN_COMMAND)

    def test_omarchy_host_paths_ignore_custom_xdg_config_home(self):
        module = load_dev_module()

        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            xdg_config = Path(tmp) / "xdg-config"
            with mock.patch.dict(
                module.os.environ,
                {"HOME": str(home), "XDG_CONFIG_HOME": str(xdg_config)},
                clear=True,
            ):
                self.assertEqual(module.config_home(), xdg_config)
                self.assertEqual(module.omarchy_config_home(), home / ".config")
                self.assertEqual(module.plugins_dir(), home / ".config/omarchy/plugins")

    def test_deploy_dry_run_restarts_and_verifies_plugin(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            installed = config_home / "omarchy" / "plugins" / "lacuna.menu"
            installed.mkdir(parents=True)
            (installed / "manifest.json").write_text('{"id":"lacuna.menu","version":"old"}\n', encoding="utf-8")

            result = run_dev(["deploy", "lacuna.menu", "--dry-run"], config_home=config_home)

        self.assertIn("Dev deploy plan", result.stdout)
        self.assertIn("deploy lacuna.menu ->", result.stdout)
        self.assertIn("omarchy shell shell rescanPlugins", result.stdout)
        self.assertIn("omarchy restart shell", result.stdout)
        self.assertIn("verify installed plugin files match this checkout", result.stdout)

    def test_deploy_copies_repo_plugin_and_verifies_installed_copy(self):
        module = load_dev_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            installed = config_home / "omarchy" / "plugins" / "lacuna.clock"
            installed.mkdir(parents=True)
            (installed / "manifest.json").write_text('{"id":"lacuna.clock","version":"old"}\n', encoding="utf-8")
            args = argparse.Namespace(
                plugins=["lacuna.clock"],
                all=False,
                dry_run=False,
                only_changed=False,
                restart_shell=True,
            )

            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "validate_plugin", return_value=0), \
                mock.patch.object(module, "run_command", return_value=0) as run_command:
                result = module.deploy(args)
                matches, issues = module.installed_matches_source("lacuna.clock")

        self.assertEqual(result, 0)
        self.assertTrue(matches, issues)
        self.assertEqual(
            [call.args[0] for call in run_command.call_args_list],
            [["omarchy", "shell", "shell", "rescanPlugins"], ["omarchy", "restart", "shell"]],
        )

    def test_cleanup_backups_migrates_exact_legacy_names_and_prunes_per_plugin(self):
        module = load_dev_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            plugins = config_home / "omarchy" / "plugins"
            plugins.mkdir(parents=True)
            for index in range(4):
                backup = plugins / f".lacuna.clock.bak.2026010100000{index}"
                backup.mkdir()
                os.utime(backup, (index, index))
            unrelated = plugins / ".lacuna.clock.manualbak.20260101000009"
            unrelated.mkdir()

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}):
                migrated, removed = module.cleanup_plugin_backups(keep=2)
                archive = module.plugin_backup_dir()

            retained = sorted(path.name for path in archive.iterdir())
            registry_names = sorted(path.name for path in plugins.iterdir())

        self.assertEqual((migrated, removed), (2, 2))
        self.assertEqual(retained, [".lacuna.clock.bak.20260101000002", ".lacuna.clock.bak.20260101000003"])
        self.assertEqual(registry_names, [".lacuna.clock.manualbak.20260101000009"])

    def test_cleanup_backups_dry_run_is_immutable(self):
        module = load_dev_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            plugins = config_home / "omarchy" / "plugins"
            legacy = plugins / ".lacuna.menu.bak.20260101000000"
            legacy.mkdir(parents=True)

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}):
                migrated, removed = module.cleanup_plugin_backups(keep=1, dry_run=True)
                archive = module.plugin_backup_dir()

            self.assertTrue(legacy.is_dir())
            self.assertFalse(archive.exists())

        self.assertEqual((migrated, removed), (1, 0))

    def test_cleanup_backups_handles_broken_symlinks(self):
        module = load_dev_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            plugins = config_home / "omarchy" / "plugins"
            plugins.mkdir(parents=True)
            legacy = plugins / ".lacuna.menu.bak.20260101000000"
            legacy.symlink_to("missing-target")

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}):
                migrated, removed = module.cleanup_plugin_backups(keep=1)
                archived = module.plugin_backup_dir() / legacy.name

            self.assertEqual((migrated, removed), (1, 0))
            self.assertTrue(archived.is_symlink())
            self.assertFalse(legacy.is_symlink())

    def test_cleanup_backups_retains_unique_names_and_prefers_archive_copy(self):
        module = load_dev_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            plugins = config_home / "omarchy" / "plugins"
            archive = config_home / "omarchy" / "lacuna" / "backups" / "plugins"
            plugins.mkdir(parents=True)
            archive.mkdir(parents=True)
            duplicate_name = ".lacuna.clock.bak.20260101000001"
            (plugins / duplicate_name).mkdir()
            (archive / duplicate_name).mkdir()
            newer = plugins / ".lacuna.clock.bak.20260101000002"
            newer.write_text("newer", encoding="utf-8")
            other = plugins / ".lacuna.menu.bak.20260101000003-2"
            other.symlink_to("missing")

            # Payload mtimes deliberately oppose filename chronology.
            os.utime(newer, (1, 1))
            os.utime(archive / duplicate_name, (999, 999))
            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}):
                migrated, removed = module.cleanup_plugin_backups(keep=2)

            self.assertEqual((migrated, removed), (2, 1))
            self.assertTrue((archive / duplicate_name).is_dir())
            self.assertFalse((plugins / duplicate_name).exists())
            self.assertEqual((archive / newer.name).read_text(encoding="utf-8"), "newer")
            self.assertTrue((archive / other.name).is_symlink())

    def test_operation_lock_rejects_concurrent_nonblocking_mutation(self):
        module = load_dev_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}):
                with module.operation_lock():
                    with self.assertRaisesRegex(RuntimeError, "Another Lacuna dev operation"):
                        with module.operation_lock(blocking=False):
                            pass

    def test_backup_target_uses_lacuna_runtime_archive(self):
        module = load_dev_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            target = config_home / "omarchy" / "plugins" / "lacuna.clock"
            target.mkdir(parents=True)
            (target / "manifest.json").write_text("{}", encoding="utf-8")

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}):
                backup = module.backup_target(target)
                archive = module.plugin_backup_dir()

            self.assertIsNotNone(backup)
            self.assertEqual(backup.parent, archive)
            self.assertFalse(target.exists())
            self.assertTrue((backup / "manifest.json").is_file())

    def test_failed_rescan_restores_previous_deployed_copy(self):
        module = load_dev_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            installed = config_home / "omarchy" / "plugins" / "lacuna.clock"
            installed.mkdir(parents=True)
            (installed / "manifest.json").write_text('{"id":"lacuna.clock","old":true}\n', encoding="utf-8")
            # Reproduce the former retention bug: the installed directory has
            # an old mtime while pre-existing backups look newer by mtime.
            os.utime(installed, (1, 1))
            archive = config_home / "omarchy" / "lacuna" / "backups" / "plugins"
            archive.mkdir(parents=True)
            for index in (1, 2):
                backup = archive / f".lacuna.clock.bak.2025010100000{index}"
                backup.mkdir()
                os.utime(backup, (100 + index, 100 + index))
            args = argparse.Namespace(
                plugins=["lacuna.clock"],
                all=False,
                dry_run=False,
                only_changed=False,
                restart_shell=True,
            )

            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "validate_plugin", return_value=0), \
                mock.patch.object(module, "run_command", side_effect=[7, 0]) as run_command:
                result = module.deploy(args)
                restored = (installed / "manifest.json").read_text(encoding="utf-8")

        self.assertEqual(7, result)
        self.assertIn('"old":true', restored)
        self.assertEqual(
            [
                ["omarchy", "shell", "shell", "rescanPlugins"],
                ["omarchy", "shell", "shell", "rescanPlugins"],
            ],
            [item.args[0] for item in run_command.call_args_list],
        )


if __name__ == "__main__":
    unittest.main()
