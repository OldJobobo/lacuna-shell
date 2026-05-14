import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services"
import "../../components"

Scope {
  id: root

  required property var menuState
  property color foreground: menuTheme.foreground
  property color background: menuTheme.background
  property color panelColor: menuTheme.panel
  property color accent: menuTheme.color("color14")
  property color shellAccent: menuTheme.color("color6")
  property color sessionAccent: menuTheme.color("color11")
  property color dangerAccent: menuTheme.color("color9")
  property color navAccent: menuTheme.soft
  property color muted: menuTheme.muted
  property int fullPanelWidth: 340
  property int railButtonWidth: barHeight
  property int railPanelWidth: railButtonWidth + 10
  property int panelWidth: sidebarState.collapsed ? railPanelWidth : fullPanelWidth
  property int barHeight: menuCompactState.compact ? 24 : 32
  property int joinRadius: 18
  property int connectorOverlap: 33
  property int bodyRightInset: joinRadius
  property int surfaceRightInset: sidebarState.collapsed ? 0 : bodyRightInset
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

    if (entry.view) {
      if (sidebarState.collapsed) sidebarState.expand()
      menuState.push(entry.view)
      return
    }

    if (entry.command) {
      commands.run(entry.command)
    }
  }

  CompactState {
    id: menuCompactState
  }

  SidebarState {
    id: sidebarState
  }

  Theme {
    id: menuTheme
  }

  MenuRegistry {
    id: registry
    sidebarExclusive: sidebarState.exclusive
    sidebarCollapsed: sidebarState.collapsed
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
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: root.barBottomY + 8
        anchors.bottomMargin: 16
        open: root.menuState.open
        menuState: root.menuState
        registry: registry
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
        anchors.topMargin: root.barBottomY + 10
        anchors.horizontalCenter: parent.horizontalCenter
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
