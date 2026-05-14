import QtQuick
import "../../components"
import ".."

Column {
  id: root

  signal activated(var entry)

  required property var menuState
  required property var registry
  property bool open: true
  property string currentView: menuState.currentView
  property real viewProgress: 1
  property string themeTitle: ""
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color accent: "#88c0d0"
  property color shellAccent: "#88c0d0"
  property color sessionAccent: "#ebcb8b"
  property color dangerAccent: "#bf616a"
  property color navAccent: "#d8dee9"
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  property string bodyFontFamily: "GeistMono Nerd Font"
  property string itemFontFamily: itemFont.name !== "" ? itemFont.name : "Tektur"
  property int iconRailWidth: 32

  function toneAccent(tone) {
    if (tone === "lacuna") return root.accent
    if (tone === "shell") return root.shellAccent
    if (tone === "session") return root.sessionAccent
    if (tone === "danger") return root.dangerAccent
    return root.navAccent
  }

  spacing: 10
  onCurrentViewChanged: {
    viewProgress = 0
    viewReveal.restart()
  }

  opacity: open ? viewProgress : 0
  x: open ? -6 * (1 - viewProgress) : -6

  Behavior on opacity {
    LacunaAnim { motion: "normal" }
  }

  NumberAnimation {
    id: viewReveal

    target: root
    property: "viewProgress"
    to: 1
    duration: 180
    easing.type: Easing.OutCubic
  }

  FontLoader {
    id: itemFont

    source: "../../assets/fonts/Tektur-SemiBold.ttf"
  }

  MenuHeader {
    width: parent.width
    title: root.registry.titleFor(root.menuState.currentView)
    subtitle: (root.themeTitle !== "" ? root.themeTitle : "Quickshell") + " / utility sidebar"
    canGoBack: root.menuState.stack.length > 1
    foreground: root.foreground
    muted: root.muted
    accent: root.accent
    danger: root.dangerAccent
    bodyFontFamily: root.bodyFontFamily
    onBackRequested: root.menuState.back()
    onCloseRequested: root.menuState.close()
  }

  LacunaRect {
    width: parent.width
    height: 1
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
  }

  Column {
    width: parent.width
    spacing: 2

    Repeater {
      model: root.registry.itemsFor(root.menuState.currentView)

      Loader {
        property var entry: modelData

        width: parent.width
        sourceComponent: entry.kind === "header" ? sectionDelegate : itemDelegate
      }
    }

    Component {
      id: sectionDelegate

      MenuSection {
        width: parent ? parent.width : 0
        title: parent.entry.label
        foreground: root.foreground
        muted: root.muted
        accent: root.toneAccent(parent.entry.tone)
        band: parent.entry.tone === "lacuna" || parent.entry.tone === "danger"
        fontFamily: root.bodyFontFamily
      }
    }

    Component {
      id: itemDelegate

      LacunaMenuItem {
        width: parent.width
        kind: parent.entry.kind
        icon: parent.entry.icon
        label: parent.entry.label
        hint: parent.entry.hint
        hasChildren: parent.entry.view !== ""
        foreground: root.foreground
        muted: root.muted
        accent: root.accent
        tone: parent.entry.tone
        toneAccent: root.toneAccent(parent.entry.tone)
        priority: parent.entry.priority
        layout: parent.entry.layout
        danger: parent.entry.danger
        background: root.background
        fontFamily: root.bodyFontFamily
        labelFontFamily: root.itemFontFamily
        iconRailWidth: root.iconRailWidth
        onTriggered: root.activated(parent.entry)
      }
    }
  }
}
