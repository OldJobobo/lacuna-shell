import fcntl
import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests" / "fixtures" / "full-settings.json"
BAR_SIZE_STATE = ROOT / "lacuna.bar-size-pill" / "scripts" / "bar-size-state"
COMPACT_STATE = ROOT / "lacuna.compact-pill" / "scripts" / "compact-state"
REFRESH_THEME_BACKGROUND = ROOT / "lacuna.theme-preloader" / "scripts" / "refresh-theme-background.sh"
SHELL_SETTINGS_STATE = ROOT / "lacuna.shell-settings" / "scripts" / "omarchy-shell-settings-state.py"

PRESERVED_KEYS = [
    "designStyles",
    "customQuickLaunchApps",
    "customQuickLaunchNames",
    "preferredApps",
    "sidebar",
    "frame",
]


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_module(path, name):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def seed_config(tmp_path):
    config_home = tmp_path / "config"
    settings_path = config_home / "omarchy" / "lacuna" / "settings.json"
    settings = read_json(FIXTURE)
    write_json(settings_path, settings)

    theme_dir = config_home / "omarchy" / "current" / "theme"
    theme_dir.mkdir(parents=True, exist_ok=True)
    (config_home / "omarchy" / "current" / "theme.name").write_text("fixture-theme\n", encoding="utf-8")
    (theme_dir / "colors.toml").write_text("[colors]\n", encoding="utf-8")
    (theme_dir / "shell.toml").write_text(
        "[bar]\nsize-horizontal = 30\nsize-vertical = 32\n",
        encoding="utf-8",
    )

    omarchy_path = tmp_path / "omarchy"
    (omarchy_path / "bin").mkdir(parents=True, exist_ok=True)

    return config_home, omarchy_path, settings_path, settings


def env_for(config_home, omarchy_path):
    env = os.environ.copy()
    env["XDG_CONFIG_HOME"] = str(config_home)
    env["OMARCHY_PATH"] = str(omarchy_path)
    return env


def run_script(script, action, config_home, omarchy_path):
    return subprocess.run(
        [sys.executable, str(script), action],
        check=True,
        env=env_for(config_home, omarchy_path),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def run_shell_script(script, args, config_home, omarchy_path, extra_env=None):
    env = env_for(config_home, omarchy_path)
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        [str(script)] + list(args),
        check=True,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def assert_preserved(testcase, before, after):
    for key in PRESERVED_KEYS:
        testcase.assertEqual(after[key], before[key], key)


class StateScriptTests(unittest.TestCase):
    def test_shell_settings_state_uses_direct_subprocess_capture(self):
        script = SHELL_SETTINGS_STATE.read_text(encoding="utf-8")

        self.assertIn("shlex.split(command)", script)
        self.assertIn("stderr=subprocess.DEVNULL", script)
        self.assertIn("start_new_session=True", script)
        self.assertIn("os.killpg(proc.pid, signal.SIGTERM)", script)
        self.assertIn("fcntl.LOCK_EX | fcntl.LOCK_NB", script)
        self.assertNotIn('["bash", "-lc"', script)
        self.assertNotIn("NamedTemporaryFile", script)
        self.assertNotIn("omarchy-shell notifications isDnd", script)
        self.assertIn("omarchy toggle nightlight --status", script)
        self.assertIn("isinstance(parsed.get(\"enabled\"), bool)", script)
        self.assertIn("int(match.group(0)) < 6000", script)

    def test_shell_settings_state_reports_window_rounding_override_mode(self):
        module = load_module(SHELL_SETTINGS_STATE, "shell_settings_state_rounding_mode_test")
        option_values = {
            "general:gaps_in": "css gap data: 4",
            "general:gaps_out": "css gap data: 8",
            "general:border_size": "int: 2",
            "decoration:rounding": "int: 9",
            "layout:single_window_aspect_ratio": "vec2: 0 0",
        }

        with tempfile.TemporaryDirectory() as tmp:
            toggles_dir = Path(tmp)
            hypr_dir = toggles_dir / "hypr"
            hypr_dir.mkdir()
            with mock.patch.object(module, "hypr_option", side_effect=lambda name: option_values[name]):
                themed = module.hypr_state(str(toggles_dir))
                self.assertEqual("theme", themed["windowRoundingMode"])
                self.assertFalse(themed["windowRoundingOverride"])
                self.assertEqual(-1, themed["windowRoundingOverrideRadius"])
                self.assertTrue(themed["roundedWindows"])

                stock_no_gaps = hypr_dir / "window-no-gaps.lua"
                stock_no_gaps.write_text("hl.config({ decoration = { rounding = 0 } })\n", encoding="utf-8")
                stock_square = module.hypr_state(str(toggles_dir))
                self.assertEqual("square", stock_square["windowRoundingMode"])
                self.assertFalse(stock_square["windowRoundingOverride"])
                self.assertEqual(-1, stock_square["windowRoundingOverrideRadius"])
                stock_no_gaps.unlink()

                override = hypr_dir / "zz-lacuna-window-rounded.lua"
                override.write_text("hl.config({\n  decoration = {\n    rounding = 0,\n  },\n})\n", encoding="utf-8")
                square = module.hypr_state(str(toggles_dir))
                self.assertEqual("square", square["windowRoundingMode"])
                self.assertTrue(square["windowRoundingOverride"])
                self.assertEqual(0, square["windowRoundingOverrideRadius"])

                override.write_text("hl.config({\n  decoration = {\n    rounding = 12,\n  },\n})\n", encoding="utf-8")
                rounded = module.hypr_state(str(toggles_dir))
                self.assertEqual("rounded", rounded["windowRoundingMode"])
                self.assertTrue(rounded["windowRoundingOverride"])
                self.assertEqual(12, rounded["windowRoundingOverrideRadius"])

    def test_shell_settings_state_lock_is_global_single_flight(self):
        module = load_module(SHELL_SETTINGS_STATE, "shell_settings_state_lock_test")
        with tempfile.TemporaryDirectory() as tmp:
            lock_path = Path(tmp) / "state.lock"
            old = os.environ.get("LACUNA_SHELL_SETTINGS_LOCK")
            os.environ["LACUNA_SHELL_SETTINGS_LOCK"] = str(lock_path)
            try:
                self.assertTrue(module.acquire_single_flight_lock())
                second = load_module(SHELL_SETTINGS_STATE, "shell_settings_state_second_lock_test")
                self.assertFalse(second.acquire_single_flight_lock())
            finally:
                if old is None:
                    os.environ.pop("LACUNA_SHELL_SETTINGS_LOCK", None)
                else:
                    os.environ["LACUNA_SHELL_SETTINGS_LOCK"] = old

    def test_shell_settings_state_timeout_kills_descendant_process_group(self):
        module = load_module(SHELL_SETTINGS_STATE, "shell_settings_state_timeout_test")
        with tempfile.TemporaryDirectory() as tmp:
            pid_file = Path(tmp) / "child.pid"
            command = [
                "bash",
                "-c",
                f"sleep 30 & child=$!; printf '%s' \"$child\" > {pid_file}; wait",
            ]
            self.assertEqual("", module.run(command, timeout=0.2))
            self.assertTrue(pid_file.exists())
            status_path = Path("/proc", pid_file.read_text(), "status")
            state = None
            for _ in range(20):
                if not status_path.exists():
                    state = None
                    break
                status = status_path.read_text(encoding="utf-8")
                state_line = next((line for line in status.splitlines() if line.startswith("State:")), "")
                state = state_line.split()[1] if len(state_line.split()) > 1 else ""
                if state == "Z":
                    break
                time.sleep(0.05)
            # A zombie has terminated and cannot consume CPU or spawn work. It
            # may remain visible under container PID 1 because GitHub's runner
            # does not guarantee prompt orphan reaping.
            self.assertIn(state, (None, "Z"))

    def test_bar_size_state_preserves_user_runtime_state_on_toggle(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home, omarchy_path, settings_path, before = seed_config(Path(tmp))

            result = run_script(BAR_SIZE_STATE, "compact", config_home, omarchy_path)
            payload = json.loads(result.stdout)
            after = read_json(settings_path)

            self.assertEqual(payload["mode"], "compact")
            self.assertEqual(after["barSizeMode"], "compact")
            self.assertIs(after["compact"], True)
            self.assertGreater(after["sizeTransition"]["holdUntil"], 0)
            assert_preserved(self, before, after)

    def test_bar_size_state_merges_owned_keys_into_fresh_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home, omarchy_path, settings_path, before = seed_config(Path(tmp))
            old_config = os.environ.get("XDG_CONFIG_HOME")
            old_omarchy = os.environ.get("OMARCHY_PATH")
            os.environ["XDG_CONFIG_HOME"] = str(config_home)
            os.environ["OMARCHY_PATH"] = str(omarchy_path)
            try:
                module = load_module(BAR_SIZE_STATE, "bar_size_state_merge_test")
                stale = module.load_settings()
                concurrent = read_json(settings_path)
                concurrent["preferredApps"]["editor"] = "concurrent-editor"
                concurrent["futureSetting"] = {"preserve": True}
                write_json(settings_path, concurrent)
                legacy_tmp = settings_path.with_suffix(".json.tmp")
                legacy_tmp.write_text("do-not-touch\n", encoding="utf-8")

                stale["barSizeMode"] = "compact"
                stale["compact"] = True
                stale["sizeTransition"] = {"holdCompact": False, "holdUntil": 123}
                with module.settings_transaction():
                    merged = module.save_settings(stale)
            finally:
                if old_config is None:
                    os.environ.pop("XDG_CONFIG_HOME", None)
                else:
                    os.environ["XDG_CONFIG_HOME"] = old_config
                if old_omarchy is None:
                    os.environ.pop("OMARCHY_PATH", None)
                else:
                    os.environ["OMARCHY_PATH"] = old_omarchy

            after = read_json(settings_path)
            self.assertEqual(after["preferredApps"]["editor"], "concurrent-editor")
            self.assertEqual(after["futureSetting"], {"preserve": True})
            self.assertEqual(after["barSizeMode"], "compact")
            self.assertTrue(after["compact"])
            self.assertEqual(merged, after)
            self.assertEqual(legacy_tmp.read_text(encoding="utf-8"), "do-not-touch\n")

    def test_bar_size_state_routes_live_commit_through_state_service(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home, omarchy_path, _settings_path, _before = seed_config(Path(tmp))
            old_config = os.environ.get("XDG_CONFIG_HOME")
            old_omarchy = os.environ.get("OMARCHY_PATH")
            os.environ["XDG_CONFIG_HOME"] = str(config_home)
            os.environ["OMARCHY_PATH"] = str(omarchy_path)
            try:
                module = load_module(BAR_SIZE_STATE, "bar_size_state_ipc_test")
                expected = module.load_settings()
                expected["barSizeMode"] = "compact"
                expected["compact"] = True
                status = subprocess.CompletedProcess(
                    [], 0, json.dumps({"ready": True, "settingsFile": str(module.SETTINGS_PATH)}) + "\n", ""
                )
                committed = subprocess.CompletedProcess(
                    [], 0, json.dumps({"ok": True, "data": expected}) + "\n", ""
                )
                with mock.patch.object(module.subprocess, "run", side_effect=[status, committed]) as run:
                    result = module.save_settings_via_state_service(expected)
            finally:
                if old_config is None:
                    os.environ.pop("XDG_CONFIG_HOME", None)
                else:
                    os.environ["XDG_CONFIG_HOME"] = old_config
                if old_omarchy is None:
                    os.environ.pop("OMARCHY_PATH", None)
                else:
                    os.environ["OMARCHY_PATH"] = old_omarchy

            self.assertEqual(result, expected)
            self.assertEqual(run.call_args_list[0].args[0][-1], "status")
            self.assertEqual(run.call_args_list[1].args[0][1:3], ["lacuna-settings-state", "patchBarSize"])
            patch = json.loads(run.call_args_list[1].args[0][3])
            self.assertEqual(set(patch["keys"]), {"barSizeMode", "compact", "barSizeSnapshot", "sizeTransition"})

    def test_bar_size_state_serializes_mutating_processes(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home, omarchy_path, _settings_path, _before = seed_config(Path(tmp))
            lock_path = config_home / "omarchy" / "lacuna" / "settings.lock"
            lock_path.parent.mkdir(parents=True, exist_ok=True)
            with lock_path.open("w") as lock_file:
                fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
                proc = subprocess.Popen(
                    [sys.executable, str(BAR_SIZE_STATE), "compact"],
                    env=env_for(config_home, omarchy_path),
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                try:
                    time.sleep(0.15)
                    self.assertIsNone(proc.poll(), "bar-size writer bypassed the settings lock")
                finally:
                    fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
                stdout, stderr = proc.communicate(timeout=5)
            self.assertEqual(proc.returncode, 0, stderr)
            self.assertEqual(json.loads(stdout)["mode"], "compact")

    def test_bar_size_state_restores_theme_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home, omarchy_path, settings_path, before = seed_config(Path(tmp))
            shell_path = config_home / "omarchy" / "current" / "theme" / "shell.toml"

            compact_result = run_script(BAR_SIZE_STATE, "compact", config_home, omarchy_path)
            compact_payload = json.loads(compact_result.stdout)
            self.assertEqual(compact_payload["mode"], "compact")
            self.assertIn("size-horizontal = 26", shell_path.read_text(encoding="utf-8"))
            self.assertIn("size-vertical = 28", shell_path.read_text(encoding="utf-8"))

            theme_result = run_script(BAR_SIZE_STATE, "theme", config_home, omarchy_path)
            theme_payload = json.loads(theme_result.stdout)
            after = read_json(settings_path)
            shell = shell_path.read_text(encoding="utf-8")

        self.assertEqual(theme_payload["mode"], "theme")
        self.assertEqual(after["barSizeMode"], "theme")
        self.assertIs(after["compact"], False)
        self.assertIsNone(after["barSizeSnapshot"])
        self.assertIn("size-horizontal = 30", shell)
        self.assertIn("size-vertical = 32", shell)
        assert_preserved(self, before, after)

    def test_bar_size_state_reapplies_saved_user_mode_after_theme_change(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home, omarchy_path, settings_path, before = seed_config(Path(tmp))
            shell_path = config_home / "omarchy" / "current" / "theme" / "shell.toml"
            settings = read_json(settings_path)
            settings["barSizeMode"] = "full"
            settings["compact"] = False
            settings["barSizeSnapshot"] = {
                "themeName": "previous-theme",
                "sizeHorizontal": 26,
                "sizeVertical": 28,
            }
            write_json(settings_path, settings)
            (config_home / "omarchy" / "current" / "theme.name").write_text("next-theme\n", encoding="utf-8")
            shell_path.write_text("[bar]\nsize-horizontal = 26\nsize-vertical = 28\n", encoding="utf-8")

            result = run_script(BAR_SIZE_STATE, "reapply", config_home, omarchy_path)
            payload = json.loads(result.stdout)
            after = read_json(settings_path)
            shell = shell_path.read_text(encoding="utf-8")

        self.assertEqual(payload["mode"], "full")
        self.assertEqual(after["barSizeMode"], "full")
        self.assertIs(after["compact"], False)
        self.assertEqual(after["barSizeSnapshot"]["themeName"], "next-theme")
        self.assertIn("size-horizontal = 32", shell)
        self.assertIn("size-vertical = 34", shell)
        assert_preserved(self, before, after)

    def test_compact_state_preserves_user_runtime_state_without_delegate(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home, omarchy_path, settings_path, before = seed_config(Path(tmp))

            result = run_script(COMPACT_STATE, "toggle", config_home, omarchy_path)
            payload = json.loads(result.stdout)
            after = read_json(settings_path)

            self.assertIs(payload["compact"], True)
            self.assertEqual(after["barSizeMode"], "compact")
            self.assertIs(after["compact"], True)
            self.assertGreater(after["sizeTransition"]["holdUntil"], 0)
            assert_preserved(self, before, after)

    def test_compact_state_delegates_to_bar_size_state_and_preserves_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            config_home, omarchy_path, settings_path, before = seed_config(Path(tmp))
            delegated = config_home / "omarchy" / "plugins" / "lacuna.bar-size-pill" / "scripts" / "bar-size-state"
            delegated.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(BAR_SIZE_STATE, delegated)

            result = run_script(COMPACT_STATE, "compact", config_home, omarchy_path)
            payload = json.loads(result.stdout)
            after = read_json(settings_path)

            self.assertIs(payload["compact"], True)
            self.assertEqual(after["barSizeMode"], "compact")
            assert_preserved(self, before, after)

    def test_theme_background_refresh_relinks_reused_current_theme_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            config_home, omarchy_path, _settings_path, _before = seed_config(tmp_path)
            theme_name = "fixture-theme"
            state_home = tmp_path / "state"
            current_background = state_home / "omarchy" / "current" / "theme" / "backgrounds" / "same-name.jpg"
            source_background = config_home / "omarchy" / "themes" / theme_name / "backgrounds" / "same-name.jpg"
            current_background.parent.mkdir(parents=True, exist_ok=True)
            source_background.parent.mkdir(parents=True, exist_ok=True)
            current_background.write_bytes(b"old-current-copy")
            source_background.write_bytes(b"new-source-image")
            background_link = state_home / "omarchy" / "current" / "background"
            background_link.symlink_to(current_background)

            fake_bin = tmp_path / "bin"
            fake_bin.mkdir()
            shell_log = tmp_path / "omarchy-shell.log"
            fake_omarchy_shell = fake_bin / "omarchy-shell"
            fake_omarchy_shell.write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\n' \"$*\" >> \"$OMARCHY_SHELL_LOG\"\n",
                encoding="utf-8",
            )
            fake_omarchy_shell.chmod(0o755)

            run_shell_script(
                REFRESH_THEME_BACKGROUND,
                [theme_name],
                config_home,
                omarchy_path,
                {
                    "PATH": str(fake_bin) + os.pathsep + os.environ.get("PATH", ""),
                    "OMARCHY_SHELL_LOG": str(shell_log),
                    "XDG_STATE_HOME": str(state_home),
                },
            )

            self.assertEqual(background_link.resolve(), source_background)
            self.assertIn("-q background set " + str(source_background), shell_log.read_text(encoding="utf-8"))
