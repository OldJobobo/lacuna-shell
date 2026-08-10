import unittest
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def read_json(path):
    return json.loads(read(path))


def plugin_manifest_paths():
    return sorted(ROOT.glob("lacuna.*/manifest.json"))


class QmlContractTests(unittest.TestCase):
    def test_media_player_keeps_jellyfin_credentials_out_of_persistent_tracks_and_ipc(self):
        service = read("lacuna.media-player/Service.qml")
        search_script = read("lacuna.media-player/scripts/jellyfin-search")
        status_body = service[service.index("function status(): string") : service.index("function setBackgroundVideo", service.index("function status(): string"))]

        self.assertIn('return id === "" ? "" : "jellyfin://item/" + encodeURIComponent(id)', service)
        self.assertIn('thumbnail: provider === "jellyfin" ? "" : trackThumbnail(track)', service)
        self.assertIn('"url": stable_item_url(item_id)', search_script)
        self.assertNotIn('"api_key": api_key', search_script)
        self.assertNotIn("previewUrl:", status_body)
        self.assertNotIn("backgroundUrl:", status_body)

    def test_lacuna_settings_files_are_restricted_after_load_and_write(self):
        for path in ("lacuna.state/Service.qml", "lacuna.menu/services/LacunaSettings.qml"):
            qml = read(path)
            self.assertIn('["chmod", "600", root.settingsFile, root.settingsFile + ".bak"]', qml, path)
            self.assertIn("secureSettingsFile()", qml, path)

    def test_shader_effect_qsb_references_exist(self):
        pattern = re.compile(r'fragmentShader:\s*Qt\.resolvedUrl\("([^"]+\.qsb)"\)')
        for qml_path in sorted(ROOT.glob("lacuna.*/**/*.qml")):
            qml = qml_path.read_text(encoding="utf-8")
            for shader in pattern.findall(qml):
                self.assertTrue((qml_path.parent / shader).exists(), f"{qml_path.relative_to(ROOT)} references missing {shader}")

    def test_ambience_overlays_use_frame_animation_for_continuous_motion(self):
        overlay_paths = [
            "lacuna.film-grain-overlay/Overlay.qml",
            "lacuna.rainfall-overlay/Overlay.qml",
            "lacuna.aurora-drift/Overlay.qml",
            "lacuna.god-rays-overlay/Overlay.qml",
            "lacuna.cinematic-light-overlay/Overlay.qml",
            "lacuna.background-vignette/Overlay.qml",
        ]
        frame_driven_paths = {
            "lacuna.film-grain-overlay/Overlay.qml",
        }

        for path in overlay_paths:
            qml = read(path)
            # Short one-shot theme reload/retry timers are allowed; continuous
            # visual motion must remain frame-driven rather than wall-clock-driven.
            self.assertNotIn("repeat: true\n    running: root.effectVisible", qml, path)
            if path in frame_driven_paths:
                self.assertIn("FrameAnimation {", qml, path)

    def test_bar_seam_widget_contract(self):
        manifest = read_json("lacuna.bar-seam/manifest.json")
        self.assertEqual(["bar-widget"], manifest["kinds"])
        self.assertEqual("Widget.qml", manifest["entryPoints"]["barWidget"])
        schema_keys = {option["key"] for option in manifest["barWidget"]["schema"]}
        self.assertIn("gapWidth", schema_keys)

        widget = read("lacuna.bar-seam/Widget.qml")
        # bar-widget injection contract
        self.assertIn("property var bar", widget)
        self.assertIn("property string moduleName", widget)
        self.assertIn("property var settings", widget)
        # reserves the separation gap and drives the breathing glow from a Timer
        self.assertIn("implicitWidth: gapWidth", widget)
        self.assertIn("gapBreath", widget)
        self.assertIn("readonly property int glowHeight", widget)
        self.assertIn("seamGap + Math.round(gapBreath * barSize * 0.58)", widget)
        self.assertIn("height: root.glowHeight", widget)
        self.assertNotIn("readonly property color seam", widget)
        self.assertNotIn("color: root.seam", widget)
        self.assertIn("width: 5", widget)
        self.assertIn("width: 3", widget)
        self.assertIn("width: 1", widget)
        self.assertIn("Timer", widget)
        # vendored helpers travel with the plugin
        self.assertTrue((ROOT / "lacuna.bar-seam/ColorProfile.qml").exists())
        self.assertTrue((ROOT / "lacuna.bar-seam/MotionTokens.qml").exists())


    def test_lacuna_settings_keeps_carbon_as_legacy_lacuna_alias(self):
        qml = read("lacuna.menu/services/LacunaSettings.qml")

        self.assertIn('designStyle: "lacuna"', qml)
        self.assertIn("designStyles: {", qml)
        self.assertIn("function normalizeDesignStyles", qml)
        self.assertIn("function normalizeDesignStyleBar", qml)
        self.assertIn("function normalizeBarLayoutEntry", qml)
        self.assertIn('style === "lacuna" || style === "carbon"', qml)
        self.assertIn('return "lacuna"', qml)

    def test_lacuna_frame_border_option_is_configurable_and_separate_from_shadow(self):
        menu_settings = read("lacuna.menu/services/LacunaSettings.qml")
        state_service = read("lacuna.state/Service.qml")
        settings_example = read_json("config/settings.example.json")
        full_settings = read_json("tests/fixtures/full-settings.json")
        registry = read("lacuna.menu/menu/MenuRegistry.qml")
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")
        menu_window = read("lacuna.menu/menu/MenuWindow.qml")
        overlay = read("lacuna.menu/menu/LacunaFrameOverlay.qml")
        menu_surface = read("lacuna.menu/menu/MenuSurface.qml")
        panel_border = read("lacuna.menu/menu/LacunaPanelBorder.qml")
        bar = read("lacuna.bar/Bar.qml")
        adapter = read("lacuna.bar/OmarchyBarAdapter.qml")
        omarchy_bar = read("lacuna.bar/OmarchyBar.qml")
        frame = read("lacuna.bar/LacunaFrameWindow.qml")
        border_window = read("lacuna.bar/LacunaFrameBorderWindow.qml")

        self.assertIs(settings_example["frame"]["border"], False)
        self.assertIs(full_settings["frame"]["border"], True)
        for qml in [menu_settings, state_service]:
            self.assertIn("border: false", qml)
            self.assertIn("next.frame.border = sourceFrame.border === true", qml)

        self.assertIn("property bool frameBorder: false", registry)
        self.assertIn('row("corners", "Frame Border"', settings_window)
        self.assertIn('"toggle-frame-border"', settings_window)
        self.assertIn("readonly property bool frameBorder: boolSetting(frameSettings.border, false)", menu_window)
        self.assertIn("readonly property bool frameBorderAttachedFlyoutVisible", menu_window)
        self.assertIn("readonly property bool frameBorderAttachedConnectorVisible", menu_window)
        self.assertIn("readonly property real frameBorderAttachedFlyoutY", menu_window)
        self.assertIn("frameBorderAttachedFlyoutYFor(sidebarScreen)", menu_window)
        self.assertIn("frameBorderAttachedFlyoutHeightFor(sidebarScreen)", menu_window)
        self.assertIn("function setFrameBorder(enabled)", menu_window)
        self.assertIn('if (entry.action === "toggle-frame-border")', menu_window)
        self.assertIn("frameBorder: root.frameBorder && !frameOverlay.borderOnly", menu_window)
        self.assertIn('borderOnly: root.ownsHostFrameBorderOnScreen(modelData)', menu_window)
        self.assertIn("borderEnabled: root.lacunaEnabled && !menuWindow.fullscreenSuppressed", menu_window)
        self.assertIn('&& root.frameBorder && root.frameMode !== "off"', menu_window)
        self.assertIn("borderGeometryRecord: root.sidebarAutoHideEnabled ? null : root.hostFrameGeometryFor(modelData)", menu_window)
        self.assertIn("function ownsHostFrameBorderOnScreen(screen)", menu_window)
        self.assertIn("record.holeX = Number(source.holeX) - visualLeftInset", menu_window)
        self.assertIn("record.holeY = Number(source.holeY) - visualTopInset", menu_window)
        self.assertIn("readonly property int standaloneBorderWindowOverlap", menu_window)
        self.assertIn('&& frameMode === "off" && root.topBar ? 1 : 0', menu_window)
        self.assertIn("visualTopInset: Math.max(0, root.visualTopInset - root.standaloneBorderWindowOverlap)", menu_window)
        self.assertIn("if (barOwnsLacunaFrame && !ownsHostFrameBorderOnScreen(screen)) return 0", menu_window)
        self.assertIn("z: borderOnly ? 11 : 0", menu_window)
        self.assertIn("borderColor: root.menuThemeRef.frameBorder", menu_window)
        self.assertIn("frameBorderColor: root.menuThemeRef.frameBorder", menu_window)
        self.assertIn("outputScale: modelData && modelData.devicePixelRatio !== undefined", menu_window)
        self.assertIn("readonly property real frameMoldingBorderWidth: frameBorderWidth + (outputScale <= 1.25 ? 0.5 : 0)", menu_surface)
        self.assertIn("strokeWidth: root.frameBorderWidth", menu_surface)
        self.assertIn("strokeWidth: root.frameMoldingBorderWidth", menu_surface)
        self.assertEqual(2, menu_surface.count("startX: root.bodyRightInset"))
        self.assertIn("readonly property bool standaloneSidebarBorderVisible: backgroundVisible && frameBorder && !fullFrame", menu_surface)
        self.assertIn("property bool attachedFlyoutVisible: false", menu_surface)
        self.assertIn("readonly property bool standaloneAttachmentGapRenderable: attachedFlyoutVisible", menu_surface)
        self.assertIn("readonly property real standaloneVerticalUpperEnd", menu_surface)
        self.assertIn("readonly property real standaloneVerticalLowerStart", menu_surface)
        self.assertIn("id: standaloneSidebarBorderShape", menu_surface)
        self.assertIn("readonly property real standaloneBorderOuterTopX", menu_surface)
        self.assertIn("startX: root.standaloneBorderOuterTopX", menu_surface)
        self.assertIn("x: root.standaloneBorderRight", menu_surface)
        self.assertIn("y: root.standaloneBorderBottom", menu_surface)
        self.assertIn("visible: root.standaloneSidebarBorderVisible && root.openFromRight", menu_surface)
        self.assertGreaterEqual(menu_surface.count("PathMove {"), 2)
        self.assertIn("attachedFlyoutY: panelHost.effectiveConnectorVisible", menu_window)
        self.assertIn("? panelHost.connectorY : panelHost.flyoutMaskY", menu_window)
        self.assertIn("? panelHost.effectiveFlyoutHeight + panelHost.effectiveConnectorWidth * 2", menu_window)
        self.assertIn("LacunaPanelBorder", menu_window)
        self.assertIn("active: root.lacunaEnabled && root.frameBorder", menu_window)
        self.assertIn("flyoutVisible: root.flyoutVisibleOnScreen(modelData) && root.menuPanelControllerRef.flyoutProgress > 0.001", menu_window)
        self.assertIn("readonly property bool frameBorder: frameSettings.border === true", bar)
        self.assertIn("borderEnabled: root.frameBorder && !hostedMenu.ownsHostFrameBorderOnScreen(modelData)", bar)
        self.assertIn("hostFrameBorderEnabled: root.frameBorder", bar)
        self.assertIn("hostFrameGeometryProvider: function(screen)", bar)
        self.assertIn("barOutlineEnabled: root.frameBorder && !root.frameEnabled", bar)
        self.assertIn("function barOutlineInsetsFor(screen, barPosition)", bar)
        self.assertIn("var surfaceInset = root.frameMoldingPieces ? root.frameRadius : 0", bar)
        self.assertNotIn("surfaceInset = Math.max(surfaceInset, Number(panelGeometry.connectorWidth || 0))", bar)
        self.assertIn("A flyout connector", bar)
        self.assertIn("var tangentInset = Math.max(0, sidebarExtent - 1)", bar)
        self.assertIn("barOutlineInsetsProvider: function(screen, barPosition)", bar)
        self.assertIn("function barFlyoutAvoidanceInsetsFor(screen, barPosition)", bar)
        self.assertIn("hostedMenu.sidebarState.collapsed === true", bar)
        self.assertIn("popoutAvoidanceInsetsProvider: function(screen, barPosition)", bar)
        self.assertIn("property var popoutAvoidanceInsetsProvider: null", adapter)
        self.assertIn("popoutAvoidanceInsetsProvider: root.popoutAvoidanceInsetsProvider", adapter)
        self.assertIn("property var popoutAvoidanceInsetsProvider: null", omarchy_bar)
        self.assertIn("function popoutAvoidanceInsetsFor(screen, surfacePosition)", omarchy_bar)
        self.assertIn("readonly property var popupAvoidanceInsets", omarchy_bar)
        self.assertIn("borderColor: barTheme.frameBorder", bar)
        self.assertIn("LacunaFrameBorderWindow", frame)
        self.assertIn("active: root.active && root.borderEnabled", frame)
        self.assertIn("geometryRecord: root.geometryRecord", frame)
        self.assertLess(frame.index("id: framePaintClip"), frame.index("LacunaFrameBorderWindow"))
        self.assertNotIn("property bool frameBorder: false", adapter)
        self.assertNotIn("property bool frameBorder: false", omarchy_bar)

        self.assertIn("property bool borderEnabled: false", overlay)
        self.assertIn("id: frameBorderSource", overlay)
        self.assertIn("strokeColor: root.borderColor", overlay)
        self.assertIn("root.curveKappa", overlay)
        self.assertNotIn("PathArc {\n        x: root.borderRight", overlay)

        self.assertIn("property bool active: false", border_window)
        self.assertIn("property var geometryRecord: null", border_window)
        self.assertIn("property color borderColor", border_window)
        self.assertIn("id: frameBorderSource", border_window)
        self.assertIn('fillColor: "transparent"', border_window)
        self.assertIn("strokeColor: root.borderColor", border_window)
        self.assertIn("strokeWidth: root.borderWidth", border_window)
        self.assertIn("Item {", border_window)
        self.assertNotIn("PanelWindow", border_window)
        self.assertNotIn("WlrLayershell.", border_window)
        self.assertIn("readonly property real borderInset: Math.max(0, borderWidth / 2)", border_window)
        self.assertIn("readonly property real moldingBorderWidth: borderWidth + (outputScale <= 1.25 ? 0.5 : 0)", border_window)
        self.assertNotIn("lowerLeftCornerRepaintedBySidebar", border_window)
        self.assertIn("strokeWidth: root.borderRadius > 0 ? root.moldingBorderWidth : 0", border_window)
        self.assertIn("readonly property real borderRight: holeRight - borderInset", border_window)
        self.assertIn("readonly property real borderRadius: Math.max(0, holeRadius - borderInset)", border_window)
        self.assertIn("joinStyle: ShapePath.MiterJoin", border_window)
        self.assertIn("readonly property real attachmentGapTop: Math.max(borderTop + borderRadius, attachedFlyoutY + borderInset)", border_window)
        self.assertIn("readonly property real attachmentGapBottom: Math.min(borderBottom - borderRadius, attachedFlyoutY + attachedFlyoutHeight - borderInset)", border_window)
        self.assertIn("readonly property bool leftAttachmentGapVisible", border_window)
        self.assertIn("readonly property real leftVerticalUpperStartY", border_window)
        self.assertIn("y: root.borderBottom - root.borderRadius", border_window)
        self.assertIn("y: root.borderTop + root.borderRadius", border_window)
        self.assertIn("attachedFlyoutVisible: root.hostedFlyoutVisibleOnScreen(modelData)", bar)
        self.assertIn("root.borderRadius * (1 - root.curveKappa)", border_window)
        self.assertIn("property bool borderOnly: false", overlay)
        self.assertIn("property var borderGeometryRecord: null", overlay)
        self.assertIn("readonly property bool borderFrameEnabled: frameEnabled || borderOnly", overlay)
        self.assertIn("visible: (frameEnabled || (borderOnly && borderEnabled))", overlay)
        self.assertIn("visible: root.borderFrameEnabled && root.borderEnabled", overlay)
        self.assertIn("readonly property real borderInset: Math.max(0, borderWidth / 2)", overlay)
        self.assertIn("readonly property real moldingBorderWidth: borderWidth + (outputScale <= 1.25 ? 0.5 : 0)", overlay)
        self.assertIn("readonly property real borderLeft: hasBorderGeometryRecord ? Number(borderGeometryRecord.holeX)", overlay)
        self.assertNotIn("lowerLeftCornerRepaintedBySidebar", overlay)
        self.assertIn("strokeWidth: root.borderRadius > 0 ? root.moldingBorderWidth : 0", overlay)
        self.assertIn("readonly property real strokeRight: borderRight - borderInset", overlay)
        self.assertIn("readonly property real attachedOutlineTop: connectorVisible && connectorHeight > 0", overlay)
        self.assertIn("? connectorY : flyoutY", overlay)
        self.assertIn("readonly property real attachedOutlineBottom: connectorVisible && connectorHeight > 0", overlay)
        self.assertIn("? connectorY + connectorHeight : flyoutY + flyoutHeight", overlay)
        self.assertIn("readonly property real attachmentGapTop: Math.max(strokeTop + borderRadius, attachedOutlineTop + borderInset)", overlay)
        self.assertIn("readonly property real attachmentGapBottom: Math.min(strokeBottom - borderRadius, attachedOutlineBottom - borderInset)", overlay)
        self.assertIn("readonly property bool leftAttachmentGapVisible", overlay)
        self.assertIn("PathMove", overlay)
        self.assertIn("y: root.strokeBottom - root.borderRadius", overlay)
        self.assertIn("y: root.strokeTop + root.borderRadius", overlay)
        self.assertIn("PathMove", border_window)
        self.assertIn("property bool connectorVisible: false", panel_border)
        self.assertIn("property bool flyoutVisible: false", panel_border)
        self.assertIn("readonly property real connectorOutlineBottom: connectorY + effectiveConnectorWidth * 2 + visibleFlyoutHeight - borderInset", panel_border)
        self.assertIn("readonly property real outlineLeft: strokeLeft", panel_border)
        self.assertIn("readonly property real outlineTop: strokeTop", panel_border)
        self.assertIn("readonly property real outlineRight: strokeRight", panel_border)
        self.assertIn("readonly property real outlineBottom: strokeBottom", panel_border)
        self.assertIn("visible: root.renderable && !root.openToLeft", panel_border)
        self.assertIn("visible: root.renderable && root.openToLeft", panel_border)
        self.assertIn("? root.connectorOutlineX", panel_border)
        self.assertIn("control1X: root.connectorVisible ? root.connectorOutlineX : root.outlineLeft", panel_border)
        self.assertIn("control2X: root.connectorVisible ? root.connectorOutlineX + root.effectiveConnectorWidth * (1 - root.curveKappa) : root.outlineLeft", panel_border)
        self.assertIn("strokeColor: root.borderColor", panel_border)
        self.assertIn("source: frameSource", overlay)
        self.assertIn("source: frameShadowCaster", frame)
        self.assertIn("shadowEnabled: root.shadowEnabled", overlay)
        self.assertIn("shadowEnabled: !root.suppressed && root.shadowEnabled && root.width > 0 && root.height > 0", frame)
        self.assertNotIn("id: frameBorderSource", frame)
        self.assertIn("property var activePopoutBorderGap: ({})", omarchy_bar)
        self.assertIn("function setPopoutBorderGapFor(surfacePosition, owner, start, length, owningScreen)", omarchy_bar)
        self.assertIn("function clearPopoutBorderGap(owner)", omarchy_bar)
        self.assertIn("readonly property bool popoutBorderGapActive", omarchy_bar)
        self.assertIn("readonly property real popoutBorderGapStart", omarchy_bar)
        self.assertIn("readonly property real popoutBorderGapEnd", omarchy_bar)
        self.assertIn('model: ["top", "bottom"]', omarchy_bar)
        self.assertIn('model: ["left", "right"]', omarchy_bar)

    def test_bar_flyouts_report_and_clear_their_attachment_gap(self):
        flyouts = [
            "lacuna.audio/AudioFlyout.qml",
            "lacuna.bluetooth/BluetoothFlyout.qml",
            "lacuna.claude-usage/ClaudeUsageFlyout.qml",
            "lacuna.clock/CalendarFlyout.qml",
            "lacuna.codex-usage/CodexUsageFlyout.qml",
            "lacuna.network/NetworkFlyout.qml",
            "lacuna.notifications/NotificationsFlyout.qml",
            "lacuna.power/PowerFlyout.qml",
            "lacuna.system-stats/TelemetryFlyout.qml",
            "lacuna.temperature/ThermalFlyout.qml",
            "lacuna.theme/ThemeFlyout.qml",
            "lacuna.wallpaper/WallpaperFlyout.qml",
            "lacuna.weather/WeatherFlyout.qml",
        ]
        for path in flyouts:
            qml = read(path)
            self.assertIn("typeof root.bar.setPopoutBorderGap", qml, path)
            self.assertIn("var gapLength = surface.borderGapLength", qml, path)
            self.assertIn("root.bar.setPopoutBorderGap(root.coordinatorKey, gapStart, gapLength)", qml, path)
            self.assertIn("typeof bar.clearPopoutBorderGap", qml, path)
            self.assertIn("bar.clearPopoutBorderGap(coordinatorKey)", qml, path)

    def test_lacuna_menu_surface_tracks_transactional_native_bar_color(self):
        qml = read("lacuna.menu/services/Theme.qml")

        self.assertIn("import qs.Commons", qml)
        self.assertIn("property color panelBackground: opaqueColor(Color.bar.background)", qml)
        self.assertIn("property color foreground: Color.menu.text", qml)
        self.assertIn("property color background: Color.background", qml)
        self.assertIn("readonly property color frameBorder: opaqueColor(Color.popups.border)", qml)
        self.assertIn("property color accent: Color.menu.selectedText", qml)
        self.assertIn("function opaqueColor", qml)
        self.assertNotIn("property var shellValues", qml)
        self.assertNotIn("shellSurfaceColor", qml)
        self.assertNotIn("id: shellFile", qml)
        self.assertIn("function onShellValuesChanged()", qml)
        self.assertIn("watchChanges: false", qml)
        self.assertIn("onLoadFailed: retryTimer.restart()", qml)
        self.assertNotIn('onLoadFailed: root.load("")', qml)
        self.assertIn("function parseColor", qml)
        self.assertIn("rgba?", qml)
        self.assertIn("rgbHexAlpha", qml)
        self.assertIn("hyprHex", qml)

    def test_theme_reads_omarchy4_current_theme_state(self):
        theme = read("lacuna.menu/services/Theme.qml")
        bar_size = read("lacuna.menu/services/BarSizeMode.qml")

        for qml in [theme, bar_size]:
            self.assertIn('Quickshell.env("XDG_STATE_HOME")', qml)
            self.assertIn('"/omarchy/current/theme/colors.toml"', qml)
            self.assertNotIn('XDG_CONFIG_HOME") ? Quickshell.env("XDG_CONFIG_HOME") + "/omarchy/current/theme', qml)

        self.assertNotIn('"/omarchy/current/theme/shell.toml"', theme)
        self.assertIn('"/omarchy/current/theme/shell.toml"', bar_size)
        self.assertIn('"/omarchy/current/theme.name"', theme)
        self.assertIn('"OMARCHY_PATH=" + quote(omarchyPath) + " omarchy-shell"', bar_size)
        self.assertNotIn('"OMARCHY_PATH=" + quote(omarchyPath) + " omarchy shell"', bar_size)

    def test_theme_parse_fallbacks_emit_diagnostics(self):
        qml = read("lacuna.menu/services/Theme.qml")
        # An unparseable (non-empty) color value and a non-empty theme file
        # that yields no entries are real authoring mistakes, so they warn
        # instead of silently snapping to the built-in fallback palette.
        self.assertIn("could not parse color value", qml)
        self.assertIn("colors.toml has content but produced no parseable entries", qml)
        self.assertIn("retaining last palette", qml)
        self.assertNotIn("shell.toml has content but produced no parseable entries", qml)
        # Only the genuine-mistake paths warn; routine per-key misses do not.
        self.assertIn("if (raw.length > 0)", qml)
        self.assertNotIn("function rawColor(name) {\n    console.warn", qml)
        # Documented color formats stay supported (#RRGGBB[AA], rgb/rgba, 0xAARRGGBB).
        self.assertIn("/^#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/", qml)
        self.assertIn("/^rgba\\(\\s*#?([0-9a-f]{6})([0-9a-f]{2})\\s*\\)$/", qml)
        self.assertIn("/^0x([0-9a-f]{2})([0-9a-f]{6})$/", qml)

    def test_lacuna_log_helper_exists_and_is_adopted(self):
        # Shared level-gated logger, vendored to both component dirs.
        for path in [
            "lacuna.shell-settings/components/LacunaLog.qml",
            "lacuna.menu/components/LacunaLog.qml",
        ]:
            log = read(path)
            self.assertIn("function warn(message)", log, path)
            self.assertIn("property int level: 1", log, path)
            self.assertIn("console.warn(format(message))", log, path)
        # Adopted by the menu-only services that have real failure sites; their
        # diagnostics route through log.warn instead of bare console.warn.
        for path in [
            "lacuna.menu/services/Theme.qml",
            "lacuna.menu/services/BarSizeMode.qml",
        ]:
            qml = read(path)
            self.assertIn('import "../components"', qml, path)
            self.assertIn("LacunaLog {", qml, path)
            self.assertIn("log.warn(", qml, path)
            self.assertNotIn("console.warn(", qml, path)

    def test_menu_value_helpers_extracted_and_delegated(self):
        # Pure validators/converters moved out of MenuWindow into a stateless
        # helper; MenuWindow keeps same-named delegators so call sites and the
        # source contract are unchanged.
        helpers = read("lacuna.menu/menu/MenuValueHelpers.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")
        for fn in [
            "function localPath", "function positiveInt", "function safeValue",
            "function numberSetting", "function boolSetting", "function validFrameMode",
            "function validFrameReserveMode", "function validShellSettingsSurface",
            "function desiredChecked", "function validClockAnchor",
            "function clockAnchorHorizontal", "function clockAnchorVertical",
            "function clockAnchorFromParts",
        ]:
            self.assertIn(fn, helpers, fn)
        self.assertIn("MenuValueHelpers {", window)
        self.assertIn("id: valueHelpers", window)
        self.assertIn("return valueHelpers.validClockAnchor(value)", window)
        self.assertIn("return valueHelpers.boolSetting(value, fallback)", window)
        # The pure bodies no longer live in MenuWindow.
        self.assertNotIn('"top-left": true', window)

    def test_lacuna_panel_surfaces_use_opaque_bar_surface_color(self):
        menu = read("lacuna.menu/menu/MenuWindow.qml")
        shell_settings = read("lacuna.shell-settings/Panel.qml")
        bar = read("lacuna.bar/OmarchyBar.qml")

        self.assertIn("property color surfaceBackground: menuTheme.panelBackground", menu)
        self.assertIn("property color panelColor: surfaceBackground", menu)
        self.assertIn("panelColor: root.panelColor", menu)
        self.assertIn("frameColor: root.panelColor", menu)
        self.assertIn("background: root.background", menu)
        self.assertNotIn("background: root.surfaceBackground", menu)
        self.assertNotIn("color: root.surfaceBackground", menu)
        self.assertIn("readonly property color surfaceBackground: opaqueColor(Color.bar.background)", shell_settings)
        self.assertIn("function opaqueColor(colorValue)", shell_settings)
        self.assertIn('color: "transparent"', shell_settings)
        self.assertIn("color: root.surfaceBackground", shell_settings)
        self.assertIn("background: Color.background", shell_settings)
        self.assertIn("property color background: opaqueColor(Color.bar.background)", bar)
        self.assertIn("function opaqueColor(colorValue)", bar)
        self.assertIn("property string fontFamily: proportionalFontFamily(Style.font.family)", bar)
        self.assertIn("function proportionalFontFamily(value)", bar)
        self.assertIn('return "Hack Nerd Font Propo"', bar)
        self.assertIn('return "BlexMono Nerd Font Propo"', bar)
        self.assertIn('return "JetBrainsMono Nerd Font Propo"', bar)
        self.assertIn("color: root.background", bar)
        self.assertNotIn('root.transparent ? "transparent" : root.background', bar)
        self.assertNotIn("function toggleTransparency", bar)
        self.assertNotIn("function setRequestedTransparency", bar)
        self.assertNotIn("CenterGestureArea", bar)
        self.assertNotIn("omarchy-bar-text-color", bar)

    def test_lacuna_panel_surface_geometry_is_owned_by_surface_components(self):
        host = read("lacuna.menu/menu/LacunaPanelHost.qml")
        flyout = read("lacuna.menu/menu/LacunaAttachedFlyout.qml")
        connector = read("lacuna.menu/menu/LacunaPanelConnector.qml")
        overlay = read("lacuna.menu/menu/LacunaFrameOverlay.qml")
        surface = read("lacuna.menu/menu/MenuSurface.qml")
        unified = read("lacuna.menu/menu/LacunaPanelUnifiedSurface.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")

        self.assertIn("effectiveConnectorVisible\n    ? effectiveFlyoutHeight + effectiveConnectorWidth * 2 : 0", host)
        self.assertIn("readonly property var requestedPanelGeometry", host)
        self.assertIn("property var fromPanelGeometry", host)
        self.assertIn("property var targetPanelGeometry", host)
        self.assertIn("readonly property var effectivePanelGeometry", host)
        self.assertIn("function requestPanelGeometry(geometry, key)", host)
        self.assertIn("var current = copyPanelGeometry(effectivePanelGeometry)", host)
        self.assertIn("effectiveConnectorWidth > connectorEpsilon", host)
        self.assertIn("readonly property real flyoutCurrentWidth: Math.max(0, effectiveFlyoutWidth * clampedFlyoutProgress)", host)
        self.assertIn("readonly property real flyoutX: effectiveAnchorRight ? 0 : panelWidth + effectiveConnectorWidth", host)
        self.assertIn("property int flyoutLaneWidth: lacunaEnabled && panelController.menuRenderable ? maxFlyoutWidthFor(sidebarScreen) + panelShadowOutset : 0", window)
        self.assertIn("readonly property int panelShadowBlurMax: 28", window)
        self.assertIn("readonly property int panelShadowOutset: frameShadow ? Math.ceil(panelShadowBlurMax + Math.abs(frameShadowOffsetX)) : 0", window)
        self.assertIn("connectorWidth: root.settingsConnectorWidth", window)
        self.assertIn("connectorOverlap: root.effectiveConnectorPieces ? root.connectorOverlap : 0", window)
        self.assertIn("geometrySemanticKey: root.geometryTargetFlyout", window)
        self.assertIn("surfaceRightInset: Math.max(panelHost.effectiveConnectorWidth, root.frameMoldingPieces ? root.frameRadius : 0)", window)
        self.assertIn("x: panelHost.connectorX", window)
        self.assertIn("openX: panelHost.flyoutX", window)
        self.assertIn("panelRadius: root.attachedFlyoutRadius", window)
        self.assertIn("topLeftCornerState: root.openToLeft ? 0 : -1", flyout)
        self.assertIn("bottomLeftCornerState: root.openToLeft ? 0 : -1", flyout)
        self.assertIn("topRightCornerState: root.openToLeft ? -1 : 0", flyout)
        self.assertIn("bottomRightCornerState: root.openToLeft ? -1 : 0", flyout)
        self.assertIn("property bool backgroundVisible: true", flyout)
        self.assertIn("property real contentProgress: Math.max(0, Math.min(1, progress))", flyout)
        self.assertNotIn("Rectangle.radius", flyout)
        shape_surface = read("lacuna.menu/menu/LacunaShapeSurface.qml")
        self.assertNotIn("surfaceAlpha", shape_surface)
        self.assertIn("readonly property color solidPanelColor", shape_surface)
        self.assertIn("readonly property real curveKappa: lacunaGeometry.curveKappa", connector)
        self.assertIn("property bool backgroundVisible: true", connector)
        self.assertIn("property color foreground: \"#d8dee9\"", connector)
        self.assertIn("readonly property int joinLineGap", connector)
        self.assertIn("id: joinLine", connector)
        self.assertIn("opacity: root.clampedProgress * 0.58", connector)
        self.assertIn("opacity: backgroundVisible ? 1 : 0", connector)
        self.assertNotIn("surfaceAlpha", connector)
        self.assertIn("height: contentHeight + connectorWidth * 2", connector)
        self.assertIn("y: root.connectorWidth + root.contentHeight", connector)
        self.assertGreaterEqual(connector.count("strokeWidth: 0"), 2)
        self.assertIn("property bool backgroundVisible: true", surface)
        self.assertIn("readonly property color solidPanelColor", surface)
        self.assertIn("height: Math.max(0, (root.fullFrame ? root.bottomJoinTop : surface.height) - root.joinTop)", surface)
        self.assertIn("id: barJoinShape", surface)
        self.assertIn("id: bottomFrameJoinShape", surface)
        self.assertIn("LacunaPanelUnifiedSurface", window)
        self.assertLess(window.index("LacunaPanelUnifiedSurface"), window.index("MenuSurface"))
        self.assertIn("id: panelUnifiedSurface\n\n      anchors.fill: parent\n      z: 0", window)
        self.assertIn("id: surface\n\n      // Explicitly keep the durable sidebar", window)
        self.assertIn("z: 10\n      visible: menuWindow.sidebarRenderable", window)
        self.assertIn("id: flyoutConnector\n\n      z: 20", window)
        self.assertIn("id: attachedFlyout\n\n      z: 20", window)
        visible_sidebar = window[window.index("MenuSurface", window.index("LacunaPanelUnifiedSurface") + len("LacunaPanelUnifiedSurface")):]
        self.assertIn("backgroundVisible: true", visible_sidebar)
        self.assertIn("visible sidebar paint independent of the flattened", visible_sidebar)
        self.assertIn("readonly property var menuRegistryRef: registry", window)
        self.assertIn("readonly property var menuDesignTokensRef: designTokens", window)
        self.assertIn("registry: root.menuRegistryRef", window)
        self.assertIn("designTokens: root.menuDesignTokensRef", window)
        self.assertIn("sidebarVisible: false", window)
        self.assertIn("shadowEnabled: root.lacunaEnabled && root.frameShadow && root.menuPanelControllerRef.flyoutRenderable", window)
        self.assertIn("shadowBlurMax: root.panelShadowBlurMax", window)
        self.assertIn('readonly property bool topBarPanelShadowVisible: lacunaEnabled && !barOwnsLacunaFrame && frameShadow && frameMode === "off" && root.topBar', window)
        self.assertIn("readonly property int topBarPanelShadowVisualWidth", window)
        self.assertIn("visualWidth: Math.max(root.frameOverlayWidthFor(modelData), root.topBarPanelShadowVisualWidthFor(modelData))", window)
        self.assertIn('keepMapped: root.lacunaEnabled && (root.sidebarAutoHideEnabled || root.frameMode !== "off" || root.topBarPanelShadowVisible)', window)
        self.assertIn("topBarShadowEnabled: root.topBarPanelShadowVisible", window)
        self.assertIn("topBarShadowX: root.topBarPanelShadowX", window)
        self.assertIn("topBarShadowWidth: root.topBarPanelShadowWidth", window)
        self.assertIn("readonly property real topBarPanelShadowX: 0", window)
        self.assertIn("readonly property real topBarPanelShadowWidth: topBarPanelShadowVisualWidth", window)
        self.assertIn("readonly property real topBarPanelShadowHeight: Math.max(10, Math.round(barEdgeCasterSize * 0.62))", window)
        self.assertIn("backgroundVisible: false", window)
        self.assertIn("LacunaDropShadow", unified)
        self.assertIn("source: surfaceSource", unified)
        self.assertIn("property bool topBarShadowEnabled: false", unified)
        self.assertIn("readonly property real barEdgeShadowOpacity: Math.min(1, shadowOpacity * 1.35)", unified)
        self.assertIn("readonly property real topBarPanelShadowOpacity: Math.min(1, shadowOpacity * 0.72)", unified)
        self.assertIn("visible: root.shadowEnabled && root.topBarShadowEnabled && root.topBarShadowWidth > 0 && root.topBarShadowHeight > 0", unified)
        self.assertIn("GradientStop { position: 0.38; color: Qt.rgba(0, 0, 0, root.topBarPanelShadowOpacity * 0.24) }", unified)
        self.assertIn("Math.max(0, frameThickness + shadowBlurMax + Math.abs(shadowOffsetY))", unified)
        self.assertIn("id: shadowClip", unified)
        self.assertIn("height: Math.max(0, parent.height - root.shadowBottomClipInset)", unified)
        self.assertIn("clip: root.shadowBottomClipInset > 0", unified)
        self.assertIn("id: shadowRenderLayer", unified)
        self.assertIn("MenuSurface {", unified)
        self.assertIn("LacunaPanelConnector {", unified)
        self.assertIn("LacunaAttachedFlyout {", unified)
        self.assertIn("property real contentProgress: Math.max(0, Math.min(1, flyoutProgress))", unified)
        controller = read("lacuna.menu/services/PanelController.qml")
        self.assertIn("readonly property real flyoutContentThreshold: 0.55", controller)
        self.assertIn("(flyoutProgress - flyoutContentThreshold) / (1 - flyoutContentThreshold)", controller)
        self.assertIn("readonly property real menuToFlyoutThreshold: 0.65", controller)
        self.assertIn("property real contentSwitchProgress: 1", controller)
        self.assertIn("property int contentSwitchRevision: -1", controller)
        self.assertNotIn("contentSwitchTimer", controller)
        self.assertIn("duration: root.motionTokens.quick", controller)
        self.assertIn("easing.type: Easing.OutCubic", controller)
        self.assertIn("geometryAnimationDuration: root.menuMotionTokensRef.quick", window)
        self.assertIn("reducedMotion: root.menuMotionTokensRef.animationDisabled", window)
        self.assertIn("connectorRenderable: menuWindow.sidebarRenderable && panelHost.effectiveConnectorVisible", window)
        self.assertIn("connectorVisible: menuWindow.sidebarRenderable && panelHost.effectiveConnectorVisible", window)
        self.assertIn("contentProgress: root.menuPanelControllerRef.contentProgress", window)
        self.assertIn("opacity: root.flyoutContentOpacity(\"settings\")", window)
        self.assertIn("opacity: root.flyoutContentOpacity(\"shellSettings\")", window)
        self.assertIn("opacity: root.flyoutContentOpacity(\"appPicker\")", window)
        self.assertIn("opacity: root.flyoutContentOpacity(\"mediaPlayer\")", window)
        self.assertIn("return panelController.contentSwitchOpacity(kind)", window)
        self.assertIn("applies contentProgress once", controller)
        self.assertIn("property string retainedFlyout: \"\"", controller)
        self.assertIn("property string closingFlyout: \"\"", controller)
        self.assertIn("function contentSwitchOpacity(id)", controller)
        self.assertIn("if (kind === retainedFlyout) opacity +=", controller)
        self.assertIn("if (kind === activeFlyout) opacity += contentSwitchProgress", controller)
        self.assertNotIn("deferredMenuOpenTimer", controller)
        self.assertIn("readonly property int flyoutActivationFocusGuardMs: 900", window)
        self.assertIn("interval: root.flyoutActivationFocusGuardMs", window)
        self.assertIn("progress: root.flyoutProgress", unified)
        self.assertIn("progress: root.menuPanelControllerRef.flyoutProgress", window)
        self.assertIn("backgroundVisible: true", unified)
        self.assertIn("y: root.barBottomY", overlay)
        self.assertIn("readonly property color solidFrameColor", overlay)
        self.assertIn("readonly property real frameAlpha: 1", overlay)
        self.assertIn("readonly property real shadowAlphaCompensation: 1", overlay)
        self.assertIn("shadowOpacity: root.shadowOpacity * root.shadowAlphaCompensation", overlay)
        self.assertNotIn("id: sidebarTopFrameCornerPiece", window)
        self.assertNotIn("id: sidebarBottomFrameCornerPiece", window)

    def test_lacuna_settings_has_pending_save_merge_for_quick_launch_state(self):
        qml = read("lacuna.menu/services/LacunaSettings.qml")

        self.assertIn("function mergePendingSave", qml)
        self.assertIn("pendingSaveTouchedQuickLaunch", qml)
        self.assertIn("pendingSaveTouchedSidebar", qml)
        self.assertIn("queuedTouchedQuickLaunch", qml)
        self.assertIn("queuedTouchedSidebar", qml)
        self.assertIn("queuedTouchedQuickLaunch !== true", qml)
        self.assertIn("merged.customQuickLaunchApps = loadedBase.customQuickLaunchApps", qml)
        self.assertIn("merged.customQuickLaunchNames = loadedBase.customQuickLaunchNames", qml)
        self.assertIn("merged.sidebar = loadedBase.sidebar", qml)

    def test_bar_size_mode_debounces_theme_changes_and_verifies_writes(self):
        qml = read("lacuna.menu/services/BarSizeMode.qml")
        # Theme-name flicker is debounced through a timer rather than reloading
        # both FileViews inline on every change.
        self.assertIn("id: themeReloadTimer", qml)
        self.assertIn("themeReloadTimer.restart()", qml)
        # The patched shell.toml must re-parse to the intended sizes before it
        # is written, so a bad patch can never half-apply a bar size.
        self.assertIn("function patchedValuesMatch", qml)
        self.assertIn("if (!patchedValuesMatch(patched, desired.sizeHorizontal, desired.sizeVertical))", qml)
        self.assertIn("if (!patchedValuesMatch(restored, snapshot.sizeHorizontal, snapshot.sizeVertical))", qml)

    def test_bar_size_theme_mode_is_reachable(self):
        settings = read("lacuna.menu/services/LacunaSettings.qml")
        state_service = read("lacuna.state/Service.qml")
        bar_size = read("lacuna.menu/services/BarSizeMode.qml")
        registry = read("lacuna.menu/menu/MenuRegistry.qml")
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")

        for qml in [settings, state_service]:
            self.assertIn('barSizeMode: "theme"', qml)
            self.assertIn('mode === "theme" || mode === "compact" || mode === "full"', qml)

        self.assertIn('if (value === "theme" || value === "compact" || value === "full") return value', bar_size)
        self.assertIn('if (mode === "theme")', bar_size)
        self.assertIn('savePatch({ barSizeSnapshot: null })', bar_size)
        self.assertIn('if (root.barSizeMode === "theme") return "Theme"', registry)
        self.assertIn('if (root.barSizeMode === "theme") return "Use the active Omarchy theme bar sizing"', registry)
        self.assertIn('{ value: "theme", label: "Theme" }', settings_window)

    def test_lacuna_settings_uses_fileview_for_load_save(self):
        for path in [
            "lacuna.state/Service.qml",
            "lacuna.menu/services/LacunaSettings.qml",
        ]:
            qml = read(path)

            self.assertIn("function applyLoadedText", qml, path)
            self.assertIn("function writePayload", qml, path)
            self.assertIn("settingsFileView.setText(payload)", qml, path)
            self.assertIn("atomicWrites: true", qml, path)
            self.assertIn("suppressFileReloads", qml, path)
            self.assertNotIn("id: loadProc", qml, path)
            self.assertNotIn("id: saveProc", qml, path)
            self.assertNotIn('"bash", "-lc"', qml, path)

    def test_lacuna_settings_load_emits_loaded_signal_without_shadowing(self):
        # Regression: a local `var loaded` in applyLoadedText shadowed the
        # `signal loaded()`, so calling loaded() threw and the pending-save
        # tail never ran. The local must not be named `loaded`.
        for path in [
            "lacuna.state/Service.qml",
            "lacuna.menu/services/LacunaSettings.qml",
        ]:
            qml = read(path)

            self.assertIn("signal loaded()", qml, path)
            self.assertIn("function applyLoadedText", qml, path)
            self.assertIn("var parsed", qml, path)
            self.assertIn("data = parsed", qml, path)
            # The buggy local assignment must be gone.
            self.assertNotIn("data = loaded\n", qml, path)
            self.assertNotIn("loaded = normalize(", qml, path)

    def test_lacuna_settings_backs_up_corrupt_settings_before_defaults(self):
        # Regression: corrupt settings.json silently wiped all customization.
        # The parse-failure path must back the bad file up and flag recovery.
        for path in [
            "lacuna.state/Service.qml",
            "lacuna.menu/services/LacunaSettings.qml",
        ]:
            qml = read(path)

            self.assertIn("recoveredFromCorruptSettings", qml, path)
            self.assertIn("settingsBackupFileView.setText(corrupt)", qml, path)
            self.assertIn('path: root.settingsFile + ".bak"', qml, path)

    def test_lacuna_settings_share_versioned_canonical_layout_contract(self):
        state = read("lacuna.state/Service.qml")
        menu = read("lacuna.menu/services/LacunaSettings.qml")
        example = read_json("config/settings.example.json")
        fixture = read_json("tests/fixtures/full-settings.json")

        self.assertEqual(state, menu)
        self.assertIn('"lacuna-settings-state"', state)
        self.assertIn("function patchBarSize(payload: string): string", state)
        self.assertIn('key === "barSizeMode"', state)
        for qml in [state, menu]:
            self.assertIn("settingsSchemaVersion: 3", qml)
            self.assertIn('cornerMode: "theme"', qml)
            self.assertIn("cornerRadius: 14", qml)
            self.assertIn("function normalizeCornerMode", qml)
            self.assertIn("preserveUnknownJson(next.geometry, sourceGeometry", qml)
            self.assertIn("connectorPieces: true", qml)
            self.assertIn("moldingPieces: true", qml)
            self.assertIn("roundedContentCorners: true", qml)
            self.assertIn("next.frame.roundedContentCorners = next.frame.moldingPieces", qml)
            self.assertIn("next.sidebar.cornerPieces = next.sidebar.connectorPieces", qml)
            self.assertIn("function migrateSettings", qml)
            self.assertIn("function preserveUnknownJson", qml)
            self.assertIn('monitorPolicy: "auto"', qml)
            self.assertIn("function normalizeSidebarMonitorPolicy", qml)
            self.assertIn("function normalizeSidebarMonitorNames", qml)
            self.assertNotIn("function normalizeSidebarAutoHideRevealMode", qml)
            self.assertIn("preserveUnknownJson(next.sidebar.autoHide, sourceAutoHide", qml)
            self.assertIn("revealMode: true", qml)
            self.assertIn("function designStyleBar", qml)
            self.assertIn("function saveDesignStyleBar", qml)
            self.assertIn('if (typeof value === "string")', qml)
            self.assertIn("return stringId === \"\" ? null : { id: stringId }", qml)
            self.assertIn("next.version = root.settingsSchemaVersion", qml)
            self.assertIn("barPresentation: {", qml)
            self.assertIn("portraitSplit: true", qml)
            self.assertIn('typeof source.barPresentation.portraitSplit === "boolean"', qml)
            self.assertIn("preserveUnknownJson(next.barPresentation, source.barPresentation", qml)

        self.assertEqual(3, example["version"])
        self.assertEqual({"cornerMode": "theme", "cornerRadius": 14}, example["geometry"])
        self.assertTrue(example["barPresentation"]["portraitSplit"])
        self.assertFalse(fixture["barPresentation"]["portraitSplit"])
        self.assertEqual({"keep": True}, fixture["barPresentation"]["futurePresentationField"])
        self.assertEqual({"lacuna": {}, "omarchy": {}, "material": {}}, example["designStyles"])
        self.assertEqual("auto", example["sidebar"]["monitorPolicy"])
        self.assertEqual([], example["sidebar"]["monitorNames"])
        self.assertFalse(example["sidebar"]["autoHide"]["enabled"])
        self.assertNotIn("revealMode", example["sidebar"]["autoHide"])
        self.assertEqual(3, example["sidebar"]["autoHide"]["hotZoneWidth"])
        self.assertEqual("pinned", fixture["sidebar"]["monitorPolicy"])
        self.assertEqual(["DP-1", "DP-2"], fixture["sidebar"]["monitorNames"])
        self.assertEqual("lacuna.clock", fixture["designStyles"]["lacuna"]["bar"]["centerAnchor"])
        self.assertEqual("lacuna.menu-button", fixture["designStyles"]["lacuna"]["bar"]["layout"]["left"][0])
        self.assertEqual(
            {"role": "time", "weights": [1, 2, 3]},
            fixture["designStyles"]["lacuna"]["bar"]["layout"]["center"][0]["futureMetadata"],
        )
        future_fixture_paths = [
            fixture["barSizeSnapshot"]["futureSnapshotField"],
            fixture["sizeTransition"]["futureTransitionField"],
            fixture["preferredApps"]["futureRole"],
            fixture["power"]["futurePowerField"],
            fixture["shellSettings"]["futureShellField"],
            fixture["mediaProviders"]["youtube"]["futureAuthField"],
            fixture["mediaProviders"]["jellyfin"]["futurePlaybackField"],
            fixture["mediaProviders"]["futureProvider"],
            fixture["mediaPlayer"]["futurePlayerField"],
            fixture["sidebar"]["futureSidebarField"],
            fixture["sidebar"]["autoHide"]["futureAutoHideField"],
            fixture["backgroundEffects"]["futureEffectsField"],
            fixture["backgroundEffects"]["effects"]["filmGrain"]["futureTuningField"],
            fixture["backgroundEffects"]["effects"]["futureEffect"]["futureEffectField"],
            fixture["backgroundVignette"]["futureVignetteField"],
            fixture["frame"]["futureFrameField"],
        ]
        self.assertTrue(all(value is not None for value in future_fixture_paths))

        sidebar_state = read("lacuna.menu/services/SidebarState.qml")
        self.assertNotIn("next.sidebar = {\n      defaultMode:", sidebar_state)
        self.assertIn("next.sidebar.defaultMode = defaultMode", sidebar_state)
        self.assertNotIn("next.sidebar.connectorPieces = connectorPieces", sidebar_state)
        self.assertNotIn("next.sidebar.cornerPieces = connectorPieces", sidebar_state)
        self.assertNotIn("property bool connectorPieces", sidebar_state)
        self.assertNotIn("function setConnectorPiecesEnabled", sidebar_state)
        self.assertIn("next.sidebar.autoHide.enabled = autoHideEnabled", sidebar_state)
        for service_path in ("lacuna.state/Service.qml", "lacuna.menu/services/LacunaSettings.qml"):
            status_service = read(service_path)
            self.assertNotIn("sidebarConnectorPieces:", status_service)
            self.assertNotIn("frameMoldingPieces:", status_service)
            self.assertNotIn("frameRoundedContentCorners:", status_service)
        self.assertNotIn("autoHideRevealMode", sidebar_state)
        self.assertNotIn("property bool cornerPieces", sidebar_state)

        menu_window = read("lacuna.menu/menu/MenuWindow.qml")
        registry = read("lacuna.menu/menu/MenuRegistry.qml")
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")
        self.assertIn("readonly property bool portraitSplit", menu_window)
        self.assertIn("function setPortraitSplit(enabled)", menu_window)
        self.assertIn('entry.action === "toggle-portrait-split"', menu_window)
        self.assertIn("property bool portraitSplit: true", registry)
        self.assertIn('"Portrait split bar"', settings_window)
        self.assertIn("Selected widgets are redistributed automatically", settings_window)
        self.assertIn('function workspacesActiveOnly()', registry)
        self.assertIn('pluginRegistry.setBarWidget(', menu_window)
        self.assertIn('entry.action === "toggle-workspaces-active-only"', menu_window)
        self.assertIn('{ id: "bar", icon: "density-normal", label: "Bar"', settings_window)
        self.assertIn('"Active workspace only"', settings_window)

    def test_curve_kappa_constant_has_single_definition(self):
        # Plugins require local runtime copies, but every copy is vendored from
        # one build-time source so the molding geometry cannot drift.
        literal = "0.5522847498"
        canonical_geometry = "shared/qml/LacunaGeometry.qml"
        geometry_files = {
            "lacuna.shell-settings/components/LacunaGeometry.qml",
            "lacuna.menu/components/LacunaGeometry.qml",
            "lacuna.bar/LacunaGeometry.qml",
            "lacuna.claude-usage/LacunaGeometry.qml",
            "lacuna.codex-usage/LacunaGeometry.qml",
            "lacuna.network/LacunaGeometry.qml",
            "lacuna.audio/LacunaGeometry.qml",
            "lacuna.bluetooth/LacunaGeometry.qml",
            "lacuna.power/LacunaGeometry.qml",
            "lacuna.notifications/LacunaGeometry.qml",
            "lacuna.theme/LacunaGeometry.qml",
            "lacuna.wallpaper/LacunaGeometry.qml",
            "lacuna.system-stats/LacunaGeometry.qml",
            "lacuna.temperature/LacunaGeometry.qml",
            "lacuna.clock/LacunaGeometry.qml",
            "lacuna.weather/LacunaGeometry.qml",
        }
        canonical = read(canonical_geometry)
        self.assertIn("readonly property real curveKappa: " + literal, canonical)
        for path in sorted(geometry_files):
            self.assertEqual(canonical, read(path), path)

        consumers = [
            "lacuna.menu/menu/MenuSurface.qml",
            "lacuna.menu/menu/LacunaFrameOverlay.qml",
            "lacuna.menu/menu/LacunaPanelConnector.qml",
            "lacuna.menu/menu/LacunaAttachedFlyout.qml",
            "lacuna.menu/settings/SettingsWindow.qml",
            "lacuna.menu/settings/OmarchyShellSettingsWindow.qml",
            "lacuna.shell-settings/settings/OmarchyShellSettingsWindow.qml",
            "lacuna.bar/LacunaFrameWindow.qml",
            "lacuna.claude-usage/BarFlyoutSurface.qml",
            "lacuna.codex-usage/BarFlyoutSurface.qml",
            "lacuna.network/BarFlyoutSurface.qml",
            "lacuna.audio/BarFlyoutSurface.qml",
            "lacuna.bluetooth/BarFlyoutSurface.qml",
            "lacuna.power/BarFlyoutSurface.qml",
            "lacuna.notifications/BarFlyoutSurface.qml",
            "lacuna.theme/BarFlyoutSurface.qml",
            "lacuna.wallpaper/BarFlyoutSurface.qml",
            "lacuna.system-stats/BarFlyoutSurface.qml",
            "lacuna.temperature/BarFlyoutSurface.qml",
            "lacuna.clock/BarFlyoutSurface.qml",
            "lacuna.weather/BarFlyoutSurface.qml",
        ]
        for path in consumers:
            qml = read(path)
            self.assertIn("readonly property real curveKappa: lacunaGeometry.curveKappa", qml, path)
            self.assertIn("LacunaGeometry { id: lacunaGeometry }", qml, path)

        # Only the canonical build-time source and its verified runtime copies
        # may contain the literal.
        for qml_path in ROOT.glob("**/*.qml"):
            rel = qml_path.relative_to(ROOT).as_posix()
            if rel == canonical_geometry or rel in geometry_files:
                continue
            self.assertNotIn(literal, qml_path.read_text(encoding="utf-8"), rel)

    def test_lacuna_menu_state_uses_fileview_for_load_save(self):
        qml = read("lacuna.menu/services/LacunaMenuState.qml")

        self.assertIn("function savePayload", qml)
        self.assertIn("stateFileView.setText(savePayload())", qml)
        self.assertIn("atomicWrites: true", qml)
        self.assertNotIn("saveCommand", qml)
        self.assertNotIn("id: loadProc", qml)
        self.assertNotIn("id: saveProc", qml)
        self.assertNotIn('"bash", "-lc"', qml)

    def test_qml_processes_do_not_use_noninteractive_login_shells(self):
        login_shell_exceptions = {
            "lacuna.bar/OmarchyBar.qml",
            "lacuna.shell-settings/Panel.qml",
        }
        for path in sorted(ROOT.glob("lacuna.*/*.qml")):
            if path.relative_to(ROOT).as_posix() in login_shell_exceptions:
                continue
            qml = path.read_text(encoding="utf-8")
            self.assertNotIn('"bash", "-lc"', qml, str(path.relative_to(ROOT)))
            self.assertNotIn('"-lc"', qml, str(path.relative_to(ROOT)))

        for path in [
            "lacuna.menu/menu/MenuCommandCatalog.qml",
            "lacuna.shell-settings/Panel.qml",
        ]:
            qml = read(path)
            self.assertIn("Interactive terminal sessions intentionally use a login shell", qml, path)

    def test_canonical_settings_persistence_is_confirmed_latest_write_wins(self):
        for path in ("lacuna.state/Service.qml", "lacuna.menu/services/LacunaSettings.qml"):
            qml = read(path)
            self.assertIn('property string persistenceState: "idle"', qml, path)
            self.assertIn("property int requestedSaveRevision: 0", qml, path)
            self.assertIn("property int confirmedSaveRevision: 0", qml, path)
            self.assertIn("function handleSaveSucceeded()", qml, path)
            self.assertIn("function handleSaveFailed(error)", qml, path)
            self.assertIn("function retryPersistence()", qml, path)
            self.assertIn("onSaved: root.handleSaveSucceeded()", qml, path)
            self.assertIn("onSaveFailed: function(error) { root.handleSaveFailed(error) }", qml, path)
            self.assertIn('onLoadFailed: if (!root.hasLoaded) root.applyLoadedText("{}")', qml, path)
            self.assertNotIn("writeInFlight = false\n\n    if (queuedSavePayload", qml, path)

        window = read("lacuna.menu/menu/MenuWindow.qml")
        settings = read("lacuna.menu/settings/SettingsWindow.qml")
        self.assertIn('entry.action === "retry-settings-save"', window)
        self.assertIn("lacunaSettings.retryPersistence()", window)
        self.assertIn('"Settings Persistence"', settings)
        self.assertIn('"retry-settings-save"', settings)

    def test_settings_persistence_preserves_observed_nightlight_temperatures(self):
        qml = read("lacuna.settings-persistence/Service.qml")

        self.assertIn("function noteNightlightTemperature", qml)
        self.assertIn("function targetNightlightTemperature", qml)
        self.assertIn("temp < 5000", qml)
        self.assertIn("nightlightApplyProc.appliedTemperature", qml)
        self.assertIn("apply_status=$?", qml)
        self.assertIn("exit $apply_status", qml)
        self.assertNotIn("expected ? 4000 : 6000", qml)

    def test_custom_quick_launch_context_menu_can_delete_items(self):
        content = read("lacuna.menu/menu/MenuContent.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")

        self.assertIn("signal quickLaunchRemoveRequested(string appId)", content)
        self.assertIn('text: "Delete"', content)
        self.assertIn("function openQuickLaunchContext", content)
        self.assertIn("onSecondaryClicked: function(x, y)", content)
        self.assertIn("root.quickLaunchRemoveRequested(quickLaunchContextAppId)", content)
        self.assertIn("function removeCustomQuickLaunchApp(id)", window)
        self.assertIn("next.customQuickLaunchApps = ids", window)
        self.assertIn("next.customQuickLaunchNames = names", window)
        self.assertIn("lacunaSettings.save(next, true)", window)
        self.assertIn("onQuickLaunchRemoveRequested", window)

    def test_app_picker_does_not_cap_search_results(self):
        picker = read("lacuna.menu/menu/FlyoutAppPickerContent.qml")
        filtered = picker.split("function filteredApps()", 1)[1].split("return list", 1)[0]

        self.assertNotIn("list.length >= 80", filtered)
        self.assertNotIn("break", filtered)

    def test_quick_launch_add_action_lives_in_header_controls(self):
        registry = read("lacuna.menu/menu/MenuRegistry.qml")
        content = read("lacuna.menu/menu/MenuContent.qml")
        section = read("lacuna.menu/menu/MenuSection.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")

        self.assertIn('header.headerAction = "open-custom-quick-launch-picker"', registry)
        self.assertIn('header.headerActionIcon = "plus"', registry)
        self.assertIn('var header = entries.header("Daily Launch", "nav", "launch")', registry)
        self.assertIn('var header = entries.header("Shortcuts", "nav", "shortcuts")', registry)
        self.assertIn('header.optionActionPrefix = "set-shortcuts-layout-"', registry)
        self.assertIn('if (root.shortcutsLayout === "grid")', registry)
        self.assertIn('entry.action.indexOf("set-shortcuts-layout-") === 0', window)
        self.assertIn("function setShortcutsLayout", window)
        self.assertIn("var launchers = customQuickLaunchItems()", registry)
        self.assertNotIn('entries.action({ icon: "plus", label: "Add Quick Launch App"', registry)
        self.assertIn("onActionTriggered", content)
        self.assertIn("signal actionTriggered()", section)
        self.assertIn("var header = entry", content)
        self.assertNotIn("for (var key in entry) header[key] = entry[key]", content)
        self.assertIn("width: itemList.width", content)
        self.assertIn("width: implicitWidth", section)
        self.assertIn("width: root.options.length * height", section)

    def test_system_restart_requires_confirmation_unless_enabled(self):
        registry = read("lacuna.menu/menu/MenuRegistry.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")
        settings = read("lacuna.menu/services/LacunaSettings.qml")
        state_service = read("lacuna.state/Service.qml")
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")

        self.assertIn('instantRestart: false', settings)
        self.assertIn('instantRestart: false', state_service)
        self.assertIn('action: "confirm-system-restart"', registry)
        self.assertNotIn('label: "Restart", hint: "Reboot machine", command: "omarchy system reboot"', registry)
        self.assertIn("property bool pendingSystemRestartConfirmation", window)
        self.assertIn("function requestSystemRestart()", window)
        self.assertIn("function confirmSystemRestart()", window)
        self.assertIn('commands.run("omarchy system reboot")', window)
        self.assertIn('entry.action === "confirm-system-restart"', window)
        self.assertIn('entry.action === "toggle-instant-restart"', window)
        self.assertIn('"Skip Restart Confirmation"', settings_window)
        self.assertIn('"toggle-instant-restart"', settings_window)

    def test_rail_has_no_compact_density_button(self):
        rail = read("lacuna.menu/menu/MenuRail.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")

        self.assertNotIn("signal compactToggleRequested", rail)
        self.assertNotIn("id: compactButton", rail)
        self.assertNotIn("Compact density", rail)
        self.assertNotIn("Normal density", rail)
        self.assertNotIn("onCompactToggleRequested", window)

    def test_idle_indicator_uses_stable_reveal_and_clear_icon(self):
        combined = read("lacuna.indicators/Widget.qml")
        standalone = read("lacuna.idle-inhibitor/Widget.qml")

        self.assertIn('if (id === "StayAwake") return "Zz"', combined)
        self.assertIn('text: "Zz"', standalone)
        self.assertIn("opacity: root.stayAwake || mouseArea.containsMouse ? 1 : 0.55", standalone)
        self.assertIn('bar.shell.ensureService("omarchy.idle")', standalone)
        self.assertIn('bar.shell.serviceFor("omarchy.idle")', standalone)
        self.assertIn("readonly property bool serviceStateLoaded", standalone)
        self.assertIn("serviceStateLoaded ? idleService.stayAwake === true : polledStayAwake", standalone)
        self.assertIn('readonly property bool showInactive: boolSetting("showInactive", true)', standalone)
        self.assertIn("readonly property bool shown: stayAwake || showInactive || mouseArea.containsMouse", standalone)
        self.assertIn("implicitWidth: shown ? button.implicitWidth : 0", standalone)
        self.assertIn("function refreshStatus()", standalone)
        self.assertIn('command: ["bash", "-c", "omarchy-shell idle status 2>/dev/null"]', standalone)
        self.assertIn('if (data && typeof data.stayAwake === "boolean")', standalone)
        self.assertIn("idleService.setIdleEnabled(!idleEnabled)", standalone)
        self.assertIn("refreshDelay.restart()", standalone)
        self.assertIn('font.bold: indicatorButton.indicatorId === "StayAwake"', combined)
        self.assertIn("function hasConfiguredActiveIndicator", combined)
        self.assertIn("function readableIndicatorColor(id, active)", combined)
        self.assertIn("contrastDistance(candidate, background) >= 0.24", combined)
        self.assertIn("opacity: indicatorButton.active || clickArea.containsMouse ? 1 : 0.72", combined)
        self.assertIn("property int hoveredIndicators", combined)
        self.assertIn('readonly property bool showInactive: boolSetting("showInactive", false)', combined)
        self.assertIn("readonly property bool tooltipHovered: visible && opacity > 0 && hoveredIndicators > 0", combined)
        self.assertIn("visible: active || root.showInactive", combined)
        self.assertNotIn("revealInactive", combined)
        self.assertNotIn("revealCollapseDelay", combined)
        self.assertNotIn('text: "󰄲"', combined)
        self.assertIn("visible: shown", standalone)

    def test_grouped_indicators_match_standalone_controls(self):
        combined = read("lacuna.indicators/Widget.qml")
        manifest = read_json("lacuna.indicators/manifest.json")

        self.assertFalse(manifest["barWidget"]["defaults"]["showInactive"])
        self.assertIn("showInactive", [entry["key"] for entry in manifest["barWidget"]["schema"]])
        self.assertIn("readonly property int pendingCount", combined)
        self.assertIn('if (id === "Dnd") return dnd || pendingCount > 0', combined)
        self.assertIn('pendingCount + " pending notification"', combined)
        self.assertIn('bar.run("omarchy-shell notifications showHistory")', combined)
        self.assertIn('bar.run("omarchy toggle notification silencing")', combined)
        self.assertIn('else if (recording) bar.run("omarchy capture screenrecording --stop-recording")', combined)
        self.assertIn("Qt.LeftButton | Qt.MiddleButton | Qt.RightButton", combined)
        self.assertIn('indicatorButton.indicatorId === "Dnd" && root.pendingCount > 0 && !root.dnd', combined)

    def test_indicator_status_roles_have_visible_palette_slots(self):
        combined = read("lacuna.indicators/Widget.qml")

        self.assertIn('if (id === "Dnd") return "color13"', combined)
        self.assertIn('if (id === "NightLight") return "color11"', combined)
        self.assertIn('if (id === "StayAwake") return "color14"', combined)
        self.assertIn('if (id === "ScreenRecording") return "color9"', combined)
        self.assertIn('if (id === "Dictation") return "color6"', combined)
        self.assertIn('return "foreground"', combined)

    def test_topbar_tooltip_targets_expose_hover_state(self):
        root_target_widgets = [
            "lacuna.audio",
            "lacuna.bluetooth",
            "lacuna.clock",
            "lacuna.bar-size-pill",
            "lacuna.claude-usage",
            "lacuna.codex-usage",
            "lacuna.compact-pill",
            "lacuna.idle-inhibitor",
            "lacuna.indicators",
            "lacuna.nightlight",
            "lacuna.menu-button",
            "lacuna.network",
            "lacuna.notifications",
            "lacuna.power",
            "lacuna.script-pill",
            "lacuna.screen-recording",
            "lacuna.system-update",
            "lacuna.temperature",
            "lacuna.theme",
            "lacuna.voxtype",
            "lacuna.wallpaper",
            "lacuna.weather",
        ]

        for plugin in root_target_widgets:
            qml = read(f"{plugin}/Widget.qml")
            self.assertIn("readonly property bool tooltipHovered", qml, plugin)
            if plugin == "lacuna.indicators":
                self.assertIn("hoveredIndicators > 0", qml, plugin)
            else:
                self.assertIn("mouseArea.containsMouse", qml, plugin)

        system_stats = read("lacuna.system-stats/Widget.qml")
        system_stats_service = read("lacuna.system-stats/Service.qml")
        self.assertIn("readonly property bool tooltipHovered", system_stats)
        self.assertIn("parent.bar.showTooltip(parent, parent.tooltip)", system_stats)
        self.assertIn('path: "/proc/stat"', system_stats_service)
        self.assertIn('path: "/proc/meminfo"', system_stats_service)
        self.assertNotIn('"head -n1 /proc/stat"', system_stats)
        self.assertNotIn('"head -n3 /proc/meminfo"', system_stats)

        for path in [
            "lacuna.mpris/components/LacunaMprisButton.qml",
            "lacuna.workspaces/components/LacunaWorkspaceButton.qml",
        ]:
            qml = read(path)
            self.assertIn("readonly property bool tooltipHovered", qml, path)
            self.assertIn("clickArea.containsMouse", qml, path)

    def test_lacuna_notifications_widget_owns_history_flyout(self):
        widget = read("lacuna.notifications/Widget.qml")
        flyout = read("lacuna.notifications/NotificationsFlyout.qml")

        self.assertIn("property bool flyoutOpen: false", widget)
        self.assertIn("function togglePanel()", widget)
        self.assertIn("root.togglePanel()", widget)
        self.assertIn("NotificationsFlyout {", widget)
        self.assertIn("function onHistoryOpenRequested()", widget)
        self.assertNotIn('root.bar.run("omarchy-shell notifications showHistory")', widget)

        for snippet in [
            "required property Item anchorItem",
            "required property QtObject bar",
            "property var service: null",
            "readonly property int pendingCount",
            "readonly property int pastCount",
            "service.pendingModel",
            "service.pastModel",
            'activeTab === "pending"',
            "root.service.markAllSeen()",
            "root.service.clearPast()",
            "root.service.dismissPending(rowCard.index)",
            "root.service.dismissPast(rowCard.index)",
            "root.service.setDoNotDisturb(!root.service.doNotDisturb)",
            "BarFlyoutSurface {",
            "HyprlandFocusGrab {",
        ]:
            self.assertIn(snippet, flyout)

    def test_lacuna_bar_module_slot_visibility_does_not_depend_on_child_visible(self):
        qml = read("lacuna.bar/OmarchyBar.qml")

        self.assertIn("readonly property bool contentVisible: activeItem && (itemImplicitWidth > 0 || itemImplicitHeight > 0)", qml)
        self.assertNotIn("activeItem.visible !== false || itemImplicitWidth", qml)

    def test_lacuna_native_replacement_widgets_have_expected_contracts(self):
        replacements = {
            "lacuna.system-update": "SystemUpdate",
            "lacuna.clock": "Clock",
            "lacuna.weather": "Weather",
            "lacuna.notifications": "NotificationCenter",
            "lacuna.nightlight": "NightLight",
            "lacuna.idle-inhibitor": "idleInhibitor",
            "lacuna.screen-recording": "screenRecording",
            "lacuna.voxtype": "voxtype",
            "lacuna.tray": "Tray",
            "lacuna.bluetooth": "BluetoothPanel",
            "lacuna.network": "NetworkPanel",
            "lacuna.audio": "AudioPanel",
            "lacuna.power": "PowerPanel",
        }

        example = read_json("config/shell.lacuna-native-replacements.example.json")
        layout_ids = []
        for section in ["left", "center", "right"]:
            layout_ids.extend(entry["id"] for entry in example["bar"]["layout"][section])

        native_system_ids = {
            "lacuna.bluetooth": "omarchy.bluetooth",
            "lacuna.network": "omarchy.network",
            "lacuna.audio": "omarchy.audio",
            "lacuna.power": "omarchy.power",
        }

        for plugin_id in replacements:
            manifest = read_json(f"{plugin_id}/manifest.json")
            qml = read(f"{plugin_id}/Widget.qml")

            self.assertEqual(plugin_id, manifest["id"])
            self.assertIn("bar-widget", manifest["kinds"])
            self.assertEqual("Widget.qml", manifest["entryPoints"]["barWidget"])
            self.assertEqual("Lacuna", manifest["barWidget"]["category"])
            self.assertIn(plugin_id, layout_ids)
            if plugin_id in native_system_ids:
                self.assertNotIn(f'moduleName: "{native_system_ids[plugin_id]}"', qml)
            self.assertIn(f'moduleName: "{plugin_id}"', qml)
            self.assertIn("barSize", qml)
            if plugin_id != "lacuna.tray":
                self.assertIn("colorProfile", qml)
        for native_id in ["omarchy.bluetooth", "omarchy.network", "omarchy.audio", "omarchy.power"]:
            self.assertNotIn(native_id, layout_ids)

    def test_lacuna_network_exposes_live_widget_flyout_contract(self):
        manifest = read_json("lacuna.network/manifest.json")
        service = read("lacuna.network/Service.qml")
        widget = read("lacuna.network/Widget.qml")
        panel = read("lacuna.network/Panel.qml")
        flyout = read("lacuna.network/NetworkFlyout.qml")
        model = read("lacuna.network/NetworkModel.js")

        self.assertEqual(["service", "bar-widget"], manifest["kinds"])
        self.assertTrue(manifest["keepLoaded"])
        self.assertEqual("Service.qml", manifest["entryPoints"]["service"])
        self.assertNotIn("panel", manifest["entryPoints"])
        self.assertEqual("Widget.qml", manifest["entryPoints"]["barWidget"])

        for snippet in [
            "import Quickshell.Networking",
            "readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager",
            "readonly property var wifiDevice: findDevice(DeviceType.Wifi)",
            "readonly property var connectedWifiNetwork: findConnectedWifiNetwork()",
            "property var wifiNetworks: []",
            "function refresh(scanWifi)",
            "function connectKnown(ssid)",
            "function connectWithPassphrase(ssid, passphrase)",
            "function disconnect(network)",
            "function forget(row)",
            "function toggleWifi()",
            "Networking.wifiEnabled = !Networking.wifiEnabled",
            'target: "lacuna-network"',
        ]:
            self.assertIn(snippet, service)

        for snippet in [
            'bar.shell.ensureService("lacuna.network")',
            'bar.shell.serviceFor("lacuna.network")',
            "NetworkFlyout {",
            "readonly property bool opened: flyoutOpen",
            "function open()",
            "function close()",
            "flyoutOpen = !flyoutOpen",
            "root.networkService.toggleWifi()",
            "networkService.tooltip",
        ]:
            self.assertIn(snippet, widget)

        for snippet in [
            "property var service: null",
            "PanelWindow {",
            'WlrLayershell.namespace: "lacuna-network-panel"',
            "WlrLayershell.layer: WlrLayer.Overlay",
            'shell.ensureService("lacuna.network")',
            "activeService.refresh(true)",
            "activeService.toggleWifi()",
            "activeService.connectKnown(row.ssid)",
            "activeService.connectWithPassphrase(row.ssid, root.passwordText)",
            "activeService.disconnect(row.network)",
            "activeService.forget(row)",
            "component ActionChip: Rectangle",
            "component SignalBars: Row",
            "component NetworkSlat: Rectangle",
            "Flickable {",
            'text: "LACUNA NETWORK PROVIDER"',
            '"SIGNALS IN RANGE"',
            "function onConnectionFailed(reason)",
            "ConnectionFailReason.NoSecrets",
        ]:
            self.assertIn(snippet, panel)
        self.assertNotIn("FloatingWindow", panel)
        self.assertNotIn("PanelSectionHeader", panel)

        for snippet in [
            "PopupWindow {",
            "required property Item anchorItem",
            "BarFlyoutSurface {",
            "HyprlandFocusGrab {",
            "bar.requestPopout(root)",
            "activeService.refresh(true)",
            "activeService.toggleWifi()",
            "activeService.connectKnown(row.ssid)",
            "activeService.connectWithPassphrase(row.ssid, root.passwordText)",
            "activeService.disconnect(row.network)",
            "activeService.forget(row)",
            "component ActionChip: Rectangle",
            "component SignalBars: Row",
            "component NetworkSlat: Rectangle",
            "Flickable {",
            'text: "LACUNA NETWORK"',
            '"SIGNALS IN RANGE"',
        ]:
            self.assertIn(snippet, flyout)

        for snippet in [
            "function parseNetworkStatus(raw)",
            "function wifiIconFor(strength)",
            "function connectionIcon(kind, signalStrength)",
            "function wifiRow(network)",
            "function sortWifiRows(rows)",
            "function networkFailureReason(reason, reasons)",
        ]:
            self.assertIn(snippet, model)

    def test_lacuna_audio_exposes_live_widget_flyout_contract(self):
        manifest = read_json("lacuna.audio/manifest.json")
        service = read("lacuna.audio/Service.qml")
        widget = read("lacuna.audio/Widget.qml")
        flyout = read("lacuna.audio/AudioFlyout.qml")
        panel = read("lacuna.audio/Panel.qml")
        model = read("lacuna.audio/AudioModel.js")

        self.assertEqual(["service", "bar-widget"], manifest["kinds"])
        self.assertTrue(manifest["keepLoaded"])
        self.assertEqual("Service.qml", manifest["entryPoints"]["service"])
        self.assertNotIn("panel", manifest["entryPoints"])
        self.assertEqual("Widget.qml", manifest["entryPoints"]["barWidget"])

        for snippet in [
            "import Quickshell.Services.Pipewire",
            "readonly property var sink: Pipewire.defaultAudioSink",
            "readonly property var source: Pipewire.defaultAudioSource",
            "readonly property var liveStreams:",
            "property var streams: []",
            "PwObjectTracker { objects: root.liveStreams }",
            "function snapshotRows(liveNodes, kind, preferred)",
            "function resolveLiveNode(reference)",
            "function setOutputVolume(value)",
            "function toggleOutputMute()",
            "function setDefaultSink(reference)",
            "function setStreamVolume(reference, value)",
            'target: "lacuna-audio"',
        ]:
            self.assertIn(snippet, service)

        for snippet in [
            'bar.shell.ensureService("lacuna.audio")',
            'bar.shell.serviceFor("lacuna.audio")',
            "AudioFlyout {",
            "readonly property bool opened: flyoutOpen",
            "function open()",
            "function close()",
            "flyoutOpen = !flyoutOpen",
            "audioService.toggleOutputMute()",
            "audioService.tooltip",
        ]:
            self.assertIn(snippet, widget)

        for snippet in [
            "PopupWindow {",
            "required property Item anchorItem",
            "BarFlyoutSurface {",
            "HyprlandFocusGrab {",
            "bar.requestPopout(root)",
            "activeService.setOutputVolume(value / 100)",
            "activeService.toggleOutputMute()",
            "activeService.setDefaultSink(modelData)",
            "activeService.setDefaultSource(modelData)",
            "activeService.setStreamVolume(streamSlat.row, value / 100)",
            "activeService.toggleStreamMute(streamSlat.row)",
            "component ActionChip: Rectangle",
            "component DeviceSlat: Rectangle",
            "component StreamSlat: Rectangle",
            'text: "LACUNA AUDIO"',
            'text: "OUTPUT DEVICES"',
            'text: "PLAYBACK STREAMS"',
        ]:
            self.assertIn(snippet, flyout)

        for snippet in [
            "PanelWindow {",
            'WlrLayershell.namespace: "lacuna-audio-panel"',
            "component ActionChip: Rectangle",
            "component VolumeSlab: Rectangle",
            "component DeviceSlat: Rectangle",
            "component StreamSlat: VolumeSlab",
            'text: "LACUNA AUDIO PROVIDER"',
            'text: "OUTPUT DEVICES"',
            'text: "PLAYBACK STREAMS"',
            "activeService.setOutputVolume(value / 100)",
            "activeService.setDefaultSink(modelData)",
            "activeService.setStreamVolume(row, value / 100)",
        ]:
            self.assertIn(snippet, panel)
        self.assertNotIn("FloatingWindow", panel)

        for snippet in [
            "function outputIcon(hasSink, muted, volume)",
            "function inputIcon(hasSource, muted)",
            "function outputMood(volume, muted)",
            "function nodeLabel(node)",
            "function isPlaybackStream(node)",
            "function streamLabel(node)",
            "function nodeKey(node)",
            "function snapshotRow(node, kind, selected)",
        ]:
            self.assertIn(snippet, model)

    def test_lacuna_bluetooth_exposes_live_widget_flyout_contract(self):
        manifest = read_json("lacuna.bluetooth/manifest.json")
        service = read("lacuna.bluetooth/Service.qml")
        widget = read("lacuna.bluetooth/Widget.qml")
        flyout = read("lacuna.bluetooth/BluetoothFlyout.qml")
        panel = read("lacuna.bluetooth/Panel.qml")
        model = read("lacuna.bluetooth/BluetoothModel.js")

        self.assertEqual(["service", "bar-widget"], manifest["kinds"])
        self.assertTrue(manifest["keepLoaded"])
        self.assertEqual("Service.qml", manifest["entryPoints"]["service"])
        self.assertNotIn("panel", manifest["entryPoints"])
        self.assertEqual("Widget.qml", manifest["entryPoints"]["barWidget"])

        for snippet in [
            "import Quickshell.Bluetooth",
            "readonly property var adapter: Bluetooth.defaultAdapter",
            "readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []",
            "readonly property var connectedDevices: deviceGroups.connected || []",
            "function startDiscovery()",
            "function toggleBluetooth()",
            "function connectDevice(device)",
            "function disconnectDevice(device)",
            "function forgetDevice(device)",
            "omarchy-bluetooth-device",
            "omarchy-audio-output-set-default",
            'target: "lacuna-bluetooth"',
        ]:
            self.assertIn(snippet, service)

        for snippet in [
            'bar.shell.ensureService("lacuna.bluetooth")',
            'bar.shell.serviceFor("lacuna.bluetooth")',
            "BluetoothFlyout {",
            "readonly property bool opened: flyoutOpen",
            "function open()",
            "function close()",
            "flyoutOpen = !flyoutOpen",
            "bluetoothService.toggleBluetooth()",
            "bluetoothService.tooltip",
        ]:
            self.assertIn(snippet, widget)

        for snippet in [
            "PopupWindow {",
            "required property Item anchorItem",
            "BarFlyoutSurface {",
            "HyprlandFocusGrab {",
            "bar.requestPopout(root)",
            "activeService.startDiscovery()",
            "activeService.toggleBluetooth()",
            "activeService.connectDevice(device)",
            "activeService.disconnectDevice(device)",
            "activeService.forgetDevice(slat.device)",
            "component ActionChip: Rectangle",
            "component DeviceSlat: Rectangle",
            'text: "LACUNA BLUETOOTH"',
            'text: "PAIRED DEVICES"',
            'text: "DISCOVERED"',
        ]:
            self.assertIn(snippet, flyout)

        for snippet in [
            "PanelWindow {",
            'WlrLayershell.namespace: "lacuna-bluetooth-panel"',
            "WlrLayershell.layer: WlrLayer.Overlay",
            'shell.ensureService("lacuna.bluetooth")',
            "activeService.startDiscovery()",
            "activeService.toggleBluetooth()",
            "activeService.connectDevice(device)",
            "activeService.disconnectDevice(device)",
            "activeService.forgetDevice(slat.device)",
            "component ActionChip: Rectangle",
            "component DeviceSlat: Rectangle",
            'text: "LACUNA BLUETOOTH PROVIDER"',
            'text: "PAIRED DEVICES"',
            'text: "DISCOVERED"',
        ]:
            self.assertIn(snippet, panel)
        self.assertNotIn("FloatingWindow", panel)
        self.assertNotIn("PanelSectionHeader", panel)

        for snippet in [
            "function deviceLabel(device)",
            "function deviceLists(devices)",
            "function pendingAction(actions, address)",
            "function bluetoothSinkMatchesDevice(node, device)",
            "function deviceStatus(device, pending, section)",
        ]:
            self.assertIn(snippet, model)

    def test_lacuna_power_exposes_live_widget_flyout_contract(self):
        manifest = read_json("lacuna.power/manifest.json")
        service = read("lacuna.power/Service.qml")
        widget = read("lacuna.power/Widget.qml")
        flyout = read("lacuna.power/PowerFlyout.qml")
        panel = read("lacuna.power/Panel.qml")
        model = read("lacuna.power/PowerModel.js")

        self.assertEqual(["service", "bar-widget"], manifest["kinds"])
        self.assertTrue(manifest["keepLoaded"])
        self.assertEqual("Service.qml", manifest["entryPoints"]["service"])
        self.assertNotIn("panel", manifest["entryPoints"])
        self.assertEqual("Widget.qml", manifest["entryPoints"]["barWidget"])

        for snippet in [
            "import Quickshell.Services.UPower",
            "readonly property var device: UPower.displayDevice",
            "readonly property bool onBattery: UPower.onBattery",
            "function refresh()",
            "function updateProfiles(raw)",
            "function setProfile(profile)",
            "omarchy-battery-status",
            "omarchy-powerprofiles-list",
            "omarchy-system-stats",
            'target: "lacuna-power"',
        ]:
            self.assertIn(snippet, service)

        for snippet in [
            'bar.shell.ensureService("lacuna.power")',
            'bar.shell.serviceFor("lacuna.power")',
            "PowerFlyout {",
            "readonly property bool opened: flyoutOpen",
            "function open()",
            "function close()",
            "flyoutOpen = !flyoutOpen",
            "powerService.tooltip",
            "root.powerService.refresh()",
        ]:
            self.assertIn(snippet, widget)

        for snippet in [
            "PopupWindow {",
            "required property Item anchorItem",
            "BarFlyoutSurface {",
            "HyprlandFocusGrab {",
            "bar.requestPopout(root)",
            "activeService.refresh()",
            "activeService.setProfile(modelData)",
            "component ActionChip: Rectangle",
            "component StatTile: Rectangle",
            'text: "LACUNA POWER"',
            'text: "Power profile"',
            'label: "TIME LEFT"',
            'label: "DRAW"',
        ]:
            self.assertIn(snippet, flyout)

        for snippet in [
            "PanelWindow {",
            'WlrLayershell.namespace: "lacuna-power-panel"',
            "WlrLayershell.layer: WlrLayer.Overlay",
            'shell.ensureService("lacuna.power")',
            "activeService.refresh()",
            "activeService.setProfile(modelData)",
            "component ActionChip: Rectangle",
            "component StatTile: Rectangle",
            'text: "LACUNA POWER PROVIDER"',
            'text: "Power profile"',
            'label: "TIME LEFT"',
            'label: "DRAW"',
        ]:
            self.assertIn(snippet, panel)
        self.assertNotIn("FloatingWindow", panel)
        self.assertNotIn("PanelSectionHeader", panel)

        for snippet in [
            "function parseKeyValue(raw)",
            "function parseProfiles(raw, previousIndex)",
            "function profileIcon(name)",
            "function batteryIcon(device, onBattery, states)",
            "function modeLabel(device, onBattery, states)",
        ]:
            self.assertIn(snippet, model)

    def test_lacuna_screen_recording_exposes_provider_widget_contract(self):
        manifest = read_json("lacuna.screen-recording/manifest.json")
        service = read("lacuna.screen-recording/Service.qml")
        widget = read("lacuna.screen-recording/Widget.qml")

        self.assertEqual(["service", "bar-widget"], manifest["kinds"])
        self.assertTrue(manifest["keepLoaded"])
        self.assertEqual("Service.qml", manifest["entryPoints"]["service"])
        self.assertEqual("Widget.qml", manifest["entryPoints"]["barWidget"])

        for snippet in [
            'command: ["pgrep", "--quiet", "-f", "^gpu-screen-recorder"]',
            "function refresh()",
            "function startRecording()",
            "function stopRecording()",
            "function toggleRecording()",
            'Quickshell.execDetached(["omarchy", "capture", "screenrecording"])',
            'Quickshell.execDetached(["omarchy", "capture", "screenrecording", "--stop-recording"])',
            'target: "lacuna-screen-recording"',
        ]:
            self.assertIn(snippet, service)

        for snippet in [
            'bar.shell.ensureService("lacuna.screen-recording")',
            'bar.shell.serviceFor("lacuna.screen-recording")',
            "recordingService.toggleRecording()",
            "recordingService.tooltip",
            "readonly property bool shown: recording || showInactive",
            "implicitWidth: shown ? button.implicitWidth : 0",
            'command: ["pgrep", "--quiet", "-f", "^gpu-screen-recorder"]',
            'text: "REC"',
            "SequentialAnimation on scale",
        ]:
            self.assertIn(snippet, widget)
        self.assertNotIn("omarchy capture screenrecording", widget)

    def test_lacuna_reminders_match_omarchy_indicator_workflow(self):
        manifest = read_json("lacuna.reminders/manifest.json")
        widget = read("lacuna.reminders/Widget.qml")
        combined = read("lacuna.indicators/Widget.qml")

        self.assertEqual(["bar-widget"], manifest["kinds"])
        self.assertEqual("Widget.qml", manifest["entryPoints"]["barWidget"])
        for snippet in [
            'command: ["omarchy-reminder", "show", "--json"]',
            'Quickshell.execDetached(["omarchy-reminder", "show"])',
            'Quickshell.execDetached(["omarchy-reminder", "-i"])',
            'text: root.reminderCount + " DUE"',
        ]:
            self.assertIn(snippet, widget)
        self.assertIn('if (id === "Reminder") return reminderCount > 0', combined)
        self.assertIn('command: ["omarchy-reminder", "show", "--json"]', combined)

    def test_stateful_widgets_do_not_create_parent_visibility_loops(self):
        for plugin in [
            "lacuna.mpris",
            "lacuna.nightlight",
            "lacuna.reminders",
            "lacuna.screen-recording",
            "lacuna.script-pill",
            "lacuna.system-update",
            "lacuna.temperature",
            "lacuna.voxtype",
            "lacuna.weather",
        ]:
            widget = read(f"{plugin}/Widget.qml")
            self.assertNotIn("implicitWidth: visible ?", widget, plugin)
            self.assertNotIn("implicitHeight: visible ?", widget, plugin)

    def test_lacuna_tray_dispatches_status_notifier_context_menus(self):
        manifest = read_json("lacuna.tray/manifest.json")
        qml = read("lacuna.tray/Widget.qml")
        registry = read("lacuna.menu/menu/MenuRegistry.qml")

        self.assertEqual("lacuna.tray", manifest["id"])
        self.assertEqual("Widget.qml", manifest["entryPoints"]["barWidget"])
        self.assertIn("bar-widget", manifest["kinds"])
        self.assertNotIn("QsMenuAnchor", qml)
        self.assertIn("import Quickshell", qml)
        self.assertIn("property bool trayMenuOpen", qml)
        self.assertIn("property var activeTrayItem: null", qml)
        self.assertIn("property var activeTrayAnchor: null", qml)
        self.assertIn("readonly property bool expanded: drawerHovered || trayMenuOpen", qml)
        self.assertIn("function openTrayMenu(item, anchorItem, mouse)", qml)
        self.assertIn("if (!item.menu)", qml)
        self.assertIn("QsMenuOpener", qml)
        self.assertIn("menu: root.activeTrayItem ? root.activeTrayItem.menu : null", qml)
        self.assertIn("id: trayMenuPopup", qml)
        self.assertIn("contentHeight: trayMenuPopup.fittedContentHeight(trayMenuColumn.implicitHeight)", qml)
        self.assertIn("Flickable {", qml)
        self.assertIn("contentHeight: trayMenuColumn.implicitHeight", qml)
        self.assertIn("flickableDirection: Flickable.VerticalFlick", qml)
        self.assertIn("interactive: contentHeight > height", qml)
        self.assertNotIn("Style.space(420)", qml)
        self.assertIn("model: trayMenuOpener.children", qml)
        self.assertIn("menuRow.modelData.triggered()", qml)
        self.assertIn("onPressed: function(mouse)", qml)
        self.assertIn("mouse.button === Qt.RightButton", qml)
        self.assertIn("trayItemRoot.displayMenu(mouse)", qml)
        self.assertIn("trayItemRoot.modelData.onlyMenu", qml)
        self.assertIn("item.display(anchorItem.QsWindow.window, point.x, point.y)", qml)
        self.assertIn("function trayIconFallbackSource(icon)", qml)
        self.assertIn('return Util.fileUrl(iconPath + "/" + name + ".png")', qml)
        self.assertIn("property bool fallbackActive: false", qml)
        self.assertIn("onStatusChanged:", qml)
        self.assertNotIn("Status.Passive", qml)
        self.assertNotIn("trayMenuReset", qml)
        self.assertNotIn("markTrayMenuRequested", qml)
        self.assertIn('root.bar.shell.updateEntryInline(id, { id: id, pinned: pinned, hidden: hidden })', qml)
        self.assertIn('if (key === "lacuna.tray") return "apps"', registry)

    def test_system_stats_uses_tabler_cpu_icon(self):
        qml = read("lacuna.system-stats/Widget.qml")
        flyout = read("lacuna.system-stats/TelemetryFlyout.qml")
        thermal_widget = read("lacuna.temperature/Widget.qml")
        thermal_flyout = read("lacuna.temperature/ThermalFlyout.qml")
        icon = read("lacuna.system-stats/assets/tabler/cpu.svg")

        self.assertIn('iconSource: Qt.resolvedUrl("assets/tabler/cpu.svg")', qml)
        self.assertNotIn('iconSource: Qt.resolvedUrl("assets/tabler/assembly-filled.svg")', qml)
        self.assertIn("icon-tabler-cpu", icon)
        self.assertIn('metric: "disk"', qml)
        self.assertIn('metric: "memory"', qml)
        self.assertIn('metric: "cpu"', qml)
        self.assertIn("TelemetryFlyout {", qml)
        self.assertIn("diskHistory: root.diskHistory", qml)
        self.assertIn("memoryHistory: root.memoryHistory", qml)
        self.assertIn("cpuHistory: root.cpuHistory", qml)
        self.assertNotIn("btop", qml)
        self.assertIn('"SYSTEM / MEMORY"', flyout)
        self.assertIn('"SYSTEM / STORAGE"', flyout)
        self.assertIn('"SYSTEM / PROCESSOR"', flyout)
        self.assertIn("BarFlyoutSurface {", flyout)
        self.assertIn("LacunaDropShadow", flyout)
        self.assertIn("font.letterSpacing: tokens.trackingTitle", flyout)
        self.assertIn("i % 15 === 0", flyout)
        self.assertIn("id: allocationField", flyout)
        self.assertIn('visible: root.mode === "disk"', flyout)
        self.assertIn("font.family: tokens.displayFont; font.pixelSize: tokens.textTelemetry", flyout)
        self.assertIn("ThermalFlyout {", thermal_widget)
        self.assertNotIn("btop", thermal_widget)
        self.assertIn('text: "THERMAL / SENSOR ARRAY"', thermal_flyout)
        self.assertIn("SENSOR FIELD", thermal_flyout)
        self.assertIn("LacunaDropShadow", thermal_flyout)
        self.assertIn("font.family: tokens.displayFont; font.pixelSize: tokens.textTelemetry", thermal_flyout)

    def test_weather_flyout_is_standalone_resilient_and_coordinated(self):
        widget = read("lacuna.weather/Widget.qml")
        flyout = read("lacuna.weather/WeatherFlyout.qml")
        state = read("lacuna.weather/WeatherState.qml")
        model = read("lacuna.weather/WeatherModel.js")
        manifest = json.loads(read("lacuna.weather/manifest.json"))
        defaults = manifest["barWidget"]["defaults"]
        schema = {entry["key"]: entry for entry in manifest["barWidget"]["schema"]}

        self.assertIn("property bool flyoutOpen: false", widget)
        self.assertIn("readonly property bool opened: flyoutOpen", widget)
        for method in ("open", "close", "closeForPopoutSwitch", "toggleFlyout"):
            self.assertIn(f"function {method}()", widget)
        self.assertIn("WeatherState {", widget)
        self.assertIn("WeatherFlyout {", widget)
        self.assertIn("owner: root", widget)
        self.assertIn("weatherState: weatherState", widget)
        self.assertIn("root.refresh(true)", widget)
        self.assertIn("weatherState.notificationText()", widget)
        self.assertIn("readonly property string weatherIcon: weatherState.icon", widget)
        self.assertIn("readonly property string displayText: weatherState.barLabel", widget)
        self.assertIn("readonly property color iconColor: moduleColor", widget)
        self.assertIn("readonly property color textColor: foreground", widget)
        self.assertIn("text: root.weatherIcon", widget)
        self.assertIn("text: root.displayText", widget)
        self.assertIn("font.weight: Font.DemiBold", widget)
        self.assertNotIn("omarchy weather status", widget)

        self.assertIn("readonly property var coordinatorKey: owner || root", flyout)
        self.assertIn('bar.requestPopout(coordinatorKey, anchorItem, owner ? owner.moduleName : "")', flyout)
        self.assertIn("bar.releasePopout(coordinatorKey)", flyout)
        self.assertIn("HyprlandFocusGrab", flyout)
        self.assertIn("onCleared: root.close()", flyout)
        self.assertIn('text: "WEATHER / CONDITIONS"', flyout)
        self.assertIn('text: "FORECAST / 3 DAYS"', flyout)
        self.assertIn("model: root.forecastDays.length > 0 ? root.forecastDays : 3", flyout)
        self.assertIn("function loadFrameSettings(raw)", flyout)
        self.assertIn("shadowEnabled = frame.shadow === true", flyout)
        self.assertIn('configHome + "/omarchy/lacuna/settings.json"', flyout)
        self.assertIn("id: shadowSource", flyout)
        self.assertIn("LacunaDropShadow {", flyout)
        self.assertIn("source: shadowSource", flyout)
        self.assertIn("shadowEnabled: root.shadowEnabled", flyout)
        self.assertIn("readonly property bool contentFitsPanel:", flyout)
        self.assertIn("font.family: root.displayFontFamily", flyout)
        self.assertIn("font.weight: root.displayHeroWeight", flyout)
        self.assertIn("font.letterSpacing: root.displayTitleTracking", flyout)
        tokens = read("lacuna.weather/LacunaTokens.qml")
        self.assertIn('readonly property string displayFont: "Tektur"', tokens)
        self.assertIn("readonly property int displayTelemetryWeight: Font.Normal", tokens)
        self.assertIn("readonly property real trackingTitle: 2.0", tokens)

        self.assertIn("Math.max(60000, Number(setting(\"interval\", 900000))", state)
        self.assertIn("property bool stale: false", state)
        self.assertIn("property string errorText", state)
        self.assertIn("stale = hasData", state)
        self.assertIn("function finishWeatherRequest(raw)", state)
        self.assertIn("function finishDailyRequest(raw)", state)
        self.assertIn("function finishLocationRequest(raw)", state)
        self.assertIn("function finishOpenMeteoRequest(raw)", state)
        self.assertIn("Model.buildLocationUrl", state)
        self.assertIn("Model.buildOpenMeteoWeatherUrl", state)
        self.assertIn("Model.reportFromOpenMeteo", state)
        self.assertIn("Model.buildForecastDays", state)
        self.assertIn('command = ["curl", "-fsS", "--max-time", "5"', state)
        self.assertIn("function buildWttrUrl(location)", model)
        self.assertIn("function buildLocationUrl(location)", model)
        self.assertIn("function parseLocation(raw, override)", model)
        self.assertIn("function buildOpenMeteoWeatherUrl(location)", model)
        self.assertIn("function reportFromOpenMeteo(payload, location)", model)
        self.assertIn("encodeURIComponent(normalized)", model)
        self.assertIn("function shouldUseImperial", model)
        self.assertIn("function openMeteoUrl(report)", model)
        self.assertIn("function buildForecastDays", model)
        self.assertIn("function notificationText(data)", model)

        self.assertEqual(900000, defaults["interval"])
        self.assertEqual("", defaults["location"])
        self.assertEqual("auto", defaults["unit"])
        self.assertEqual(60000, schema["interval"]["min"])
        self.assertEqual(["auto", "imperial", "metric"], schema["unit"]["options"])
        self.assertEqual([], manifest["lacuna"]["requires"])
        self.assertIn('weather: "blue"', read("lacuna.weather/ColorProfile.qml"))

    def test_clock_splits_colored_date_from_foreground_time(self):
        qml = read("lacuna.clock/Widget.qml")

        self.assertIn("readonly property color dateColor: moduleColor", qml)
        self.assertIn("readonly property color timeColor: foreground", qml)
        self.assertIn("readonly property color seamColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)", qml)
        self.assertIn("readonly property int topbarTextSize: barSize <= 26 ? 12 : 13", qml)
        self.assertIn("readonly property int contentSpacing: 5", qml)
        self.assertIn("readonly property int horizontalPadding: vertical ? 0 : 5", qml)
        self.assertIn("function dateFormatPart(format)", qml)
        self.assertIn("function timeFormatPart(format)", qml)
        self.assertIn("readonly property string dateText: formattedWith(displayDate, activeDateFormat)", qml)
        self.assertIn("readonly property string timeText: formattedWith(displayDate, activeTimeFormat)", qml)
        self.assertIn("text: root.dateText", qml)
        self.assertIn("color: root.dateColor", qml)
        self.assertIn("color: root.seamColor", qml)
        self.assertIn("text: root.timeText", qml)
        self.assertIn("color: root.timeColor", qml)
        self.assertEqual(qml.count("font.weight: Font.DemiBold"), 2)
        self.assertIn('clock: "accent"', read("lacuna.clock/ColorProfile.qml"))

    def test_clock_calendar_flyout_is_standalone_read_only_and_coordinated(self):
        widget = read("lacuna.clock/Widget.qml")
        flyout = read("lacuna.clock/CalendarFlyout.qml")
        state = read("lacuna.clock/CalendarState.qml")
        model = read("lacuna.clock/CalendarModel.js")
        manifest = json.loads(read("lacuna.clock/manifest.json"))
        defaults = manifest["barWidget"]["defaults"]
        schema = {entry["key"]: entry for entry in manifest["barWidget"]["schema"]}

        self.assertIn("property bool flyoutOpen: false", widget)
        self.assertIn("readonly property bool opened: flyoutOpen", widget)
        for method in ("open", "close", "closeForPopoutSwitch", "toggleFlyout"):
            self.assertIn(f"function {method}()", widget)
        self.assertIn("CalendarFlyout {", widget)
        self.assertIn("owner: root", widget)
        self.assertIn("liveDate: root.displayDate", widget)
        self.assertIn('bar.run("omarchy menu timezone")', widget)
        self.assertNotIn("property bool alt", widget)
        self.assertNotIn("formatAlt", widget)

        self.assertIn("readonly property var coordinatorKey: owner || root", flyout)
        self.assertIn('bar.requestPopout(coordinatorKey, anchorItem, owner ? owner.moduleName : "")', flyout)
        self.assertIn("bar.releasePopout(coordinatorKey)", flyout)
        self.assertIn("HyprlandFocusGrab", flyout)
        self.assertIn("onCleared: root.close()", flyout)
        self.assertIn("model: calendar.cells", flyout)
        self.assertIn('text: "Today"', flyout)
        self.assertIn("CalendarState {", flyout)
        self.assertIn("import Quickshell.Io", flyout)
        self.assertIn("function loadFrameSettings(raw)", flyout)
        self.assertIn("shadowEnabled = frame.shadow === true", flyout)
        self.assertIn('configHome + "/omarchy/lacuna/settings.json"', flyout)
        self.assertIn("id: shadowSource", flyout)
        self.assertIn("LacunaDropShadow {", flyout)
        self.assertIn("LacunaTokens { id: tokens }", flyout)
        self.assertIn("font.family: root.displayFontFamily", flyout)
        self.assertIn("font.weight: root.displayHeroWeight", flyout)
        self.assertIn("font.letterSpacing: root.displayTitleTracking", flyout)
        self.assertIn('readonly property string displayFont: "Tektur"', read("lacuna.clock/LacunaTokens.qml"))
        self.assertIn("readonly property int displayTelemetryWeight: Font.Normal", read("lacuna.clock/LacunaTokens.qml"))
        self.assertIn("readonly property real trackingTitle: 2.0", read("lacuna.clock/LacunaTokens.qml"))
        self.assertIn("source: shadowSource", flyout)
        self.assertIn("shadowEnabled: root.shadowEnabled", flyout)
        self.assertIn("x: root.shadowLeftMargin", flyout)
        self.assertIn("y: root.shadowTopMargin", flyout)
        self.assertIn("readonly property bool contentFitsPanel:", flyout)
        self.assertIn("height: root.footerHeight", flyout)
        shadow = read("lacuna.clock/LacunaDropShadow.qml")
        self.assertIn("MultiEffect {", shadow)
        self.assertIn("autoPaddingEnabled: root.autoPaddingEnabled", shadow)
        self.assertNotIn("autoPaddingEnabled: true", shadow)

        self.assertIn("function showPreviousMonth()", state)
        self.assertIn("function showNextMonth()", state)
        self.assertIn("function selectCell(cell)", state)
        self.assertIn("function showToday()", state)
        self.assertIn("function syncLiveDate(value)", state)
        self.assertIn("for (var index = 0; index < 42; index++)", model)
        self.assertIn("12, 0, 0, 0", model)
        self.assertIn("1 - first.getDay()", model)
        self.assertIn('locale.toString(date, "ddd")', model)

        self.assertEqual("ddd d", defaults["dateFormat"])
        self.assertEqual("h:mm AP", defaults["timeFormat"])
        self.assertNotIn("formatAlt", defaults)
        self.assertIn("dateFormat", schema)
        self.assertIn("timeFormat", schema)
        self.assertNotIn("formatAlt", schema)
        self.assertEqual([], manifest["lacuna"]["requires"])

        combined = "\n".join((widget, flyout, state, model)).lower()
        for forbidden in ("event backend", "calendar backend", "caldav", "agenda", "create event"):
            self.assertNotIn(forbidden, combined)

    def test_theme_and_wallpaper_widgets_use_details_flyouts_not_switchers(self):
        theme = read("lacuna.theme/Widget.qml")
        wallpaper = read("lacuna.wallpaper/Widget.qml")
        theme_flyout = read("lacuna.theme/ThemeFlyout.qml")
        wallpaper_flyout = read("lacuna.wallpaper/WallpaperFlyout.qml")

        for qml, flyout_type in [(theme, "ThemeFlyout"), (wallpaper, "WallpaperFlyout")]:
            self.assertIn("readonly property bool opened: flyoutOpen", qml)
            self.assertIn("function open()", qml)
            self.assertIn("function close()", qml)
            self.assertIn(f"{flyout_type} {{", qml)
            self.assertNotIn("switcher", qml.lower())
            self.assertNotIn("bar.run(", qml)
        self.assertIn('text: "PALETTE ANATOMY"', theme_flyout)
        self.assertIn('"dark_bg", "bg", "lighter_bg", "muted"', theme_flyout)
        self.assertIn('iconSource: Qt.resolvedUrl("assets/tabler/palette.svg")', theme)
        self.assertIn("text: root.displayText", theme)
        self.assertIn('iconSource: Qt.resolvedUrl("assets/tabler/photo.svg")', wallpaper)
        self.assertIn("text: root.displayText", wallpaper)
        self.assertIn("interval: 1500", wallpaper)
        self.assertIn("onTriggered: root.refresh()", wallpaper)
        self.assertIn('text: "ACTIVE WALLPAPER"', wallpaper_flyout)
        self.assertIn("Image {", wallpaper_flyout)
        self.assertNotIn("switcher", theme_flyout.lower())
        self.assertNotIn("switcher", wallpaper_flyout.lower())

        for flyout in [theme_flyout, wallpaper_flyout]:
            self.assertIn("LacunaTokens { id: tokens }", flyout)
            self.assertIn("MotionTokens {", flyout)
            self.assertIn("animationDisabled: root.reduceMotion", flyout)
            self.assertIn("duration: motionTokens.reveal", flyout)
            self.assertIn("(root.reveal - 0.55) / 0.45", flyout)
            self.assertIn("font.family: tokens.displayFont", flyout)
            self.assertIn("font.pixelSize: tokens.textTitle", flyout)
            self.assertIn("font.letterSpacing: tokens.trackingTitle", flyout)
            self.assertIn("font.family: tokens.monoFont", flyout)
            self.assertIn("font.pixelSize: tokens.textSmall", flyout)
        self.assertNotIn("width: 52; height: 3", wallpaper_flyout)
        self.assertNotIn("width: 10\n", theme_flyout)

        menu_header = read("lacuna.menu/menu/MenuHeader.qml")
        menu_section = read("lacuna.menu/menu/MenuSection.qml")
        menu_item = read("lacuna.menu/modules/LacunaMenuItem.qml")
        self.assertIn("tokens.trackingTitleCompact : tokens.trackingTitle", menu_header)
        self.assertIn("typeTokens.trackingSection", menu_section)
        self.assertIn("tokens.trackingMenuItemCompact : tokens.trackingMenuItem", menu_item)

    def test_background_animations_use_single_selected_effect_contract(self):
        manifest = read_json("lacuna.aurora-drift/manifest.json")
        qml = read("lacuna.aurora-drift/Overlay.qml")
        rain_manifest = read_json("lacuna.rainfall-overlay/manifest.json")
        rain = read("lacuna.rainfall-overlay/Overlay.qml")
        cinematic_manifest = read_json("lacuna.cinematic-light-overlay/manifest.json")
        cinematic = read("lacuna.cinematic-light-overlay/Overlay.qml")
        crt_manifest = read_json("lacuna.crt-overlay/manifest.json")
        crt = read("lacuna.crt-overlay/Overlay.qml")
        vhs_manifest = read_json("lacuna.vhs-overlay/manifest.json")
        vhs = read("lacuna.vhs-overlay/Overlay.qml")
        film_manifest = read_json("lacuna.film-grain-overlay/manifest.json")
        film = read("lacuna.film-grain-overlay/Overlay.qml")
        dust_manifest = read_json("lacuna.dust-motes-overlay/manifest.json")
        dust = read("lacuna.dust-motes-overlay/Overlay.qml")
        vignette_manifest = read_json("lacuna.background-vignette/manifest.json")
        vignette = read("lacuna.background-vignette/Overlay.qml")
        settings = read("lacuna.menu/services/LacunaSettings.qml")
        state_service = read("lacuna.state/Service.qml")
        registry = read("lacuna.menu/menu/MenuRegistry.qml")
        shell_settings_panel = read("lacuna.shell-settings/Panel.qml")
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")
        example = read_json("config/shell.lacuna-native-replacements.example.json")
        settings_example = read_json("config/settings.example.json")
        full_settings = read_json("tests/fixtures/full-settings.json")

        self.assertEqual("lacuna.aurora-drift", manifest["id"])
        self.assertEqual(["overlay"], manifest["kinds"])
        self.assertEqual("Overlay.qml", manifest["entryPoints"]["overlay"])
        self.assertEqual("lacuna.rainfall-overlay", rain_manifest["id"])
        self.assertEqual(["overlay"], rain_manifest["kinds"])
        self.assertEqual("Overlay.qml", rain_manifest["entryPoints"]["overlay"])
        self.assertEqual("lacuna.cinematic-light-overlay", cinematic_manifest["id"])
        self.assertEqual(["overlay"], cinematic_manifest["kinds"])
        self.assertEqual("persistent", cinematic_manifest["activation"])
        self.assertIs(cinematic_manifest["keepLoaded"], True)
        self.assertEqual("Overlay.qml", cinematic_manifest["entryPoints"]["overlay"])
        self.assertEqual("lacuna.film-grain-overlay", film_manifest["id"])
        self.assertEqual(["overlay"], film_manifest["kinds"])
        self.assertEqual("persistent", film_manifest["activation"])
        self.assertIs(film_manifest["keepLoaded"], True)
        self.assertEqual("Overlay.qml", film_manifest["entryPoints"]["overlay"])
        self.assertEqual("lacuna.dust-motes-overlay", dust_manifest["id"])
        self.assertEqual(["overlay"], dust_manifest["kinds"])
        self.assertEqual("persistent", dust_manifest["activation"])
        self.assertIs(dust_manifest["keepLoaded"], True)
        self.assertEqual("Overlay.qml", dust_manifest["entryPoints"]["overlay"])
        self.assertEqual(1, cinematic_manifest["defaults"]["intensity"])
        self.assertEqual("lightLeak", cinematic_manifest["defaults"]["stylePreset"])
        self.assertTrue(cinematic_manifest["defaults"]["slowDrift"])
        self.assertFalse(cinematic_manifest["defaults"]["occasionalSweeps"])
        self.assertFalse(cinematic_manifest["defaults"]["activeShimmer"])
        self.assertEqual("lacuna.crt-overlay", crt_manifest["id"])
        self.assertEqual(["overlay"], crt_manifest["kinds"])
        self.assertEqual("persistent", crt_manifest["activation"])
        self.assertIs(crt_manifest["keepLoaded"], True)
        self.assertEqual("Overlay.qml", crt_manifest["entryPoints"]["overlay"])
        self.assertFalse(crt_manifest["defaults"]["foregroundOverlay"])
        self.assertTrue(crt_manifest["defaults"]["distortion"])
        self.assertTrue(crt_manifest["defaults"]["bloomPulse"])
        self.assertFalse(vhs_manifest["defaults"]["foregroundOverlay"])
        self.assertEqual("lacuna.background-vignette", vignette_manifest["id"])
        self.assertEqual(["overlay"], vignette_manifest["kinds"])
        self.assertEqual("persistent", vignette_manifest["activation"])
        self.assertIs(vignette_manifest["keepLoaded"], True)
        self.assertEqual("Overlay.qml", vignette_manifest["entryPoints"]["overlay"])
        self.assertIn("backgroundVignette", settings)
        self.assertIn("ignoreBackgroundAnimationLayer", settings)
        self.assertIn("backgroundVignetteSettings()", vignette)
        self.assertIn('if (text.length === 0) return false', vignette)
        self.assertIn('if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return false', vignette)
        self.assertIn("return false", vignette)
        self.assertNotIn("onLoadFailed: root.lacunaSettings = {}", vignette)
        self.assertIn("WlrLayer.Background", vignette)
        self.assertIn("WlrLayer.Bottom", vignette)
        self.assertIn("function resolveFrameRect(screen)", vignette)
        self.assertIn("readonly property string frameGeometryKey: resolveFrameGeometryKey()", vignette)
        self.assertIn("readonly property int frameGeometryRevision: resolveFrameGeometryRevision()", vignette)
        self.assertIn("function resolveFrameGeometryRevision()", vignette)
        self.assertIn("root.shell.bar.lacunaFrameGeometryRevision", vignette)
        self.assertIn("function resolveFrameGeometryKey()", vignette)
        self.assertIn("root.shell.bar.lacunaFrameGeometryKey", vignette)
        self.assertIn("root.shell.bar.lacunaFrameContentRect(screen)", vignette)
        self.assertIn("readonly property var frameRect: {", vignette)
        self.assertIn("root.frameGeometryKey", vignette)
        self.assertIn("root.frameGeometryRevision", vignette)
        self.assertIn("modelData.width", vignette)
        self.assertIn("modelData.height", vignette)
        self.assertIn("return root.resolveFrameRect(modelData)", vignette)
        self.assertIn("x: Math.round(vignetteWindow.frameRect.x)", vignette)
        self.assertIn("y: Math.round(vignetteWindow.frameRect.y)", vignette)
        self.assertIn("width: Math.round(vignetteWindow.frameRect.width)", vignette)
        self.assertIn("height: Math.round(vignetteWindow.frameRect.height)", vignette)
        self.assertIn("radius: Math.max(0, Number(vignetteWindow.frameRect.radius || 0))", vignette)
        self.assertIn('color: "transparent"', vignette)
        self.assertIn("clip: true", vignette)
        self.assertIn('source: Qt.resolvedUrl("assets/vignette.svg")', vignette)
        self.assertIn("readonly property real outputScale:", vignette)
        self.assertIn("sourceSize.width: Math.max(1, Math.round((Number(vignetteWindow.modelData.width) || 1)", vignette)
        self.assertIn("sourceSize.height: Math.max(1, Math.round((Number(vignetteWindow.modelData.height) || 1)", vignette)
        self.assertGreaterEqual(vignette.count("* vignetteWindow.outputScale"), 2)
        self.assertNotIn("sourceSize.width: width", vignette)
        self.assertNotIn("sourceSize.height: height", vignette)
        self.assertIn("fillMode: Image.Stretch", vignette)
        self.assertNotIn("LacunaVignette", vignette)
        self.assertNotIn("Canvas {", vignette)
        self.assertNotIn("gradient: Gradient", vignette)
        self.assertNotIn("ShaderEffect", vignette)
        self.assertFalse((ROOT / "lacuna.background-vignette/shaders").exists())
        self.assertTrue((ROOT / "lacuna.background-vignette/assets/vignette.svg").exists())
        vignette_asset = read("lacuna.background-vignette/assets/vignette.svg")
        self.assertIn('id="left-edge"', vignette_asset)
        self.assertIn('id="right-edge"', vignette_asset)

        self.assertIn("stylePreset", [entry["key"] for entry in cinematic_manifest["schema"]])
        self.assertIn("slowDrift", [entry["key"] for entry in cinematic_manifest["schema"]])
        self.assertIn("occasionalSweeps", [entry["key"] for entry in cinematic_manifest["schema"]])
        self.assertIn("activeShimmer", [entry["key"] for entry in cinematic_manifest["schema"]])
        self.assertIn("foregroundOverlay", [entry["key"] for entry in crt_manifest["schema"]])
        self.assertIn("distortion", [entry["key"] for entry in crt_manifest["schema"]])
        self.assertIn("distortionAmount", [entry["key"] for entry in crt_manifest["schema"]])
        self.assertIn("bloomPulse", [entry["key"] for entry in crt_manifest["schema"]])
        self.assertIn("bloomPulseAmount", [entry["key"] for entry in crt_manifest["schema"]])
        self.assertIn("bloomPulseInterval", [entry["key"] for entry in crt_manifest["schema"]])
        self.assertIn("foregroundOverlay", [entry["key"] for entry in vhs_manifest["schema"]])
        self.assertIn("grainCount", [entry["key"] for entry in film_manifest["schema"]])
        self.assertIn("grainSize", [entry["key"] for entry in film_manifest["schema"]])
        self.assertIn("moteCount", [entry["key"] for entry in dust_manifest["schema"]])
        self.assertIn("moteSize", [entry["key"] for entry in dust_manifest["schema"]])
        self.assertIn("mouseReactive", [entry["key"] for entry in dust_manifest["schema"]])
        self.assertIn("mouseInfluence", [entry["key"] for entry in dust_manifest["schema"]])
        self.assertIn('backgroundEffectEnabled("auroraDrift", true)', qml)
        self.assertIn('backgroundEffectEnabled("filmGrain", true)', film)
        self.assertIn('backgroundEffectEnabled("dustMotes", true)', dust)
        self.assertIn('backgroundEffectEnabled("rainfall", true)', rain)
        self.assertIn('backgroundEffectEnabled("cinematicLight", true)', cinematic)
        self.assertIn('backgroundEffectEnabled("crt", true)', crt)
        self.assertIn("foregroundOverlay: false", settings)
        self.assertIn("foregroundOverlay: false", state_service)
        self.assertIn("opacity: 1", settings)
        self.assertIn("opacity: 1", state_service)
        self.assertIn("activeEffects: [", settings)
        self.assertIn("activeEffects: [", state_service)
        self.assertIn("function normalizeBackgroundEffectStack", settings)
        self.assertIn("function normalizeBackgroundEffectStack", state_service)
        self.assertIn("function normalizeBackgroundEffectConfig", settings)
        self.assertIn("function normalizeBackgroundEffectConfig", state_service)
        self.assertIn("intensity: 0.28", settings)
        self.assertIn("grainCount: 180", settings)
        self.assertIn("grainSize: 1.35", settings)
        self.assertIn("accentBlend: 0.18", settings)
        self.assertEqual(1, settings_example["backgroundEffects"]["opacity"])
        self.assertEqual(0.28, settings_example["backgroundEffects"]["effects"]["filmGrain"]["intensity"])
        self.assertEqual(180, settings_example["backgroundEffects"]["effects"]["filmGrain"]["grainCount"])
        self.assertEqual(0.92, full_settings["backgroundEffects"]["opacity"])
        self.assertEqual(0.42, full_settings["backgroundEffects"]["effects"]["filmGrain"]["intensity"])
        self.assertIn("mediaProviders", settings_example)
        self.assertIn("youtube", settings_example["mediaProviders"])
        self.assertFalse(settings_example["mediaProviders"]["youtube"]["enabled"])
        self.assertIn("jellyfin", settings_example["mediaProviders"])
        self.assertFalse(settings_example["mediaProviders"]["jellyfin"]["enabled"])
        self.assertEqual("firefox", full_settings["mediaProviders"]["youtube"]["cookiesFromBrowser"])
        self.assertEqual("https://jellyfin.example", full_settings["mediaProviders"]["jellyfin"]["serverUrl"])
        self.assertIn("mediaProviders", read("lacuna.menu/services/LacunaSettings.qml"))
        self.assertIn("function normalizeMediaProviders", read("lacuna.menu/services/LacunaSettings.qml"))
        self.assertIn("function normalizeMediaProviders", read("lacuna.state/Service.qml"))
        self.assertIn("userId", settings_example["mediaProviders"]["jellyfin"])
        self.assertEqual("fixture-user", full_settings["mediaProviders"]["jellyfin"]["userId"])
        self.assertEqual("English", settings_example["mediaProviders"]["jellyfin"]["preferredAudioLanguage"])
        self.assertEqual("English", full_settings["mediaProviders"]["jellyfin"]["preferredAudioLanguage"])
        self.assertEqual("auto", settings_example["mediaPlayer"]["presentationMode"])
        self.assertEqual("adaptive", settings_example["mediaPlayer"]["videoQuality"])
        self.assertEqual("all", settings_example["mediaPlayer"]["providerFilter"])
        self.assertEqual("background", full_settings["mediaPlayer"]["presentationMode"])
        self.assertEqual("stable", full_settings["mediaPlayer"]["videoQuality"])
        self.assertEqual("jellyfin", full_settings["mediaPlayer"]["providerFilter"])
        self.assertIn("function normalizeMediaPlayer", read("lacuna.menu/services/LacunaSettings.qml"))
        self.assertIn("function normalizeMediaPlayer", read("lacuna.state/Service.qml"))
        self.assertIn("backgroundEffects.activeEffect", qml)
        self.assertIn("backgroundEffects.activeEffect", vhs)
        self.assertIn("backgroundEffects.activeEffect", film)
        self.assertIn("backgroundEffects.activeEffect", dust)
        self.assertIn("backgroundEffects.activeEffect", rain)
        self.assertIn("backgroundEffects.activeEffect", cinematic)
        self.assertIn("backgroundEffects.activeEffect", crt)
        for overlay in [qml, vhs, film, dust, rain, cinematic, crt, read("lacuna.god-rays-overlay/Overlay.qml")]:
            self.assertIn("Array.isArray(backgroundEffects.activeEffects)", overlay)
            self.assertIn("backgroundEffects.activeEffects.length", overlay)
            self.assertIn("readonly property bool foregroundOverlay: backgroundForegroundOverlayEnabled()", overlay)
            self.assertIn("* backgroundAnimationOpacity()", overlay)
            self.assertIn("function backgroundAnimationOpacity()", overlay)
            self.assertIn("function backgroundForegroundOverlayEnabled", overlay)
            self.assertIn("backgroundEffects.foregroundOverlay === true", overlay)
            self.assertIn("WlrLayershell.layer: root.foregroundOverlay ? WlrLayer.Overlay : WlrLayer.Bottom", overlay)
        self.assertIn('target: "lacuna-film-grain-overlay"', film)
        self.assertIn('WlrLayershell.namespace: "lacuna-film-grain-overlay"', film)
        self.assertIn('readonly property var filmGrainSettings: backgroundEffectSettings("filmGrain")', film)
        self.assertIn("function effectNumberSetting", film)
        self.assertIn("function backgroundEffectSettings", film)
        self.assertIn("animationOpacity: root.backgroundAnimationOpacity()", film)
        self.assertIn("FrameAnimation {", film)
        self.assertIn("model: root.grainCount", film)
        self.assertIn("color: root.grainColor", film)
        self.assertNotIn("ShaderEffect {", film)
        self.assertFalse((ROOT / "lacuna.film-grain-overlay/shaders").exists())
        self.assertIn('target: "lacuna-dust-motes-overlay"', dust)
        self.assertIn('WlrLayershell.namespace: "lacuna-dust-motes-overlay"', dust)
        self.assertIn('readonly property var dustMotesSettings: backgroundEffectSettings("dustMotes")', dust)
        self.assertIn('readonly property bool mouseReactive: effectBoolSetting("mouseReactive", "mouseReactive", true)', dust)
        self.assertIn('readonly property real mouseInfluence: clamp(effectNumberSetting("mouseInfluence", "mouseInfluence", 0.28), 0, 1)', dust)
        self.assertIn("function effectBoolSetting", dust)
        self.assertIn("function backgroundEffectSettings", dust)
        self.assertIn('cursorProc.command = ["hyprctl", "cursorpos", "-j"]', dust)
        self.assertIn("function applyCursorPayload", dust)
        self.assertIn("cursorDecayTimer.restart()", dust)
        self.assertIn("ListModel {", dust)
        self.assertIn("transientMotes.append({", dust)
        self.assertIn("var cursorFalloff = Math.pow(1 - cursorDistance / root.cursorInfluenceRadius, 1.35)", dust)
        self.assertIn("transform: [", dust)
        self.assertIn("Translate {", dust)
        self.assertIn("SequentialAnimation on x", dust)
        self.assertIn("SequentialAnimation on y", dust)
        self.assertIn('target: "lacuna-aurora-drift"', qml)
        self.assertIn('WlrLayershell.namespace: "lacuna-aurora-drift"', qml)
        self.assertIn('target: "lacuna-rainfall-overlay"', rain)
        self.assertIn('WlrLayershell.namespace: "lacuna-rainfall-overlay"', rain)
        self.assertIn("model: root.dropCount", rain)
        self.assertIn("readonly property int dropLength", rain)
        self.assertNotIn("import QtQuick.Particles", rain)
        self.assertFalse((ROOT / "lacuna.rainfall-overlay/assets").exists())
        self.assertIn('target: "lacuna-cinematic-light-overlay"', cinematic)
        self.assertIn('WlrLayershell.namespace: "lacuna-cinematic-light-overlay"', cinematic)
        self.assertIn('target: "lacuna-crt-overlay"', crt)
        self.assertIn('WlrLayershell.namespace: "lacuna-crt-overlay"', crt)
        self.assertIn("mask: Region {}", qml)
        self.assertIn("mask: Region {}", film)
        self.assertIn("mask: Region {}", dust)
        self.assertIn("mask: Region {}", rain)
        self.assertIn("mask: Region {}", cinematic)
        self.assertIn("mask: Region {}", crt)
        self.assertIn("staticBand", crt)
        self.assertIn("curvedGlassDistortion", crt)
        self.assertIn("visible: root.foregroundOverlay && root.distortion", crt)
        self.assertIn('readonly property string stylePreset: normalizeStylePreset(settingValue("stylePreset", "lightLeak"))', cinematic)
        self.assertIn("readonly property bool slowDriftEnabled", cinematic)
        self.assertIn("readonly property bool occasionalSweepsEnabled", cinematic)
        self.assertIn("readonly property bool activeShimmerEnabled", cinematic)
        self.assertIn("readonly property real ambientWashOpacity", cinematic)
        self.assertIn("readonly property real ambientBandOpacity", cinematic)
        self.assertIn("property real ambientPulse", cinematic)
        self.assertIn("running: root.effectVisible && !root.reducedMotion && root.slowDriftEnabled", cinematic)
        self.assertIn("readonly property int hiddenPause: root.slowDriftEnabled", cinematic)
        self.assertIn("readonly property int darkPause: root.slowDriftEnabled", cinematic)
        self.assertIn('if (preset === "cinematicFlare" || preset === "anamorphicGlow") return preset', cinematic)
        self.assertIn('if (mode === "occasionalSweeps" || mode === "activeShimmer") return mode', cinematic)
        self.assertIn("motionModes: {", cinematic)
        self.assertIn("readonly property real xSwing: 0.055", qml)
        self.assertIn("readonly property real ySwing: 0.04", qml)
        self.assertIn("readonly property int cycleXDirection", cinematic)
        self.assertIn("readonly property int cycleYDirection", cinematic)
        self.assertIn('activeEffect: "trackingLines"', settings)
        self.assertIn('"trackingLines"', settings)
        self.assertIn('filmGrain: {', settings)
        self.assertIn('dustMotes: {', settings)
        self.assertIn('auroraDrift: {', settings)
        self.assertIn('rainfall: {', settings)
        self.assertIn('cinematicLight: {', settings)
        self.assertIn('godRays: {', settings)
        self.assertIn('crt: {', settings)
        self.assertIn('activeEffect: "trackingLines"', state_service)
        self.assertIn('"trackingLines"', state_service)
        self.assertIn('filmGrain: {', state_service)
        self.assertIn('dustMotes: {', state_service)
        self.assertIn('auroraDrift: {', state_service)
        self.assertIn('rainfall: {', state_service)
        self.assertIn('cinematicLight: {', state_service)
        self.assertIn('godRays: {', state_service)
        self.assertIn('crt: {', state_service)
        self.assertIn("function activeBackgroundEffect", registry)
        self.assertIn("function activeBackgroundEffects", registry)
        self.assertIn("function backgroundEffectStackIndex", registry)
        self.assertIn("function backgroundEffectStackCount", registry)
        self.assertIn("function backgroundEffectStackWarning", registry)
        self.assertIn("function backgroundEffectOptions", registry)
        self.assertIn("root.pluginRegistry.isEnabled(id)", registry)
        self.assertIn("pluginRegistry.isEnabled(id)", shell_settings_panel)
        self.assertIn("shellBarWidgetExistsAnywhere(id)", registry)
        self.assertIn("function backgroundEffectPluginId", registry)
        self.assertIn('if (effectId === "filmGrain") return "lacuna.film-grain-overlay"', registry)
        self.assertIn('if (effectId === "dustMotes") return "lacuna.dust-motes-overlay"', registry)
        self.assertIn('if (effectId === "auroraDrift") return "lacuna.aurora-drift"', registry)
        self.assertIn('if (effectId === "rainfall") return "lacuna.rainfall-overlay"', registry)
        self.assertIn('if (effectId === "cinematicLight") return "lacuna.cinematic-light-overlay"', registry)
        self.assertIn("function backgroundEffectForegroundEnabled", registry)
        self.assertIn("function backgroundEffectsForegroundOverlayEnabled", registry)
        self.assertIn("function backgroundVignetteIntensity", registry)
        self.assertIn("function backgroundVignetteIntensityName", registry)
        self.assertIn("function backgroundVignetteIntensityHint", registry)
        self.assertIn("function backgroundAnimationOpacity", registry)
        self.assertIn("function backgroundAnimationOpacityName", registry)
        self.assertIn("function backgroundAnimationOpacityHint", registry)
        self.assertIn("function backgroundEffectRuntimeSettings", registry)
        self.assertIn("function filmGrainSettings", registry)
        self.assertIn("function filmGrainIntensity", registry)
        self.assertIn("function filmGrainGrainCount", registry)
        self.assertIn("function filmGrainGrainSize", registry)
        self.assertIn("function filmGrainAccentBlend", registry)
        self.assertIn("function dustMotesSettings", registry)
        self.assertIn("function dustMotesIntensity", registry)
        self.assertIn("function dustMotesSpeed", registry)
        self.assertIn("function dustMotesMoteCount", registry)
        self.assertIn("function dustMotesMoteSize", registry)
        self.assertIn("function dustMotesAccentBlend", registry)
        self.assertIn("function dustMotesMouseReactive", registry)
        self.assertIn("function dustMotesMouseInfluence", registry)
        self.assertIn("function cinematicLightSettings", registry)
        self.assertIn("function cinematicLightIntensityOptions", registry)
        self.assertIn("function cinematicLightIntensity", registry)
        self.assertIn("function cinematicLightIntensityHint", registry)
        self.assertIn("function cinematicLightStyleOptions", registry)
        self.assertIn("function cinematicLightMotionModes", registry)
        self.assertIn("function cinematicLightSlowDriftEnabled", registry)
        self.assertIn("function cinematicLightOccasionalSweepsEnabled", registry)
        self.assertIn("function cinematicLightActiveShimmerEnabled", registry)
        self.assertIn('if (effectId === "auroraDrift") return "Aurora Drift"', registry)
        self.assertIn('if (effectId === "filmGrain") return "Film Grain"', registry)
        self.assertIn('if (effectId === "dustMotes") return "Dust Motes"', registry)
        self.assertIn('if (effectId === "rainfall") return "Rainfall"', registry)
        self.assertIn('if (effectId === "cinematicLight") return "Cinematic Light"', registry)
        self.assertIn('if (effectId === "godRays") return "God Rays"', registry)
        self.assertIn('if (effectId === "crt") return "CRT"', registry)
        self.assertIn('"toggle-background-effects"', settings_window)
        self.assertIn('{ id: "animations", icon: "background", label: "Animations"', settings_window)
        self.assertIn('navRow("background", "Animations", root.registry.backgroundEffectsHint(), "animations"', settings_window)
        self.assertIn('if (sectionId === "animations")', settings_window)
        self.assertIn('return backgroundEffectRows()', settings_window)
        self.assertIn('width: 560', settings_window)
        self.assertIn('height: 660', settings_window)
        self.assertNotIn('].concat(backgroundEffectRows())', settings_window)
        self.assertNotIn('showLabels: true', settings_window)
        self.assertIn('"toggle-background-vignette"', settings_window)
        self.assertIn('"Vignette Intensity"', settings_window)
        self.assertIn('"slider"', settings_window)
        self.assertIn('"set-background-vignette-intensity-"', settings_window)
        self.assertIn('"Animation Opacity"', settings_window)
        self.assertIn('"set-background-animation-opacity-"', settings_window)
        self.assertIn('"Global"', settings_window)
        self.assertIn('"Active Animations"', settings_window)
        self.assertIn("Front to back; #1 is topmost", settings_window)
        self.assertIn('"Add Animation"', settings_window)
        self.assertIn('"Effect Controls"', settings_window)
        self.assertIn('"Film Grain"', settings_window)
        self.assertIn('"Grain Opacity"', settings_window)
        self.assertIn('"Grain Size"', settings_window)
        self.assertIn('"Grain Count"', settings_window)
        self.assertIn('"Grain Speed"', settings_window)
        self.assertIn('"Accent Tint"', settings_window)
        self.assertIn('"set-film-grain-intensity-"', settings_window)
        self.assertIn('"set-film-grain-size-"', settings_window)
        self.assertIn('"set-film-grain-count-"', settings_window)
        self.assertIn('"set-film-grain-speed-"', settings_window)
        self.assertIn('"set-film-grain-accent-"', settings_window)
        self.assertIn('"Dust Motes"', settings_window)
        self.assertIn('"Mote Opacity"', settings_window)
        self.assertIn('"Mote Speed"', settings_window)
        self.assertIn('"Mote Count"', settings_window)
        self.assertIn('"Mote Size"', settings_window)
        self.assertIn('"Mouse Reactive"', settings_window)
        self.assertIn('"Mouse Influence"', settings_window)
        self.assertIn('"set-dust-motes-intensity-"', settings_window)
        self.assertIn('"set-dust-motes-speed-"', settings_window)
        self.assertIn('"set-dust-motes-count-"', settings_window)
        self.assertIn('"set-dust-motes-size-"', settings_window)
        self.assertIn('"set-dust-motes-accent-"', settings_window)
        self.assertIn('"toggle-dust-motes-mouse-reactive"', settings_window)
        self.assertIn('"set-dust-motes-mouse-influence-"', settings_window)
        self.assertIn('"stack-effect"', settings_window)
        self.assertIn("SettingsStackRow", settings_window)
        self.assertIn('"move-background-effect-up-"', settings_window)
        self.assertIn('"move-background-effect-down-"', settings_window)
        self.assertIn("function activateEntryAction", settings_window)
        self.assertIn('next.control = "button"', settings_window)
        slider = read("lacuna.menu/components/LacunaSlider.qml")
        stack_row = read("lacuna.menu/settings/SettingsStackRow.qml")
        self.assertIn('root.control === "slider"', read("lacuna.menu/settings/SettingsRow.qml"))
        self.assertIn("LacunaSlider", read("lacuna.menu/settings/SettingsRow.qml"))
        self.assertIn("signal sliderChanged(string value)", read("lacuna.menu/settings/SettingsRow.qml"))
        self.assertIn("signal edited(real value)", slider)
        self.assertIn("id: sliderHitArea", slider)
        self.assertIn("anchors.fill: parent", slider)
        self.assertIn("cursorShape: Qt.PointingHandCursor", slider)
        self.assertIn("onPressed: function(mouse)", slider)
        self.assertIn("root.previewAt(mouse.x)", slider)
        self.assertIn("onPositionChanged: function(mouse)", slider)
        self.assertIn("if (pressed) root.previewAt(mouse.x)", slider)
        self.assertIn("onReleased: function(mouse)", slider)
        self.assertIn("root.commitEdit()", slider)
        self.assertIn("signal edited(real value)", slider)
        self.assertIn("property bool editing: false", slider)
        self.assertIn("Behavior on scale", slider)
        self.assertIn("visualNormalizedValue", slider)
        self.assertNotIn("Math.round(raw / step) * step", slider)
        self.assertIn("signal moveUp()", stack_row)
        self.assertIn("signal moveDown()", stack_row)
        self.assertIn('icon: "arrow-up"', stack_row)
        self.assertIn('icon: "arrow-down"', stack_row)
        self.assertIn('name: "plus"', stack_row)
        self.assertIn('text: "Add"', stack_row)
        self.assertIn('"set-background-effect-"', window)
        self.assertNotIn('selectRow("background", "Animation"', settings_window)
        self.assertIn('"toggle-background-effect-foreground-"', settings_window)
        self.assertIn('root.registry.backgroundEffectEnabled("cinematicLight")', settings_window)
        self.assertIn('"set-cinematic-light-style-"', settings_window)
        self.assertIn('"set-cinematic-light-intensity-"', settings_window)
        self.assertIn('"toggle-cinematic-light-motion-slowDrift"', settings_window)
        self.assertIn('"toggle-cinematic-light-motion-occasionalSweeps"', settings_window)
        self.assertIn('"toggle-cinematic-light-motion-activeShimmer"', settings_window)
        self.assertIn("SettingsSelectRow", settings_window)
        self.assertIn("function setBackgroundEffectsEnabled", window)
        self.assertIn("function ensureAmbienceHostPlugin", window)
        self.assertIn("registry.ambienceHostPluginId()", window)
        self.assertIn("function setBackgroundVignetteEnabled", window)
        self.assertIn("function setBackgroundVignetteIntensity", window)
        self.assertIn("function setBackgroundAnimationOpacity", window)
        self.assertIn("function setBackgroundEffect", window)
        self.assertIn("function setBackgroundEffectStackEnabled", window)
        self.assertIn("function moveBackgroundEffectInStack", window)
        self.assertIn("next.backgroundEffects.activeEffects = stack", window)
        self.assertIn('entry.action.indexOf("toggle-background-effect-") === 0 && entry.action.indexOf("toggle-background-effect-foreground-") !== 0', window)
        self.assertIn('entry.action.indexOf("move-background-effect-up-") === 0', window)
        self.assertIn('entry.action.indexOf("move-background-effect-down-") === 0', window)
        self.assertIn("function toggleBackgroundEffectForeground", window)
        self.assertIn("next.backgroundEffects.foregroundOverlay = enabled === true", window)
        self.assertIn("setShellPluginEnabled(pluginId, true)", window)
        self.assertIn("function setFilmGrainSetting", window)
        self.assertIn('ensureBackgroundEffectPlugin("filmGrain")', window)
        self.assertIn("function setDustMotesSetting", window)
        self.assertIn('ensureBackgroundEffectPlugin("dustMotes")', window)
        self.assertIn("function setCinematicLightSetting", window)
        self.assertIn("function toggleCinematicLightMotion", window)
        self.assertIn('shell.updateEntryInline("lacuna.cinematic-light-overlay", next)', window)
        self.assertNotIn("next.foregroundOverlay = enabled === true", window)
        self.assertIn('entry.action.indexOf("toggle-background-effect-foreground-") === 0', window)
        self.assertIn('entry.action.indexOf("set-background-vignette-intensity-") === 0', window)
        self.assertIn('entry.action.indexOf("set-background-animation-opacity-") === 0', window)
        self.assertIn('entry.action.indexOf("set-film-grain-intensity-") === 0', window)
        self.assertIn('entry.action.indexOf("set-film-grain-size-") === 0', window)
        self.assertIn('entry.action.indexOf("set-film-grain-count-") === 0', window)
        self.assertIn('entry.action.indexOf("set-film-grain-speed-") === 0', window)
        self.assertIn('entry.action.indexOf("set-film-grain-accent-") === 0', window)
        self.assertIn('entry.action.indexOf("set-dust-motes-intensity-") === 0', window)
        self.assertIn('entry.action.indexOf("set-dust-motes-speed-") === 0', window)
        self.assertIn('entry.action.indexOf("set-dust-motes-count-") === 0', window)
        self.assertIn('entry.action.indexOf("set-dust-motes-size-") === 0', window)
        self.assertIn('entry.action.indexOf("set-dust-motes-accent-") === 0', window)
        self.assertIn('entry.action === "toggle-dust-motes-mouse-reactive"', window)
        self.assertIn('entry.action.indexOf("set-dust-motes-mouse-influence-") === 0', window)
        self.assertIn('entry.action.indexOf("set-cinematic-light-style-") === 0', window)
        self.assertIn('entry.action.indexOf("set-cinematic-light-intensity-") === 0', window)
        self.assertIn('entry.action.indexOf("toggle-cinematic-light-motion-") === 0', window)
        self.assertNotIn('"toggle-background-effect-auroraDrift"', settings_window)
        self.assertIn("lacuna.aurora-drift", [entry["id"] for entry in example["plugins"]])
        self.assertIn("lacuna.film-grain-overlay", [entry["id"] for entry in example["plugins"]])
        self.assertIn("lacuna.dust-motes-overlay", [entry["id"] for entry in example["plugins"]])
        self.assertIn("lacuna.rainfall-overlay", [entry["id"] for entry in example["plugins"]])
        self.assertIn("lacuna.cinematic-light-overlay", [entry["id"] for entry in example["plugins"]])
        self.assertIn("lacuna.god-rays-overlay", [entry["id"] for entry in example["plugins"]])
        self.assertIn("lacuna.crt-overlay", [entry["id"] for entry in example["plugins"]])
        self.assertIn("lacuna.background-vignette", [entry["id"] for entry in example["plugins"]])
        example_ids = [entry["id"] for entry in example["plugins"]]
        self.assertLess(example_ids.index("lacuna.ambience-host"), example_ids.index("lacuna.vhs-overlay"))

    def test_ambience_host_orders_siblings_and_suppresses_fallback_windows(self):
        host = read("lacuna.ambience-host/Overlay.qml")
        stack = read("lacuna.ambience-host/AmbienceStack.qml")
        foreground_border = read("lacuna.ambience-host/ForegroundFrameBorder.qml")
        self.assertIn('readonly property string mappingMode: !effectsEnabled ? "none" : (foregroundOverlay ? "overlay" : "bottom")', host)
        self.assertIn('visible: root.mappingMode === "bottom"', host)
        self.assertIn('visible: root.mappingMode === "overlay"', host)
        self.assertEqual(host.count("mask: Region {}"), 2)
        self.assertIn('WlrLayershell.namespace: "lacuna-ambience-host-bottom"', host)
        self.assertIn('WlrLayershell.namespace: "lacuna-ambience-host-overlay"', host)
        self.assertIn("readonly property bool hostReady: true", host)
        self.assertIn('paintEnabled: root.mappingMode === "bottom"', host)
        self.assertIn('paintEnabled: root.mappingMode === "overlay"', host)
        self.assertIn("ForegroundFrameBorder {", host)
        self.assertIn("z: 10000", host)
        self.assertIn("foregroundFrameSource(outputName)", host)
        self.assertIn("readonly property var source: bridge && bridge.borderSource", foreground_border)
        self.assertIn("strokeColor: root.source ? root.source.borderColor", foreground_border)
        self.assertIn("function normalizeActiveEffects(source)", stack)
        self.assertIn("function zForEffect(effectId)", stack)
        self.assertIn("z: root.zForEffect(\"auroraDrift\")", stack)
        self.assertIn("z: root.zForEffect(\"trackingLines\")", stack)
        self.assertIn("trackingBands: 4", stack)
        self.assertIn("targetScreen: root.targetScreen", stack)
        dust = read("lacuna.ambience-host/effects/DustMotesEffect.qml")
        self.assertIn("readonly property real cursorLocalX", dust)
        self.assertIn("readonly property real cursorLocalY", dust)
        self.assertNotIn("PanelWindow", stack)
        self.assertNotIn("WlrLayershell.layer", stack)
        for plugin_id in [
            "lacuna.aurora-drift",
            "lacuna.cinematic-light-overlay",
            "lacuna.crt-overlay",
            "lacuna.dust-motes-overlay",
            "lacuna.film-grain-overlay",
            "lacuna.god-rays-overlay",
            "lacuna.rainfall-overlay",
            "lacuna.vhs-overlay",
        ]:
            fallback = read(f"{plugin_id}/Overlay.qml")
            self.assertIn("readonly property bool hostedByAmbienceHost: ambienceHostEnabled()", fallback, plugin_id)
            self.assertIn('loaders["lacuna.ambience-host"]', fallback, plugin_id)
            self.assertIn("loader.item.hostReady === true", fallback, plugin_id)
            self.assertIn("effectVisible: !hostedByAmbienceHost &&", fallback, plugin_id)
            self.assertIn("suppressed: root.hostedByAmbienceHost", fallback, plugin_id)

    def test_frame_shadow_mode_contract(self):
        # The complete frame/shadow mode spec in one place. If any assertion
        # here fails, one of these behaviors regressed:
        #   frame ON:  paint = rails/molding only (never under the bar, never
        #              over the sidebar); shadow = one contiguous ring around
        #              the content area cast from every chrome edge.
        #   frame OFF: no paint; the bar still casts its shadow, flush at the
        #              bar's inner edge, without needing the menu open.
        #   both:      shadow never draws over the bar; toggling the mode
        #              changes paint only, never window mapping.
        frame = read("lacuna.bar/LacunaFrameWindow.qml")
        bar = read("lacuna.bar/Bar.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")

        # Paint is gated on frame mode and fullscreen suppression. The shadow
        # survives frame OFF but never survives fullscreen suppression.
        self.assertIn("readonly property bool isRenderable: !suppressed", frame)
        self.assertIn("readonly property bool shadowFrameRenderable: !suppressed", frame)
        self.assertIn("shadowEnabled: !root.suppressed && root.shadowEnabled && root.width > 0 && root.height > 0", frame)
        self.assertNotIn("shadowEnabled: root.active && root.shadowEnabled", frame)
        self.assertIn("active: geometryRecord && geometryRecord.framed === true", bar)
        self.assertIn("shadowEnabled: root.frameShadow", bar)
        self.assertNotIn("shadowEnabled: root.frameEnabled && root.frameShadow", bar)

        # The shadow is cast by the hidden caster, never by the painted
        # shape. Its Shape source consumes the effective frame transaction so
        # fill, border, and shadow share one radius throughout live changes;
        # the caster hole still collapses to the bar edge when the frame is off.
        self.assertIn("source: frameShadowCaster", frame)
        self.assertNotIn("source: frameSource", frame)
        self.assertIn("layer.enabled: true", frame)
        self.assertIn("shadowOnly: true", frame)
        self.assertIn("maskEnabled: root.shadowOnly", read("lacuna.menu/components/LacunaDropShadow.qml"))
        self.assertIn("maskInverted: root.shadowOnly", read("lacuna.menu/components/LacunaDropShadow.qml"))
        self.assertIn("property var shadowGeometryRecord: null", frame)
        self.assertIn("shadowGeometryRecord: root.lacunaFrameGeometryRecord(modelData)", bar)
        self.assertIn("shadowHoleLeftOverride >= 0 ? shadowHoleLeftOverride : shadowRecordHoleX", frame)
        self.assertIn('readonly property real casterHoleY: shadowFrameRenderable ? shadowRecordHoleY : (shadowBarPosition === "top" || shadowTopEdgeOccupied ? shadowBarSize : 0)', frame)
        self.assertIn("shadowHoleRightOverride >= 0 ? shadowHoleRightOverride : shadowRecordHoleRight", frame)
        self.assertIn('readonly property real casterHoleBottom: shadowFrameRenderable ? shadowRecordHoleBottom : (shadowBarPosition === "bottom" || shadowBottomEdgeOccupied ? Math.max(casterHoleY + 1, height - shadowBarSize) : height)', frame)
        self.assertIn("readonly property real casterHoleRadius: shadowFrameRenderable", frame)

        # The rendered shadow is clipped to the content side of the chrome,
        # and neither paint nor shadow may cover the bar strip.
        self.assertIn("id: shadowClip", frame)
        self.assertIn("x: root.shadowPaintLeft", frame)
        self.assertIn("width: Math.max(0, root.shadowPaintRight - root.shadowPaintLeft)", frame)
        self.assertIn("id: framePaintClip", frame)
        self.assertIn("x: root.paintLeft", frame)
        self.assertIn("y: root.outerY", frame)
        self.assertIn("width: Math.max(0, root.paintRight - root.paintLeft)", frame)
        self.assertIn("paintOcclusionLeft:", bar)
        self.assertIn("shadowOcclusionLeft:", bar)
        self.assertIn("sidebarMoldingOcclusion", bar)
        self.assertIn("shadowEnabled: root.frameShadow", bar)
        self.assertNotIn("shadowEnabled: root.frameShadow && frameWindow.sidebarPaintOcclusion", bar)
        self.assertIn("shadowHoleLeftOverride:", bar)
        self.assertIn("? frameWindow.sidebarPaintOcclusion : -1", bar)
        self.assertIn("shadowHoleRightOverride:", bar)
        self.assertIn("? frameWindow.width - frameWindow.sidebarPaintOcclusion : -1", bar)
        self.assertIn("hostedMenu.sidebarPaintOcclusionWidthFor(modelData)", bar)
        self.assertIn("height: Math.max(0, root.outerBottom - root.outerY)", frame)
        self.assertIn("clip: true", frame)

        # The menu window's gradient strip is a standalone-menu fallback
        # only; in bar-hosted mode the frame window owns the bar shadow.
        self.assertIn(
            'readonly property bool topBarPanelShadowVisible: lacunaEnabled && !barOwnsLacunaFrame && frameShadow && frameMode === "off" && root.topBar',
            window,
        )

    def test_real_fullscreen_suppresses_all_lacuna_top_and_overlay_paint(self):
        canonical_guard = read("shared/qml/FullscreenGuard.qml")
        guard_copies = sorted(ROOT.glob("lacuna.*/FullscreenGuard.qml"))
        self.assertEqual(13, len(guard_copies))
        for path in guard_copies:
            self.assertEqual(canonical_guard, path.read_text(encoding="utf-8"), path)
        self.assertIn("function activeOnScreen(screen)", canonical_guard)
        self.assertIn('name === "fullscreen"', canonical_guard)
        self.assertIn("Hyprland.refreshWorkspaces", canonical_guard)

        bar = read("lacuna.bar/Bar.qml")
        adapter = read("lacuna.bar/OmarchyBarAdapter.qml")
        omarchy_bar = read("lacuna.bar/OmarchyBar.qml")
        frame = read("lacuna.bar/LacunaFrameWindow.qml")
        menu = read("lacuna.menu/menu/MenuWindow.qml")
        rail = read("lacuna.menu/menu/MenuRail.qml")
        tray = read("lacuna.tray/Widget.qml")
        self.assertIn("function fullscreenWorkspaceOnScreen(screen)", bar)
        self.assertIn("suppressed: root.fullscreenWorkspaceOnScreen(modelData)", bar)
        self.assertIn("!root.fullscreenWorkspaceOnScreen(frameReserveScreen.screenData)", bar)
        self.assertIn("fullscreenSuppressionProvider: function(screen)", bar)
        self.assertIn("property var fullscreenSuppressionProvider: null", adapter)
        self.assertIn("fullscreenSuppressionProvider: root.fullscreenSuppressionProvider", adapter)
        self.assertIn("property var fullscreenSuppressionProvider: null", omarchy_bar)
        self.assertIn("readonly property bool fullscreenSuppressed: root.fullscreenSuppressedFor(screen)", omarchy_bar)
        self.assertIn("readonly property bool surfaceActive: configuredSurfaceActive && !fullscreenSuppressed", omarchy_bar)
        self.assertIn("onFullscreenSuppressedChanged: if (fullscreenSuppressed) root.dismissTransientUiForScreen(screen)", omarchy_bar)
        self.assertIn("active: configControl.surfaceContext && !configControl.surfaceContext.fullscreenSuppressed", omarchy_bar)
        self.assertEqual(3, omarchy_bar.count("active: !slot.surfaceContext.fullscreenSuppressed"))
        self.assertNotIn("for (var i = 0; i < root.configControls.length; i++)", omarchy_bar)
        self.assertIn("property bool suppressed: false", frame)
        self.assertIn("readonly property bool isRenderable: !suppressed", frame)
        border = read("lacuna.bar/LacunaFrameBorderWindow.qml")
        self.assertIn("property bool suppressed: false", border)
        self.assertIn("readonly property bool isRenderable: active && !suppressed", border)
        self.assertIn("suppressed: root.suppressed", frame)
        self.assertIn("readonly property bool shadowFrameRenderable: !suppressed", frame)
        self.assertIn("shadowEnabled: !root.suppressed && root.shadowEnabled", frame)
        self.assertIn("readonly property bool fullscreenSuppressed: root.fullscreenWorkspaceOnScreen(modelData)", menu)
        self.assertIn("function flyoutTargetsScreen(screen)", menu)
        self.assertIn("if (fullscreenSuppressed && root.flyoutTargetsScreen(modelData))", menu)
        self.assertEqual(6, menu.count("active: !root.fullscreenWorkspaceOnScreen(modelData)"))
        self.assertIn("borderEnabled: root.lacunaEnabled && !menuWindow.fullscreenSuppressed", menu)
        self.assertIn("topBarShadowEnabled: root.topBarPanelShadowVisible && !menuWindow.fullscreenSuppressed", menu)
        self.assertIn("fullscreenSuppressed: menuWindow.fullscreenSuppressed", menu)
        self.assertIn("visible: !root.fullscreenSuppressed && root.tooltipVisible", rail)
        self.assertIn("readonly property bool fullscreenSuppressed: bar && bar.fullscreenSuppressed === true", tray)
        self.assertIn("onFullscreenSuppressedChanged: if (fullscreenSuppressed) close()", tray)
        self.assertEqual(2, tray.count("active: !root.fullscreenSuppressed"))

        host = read("lacuna.ambience-host/Overlay.qml")
        self.assertIn("readonly property bool fullscreenSuppressed: fullscreenGuard.activeOnScreen(modelData)", host)
        self.assertIn('paintEnabled: root.mappingMode === "overlay" && !overlayWindow.fullscreenSuppressed', host)
        foreground_overlays = [
            "lacuna.aurora-drift/Overlay.qml",
            "lacuna.cinematic-light-overlay/Overlay.qml",
            "lacuna.crt-overlay/Overlay.qml",
            "lacuna.dust-motes-overlay/Overlay.qml",
            "lacuna.film-grain-overlay/Overlay.qml",
            "lacuna.god-rays-overlay/Overlay.qml",
            "lacuna.rainfall-overlay/Overlay.qml",
            "lacuna.vhs-overlay/Overlay.qml",
        ]
        for path in foreground_overlays:
            qml = read(path)
            self.assertIn("readonly property bool fullscreenSuppressed: root.foregroundOverlay", qml, path)
            self.assertIn("fullscreenGuard.activeOnScreen(modelData)", qml, path)
            self.assertRegex(qml, r"visible: !\w+Window\.fullscreenSuppressed")

        flyouts = sorted(ROOT.glob("lacuna.*/*Flyout.qml"))
        guarded_flyouts = [path for path in flyouts if "bar.fullscreenSuppressed === true" in path.read_text(encoding="utf-8")]
        self.assertEqual(13, len(guarded_flyouts))

        for path in [
            "lacuna.audio/Panel.qml",
            "lacuna.bluetooth/Panel.qml",
            "lacuna.network/Panel.qml",
            "lacuna.power/Panel.qml",
        ]:
            qml = read(path)
            self.assertIn("if (fullscreenGuard.activeOnScreen(window.screen)) return", qml, path)
            self.assertIn("onFullscreenSuppressedChanged: if (fullscreenSuppressed && visible) root.close()", qml, path)

    def test_layer_stacking_policy(self):
        # Within a Wayland layer, stacking is map order only, so every
        # surface's layer assignment is architecture, not styling. This table
        # is the policy (see docs/architecture/layer-stacking.md); changing a
        # layer or adding a surface must update both deliberately.
        policy = {
            "lacuna.ambience-host/Overlay.qml": ["WlrLayer.Bottom", "WlrLayer.Overlay"],
            "lacuna.audio/Panel.qml": ["WlrLayer.Overlay"],
            "lacuna.aurora-drift/Overlay.qml": ["root.foregroundOverlay ? WlrLayer.Overlay : WlrLayer.Bottom"],
            "lacuna.background-vignette/Overlay.qml": ["root.ignoreBackgroundAnimationLayer ? WlrLayer.Background : WlrLayer.Bottom"],
            "lacuna.bar/LacunaFrameWindow.qml": ["WlrLayer.Top"],
            "lacuna.bar/OmarchyBar.qml": ["WlrLayer.Top", "WlrLayer.Overlay"],
            "lacuna.bluetooth/Panel.qml": ["WlrLayer.Overlay"],
            "lacuna.cinematic-light-overlay/Overlay.qml": ["root.foregroundOverlay ? WlrLayer.Overlay : WlrLayer.Bottom"],
            "lacuna.crt-overlay/Overlay.qml": ["root.foregroundOverlay ? WlrLayer.Overlay : WlrLayer.Bottom"],
            "lacuna.desktop-clock/Clock.qml": ["WlrLayer.Bottom"],
            "lacuna.dust-motes-overlay/Overlay.qml": ["root.foregroundOverlay ? WlrLayer.Overlay : WlrLayer.Bottom"],
            "lacuna.film-grain-overlay/Overlay.qml": ["root.foregroundOverlay ? WlrLayer.Overlay : WlrLayer.Bottom"],
            "lacuna.god-rays-overlay/Overlay.qml": ["root.foregroundOverlay ? WlrLayer.Overlay : WlrLayer.Bottom"],
            "lacuna.menu/menu/LacunaFrameReserveWindow.qml": ["WlrLayer.Top"],
            "lacuna.menu/menu/LacunaPanelWindow.qml": ["WlrLayer.Overlay"],
            "lacuna.network/Panel.qml": ["WlrLayer.Overlay"],
            "lacuna.power/Panel.qml": ["WlrLayer.Overlay"],
            "lacuna.rainfall-overlay/Overlay.qml": ["root.foregroundOverlay ? WlrLayer.Overlay : WlrLayer.Bottom"],
            "lacuna.vhs-overlay/Overlay.qml": ["root.foregroundOverlay ? WlrLayer.Overlay : WlrLayer.Bottom"],
            "lacuna.media-player-video/Overlay.qml": ["WlrLayer.Background"],
        }

        found = {}
        for path in sorted(ROOT.glob("lacuna.*/**/*.qml")):
            text = path.read_text(encoding="utf-8")
            layers = [match.strip() for match in re.findall(r"WlrLayershell\.layer:\s*([^\n]+)", text)]
            if layers:
                found[path.relative_to(ROOT).as_posix()] = layers
        self.assertEqual(policy, found)

        # The frame stays mapped for its shadow. Inactive ambience/video
        # surfaces unmap, while the frame border is composed inside the frame.
        frame = read("lacuna.bar/LacunaFrameWindow.qml")
        border_item = read("lacuna.bar/LacunaFrameBorderWindow.qml")
        ambience_host = read("lacuna.ambience-host/Overlay.qml")
        video = read("lacuna.media-player-video/Overlay.qml")
        self.assertIn("visible: true", frame)
        self.assertIn("readonly property bool isRenderable: !suppressed", frame)
        self.assertIn("property bool suppressed: false", frame)
        self.assertNotIn("WlrLayershell.", border_item)
        self.assertIn('visible: root.mappingMode === "bottom"', ambience_host)
        self.assertIn('visible: root.mappingMode === "overlay"', ambience_host)
        self.assertEqual(ambience_host.count("mask: Region {}"), 2)
        self.assertIn("loadedEffectCount: root.loadedEffectCount()", ambience_host)
        self.assertIn("visible: true", video)

        # Startup mapping order inside the bar host: frame paint below the
        # bar, bar below the hosted menu/sidebar.
        bar = read("lacuna.bar/Bar.qml")
        self.assertLess(bar.index("LacunaFrameWindow {"), bar.index("OmarchyBarAdapter {"))
        self.assertLess(bar.index("OmarchyBarAdapter {"), bar.index("MenuWindow {"))
        # Frame reserve exclusive zones must never arrange before the bar at
        # shell start (they would inset the bar by frameThickness, leaving a
        # background gap at the bar's outer corner): reserves are gated on a
        # startup settle window.
        self.assertIn("property bool frameReservesReady: false", bar)
        self.assertIn("&& root.frameReservesReady", bar)
        self.assertIn("id: frameReserveSettleTimer", bar)

        omarchy_bar = read("lacuna.bar/OmarchyBar.qml")
        self.assertIn('"lacuna-bar-portrait-companion"', omarchy_bar)
        self.assertIn("readonly property var portraitCompanionScreens", omarchy_bar)
        self.assertIn("model: root.portraitCompanionScreens", omarchy_bar)
        self.assertIn('visible: band === "companion" ? true : !root.barHidden', omarchy_bar)
        self.assertIn("WlrLayershell.exclusionMode: barWindow.surfaceActive ? ExclusionMode.Auto : ExclusionMode.Ignore", omarchy_bar)
        self.assertNotIn("exclusiveZone:", omarchy_bar)
        self.assertIn("width: barWindow.surfaceActive ? barWindow.width : 0", omarchy_bar)
        self.assertIn("dragEnabled: false", omarchy_bar)
        self.assertIn("slot.band !== sourceSlot.band", omarchy_bar)
        self.assertIn("!slot.dragEnabled", omarchy_bar)
        self.assertIn('if ("bar" in target) target.bar = surfaceContext', omarchy_bar)
        for forwarded in ["barSize", "foreground", "background", "accent", "urgent", "frameBorderEnabled", "frameBorderColor", "fontFamily", "shell", "activePopout"]:
            self.assertIn(f"readonly property", omarchy_bar)
            self.assertIn(forwarded, omarchy_bar)
        self.assertIn("function activateInteractionFor(surfacePosition, anchorItem, moduleId, owningScreen)", omarchy_bar)
        self.assertIn("function requestPopoutFor(surfacePosition, owner, anchorItem, moduleId, owningScreen)", omarchy_bar)
        self.assertIn("root.popupContextFor(position, anchorItem, moduleId, owningScreen)", omarchy_bar)
        self.assertIn("function registerClickTarget(target) { root.registerClickTarget(target) }", omarchy_bar)
        self.assertIn("function unregisterClickTarget(target) { root.unregisterClickTarget(target) }", omarchy_bar)
        self.assertIn("Util.execDetached(command)", omarchy_bar)
        self.assertNotIn("Util.hyprExecCommand", omarchy_bar)

    def test_media_player_video_waits_for_high_res_background_stream(self):
        overlay = read("lacuna.media-player-video/Overlay.qml")
        bar = read("lacuna.bar/Bar.qml")

        self.assertIn("readonly property string highResVideoSource", overlay)
        self.assertIn("readonly property bool waitingForHighRes", overlay)
        self.assertIn("readonly property int backgroundRequestRevision", overlay)
        self.assertIn("readonly property bool backgroundResolveFailed", overlay)
        self.assertIn("property bool fadeCoverVisible: false", overlay)
        self.assertIn("property real fadeCoverOpacity: 0", overlay)
        self.assertIn("property double fadeCoverStartedAt: 0", overlay)
        self.assertIn("property double activeSourceAssignedAt: 0", overlay)
        self.assertIn("property int fadeRevealDelay: 0", overlay)
        self.assertIn("property bool fadeCoverRising: false", overlay)
        self.assertIn("property int fadeCoverDuration: fadeInDuration", overlay)
        self.assertIn("property bool exitTransitionActive: false", overlay)
        self.assertIn("property bool clearingWallpaperAfterExit: false", overlay)
        self.assertIn("property int wallpaperFadeGateDelay: 0", overlay)
        self.assertIn("property bool waitingForPlayerReady: false", overlay)
        self.assertIn("property bool wallpaperPositionRefreshPending: false", overlay)
        self.assertIn('property string wallpaperPositionRefreshKey: ""', overlay)
        self.assertIn("readonly property int outputRegistrationTimeoutDuration: 5000", overlay)
        self.assertIn("readonly property bool wallpaperLayerVisible", overlay)
        self.assertIn("readonly property int normalFadeCoverRiseDuration: 300", overlay)
        self.assertIn("readonly property int normalSourceHoldDuration: 150", overlay)
        self.assertIn("readonly property int normalFadeInDuration: 750", overlay)
        self.assertIn("readonly property int normalExitFadeToBlackDuration: 350", overlay)
        self.assertIn("readonly property int normalExitFadeFromBlackDuration: 600", overlay)
        self.assertIn("readonly property int reducedMotionDuration: 75", overlay)
        self.assertIn("property var activeHandoffToken: null", overlay)
        self.assertIn("readonly property int adaptiveReadinessTimeoutDuration: 4000", overlay)
        self.assertIn("readonly property int exitFadeToBlackDuration", overlay)
        self.assertIn("readonly property int exitFadeFromBlackDuration", overlay)
        self.assertIn("import QtMultimedia", overlay)
        self.assertIn("function resolveFrameRect(screen)", overlay)
        self.assertIn("function resolveFrameGeometryRevision()", overlay)
        self.assertIn("root.shell.bar.lacunaFrameGeometryRevision", overlay)
        self.assertIn("root.resolveFrameGeometryRevision()", overlay)
        self.assertIn("root.shell.bar.lacunaFrameContentRect(screen)", overlay)
        self.assertIn("MediaPlayer", overlay)
        self.assertIn("VideoOutput", overlay)
        self.assertIn("AudioOutput", overlay)
        self.assertIn("muted: true", overlay)
        self.assertIn("fillMode: VideoOutput.PreserveAspectCrop", overlay)
        self.assertIn("active: videoWindow.renderable", overlay)
        self.assertIn("sourceComponent: videoContentComponent", overlay)
        self.assertIn("source: root.activeSource", overlay)
        self.assertIn('WlrLayershell.namespace: "lacuna-media-player-video"', overlay)
        # The fade cover must live inside the video window (deterministic
        # sibling z-order), never as a second layer-shell surface whose
        # stacking against the video window is map-order dependent.
        self.assertNotIn("lacuna-media-player-video-fade", overlay)
        self.assertIn("id: fadeCover", overlay)
        self.assertIn("z: 10", overlay)
        self.assertIn("WlrLayershell.layer: WlrLayer.Background", overlay)
        self.assertNotIn("WlrLayershell.layer: WlrLayer.Bottom", overlay)
        self.assertIn("x: Math.round(videoWindow.frameRect.x)", overlay)
        self.assertIn("width: Math.round(videoWindow.frameRect.width)", overlay)
        self.assertIn("radius: Math.max(0, Number(videoWindow.frameRect.radius || 0))", overlay)
        self.assertIn("onWaitingForHighResChanged: syncWallpaper()", overlay)
        self.assertIn("onBackgroundRequestRevisionChanged", overlay)
        self.assertIn("onBackgroundResolveFailedChanged", overlay)
        self.assertIn("fadeCoverStartedAt = Date.now()", overlay)
        self.assertIn("fadeCoverRising = true", overlay)
        self.assertIn("function notePlayerReady()", overlay)
        self.assertIn("function notePlayerError(reason)", overlay)
        self.assertIn("function giveUpWallpaper(reason)", overlay)
        self.assertIn("function beginWallpaperExit()", overlay)
        self.assertIn("function clearWallpaperNow()", overlay)
        self.assertIn("exitClearTimer.restart()", overlay)
        self.assertIn("id: exitClearTimer", overlay)
        self.assertIn("var sourceAssignmentNeeded = activeSource !== videoSource", overlay)
        self.assertIn("activeRevisionKey !== sourceRevisionKey || presentationRefreshNeeded", overlay)
        self.assertIn("wallpaperFadeGateDelay = fadeCoverDuration", overlay)
        self.assertIn("function fadeCoverRiseRemaining()", overlay)
        self.assertIn("var remainingFadeCoverRise = fadeCoverRiseRemaining()", overlay)
        self.assertIn("wallpaperFadeGateTimer.restart()", overlay)
        self.assertIn("service.updatePlaybackPosition()", overlay)
        self.assertIn("service.refreshBackgroundStream()", overlay)
        self.assertIn("id: wallpaperPositionRefreshTimer", overlay)
        self.assertIn("id: outputRegistrationTimer", overlay)
        self.assertIn("root.handleOutputRegistrationTimeout()", overlay)
        self.assertIn("wallpaperPositionRefreshKey !== refreshKey", overlay)
        self.assertIn("root.wallpaperPositionRefreshKey = root.videoSource + \"#\" + root.backgroundRequestRevision", overlay)
        self.assertIn("fadeRevealDelay = Math.max(0, mediaReadyMinimumHoldMs - elapsed)", overlay)
        self.assertIn("active: videoWindow.renderable", overlay)
        self.assertIn("readonly property real localCoverOpacity: localPlayerReady ? root.fadeCoverOpacity : 1", overlay)
        self.assertIn("visible: true", overlay)
        self.assertIn("opacity: videoContent.localCoverOpacity", overlay)
        self.assertIn("interval: root.fadeRevealDelay", overlay)
        self.assertIn("id: wallpaperFadeGateTimer", overlay)
        self.assertIn("interval: 500", overlay)
        self.assertIn("releaseFadeCoverSoon()", overlay)
        self.assertIn("mediaStatus === MediaPlayer.BufferedMedia", overlay)
        self.assertIn("playbackState === MediaPlayer.PlayingState", overlay)
        self.assertIn("onErrorOccurred", overlay)
        self.assertIn("function syncVideoPosition(force)", overlay)
        # The interpolated service clock supports gentle correction below
        # 1.5s; hard seeks are rate-limited and validated before fallback.
        self.assertIn("if (absoluteDrift < 400)", overlay)
        self.assertIn("if (absoluteDrift <= 1500)", overlay)
        self.assertIn("player.playbackRate = drift > 0 ? 1.03 : 0.97", overlay)
        self.assertIn("var hardSeekAllowed = force || now - lastHardSeekAt >= hardSeekCooldownDuration", overlay)
        self.assertIn("if (!hardSeekAllowed) continue", overlay)
        self.assertIn("if (hardSeekFailureCount < 2) return", overlay)
        self.assertIn("player.play()", overlay)
        self.assertIn("player.pause()", overlay)
        self.assertIn("root.syncVideoPosition(true)", overlay)
        self.assertIn("if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)", overlay)
        self.assertIn('if (root.activeSource === "") player.stop()', overlay)
        self.assertIn("function handleResolveFailure()", overlay)
        self.assertIn("id: resolveRetryTimer", overlay)
        self.assertIn("resolveRetryAttempts: root.resolveRetryAttempts", overlay)
        # A repeat of the same track re-resolves to the same cached stream
        # URL, so the already-playing player emits no fresh ready event; the
        # overlay must self-release the cover and, if it ever gives up while
        # video is still desired, retry instead of stranding the static
        # background.
        self.assertIn("function anyPlayerReadyFor(source)", overlay)
        self.assertIn("if (anyPlayerReadyFor(activeSource)) notePlayerReady()", overlay)
        self.assertIn("id: wallpaperRecoveryTimer", overlay)
        self.assertIn("wallpaperRecoveryAttempts: root.wallpaperRecoveryAttempts", overlay)
        self.assertIn("duration: root.fadeCoverDuration", overlay)
        self.assertIn("fadeCoverDuration: root.fadeCoverDuration", overlay)
        self.assertIn("exitTransitionActive: root.exitTransitionActive", overlay)
        self.assertIn("backgroundResolveFailed: root.backgroundResolveFailed", overlay)
        self.assertIn("mediaRestartAttempts: root.mediaRestartAttempts", overlay)
        self.assertIn('backend: "qml-framed-video"', overlay)
        self.assertIn("function lacunaFrameContentRect(screen)", bar)
        self.assertIn("var bleed = framed ? Math.max(t + 2, Math.ceil(root.frameRadius * 0.5)) : 0", bar)
        self.assertIn("innerWidth: Math.max(1, record.holeRight - record.holeX)", bar)
        self.assertNotIn("mpvpaper", overlay)
        self.assertNotIn("input-ipc-server=", overlay)
        self.assertNotIn("adoptBackgroundPlayback", overlay)
        self.assertIn("readonly property string preferredVideoSource", overlay)
        self.assertIn('switchToProgressive("adaptive-readiness-timeout")', overlay)
        self.assertNotIn("previewVideoSource", overlay)
        self.assertNotIn("onPreviewStreamUrlChanged", overlay)
        self.assertNotIn("lastExitCode", overlay)
        self.assertNotIn("backgroundReadyProbeAttempts", overlay)
        self.assertNotIn("usingHighRes", overlay)

    def test_workspace_lacuna_selected_state_has_no_fill_or_underline(self):
        qml = read("lacuna.workspaces/components/LacunaWorkspaceButton.qml")

        self.assertNotIn("root.active ? 0.08", qml)
        self.assertNotIn("height: 2\n    color: root.accent\n    opacity: root.active", qml)
        self.assertIn('property string designStyle: "lacuna"', qml)
        self.assertIn("property int labelPixelSize: barSize <= 26 ? 12 : 13", qml)
        self.assertIn("property int labelFontWeight: Font.DemiBold", qml)
        self.assertIn("font.pixelSize: root.labelPixelSize", qml)
        self.assertIn("font.weight: root.labelFontWeight", qml)
        self.assertNotIn("font.pixelSize: root.omarchyStyle ? 14", qml)

    def test_first_party_bar_icons_share_one_size_scale(self):
        topbar_plugins = [
            "lacuna.audio",
            "lacuna.bar-size-pill",
            "lacuna.bluetooth",
            "lacuna.claude-usage",
            "lacuna.codex-usage",
            "lacuna.compact-pill",
            "lacuna.idle-inhibitor",
            "lacuna.indicators",
            "lacuna.menu-button",
            "lacuna.network",
            "lacuna.nightlight",
            "lacuna.notifications",
            "lacuna.power",
            "lacuna.reminders",
            "lacuna.screen-recording",
            "lacuna.system-stats",
            "lacuna.system-update",
            "lacuna.temperature",
            "lacuna.voxtype",
            "lacuna.weather",
        ]
        for plugin in topbar_plugins:
            qml = read(f"{plugin}/Widget.qml")
            self.assertIn("readonly property int topbarIconSize: barSize >= 30 ? 15 : 13", qml, plugin)
            self.assertNotIn("barSize >= 30 ? 16 : 14", qml, plugin)

        for plugin in ["lacuna.theme", "lacuna.wallpaper"]:
            self.assertIn("readonly property int iconSize: barSize >= 30 ? 15 : 13", read(f"{plugin}/Widget.qml"), plugin)

        self.assertIn("iconSize: root.barSize >= 30 ? 15 : 13", read("lacuna.mpris/Widget.qml"))
        tray = read("lacuna.tray/Widget.qml")
        self.assertIn("readonly property int topbarIconSize: root.barSize >= 30 ? 15 : 13", tray)
        self.assertIn("implicitSize: root.topbarIconSize", tray)
        self.assertIn("width: root.topbarIconSize", tray)
        self.assertIn("height: root.topbarIconSize", tray)
        idle = read("lacuna.idle-inhibitor/Widget.qml")
        indicators = read("lacuna.indicators/Widget.qml")
        for qml in [idle, indicators]:
            self.assertIn("readonly property int idleGlyphSize: topbarIconSize - 3", qml)
        self.assertIn("font.pixelSize: root.idleGlyphSize", idle)
        self.assertIn(
            'font.pixelSize: indicatorButton.indicatorId === "StayAwake" ? root.idleGlyphSize : root.topbarIconSize',
            indicators,
        )

    def test_lacuna_menu_button_uses_lacuna_icon_asset(self):
        qml = read("lacuna.menu-button/Widget.qml")

        self.assertIn("circle-dotted-letter-l.svg", qml)
        self.assertNotIn("layout-sidebar-left-expand-filled.svg", qml)

    def test_lacuna_menu_uses_unified_accent_except_danger(self):
        for path in [
            "lacuna.menu/menu/MenuContent.qml",
            "lacuna.menu/menu/MenuRail.qml",
            "lacuna.menu/settings/SettingsWindow.qml",
            "lacuna.menu/settings/OmarchyShellSettingsWindow.qml",
        ]:
            qml = read(path)
            tone_function = qml.split("function toneAccent", 1)[1].split("\n  }", 1)[0]

            self.assertIn('if (tone === "danger") return root.dangerAccent', tone_function, path)
            if path.endswith("OmarchyShellSettingsWindow.qml"):
                self.assertIn('if (tone === "shell") return root.shellAccent', tone_function, path)
                self.assertIn("return root.navAccent", tone_function, path)
            else:
                self.assertIn("return root.accent", tone_function, path)
                self.assertNotIn("return root.shellAccent", tone_function, path)
                self.assertNotIn("return root.sessionAccent", tone_function, path)
                self.assertNotIn("return root.navAccent", tone_function, path)

        docs = read("docs/lacuna-design-system/01-color.md")
        self.assertIn("One accent for everything non-destructive", docs)
        self.assertIn("reserved for destructive actions only", docs)
        self.assertIn('tone === "danger" ? danger : accent', docs)

    def test_design_token_consumers_use_lacuna_not_carbon_flag(self):
        paths = [
            "lacuna.menu/settings/SettingsRail.qml",
            "lacuna.menu/settings/SettingsRow.qml",
            "lacuna.menu/modules/LacunaMenuItem.qml",
            "lacuna.menu/menu/MenuContent.qml",
            "lacuna.menu/menu/FlyoutAppPickerContent.qml",
        ]

        for path in paths:
            qml = read(path)
            self.assertNotIn("designTokens.carbon", qml, path)

    def test_design_tokens_retire_carbon_lineage(self):
        # Phase A of the Lacuna design language: the design-system core no
        # longer names Carbon. The persisted-settings layer (LacunaSettings /
        # lacuna.state) still migrates a legacy "carbon" value to "lacuna";
        # that is covered separately and intentionally kept.
        for path in [
            "lacuna.menu/services/DesignTokens.qml",
            "lacuna.shell-settings/services/DesignTokens.qml",
        ]:
            qml = read(path)
            self.assertNotIn("carbon", qml, path)
            self.assertIn('if (styleName === "lacuna") return "lacuna"', qml, path)

        rail = read("lacuna.menu/menu/MenuRail.qml")
        self.assertNotIn('"carbon"', rail)
        self.assertIn('designStyle: "lacuna"', rail)

    def test_recess_interaction_vocabulary_named_and_wired(self):
        # Phase B of the Lacuna design language: the "recess" interaction-depth
        # family is named in the token registry and consumed by the state
        # layer, replacing inline alpha literals (pure indirection).
        tokens = read("lacuna.shell-settings/components/LacunaTokens.qml")
        for name in ("recessRest", "recessHover", "recessPress"):
            self.assertIn(name, tokens)

        layer = read("lacuna.shell-settings/components/LacunaStateLayer.qml")
        self.assertIn("property real hoverOpacity: tokens.recessHover", layer)
        self.assertIn("property real pressOpacity: tokens.recessPress", layer)
        self.assertIn("LacunaTokens { id: tokens }", layer)
        self.assertNotIn("property real hoverOpacity: 0.06", layer)

    def test_theme_exposes_design_language_color_roles(self):
        # Phase C: named, theme-derived color roles (01-color.md). Additive
        # aliases over the canonical derivations plus the exposed danger/warning
        # roles; no rendered-value change.
        theme = read("lacuna.menu/services/Theme.qml")
        self.assertIn("readonly property color field: background", theme)
        self.assertIn("readonly property color plate: panelBackground", theme)
        self.assertIn("readonly property color ink: foreground", theme)
        self.assertIn("readonly property color whisper: muted", theme)
        self.assertIn("readonly property color seam: border", theme)
        self.assertIn('readonly property color danger: color("color9")', theme)
        self.assertIn('readonly property color warning: color("color11")', theme)

        profile = read("shared/qml/simple-bar/ColorProfile.qml")
        self.assertIn("readonly property color ink: foreground", profile)

    def test_color_profiles_read_quattro_theme_state_and_named_hues(self):
        profile = read("shared/qml/simple-bar/ColorProfile.qml")
        workspaces = read("lacuna.workspaces/ColorProfile.qml")

        for qml in (profile, workspaces):
            self.assertIn('Quickshell.env("XDG_STATE_HOME")', qml)
            self.assertIn('stateHome + "/omarchy/current/theme/colors.toml"', qml)
            self.assertIn('stateHome + "/omarchy/current/theme.name"', qml)
            self.assertNotIn('configHome + "/omarchy/current/theme', qml)
            self.assertIn("if (!next.background && next.bg)", qml)
            self.assertIn("if (!next.foreground && next.fg)", qml)
            self.assertIn("import qs.Commons", qml)
            self.assertIn("target: Color", qml)
            self.assertIn("function onShellValuesChanged()", qml)
            self.assertIn("watchChanges: false", qml)
            self.assertIn("onLoadFailed: themeRetryTimer.restart()", qml)
            self.assertNotIn('onLoadFailed: root.loadTheme("")', qml)

        for role, hue in {
            "codex": "cyan",
            "claude": "magenta",
            "memory": "green",
            "cpu": "yellow",
            "temperature": "red",
            "recording": "red",
        }.items():
            self.assertIn(f'{role}: "{hue}"', profile)

        self.assertIn('profile === "colorful" ? roleColor(roleName || role, accent) : accent', profile)
        self.assertIn('occupied: "green"', workspaces)
        self.assertIn('urgent: "red"', workspaces)

    def test_theme_and_wallpaper_keep_text_ink_while_colorizing_icons(self):
        for plugin, role, hue in [
            ("lacuna.theme", "theme", "magenta"),
            ("lacuna.wallpaper", "wallpaper", "blue"),
        ]:
            widget = read(f"{plugin}/Widget.qml")
            profile = read(f"{plugin}/ColorProfile.qml")

            self.assertIn("readonly property color iconColor: moduleColor", widget)
            self.assertIn("readonly property color textColor: foreground", widget)
            self.assertIn("colorizationColor: root.iconColor", widget)
            self.assertIn("color: root.textColor", widget)
            self.assertIn('stateHome + "/omarchy/current/theme/colors.toml"', profile)
            self.assertIn(f'{role}: "{hue}"', profile)

        theme_widget = read("lacuna.theme/Widget.qml")
        self.assertIn("readonly property var palette: colorProfile.palette", theme_widget)
        self.assertIn("readonly property string themeName: colorProfile.themeName", theme_widget)
        self.assertNotIn("function loadTheme(raw)", theme_widget)
        self.assertNotIn("FileView {", theme_widget)

    def test_motion_uses_one_named_reveal_scale(self):
        # Phase D: a single named "reveal" scale (03-motion.md) replaces the
        # legacy + noctalia timing sets. animation* survive as same-value
        # aliases; the divergent legacy* scale is removed.
        for path in [
            "lacuna.menu/services/MotionTokens.qml",
            "lacuna.shell-settings/services/MotionTokens.qml",
        ]:
            qml = read(path)
            for name in ("instant", "quick", "color", "reveal", "settle",
                         "ambient", "pulse", "sweep"):
                self.assertIn("property int %s:" % name, qml, path)
            self.assertNotIn("legacyFast", qml, path)
            self.assertNotIn("legacyNormal", qml, path)
            self.assertNotIn("legacySlow", qml, path)
            self.assertNotIn("legacyDurationFor", qml, path)
            self.assertIn("readonly property int animationNormal: reveal", qml, path)
            self.assertIn("function duration(baseMs)", qml, path)
            self.assertIn("panelBezierCurve", qml, path)

        anim = read("lacuna.shell-settings/components/LacunaAnim.qml")
        self.assertIn('if (value === "fast") return motionTokens.quick', anim)
        self.assertIn('if (value === "slow") return motionTokens.settle', anim)

        widget = read("shared/qml/simple-bar/MotionTokens.qml")
        self.assertIn("readonly property int quick: duration(150)", widget)
        self.assertIn("property bool animationDisabled: false", widget)
        self.assertIn("readonly property int hoverDuration: quick", widget)

    def test_typography_adopts_hack_nerd_font_propo(self):
        # Phase E follow-up: shell chrome uses the proportional Nerd Font
        # variant; Tektur stays the display/title face. No JetBrains Mono
        # literals or quoted monospace fallbacks remain in QML.
        tokens = read("lacuna.shell-settings/components/LacunaTokens.qml")
        self.assertIn('readonly property string monoFont: "Hack Nerd Font Propo"', tokens)

        for path in [
            "lacuna.menu/menu/MenuWindow.qml",
            "lacuna.menu/menu/MenuContent.qml",
            "lacuna.shell-settings/settings/SettingsRow.qml",
        ]:
            qml = read(path)
            self.assertNotIn("JetBrains Mono", qml, path)
            self.assertNotIn('"Hack Nerd Font"', qml, path)
            self.assertIn('"Hack Nerd Font Propo"', qml, path)

        for qml_path in ROOT.glob("lacuna.*/**/*.qml"):
            rel = qml_path.relative_to(ROOT).as_posix()
            if rel == "lacuna.bar/OmarchyBar.qml":
                continue
            self.assertNotIn('"monospace"', qml_path.read_text(encoding="utf-8"), rel)

        # Tektur remains the title/display face.
        self.assertIn("Tektur", read("lacuna.menu/menu/MenuContent.qml"))

    def test_reduce_motion_setting_feeds_the_motion_hook(self):
        # Cleanup follow-up: the central reduced-motion hook
        # (MotionTokens.animationDisabled) is now bound to a real persisted
        # setting and shared into the structural animators.
        settings = read("lacuna.state/Service.qml")
        self.assertIn("reduceMotion: false", settings)
        self.assertIn("next.reduceMotion = value.reduceMotion === true", settings)

        window = read("lacuna.menu/menu/MenuWindow.qml")
        self.assertIn("reduceMotionEnabled", window)
        self.assertIn("animationDisabled: root.reduceMotionEnabled", window)
        # The shared instance reaches the panel + content animators.
        self.assertIn("motionTokens: sharedMotion", window)

    def test_visible_metaphor_treatments_are_wired(self):
        # Visible redesign: the identity is carried by seams + the gap (lacuna)
        # motif, gated to the lacuna style. (The darker "void well" was dropped:
        # tonal recess can't read on near-black themes.)
        for path in [
            "lacuna.menu/services/DesignTokens.qml",
            "lacuna.shell-settings/services/DesignTokens.qml",
        ]:
            tokens = read(path)
            self.assertIn("readonly property bool gappedDividers: lacuna", tokens)
            self.assertIn("readonly property int dividerGap:", tokens)
            self.assertNotIn("voidWells", tokens)

        content = read("lacuna.menu/menu/MenuContent.qml")
        self.assertIn("readonly property color seam:", content)
        self.assertIn("root.designTokens.dividerGap > 0", content)

        # The section seam (gapped) repeats the lacuna mark down the menu.
        self.assertIn("root.designTokens.dividerGap", read("lacuna.menu/menu/MenuSection.qml"))

        # The void well is gone.
        self.assertNotIn("contentWell", read("lacuna.menu/menu/MenuWindow.qml"))

    def test_daily_launch_system_editor_uses_omarchy_editor_launcher(self):
        qml = read("lacuna.menu/menu/MenuAppModel.qml")

        self.assertIn('role === "editor") return root.commands.hyprExec("omarchy launch editor")', qml)
        old_editor_helper = "omarchy" + "-launch-editor"
        self.assertNotIn(f'role === "editor") return root.commands.hyprExec("{old_editor_helper}")', qml)

    def test_sidebar_autohide_reuses_overlay_surface_and_has_single_policy_owner(self):
        controller = read("lacuna.menu/services/SidebarAutohideController.qml")
        panel_window = read("lacuna.menu/menu/LacunaPanelWindow.qml")
        menu_window = read("lacuna.menu/menu/MenuWindow.qml")
        bar = read("lacuna.bar/Bar.qml")
        frame = read("lacuna.bar/LacunaFrameWindow.qml")

        self.assertIn('property string phase: enabled ? "concealed" : "disabled"', controller)
        self.assertIn("signal revealRequested(string screenName, string reason)", controller)
        self.assertIn("signal concealRequested(string reason)", controller)
        self.assertIn("property string rearmBlockedScreenName", controller)
        self.assertIn("property int intentRevision", controller)
        self.assertIn("property bool hotZoneEnabled: false", panel_window)
        self.assertIn("width: Math.round(root.hotZoneEnabled ? Math.max(0, root.hotZoneWidth) : 0)", panel_window)
        self.assertIn("signal hotZoneEntered()", panel_window)
        self.assertEqual(1, panel_window.count("WlrLayershell.layer:"))
        self.assertIn("WlrLayershell.layer: WlrLayer.Overlay", panel_window)
        self.assertIn("frame paint and\n  // shadow cannot cover an attached flyout", panel_window)
        self.assertIn("readonly property bool effectiveSidebarExclusive: sidebarState.exclusive && !sidebarAutoHideEnabled", menu_window)
        self.assertIn("hotZoneEnabled: root.sidebarAutoHideEnabled", menu_window)
        self.assertIn("SidebarAutohideController {", menu_window)
        self.assertIn('entry.action === "toggle-sidebar-autohide"', menu_window)
        self.assertNotIn("set-sidebar-autohide-reveal-", menu_window)
        self.assertNotIn("sidebarAutoHideRevealMode", menu_window)
        self.assertNotIn("sidebarState.setDisplay(sidebarAutoHide", menu_window)
        self.assertIn("&& (effectiveSidebarExclusive || sidebarAutoHideEnabled) ? root.barHeight : 0", menu_window)
        self.assertIn("property int barBottomY: root.topBar && visualTopInset === 0 ? barHeight : 0", menu_window)
        self.assertIn("hotZoneY: root.barBottomY", menu_window)
        self.assertIn("root.bottomBar && root.visualBottomInset === 0 ? root.barHeight : 0", menu_window)
        self.assertIn("borderGeometryRecord: root.sidebarAutoHideEnabled ? null", menu_window)
        self.assertIn("Math.max(0, root.panelWidth + Math.min(0, panelHost.surfaceX))", menu_window)
        self.assertIn('publishForegroundFrameSource(\n          menuWindow.outputName, "menu", foregroundFrameBridge)', menu_window)
        self.assertIn('publishForegroundFrameSource(outputName, "bar", foregroundFrameBridge)', bar)
        self.assertIn("readonly property alias foregroundBorderSource: frameBorderPaint", frame)
        self.assertIn("shadowEnabled: root.frameShadow", bar)
        self.assertIn("property real shadowHoleLeftOverride: -1", frame)
        self.assertIn("property real shadowHoleRightOverride: -1", frame)
        self.assertIn("shadowHoleLeftOverride >= 0 ? shadowHoleLeftOverride", frame)
        self.assertIn("shadowHoleRightOverride >= 0 ? shadowHoleRightOverride", frame)
        self.assertIn("shadowHoleLeftOverride:", bar)
        self.assertIn("shadowHoleRightOverride:", bar)
        self.assertNotIn("LacunaCombinedShellShadow", menu_window)
        self.assertNotIn("LacunaSidebarShadow", menu_window)
        foreground_border = read("lacuna.ambience-host/ForegroundFrameBorder.qml")
        self.assertNotIn("shadowEnabled: true", foreground_border)
        self.assertIn("if (hostedMenu.sidebarAutoHideEnabled === true) return false", bar)

    def test_sidebar_default_mode_is_separate_from_runtime_toggle(self):
        settings = read("lacuna.menu/services/LacunaSettings.qml")
        sidebar = read("lacuna.menu/services/SidebarState.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")

        self.assertIn('defaultMode: "off"', settings)
        self.assertIn("function setDefaultMode", sidebar)
        # The persisted preference and the session toggle are named distinctly,
        # and save() persists the real runtime collapse rather than a value
        # re-derived from defaultMode.
        self.assertIn("readonly property string desiredDefaultMode: defaultMode", sidebar)
        self.assertIn("readonly property bool runtimeCollapsed: collapsed", sidebar)
        self.assertIn('collapsed = defaultMode === "rail"', sidebar)
        self.assertIn("next.sidebar.collapsed = collapsed", sidebar)
        self.assertNotIn("autoHidePriorCollapsed", sidebar)
        self.assertNotIn("autoHideSessionInitialized", sidebar)
        self.assertIn("settingsService.save(next, false, true)", sidebar)
        self.assertNotIn('collapsed: defaultMode === "rail"', sidebar)
        self.assertIn("settingsService.hasLoaded !== false", sidebar)
        self.assertIn("function sidebarDefaultMode", window)
        self.assertIn("function sidebarDefaultKeepsMenuOpen", window)
        self.assertIn("function sidebarSettingsLoaded", window)
        self.assertIn("return lacunaSettings && lacunaSettings.hasLoaded === true", window)
        self.assertIn("function applyInitialSidebarDefaultNow", window)
        self.assertIn("initialSidebarDefaultRetry.restart()", window)
        self.assertIn("if (!sidebarSettingsLoaded())", window)
        self.assertIn("if (!lacunaEnabled) return false", window)
        self.assertIn("if (!sidebarSettingsLoaded()) return false", window)
        self.assertIn("lacunaSettings.data.sidebar", window)
        self.assertIn("var mode = sidebarDefaultMode()", window)
        self.assertIn("sidebarDefaultMode: root.sidebarDefaultMode()", window)
        self.assertNotIn("sidebarDefaultMode: sidebarState.defaultMode", window)
        self.assertIn("if (!root.sidebarSettingsLoaded())", window)
        self.assertIn("if (root.sidebarDefaultKeepsMenuOpen())", window)
        self.assertIn("root.applySidebarDefaultState()", window)
        self.assertLess(
            window.index("if (root.sidebarDefaultKeepsMenuOpen())"),
            window.index("if (root.hostManaged) return"),
        )
        self.assertIn('entry.action.indexOf("set-sidebar-default-")', window)
        self.assertIn('"Sidebar Default"', settings_window)
        self.assertIn('"Autohide Sidebar"', settings_window)
        self.assertNotIn('"Autohide Reveal As"', settings_window)
        self.assertNotIn('"set-sidebar-display-"', settings_window)

    def test_lacuna_settings_persistence_service_restores_idle_state(self):
        manifest = read_json("lacuna.settings-persistence/manifest.json")
        qml = read("lacuna.settings-persistence/Service.qml")
        panel = read("lacuna.settings-persistence/Panel.qml")

        self.assertEqual("Lacuna Settings Persistence", manifest["name"])
        self.assertEqual(["service", "panel"], manifest["kinds"])
        self.assertEqual("Service.qml", manifest["entryPoints"]["service"])
        self.assertEqual("Panel.qml", manifest["entryPoints"]["panel"])
        self.assertIn("settings-persistence.json", qml)
        self.assertIn("manageIdle", qml)
        self.assertIn("manageNightlight", qml)
        self.assertIn("omarchy toggle idle status", qml)
        self.assertIn("omarchy toggle idle \" + (enabled ? \"allow-idle\" : \"stay-awake\")", qml)
        self.assertIn("omarchy toggle nightlight --status", qml)
        self.assertIn("hyprctl hyprsunset temperature", qml)
        self.assertIn('target: "lacuna-settings-persistence"', qml)
        self.assertIn("function enqueueStateSave(payload, revision)", qml)
        self.assertIn("function retryPersistence()", qml)
        self.assertIn("queuedSavePayload = payload", qml)
        self.assertIn("umask 077", qml)
        self.assertIn('stateDir + "/.settings-persistence.json.tmp.XXXXXX"', qml)
        self.assertNotIn("tmp=$(mktemp);", qml)
        self.assertIn("Retry Save", panel)
        self.assertIn("Idle Inhibit", panel)
        self.assertIn("Nightlight", panel)
        self.assertIn("setManagedToggles", panel)

    def test_review_regressions_are_guarded(self):
        network = read("lacuna.network/Service.qml")
        self.assertIn("return !!(row && row.known && !row.connected)", network)
        self.assertNotIn("row.known && isProtected(row.security) && !row.connected", network)

        wallpaper = read("lacuna.wallpaper/WallpaperFlyout.qml")
        self.assertIn("function localFileUrl(path)", wallpaper)
        self.assertIn('encodeURIComponent(value).replace(/%2F/gi, "/")', wallpaper)
        self.assertIn("source: root.localFileUrl(root.backgroundPath)", wallpaper)
        self.assertNotIn('source: root.backgroundPath ? "file://" + root.backgroundPath : ""', wallpaper)

        for path in [
            "lacuna.shell-settings/CommandRunner.qml",
            "lacuna.menu/services/CommandRunner.qml",
        ]:
            runner = read(path)
            self.assertIn("signal queueDrained()", runner, path)
            self.assertIn("if (!proc.running && root.queue.length === 0) root.queueDrained()", runner, path)

        for path in [
            "lacuna.shell-settings/Service.qml",
            "lacuna.menu/services/OmarchyShellSettingsService.qml",
        ]:
            service = read(path)
            self.assertIn("function onQueueDrained() {", service, path)
            self.assertIn("root.scheduleRefresh(domains)", service, path)
            self.assertIn("property string actionRefreshDomains", service, path)

    def test_shell_settings_service_uses_omarchy_4_toggle_contracts(self):
        for path in [
            "lacuna.shell-settings/Service.qml",
            "lacuna.menu/services/OmarchyShellSettingsService.qml",
        ]:
            qml = read(path)
            self.assertIn('omarchy toggle bar " + (want ? "on" : "off")', qml, path)
            self.assertIn('omarchy toggle idle " + (want ? "allow-idle" : "stay-awake")', qml, path)
            self.assertIn("omarchy-shell notifications isDnd", qml, path)
            self.assertIn("omarchy-shell notifications toggleDnd", qml, path)
            self.assertIn("omarchy-shell -q omarchy.indicators refresh", qml, path)
            self.assertIn("function setNightlight", qml, path)
            self.assertIn("hyprctl hyprsunset temperature", qml, path)
            self.assertNotIn("omarchy toggle idle\")", qml, path)
            self.assertNotIn("omarchy toggle notification silencing", qml, path)
            self.assertNotIn("omarchy toggle nightlight\")", qml, path)

    def test_standalone_shell_settings_window_is_bounded_and_always_dismissible(self):
        panel = read("lacuna.shell-settings/Panel.qml")

        self.assertIn("Window {", panel)
        self.assertNotIn("FloatingWindow {", panel)
        self.assertIn("width: 500", panel)
        self.assertIn("height: 620", panel)
        self.assertIn("minimumWidth: 430", panel)
        self.assertIn("minimumHeight: 460", panel)
        self.assertNotIn("Style.space(500)", panel)
        self.assertNotIn("Style.space(620)", panel)
        self.assertIn('sequence: "Escape"', panel)
        self.assertIn("context: Qt.WindowShortcut", panel)
        self.assertIn("onActivated: root.close()", panel)
        self.assertIn("function activateSettingsWindow()", panel)
        self.assertIn("window.requestActivate()", panel)
        self.assertIn("settingsPanel.forceActiveFocus()", panel)
        self.assertIn("if (visible) Qt.callLater(root.activateSettingsWindow)", panel)

    def test_menu_debug_commands_match_omarchy_4_routes(self):
        for path in [
            "lacuna.menu/menu/MenuCommandCatalog.qml",
            "lacuna.shell-settings/Panel.qml",
        ]:
            qml = read(path)
            self.assertIn("omarchy commands --check", qml, path)
            self.assertIn("omarchy-shell shell ping", qml, path)
            self.assertIn("omarchy toggle idle status", qml, path)
            self.assertIn("omarchy-shell idle debug", qml, path)
            self.assertNotIn("omarchy debug --print --no-sudo", qml, path)
            self.assertNotIn("omarchy debug idle", qml, path)

    def test_window_gaps_toggle_uses_theme_size_when_enabled(self):
        service = read("lacuna.shell-settings/Service.qml")
        state_script = read("lacuna.shell-settings/scripts/omarchy-shell-settings-state.py")
        settings_window = read("lacuna.shell-settings/settings/OmarchyShellSettingsWindow.qml")

        self.assertIn("rm -f \" + quote(stockFile) + \" \" + quote(oldLacunaFile) + \" \" + quote(lacunaFile)", service)
        self.assertIn("Disable Hyprland window gaps without changing theme borders", service)
        self.assertNotIn("border_size", service)
        self.assertIn("live_gaps_enabled = any(value and value > 0 for value in [gaps_in, gaps_out])", state_script)
        self.assertIn("Use the active theme's tiled-window gap size", settings_window)

    def test_universal_corner_control_owns_exact_window_rounding(self):
        service = read("lacuna.shell-settings/Service.qml")
        state_script = read("lacuna.shell-settings/scripts/omarchy-shell-settings-state.py")
        settings_window = read("lacuna.shell-settings/settings/OmarchyShellSettingsWindow.qml")
        menu_window = read("lacuna.menu/menu/MenuWindow.qml")

        self.assertIn('option("square", "Square"', service)
        self.assertIn('option("rounded", "Rounded"', service)
        self.assertIn('option("theme", "Theme"', service)
        self.assertIn("function setWindowRoundingMode(value)", service)
        self.assertIn("function setWindowRoundingRadius(value)", service)
        self.assertIn("Math.max(0, Math.min(32, parsed))", service)
        self.assertIn('if (mode === "theme")', service)
        self.assertIn('if [ -f " + quote(stockNoGapsFile)', service)
        self.assertIn('rm -f " + quote(file) + " " + quote(stockNoGapsFile)', service)
        self.assertIn("Preserve disabled gaps without overriding theme borders or corner rounding", service)
        self.assertIn('elif stock_no_gaps_flag:', state_script)
        self.assertIn('window_rounding_mode = "theme"', state_script)
        self.assertIn('"windowRoundingMode": window_rounding_mode', state_script)
        self.assertNotIn('selectRow("corners", "Window Corners"', settings_window)
        self.assertNotIn('"window-rounding-mode"', settings_window)
        self.assertNotIn('toggleRow("corners", "Rounded Windows"', settings_window)
        self.assertIn("function syncWindowCornerRadius(mode, radius)", menu_window)
        self.assertIn('shellSettingsService.setWindowRoundingMode("theme")', menu_window)
        self.assertIn("shellSettingsService.setWindowRoundingRadius(targetRadius)", menu_window)
        self.assertIn("if (hasLacunaOverride && Number(hypr.windowRoundingOverrideRadius) === targetRadius) return", menu_window)
        self.assertIn("if (hasLacunaOverride) shellSettingsService.setWindowRoundingMode(\"theme\")", menu_window)
        self.assertIn("cornerWindowSyncTimer.restart()", menu_window)

    def test_shell_settings_service_load_has_timeout_watchdog(self):
        # A hung state subprocess must not wedge the service. A watchdog
        # terminates it, a single resolver clears `loading` exactly once
        # (so process-exit and timeout can't double-count), the data is
        # marked stale, and a bounded retry is scheduled.
        for path in [
            "lacuna.shell-settings/Service.qml",
            "lacuna.menu/services/OmarchyShellSettingsService.qml",
        ]:
            qml = read(path)
            self.assertIn("function resolveLoad", qml, path)
            self.assertIn("function handleLoadTimeout", qml, path)
            self.assertIn("id: loadWatchdog", qml, path)
            self.assertIn("onTriggered: root.handleLoadTimeout()", qml, path)
            self.assertIn("loadWatchdog.restart()", qml, path)
            self.assertIn("if (loadProc.running) loadProc.running = false", qml, path)
            self.assertIn("property bool refreshPending: false", qml, path)
            self.assertIn("property bool loadTimedOut: false", qml, path)
            self.assertIn("id: terminationGrace", qml, path)
            self.assertIn('var currentDnd = root.toggleValue("notificationSilencing", null)', qml, path)
            self.assertIn("function mergeCollectedState(nextState)", qml, path)
            self.assertIn("nextState.toggles.notificationSilencing = currentDnd", qml, path)
            self.assertIn("property bool stale: false", qml, path)
            self.assertIn("loadFailureStreak <= maxAutoRetries", qml, path)
            self.assertIn("id: retryTimer", qml, path)

        menu = read("lacuna.menu/menu/MenuWindow.qml")
        self.assertNotIn('name === "focusedmon" || name.indexOf("monitor") >= 0', menu)

    def test_fake_frame_topbar_reserve_matches_rendered_caster_size(self):
        window = read("lacuna.menu/menu/MenuWindow.qml")
        overlay = read("lacuna.menu/menu/LacunaFrameOverlay.qml")
        reserve = read("lacuna.menu/menu/LacunaFrameReserveWindow.qml")

        self.assertIn("property int barEdgeCasterSize: frameThickness", window)
        self.assertIn("property int sidebarReserveExtra: 0", window)
        self.assertIn("readonly property bool externalLeftFrameReserveActive: frameMode === \"fullframe\" && !root.leftBar && !root.panelOnRight", window)
        self.assertIn("readonly property int barOwnedLeftFrameReserve: barOwnsLacunaFrame && externalLeftFrameReserveActive && !sidebarSurfaceVisible ? frameThickness : 0", window)
        self.assertIn("readonly property int sidebarReserveSize: sidebarReserveActive ? Math.max(0, panelWidth + effectiveSidebarReserveExtra - barOwnedLeftFrameReserve) : 0", window)
        self.assertIn('property string frameReserveMode: "auto"', read("lacuna.menu/menu/MenuRegistry.qml"))
        self.assertIn('reserveMode: "auto"', read("lacuna.menu/services/LacunaSettings.qml"))
        self.assertIn("readonly property bool frameReserveFlush: frameReserveMode === \"flush\" || hyprWindowGapsDisabled || (frameReserveMode === \"auto\" && fakeFullscreenWorkspaceActive())", window)
        self.assertIn("readonly property bool barOwnsLacunaFrame: hostManaged || (shell && shell.bar && shell.bar.lacunaFrameHost === true)", window)
        self.assertIn("property bool hostManaged: false", window)
        self.assertIn("if (root.hostManaged) return", window)
        self.assertIn("function frameOverlayWidthFor(screen)", window)
        self.assertIn("readonly property var flyoutScreen: MonitorPolicy.chooseFlyoutScreen(Quickshell.screens, sidebarMonitorPolicy, activeMonitorName, sidebarMonitorNames)", window)
        self.assertIn("Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor", window)
        self.assertIn("onLiveFocusedMonitorNameChanged", window)
        self.assertIn("onTriggered: root.settledFocusedMonitorName = root.liveFocusedMonitorName", window)
        self.assertIn('sidebarMonitorPolicy === "auto" || requestedInteractionMonitorName === ""', window)
        self.assertIn("function flyoutVisibleOnScreen(screen)", window)
        self.assertIn("function flyoutOpenOnScreen(screen)", window)
        self.assertIn("function flyoutInteractiveOnScreen(screen)", window)
        self.assertIn("function flyoutLaneWidthFor(screen, effectiveConnectorWidth)", window)
        self.assertIn("if (!sidebarVisibleOnScreen(screen)) return 0", window)
        self.assertIn("function maxFlyoutExtentFor(screen)", window)
        self.assertIn("flyoutGeometryFor(screen, kinds[i], 0).width", window)
        self.assertIn("connectorWidth + flyoutGeometryFor(screen, kinds[i], connectorWidth).width", window)
        self.assertIn("return extent + 1", window)
        self.assertIn("- Math.max(0, Number(effectiveConnectorWidth) || 0)", window)
        self.assertNotIn("return flyoutVisibleOnScreen(screen) ? flyoutLaneWidth : 0", window)
        self.assertIn("flyoutOpen: root.lacunaEnabled && root.flyoutOpenOnScreen(modelData)", window)
        self.assertIn("flyoutInteractive: root.lacunaEnabled && root.flyoutInteractiveOnScreen(modelData)", window)
        self.assertIn("flyoutLaneWidth: root.flyoutLaneWidthFor(modelData, panelHost.effectiveConnectorWidth)", window)
        self.assertIn("flyoutRenderable: root.lacunaEnabled && root.flyoutVisibleOnScreen(modelData)", window)
        self.assertIn("open: root.flyoutOpenOnScreen(modelData)", window)
        self.assertIn("interactive: root.flyoutInteractiveOnScreen(modelData)", window)
        panel_window = read("lacuna.menu/menu/LacunaPanelWindow.qml")
        self.assertIn("property bool keyboardInputActive: false", panel_window)
        self.assertIn("property bool shortcutInhibitionActive: false", panel_window)
        self.assertIn("? WlrKeyboardFocus.Exclusive", panel_window)
        self.assertIn("root.dismissActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None", panel_window)
        self.assertIn("ShortcutInhibitor {", panel_window)
        self.assertIn("enabled: root.shortcutInhibitionActive", panel_window)
        self.assertIn("root.activeFlyoutMediaPlayer || root.activeFlyoutAppPicker", window)
        self.assertIn("menuContent.quickLaunchRenameOpen", window)
        self.assertIn("shortcutInhibitionActive: menuWindow.keyboardInputActive && mediaPlayerContent.searchInputFocused", window)
        self.assertIn("HyprlandFocusGrab {", panel_window)
        self.assertIn("active: root.focusGrabActive", panel_window)
        self.assertIn("root.focusSessionRevision += 1", panel_window)
        self.assertIn('sequence: "Backspace"', panel_window)
        self.assertIn("!root.textEditingActive", panel_window)
        self.assertIn("dismissActive: root.lacunaEnabled && root.flyoutInteractiveOnScreen(modelData)", window)
        self.assertIn("onDismissRequested: function(reason) { root.closeFlyouts(reason) }", window)
        self.assertIn("onFocusGrabCleared: function(reason) { root.closeFlyouts(reason) }", window)
        self.assertIn("mode: root.lacunaEnabled && !menuWindow.fullscreenSuppressed", window)
        self.assertIn("shadowEnabled: root.lacunaEnabled && !menuWindow.fullscreenSuppressed", window)
        self.assertIn("readonly property bool frameReserveActive: !barOwnsLacunaFrame && lacunaEnabled", window)
        self.assertIn("readonly property int effectiveSidebarReserveExtra: frameReserveFlush ? 0 : sidebarReserveExtra", window)
        self.assertIn("readonly property bool hyprWindowGapsDisabled", window)
        self.assertIn("shellHyprState.windowGapsEnabled === false", window)
        self.assertIn("function hyprGapValue(value)", window)
        self.assertIn("function fakeFullscreenWorkspaceActive()", window)
        self.assertIn("function gapslessWorkspaceActive()", window)
        self.assertIn("return hyprWindowGapsDisabled || fakeFullscreenWorkspaceActive()", window)
        self.assertIn("Hyprland.monitorFor(screen)", window)
        self.assertIn("function fullscreenWorkspaceOnScreen(screen)", window)
        self.assertIn("readonly property bool sidebarRenderable: root.sidebarVisibleOnScreen(modelData)", window)
        self.assertIn("if (monitor && monitor.activeWorkspace) return monitor.activeWorkspace", window)
        self.assertIn("import Quickshell.Hyprland", window)
        self.assertIn("property int hostBarSize: 0", window)
        self.assertIn("if (hostBarSize > 0) return positiveInt(hostBarSize, verticalFallback)", window)
        self.assertIn("if (hostBarSize > 0) return positiveInt(hostBarSize, configBarHeight())", window)
        self.assertIn("barEdgeCasterSize: root.barEdgeCasterSize", window)
        self.assertIn("moldingPieces: root.frameMoldingPieces", window)
        self.assertIn("function holdFlyoutAfterSettingsActivation()", window)
        self.assertIn("function openPayload(payloadJson)", window)
        self.assertIn("function openPayloadFlyout(payload)", window)
        self.assertIn('if (flyout === "settings")', window)
        self.assertIn('if (flyout === "shellSettings")', window)
        self.assertIn('if (flyout === "appPicker")', window)
        self.assertIn('if (flyoutFocusClearHold.running && nextReason === "click-away") return', window)
        self.assertIn("id: flyoutFocusClearHold", window)
        self.assertNotIn("Date.now()", window)
        self.assertIn("property int railReferenceBarHeight: Math.max(1, root.topBar && root.barHeight > 0 ? root.barHeight : configBarHeight())", window)
        self.assertIn("property int railPanelWidth: Math.round(railReferenceBarHeight)", window)
        self.assertIn("property int railButtonWidth: railPanelWidth", window)
        self.assertIn("property int railLeftInset: 0", window)
        self.assertIn("property int railRightInset: 0", window)
        self.assertIn("property int panelWidth: sidebarSurfaceVisible ? (sidebarState.collapsed ? railPanelWidth : fullPanelWidth) : 0", window)
        self.assertIn("property real barEdgeCasterSize: frameThickness", overlay)
        self.assertIn("readonly property real sidebarOccupiedWidth: sidebarWidth + (sidebarMoldingVisible ? sidebarMoldingWidth : 0)", overlay)
        self.assertIn("sidebarX + sidebarOccupiedWidth", overlay)
        self.assertNotIn("shadowJoinOverlap", overlay)
        self.assertNotIn("barEdgeShadowEnabled", overlay)
        self.assertIn("readonly property real horizontalBarShadowWidth", overlay)
        self.assertIn("visible: root.topBar && root.horizontalBarShadowWidth > 0", overlay)
        self.assertIn("x: root.horizontalBarShadowX", overlay)
        self.assertIn("property bool moldingPieces: true", overlay)
        self.assertNotIn("id: surfaceShadowLayer", overlay)
        self.assertIn("LacunaPanelUnifiedSurface", window)
        self.assertIn("flyoutRenderable: root.flyoutVisibleOnScreen(modelData)", window)
        self.assertIn("connectorRenderable: menuWindow.sidebarRenderable && panelHost.effectiveConnectorVisible", window)
        self.assertIn("backgroundVisible: false", window)
        self.assertIn("source: frameSource", overlay)
        self.assertNotIn("id: sidebarSilhouette", overlay)
        self.assertNotIn("id: connectorSilhouette", overlay)
        self.assertNotIn("id: flyoutSilhouette", overlay)
        self.assertNotIn("drawCoveredSurfaceSilhouettes", overlay)
        self.assertIn("root.fullFrame && root.moldingPieces && root.topBar && !root.leftBar && !root.leftEdgeOccupied", overlay)
        surface = read("lacuna.menu/menu/MenuSurface.qml")
        self.assertIn("property bool fullFrame: false", surface)
        self.assertIn("id: bottomFrameJoinShape", surface)
        self.assertIn("readonly property bool bottomFrameJoinVisible: backgroundVisible && fullFrame", surface)
        self.assertIn('&& barPosition !== "bottom" && frameMoldingPieces && bodyRightInset > 0', surface)
        self.assertIn("visible: root.bottomFrameJoinVisible", surface)
        self.assertIn("fullFrame: root.frameMode === \"fullframe\"", window)
        self.assertIn("frameThickness: root.frameThickness", window)
        self.assertNotIn("import QtQuick.Shapes", window)
        self.assertIn("frameReserveRight: frameReserveActive && frameMode === \"fullframe\" && !root.panelOnRight && !root.rightBar ? frameThickness + reservePadding : 0", window)
        self.assertIn("topBarShadowReserve: frameReserveActive && root.topBar ? reservePadding : 0", window)
        self.assertIn("WlrLayershell.namespace: layerNamespace + \"-\" + edge", reserve)
        self.assertIn("edge suffix keeps", reserve)

    def test_plugin_manifests_have_existing_item_entrypoints(self):
        kind_entry_points = {
            "bar": "bar",
            "bar-widget": "barWidget",
            "panel": "panel",
            "overlay": "overlay",
            "menu": "menu",
            "service": "service",
        }

        manifest_paths = plugin_manifest_paths()
        self.assertTrue(manifest_paths)
        self.assertFalse((ROOT / "plugins").exists())

        for manifest_path in manifest_paths:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(1, manifest.get("schemaVersion"), manifest_path)
            self.assertIsInstance(manifest.get("id"), str, manifest_path)
            self.assertTrue(manifest["id"].startswith("lacuna."), manifest_path)
            self.assertFalse(manifest["id"].startswith("omarchy."), manifest_path)
            self.assertEqual(manifest_path.parent.name, manifest["id"], manifest_path)
            for required in ["name", "version", "kinds", "entryPoints"]:
                self.assertIn(required, manifest, manifest_path)

            entry_points = manifest.get("entryPoints", {})
            self.assertIsInstance(entry_points, dict, manifest_path)
            self.assertTrue(entry_points, manifest_path)

            for kind in manifest["kinds"]:
                self.assertIn(kind, kind_entry_points, manifest_path)
                self.assertIn(kind_entry_points[kind], entry_points, manifest_path)

            for entry_path in entry_points.values():
                self.assertIsInstance(entry_path, str, manifest_path)
                self.assertFalse(entry_path.startswith("/"), manifest_path)
                self.assertNotIn("..", entry_path, manifest_path)
                qml_path = manifest_path.parent / entry_path
                self.assertTrue(qml_path.exists(), qml_path)
                self.assertNotIn("ShellRoot", qml_path.read_text(encoding="utf-8"), qml_path)

    def test_plugin_manifest_schemas_have_coherent_defaults(self):
        for manifest_path in plugin_manifest_paths():
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            containers = []
            if isinstance(manifest.get("barWidget"), dict):
                containers.append(("barWidget", manifest["barWidget"]))
            containers.append(("root", manifest))

            for label, container in containers:
                schema = container.get("schema", [])
                defaults = container.get("defaults", {})
                if not schema:
                    continue

                self.assertIsInstance(defaults, dict, (manifest_path, label))
                for entry in schema:
                    key = entry["key"]
                    self.assertIn(key, defaults, (manifest_path, label, key))
                    self.assertIn("defaultValue", entry, (manifest_path, label, key))
                    self.assertEqual(defaults[key], entry["defaultValue"], (manifest_path, label, key))

    def test_command_runners_do_not_log_successful_command_payloads(self):
        for path in [
            "lacuna.menu/services/CommandRunner.qml",
            "lacuna.shell-settings/CommandRunner.qml",
        ]:
            qml = read(path)
            self.assertNotIn("console.log", qml, path)
            self.assertIn("console.warn(\"lacuna command failed:\"", qml, path)
            self.assertIn("property var failureQueue", qml, path)
            self.assertIn("function notifyFailure", qml, path)
            self.assertIn("function drainFailures", qml, path)
            self.assertIn("onExited: root.drainFailures()", qml, path)

    def test_media_player_favorites_are_persisted_and_exposed(self):
        service = read("lacuna.media-player/Service.qml")

        for snippet in [
            "property var favorites: []",
            "property int favoritesRevision: 0",
            "readonly property int favoritesLength: favoritesRevision >= 0 ? favorites.length : 0",
            "readonly property bool currentFavorite: favoritesRevision >= 0 && isFavorite(currentTrack)",
            "version: 4",
            "favorites: normalizeUniqueTrackList(source.favorites, 500)",
            "repeatMode: normalizeRepeatMode(source.repeatMode)",
            "provider: provider",
            "providerId: providerId",
            "mediaType: mediaType",
            "streamKind: streamKind",
            "libraryName: String(track.libraryName || \"\")",
            "favorites: favorites",
            "repeatMode: repeatMode",
            "favorites = restored.favorites",
            "repeatMode = restored.repeatMode",
            "property var lacunaSettings: ({})",
            "property string searchFilter: \"all\"",
            "readonly property string lacunaSettingsFile",
            "readonly property bool jellyfinConfigured",
            "readonly property string authScript",
            "readonly property string youtubeAuthDir",
            "readonly property string youtubeCookiesFile",
            "readonly property string youtubeConfigJson",
            "readonly property bool youtubeLoginEnabled",
            "function youtubeProviderSettings()",
            "function youtubeConfigValue(key, fallback)",
            "readonly property string jellyfinSearchScript",
            "readonly property string jellyfinStreamScript",
            "readonly property string infoScript",
            "readonly property string refreshFavoritesScript",
            "function jellyfinProviderSettings()",
            "function providerFor(track)",
            "function streamKindFor(track)",
            "function itemHasVideo(track)",
            "providerSearchActive = true",
            "startJellyfinSearch(trimmed, providerSearchLimit(\"jellyfin\"), searchRevision)",
            "jellyfinSearchProc.pendingCommand = [jellyfinSearchScript, \"--settings-file\", lacunaSettingsFile",
            "completeProviderSearch(\"jellyfin\", rows, error, requestRevision)",
            "function normalizeUniqueTrackList",
            "function normalizeRepeatMode",
            "function normalizeSearchFilter(value)",
            "function isYoutubeUrl(value)",
            "function normalizeYoutubeUrl(value)",
            "function playUrl(url)",
            "function resolveTrackInfo(track)",
            "property bool resolvingTrackInfo",
            "property bool refreshingFavorites",
            "property string trackInfoRequestUrl",
            "readonly property string defaultSuggestionsQuery",
            "property bool pendingDefaultSuggestions: false",
            "function loadDefaultSuggestions()",
            "function refreshYoutubeResultsAfterLogin()",
            "if (youtubeLoginEnabled) refreshYoutubeResultsAfterLogin()",
            "function startYoutubeSuggestions(limit, revision)",
            "startYoutubeSuggestions(Math.min(providerSearchLimit(\"youtube\"), 24), searchRevision)",
            "searchProc.pendingCommand = [searchScript, \"--config-json\", youtubeConfigJson, \"--filter\", \"all\"",
            "pendingDefaultSuggestions = true",
            "if (root.pendingDefaultSuggestions && (root.ytdlpAvailable || root.jellyfinConfigured)) root.loadDefaultSuggestions()",
            "function openYoutubeLogin()",
            "function openYoutubeMusicLogin()",
            "authProc.command = [authScript, \"--auth-dir\", youtubeAuthDir]",
            "id: authProc",
            "videoIdFromUrl(normalizedUrl)",
            "resolveTrackInfo(currentTrack)",
            "id: trackInfoProc",
            "trackInfoProc.command = [infoScript, \"--config-json\", root.youtubeConfigJson, root.trackInfoRequestUrl]",
            "root.currentTrack = resolved",
            "Paste a YouTube URL",
            "function favoriteIndex(track)",
            "function isFavorite(track)",
            "function favoriteTrack(track)",
            "function unfavoriteTrack(track)",
            "function toggleFavorite(track)",
            "function removeFavorite(index)",
            "function playFavorite(index)",
            "function playFavoriteIndex(index: string): string",
            "function playUrl(url: string): string",
            "function clearFavorites()",
            "function refreshFavoriteMetadata()",
            "function setRepeatMode(mode)",
            "function cycleRepeatMode()",
            "function handlePlaybackEnded()",
            "if (repeatMode === \"one\" && currentTrack)",
            "playNextFromQueue(true, repeatMode === \"all\")",
            "stop()",
            "onRepeatModeChanged: scheduleStateSave()",
            "playbackProbeFailures >= 2",
            "property double playbackStartedAtMs: 0",
            "Date.now() - playbackStartedAtMs < 10000",
            "playbackStartedAtMs = Date.now()",
            "function markPlaybackFailed(message)",
            "function notePlaybackProbeFailure()",
            "markPlaybackFailed(\"Playback stream unavailable\")",
            "function notePlaybackEnded()",
            "function playbackLooksFinished()",
            "property real playbackDuration: 0",
            "property bool playbackEndHandled: false",
            "property int playbackSessionRevision: 0",
            "positionProc.command = [controlScript, \"probe\", \"--socket\", playbackSocket()]",
            "if (positionProc.sessionRevision !== root.playbackSessionRevision) return",
            "payload.eofReached === true || (payload.idleActive === true && root.playbackDuration > 0)",
            "if (payload.running !== true && root.playbackLooksFinished())",
            "root.notePlaybackEnded()",
            "playbackDuration: root.playbackDuration",
            "youtubeConfig.enabled === true && youtubeConfig.cookiesFile !== \"\"",
            "else if (youtubeConfig.enabled === true && youtubeConfig.cookiesFromBrowser !== \"\")",
            "property int backgroundRequestRevision: 0",
            "property bool backgroundResolveFailed: false",
            "property var streamUrlCache",
            "readonly property int streamUrlCacheTtlMs",
            "property var previewTelemetry",
            "function updatePreviewTelemetry(payload)",
            "function cachedStreamUrl(trackOrUrl)",
            "function rememberStreamUrl(trackOrUrl, url)",
            "backgroundRequestRevision += 1",
            "function refreshBackgroundStream()",
            "function prefetchNextBackground()",
            "function setPresentationMode(value)",
            "function reconcilePresentationState()",
            "property string presentationMode: \"auto\"",
            "property string presentationState: \"inline\"",
            "readonly property bool desiredBackgroundVideo",
            "function reportVideoLoading(surface, token, diagnostics)",
            "function reportVideoReady(surface, revision, position, token, diagnostics)",
            "function reportVideoFailure(surface, revision, reason, token, diagnostics)",
            "function safePresentationFailureReason(reason)",
            'property string presentationErrorText: ""',
            "presentationError: root.presentationErrorText",
            'property string handoffPhase: "idle"',
            "property bool rendererHandoffDeadlineActive: false",
            "resolvingBackground = false",
            "backgroundStreamUrl = \"\"",
            "backgroundRequestUrl = \"\"",
            "backgroundResolveFailed = false",
            "backgroundResolveFailed: root.backgroundResolveFailed",
            "function refreshBackgroundStream(): string",
            "Background video is unavailable for audio-only media",
            "if (previewStreamUrl === \"\" && !resolvingPreview) resolvePreview(currentTrack)",
            "previewTelemetry: root.previewTelemetry",
            "trackInfoResolving: root.resolvingTrackInfo",
            "refreshingFavorites: root.refreshingFavorites",
            "backgroundRequestRevision: root.backgroundRequestRevision",
            "repeatMode: root.repeatMode",
            "searchFilter: root.searchFilter",
            "onFavoritesChanged: {",
            "favoritesRevision += 1",
            "favoritesLength: root.favoritesLength",
            "currentFavorite: root.currentFavorite",
            "function toggleFavoriteCurrent(): string",
            "function refreshFavoriteMetadata(): string",
            "function cycleRepeatMode(): string",
            "function openYoutubeLogin(): string",
            "function openYoutubeMusicLogin(): string",
        ]:
            self.assertIn(snippet, service)
        self.assertTrue((ROOT / "lacuna.media-player/scripts/youtube-auth").exists())
        self.assertTrue((ROOT / "lacuna.media-player/scripts/jellyfin-search").exists())
        self.assertTrue((ROOT / "lacuna.media-player/scripts/jellyfin-stream").exists())
        self.assertTrue((ROOT / "lacuna.media-player/scripts/media-player-info").exists())
        self.assertTrue((ROOT / "lacuna.media-player/scripts/media-player-refresh-favorites").exists())
        self.assertTrue((ROOT / "lacuna.media-player/scripts/media-player-worker").exists())
        search_script = read("lacuna.media-player/scripts/media-player-search")
        self.assertIn("def youtube_home_results", search_script)
        self.assertIn("def filtered_home_music_rows", search_script)
        self.assertIn('parser.add_argument("--filter"', search_script)
        self.assertIn('"https://www.youtube.com/"', search_script)
        self.assertIn('"YouTube Home"', search_script)
        self.assertIn('"YouTube Home Music"', search_script)

    def test_media_player_favorites_are_available_in_menu_ui(self):
        flyout = read("lacuna.menu/menu/FlyoutMediaPlayerContent.qml")
        tile = read("lacuna.menu/menu/MediaPlayerTile.qml")
        icons = read("lacuna.menu/components/LacunaTablerIcon.qml")

        for snippet in [
            "id: accountButton",
            'icon: "user-circle"',
            "root.service.openYoutubeLogin()",
            'id: "favorites"',
            'icon: "heart"',
            'label: "Favorites"',
            "readonly property string repeatMode",
            "readonly property string currentProviderFilter",
            "function setProviderFilter(value)",
            "readonly property int favoritesLength",
            "readonly property int favoritesRevision",
            "readonly property bool inputIsYoutubeUrl",
            "service.playUrl(searchInput.text)",
            "service.loadDefaultSuggestions()",
            "function ensureDefaultSuggestions()",
            "id: defaultSuggestionsTimer",
            "defaultSuggestionsTimer.restart()",
            'readonly property bool searchInputFocused: open && activeTab === "search" && searchInput.activeFocus',
            "var count = visibleSearchResults.length",
            "var rows = visibleSearchResults",
            "function dismissSearchPasteMenu()",
            "function dismissSearchPasteMenuAt(x, y)",
            "onOpenChanged: {",
            "onActiveTabChanged: {",
            "onVisibleSearchResultsChanged: {",
            "if (!activeFocus) root.dismissSearchPasteMenu()",
            'text: "Search media or paste YouTube URL"',
            'event.key === Qt.Key_V && (event.modifiers & Qt.MetaModifier) !== 0',
            'acceptedButtons: Qt.RightButton',
            'root.searchPasteMenuOpen = searchInput.canPaste',
            'id: searchFieldShell',
            'z: root.searchPasteMenuOpen ? 100 : 0',
            'visible: root.searchPasteMenuOpen && searchInput.canPaste',
            'text: "Paste"',
            'searchInput.paste()',
            'id: searchActionButton',
            'accessibleName: searchInput.text !== "" && !root.inputIsYoutubeUrl ? "Clear search"',
            "id: searchFilterRow",
            'text: "All"',
            "id: transportControls",
            'visible: root.activeTab !== "search"',
            "id: durationBadgeText",
            "text: modelData.duration || \"\"",
            "function isFavorite(track)",
            "var revision = favoritesRevision",
            "service.clearFavorites()",
            "root.service.toggleFavorite(modelData)",
            "root.service.playNow(modelData)",
            "Favorite media from Search or Queue",
            'text: "Media"',
            "modelData.source || modelData.provider || \"\"",
            "id: favoritesScroll",
            "showLabels: false",
            "model: root.visibleFavorites",
        ]:
            self.assertIn(snippet, flyout)
        self.assertIn('icon === "user-circle" || icon === "account"', icons)

        self.assertIn('icon: root.service && root.service.currentFavorite ? "heart-filled" : "heart"', flyout)
        self.assertNotIn("id: headerFavoriteButton", flyout)
        self.assertIn('icon: root.currentFavorite ? "heart-filled" : "heart"', tile)
        self.assertIn("readonly property int favoritesRevision", tile)
        self.assertIn("id: tileFavoriteButton", tile)
        self.assertIn("anchors.right: parent.right", tile)
        self.assertIn("anchors.rightMargin: root.tileInset + tileFavoriteButton.width", tile)
        self.assertIn("root.service.toggleFavorite(root.service.currentTrack)", tile)
        self.assertIn("root.service.toggleBackgroundVideo()", tile)
        self.assertNotIn("root.service.setBackgroundVideoEnabled(true)", tile)
        self.assertIn("root.service.cycleRepeatMode()", tile)
        self.assertIn('icon: root.repeatMode === "one" ? "repeat-once" : "repeat"', tile)
        self.assertIn("readonly property real playbackPosition", tile)
        self.assertIn("readonly property bool localPreviewVisible: hasTrack && !sentToBackground", tile)
        self.assertIn("property bool previewSuppressed: false", tile)
        self.assertIn("readonly property bool previewVideoActive: previewActive && !previewSuppressed", tile)
        self.assertIn("previewSuppressed: previewSuppressed", tile)
        self.assertIn("function syncPreviewPosition(force)", tile)
        self.assertIn("function previewCanSeek()", tile)
        self.assertIn("function previewBuffering()", tile)
        self.assertIn("function previewStartupSettling()", tile)
        self.assertIn("function recoverPreviewPlayback()", tile)
        self.assertIn("function maintainPreviewPosition()", tile)
        self.assertIn("function previewDiagnosticPayload()", tile)
        self.assertIn("function samplePreviewTelemetry(reason)", tile)
        self.assertIn("service.updatePreviewTelemetry(previewDiagnosticPayload())", tile)
        self.assertIn("likelyFrozen", tile)
        self.assertIn("property double previewPlaybackStartedAt", tile)
        self.assertIn("property int previewStablePositionTicks", tile)
        self.assertIn("if (!localPreviewVisible) {", tile)
        self.assertIn("previewPositionSettleTimer.stop()", tile)
        self.assertIn("previewRecoveryTimer.stop()", tile)
        self.assertIn("previewPlayer.play()", tile)
        self.assertIn("previewPositionSettleTimer.restart()", tile)
        self.assertIn("previewRecoveryTimer.restart()", tile)
        self.assertIn("previewPlayer.pause()", tile)
        self.assertIn("previewPlayer.playbackState === MediaPlayer.StoppedState", tile)
        self.assertIn("previewPlayer.mediaStatus === MediaPlayer.LoadedMedia", tile)
        self.assertIn("previewPlayer.mediaStatus === MediaPlayer.BufferedMedia", tile)
        self.assertIn("previewPlayer.mediaStatus === MediaPlayer.LoadingMedia", tile)
        self.assertIn("previewPlayer.mediaStatus === MediaPlayer.BufferingMedia", tile)
        self.assertIn("previewPlayer.setPosition(target)", tile)
        self.assertIn("if (!force && previewBuffering()) return", tile)
        self.assertIn("if (drift < 400)", tile)
        self.assertIn("var drift = Math.abs(previewPlayer.position - target)", tile)
        self.assertIn("if (drift <= 1500)", tile)
        self.assertIn("previewPlayer.playbackRate = signedDrift < 0 ? 1.03 : 0.97", tile)
        self.assertIn("Date.now() - previewLastSeekAt < 1500", tile)
        # Desktop-to-sidebar handoff: the hidden preview unloads and reloads
        # fresh on return, resume clears the suppression latch, in-flight
        # seeks are not re-issued or judged as drift, and the watchdog only
        # suppresses after repeated failed corrections.
        self.assertIn("if (localPreviewVisible) previewSuppressed = false", tile)
        self.assertIn('readonly property string desiredPreviewSource: previewRendererActive && localPreviewVisible ? previewUrl : ""', tile)
        self.assertIn("readonly property bool previewRendererActive: playbackLoaded && previewVideoActive", tile)
        self.assertIn("function syncPreviewSource()", tile)
        self.assertIn('service.reportVideoLoading("inline", activePreviewHandoffToken', tile)
        self.assertIn("id: previewPlayerLoader", tile)
        self.assertIn("function inlineSourceGenerationIsCurrent(player)", tile)
        self.assertIn("onPresentationRevisionChanged: syncPreviewSource()", tile)
        self.assertIn('resetPreviewTelemetry("stopped")', tile)
        self.assertIn("property int previewDriftStrikes: 0", tile)
        self.assertIn("previewDriftStrikes += 1", tile)
        self.assertIn("if (previewDriftStrikes === 2)", tile)
        self.assertIn('reportInlineFailure("seek-correction")', tile)
        self.assertIn("previewLastSeekAt = Date.now()", tile)
        self.assertIn("syncPreviewPosition(false)", tile)
        self.assertIn('samplePreviewTelemetry("periodic")', tile)
        self.assertIn("onTriggered: root.maintainPreviewPosition()", tile)
        self.assertIn("id: previewPositionSettleTimer", tile)
        self.assertIn("id: previewRecoveryTimer", tile)
        self.assertIn("onPlaybackStateChanged", tile)
        self.assertIn("onMediaStatusChanged", tile)
        self.assertIn("root.syncPreviewPosition(true)", tile)
        self.assertIn("mediaStatus === MediaPlayer.StalledMedia", tile)
        self.assertIn("mediaStatus === MediaPlayer.InvalidMedia", tile)
        self.assertIn("previewPositionSettleTimer.interval = 1800", tile)
        self.assertIn("interval = 350", tile)
        self.assertIn("onPlaybackPositionChanged: if (previewPositionPending) syncPreviewPosition(false)", tile)
        self.assertLess(tile.index("previewPlayer.play()"), tile.index("previewPositionSettleTimer.restart()"))
        self.assertLess(tile.index("previewPlayer.play()"), tile.index("previewPlayer.setPosition(target)"))
        self.assertIn('name === "heart-filled"', icons)
        self.assertIn('if (icon === "heart" || icon === "heart-filled")', icons)
        self.assertIn('if (icon === "repeat")', icons)
        self.assertIn('if (icon === "repeat-once")', icons)

    def test_lacuna_manifest_metadata_describes_install_groups(self):
        manifests = {
            path.parent.name: json.loads(path.read_text(encoding="utf-8"))
            for path in plugin_manifest_paths()
        }
        standalone = {
            "lacuna.audio",
            "lacuna.aurora-drift",
            "lacuna.background-vignette",
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
            "lacuna.system-stats",
            "lacuna.system-update",
            "lacuna.temperature",
            "lacuna.theme",
            "lacuna.tray",
            "lacuna.vhs-overlay",
            "lacuna.voxtype",
            "lacuna.wallpaper",
            "lacuna.weather",
            "lacuna.workspaces",
            "lacuna.media-player",
            "lacuna.media-player-video",
        }
        bundle_only = set(manifests) - standalone

        self.assertEqual(
            {
                "lacuna.ambience-host",
                "lacuna.compact-pill",
                "lacuna.bar",
                "lacuna.menu",
                "lacuna.menu-button",
                "lacuna.shell-settings",
                "lacuna.state",
                "lacuna.theme-preloader",
            },
            bundle_only,
        )
        for plugin_id, manifest in manifests.items():
            metadata = manifest.get("lacuna", {})
            self.assertIsInstance(metadata.get("standalone"), bool, plugin_id)
            self.assertIn(metadata.get("bundle"), {"standalone", "core", "theme", "ambience", "legacy"}, plugin_id)
            self.assertIsInstance(metadata.get("requires"), list, plugin_id)
            self.assertIsInstance(metadata.get("recommends"), list, plugin_id)
            for dependency in metadata["requires"] + metadata["recommends"]:
                self.assertIn(dependency, manifests, plugin_id)

        for plugin_id in standalone:
            self.assertTrue(manifests[plugin_id]["lacuna"]["standalone"], plugin_id)
            self.assertEqual("standalone", manifests[plugin_id]["lacuna"]["bundle"], plugin_id)
        for plugin_id in bundle_only:
            self.assertFalse(manifests[plugin_id]["lacuna"]["standalone"], plugin_id)

        self.assertEqual(["lacuna.menu"], manifests["lacuna.menu-button"]["lacuna"]["requires"])
        self.assertEqual(
            ["lacuna.state", "lacuna.shell-settings"],
            manifests["lacuna.menu"]["lacuna"]["requires"],
        )
        self.assertEqual(
            ["lacuna.state", "lacuna.shell-settings", "lacuna.menu"],
            manifests["lacuna.bar"]["lacuna"]["requires"],
        )
        self.assertEqual(["lacuna.bar-size-pill"], manifests["lacuna.compact-pill"]["lacuna"]["requires"])

    def test_lacuna_bar_is_bar_option_frame_host(self):
        manifest = read_json("lacuna.bar/manifest.json")
        bar = read("lacuna.bar/Bar.qml")
        adapter = read("lacuna.bar/OmarchyBarAdapter.qml")
        frame = read("lacuna.bar/LacunaFrameWindow.qml")
        omarchy_bar = read("lacuna.bar/OmarchyBar.qml")

        self.assertEqual(["bar"], manifest["kinds"])
        self.assertEqual("Bar.qml", manifest["entryPoints"]["bar"])
        self.assertIn('property string omarchyPath: ""', bar)
        self.assertIn("property var barWidgetRegistry: null", bar)
        self.assertIn("property var barConfig: ({})", bar)
        self.assertNotIn("required property string omarchyPath", bar)
        self.assertIn("property bool lacunaFrameHost: true", bar)
        self.assertIn("readonly property bool barHidden: omarchyBar.barItem && omarchyBar.barItem.barHidden === true", bar)
        self.assertIn("readonly property bool hostedMenuOpen: hostedMenu.menuState && hostedMenu.menuState.open === true", bar)
        self.assertIn('import "../lacuna.menu/menu"', bar)
        self.assertIn('import "../lacuna.menu/services"', bar)
        self.assertIn("readonly property string lacunaMenuSourceDir", bar)
        self.assertIn('id: "lacuna.menu"', bar)
        self.assertIn("readonly property bool hostedSidebarVisible", bar)
        self.assertIn("hostBarSize: root.barSize", bar)
        self.assertIn("readonly property bool hostedSidebarOnLeft", bar)
        self.assertIn("function hostedSidebarOccupiesEdge(edge, screen)", bar)
        self.assertIn("readonly property real hostedSidebarFrameOcclusionWidth", bar)
        self.assertIn("readonly property string lacunaFrameGeometryKey", bar)
        self.assertIn("hostedSidebarFrameOcclusionWidth", bar)
        self.assertIn('root.hostedSidebarOccupiesEdge("left", screen)', bar)
        self.assertIn('root.hostedSidebarOccupiesEdge("right", screen)', bar)
        self.assertIn('occupiedEdge === "" ? 0 : root.hostedSidebarFrameOcclusionWidth', bar)
        self.assertNotIn("      hostedSidebarVisible,\n      hostedSidebarFrameOcclusionWidth,", bar)
        self.assertIn("The full-frame cutout is cast from the visible sidebar body edge", bar)
        self.assertIn("pushes", bar)
        self.assertIn("the cutout and shadow past the actual frame edge", bar)
        self.assertNotIn("hostedSidebarOccupiedWidth", bar)
        self.assertIn("Theme {", bar)
        self.assertIn("function toggleMenu(payloadJson)", bar)
        self.assertIn("MenuWindow", bar)
        self.assertIn("hostManaged: true", bar)
        self.assertIn('root.shell.ensureService("lacuna.state")', bar)

        menu_entry = read("lacuna.menu/Menu.qml")
        self.assertIn("readonly property bool barHostAvailable", menu_entry)
        self.assertIn("shell.bar.lacunaFrameHost === true", menu_entry)
        self.assertIn("function unloadFallback", menu_entry)
        self.assertIn("onBarHostAvailableChanged", menu_entry)
        self.assertIn("fallbackLoader.active = false", menu_entry)
        self.assertIn("shell.bar.openMenu(payloadJson || \"{}\")", menu_entry)
        self.assertIn("shell.bar.closeMenu()", menu_entry)
        self.assertIn("Loader", menu_entry)
        self.assertIn("MenuWindow", menu_entry)
        self.assertIn('bar.toggleMenu("{}")', read("lacuna.menu-button/Widget.qml"))
        self.assertIn('readonly property bool frameEnabled: frameMode === "fullframe"', bar)
        self.assertIn("OmarchyBarAdapter", bar)
        self.assertIn("LacunaFrameWindow", bar)
        self.assertNotIn("LacunaFrameShadowWindow", bar)
        self.assertIn("OmarchyBar", adapter)
        self.assertIn("readonly property var barItem: omarchyBar", adapter)
        self.assertIn("property bool frameBorderEnabled: false", adapter)
        self.assertIn("property bool barOutlineEnabled: false", adapter)
        self.assertIn("property var barOutlineInsetsProvider: null", adapter)
        self.assertIn("frameBorderEnabled: root.frameBorderEnabled", adapter)
        self.assertIn("barOutlineEnabled: root.barOutlineEnabled", adapter)
        self.assertIn("barOutlineInsetsProvider: root.barOutlineInsetsProvider", adapter)
        self.assertIn("frameBorderColor: root.frameBorderColor", adapter)
        self.assertIn("function debugBarGeometry()", adapter)
        self.assertIn("function openConfigPanel()", adapter)
        self.assertIn("readonly property real itemImplicitWidth", omarchy_bar)
        self.assertIn("readonly property real itemImplicitHeight", omarchy_bar)
        self.assertIn('import "BarResponsiveModel.js" as BarResponsiveModel', omarchy_bar)
        self.assertIn("readonly property var responsivePlan: BarResponsiveModel.horizontalPlan(", omarchy_bar)
        self.assertIn("clip: moduleListRoot.overflowEnabled", omarchy_bar)
        self.assertIn("BarResponsiveModel.prepareSlotForHide(root, slot)", omarchy_bar)
        self.assertIn("property bool frameBorderEnabled: false", omarchy_bar)
        self.assertIn("property bool barOutlineEnabled: false", omarchy_bar)
        self.assertIn("property var barOutlineInsetsProvider: null", omarchy_bar)
        self.assertIn("property color frameBorderColor: Color.popups.border", omarchy_bar)
        self.assertIn('model: ["top", "bottom"]', omarchy_bar)
        self.assertIn('model: ["left", "right"]', omarchy_bar)
        self.assertEqual(2, omarchy_bar.count("barWindow.popoutBorderGapStart - barWindow.outlineAxisStart"))
        self.assertEqual(2, omarchy_bar.count("barWindow.outlineAxisEnd - barWindow.popoutBorderGapEnd"))
        self.assertIn("frameBorderEnabled: root.frameBorder", bar)
        self.assertIn("barOutlineEnabled: root.frameBorder && !root.frameEnabled", bar)
        self.assertIn("frameBorderColor: barTheme.frameBorder", bar)
        self.assertIn("readonly property bool contentVisible: activeItem && (itemImplicitWidth > 0 || itemImplicitHeight > 0)", omarchy_bar)
        self.assertNotIn("readonly property bool contentVisible: activeItem && activeItem.visible", omarchy_bar)
        self.assertIn('WlrLayershell.namespace: "lacuna-bar-frame"', frame)
        self.assertIn("WlrLayershell.layer: WlrLayer.Top", frame)
        self.assertIn("WlrLayershell.exclusionMode: ExclusionMode.Ignore", frame)
        self.assertIn("mask: Region {}", frame)
        self.assertIn('import "../lacuna.menu/components"', frame)
        self.assertIn("property bool leftEdgeOccupied: false", frame)
        self.assertIn("property bool rightEdgeOccupied: false", frame)
        self.assertIn("property real leftOccupiedWidth: 0", frame)
        self.assertIn("readonly property real holeX: hasGeometryRecord ? Number(geometryRecord.holeX || 0)", frame)
        self.assertIn("readonly property real holeRight: hasGeometryRecord ? Number(geometryRecord.holeRight || holeX + 1)", frame)
        self.assertIn("readonly property real minArcRadius: 0", frame)
        self.assertIn("readonly property real holeRadius: effectiveMoldingPieces ? Math.max(0, Math.min(r, holeWidth / 2, holeHeight / 2)) : 0", frame)
        self.assertIn("property bool shadowEnabled: false", frame)
        self.assertIn("readonly property int topInset: topBar || effectiveTopEdgeOccupied ? effectiveBarSize : t", frame)
        self.assertIn("readonly property int leftInset: leftBar ? effectiveBarSize : t", frame)
        # The frame must never paint under the bar: bar-over-frame rendering
        # is guaranteed by geometry because the vendored bar window's map
        # order (and therefore same-layer stacking) is not ours to control.
        self.assertIn("readonly property real outerY: hasGeometryRecord ? Number(geometryRecord.outerY || 0)", frame)
        self.assertIn("readonly property real outerX: hasGeometryRecord ? Number(geometryRecord.outerX || 0)", frame)
        self.assertIn("startY: root.isRenderable ? root.outerY : -1", frame)
        self.assertIn("readonly property color effectiveFrameColor", frame)
        self.assertIn("LacunaDropShadow", frame)
        # The shadow is cast by a hidden full-coverage silhouette (bar strip
        # included, hole collapsing to the bar edge when the frame is off) and
        # clipped to the content side of the chrome, so the bar's shadow hugs
        # the bar in every frame mode without painting over the bar.
        self.assertIn("id: frameShadowCaster", frame)
        self.assertIn("source: frameShadowCaster", frame)
        self.assertIn("property var shadowGeometryRecord: null", frame)
        self.assertIn("shadowGeometryRecord: root.lacunaFrameGeometryRecord(modelData)", bar)
        self.assertIn('readonly property real casterHoleY: shadowFrameRenderable ? shadowRecordHoleY : (shadowBarPosition === "top" || shadowTopEdgeOccupied ? shadowBarSize : 0)', frame)
        self.assertIn("shadowEnabled: !root.suppressed && root.shadowEnabled && root.width > 0 && root.height > 0", frame)
        self.assertIn("id: shadowClip", frame)
        self.assertIn("Shape {", frame)
        self.assertIn("id: frameSource", frame)
        self.assertIn("fillRule: ShapePath.OddEvenFill", frame)
        self.assertIn("PathMove", frame)
        self.assertIn("id: frameShadowMask", frame)
        self.assertIn("shadowMaskSource: frameShadowMask", frame)
        self.assertIn("visible: root.attachedFlyoutVisible", frame)
        self.assertNotIn("gradient: Gradient", frame)
        self.assertNotIn("Canvas {", frame)
        self.assertIn("sourceItem: frameShadowCaster", frame)
        self.assertIn("frameColor: barTheme.panelBackground", bar)
        self.assertIn("shadowEnabled: root.frameShadow", bar)
        self.assertIn("shadowOffsetX: root.frameShadowOffsetX", bar)
        self.assertIn("shadowOffsetY: root.frameShadowOffsetY", bar)
        self.assertIn("leftEdgeOccupied: root.hostedSidebarVisibleOnScreen(modelData) && !hostedMenu.panelOnRight", bar)
        self.assertIn("frameRadius: root.frameRadius", bar)
        self.assertIn("moldingPieces: root.frameMoldingPieces", bar)
        self.assertIn("leftOccupiedWidth: root.hostedSidebarFrameOcclusionWidth", bar)
        self.assertIn("rightOccupiedWidth: root.hostedSidebarFrameOcclusionWidth", bar)
        self.assertNotIn("readonly property real hostedSidebarShadowInset", bar)

    def test_theme_preloader_is_loaded_as_a_service(self):
        manifest = read_json("lacuna.theme-preloader/manifest.json")

        self.assertEqual(["service"], manifest["kinds"])
        self.assertEqual("Service.qml", manifest["entryPoints"]["service"])
        self.assertNotIn("panel", manifest["entryPoints"])

    def test_example_shell_configs_use_current_widget_ids(self):
        stale_ids = {
            "spacer",
            "tray",
            "calendar",
            "omarchy",
            "bluetoothPanel",
            "networkPanel",
            "audioPanel",
            "battery",
            "controlCenter",
        }

        for path in [
            "config/shell.phase1.example.json",
            "config/shell.lacuna-native-replacements.example.json",
        ]:
            config = read_json(path)
            layout = config["bar"]["layout"]
            ids = [entry["id"] for section in ["left", "center", "right"] for entry in layout[section]]
            self.assertFalse(stale_ids.intersection(ids), path)

    def test_theme_widget_schema_exposes_defaults_for_bar_settings(self):
        manifest = read_json("lacuna.theme/manifest.json")
        schema = {entry["key"]: entry for entry in manifest["barWidget"]["schema"]}
        qml = read("lacuna.theme/Widget.qml")

        self.assertEqual("boolean", schema["enabled"]["type"])
        self.assertIs(schema["enabled"]["defaultValue"], True)
        self.assertEqual(22, schema["maxTextLength"]["defaultValue"])
        self.assertNotIn("showIcon", schema)
        self.assertEqual("semantic", schema["colorProfile"]["defaultValue"])
        self.assertIn('readonly property bool widgetEnabled: boolSetting("enabled", true)', qml)
        self.assertIn("visible: widgetEnabled", qml)

    def test_usage_widgets_place_meter_away_from_open_indicator_edge(self):
        for plugin in ["lacuna.claude-usage", "lacuna.codex-usage"]:
            qml = read(f"{plugin}/Widget.qml")
            self.assertIn('readonly property bool showProgress: setting("showProgress", true) === true', qml)
            self.assertIn("readonly property int stableMinimumWidth: root.vertical ? root.barSize : (root.compact ? 58 : 104)", qml)
            self.assertIn("width: root.vertical ? root.barSize : Math.max(stableMinimumWidth, content.implicitWidth + root.horizontalPadding * 2)", qml)
            self.assertIn('readonly property bool meterAtTop: !root.vertical && root.bar && root.bar.position === "top"', qml)
            self.assertIn("y: button.meterAtTop ? 3 : parent.height - height - 3", qml)
            self.assertIn("anchors.verticalCenterOffset: button.meterHeight > 0 ? (button.meterAtTop ? 1 : -1) : 0", qml)
            self.assertIn("readonly property int activeUsedPercent: activeMode === 1 ? weekUsedPercent : usedPercent", qml)
            self.assertIn("parent.width * root.activeUsedPercent / 100", qml)

        claude_qml = read("lacuna.claude-usage/Widget.qml")
        claude_manifest = read_json("lacuna.claude-usage/manifest.json")
        claude_schema = {entry["key"]: entry for entry in claude_manifest["barWidget"]["schema"]}
        self.assertNotIn("secondaryText", claude_qml)
        self.assertNotIn("resetLabel", claude_qml)
        self.assertNotIn("showReset", claude_qml)
        self.assertNotIn("showReset", claude_manifest["barWidget"]["defaults"])
        self.assertNotIn("showReset", claude_schema)

        codex_manifest = read_json("lacuna.codex-usage/manifest.json")
        codex_schema = {entry["key"]: entry for entry in codex_manifest["barWidget"]["schema"]}
        self.assertIs(codex_manifest["barWidget"]["defaults"]["showProgress"], True)
        self.assertEqual("boolean", codex_schema["showProgress"]["type"])
        self.assertIs(codex_schema["showProgress"]["defaultValue"], True)
        self.assertIs(codex_manifest["barWidget"]["defaults"]["showWeekly"], True)
        self.assertEqual("boolean", codex_schema["showWeekly"]["type"])
        self.assertEqual(6000, codex_manifest["barWidget"]["defaults"]["cycleInterval"])
        self.assertEqual("integer", codex_schema["cycleInterval"]["type"])
        self.assertEqual("left", codex_manifest["barWidget"]["defaults"]["displayMode"])
        self.assertEqual("enum", codex_schema["displayMode"]["type"])

    def test_usage_widgets_match_theme_wallpaper_bar_typography_and_seam(self):
        for plugin in ["lacuna.claude-usage", "lacuna.codex-usage"]:
            qml = read(f"{plugin}/Widget.qml")
            self.assertIn("readonly property color iconColor: moduleColor", qml)
            self.assertIn("readonly property color textColor: foreground", qml)
            self.assertIn("readonly property color seamColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)", qml)
            self.assertIn("readonly property int topbarIconSize: barSize >= 30 ? 15 : 13", qml)
            self.assertIn("readonly property int topbarTextSize: barSize <= 26 ? 12 : 13", qml)
            self.assertIn("readonly property int contentSpacing: 5", qml)
            self.assertIn("readonly property int horizontalPadding: vertical ? 0 : 5", qml)
            self.assertIn("width: root.topbarIconSize", qml)
            self.assertIn("visible: root.showIcon && label.text.length > 0", qml)
            self.assertIn("colorizationColor: root.iconColor", qml)
            self.assertIn("color: root.textColor", qml)
            self.assertIn("pixelSize: root.topbarTextSize", qml)
            self.assertIn("fontWeight: Font.DemiBold", qml)

    def test_mpris_matches_bar_style_without_removing_playing_sweep(self):
        widget = read("lacuna.mpris/Widget.qml")
        button = read("lacuna.mpris/components/LacunaMprisButton.qml")
        profile = read("lacuna.mpris/ColorProfile.qml")

        self.assertIn("accentText: false", widget)
        self.assertIn("contentHorizontalPadding: 10", widget)
        self.assertIn("labelPixelSize: 12", widget)
        self.assertIn("iconSize: root.barSize >= 30 ? 15 : 13", widget)
        self.assertIn("labelFontWeight: Font.DemiBold", widget)
        self.assertIn('sweepActive: root.sweepOnPlaying && root.cssClass === "playing"', widget)

        self.assertIn("property int contentSpacing: 5", button)
        self.assertIn("property int labelPixelSize: 12", button)
        self.assertIn("return root.accentText ? root.accent : root.foreground", button)
        self.assertIn("strokeColor: root.accent", button)
        self.assertIn("width: root.iconSize", button)
        self.assertIn('visible: root.iconName !== "" && root.text.length > 0', button)
        self.assertIn("color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)", button)
        self.assertIn("NumberAnimation on sweepPosition", button)
        self.assertIn("running: root.sweepActive && root.visible", button)
        self.assertIn("color: root.textSweepColor(index, label.text.length)", button)

        self.assertIn('stateHome + "/omarchy/current/theme/colors.toml"', profile)
        self.assertIn('playing: "green"', profile)
        self.assertIn('paused: "muted"', profile)

    def test_bar_icon_seams_use_equal_optical_spacing(self):
        widget_paths = [
            "lacuna.claude-usage/Widget.qml",
            "lacuna.codex-usage/Widget.qml",
            "lacuna.system-stats/Widget.qml",
            "lacuna.temperature/Widget.qml",
            "lacuna.theme/Widget.qml",
            "lacuna.wallpaper/Widget.qml",
            "lacuna.weather/Widget.qml",
        ]

        for path in widget_paths:
            qml = read(path)
            self.assertIn("contentSpacing: 5", qml, path)
            self.assertNotRegex(qml, r"width: .*IconSize \+ 4", path)
            self.assertNotRegex(qml, r"width: .*iconSize \+ 4", path)

        self.assertIn("readonly property int horizontalPadding: 0", read("lacuna.system-stats/Widget.qml"))
        self.assertIn("readonly property int horizontalPadding: vertical ? 0 : 2", read("lacuna.temperature/Widget.qml"))

        mpris = read("lacuna.mpris/components/LacunaMprisButton.qml")
        self.assertIn("property int contentSpacing: 5", mpris)
        self.assertIn("property int contentHorizontalPadding: 10", mpris)
        self.assertNotIn("width: root.iconSize + 4", mpris)

    def test_resource_widgets_match_bar_style_and_keep_graphs_out_of_bar(self):
        stats = read("lacuna.system-stats/Widget.qml")
        temperature = read("lacuna.temperature/Widget.qml")

        for qml in [stats, temperature]:
            self.assertIn("readonly property int topbarIconSize: barSize >= 30 ? 15 : 13", qml)
            self.assertIn("readonly property int topbarTextSize: barSize <= 26 ? 12 : 13", qml)
            self.assertIn("readonly property int contentSpacing: 5", qml)
            self.assertIn("font.weight: Font.DemiBold", qml)
            self.assertIn("horizontalAlignment: Text.AlignLeft", qml)

        stat_button = stats[stats.index("component StatButton:") :]
        self.assertNotIn("Canvas {", stats)
        self.assertNotIn("id: trendCanvas", stats)
        self.assertNotIn("property var history: []", stat_button)
        self.assertIn('metricFontMetrics.advanceWidth("100%")', stats)
        self.assertIn("width: content.parent.topbarIconSize", stats)
        self.assertIn("width: content.parent.valueWidth", stats)
        self.assertIn("colorizationColor: content.parent.accent", stats)
        self.assertIn("color: content.parent.foreground", stats)
        self.assertIn("visible: content.parent.showLabel", stats)

        self.assertIn('temperatureFontMetrics.advanceWidth("000 F")', temperature)
        self.assertIn("width: root.topbarIconSize", temperature)
        self.assertIn("width: root.temperatureValueWidth", temperature)
        self.assertIn("colorizationColor: root.statusColor", temperature)
        self.assertIn("color: root.foreground", temperature)
        self.assertIn("visible: root.showText", temperature)

        self.assertIn("Canvas {", read("lacuna.system-stats/TelemetryFlyout.qml"))
        self.assertIn("Canvas {", read("lacuna.temperature/ThermalFlyout.qml"))

    def test_usage_widgets_suppress_absent_5h_window_and_restore_rotation(self):
        for plugin in ["lacuna.codex-usage", "lacuna.claude-usage"]:
            qml = read(f"{plugin}/Widget.qml")
            self.assertIn("property int displayCycle: 0", qml)
            self.assertIn("readonly property bool sessionReady: loadedOnce && sessionAvailable", qml)
            self.assertIn("readonly property bool weeklyReady: loadedOnce && showWeekly && weekActive", qml)
            self.assertIn("readonly property int activeMode: !sessionReady && weeklyReady", qml)
            self.assertIn("readonly property string primaryText: activeMode === 1 ? weekPrimary : sessionPrimary", qml)
            self.assertIn("running: root.sessionReady && root.weeklyReady && !root.flyoutOpen && !mouseArea.containsMouse", qml)
            self.assertIn("BarCycleText {", qml)
            self.assertIn("text: root.primaryText", qml)
            self.assertIn("weekActive = payload.weekActive === true", qml)
            self.assertIn("weekUsedPercent = boundedPercent(payload.weekUsedPercent", qml)
            self.assertIn("sessionAvailable:", qml)

        codex_flyout = read("lacuna.codex-usage/CodexUsageFlyout.qml")
        self.assertIn("property bool sessionAvailable: false", codex_flyout)
        self.assertIn('text: "5h limit"', codex_flyout)
        self.assertIn('text: "Weekly limit"', codex_flyout)
        self.assertIn(': "suppressed"', codex_flyout)
        self.assertIn("opacity: root.sessionAvailable ? 1 : 0.38", codex_flyout)

        claude_flyout = read("lacuna.claude-usage/ClaudeUsageFlyout.qml")
        self.assertIn("property bool sessionAvailable: true", claude_flyout)
        self.assertIn("property bool available: true", claude_flyout)
        self.assertIn(': "suppressed"', claude_flyout)
        self.assertIn("opacity: available ? 1 : 0.38", claude_flyout)

    def test_usage_flyout_shadows_reserve_bottom_render_padding(self):
        for path in [
            "lacuna.claude-usage/ClaudeUsageFlyout.qml",
            "lacuna.codex-usage/CodexUsageFlyout.qml",
            "lacuna.theme/ThemeFlyout.qml",
            "lacuna.wallpaper/WallpaperFlyout.qml",
        ]:
            qml = read(path)
            self.assertIn("readonly property int shadowBottomMargin", qml)
            self.assertIn("implicitHeight: surface.fullHeight + shadowTopMargin + shadowBottomMargin", qml)
            self.assertIn("id: shadowSource", qml)
            self.assertIn("height: root.implicitHeight", qml)
            self.assertIn("source: shadowSource", qml)
            self.assertNotIn("autoPaddingEnabled: true", qml)

    def test_wallpaper_widget_schema_exposes_real_enabled_setting(self):
        manifest = read_json("lacuna.wallpaper/manifest.json")
        schema = {entry["key"]: entry for entry in manifest["barWidget"]["schema"]}
        qml = read("lacuna.wallpaper/Widget.qml")

        self.assertEqual("boolean", schema["enabled"]["type"])
        self.assertIs(schema["enabled"]["defaultValue"], True)
        self.assertEqual(22, schema["maxTextLength"]["defaultValue"])
        self.assertNotIn("showIcon", schema)
        self.assertEqual("semantic", schema["colorProfile"]["defaultValue"])
        self.assertIn('readonly property bool widgetEnabled: boolSetting("enabled", true)', qml)
        self.assertIn("visible: widgetEnabled", qml)

    def test_lacuna_state_and_shell_settings_are_split_plugins(self):
        state_manifest = read_json("lacuna.state/manifest.json")
        shell_settings_manifest = read_json("lacuna.shell-settings/manifest.json")
        menu = read("lacuna.menu/menu/MenuWindow.qml")
        settings = read("lacuna.menu/services/LacunaSettings.qml")
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")

        self.assertIn("service", state_manifest["kinds"])
        self.assertEqual("Service.qml", state_manifest["entryPoints"]["service"])
        self.assertIn("service", shell_settings_manifest["kinds"])
        self.assertIn("panel", shell_settings_manifest["kinds"])
        self.assertEqual("Service.qml", shell_settings_manifest["entryPoints"]["service"])
        self.assertEqual("Panel.qml", shell_settings_manifest["entryPoints"]["panel"])
        self.assertIn('ensureService("lacuna.state")', menu)
        self.assertIn('ensureService("lacuna.shell-settings")', menu)
        self.assertIn('panelController.openFlyout("shellSettings")', menu)
        self.assertIn("OmarchyShellSettingsWindow", menu)
        self.assertIn("shellSettingsSurface", menu)
        self.assertIn("property int settingsPanelWidth: Math.round(sizeMix(560, 500))", menu)
        self.assertIn("return MenuFlyoutGeometry.boundedGeometry({", menu)
        shell_section = menu.split("function openShellSettingsSection", 1)[1].split("function requestFlyoutFocus", 1)[0]
        self.assertNotIn("sidebarState.expand()", shell_section)
        self.assertIn("function flyoutGeometryFor(screen, kind, connectorWidthOverride)", menu)
        self.assertIn('surface: "flyout"', settings)
        self.assertIn('"Omarchy Settings Link"', settings_window)
        self.assertIn('"set-shell-settings-surface-"', settings_window)

    def test_lacuna_settings_only_exposes_lacuna_owned_settings(self):
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")

        self.assertIn('"Lacuna Tools"', settings_window)
        self.assertIn('"Lacuna Maintenance"', settings_window)
        self.assertIn('"Reload App Catalog"', settings_window)
        self.assertIn('"Open Plugin Source"', settings_window)
        self.assertIn('"Skip Restart Confirmation"', settings_window)
        self.assertIn('"Omarchy Settings Link"', settings_window)

        self.assertNotIn('"Runtime", hint: "Diagnostics and maintenance"', settings_window)
        self.assertNotIn('"Shortcuts for the host theme workflow."', settings_window)
        self.assertNotIn('"Theme", "Switch Omarchy theme"', settings_window)
        self.assertNotIn('"Background", "Switch the active theme background"', settings_window)
        self.assertNotIn('"Wallpaper Catalog"', settings_window)
        self.assertNotIn('"Restart Shell"', settings_window)
        self.assertNotIn('"Open Log"', settings_window)

        for path in [
            "lacuna.menu/settings/OmarchyShellSettingsWindow.qml",
            "lacuna.shell-settings/settings/OmarchyShellSettingsWindow.qml",
        ]:
            qml = read(path)
            self.assertIn('"Theme", "Switch Omarchy theme"', qml, path)
            self.assertIn('"Background", "Switch active theme background"', qml, path)
            self.assertIn('"Wallpaper Catalog"', qml, path)
            self.assertIn('"Restart Shell"', qml, path)
            self.assertIn('"Open Log"', qml, path)

    def test_media_player_provider_settings_expose_jellyfin_v1(self):
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")
        registry = read("lacuna.menu/menu/MenuRegistry.qml")
        menu = read("lacuna.menu/menu/MenuWindow.qml")
        text_row = read("lacuna.menu/settings/SettingsTextRow.qml")

        for snippet in [
            '{ id: "media-player", icon: "music", label: "Media Player"',
            'navRow("music", "Media Player", "Provider search and playback sources", "media-player"',
            'section("Providers", "Configure media sources used by search and playback.", "lacuna")',
            '"toggle-jellyfin-provider"',
            '"Server URL"',
            '"set-jellyfin-server-url-"',
            '"API Key"',
            '"set-jellyfin-api-key-"',
            '"Preferred Audio Language"',
            '"set-jellyfin-audio-language-"',
            "SettingsTextRow",
            "entry.control === \"text\"",
        ]:
            self.assertIn(snippet, settings_window)

        for snippet in [
            "property var mediaProviders",
            "function jellyfinProviderSettings()",
            "readonly property bool jellyfinProviderEnabled",
            "readonly property string jellyfinServerUrl",
            "readonly property string jellyfinApiKey",
            "readonly property string jellyfinAudioLanguage",
            "function jellyfinProviderHint()",
            "function jellyfinAudioLanguageHint()",
            "Jellyfin results are merged into Media Player search",
        ]:
            self.assertIn(snippet, registry)

        for snippet in [
            "readonly property var mediaProvidersSettings",
            "function cleanJellyfinServerUrl(value)",
            "function ensureMediaProviders(settings)",
            "function setJellyfinProviderEnabled(enabled)",
            "function setJellyfinServerUrl(value)",
            "function setJellyfinApiKey(value)",
            "function setJellyfinAudioLanguage(value)",
            "setJellyfinProviderEnabled(desiredChecked(entry, !registry.jellyfinProviderEnabled))",
            'entry.action.indexOf("set-jellyfin-server-url-") === 0',
            'entry.action.indexOf("set-jellyfin-api-key-") === 0',
            'entry.action.indexOf("set-jellyfin-audio-language-") === 0',
            "mediaProviders: root.mediaProvidersSettings",
        ]:
            self.assertIn(snippet, menu)

        self.assertIn("signal accepted(string value)", text_row)
        self.assertIn("property bool masked: false", text_row)
        self.assertIn("echoMode: root.masked ? TextInput.Password : TextInput.Normal", text_row)
        self.assertIn("onEditingFinished: root.accepted(text)", text_row)

    def test_lacuna_settings_windows_use_parent_control_state(self):
        settings_window = read("lacuna.menu/settings/SettingsWindow.qml")
        menu_shell_settings = read("lacuna.menu/settings/OmarchyShellSettingsWindow.qml")
        standalone_shell_settings = read("lacuna.shell-settings/settings/OmarchyShellSettingsWindow.qml")

        for qml in [settings_window, menu_shell_settings, standalone_shell_settings]:
            self.assertIn("property var controlOverrides", qml)
            self.assertIn("function currentControlChecked", qml)
            self.assertIn("function currentControlValue", qml)
            self.assertIn("function activateControl", qml)
            self.assertIn("checked: root.currentControlChecked(parent.entry)", qml)
            self.assertIn("optionValue: root.currentControlValue(parent.entry)", qml)
            self.assertIn("onTriggered: root.activateControl(parent.entry)", qml)

        self.assertIn("function entryWithDesiredChecked", settings_window)
        self.assertIn("next.desiredChecked = desiredChecked === true", settings_window)
        self.assertIn("function desiredChecked", read("lacuna.menu/menu/MenuWindow.qml"))

    def test_omarchy_shell_settings_sections_have_distinct_models(self):
        for path in [
            "lacuna.menu/settings/OmarchyShellSettingsWindow.qml",
            "lacuna.shell-settings/settings/OmarchyShellSettingsWindow.qml",
        ]:
            qml = read(path)

            self.assertIn("property var currentItems", qml, path)
            self.assertIn("property string modelError", qml, path)
            self.assertIn("function refreshItems()", qml, path)
            self.assertIn("try {", qml, path)
            self.assertIn('"Section Error"', qml, path)
            self.assertIn("function registryCommand(name)", qml, path)
            self.assertIn("model: root.currentItems", qml, path)
            self.assertIn('if (sectionId === "notifications")', qml, path)
            self.assertIn('if (sectionId === "plugins") return pluginItems()', qml, path)
            self.assertIn("typeof root.registry.installedShellPluginRows", qml, path)
            self.assertIn('commandRow("refresh", "Restart Shell"', qml, path)
            self.assertIn("showLabels: true", qml, path)

        menu = read("lacuna.menu/menu/MenuWindow.qml")
        self.assertIn("property var registryRef: root.menuRegistryRef", menu)
        self.assertIn("registry: shellSettingsPanel.registryRef", menu)
        self.assertIn("onCurrentSectionChanged: root.shellSettingsSection = currentSection", menu)

        for path in [
            "lacuna.menu/settings/SettingsRail.qml",
            "lacuna.shell-settings/settings/SettingsRail.qml",
        ]:
            qml = read(path)

            self.assertIn("signal sectionSelected(string sectionId)", qml, path)
            self.assertIn("readonly property string sectionId", qml, path)
            self.assertIn("property bool showLabels", qml, path)
            self.assertIn("text: modelData.label || \"\"", qml, path)
            self.assertIn("onTriggered: root.sectionSelected(parent.sectionId)", qml, path)

    def test_lacuna_bar_routes_shell_commands_to_live_flyout_widgets(self):
        bar = read("lacuna.bar/Bar.qml")
        adapter = read("lacuna.bar/OmarchyBarAdapter.qml")
        implementation = read("lacuna.bar/OmarchyBar.qml")

        for snippet in [
            "function summonBarWidget(pluginId)",
            "function hideBarWidget(pluginId)",
            "function isBarWidgetOpen(pluginId)",
        ]:
            self.assertIn(snippet, bar)
            self.assertIn(snippet, adapter)
            self.assertIn(snippet, implementation)
        self.assertIn("function findPanelWidget(pluginId)", implementation)
        self.assertIn("var chosen = BarModel.pickDrawnSlot(candidates)", implementation)
        self.assertIn("active: visible && entries.length > 0", implementation)
        self.assertIn("readonly property real panelIndicatorExtent", implementation)
        self.assertIn("function moduleWidgets(pluginId)", implementation)
        self.assertIn("function moduleWidgets(pluginId) { return root.moduleWidgets(pluginId) }", implementation)
        self.assertIn("items.push(slot.activeItem)", implementation)
        self.assertNotIn('"omarchy-bar-text-color"', implementation)
        self.assertNotIn('"omarchy-shell-bar-text-color"', implementation)

    def test_simple_bar_helpers_match_canonical_vendored_templates(self):
        color_template = read("shared/qml/simple-bar/ColorProfile.qml")
        motion_template = read("shared/qml/simple-bar/MotionTokens.qml")
        simple_color_plugins = [
            "lacuna.audio",
            "lacuna.bluetooth",
            "lacuna.bar-size-pill",
            "lacuna.clock",
            "lacuna.claude-usage",
            "lacuna.codex-usage",
            "lacuna.compact-pill",
            "lacuna.idle-inhibitor",
            "lacuna.indicators",
            "lacuna.nightlight",
            "lacuna.menu-button",
            "lacuna.network",
            "lacuna.notifications",
            "lacuna.power",
            "lacuna.script-pill",
            "lacuna.screen-recording",
            "lacuna.system-stats",
            "lacuna.system-update",
            "lacuna.temperature",
            "lacuna.voxtype",
            "lacuna.weather",
        ]
        simple_motion_plugins = simple_color_plugins + [
            "lacuna.theme",
            "lacuna.wallpaper",
        ]

        for plugin in simple_color_plugins:
            self.assertEqual(read(f"{plugin}/ColorProfile.qml"), color_template, plugin)
        for plugin in simple_motion_plugins:
            self.assertEqual(read(f"{plugin}/MotionTokens.qml"), motion_template, plugin)
