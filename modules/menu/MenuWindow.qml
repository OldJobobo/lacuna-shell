import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../services"
import "../../components"

Scope {
  id: root

  required property var menuState
  property string lacunaPath: Quickshell.env("LACUNA_PATH") || Quickshell.env("PWD")
  property var sharedCompactState: null
  readonly property var compactState: sharedCompactState || localCompactState
  property color foreground: menuTheme.foreground
  property color background: menuTheme.background
  property color panelColor: menuTheme.panel
  property color accent: menuTheme.color("color14")
  property color shellAccent: menuTheme.color("color6")
  property color sessionAccent: menuTheme.color("color11")
  property color dangerAccent: menuTheme.color("color9")
  property color navAccent: menuTheme.soft
  property color muted: menuTheme.muted
  property string version: ""
  property bool compact: compactState.compact
  property int fullPanelWidth: compact ? 270 : 310
  property int railButtonWidth: barHeight
  property int railPanelWidth: railButtonWidth + (compact ? 6 : 10)
  property int panelWidth: sidebarState.collapsed ? railPanelWidth : fullPanelWidth
  property int barHeight: compact ? 24 : 32
  property int joinRadius: compact ? 14 : 18
  property int connectorOverlap: compact ? 25 : 33
  property int bodyRightInset: joinRadius
  property int surfaceRightInset: bodyRightInset
  // In exclusive mode the compositor pushes our window down by the bar's
  // exclusive zone, so the surface top IS the bar bottom (offset 0).
  // In overlay mode we sit on top of the bar from y=0, so the bar bottom
  // is barHeight pixels into our surface.
  property int barBottomY: sidebarState.exclusive ? 0 : barHeight
  property bool panelVisible: menuState.open

  function viewToneAccent() {
    if (menuState.currentView === "system") return root.dangerAccent
    if (menuState.currentView === "lacuna-shell") return root.shellAccent
    if (menuState.currentView === "lacuna" || menuState.currentView === "lacuna-preferences") return root.accent
    return root.accent
  }

  function activate(entry) {
    if (!entry || entry.kind === "header") return

    if (entry.action === "toggle-sidebar-mode") {
      sidebarState.toggle()
      return
    }

    if (entry.action === "toggle-sidebar-rail") {
      sidebarState.toggleCollapsed()
      return
    }

    if (entry.action === "toggle-bar-density") {
      compactState.toggle()
      return
    }

    if (entry.action === "reload-apps") {
      appCatalog.reload()
      return
    }

    if (entry.view) {
      if (sidebarState.collapsed) sidebarState.expand()
      menuState.push(entry.view)
      return
    }

    if (entry.command) {
      commands.run(menuState.saveCommand() + "; " + entry.command)
    }
  }

  Component.onCompleted: versionFile.reload()

  CompactState {
    id: localCompactState
  }

  SidebarState {
    id: sidebarState
  }

  AppCatalog {
    id: appCatalog
  }

  Theme {
    id: menuTheme
  }

  FileView {
    id: versionFile

    path: root.lacunaPath + "/VERSION"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var raw = text().trim()
      root.version = raw === "" ? "" : "v" + raw.replace(/^v/, "")
    }
    onFileChanged: reload()
  }

  MenuRegistry {
    id: registry
    sidebarExclusive: sidebarState.exclusive
    sidebarCollapsed: sidebarState.collapsed
    appCatalog: appCatalog
  }

  Connections {
    target: root.menuState
    function onOpenChanged() {
      if (root.menuState.open) {
        root.panelVisible = true
      } else {
        hideTimer.restart()
      }
    }
  }

  Timer {
    id: hideTimer
    interval: 190
    repeat: false
    onTriggered: if (!root.menuState.open) root.panelVisible = false
  }

  CommandRunner {
    id: commands
  }

  PanelWindow {
    id: menuWindow

    visible: root.panelVisible
    color: "transparent"
    implicitWidth: root.panelWidth + root.surfaceRightInset
    exclusiveZone: sidebarState.exclusive && root.menuState.open ? root.panelWidth : 0
    exclusionMode: sidebarState.exclusive ? ExclusionMode.Normal : ExclusionMode.Ignore
    WlrLayershell.namespace: "lacuna-menu"
    WlrLayershell.layer: sidebarState.exclusive ? WlrLayer.Top : WlrLayer.Overlay

    anchors {
      top: true
      bottom: true
      left: true
    }

    MenuSurface {
      id: surface

      anchors.top: parent.top
      anchors.bottom: parent.bottom
      panelWidth: root.panelWidth
      open: root.menuState.open
      barHeight: root.barHeight
      barBottomY: root.barBottomY
      joinRadius: root.joinRadius
      connectorOverlap: root.connectorOverlap
      bodyRightInset: root.surfaceRightInset
      panelColor: root.panelColor

      MenuContent {
        visible: !sidebarState.collapsed
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 10 : 14
        anchors.rightMargin: root.compact ? 10 : 14
        anchors.topMargin: root.barBottomY + (root.compact ? 6 : 8)
        anchors.bottomMargin: root.compact ? 10 : 16
        compact: root.compact
        open: root.menuState.open
        menuState: root.menuState
        registry: registry
        version: root.version
        themeTitle: menuTheme.themeTitle
        foreground: root.foreground
        background: root.background
        accent: root.accent
        shellAccent: root.shellAccent
        sessionAccent: root.sessionAccent
        dangerAccent: root.dangerAccent
        navAccent: root.navAccent
        muted: root.muted
        iconRailWidth: root.barHeight
        onActivated: function(entry) {
          root.activate(entry)
        }
      }

      MenuRail {
        visible: sidebarState.collapsed
        anchors.top: parent.top
        anchors.topMargin: root.barBottomY + (root.compact ? 6 : 10)
        anchors.horizontalCenter: parent.horizontalCenter
        compact: root.compact
        open: root.menuState.open
        menuState: root.menuState
        registry: registry
        foreground: root.foreground
        panelWindow: menuWindow
        panelColor: root.panelColor
        accent: root.accent
        shellAccent: root.shellAccent
        sessionAccent: root.sessionAccent
        dangerAccent: root.dangerAccent
        navAccent: root.navAccent
        muted: root.muted
        railWidth: root.railButtonWidth
        onActivated: function(entry) {
          root.activate(entry)
        }
      }
    }
  }
}
