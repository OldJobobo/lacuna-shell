import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "../services"

Scope {
  id: root

  required property var menuState
  property color foreground: menuTheme.foreground
  property color background: menuTheme.background
  property color panelColor: menuTheme.panel
  property color accent: menuTheme.color("color14")
  property color muted: menuTheme.muted
  property string lacunaPath: Quickshell.env("LACUNA_PATH") || Quickshell.env("PWD")
  property int panelWidth: 340
  property int shadowExtent: 14
  readonly property int joinRadius: 8
  readonly property int bodyRightInset: joinRadius
  property bool panelVisible: menuState.open

  Theme {
    id: menuTheme
  }

  function item(kind, icon, label, hint, view, command) {
    return {
      kind: kind,
      icon: icon,
      label: label,
      hint: hint,
      view: view,
      command: command
    }
  }

  function titleFor(view) {
    if (view === "lacuna") return "Lacuna"
    if (view === "lacuna-shell") return "Shell Settings"
    if (view === "lacuna-preferences") return "Preferences"
    if (view === "system") return "System"
    return "Lacuna Menu"
  }

  function itemsFor(view) {
    if (view === "lacuna") {
      return [
        item("header", "", "Shell", "", "", ""),
        item("item", "󰒓", "Shell settings", "Panel behavior and runtime actions", "lacuna-shell", ""),
        item("item", "", "Preferences", "Local Lacuna preference groups", "lacuna-preferences", ""),
        item("item", "󰑐", "Restart Lacuna", "Reload this Quickshell config", "", "quickshell kill -p " + root.lacunaPath + "/shell.qml; setsid " + root.lacunaPath + "/run.sh >/tmp/lacuna-quickshell.log 2>&1 &"),
        item("item", "", "Open source", "Edit the Lacuna project", "", "xdg-terminal-exec --app-id=org.omarchy.terminal bash -lc 'cd " + root.lacunaPath + " && ${EDITOR:-nvim} .'")
      ]
    }

    if (view === "lacuna-shell") {
      return [
        item("header", "", "Runtime", "", "", ""),
        item("item", "󰑐", "Restart shell", "Restart Lacuna Quickshell", "", "quickshell kill -p " + root.lacunaPath + "/shell.qml; setsid " + root.lacunaPath + "/run.sh >/tmp/lacuna-quickshell.log 2>&1 &"),
        item("item", "󰌾", "Open log", "View the current Lacuna log", "", "xdg-terminal-exec --app-id=org.omarchy.terminal less /tmp/lacuna-quickshell.log"),
        item("item", "", "Edit shell", "Open shell.qml", "", "omarchy-launch-editor " + root.lacunaPath + "/shell.qml")
      ]
    }

    if (view === "lacuna-preferences") {
      return [
        item("header", "", "Preferences", "", "", ""),
        item("item", "󰙵", "Bar density", "Coming next: compact and spacing controls", "", ""),
        item("item", "󰔡", "Tooltip style", "Coming next: surface and seam controls", "", ""),
        item("item", "󰀻", "Module visibility", "Coming next: per-module toggles", "", "")
      ]
    }

    if (view === "system") {
      return [
        item("header", "", "Session", "", "", ""),
        item("item", "󱄄", "Screensaver", "Start screensaver now", "", "omarchy-launch-screensaver force"),
        item("item", "", "Lock", "Lock session", "", "omarchy-system-lock"),
        item("item", "󰍃", "Logout", "End session", "", "omarchy-system-logout"),
        item("header", "", "Power", "", "", ""),
        item("item", "󰜉", "Restart", "Reboot machine", "", "omarchy-system-reboot"),
        item("item", "󰐥", "Shutdown", "Power off machine", "", "omarchy-system-shutdown")
      ]
    }

    return [
      item("header", "", "Go", "", "", ""),
      item("item", "󰀻", "Apps", "Open Walker app launcher", "", "walker -p 'Launch…'"),
      item("item", "󰧑", "Learn", "Keybindings and docs", "", "omarchy menu learn"),
      item("item", "󱓞", "Trigger", "Reminder, capture, share, hardware", "", "omarchy menu trigger"),
      item("item", "", "Style", "Theme, background, font, corners", "", "omarchy menu style"),
      item("item", "", "Setup", "System and default app setup", "", "omarchy menu setup"),
      item("item", "󰉉", "Install", "Packages, apps, services", "", "omarchy menu install"),
      item("item", "󰭌", "Remove", "Remove packages and apps", "", "omarchy menu remove"),
      item("item", "", "Update", "Updates and restarts", "", "omarchy menu update"),
      item("item", "", "About", "About Omarchy", "", "omarchy menu about"),
      item("item", "", "System", "Lock, logout, restart, shutdown", "system", ""),
      item("header", "", "Lacuna", "", "", ""),
      item("item", "◌", "Lacuna", "Shell settings and preferences", "lacuna", "")
    ]
  }

  function activate(entry) {
    if (!entry || entry.kind === "header") return

    if (entry.view) {
      menuState.push(entry.view)
      return
    }

    if (entry.command) {
      menuState.close()
      commands.run(entry.command)
    }
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
    implicitWidth: root.panelWidth + root.shadowExtent
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lacuna-menu"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
      top: true
      bottom: true
      left: true
    }

    Rectangle {
      id: surface

      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: root.panelWidth
      x: root.menuState.open ? 0 : -root.panelWidth
      color: "transparent"
      clip: true

      Shape {
        anchors.fill: parent
        asynchronous: true
        containsMode: Shape.FillContains

        ShapePath {
          fillColor: root.panelColor
          strokeWidth: 0
          startX: 0
          startY: 0

          PathLine { x: surface.width; y: 0 }
          PathQuad {
            x: surface.width - root.joinRadius
            y: root.joinRadius
            controlX: surface.width - root.joinRadius
            controlY: 0
          }
          PathLine { x: surface.width - root.joinRadius; y: surface.height }
          PathLine { x: 0; y: surface.height }
          PathLine { x: 0; y: 0 }
        }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: function(mouse) {
          mouse.accepted = true
        }
      }

      Behavior on x {
        NumberAnimation {
          duration: 180
          easing.type: Easing.OutCubic
        }
      }

      Column {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14 + root.bodyRightInset
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 10

        Row {
          width: parent.width
          height: 34
          spacing: 10

          LacunaMenuItem {
            visible: root.menuState.stack.length > 1
            width: visible ? 36 : 0
            height: 34
            icon: "‹"
            label: ""
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            background: root.background
            onTriggered: root.menuState.back()
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - closeButton.width - (root.menuState.stack.length > 1 ? 46 : 0)
            text: root.titleFor(root.menuState.currentView)
            color: root.foreground
            font.family: "BlexMono Nerd Font Propo"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }

          LacunaMenuItem {
            id: closeButton
            width: 36
            height: 34
            icon: "×"
            label: ""
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            background: root.background
            onTriggered: root.menuState.close()
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        }

        Column {
          width: parent.width
          spacing: 2

          Repeater {
            model: root.itemsFor(root.menuState.currentView)

            LacunaMenuItem {
              width: parent.width
              kind: modelData.kind
              icon: modelData.icon
              label: modelData.label
              hint: modelData.hint
              hasChildren: modelData.view !== ""
              foreground: root.foreground
              muted: root.muted
              accent: root.accent
              background: root.background
              onTriggered: root.activate(modelData)
            }
          }
        }
      }
    }

    Rectangle {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: root.shadowExtent
      x: surface.x + surface.width - root.bodyRightInset
      visible: root.menuState.open
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.28) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
      }
    }
  }
}
