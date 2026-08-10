from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SETTINGS = Path.home() / ".config/omarchy/lacuna/settings.json"
ENABLED = os.environ.get("LACUNA_LIVE_VISUAL") == "1"
MEDIA_TEST_URL = os.environ.get("LACUNA_LIVE_MEDIA_TEST_URL", "").strip()
MEDIA_SWITCH_URL = os.environ.get("LACUNA_LIVE_MEDIA_SWITCH_URL", "").strip()
MEDIA_FAILURE_URL = os.environ.get("LACUNA_LIVE_MEDIA_FAILURE_URL", "").strip()
REQUIRED_TOOLS = ("hyprctl", "grim", "magick", "omarchy")
HAVE_TOOLS = all(shutil.which(tool) for tool in REQUIRED_TOOLS)


def run(command: list[str], *, timeout: int = 30) -> str:
    proc = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    if proc.returncode != 0:
        raise AssertionError(f"{command} failed\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")
    return proc.stdout


def read_settings() -> dict:
    return json.loads(SETTINGS.read_text(encoding="utf-8"))


def write_settings(data: dict) -> None:
    SETTINGS.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def set_frame_mode(mode: str) -> None:
    data = read_settings()
    data.setdefault("frame", {})["mode"] = mode
    write_settings(data)
    run(["omarchy", "restart", "shell"], timeout=60)
    time.sleep(0.5)


def set_portrait_split(enabled: bool) -> None:
    data = read_settings()
    data.setdefault("barPresentation", {})["portraitSplit"] = enabled
    write_settings(data)
    # Exercise the live Variants model update. Restarting here would only
    # validate startup state and miss an unsafe same-session remap.
    time.sleep(0.75)


def set_reduce_motion(enabled: bool) -> None:
    data = read_settings()
    data["reduceMotion"] = enabled
    write_settings(data)
    run(["omarchy", "restart", "shell"], timeout=60)
    time.sleep(0.5)


def set_molding_geometry(style: str, corner_mode: str, radius: int = 14) -> dict:
    data = read_settings()
    data["version"] = 3
    data["designStyle"] = style
    geometry = data.setdefault("geometry", {})
    geometry["cornerMode"] = corner_mode
    geometry["cornerRadius"] = radius
    # Keep the rollback alias coherent without touching the deprecated trim
    # booleans: universal corners are their sole runtime owner.
    data.setdefault("frame", {})["radius"] = 0 if corner_mode == "square" else radius
    write_settings(data)
    run(["omarchy", "restart", "shell"], timeout=60)
    deadline = time.monotonic() + 15
    last_error = None
    while time.monotonic() < deadline:
        try:
            status = json.loads(run(["omarchy-shell", "lacuna-settings-state", "status"]))
            time.sleep(0.75)
            # The restart helper can briefly expose IPC before every plugin is
            # registered; require the state target to remain available.
            json.loads(run(["omarchy-shell", "lacuna-settings-state", "status"]))
            return status
        except (AssertionError, json.JSONDecodeError) as error:
            last_error = error
            time.sleep(0.25)
    raise AssertionError(f"lacuna settings IPC did not recover after shell restart: {last_error}")


def summon_menu(flyout: str) -> None:
    run(["omarchy-shell", "shell", "summon", "lacuna.menu", json.dumps({"flyout": flyout})])


def lacuna_layers() -> dict[str, list[str]]:
    data = json.loads(run(["hyprctl", "-j", "layers"]))
    result: dict[str, list[str]] = {}
    for screen, payload in data.items():
        names: list[str] = []
        for level in sorted(payload.get("levels", {}), key=lambda value: int(value)):
            for item in payload["levels"][level]:
                namespace = item.get("namespace", "")
                if namespace in {"omarchy-bar", "lacuna-bar-portrait-companion", "lacuna-bar-frame"}:
                    names.append(f"{level}:{namespace}")
        result[screen] = names
    return result


def menu_frame_layers() -> dict[str, list[str]]:
    data = json.loads(run(["hyprctl", "-j", "layers"]))
    result: dict[str, list[str]] = {}
    for screen, payload in data.items():
        names: list[str] = []
        for level in sorted(payload.get("levels", {}), key=lambda value: int(value)):
            for item in payload["levels"][level]:
                namespace = item.get("namespace", "")
                if namespace == "lacuna-bar-frame" or namespace.startswith("lacuna.menu-menu-"):
                    names.append(f"{level}:{namespace}")
        result[screen] = names
    return result


def ambience_layers() -> dict[str, list[str]]:
    data = json.loads(run(["hyprctl", "-j", "layers"]))
    result: dict[str, list[str]] = {}
    for screen, payload in data.items():
        names: list[str] = []
        for level in sorted(payload.get("levels", {}), key=lambda value: int(value)):
            for item in payload["levels"][level]:
                namespace = item.get("namespace", "")
                if namespace in {"lacuna-ambience-host-bottom", "lacuna-ambience-host-overlay"}:
                    names.append(f"{level}:{namespace}")
        result[screen] = names
    return result


def wait_for_frame_layers() -> dict[str, list[str]]:
    deadline = time.time() + 8
    last: dict[str, list[str]] = {}
    stable_count = 0
    while time.time() < deadline:
        current = lacuna_layers()
        ready = bool(current) and all("2:lacuna-bar-frame" in names for names in current.values())
        if ready and current == last:
            stable_count += 1
            if stable_count >= 2:
                return current
        else:
            stable_count = 0
        last = current
        time.sleep(0.25)
    return last


def media_ipc(method: str, *args: str) -> dict:
    output = run(["omarchy-shell", "lacuna-media-player", method, *args], timeout=60)
    return json.loads(output)


def media_video_status() -> dict:
    return json.loads(run(["omarchy-shell", "lacuna-media-player-video", "status"], timeout=30))


def wait_for_media(predicate, timeout: float = 30) -> tuple[dict, dict]:
    deadline = time.time() + timeout
    service: dict = {}
    video: dict = {}
    while time.time() < deadline:
        service = media_ipc("status")
        video = media_video_status()
        if predicate(service, video):
            return service, video
        time.sleep(0.2)
    return service, video


def pixel_luma(image: Path, x: int, y: int) -> float:
    out = run(["magick", str(image), "-format", f"%[pixel:p{{{x},{y}}}]", "info:"]).strip()
    values = [int(part) for part in out[out.find("(") + 1 : out.find(")")].split(",")[:3]]
    return (values[0] * 0.2126) + (values[1] * 0.7152) + (values[2] * 0.0722)


@unittest.skipUnless(ENABLED and HAVE_TOOLS and SETTINGS.exists(), "set LACUNA_LIVE_VISUAL=1 with hyprctl/grim/magick/omarchy to run")
class LiveVisualTests(unittest.TestCase):
    def setUp(self):
        self.original = read_settings()

    def tearDown(self):
        write_settings(self.original)
        run(["omarchy", "restart", "shell"], timeout=60)

    def test_frame_mode_toggle_preserves_layer_order(self):
        set_frame_mode("off")
        off_layers = wait_for_frame_layers()
        self.assertTrue(any("2:lacuna-bar-frame" in names for names in off_layers.values()), off_layers)
        self.assertTrue(all("3:lacuna-bar-frame-border" not in names for names in off_layers.values()), off_layers)

        set_frame_mode("fullframe")
        full_layers = wait_for_frame_layers()
        self.assertEqual(full_layers, off_layers)

        set_frame_mode("off")
        self.assertEqual(wait_for_frame_layers(), off_layers)

    def test_attached_flyout_surface_stays_above_fullframe_shadow(self):
        set_frame_mode("fullframe")
        summon_menu("settings")
        time.sleep(0.75)

        layers = menu_frame_layers()
        hosted = [names for names in layers.values()
                  if any("lacuna.menu-menu-" in name for name in names)]
        self.assertTrue(hosted, layers)
        for names in hosted:
            self.assertIn("2:lacuna-bar-frame", names)
            self.assertTrue(any(name.startswith("3:lacuna.menu-menu-") for name in names), names)
            self.assertFalse(any(name.startswith("2:lacuna.menu-menu-") for name in names), names)

    def test_portrait_companion_exists_only_on_effective_outputs(self):
        set_portrait_split(False)
        disabled_layers = wait_for_frame_layers()
        self.assertTrue(disabled_layers)
        self.assertTrue(all("2:lacuna-bar-portrait-companion" not in names for names in disabled_layers.values()))

        monitors = json.loads(run(["hyprctl", "-j", "monitors"]))
        portrait_names = set()
        for monitor in monitors:
            width = float(monitor.get("width", 0))
            height = float(monitor.get("height", 0))
            if int(monitor.get("transform", 0)) in {1, 3, 5, 7}:
                width, height = height, width
            if height > width:
                portrait_names.add(str(monitor.get("name", "")))
        set_portrait_split(True)
        time.sleep(0.75)
        enabled_layers = wait_for_frame_layers()
        for screen, names in enabled_layers.items():
            self.assertEqual("2:lacuna-bar-portrait-companion" in names, screen in portrait_names, enabled_layers)

    def test_top_bar_rows_are_not_overpainted_by_fullframe_toggle(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            off_image = tmp_path / "off.png"
            full_image = tmp_path / "full.png"
            set_frame_mode("off")
            wait_for_frame_layers()
            run(["grim", str(off_image)])
            set_frame_mode("fullframe")
            wait_for_frame_layers()
            run(["grim", str(full_image)])

            # Compare stable top-bar pixels rather than golden images. The bar
            # strip itself should not be overpainted by enabling full frame.
            for x in (200, 800, 1400):
                for y in (4, 16, 28):
                    self.assertAlmostEqual(pixel_luma(off_image, x, y), pixel_luma(full_image, x, y), delta=12.0)

            # A row just below the bar should be darker than the deep content
            # row when the shadow is active, showing a flush bar-edge shadow.
            for image in (off_image, full_image):
                edge = pixel_luma(image, 960, 34)
                deep = pixel_luma(image, 960, 52)
                self.assertLess(edge, deep + 8)

    def test_ambience_reorder_changes_pixels_without_remapping_host_surfaces(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            first_image = root / "crt-front.png"
            second_image = root / "vhs-front.png"
            data = read_settings()
            data["reduceMotion"] = True
            effects = data.setdefault("backgroundEffects", {})
            effects["enabled"] = True
            effects["opacity"] = 1
            effects["foregroundOverlay"] = False
            effects["activeEffects"] = ["crt", "trackingLines"]
            effects["activeEffect"] = "crt"
            effects.setdefault("effects", {}).setdefault("crt", {})["enabled"] = True
            effects["effects"].setdefault("trackingLines", {})["enabled"] = True
            write_settings(data)
            time.sleep(0.8)
            layers_before = ambience_layers()
            self.assertTrue(layers_before)
            self.assertTrue(all(names == ["1:lacuna-ambience-host-bottom"] for names in layers_before.values()), layers_before)
            run(["grim", str(first_image)])

            effects["activeEffects"] = ["trackingLines", "crt"]
            effects["activeEffect"] = "trackingLines"
            write_settings(data)
            time.sleep(0.8)
            self.assertEqual(ambience_layers(), layers_before)
            run(["grim", str(second_image)])

            comparison = subprocess.run(
                ["magick", "compare", "-metric", "RMSE", str(first_image), str(second_image), "null:"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertIn(comparison.returncode, (0, 1), comparison.stderr)
            normalized = float(comparison.stderr.split("(", 1)[1].split(")", 1)[0])
            self.assertGreater(normalized, 0.0005, comparison.stderr)

            effects["foregroundOverlay"] = True
            write_settings(data)
            time.sleep(0.8)
            foreground_layers = ambience_layers()
            self.assertTrue(all(names == ["3:lacuna-ambience-host-overlay"] for names in foreground_layers.values()), foreground_layers)

            effects["enabled"] = False
            write_settings(data)
            time.sleep(0.8)
            self.assertTrue(all(not names for names in ambience_layers().values()))

    @unittest.skipUnless(MEDIA_TEST_URL, "set LACUNA_LIVE_MEDIA_TEST_URL to an explicit non-secret test video URL")
    def test_media_background_handoffs_are_bounded_and_cleanup(self):
        original = media_ipc("status")
        original_mode = str(original.get("presentationMode") or "auto")
        try:
            # Force a true cold renderer start without consulting favorites or
            # any persisted user URL.
            media_ipc("stop")
            media_ipc("playUrl", MEDIA_TEST_URL)
            playing, _ = wait_for_media(lambda service, video: service.get("playing") is True, 30)
            self.assertTrue(playing.get("playing"), playing)

            media_ipc("setPresentationMode", "background")
            service, video = wait_for_media(
                lambda current, surface: current.get("presentationState") == "background"
                and surface.get("wallpaperRunning") is True,
                45,
            )
            self.assertEqual(service.get("presentationState"), "background", service)
            self.assertTrue(video.get("wallpaperRunning"), video)
            self.assertFalse(service.get("rendererHandoffDeadlineActive"), service)
            first_source_revision = int(video.get("sourceRevision") or 0)
            self.assertGreater(first_source_revision, 0, video)
            self.assertEqual(len(video.get("outputDiagnostics", {}).get("outputs", [])), int(video.get("expectedPlayerCount") or 0))
            cold_cover_age_ms = float(video.get("fadeCoverAgeMs") or 0)
            self.assertLess(cold_cover_age_ms, 8000, video)
            self.assertNotIn("googlevideo.com", str(video.get("wallpaperPositionRefreshKey") or ""))

            if MEDIA_SWITCH_URL:
                media_ipc("playUrl", MEDIA_SWITCH_URL)
                switched_service, switched_video = wait_for_media(
                    lambda current, surface: current.get("presentationState") == "background"
                    and surface.get("wallpaperRunning") is True
                    and int(surface.get("sourceRevision") or 0) > first_source_revision
                    and float(surface.get("fadeCoverOpacity") or 0) < 0.999,
                    45,
                )
                self.assertFalse(switched_service.get("rendererHandoffDeadlineActive"), switched_service)
                switch_cover_age_ms = float(switched_video.get("fadeCoverAgeMs") or 0)
                self.assertLess(switch_cover_age_ms, 8000, switched_video)
                first_source_revision = int(switched_video.get("sourceRevision") or 0)

            media_ipc("setPresentationMode", "inline")
            inline, inline_video = wait_for_media(
                lambda current, surface: current.get("presentationState") == "inline"
                and surface.get("wallpaperRunning") is False,
                15,
            )
            self.assertEqual(inline.get("presentationState"), "inline", inline)
            self.assertFalse(inline_video.get("wallpaperRunning"), inline_video)

            media_ipc("setPresentationMode", "background")
            service, video = wait_for_media(
                lambda current, surface: current.get("presentationState") == "background"
                and surface.get("wallpaperRunning") is True,
                30,
            )
            self.assertGreater(int(video.get("sourceRevision") or 0), first_source_revision, video)
            self.assertLess(float(video.get("fadeCoverOpacity") or 0), 0.999, video)
        finally:
            try:
                stopped = media_ipc("stop")
                self.assertFalse(stopped.get("playing"), stopped)
                self.assertEqual(float(stopped.get("playbackPosition") or 0), 0)
            finally:
                try:
                    media_ipc("setPresentationMode", original_mode)
                    restored, _ = wait_for_media(
                        lambda current, surface: current.get("presentationMode") == original_mode, 5
                    )
                    self.assertEqual(restored.get("presentationMode"), original_mode, restored)
                    # Allow the service's debounced state writer to commit the
                    # restored preference before tearDown restarts the shell.
                    time.sleep(0.35)
                finally:
                    _, stopped_video = wait_for_media(
                        lambda current, surface: surface.get("wallpaperRunning") is False, 10
                    )
                    self.assertFalse(stopped_video.get("wallpaperRunning"), stopped_video)

    @unittest.skipUnless(MEDIA_FAILURE_URL, "set LACUNA_LIVE_MEDIA_FAILURE_URL to an explicit failing test URL")
    def test_media_failure_exit_cannot_leave_black_cover(self):
        original_mode = str(media_ipc("status").get("presentationMode") or "auto")
        try:
            media_ipc("playUrl", MEDIA_FAILURE_URL)
            media_ipc("setPresentationMode", "background")
            service, video = wait_for_media(
                lambda current, surface: current.get("presentationState") in {"inline", "recovering"}
                and current.get("rendererHandoffDeadlineActive") is False
                and surface.get("wallpaperRunning") is False
                and float(surface.get("fadeCoverOpacity") or 0) < 0.001,
                45,
            )
            self.assertFalse(service.get("rendererHandoffDeadlineActive"), service)
            self.assertFalse(video.get("wallpaperRunning"), video)
            self.assertLess(float(video.get("fadeCoverOpacity") or 0), 0.001, video)
        finally:
            try:
                media_ipc("stop")
            finally:
                try:
                    media_ipc("setPresentationMode", original_mode)
                    restored, _ = wait_for_media(
                        lambda current, surface: current.get("presentationMode") == original_mode, 5
                    )
                    self.assertEqual(restored.get("presentationMode"), original_mode, restored)
                    time.sleep(0.35)
                finally:
                    _, stopped_video = wait_for_media(
                        lambda current, surface: surface.get("wallpaperRunning") is False
                        and float(surface.get("fadeCoverOpacity") or 0) < 0.001,
                        10,
                    )
                    self.assertFalse(stopped_video.get("wallpaperRunning"), stopped_video)

    def test_universal_corner_trim_visual_matrix(self):
        # Capture zero/positive universal corner states and every design style.
        # tearDown restores the exact pre-test settings document, including its
        # schema version and any provider credentials not inspected here.
        cases = (
            ("lacuna-theme", "lacuna", "theme", 14),
            ("lacuna-square", "lacuna", "square", 14),
            ("lacuna-custom-zero", "lacuna", "custom", 0),
            ("lacuna-custom", "lacuna", "custom", 9),
            ("omarchy", "omarchy", "theme", 14),
            ("material", "material", "theme", 14),
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, style, corner_mode, radius in cases:
                status = set_molding_geometry(style, corner_mode, radius)
                self.assertEqual(3, status.get("schemaVersion"), status)
                self.assertEqual(corner_mode, status.get("cornerMode"), status)
                self.assertEqual(radius, status.get("cornerRadius"), status)
                if corner_mode in {"square", "custom"}:
                    hypr_rounding = json.loads(run(["hyprctl", "-j", "getoption", "decoration:rounding"]))
                    expected_rounding = 0 if corner_mode == "square" else radius
                    self.assertEqual(expected_rounding, hypr_rounding.get("int"), hypr_rounding)
                else:
                    rounding_override = Path.home() / ".local/state/omarchy/toggles/hypr/zz-lacuna-window-rounded.lua"
                    self.assertFalse(rounding_override.exists(), rounding_override)
                summon_menu("settings")
                time.sleep(0.45)
                image = root / f"{name}.png"
                run(["grim", str(image)])
                self.assertGreater(image.stat().st_size, 0, name)

    def test_bar_flyout_universal_corner_visual_matrix(self):
        cases = (("square", 0), ("custom", 17), ("theme", 14))
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for mode, radius in cases:
                set_molding_geometry("lacuna", mode, radius)
                run(["omarchy-shell", "shell", "summon", "lacuna.clock", "{}"])
                time.sleep(0.65)
                image = root / f"bar-flyout-{mode}.png"
                run(["grim", str(image)])
                self.assertGreater(image.stat().st_size, 0, mode)

    def test_transition_pipeline_smoke_states(self):
        # This is intentionally opt-in: it exercises the real menu surface,
        # including sidebar-first disclosure, dimension switches, a newest-wins
        # interruption, closing, and reduced-motion settlement. The per-state
        # screenshots make failures inspectable without retaining user state.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            set_reduce_motion(False)
            for name, flyout in (("settings", "settings"), ("media", "mediaPlayer"), ("app-picker", "appPicker")):
                summon_menu(flyout)
                time.sleep(0.45)
                image = root / f"{name}.png"
                run(["grim", str(image)])
                self.assertGreater(image.stat().st_size, 0, name)

            # A rapid third request must leave a usable, non-empty surface.
            summon_menu("settings")
            summon_menu("mediaPlayer")
            summon_menu("appPicker")
            time.sleep(0.45)
            interrupted = root / "interrupted.png"
            run(["grim", str(interrupted)])
            self.assertGreater(interrupted.stat().st_size, 0)

            set_reduce_motion(True)
            summon_menu("settings")
            immediate = root / "reduced-motion.png"
            run(["grim", str(immediate)])
            self.assertGreater(immediate.stat().st_size, 0)


if __name__ == "__main__":
    unittest.main()
