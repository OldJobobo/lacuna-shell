import os
import tempfile
import unittest
from pathlib import Path

from qml_harness import HAVE_SESSION, parse_behave, qml_url, require_no_qml_errors, run_quickshell


@unittest.skipUnless(HAVE_SESSION, "needs a quickshell binary and a Wayland session")
class QmlLacunaSettingsBehaviorTests(unittest.TestCase):
    def test_sidebar_autohide_normalization_clamps_and_preserves_unknown_fields(self):
        for relative in ["lacuna.state/Service.qml", "lacuna.menu/services/LacunaSettings.qml"]:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url(relative)}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    var service = component.createObject(this)
    var normalized = service.normalize({{
      version: 2,
      sidebar: {{
        defaultMode: "rail",
        autoHide: {{
          enabled: true,
          revealMode: "invalid",
          hotZoneWidth: 99,
          revealDelayMs: -20,
          hideDelayMs: 99999,
          futureAutoHide: {{ keep: true }}
        }}
      }}
    }})
    console.log("BEHAVE " + JSON.stringify(normalized.sidebar.autoHide))
    finish.start()
  }}
  Timer {{ id: finish; interval: 20; onTriggered: Qt.quit() }}
}}
"""
            output = run_quickshell(qml, timeout=8)
            require_no_qml_errors(output)
            row = parse_behave(output)[-1]
            self.assertTrue(row["enabled"], output[-2000:])
            self.assertNotIn("revealMode", row, output[-2000:])
            self.assertEqual(8, row["hotZoneWidth"], output[-2000:])
            self.assertEqual(0, row["revealDelayMs"], output[-2000:])
            self.assertEqual(3000, row["hideDelayMs"], output[-2000:])
            self.assertEqual({"keep": True}, row["futureAutoHide"], output[-2000:])

    def test_canonical_and_vendored_normalizers_preserve_future_nested_json(self):
        for service_path in (
            "lacuna.state/Service.qml",
            "lacuna.menu/services/LacunaSettings.qml",
        ):
            with self.subTest(service_path=service_path), tempfile.TemporaryDirectory() as cfg:
                qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var service: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url(service_path)}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    service = component.createObject(root)
    var value = service.normalize({{
      version: 99,
      futureTop: {{ keep: true }},
      geometry: {{ cornerMode: "custom", cornerRadius: 9, futureGeometry: {{ keep: true }} }},
      barPresentation: {{ portraitSplit: false, futurePresentation: {{ keep: true }} }},
      barSizeSnapshot: {{ themeName: "future", sizeHorizontal: 30, sizeVertical: 32, futureSnapshot: [1, 2] }},
      sizeTransition: {{ holdCompact: true, holdUntil: -9, futureTransition: {{ keep: true }} }},
      preferredApps: {{ files: "", editor: "editor.desktop", futureRole: {{ id: "future.desktop" }} }},
      power: {{ instantReboot: true, futurePower: ["keep"] }},
      shellSettings: {{ mode: "panel", futureShell: {{ keep: true }} }},
      mediaProviders: {{
        youtube: {{ enabled: true, cookiesFromBrowser: "firefox", cookiesFile: "/canonical/auth", futureAuth: {{ source: "canonical" }} }},
        youtubeMusic: {{ enabled: false, authPath: "/legacy/auth", cookiesFromBrowser: "chromium", cookiesFile: "/legacy/collision", futureAuth: {{ source: "legacy" }}, futureLegacy: ["keep"] }},
        jellyfin: {{ enabled: true, preferredAudioLanguage: "ja", apiKey: "do-not-log", futurePlayback: ["keep"] }},
        futureProvider: {{ enabled: true, endpoint: "future" }}
      }},
      mediaPlayer: {{ presentationMode: "invalid", videoQuality: "invalid", providerFilter: "invalid", futurePlayer: {{ keep: true }} }},
      sidebar: {{ defaultMode: "rail", cornerPieces: false, futureSidebar: {{ keep: true }} }},
      backgroundEffects: {{
        opacity: 3,
        activeEffects: ["filmGrain"],
        futureEffects: ["keep"],
        effects: {{
          filmGrain: {{ enabled: true, intensity: -2, futureTuning: {{ keep: true }} }},
          futureEffect: {{ enabled: true, futureEffectValue: [1, 2, 3] }}
        }}
      }},
      backgroundVignette: {{ enabled: true, intensity: 4, futureVignette: {{ keep: true }} }},
      frame: {{ mode: "fullframe", radius: 0, futureFrame: {{ keep: true }} }},
      designStyles: {{
        lacuna: {{
          futurePreset: true,
          bar: {{
            centerAnchor: "lacuna.clock",
            futureBar: {{ keep: true }},
            layout: {{ left: [], center: [], right: [], futureLayout: ["keep"] }}
          }}
        }},
        futureStyle: {{ futureStyleValue: {{ keep: true }} }}
      }}
    }})
    var aliasOnly = service.normalize({{
      mediaProviders: {{ youtubeMusic: {{ enabled: true, authPath: "/legacy/only", futureLegacyOnly: {{ keep: true }} }} }}
    }})
    console.log("BEHAVE " + JSON.stringify({{
      version: value.version,
      top: value.futureTop.keep === true,
      geometry: value.geometry.cornerMode === "custom"
        && value.geometry.cornerRadius === 9
        && value.geometry.futureGeometry.keep === true,
      presentation: value.barPresentation.futurePresentation.keep === true,
      snapshot: value.barSizeSnapshot.futureSnapshot.length === 2,
      transition: value.sizeTransition.futureTransition.keep === true,
      futureRole: value.preferredApps.futureRole.id === "future.desktop",
      power: value.futurePower === undefined && value.power.futurePower[0] === "keep",
      shell: value.shellSettings.futureShell.keep === true,
      youtube: value.mediaProviders.youtube.futureAuth.source === "canonical",
      youtubeLegacy: value.mediaProviders.youtube.futureLegacy[0] === "keep",
      youtubeCanonicalKnownWins: value.mediaProviders.youtube.cookiesFile === "/canonical/auth"
        && value.mediaProviders.youtube.cookiesFromBrowser === "firefox",
      youtubeAliasKnown: aliasOnly.mediaProviders.youtube.enabled === true
        && aliasOnly.mediaProviders.youtube.cookiesFile === "/legacy/only",
      youtubeAliasUnknown: aliasOnly.mediaProviders.youtube.futureLegacyOnly.keep === true,
      youtubeAliasRemoved: value.mediaProviders.youtubeMusic === undefined
        && aliasOnly.mediaProviders.youtubeMusic === undefined,
      jellyfin: value.mediaProviders.jellyfin.futurePlayback[0] === "keep",
      provider: value.mediaProviders.futureProvider.endpoint === "future",
      player: value.mediaPlayer.futurePlayer.keep === true,
      sidebar: value.sidebar.futureSidebar.keep === true,
      effects: value.backgroundEffects.futureEffects[0] === "keep",
      effectConfig: value.backgroundEffects.effects.filmGrain.futureTuning.keep === true,
      futureEffect: value.backgroundEffects.effects.futureEffect.futureEffectValue.length === 3,
      vignette: value.backgroundVignette.futureVignette.keep === true,
      frame: value.frame.futureFrame.keep === true,
      preset: value.designStyles.lacuna.futurePreset === true,
      bar: value.designStyles.lacuna.bar.futureBar.keep === true,
      layout: value.designStyles.lacuna.bar.layout.futureLayout[0] === "keep",
      style: value.designStyles.futureStyle.futureStyleValue.keep === true,
      normalized: value.mediaPlayer.presentationMode === "auto"
        && value.mediaPlayer.videoQuality === "adaptive"
        && value.mediaPlayer.providerFilter === "all"
        && value.mediaProviders.jellyfin.preferredAudioLanguage === "Japanese"
        && value.backgroundEffects.opacity === 1
        && value.backgroundEffects.effects.filmGrain.intensity === 0
        && value.backgroundVignette.intensity === 1
        && value.sizeTransition.holdUntil === 0
        && value.preferredApps.files === "system"
        && value.geometry.cornerMode === "custom"
        && value.geometry.cornerRadius === 9
        && value.frame.radius === 9
    }}))
    finish.restart()
  }}

  Timer {{
    id: finish
    interval: 20
    onTriggered: Qt.quit()
  }}
}}
"""
                output = run_quickshell(qml, config_home=Path(cfg), timeout=8)

            require_no_qml_errors(output)
            row = parse_behave(output)[-1]
            self.assertEqual(3, row.pop("version"), output[-2000:])
            self.assertTrue(all(row.values()), output[-2000:])

    def test_schema_v3_corner_migration_matrix_and_alias(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.state/Service.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    var service = component.createObject(root)
    function result(value) {{
      var normalized = service.normalize(value)
      return {{
        version: normalized.version,
        connector: normalized.sidebar.connectorPieces,
        alias: normalized.sidebar.cornerPieces,
        molding: normalized.frame.moldingPieces,
        roundedAlias: normalized.frame.roundedContentCorners,
        radius: normalized.frame.radius,
        cornerMode: normalized.geometry.cornerMode,
        cornerRadius: normalized.geometry.cornerRadius
      }}
    }}
    console.log("BEHAVE " + JSON.stringify({{
      missing: result({{}}),
      legacyTrue: result({{ version: 1, sidebar: {{ cornerPieces: true }} }}),
      legacyFalse: result({{ version: 1, sidebar: {{ cornerPieces: false }} }}),
      interimRoundedFalse: result({{ version: 2, frame: {{ roundedContentCorners: false }} }}),
      newWins: result({{
        version: 2,
        sidebar: {{ connectorPieces: true, cornerPieces: false }},
        frame: {{ moldingPieces: true, roundedContentCorners: false, radius: 0 }}
      }}),
      split: result({{
        version: 2,
        sidebar: {{ connectorPieces: false, cornerPieces: true }},
        frame: {{ moldingPieces: false, radius: 0 }}
      }}),
      legacyCustom: result({{ version: 2, frame: {{ radius: 9 }} }}),
      geometryWins: result({{
        version: 3,
        geometry: {{ cornerMode: "custom", cornerRadius: 21 }},
        frame: {{ radius: 0 }}
      }})
    }}))
    finish.restart()
  }}
  Timer {{ id: finish; interval: 20; onTriggered: Qt.quit() }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        row = parse_behave(output)[-1]
        for name in ("missing", "legacyTrue"):
            self.assertEqual(
                {"version": 3, "connector": True, "alias": True, "molding": True, "roundedAlias": True, "radius": 14, "cornerMode": "theme", "cornerRadius": 14},
                row[name],
            )
        self.assertEqual(
            {"version": 3, "connector": False, "alias": False, "molding": False, "roundedAlias": False, "radius": 14, "cornerMode": "theme", "cornerRadius": 14},
            row["legacyFalse"],
        )
        self.assertEqual(
            {"version": 3, "connector": True, "alias": True, "molding": False, "roundedAlias": False, "radius": 14, "cornerMode": "theme", "cornerRadius": 14},
            row["interimRoundedFalse"],
        )
        self.assertEqual(
            {"version": 3, "connector": True, "alias": True, "molding": True, "roundedAlias": True, "radius": 0, "cornerMode": "square", "cornerRadius": 14},
            row["newWins"],
        )
        self.assertEqual(
            {"version": 3, "connector": False, "alias": False, "molding": False, "roundedAlias": False, "radius": 0, "cornerMode": "square", "cornerRadius": 14},
            row["split"],
        )
        self.assertEqual(
            {"version": 3, "connector": True, "alias": True, "molding": True, "roundedAlias": True, "radius": 9, "cornerMode": "custom", "cornerRadius": 9},
            row["legacyCustom"],
        )
        self.assertEqual(
            {"version": 3, "connector": True, "alias": True, "molding": True, "roundedAlias": True, "radius": 21, "cornerMode": "custom", "cornerRadius": 21},
            row["geometryWins"],
        )

    def test_design_tokens_accept_the_resolved_exposed_corner_radius(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var tokens: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/services/DesignTokens.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    tokens = component.createObject(root, {{ designStyle: "lacuna" }})
    settle.start()
  }}

  Timer {{
    id: settle
    interval: 20
    onTriggered: {{
      var fallback = tokens.panelRadius
      var fallbackJoin = tokens.joinRadius
      tokens.exposedCornerRadius = 0
      var square = tokens.panelRadius
      var squareJoin = tokens.joinRadius
      tokens.exposedCornerRadius = 9.6
      console.log("BEHAVE " + JSON.stringify({{
        fallback: fallback,
        fallbackJoin: fallbackJoin,
        square: square,
        squareJoin: squareJoin,
        rounded: tokens.panelRadius,
        roundedJoin: tokens.joinRadius
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        self.assertEqual(
            {
                "fallback": 14,
                "fallbackJoin": 14,
                "square": 0,
                "squareJoin": 0,
                "rounded": 10,
                "roundedJoin": 10,
            },
            parse_behave(output)[-1],
        )

    def test_confirmed_persistence_converges_to_latest_rapid_save(self):
        for service_path in (
            "lacuna.state/Service.qml",
            "lacuna.menu/services/LacunaSettings.qml",
        ):
            with self.subTest(service_path=service_path), tempfile.TemporaryDirectory() as cfg:
                qml = f'''
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var service: null
  property bool issued: false
  property bool noopIssued: false

  function issueSaves() {{
    if (issued || !service || !service.hasLoaded) return
    issued = true
    var first = service.normalize(service.data)
    first.designStyle = "omarchy"
    service.save(first)
    var second = service.normalize(service.data)
    second.designStyle = "material"
    service.save(second)
    var latest = service.normalize(service.data)
    latest.designStyle = "lacuna"
    latest.futureRapidSave = {{ winner: 3 }}
    service.save(latest)
    settle.start()
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url(service_path)}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    service = component.createObject(root)
    Qt.callLater(root.issueSaves)
  }}

  Connections {{
    target: root.service
    function onLoaded() {{ Qt.callLater(root.issueSaves) }}
  }}

  Timer {{
    id: settle
    interval: 20
    repeat: true
    property int attempts: 0
    onTriggered: {{
      attempts += 1
      if (service.persistenceState === "saved"
          && service.confirmedSaveRevision === service.requestedSaveRevision
          && service.requestedSaveRevision >= 3
          && !noopIssued) {{
        noopIssued = true
        service.save(service.data)
      }} else if (noopIssued
          && service.persistenceState === "saved"
          && service.confirmedSaveRevision === service.requestedSaveRevision
          && service.requestedSaveRevision >= 4) {{
        console.log("BEHAVE " + JSON.stringify({{
          state: service.persistenceState,
          requested: service.requestedSaveRevision,
          confirmed: service.confirmedSaveRevision,
          queued: service.queuedSaveRevision,
          winner: service.data.futureRapidSave.winner
        }}))
        Qt.quit()
      }} else if (attempts > 250) {{
        console.log("BEHAVE_ERR persistence timeout " + service.persistenceState
          + " requested=" + service.requestedSaveRevision
          + " confirmed=" + service.confirmedSaveRevision)
        Qt.quit()
      }}
    }}
  }}
}}
'''
                output = run_quickshell(qml, config_home=Path(cfg), timeout=10)
                require_no_qml_errors(output)
                row = parse_behave(output)[-1]
                self.assertEqual("saved", row["state"], output[-2000:])
                self.assertEqual(row["requested"], row["confirmed"])
                self.assertEqual(0, row["queued"])
                self.assertEqual(3, row["winner"])
                persisted = Path(cfg, "omarchy/lacuna/settings.json").read_text(encoding="utf-8")
                self.assertIn('"winner": 3', persisted)

    @unittest.skipIf(os.geteuid() == 0, "root bypasses the permission failure this test exercises")
    def test_failed_save_is_visible_and_retryable(self):
        with tempfile.TemporaryDirectory() as cfg:
            settings_dir = Path(cfg, "omarchy/lacuna")
            settings_dir.mkdir(parents=True)
            settings_dir.chmod(0o500)
            qml = f'''
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {{
  id: root
  property var service: null
  property bool issued: false
  property bool observedFailure: false

  function issueSave() {{
    if (issued || !service || !service.hasLoaded) return
    issued = true
    var next = service.normalize(service.data)
    next.futureRetry = {{ persisted: true }}
    service.save(next)
    watch.start()
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.state/Service.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    service = component.createObject(root)
    Qt.callLater(root.issueSave)
  }}

  Connections {{
    target: root.service
    function onLoaded() {{ Qt.callLater(root.issueSave) }}
  }}

  Process {{
    id: unlock
    command: ["chmod", "700", "{settings_dir.as_posix()}"]
    onExited: function(exitCode) {{
      if (exitCode !== 0) {{
        console.log("BEHAVE_ERR chmod failed")
        Qt.quit()
        return
      }}
      service.retryPersistence()
    }}
  }}

  Timer {{
    id: watch
    interval: 20
    repeat: true
    property int attempts: 0
    onTriggered: {{
      attempts += 1
      if (!observedFailure && service.persistenceState === "failed") {{
        observedFailure = service.retrySavePayload !== "" && service.persistenceError !== ""
        unlock.running = true
      }} else if (observedFailure && service.persistenceState === "saved") {{
        console.log("BEHAVE " + JSON.stringify({{
          failed: observedFailure,
          state: service.persistenceState,
          requested: service.requestedSaveRevision,
          confirmed: service.confirmedSaveRevision,
          retryAvailable: service.retrySavePayload !== ""
        }}))
        Qt.quit()
      }} else if (attempts > 300) {{
        console.log("BEHAVE_ERR retry timeout " + service.persistenceState + " " + service.persistenceError)
        Qt.quit()
      }}
    }}
  }}
}}
'''
            try:
                output = run_quickshell(qml, config_home=Path(cfg), timeout=12)
            finally:
                settings_dir.chmod(0o700)
            require_no_qml_errors(output)
            row = parse_behave(output)[-1]
            self.assertTrue(row["failed"], output[-2000:])
            self.assertEqual("saved", row["state"])
            self.assertEqual(row["requested"], row["confirmed"])
            self.assertFalse(row["retryAvailable"])
            self.assertIn('"persisted": true', Path(settings_dir, "settings.json").read_text(encoding="utf-8"))

    def test_sidebar_save_merges_owned_fields_without_dropping_future_fields(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var sidebar: null

  QtObject {{
    id: settings
    property bool hasLoaded: true
    property var data: ({{ sidebar: {{ futureSidebar: {{ keep: true }} }} }})
    property var saved: null
    function normalize(value) {{
      return {{
        version: 2,
        sidebar: {{
          defaultMode: "off",
          collapsed: false,
          exclusive: true,
          connectorPieces: true,
          cornerPieces: true,
          monitorPolicy: "pinned",
          monitorNames: ["DP-1"],
          autoHide: {{
            enabled: false,
            hotZoneWidth: 3,
            revealDelayMs: 120,
            hideDelayMs: 350,
            futureAutoHide: {{ keep: true }}
          }},
          futureSidebar: {{ keep: true }}
        }}
      }}
    }}
    function save(value, touchedQuickLaunch, touchedSidebar) {{ saved = value }}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/services/SidebarState.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    sidebar = component.createObject(root, {{ settingsService: settings }})
    sidebar.defaultMode = "rail"
    sidebar.collapsed = true
    sidebar.exclusive = false
    sidebar.autoHideEnabled = true
    sidebar.autoHideHotZoneWidth = 4
    sidebar.autoHideRevealDelayMs = 140
    sidebar.autoHideHideDelayMs = 420
    sidebar.save()
    console.log("BEHAVE " + JSON.stringify({{
      futurePreserved: settings.saved.sidebar.futureSidebar.keep === true,
      defaultMode: settings.saved.sidebar.defaultMode,
      collapsed: sidebar.collapsed,
      exclusive: settings.saved.sidebar.exclusive,
      connectorPieces: settings.saved.sidebar.connectorPieces,
      cornerAlias: settings.saved.sidebar.cornerPieces,
      monitorPolicy: settings.saved.sidebar.monitorPolicy,
      monitorName: settings.saved.sidebar.monitorNames[0],
      autoHide: settings.saved.sidebar.autoHide,
      savedCollapsed: settings.saved.sidebar.collapsed
    }}))
    finish.restart()
  }}

  Timer {{
    id: finish
    interval: 20
    onTriggered: Qt.quit()
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        row = parse_behave(output)[-1]
        self.assertTrue(row["futurePreserved"], output[-2000:])
        self.assertEqual("rail", row["defaultMode"])
        self.assertTrue(row["collapsed"])
        self.assertFalse(row["exclusive"])
        self.assertTrue(row["connectorPieces"])
        self.assertTrue(row["cornerAlias"])
        self.assertEqual("pinned", row["monitorPolicy"])
        self.assertEqual("DP-1", row["monitorName"])
        self.assertTrue(row["autoHide"]["enabled"])
        self.assertNotIn("revealMode", row["autoHide"])
        self.assertEqual(4, row["autoHide"]["hotZoneWidth"])
        self.assertEqual({"keep": True}, row["autoHide"]["futureAutoHide"])
        self.assertTrue(row["savedCollapsed"])

    def test_sidebar_autohide_enable_disable_preserves_existing_runtime_presentation(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var sidebar: null

  QtObject {{
    id: settings
    property bool hasLoaded: true
    property var data: ({{ sidebar: {{ defaultMode: "full", collapsed: false, autoHide: {{ enabled: false }} }} }})
    property var saved: null
    function normalize(value) {{
      return {{ version: 2, sidebar: {{
        defaultMode: "full", collapsed: false, exclusive: true,
        connectorPieces: true, cornerPieces: true, monitorPolicy: "auto", monitorNames: [],
        autoHide: {{ enabled: false, hotZoneWidth: 3, revealDelayMs: 120, hideDelayMs: 350 }}
      }} }}
    }}
    function save(value) {{ saved = value }}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/services/SidebarState.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    sidebar = component.createObject(root, {{ settingsService: settings }})
    sidebar.setDisplay("rail")
    sidebar.setAutoHideEnabled(true)
    var savedWhileEnabled = settings.saved.sidebar.collapsed
    var visibleModeWhileEnabled = sidebar.collapsed
    sidebar.setAutoHideEnabled(false)
    console.log("BEHAVE " + JSON.stringify({{
      savedWhileEnabled: savedWhileEnabled,
      visibleModeWhileEnabled: visibleModeWhileEnabled,
      modeAfterDisable: sidebar.collapsed,
      savedCollapsed: settings.saved.sidebar.collapsed,
      enabled: settings.saved.sidebar.autoHide.enabled,
      hasRevealMode: settings.saved.sidebar.autoHide.revealMode !== undefined
    }}))
    finish.start()
  }}

  Timer {{ id: finish; interval: 20; onTriggered: Qt.quit() }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        row = parse_behave(output)[-1]
        self.assertTrue(row["savedWhileEnabled"], output[-2000:])
        self.assertTrue(row["visibleModeWhileEnabled"], output[-2000:])
        self.assertTrue(row["modeAfterDisable"], output[-2000:])
        self.assertTrue(row["savedCollapsed"], output[-2000:])
        self.assertFalse(row["enabled"], output[-2000:])
        self.assertFalse(row["hasRevealMode"], output[-2000:])


if __name__ == "__main__":
    unittest.main()
