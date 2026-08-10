import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts" / "lacuna"


def run_lacuna(args, config_home=None):
    if config_home is None:
        with tempfile.TemporaryDirectory() as tmp:
            return run_lacuna(args, config_home=Path(tmp) / "config")

    env = os.environ.copy()
    env["XDG_CONFIG_HOME"] = str(config_home)
    env["LACUNA_OMARCHY_CONFIG_HOME"] = str(config_home)
    return subprocess.run(
        [str(INSTALLER), *args],
        check=True,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def run_lacuna_unchecked(args, config_home=None):
    if config_home is None:
        with tempfile.TemporaryDirectory() as tmp:
            return run_lacuna_unchecked(args, config_home=Path(tmp) / "config")

    env = os.environ.copy()
    env["XDG_CONFIG_HOME"] = str(config_home)
    env["LACUNA_OMARCHY_CONFIG_HOME"] = str(config_home)
    return subprocess.run(
        [str(INSTALLER), *args],
        check=False,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


OMAKASE_PLUGIN_IDS = {
    "lacuna.ambience-host",
    "lacuna.audio",
    "lacuna.aurora-drift",
    "lacuna.background-vignette",
    "lacuna.bar",
    "lacuna.bar-seam",
    "lacuna.bar-size-pill",
    "lacuna.bluetooth",
    "lacuna.cinematic-light-overlay",
    "lacuna.claude-usage",
    "lacuna.clock",
    "lacuna.codex-usage",
    "lacuna.crt-overlay",
    "lacuna.desktop-clock",
    "lacuna.dust-motes-overlay",
    "lacuna.film-grain-overlay",
    "lacuna.god-rays-overlay",
    "lacuna.idle-inhibitor",
    "lacuna.indicators",
    "lacuna.media-player",
    "lacuna.media-player-video",
    "lacuna.menu",
    "lacuna.menu-button",
    "lacuna.mpris",
    "lacuna.network",
    "lacuna.nightlight",
    "lacuna.notifications",
    "lacuna.power",
    "lacuna.rainfall-overlay",
    "lacuna.reminders",
    "lacuna.screen-recording",
    "lacuna.script-pill",
    "lacuna.settings-persistence",
    "lacuna.shell-settings",
    "lacuna.state",
    "lacuna.system-stats",
    "lacuna.system-update",
    "lacuna.temperature",
    "lacuna.theme",
    "lacuna.theme-preloader",
    "lacuna.tray",
    "lacuna.vhs-overlay",
    "lacuna.voxtype",
    "lacuna.wallpaper",
    "lacuna.weather",
    "lacuna.workspaces",
}


def install_omakase_roots(config_home, plugin_ids=OMAKASE_PLUGIN_IDS):
    for plugin_id in plugin_ids:
        (config_home / "omarchy" / "plugins" / plugin_id).mkdir(parents=True, exist_ok=True)


def load_installer_module():
    import importlib.util
    import importlib.machinery

    loader = importlib.machinery.SourceFileLoader("lacuna_installer", str(INSTALLER))
    spec = importlib.util.spec_from_loader("lacuna_installer", loader)
    module = importlib.util.module_from_spec(spec)
    sys.modules["lacuna_installer"] = module
    spec.loader.exec_module(module)
    return module


class LacunaInstallerTests(unittest.TestCase):
    def test_restart_timeout_is_accepted_only_for_a_new_healthy_shell(self):
        module = load_installer_module()
        command = ["omarchy", "restart", "shell"]
        with mock.patch.object(module, "omarchy_shell_process_ids", side_effect=[{101}, {202}]), \
            mock.patch.object(module, "run_command", return_value=1) as run_command, \
            mock.patch.object(module, "shell_ping_ready", side_effect=[False, True]) as ping, \
            mock.patch.object(module.time, "sleep"):
            self.assertEqual(module.run_reload_command(command, dry_run=False), 0)
        run_command.assert_called_once_with(command, False)
        self.assertEqual(ping.call_count, 2)

    def test_restart_failure_is_not_masked_when_no_new_shell_started(self):
        module = load_installer_module()
        command = ["omarchy", "restart", "shell"]
        with mock.patch.object(module, "omarchy_shell_process_ids", side_effect=[{101}, {101}]), \
            mock.patch.object(module, "run_command", return_value=1), \
            mock.patch.object(module, "shell_ping_ready") as ping:
            self.assertEqual(module.run_reload_command(command, dry_run=False), 1)
        ping.assert_not_called()

    def test_run_command_returns_failure_when_executable_is_missing(self):
        module = load_installer_module()
        with mock.patch.object(module.subprocess, "run", side_effect=FileNotFoundError("missing")):
            self.assertEqual(module.run_command(["hyprctl", "reload"], dry_run=False), 127)

    def test_omarchy_host_paths_ignore_custom_xdg_config_home(self):
        module = load_installer_module()

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
                self.assertEqual(module.shell_config_path(), home / ".config/omarchy/shell.json")
                self.assertEqual(module.lacuna_state_dir(), xdg_config / "omarchy/lacuna")
                self.assertEqual(
                    module.lacuna_hypr_override_paths()[0].parent,
                    home / ".local/state/omarchy/toggles/hypr",
                )

    def test_installer_transaction_lock_serializes_processes(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            lock_path = config_home / "omarchy" / "lacuna-installer.lock"
            lock_path.parent.mkdir(parents=True)
            helper = f'''import importlib.machinery
import importlib.util
import sys
loader = importlib.machinery.SourceFileLoader("installer_lock_child", {str(INSTALLER)!r})
spec = importlib.util.spec_from_loader("installer_lock_child", loader)
module = importlib.util.module_from_spec(spec)
sys.modules["installer_lock_child"] = module
loader.exec_module(module)
with module.installer_transaction_lock():
    print("acquired", flush=True)
'''
            env = os.environ.copy()
            env["LACUNA_OMARCHY_CONFIG_HOME"] = str(config_home)
            with lock_path.open("w") as lock_file:
                fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
                proc = subprocess.Popen(
                    [sys.executable, "-c", helper],
                    env=env,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                try:
                    time.sleep(0.15)
                    self.assertIsNone(proc.poll(), "installer bypassed the transaction lock")
                finally:
                    fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
                stdout, stderr = proc.communicate(timeout=5)
            self.assertEqual(proc.returncode, 0, stderr)
            self.assertEqual(stdout.strip(), "acquired")

    def test_shell_config_write_uses_owned_unique_temporary(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            legacy_tmp = config_home / "omarchy" / "shell.json.tmp"
            legacy_tmp.parent.mkdir(parents=True)
            legacy_tmp.write_text("do-not-touch\n", encoding="utf-8")
            config = module.default_shell_config()
            with mock.patch.dict(module.os.environ, {"LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}):
                module.write_shell_config(config)
            self.assertEqual(legacy_tmp.read_text(encoding="utf-8"), "do-not-touch\n")
            self.assertEqual(module.json.loads((config_home / "omarchy" / "shell.json").read_text()), config)
            self.assertEqual(list(legacy_tmp.parent.glob(".shell.json.tmp.*")), [])

    def test_core_profile_dry_run_uses_current_omarchy_plugin_routes(self):
        result = run_lacuna(["install", "--profile", "core", "--dry-run", "--yes"])

        self.assertIn("Install plan", result.stdout)
        self.assertIn("stage lacuna.bar ->", result.stdout)
        self.assertIn("stage lacuna.state ->", result.stdout)
        self.assertIn("stage lacuna.menu-button ->", result.stdout)
        self.assertIn("omarchy plugin rescan", result.stdout)
        self.assertNotIn("omarchy-shell-refactor", result.stdout)

    def test_global_flags_work_before_or_after_subcommand(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            before = run_lacuna(["--dry-run", "--yes", "install", "--profile", "core"], config_home=config_home).stdout
            after = run_lacuna(["install", "--profile", "core", "--dry-run", "--yes"], config_home=config_home).stdout

        self.assertEqual(before, after)

    def test_full_profile_installs_and_activates_lacuna_bar_by_default(self):
        result = run_lacuna(["install", "--profile", "full", "--dry-run", "--yes"])

        self.assertIn("lacuna.menu-button", result.stdout)
        self.assertIn("lacuna.theme-preloader", result.stdout)
        self.assertIn("stage lacuna.bar ->", result.stdout)
        self.assertIn("lacuna.clock", result.stdout)
        self.assertIn("lacuna.audio", result.stdout)
        self.assertIn("lacuna.tray", result.stdout)
        self.assertIn("Activation", result.stdout)
        self.assertIn("apply Lacuna bar host layout in shell.json", result.stdout)
        self.assertIn("apply Lacuna bar layout in shell.json", result.stdout)
        self.assertEqual(result.stdout.count("omarchy restart shell"), 1)
        self.assertEqual(result.stdout.count("omarchy plugin rescan"), 0)
        self.assertNotIn("lacuna.compact-pill", result.stdout)

    def test_omakase_profile_is_exact_checked_set_with_canonical_layout(self):
        module = load_installer_module()
        plugins = module.load_plugins()
        profile = module.load_omakase_profile(plugins)

        self.assertEqual(len(OMAKASE_PLUGIN_IDS), 46)
        self.assertEqual(set(profile["installRoots"]), OMAKASE_PLUGIN_IDS)
        self.assertNotIn("lacuna.compact-pill", profile["installRoots"])
        self.assertEqual(profile["shell"]["bar"]["layout"], module.LACUNA_BAR_LAYOUT)
        layout_ids = {
            entry["id"]
            for entries in profile["shell"]["bar"]["layout"].values()
            for entry in entries
        }
        self.assertNotIn("lacuna.script-pill", layout_ids)
        self.assertNotIn("lacuna.reminders", layout_ids)
        self.assertNotIn("lacuna.bar-seam", layout_ids)
        self.assertEqual(profile["reset"]["mode"], "safe-only")
        self.assertEqual(profile["reset"]["reloadCount"], 1)
        self.assertIs(profile["reset"]["atomicFileWrites"], True)
        self.assertNotIn("atomicMerge", profile["reset"])
        self.assertIs(profile["reset"]["purgeSupported"], False)
        self.assertIn("youtube/", profile["settings"]["untouchedExternalState"])
        self.assertNotIn("youtube-auth/", profile["settings"]["untouchedExternalState"])
        self.assertEqual(profile["releaseRehearsal"]["target"], "current-user-current-machine")
        self.assertIs(profile["releaseRehearsal"]["runNow"], False)
        self.assertEqual(
            profile["releaseRehearsal"]["prerequisites"],
            [
                "automatic-backups",
                "verified-restoration-capability",
                "fresh-explicit-confirmation-immediately-before-destructive-steps",
            ],
        )

    def test_omakase_media_is_installed_and_activated_without_credentials(self):
        module = load_installer_module()
        profile = module.load_omakase_profile(module.load_plugins())
        activation_ids = {entry["id"] for entry in profile["shell"]["activationEntries"]}

        self.assertEqual(
            profile["media"]["installRoots"],
            ["lacuna.media-player", "lacuna.media-player-video"],
        )
        self.assertTrue(set(profile["media"]["installRoots"]) <= set(profile["installRoots"]))
        self.assertTrue(set(profile["media"]["installRoots"]) <= activation_ids)
        self.assertIs(profile["media"]["credentialsRequired"], False)
        defaults = json.loads((ROOT / "config/settings.example.json").read_text(encoding="utf-8"))
        self.assertIs(defaults["mediaProviders"]["youtube"]["enabled"], False)
        self.assertIs(defaults["mediaProviders"]["jellyfin"]["enabled"], False)

    def test_ambience_profile_stages_host_first_and_every_fallback(self):
        result = run_lacuna(["install", "--profile", "ambience", "--activate", "--dry-run", "--yes"])
        expected = [
            "lacuna.ambience-host",
            "lacuna.aurora-drift",
            "lacuna.cinematic-light-overlay",
            "lacuna.crt-overlay",
            "lacuna.dust-motes-overlay",
            "lacuna.film-grain-overlay",
            "lacuna.god-rays-overlay",
            "lacuna.rainfall-overlay",
            "lacuna.vhs-overlay",
        ]
        positions = [result.stdout.index(plugin_id) for plugin_id in expected]
        self.assertEqual(positions, sorted(positions), result.stdout)

    def test_ambience_activation_refreshes_installed_fallback_without_reinstall_flag(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            installed = config_home / "omarchy" / "plugins" / "lacuna.crt-overlay"
            installed.mkdir(parents=True)
            (installed / "manifest.json").write_text("{}\n", encoding="utf-8")
            result = run_lacuna(
                ["install", "--profile", "ambience", "--activate", "--dry-run", "--yes"],
                config_home=config_home,
            )
        self.assertIn("stage lacuna.crt-overlay ->", result.stdout)
        self.assertIn("refresh installed ambience fallbacks before host activation", result.stdout)

    def test_ambience_host_ordering_preserves_fallback_inline_settings(self):
        module = load_installer_module()
        config = module.default_shell_config()
        crt = {"id": "lacuna.crt-overlay", "intensity": 0.73, "custom": {"keep": True}}
        vhs = {"id": "lacuna.vhs-overlay", "noiseAmount": 0.19}
        config["plugins"] = [
            {"id": "unrelated.before"},
            crt,
            {"id": "unrelated.middle"},
            vhs,
            {"id": "lacuna.ambience-host"},
        ]
        module.order_ambience_host_before_fallbacks(config)
        self.assertEqual(
            [entry["id"] for entry in config["plugins"]],
            ["unrelated.before", "lacuna.ambience-host", "lacuna.crt-overlay", "unrelated.middle", "lacuna.vhs-overlay"],
        )
        self.assertIs(config["plugins"][2], crt)
        self.assertIs(config["plugins"][4], vhs)

    def test_full_profile_can_stage_without_activation_or_layout(self):
        result = run_lacuna(["install", "--profile", "full", "--no-activate", "--keep-layout", "--dry-run", "--yes"])

        self.assertIn("stage lacuna.bar ->", result.stdout)
        self.assertIn("lacuna.audio", result.stdout)
        self.assertNotIn("Activation", result.stdout)
        self.assertNotIn("apply Lacuna bar host layout in shell.json", result.stdout)
        self.assertNotIn("omarchy restart shell", result.stdout)
        self.assertIn("omarchy plugin rescan", result.stdout)
        self.assertNotIn("lacuna.compact-pill", result.stdout)

    def test_custom_plugin_selection_adds_required_dependencies(self):
        result = run_lacuna(["install", "--plugin", "lacuna.menu-button", "--dry-run", "--yes"])

        self.assertIn("lacuna.state", result.stdout)
        self.assertIn("lacuna.shell-settings", result.stdout)
        self.assertIn("lacuna.menu", result.stdout)
        self.assertIn("lacuna.menu-button", result.stdout)

    def test_apply_layout_prints_bar_move_routes(self):
        result = run_lacuna(["install", "--profile", "native", "--activate", "--apply-layout", "--dry-run", "--yes"])

        self.assertIn("Activation", result.stdout)
        self.assertIn("update", result.stdout)
        self.assertIn("shell.json once", result.stdout)
        self.assertIn("apply Lacuna bar host layout in shell.json", result.stdout)
        self.assertIn("apply Lacuna bar layout in shell.json", result.stdout)
        self.assertEqual(result.stdout.count("omarchy restart shell"), 1)
        self.assertEqual(result.stdout.count("omarchy plugin rescan"), 0)
        self.assertNotIn("omarchy plugin enable", result.stdout)
        self.assertNotIn("omarchy plugin bar move", result.stdout)

    def test_uninstall_all_dry_run_detects_installed_lacuna_plugins(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            installed = config_home / "omarchy" / "plugins" / "lacuna.clock"
            installed.mkdir(parents=True)
            (installed / "manifest.json").write_text("{}", encoding="utf-8")

            result = run_lacuna(["uninstall", "--all", "--dry-run", "--yes"], config_home=config_home)

        self.assertIn("Uninstall plan", result.stdout)
        self.assertIn("lacuna.clock", result.stdout)
        self.assertIn("shell.json once", result.stdout)
        self.assertIn("remove", result.stdout)
        self.assertIn("remove Lacuna Hyprland overrides", result.stdout)
        self.assertIn("hyprctl reload", result.stdout)
        self.assertIn("omarchy plugin rescan", result.stdout)
        self.assertNotIn("disable lacuna.clock if enabled", result.stdout)
        self.assertNotIn("omarchy plugin remove", result.stdout)

    def test_plugin_selection_takes_precedence_over_all_for_override_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            for plugin_id in ["lacuna.clock", "lacuna.shell-settings"]:
                installed = config_home / "omarchy" / "plugins" / plugin_id
                installed.mkdir(parents=True)
                shutil.copy2(ROOT / plugin_id / "manifest.json", installed / "manifest.json")

            result = run_lacuna(
                ["uninstall", "--all", "--plugin", "lacuna.clock", "--dry-run", "--yes"],
                config_home=config_home,
            )

        self.assertIn("lacuna.clock", result.stdout)
        self.assertNotIn("lacuna.shell-settings", result.stdout)
        self.assertNotIn("Lacuna Hyprland overrides", result.stdout)
        self.assertNotIn("hyprctl reload", result.stdout)

    def test_uninstall_removes_only_lacuna_owned_hyprland_overrides(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            config_home = Path(tmp) / "config"
            hypr_dir = home / ".local/state/omarchy/toggles/hypr"
            hypr_dir.mkdir(parents=True)
            canonical_service = (ROOT / "lacuna.shell-settings/Service.qml").read_text(encoding="utf-8")
            service_owned_names = set(re.findall(r'/((?:zz-lacuna-)[^"]+\.lua)"', canonical_service))
            self.assertEqual(set(module.LACUNA_HYPR_OVERRIDE_FILENAMES), service_owned_names)

            owned = [hypr_dir / name for name in module.LACUNA_HYPR_OVERRIDE_FILENAMES]
            for path in owned:
                path.write_text(f"-- {path.name}\n", encoding="utf-8")
            stock_overrides = [hypr_dir / "window-no-gaps.lua", hypr_dir / "single-window-aspect-ratio.lua"]
            for path in stock_overrides:
                path.write_text(f"-- Omarchy {path.name}\n", encoding="utf-8")

            env = {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(config_home),
                "LACUNA_OMARCHY_CONFIG_HOME": str(config_home),
            }
            with mock.patch.dict(module.os.environ, env, clear=True), \
                mock.patch.object(module, "deactivate_plugins", return_value=0), \
                mock.patch.object(module, "remove_plugin", return_value=0), \
                mock.patch.object(module, "run_reload_command", return_value=0) as reload_command:
                result = module.uninstall_plugins(["lacuna.shell-settings"], dry_run=False, cleanup_hypr_overrides=True)

            self.assertEqual(result, 0)
            self.assertTrue(all(not path.exists() for path in owned))
            for path in stock_overrides:
                self.assertEqual(path.read_text(encoding="utf-8"), f"-- Omarchy {path.name}\n")
            self.assertEqual(
                reload_command.call_args_list,
                [mock.call(["hyprctl", "reload"], False), mock.call(["omarchy", "plugin", "rescan"], False)],
            )

    def test_uninstall_restores_hyprland_overrides_when_reload_fails(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            config_home = Path(tmp) / "config"
            override = home / ".local/state/omarchy/toggles/hypr/zz-lacuna-window-rounded.lua"
            override.parent.mkdir(parents=True)
            original = b"hl.config({ decoration = { rounding = 12 } })\n"
            override.write_bytes(original)

            env = {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(config_home),
                "LACUNA_OMARCHY_CONFIG_HOME": str(config_home),
            }
            with mock.patch.dict(module.os.environ, env, clear=True), \
                mock.patch.object(module, "deactivate_plugins", return_value=0), \
                mock.patch.object(module, "remove_plugin", return_value=0), \
                mock.patch.object(module, "run_reload_command", side_effect=[1, 0]) as reload_command, \
                mock.patch.object(module, "reload_after_rollback", return_value=0) as recovery:
                result = module.uninstall_plugins(["lacuna.shell-settings"], dry_run=False, cleanup_hypr_overrides=True)

            self.assertEqual(result, 1)
            self.assertEqual(override.read_bytes(), original)
            self.assertEqual(
                reload_command.call_args_list,
                [mock.call(["hyprctl", "reload"], False), mock.call(["hyprctl", "reload"], dry_run=False)],
            )
            recovery.assert_called_once_with({"lacuna.shell-settings"})

    def test_uninstall_refuses_directory_at_override_path_without_mutation(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            config_home = Path(tmp) / "config"
            override = home / ".local/state/omarchy/toggles/hypr/zz-lacuna-window-rounded.lua"
            override.mkdir(parents=True)
            payload = override / "user-data"
            payload.write_text("keep\n", encoding="utf-8")
            env = {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(config_home),
                "LACUNA_OMARCHY_CONFIG_HOME": str(config_home),
            }
            with mock.patch.dict(module.os.environ, env, clear=True), \
                mock.patch.object(module, "deactivate_plugins") as deactivate:
                result = module.uninstall_plugins(["lacuna.shell-settings"], dry_run=False, cleanup_hypr_overrides=True)

            self.assertEqual(result, 1)
            self.assertEqual(payload.read_text(encoding="utf-8"), "keep\n")
            deactivate.assert_not_called()

    def test_interactive_uninstall_recovers_stale_hyprland_overrides(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            override = home / ".local/state/omarchy/toggles/hypr/zz-lacuna-window-gaps.lua"
            override.parent.mkdir(parents=True)
            override.write_text("-- stale\n", encoding="utf-8")
            args = module.argparse.Namespace(all=False)
            with mock.patch.dict(module.os.environ, {"HOME": str(home)}, clear=True), \
                mock.patch.object(module, "installed_lacuna_plugins", return_value=[]):
                result = module.uninstall_menu(args)

            self.assertIs(result, args)
            self.assertTrue(args.all)

    def test_uninstall_lacuna_bar_dry_run_reports_stock_bar_restore_and_shell_restart(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            installed = config_home / "omarchy" / "plugins" / "lacuna.bar"
            installed.mkdir(parents=True)
            (installed / "manifest.json").write_text("{}", encoding="utf-8")

            result = run_lacuna(["uninstall", "--all", "--dry-run", "--yes"], config_home=config_home)

        self.assertIn("restore stock Omarchy bar layout in shell.json", result.stdout)
        self.assertIn("omarchy restart shell", result.stdout)
        self.assertNotIn("omarchy plugin rescan", result.stdout)

    def test_selective_uninstall_refuses_to_break_installed_dependencies(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            for plugin_id in ["lacuna.menu", "lacuna.menu-button"]:
                installed = config_home / "omarchy" / "plugins" / plugin_id
                installed.mkdir(parents=True)
                shutil.copy2(ROOT / plugin_id / "manifest.json", installed / "manifest.json")

            result = run_lacuna_unchecked(
                ["uninstall", "--plugin", "lacuna.menu", "--dry-run", "--yes"],
                config_home=config_home,
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("Refusing to break installed plugin dependencies", result.stderr)
        self.assertIn("lacuna.menu-button", result.stderr)
        self.assertIn("--cascade", result.stderr)

    def test_selective_uninstall_cascade_includes_installed_dependents(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            for plugin_id in ["lacuna.menu", "lacuna.menu-button"]:
                installed = config_home / "omarchy" / "plugins" / plugin_id
                installed.mkdir(parents=True)
                shutil.copy2(ROOT / plugin_id / "manifest.json", installed / "manifest.json")

            result = run_lacuna(
                ["uninstall", "--plugin", "lacuna.menu", "--cascade", "--dry-run", "--yes"],
                config_home=config_home,
            )

        self.assertIn("lacuna.menu", result.stdout)
        self.assertIn("lacuna.menu-button", result.stdout)

    def test_uninstall_requires_all_or_plugin_selection(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            installed = config_home / "omarchy" / "plugins" / "lacuna.clock"
            installed.mkdir(parents=True)
            (installed / "manifest.json").write_text("{}", encoding="utf-8")

            result = run_lacuna_unchecked(["uninstall", "--dry-run", "--yes"], config_home=config_home)

        self.assertEqual(result.returncode, 2)
        self.assertIn("Pass --all or --plugin", result.stderr)

    def test_prune_backups_keeps_latest_two_per_plugin(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            backup_dir = config_home / "omarchy" / "plugins"
            backup_dir.mkdir(parents=True)
            for index in range(4):
                backup = backup_dir / f".lacuna.clock.bak.2026010100000{index}"
                backup.mkdir()
                os.utime(backup, (index, index))

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}):
                module.prune_backups("lacuna.clock", keep=2)

            remaining = sorted(path.name for path in backup_dir.glob(".lacuna.clock.bak.*"))

        self.assertEqual(remaining, [".lacuna.clock.bak.20260101000002", ".lacuna.clock.bak.20260101000003"])

    def test_stage_plugin_ignores_pycache_directories(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            config_home = tmp_path / "config"
            source = tmp_path / "repo" / "lacuna.fake"
            (source / "__pycache__").mkdir(parents=True)
            (source / "__pycache__" / "stale.pyc").write_bytes(b"cache")
            (source / "manifest.json").write_text('{"id":"lacuna.fake"}\n', encoding="utf-8")

            with mock.patch.object(module, "ROOT", tmp_path / "repo"), \
                mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "validate_plugin", return_value=0):
                result = module.stage_plugin("lacuna.fake", dry_run=False, reinstall=True)

            target = config_home / "omarchy" / "plugins" / "lacuna.fake"
            manifest_staged = (target / "manifest.json").exists()
            pycache_staged = (target / "__pycache__").exists()

        self.assertEqual(result, 0)
        self.assertTrue(manifest_staged)
        self.assertFalse(pycache_staged)

    def test_stage_plugin_does_not_remove_stale_pid_temporary(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            config_home = tmp_path / "config"
            source = tmp_path / "repo" / "lacuna.fake"
            source.mkdir(parents=True)
            (source / "manifest.json").write_text('{"id":"lacuna.fake"}\n', encoding="utf-8")
            stale = config_home / "omarchy" / "plugins" / f".lacuna.fake.tmp.{os.getpid()}"
            stale.mkdir(parents=True)
            (stale / "sentinel").write_text("owned elsewhere\n", encoding="utf-8")

            with mock.patch.object(module, "ROOT", tmp_path / "repo"), \
                mock.patch.dict(module.os.environ, {"LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "validate_plugin", return_value=0):
                result = module.stage_plugin("lacuna.fake", dry_run=False, reinstall=True)

            self.assertEqual(result, 0)
            self.assertEqual((stale / "sentinel").read_text(encoding="utf-8"), "owned elsewhere\n")
            self.assertTrue((config_home / "omarchy" / "plugins" / "lacuna.fake" / "manifest.json").is_file())

    def test_interrupted_stage_cleans_owned_temporary_directory(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            config_home = tmp_path / "config"
            source = tmp_path / "repo" / "lacuna.fake"
            source.mkdir(parents=True)
            (source / "manifest.json").write_text('{"id":"lacuna.fake"}\n', encoding="utf-8")

            with mock.patch.object(module, "ROOT", tmp_path / "repo"), \
                mock.patch.dict(module.os.environ, {"LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "validate_plugin", return_value=0), \
                mock.patch.object(module.shutil, "copytree", side_effect=KeyboardInterrupt):
                with self.assertRaises(KeyboardInterrupt):
                    module.stage_plugin("lacuna.fake", dry_run=False, reinstall=True)

            plugin_root = config_home / "omarchy" / "plugins"
            self.assertEqual(list(plugin_root.glob(".lacuna.fake.tmp.*")), [])

    def test_failed_batch_rescan_restores_all_previous_plugin_copies(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            repo = tmp_path / "repo"
            config_home = tmp_path / "config"
            for plugin_id in ("lacuna.first", "lacuna.second"):
                source = repo / plugin_id
                source.mkdir(parents=True)
                (source / "manifest.json").write_text(f'{{"id":"{plugin_id}"}}\n', encoding="utf-8")
                target = config_home / "omarchy" / "plugins" / plugin_id
                target.mkdir(parents=True)
                (target / "manifest.json").write_text(f'{{"id":"{plugin_id}","old":true}}\n', encoding="utf-8")

            changes = []
            with mock.patch.object(module, "ROOT", repo), \
                mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "validate_plugin", return_value=0), \
                mock.patch.object(module, "run_command", side_effect=[7, 0]) as run_command:
                result = module.stage_plugins(
                    ["lacuna.first", "lacuna.second"],
                    dry_run=False,
                    reinstall=True,
                    rescan=True,
                    changes=changes,
                )

            first = (config_home / "omarchy" / "plugins" / "lacuna.first" / "manifest.json").read_text(encoding="utf-8")
            second = (config_home / "omarchy" / "plugins" / "lacuna.second" / "manifest.json").read_text(encoding="utf-8")

        self.assertEqual(7, result)
        self.assertIn('"old":true', first)
        self.assertIn('"old":true', second)
        self.assertEqual([], changes)
        self.assertEqual(
            [["omarchy", "plugin", "rescan"], ["omarchy", "plugin", "rescan"]],
            [item.args[0] for item in run_command.call_args_list],
        )

    def test_failed_activation_restores_previous_shell_config(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            shell_json = config_home / "omarchy" / "shell.json"
            shell_json.parent.mkdir(parents=True)
            original = '{"version":1,"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[]}\n'
            shell_json.write_text(original, encoding="utf-8")
            plugins = module.load_plugins()

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "run_command", return_value=9) as run_command:
                result = module.activate_plugins(
                    ["lacuna.state"],
                    plugins,
                    {"lacuna.state"},
                    False,
                    False,
                )

            restored = shell_json.read_text(encoding="utf-8")

        self.assertEqual(9, result)
        self.assertEqual(original, restored)
        self.assertEqual(run_command.call_count, 2)

    def test_failed_ambience_activation_restores_shell_and_never_rewrites_lacuna_settings(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            shell_json = config_home / "omarchy" / "shell.json"
            settings_json = config_home / "omarchy" / "lacuna" / "settings.json"
            settings_json.parent.mkdir(parents=True)
            original_shell = '{"version":1,"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[{"id":"lacuna.crt-overlay","intensity":0.73}]}\n'
            original_settings = '{"backgroundEffects":{"activeEffects":["crt","trackingLines"]}}\n'
            shell_json.write_text(original_shell, encoding="utf-8")
            settings_json.write_text(original_settings, encoding="utf-8")
            plugins = module.load_plugins()
            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "run_command", return_value=9):
                result = module.activate_plugins(
                    ["lacuna.ambience-host", "lacuna.crt-overlay"],
                    plugins,
                    {"lacuna.ambience-host", "lacuna.crt-overlay"},
                    False,
                    False,
                )
            self.assertEqual(result, 9)
            self.assertEqual(shell_json.read_text(encoding="utf-8"), original_shell)
            self.assertEqual(settings_json.read_text(encoding="utf-8"), original_settings)

    def test_runtime_state_snapshot_preserves_shell_and_lacuna_settings(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            shell_json = config_home / "omarchy" / "shell.json"
            settings_json = config_home / "omarchy" / "lacuna" / "settings.json"
            shell_json.parent.mkdir(parents=True)
            settings_json.parent.mkdir(parents=True)
            shell_json.write_text("shell-state\n", encoding="utf-8")
            settings_json.write_text("settings-state\n", encoding="utf-8")

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}):
                backups = module.preserve_runtime_state()

            contents = sorted(path.read_text(encoding="utf-8") for path in backups)

        self.assertEqual(["settings-state\n", "shell-state\n"], contents)

    def test_gum_wrapper_does_not_hide_interactive_ui(self):
        module = load_installer_module()

        with mock.patch.object(module.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess(["gum"], 0, stdout="Full Lacuna install\n")

            self.assertEqual(
                module.run_gum(["choose", "--header=Lacuna", "Full Lacuna install"]),
                "Full Lacuna install",
            )

        self.assertIsNone(run.call_args.kwargs["stderr"])
        command = run.call_args.args[0]
        self.assertEqual(command[:2], ["gum", "choose"])
        self.assertIn("--cursor.foreground=", command)
        self.assertIn("--cursor.background=", command)
        self.assertIn("--header.foreground=", command)
        self.assertIn("--selected.background=", command)

    def test_gum_confirm_inherits_terminal_foreground_and_background(self):
        module = load_installer_module()

        command = module.gum_command(["confirm", "Continue?"])

        self.assertEqual(command[:2], ["gum", "confirm"])
        self.assertIn("--prompt.foreground=", command)
        self.assertIn("--prompt.background=", command)
        self.assertIn("--selected.foreground=", command)
        self.assertIn("--selected.background=", command)
        self.assertIn("--unselected.foreground=", command)
        self.assertIn("--unselected.background=", command)
        self.assertEqual(command[-1], "Continue?")

    def test_default_source_url_prefers_local_checkout(self):
        module = load_installer_module()

        self.assertEqual(module.default_source_url(), str(ROOT))

    def test_default_source_url_uses_official_repo_for_extracted_archive(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp, \
            mock.patch.object(module, "ROOT", Path(tmp)):
            self.assertEqual(
                module.default_source_url(),
                "https://github.com/OldJobobo/lacuna-shell.git",
            )

    def test_stale_source_catalog_reports_repair_commands(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp, \
            mock.patch.object(module, "ROOT", Path(tmp)), \
            mock.patch.object(module, "source_catalog_ids", return_value=set()):
            result = module.verify_source_catalog("lacuna", ["lacuna.state"])

        self.assertEqual(result, 1)

    def test_stale_source_catalog_allows_local_checkout_plugins(self):
        module = load_installer_module()

        with mock.patch.object(module, "source_catalog_ids", return_value=set()):
            result = module.verify_source_catalog("lacuna", ["lacuna.state"])

        self.assertEqual(result, 0)

    def test_menu_full_install_activates_lacuna_bar_layout(self):
        module = load_installer_module()
        args = module.normalize_args(module.parser().parse_args([]))

        with mock.patch.object(module, "choose", return_value="Full Lacuna install"), \
            mock.patch.object(module, "run_mutation", side_effect=lambda operation, value: operation(value)), \
            mock.patch.object(module, "install", return_value=0) as install:
            result = module.menu(args)

        self.assertEqual(result, 0)
        install_args = install.call_args.args[0]
        self.assertEqual(install_args.profile, "full")
        self.assertIs(install_args.include_replacements, True)
        self.assertIs(install_args.activate, True)
        self.assertIs(install_args.apply_layout, True)

    def test_activation_mutates_shell_config_once(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            shell_json = config_home / "omarchy" / "shell.json"
            shell_json.parent.mkdir(parents=True)
            shell_json.write_text(
                '{"version":1,"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[]}\n',
                encoding="utf-8",
            )
            plugins = module.load_plugins()

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "run_command", return_value=0) as run_command:
                result = module.activate_plugins(
                    ["lacuna.state", "lacuna.menu-button"],
                    plugins,
                    {"lacuna.state", "lacuna.menu-button"},
                    False,
                    False,
                )

            data = __import__("json").loads(shell_json.read_text(encoding="utf-8"))

        self.assertEqual(result, 0)
        self.assertEqual(run_command.call_count, 1)
        self.assertEqual(run_command.call_args.args[0], ["omarchy", "plugin", "rescan"])
        self.assertEqual(data["plugins"], [{"id": "lacuna.state"}])
        self.assertEqual(data["bar"]["layout"]["right"], [{"id": "lacuna.menu-button"}])

    def test_plugin_stability_is_read_and_surfaced_in_labels(self):
        module = load_installer_module()
        plugins = module.load_plugins()

        self.assertEqual(plugins["lacuna.script-pill"].stability, "experimental")
        self.assertEqual(plugins["lacuna.compact-pill"].stability, "deprecated")
        self.assertEqual(plugins["lacuna.menu"].stability, "beta")

        self.assertIn("[experimental]", module.label(plugins["lacuna.script-pill"]))
        self.assertIn("[deprecated]", module.label(plugins["lacuna.compact-pill"]))
        self.assertIn("[beta]", module.label(plugins["lacuna.menu"]))
        # Tier markers do not interfere with id parsing.
        self.assertEqual(
            module.id_from_label(module.label(plugins["lacuna.script-pill"])),
            "lacuna.script-pill",
        )

    def test_installer_rejects_missing_invalid_and_reserved_manifest_stability(self):
        module = load_installer_module()
        for stability in (None, "stable", "preview"):
            with self.subTest(stability=stability), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                plugin_dir = root / "lacuna.fake"
                plugin_dir.mkdir()
                manifest = {
                    "id": "lacuna.fake",
                    "name": "Fake",
                    "kinds": [],
                    "lacuna": {"standalone": True, "bundle": "standalone", "requires": [], "recommends": []},
                }
                if stability is not None:
                    manifest["lacuna"]["stability"] = stability
                (plugin_dir / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
                with mock.patch.object(module, "ROOT", root):
                    with self.assertRaises(SystemExit):
                        module.load_plugins()

    def test_activation_selects_bar_options_with_bar_id(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            shell_json = config_home / "omarchy" / "shell.json"
            shell_json.parent.mkdir(parents=True)
            shell_json.write_text(
                '{"version":1,"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[]}\n',
                encoding="utf-8",
            )
            plugins = module.load_plugins()

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "run_command", return_value=0) as run_command:
                result = module.activate_plugins(
                    ["lacuna.bar", "lacuna.state"],
                    plugins,
                    {"lacuna.bar", "lacuna.state"},
                    False,
                    False,
                )

            data = __import__("json").loads(shell_json.read_text(encoding="utf-8"))

        self.assertEqual(result, 0)
        self.assertEqual(run_command.call_count, 1)
        self.assertEqual(run_command.call_args.args[0], ["omarchy", "restart", "shell"])
        self.assertEqual(data["bar"]["id"], "lacuna.bar")
        self.assertEqual(data["plugins"], [{"id": "lacuna.state"}])
        self.assertEqual(data["bar"]["layout"]["right"], [])

    def test_deactivating_lacuna_bar_restores_stock_omarchy_layout(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            stock = config_home / "stock-shell.json"
            stock.parent.mkdir(parents=True)
            stock.write_text(
                """
{
  "version": 1,
  "bar": {
    "id": "omarchy.stock-override",
    "position": "top",
    "centerAnchor": "omarchy.clock",
    "layout": {
      "left": [{ "id": "omarchy.menu" }, { "id": "omarchy.workspaces" }],
      "center": [{ "id": "omarchy.clock", "format": "dddd HH:mm" }],
      "right": [{ "id": "omarchy.tray" }, { "id": "omarchy.audio" }]
    }
  },
  "plugins": []
}
""",
                encoding="utf-8",
            )
            shell_json = config_home / "omarchy" / "shell.json"
            shell_json.parent.mkdir(parents=True)
            shell_json.write_text(
                """
{
  "version": 1,
  "bar": {
    "id": "lacuna.bar",
    "position": "bottom",
    "transparent": true,
    "futureBarKey": { "keep": true },
    "centerAnchor": "lacuna.clock",
    "layout": { "left": [], "center": [], "right": [] }
  },
  "plugins": [{ "id": "lacuna.state" }, { "id": "other.service", "settings": { "keep": true } }],
  "futureTop": ["keep"]
}
""",
                encoding="utf-8",
            )

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "OMARCHY_STOCK_SHELL_CONFIG_PATHS", [stock]):
                result = module.deactivate_plugins(["lacuna.bar", "lacuna.state"], dry_run=False)

            data = __import__("json").loads(shell_json.read_text(encoding="utf-8"))

        self.assertEqual(result, 0)
        self.assertNotIn("id", data["bar"])
        self.assertEqual("bottom", data["bar"]["position"])
        self.assertIs(data["bar"]["transparent"], True)
        self.assertEqual({"keep": True}, data["bar"]["futureBarKey"])
        self.assertEqual("omarchy.clock", data["bar"]["centerAnchor"])
        self.assertEqual([{"id": "omarchy.menu"}, {"id": "omarchy.workspaces"}], data["bar"]["layout"]["left"])
        self.assertEqual([{"id": "omarchy.clock", "format": "dddd HH:mm"}], data["bar"]["layout"]["center"])
        self.assertEqual([{"id": "omarchy.tray"}, {"id": "omarchy.audio"}], data["bar"]["layout"]["right"])
        self.assertEqual([{"id": "other.service", "settings": {"keep": True}}], data["plugins"])
        self.assertEqual(["keep"], data["futureTop"])

    def test_lacuna_bar_layout_omits_bar_seam_by_default(self):
        module = load_installer_module()
        right = [entry["id"] for entry in module.LACUNA_BAR_LAYOUT["right"]]
        self.assertNotIn("lacuna.bar-seam", right)
        self.assertEqual(
            ["lacuna.bluetooth", "lacuna.network", "lacuna.audio", "lacuna.power"],
            right[right.index("lacuna.bluetooth"):right.index("lacuna.power") + 1],
        )
        self.assertEqual("lacuna.bar-size-pill", right[-1])

    def test_lacuna_bar_activation_replaces_omarchy_layout_with_lacuna_modules(self):
        module = load_installer_module()

        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            shell_json = config_home / "omarchy" / "shell.json"
            shell_json.parent.mkdir(parents=True)
            shell_json.write_text(
                """
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [
        { "id": "omarchy.menu" },
        { "id": "omarchy.workspaces" }
      ],
      "center": [
        { "id": "omarchy.clock" }
      ],
      "right": [
        { "id": "omarchy.tray" },
        { "id": "lacuna.temperature", "mode": "compact" },
        { "id": "lacuna.bar-size-pill" },
        { "id": "omarchy.power", "showPercent": true }
      ]
    }
  },
  "plugins": []
}
""",
                encoding="utf-8",
            )
            plugins = module.load_plugins()
            selected = {"lacuna.bar"} | module.LACUNA_BAR_LAYOUT_PLUGIN_IDS

            with mock.patch.dict(module.os.environ, {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}), \
                mock.patch.object(module, "installed_lacuna_plugins", return_value=[]), \
                mock.patch.object(module, "run_command", return_value=0):
                result = module.activate_plugins(
                    module.ordered(selected, plugins),
                    plugins,
                    selected,
                    False,
                    False,
                )

            data = __import__("json").loads(shell_json.read_text(encoding="utf-8"))
            layout_ids = [
                entry["id"]
                for section in ("left", "center", "right")
                for entry in data["bar"]["layout"][section]
            ]

        self.assertEqual(result, 0)
        self.assertEqual(data["bar"]["id"], "lacuna.bar")
        self.assertIs(data["bar"]["transparent"], False)
        self.assertEqual(
            ["lacuna.bluetooth", "lacuna.network", "lacuna.audio", "lacuna.power"],
            [plugin_id for plugin_id in layout_ids if plugin_id in {"lacuna.bluetooth", "lacuna.network", "lacuna.audio", "lacuna.power"}],
        )
        self.assertNotIn("omarchy.bluetooth", layout_ids)
        self.assertNotIn("omarchy.network", layout_ids)
        self.assertNotIn("omarchy.audio", layout_ids)
        self.assertNotIn("omarchy.power", layout_ids)
        self.assertEqual(data["bar"]["layout"]["left"][0]["id"], "lacuna.menu-button")
        self.assertEqual(data["bar"]["layout"]["center"][0]["id"], "lacuna.voxtype")
        self.assertEqual(data["bar"]["layout"]["right"][0]["id"], "lacuna.tray")
        self.assertIn({"id": "lacuna.temperature", "mode": "compact"}, data["bar"]["layout"]["right"])
        self.assertIn({"id": "lacuna.power", "showPercent": True}, data["bar"]["layout"]["right"])
        self.assertEqual("lacuna.bar-size-pill", data["bar"]["layout"]["right"][-1]["id"])

    def test_lacuna_bar_layout_normalizes_transparency_off(self):
        module = load_installer_module()
        config = module.ensure_shell_config_shape(
            {
                "bar": {
                    "transparent": True,
                    "layout": {"left": [], "center": [], "right": []},
                }
            }
        )

        module.apply_lacuna_bar_layout_to_config(config, set())

        self.assertIs(config["bar"]["transparent"], False)

    def test_lacuna_bar_layout_uses_available_modules_and_preserves_entry_settings(self):
        module = load_installer_module()
        config = module.ensure_shell_config_shape(
            {
                "version": 1,
                "bar": {
                    "centerAnchor": "omarchy.clock",
                    "layout": {
                        "left": [
                            {"id": "lacuna.codex-usage", "interval": 60},
                            {"id": "omarchy.workspaces"},
                        ],
                        "center": [
                            {"id": "lacuna.clock", "format": "HH:mm", "formatAlt": "legacy value"},
                        ],
                        "right": [
                            {"id": "lacuna.temperature", "warmF": 140},
                            {"id": "omarchy.tray"},
                        ],
                    },
                },
                "plugins": [],
            }
        )

        module.apply_lacuna_bar_layout_to_config(
            config,
            {"lacuna.menu-button", "lacuna.codex-usage", "lacuna.clock", "lacuna.temperature"},
        )

        layout = config["bar"]["layout"]
        layout_ids = [
            entry["id"]
            for section in ("left", "center", "right")
            for entry in layout[section]
        ]

        self.assertEqual("lacuna.clock", config["bar"]["centerAnchor"])
        self.assertEqual(["lacuna.menu-button", "lacuna.codex-usage"], [entry["id"] for entry in layout["left"]])
        self.assertEqual(["lacuna.clock"], [entry["id"] for entry in layout["center"]])
        self.assertEqual(["lacuna.temperature"], [entry["id"] for entry in layout["right"]])
        self.assertNotIn("omarchy.workspaces", layout_ids)
        self.assertNotIn("omarchy.tray", layout_ids)
        self.assertNotIn("lacuna.tray", layout_ids)
        self.assertIn({"id": "lacuna.codex-usage", "interval": 60}, layout["left"])
        self.assertEqual("HH:mm", layout["center"][0]["format"])
        self.assertEqual("legacy value", layout["center"][0]["formatAlt"])
        self.assertIn("dateFormat", layout["center"][0])
        self.assertIn("timeFormat", layout["center"][0])
        self.assertIn("verticalFormat", layout["center"][0])
        self.assertIn({"id": "lacuna.temperature", "warmF": 140}, layout["right"])

    def test_bar_size_toggle_is_pinned_after_laptop_power_entries(self):
        module = load_installer_module()
        entries = [
            {"id": "lacuna.tray"},
            {"id": "lacuna.bar-size-pill"},
            {"id": "omarchy.power", "showPercent": True},
        ]

        module.pin_bar_size_toggle_last(entries)

        self.assertEqual(
            [
                {"id": "lacuna.tray"},
                {"id": "omarchy.power", "showPercent": True},
                {"id": "lacuna.bar-size-pill"},
            ],
            entries,
        )

    def test_reset_preflight_refuses_zero_installed_roots_without_mutation(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            shell_path = config_home / "omarchy/shell.json"
            settings_path = config_home / "omarchy/lacuna/settings.json"
            shell_path.parent.mkdir(parents=True, exist_ok=True)
            settings_path.parent.mkdir(parents=True)
            shell_path.write_bytes(b'{"keep":"shell"}\n')
            settings_path.write_bytes(b'{"keep":"settings"}\n')
            original = (shell_path.read_bytes(), settings_path.read_bytes())

            result = run_lacuna_unchecked(["reset", "--yes"], config_home=config_home)

            self.assertEqual(result.returncode, 2)
            self.assertIn("Reset refused", result.stderr)
            self.assertIn("lacuna.media-player", result.stderr)
            self.assertIn("lacuna.script-pill", result.stderr)
            self.assertIn("Recovery: ./scripts/lacuna install --yes", result.stderr)
            self.assertEqual((shell_path.read_bytes(), settings_path.read_bytes()), original)
            self.assertFalse((settings_path.parent / "installer-status.json").exists())
            self.assertFalse((settings_path.parent / "backups").exists())
            self.assertFalse((config_home / "omarchy/lacuna-installer.lock").exists())

    def test_reset_preflight_refuses_partial_installed_roots_with_exact_missing_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            missing = "lacuna.media-player-video"
            install_omakase_roots(config_home, OMAKASE_PLUGIN_IDS - {missing})

            result = run_lacuna_unchecked(["reset", "--dry-run", "--yes"], config_home=config_home)

            self.assertEqual(result.returncode, 2)
            self.assertIn(f"  - {missing}", result.stderr)
            self.assertNotIn("  - lacuna.script-pill", result.stderr)
            self.assertIn("Recovery: ./scripts/lacuna install --yes", result.stderr)

    def test_reset_preflight_allows_all_roots_for_dry_run_and_reset(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            install_omakase_roots(config_home)

            dry_run = run_lacuna(["reset", "--dry-run", "--yes"], config_home=config_home)
            self.assertIn("Omakase reset plan", dry_run.stdout)

            args = module.argparse.Namespace(dry_run=False, yes=True)
            env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}
            with mock.patch.dict(module.os.environ, env), mock.patch.object(module, "run_command", return_value=0):
                self.assertEqual(module.reset(args), 0)

    def test_reset_preserves_protected_state_plugin_copies_and_is_idempotent(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            install_omakase_roots(config_home)
            shell_path = config_home / "omarchy/shell.json"
            settings_path = config_home / "omarchy/lacuna/settings.json"
            shell_path.parent.mkdir(parents=True, exist_ok=True)
            settings_path.parent.mkdir(parents=True)
            shell_path.write_text(json.dumps({
                "version": 7,
                "futureShell": {"keep": True},
                "bar": {
                    "id": "other.bar",
                    "position": "bottom",
                    "futureBar": 9,
                    "layout": {"left": [{"id": "other.widget"}], "center": [], "right": [{"id": "lacuna.script-pill", "command": "keep-out"}]},
                },
                "plugins": [
                    {"id": "other.overlay", "custom": 1},
                    {"id": "lacuna.compact-pill"},
                    {"id": "lacuna.crt-overlay", "intensity": 0.99},
                ],
            }) + "\n", encoding="utf-8")
            protected = {
                "customQuickLaunchApps": ["secret-app"],
                "customQuickLaunchNames": {"secret-app": "Secret"},
                "preferredApps": {"files": "private-file-manager"},
                "mediaProviders": {"jellyfin": {"enabled": True, "apiKey": "credential", "serverUrl": "https://private"}},
                "mediaPlayer": {"presentationMode": "background", "videoQuality": "stable", "providerFilter": "jellyfin", "futurePlayer": {"keep": True}},
                "sidebar": {"defaultMode": "expanded", "futureNested": {"keep": True}},
                "power": {"instantRestart": True, "futurePower": "keep"},
                "futureTop": {"keep": [1, 2, 3]},
            }
            settings_input = dict(protected)
            settings_input["geometry"] = {
                "cornerMode": "square",
                "cornerRadius": 7,
                "futureGeometry": {"keep": True},
            }
            settings_path.write_text(json.dumps(settings_input) + "\n", encoding="utf-8")

            external = {
                "media-player.json": b'{"favorites":["fav"],"queue":["queued"],"history":["played"],"presentationMode":"background","videoQuality":"stable","providerFilter":"jellyfin"}\n',
                "youtube/cookies.txt": b'auth-cookie-secret\n',
                "reminders.json": b'{"reminders":["keep"]}\n',
            }
            for relative, payload in external.items():
                path = settings_path.parent / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(payload)
            plugin_sentinel = config_home / "omarchy/plugins/lacuna.media-player/user-copy"
            plugin_sentinel.parent.mkdir(parents=True, exist_ok=True)
            plugin_sentinel.write_bytes(b"do-not-touch\n")

            args = module.argparse.Namespace(dry_run=False, yes=True)
            env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}

            def reload_and_mutate_media_state(*_args, **_kwargs):
                (settings_path.parent / "media-player.json").write_bytes(b'{"favorites":[],"providerFilter":"all"}\n')
                return 0

            with mock.patch.dict(module.os.environ, env), mock.patch.object(module, "run_command", side_effect=reload_and_mutate_media_state) as reload_command:
                self.assertEqual(module.reset(args), 0)
                first_shell = shell_path.read_bytes()
                first_settings = settings_path.read_bytes()
                self.assertEqual(module.reset(args), 0)

            shell = json.loads(shell_path.read_text(encoding="utf-8"))
            settings = json.loads(settings_path.read_text(encoding="utf-8"))
            profile = module.load_omakase_profile(module.load_plugins())
            self.assertEqual(shell_path.read_bytes(), first_shell)
            self.assertEqual(settings_path.read_bytes(), first_settings)
            self.assertEqual(reload_command.call_count, 2)
            self.assertEqual(shell["bar"]["position"], "bottom")
            self.assertEqual(shell["bar"]["futureBar"], 9)
            self.assertEqual(shell["bar"]["layout"], profile["shell"]["bar"]["layout"])
            self.assertEqual(shell["plugins"][0], {"id": "other.overlay", "custom": 1})
            self.assertEqual(shell["plugins"][1:], profile["shell"]["activationEntries"])
            self.assertEqual(shell["futureShell"], {"keep": True})
            for key in module.RESET_PRESERVED_SETTINGS_KEYS:
                self.assertEqual(settings[key], protected[key])
            self.assertEqual(settings["version"], 3)
            self.assertEqual("theme", settings["geometry"]["cornerMode"])
            self.assertEqual(14, settings["geometry"]["cornerRadius"])
            self.assertEqual({"keep": True}, settings["geometry"]["futureGeometry"])
            self.assertEqual(settings["sidebar"]["defaultMode"], "off")
            self.assertEqual(settings["sidebar"]["futureNested"], {"keep": True})
            self.assertIs(settings["power"]["instantRestart"], False)
            self.assertEqual(settings["power"]["futurePower"], "keep")
            self.assertEqual(settings["futureTop"], protected["futureTop"])
            for relative, payload in external.items():
                self.assertEqual((settings_path.parent / relative).read_bytes(), payload)
            self.assertEqual(plugin_sentinel.read_bytes(), b"do-not-touch\n")
            self.assertGreaterEqual(len(list((settings_path.parent / "backups").glob("*.bak"))), 4)

    def test_reset_reloads_latest_state_after_interactive_confirmation(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            install_omakase_roots(config_home)
            shell_path = config_home / "omarchy/shell.json"
            settings_path = config_home / "omarchy/lacuna/settings.json"
            shell_path.parent.mkdir(parents=True, exist_ok=True)
            settings_path.parent.mkdir(parents=True)
            shell_path.write_text('{"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[]}\n', encoding="utf-8")
            settings_path.write_text(
                '{"mediaProviders":{"jellyfin":{"apiKey":"old"}},"futureDuringConfirm":"old"}\n',
                encoding="utf-8",
            )

            def confirm_and_mutate(_prompt, _assume_yes):
                settings_path.write_text(
                    '{"mediaProviders":{"jellyfin":{"apiKey":"latest-secret"}},"futureDuringConfirm":{"keep":true}}\n',
                    encoding="utf-8",
                )
                return True

            args = module.argparse.Namespace(dry_run=False, yes=False)
            env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}
            with mock.patch.dict(module.os.environ, env), \
                mock.patch.object(module, "confirm", side_effect=confirm_and_mutate), \
                mock.patch.object(module, "run_command", return_value=0):
                self.assertEqual(module.reset(args), 0)

            settings = json.loads(settings_path.read_text(encoding="utf-8"))
            self.assertEqual(settings["mediaProviders"]["jellyfin"]["apiKey"], "latest-secret")
            self.assertEqual(settings["futureDuringConfirm"], {"keep": True})

    def test_reset_dry_run_validates_without_confirmation_or_mutation(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            install_omakase_roots(config_home)
            shell_path = config_home / "omarchy/shell.json"
            settings_path = config_home / "omarchy/lacuna/settings.json"
            shell_path.parent.mkdir(parents=True, exist_ok=True)
            settings_path.parent.mkdir(parents=True)
            shell_path.write_bytes(b'{"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[]}\n')
            settings_path.write_bytes(b'{"mediaProviders":{"jellyfin":{"apiKey":"keep"}}}\n')
            original = (shell_path.read_bytes(), settings_path.read_bytes())
            args = module.argparse.Namespace(dry_run=True, yes=False)
            env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}
            with mock.patch.dict(module.os.environ, env), mock.patch.object(module, "confirm", side_effect=AssertionError), mock.patch.object(module, "run_command") as run_command:
                self.assertEqual(module.reset(args), 0)
            self.assertEqual((shell_path.read_bytes(), settings_path.read_bytes()), original)
            run_command.assert_not_called()

    def test_reset_rejects_malformed_input_without_mutation(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            install_omakase_roots(config_home)
            shell_path = config_home / "omarchy/shell.json"
            settings_path = config_home / "omarchy/lacuna/settings.json"
            shell_path.parent.mkdir(parents=True, exist_ok=True)
            settings_path.parent.mkdir(parents=True)
            shell_path.write_bytes(b"{malformed\n")
            settings_path.write_bytes(b'{"keep":true}\n')
            original = (shell_path.read_bytes(), settings_path.read_bytes())
            args = module.argparse.Namespace(dry_run=False, yes=True)
            env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}
            with mock.patch.dict(module.os.environ, env), mock.patch.object(module, "run_command") as run_command:
                with self.assertRaises(SystemExit):
                    module.reset(args)
            self.assertEqual((shell_path.read_bytes(), settings_path.read_bytes()), original)
            run_command.assert_not_called()

    def test_reset_rejects_invalid_shell_shape_without_mutation(self):
        module = load_installer_module()
        for malformed_shell in (
            {"bar": "invalid", "plugins": []},
            {"bar": {"layout": []}, "plugins": []},
            {"bar": {"layout": {"left": [], "center": [], "right": []}}, "plugins": {}},
        ):
            with self.subTest(shell=malformed_shell), tempfile.TemporaryDirectory() as tmp:
                config_home = Path(tmp) / "config"
                install_omakase_roots(config_home)
                shell_path = config_home / "omarchy/shell.json"
                settings_path = config_home / "omarchy/lacuna/settings.json"
                shell_path.parent.mkdir(parents=True, exist_ok=True)
                settings_path.parent.mkdir(parents=True)
                shell_path.write_text(json.dumps(malformed_shell) + "\n", encoding="utf-8")
                settings_path.write_text('{"keep":true}\n', encoding="utf-8")
                original = (shell_path.read_bytes(), settings_path.read_bytes())
                args = module.argparse.Namespace(dry_run=False, yes=True)
                env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}
                with mock.patch.dict(module.os.environ, env), mock.patch.object(module, "run_command") as run_command:
                    with self.assertRaises(SystemExit):
                        module.reset(args)
                self.assertEqual((shell_path.read_bytes(), settings_path.read_bytes()), original)
                run_command.assert_not_called()

    def test_reset_preserves_absent_unowned_shell_version(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            install_omakase_roots(config_home)
            shell_path = config_home / "omarchy/shell.json"
            shell_path.parent.mkdir(parents=True, exist_ok=True)
            shell_path.write_text(
                '{"future":{"exact":[1,2]},"bar":{"position":"bottom","layout":{"left":[],"center":[],"right":[]}},"plugins":[]}\n',
                encoding="utf-8",
            )
            args = module.argparse.Namespace(dry_run=False, yes=True)
            env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}
            with mock.patch.dict(module.os.environ, env), mock.patch.object(module, "run_command", return_value=0):
                self.assertEqual(module.reset(args), 0)

            shell = json.loads(shell_path.read_text(encoding="utf-8"))
            self.assertNotIn("version", shell)
            self.assertEqual(shell["future"], {"exact": [1, 2]})
            self.assertEqual(shell["bar"]["position"], "bottom")

    def test_reset_reload_failure_restores_exact_bytes_and_modes(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            install_omakase_roots(config_home)
            shell_path = config_home / "omarchy/shell.json"
            settings_path = config_home / "omarchy/lacuna/settings.json"
            shell_path.parent.mkdir(parents=True, exist_ok=True)
            settings_path.parent.mkdir(parents=True)
            shell_path.write_bytes(b'{"future":1,"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[]}\n')
            settings_path.write_bytes(b'{"mediaProviders":{"youtube":{"cookiesFile":"secret"}}}\n')
            shell_path.chmod(0o640)
            settings_path.chmod(0o600)
            original = (shell_path.read_bytes(), shell_path.stat().st_mode & 0o7777, settings_path.read_bytes(), settings_path.stat().st_mode & 0o7777)
            args = module.argparse.Namespace(dry_run=False, yes=True)
            env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}
            with mock.patch.dict(module.os.environ, env), mock.patch.object(module, "run_command", return_value=19) as run_command:
                self.assertEqual(module.reset(args), 19)
            restored = (shell_path.read_bytes(), shell_path.stat().st_mode & 0o7777, settings_path.read_bytes(), settings_path.stat().st_mode & 0o7777)
            self.assertEqual(restored, original)
            self.assertEqual(run_command.call_count, 1)

    def test_reset_reload_oserror_restores_exact_bytes_and_modes(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            install_omakase_roots(config_home)
            shell_path = config_home / "omarchy/shell.json"
            settings_path = config_home / "omarchy/lacuna/settings.json"
            shell_path.parent.mkdir(parents=True, exist_ok=True)
            settings_path.parent.mkdir(parents=True)
            shell_path.write_bytes(b'{"future":2,"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[]}\n')
            settings_path.write_bytes(b'{"mediaProviders":{"youtube":{"cookiesFile":"secret"}},"future":true}\n')
            shell_path.chmod(0o640)
            settings_path.chmod(0o600)
            original = (shell_path.read_bytes(), shell_path.stat().st_mode & 0o7777, settings_path.read_bytes(), settings_path.stat().st_mode & 0o7777)
            args = module.argparse.Namespace(dry_run=False, yes=True)
            env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}
            with mock.patch.dict(module.os.environ, env), \
                mock.patch.object(module, "run_command", side_effect=FileNotFoundError("omarchy")) as run_command:
                self.assertEqual(module.reset(args), 1)
            restored = (shell_path.read_bytes(), shell_path.stat().st_mode & 0o7777, settings_path.read_bytes(), settings_path.stat().st_mode & 0o7777)
            self.assertEqual(restored, original)
            self.assertEqual(run_command.call_count, 1)

    def test_reset_requires_confirmation_and_has_no_purge_option(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            install_omakase_roots(config_home)
            shell_path = config_home / "omarchy/shell.json"
            shell_path.parent.mkdir(parents=True, exist_ok=True)
            shell_path.write_bytes(b'{"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[]}\n')
            original = shell_path.read_bytes()
            args = module.argparse.Namespace(dry_run=False, yes=False)
            env = {"XDG_CONFIG_HOME": str(config_home), "LACUNA_OMARCHY_CONFIG_HOME": str(config_home)}
            with mock.patch.dict(module.os.environ, env), mock.patch.object(module, "confirm", return_value=False) as confirm, mock.patch.object(module, "run_command") as run_command:
                self.assertEqual(module.reset(args), 1)
            self.assertEqual(shell_path.read_bytes(), original)
            confirm.assert_called_once()
            run_command.assert_not_called()
            with self.assertRaises(SystemExit):
                module.parser().parse_args(["reset", "--purge"])

    def test_status_reports_staged_vs_enabled_plugins(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            plugins_dir = config_home / "omarchy" / "plugins"
            for plugin_id in ("lacuna.clock", "lacuna.state"):
                target = plugins_dir / plugin_id
                target.mkdir(parents=True)
                (target / "manifest.json").write_text("{}", encoding="utf-8")

            shell_json = config_home / "omarchy" / "shell.json"
            shell_json.parent.mkdir(parents=True, exist_ok=True)
            shell_json.write_text(
                '{"version":1,"bar":{"layout":{"left":[],"center":[],"right":[{"id":"lacuna.clock"}]}},"plugins":[]}\n',
                encoding="utf-8",
            )

            result = run_lacuna(["status"], config_home=config_home)

        self.assertIn("lacuna.clock (enabled)", result.stdout)
        self.assertIn("lacuna.state (staged)", result.stdout)
        self.assertIn("installed unknown, repo 0.1.0", result.stdout)
        self.assertIn("Omarchy config:", result.stdout)
        self.assertIn("Settings migration: missing", result.stdout)
        self.assertIn("Sidebar monitor policy: auto", result.stdout)
        self.assertIn("Last installer operation: missing", result.stdout)
        self.assertIn("Core health: missing", result.stdout)
        self.assertIn("Recovery:", result.stdout)

    def test_mutation_records_completed_and_failed_operation_phase(self):
        module = load_installer_module()
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            args = module.argparse.Namespace(dry_run=False)
            with mock.patch.dict(module.os.environ, {
                "XDG_CONFIG_HOME": str(config_home),
                "LACUNA_OMARCHY_CONFIG_HOME": str(config_home),
            }):
                self.assertEqual(module.run_mutation(lambda _args: 0, args), 0)
                completed = module.json.loads(module.installer_status_path().read_text(encoding="utf-8"))
                self.assertEqual(module.run_mutation(lambda _args: 7, args), 7)
                failed = module.json.loads(module.installer_status_path().read_text(encoding="utf-8"))

            self.assertEqual(completed["phase"], "completed")
            self.assertEqual(completed["exitCode"], 0)
            self.assertEqual(failed["phase"], "failed")
            self.assertEqual(failed["exitCode"], 7)
            self.assertIn("omarchy plugin rescan", failed["recovery"])

    def test_update_dry_run_lists_only_changed_installed_plugins(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home = Path(tmp) / "config"
            plugins_dir = config_home / "omarchy" / "plugins"
            for plugin_id in ("lacuna.clock", "lacuna.state"):
                shutil.copytree(
                    ROOT / plugin_id,
                    plugins_dir / plugin_id,
                    ignore=shutil.ignore_patterns("__pycache__"),
                )

            widget = plugins_dir / "lacuna.clock" / "Widget.qml"
            widget.write_text(widget.read_text(encoding="utf-8") + "\n// local drift\n", encoding="utf-8")

            result = run_lacuna(["update", "--dry-run", "--yes"], config_home=config_home)

        self.assertIn("Update plan", result.stdout)
        self.assertIn("lacuna.clock", result.stdout)
        self.assertNotIn("lacuna.state", result.stdout)
        self.assertIn("Already current: 1 plugin(s)", result.stdout)
        self.assertIn("stage lacuna.clock ->", result.stdout)
        self.assertIn("omarchy plugin rescan", result.stdout)


if __name__ == "__main__":
    unittest.main()
