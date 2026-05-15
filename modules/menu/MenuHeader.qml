import QtQuick
import "../../components"

Item {
  id: root

  signal backRequested()
  signal closeRequested()

  property string title: "Lacuna Menu"
  property string version: ""
  property string subtitle: "Quickshell / control aperture"
  property bool canGoBack: false
  property color foreground: "#d8dee9"
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  property color accent: "#88c0d0"
  property color danger: "#bf616a"
  property string bodyFontFamily: "GeistMono Nerd Font"
  property bool compact: false
  readonly property bool hasSubtitle: subtitle !== ""
  readonly property bool hasVersion: version !== ""
  readonly property int controlSize: compact ? 24 : tokens.controlSmall

  width: parent ? parent.width : implicitWidth
  height: compact ? (hasSubtitle || hasVersion ? 50 : 36) : (hasSubtitle || hasVersion ? 62 : 46)

  FontLoader {
    id: headingFont

    source: "../../assets/fonts/Tektur-SemiBold.ttf"
  }

  LacunaText {
    id: headerGlyph

    anchors.left: parent.left
    anchors.top: parent.top
    anchors.topMargin: 2
    width: root.controlSize
    height: root.controlSize
    text: "󱥸"
    color: root.accent
    fontFamily: root.bodyFontFamily
    font.pixelSize: root.compact ? 17 : tokens.textGlyph
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  Column {
    anchors.left: headerGlyph.right
    anchors.leftMargin: root.compact ? tokens.spaceSmall : tokens.spaceNormal
    anchors.right: headerControls.left
    anchors.rightMargin: tokens.spaceLarge
    anchors.top: parent.top
    anchors.topMargin: root.compact ? 3 : 5
    spacing: root.hasSubtitle ? tokens.spaceTiny : 0

    LacunaText {
      width: parent.width
      text: root.title
      color: root.foreground
      fontFamily: headingFont.name !== "" ? headingFont.name : "Tektur"
      font.pixelSize: root.compact ? 14 : tokens.textTitle
      font.weight: Font.DemiBold
      font.letterSpacing: root.compact ? 0.6 : 0.9
    }

    LacunaText {
      visible: root.hasSubtitle
      width: parent.width
      text: root.subtitle
      color: root.muted
      fontFamily: root.bodyFontFamily
      font.pixelSize: root.compact ? 8 : tokens.textHint
    }
  }

  LacunaText {
    visible: root.hasVersion
    anchors.right: parent.right
    anchors.rightMargin: 2
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.compact ? 7 : 9
    text: root.version
    color: root.muted
    fontFamily: root.bodyFontFamily
    font.pixelSize: root.compact ? 9 : 10
    font.weight: Font.DemiBold
  }

  Row {
    id: headerControls

    anchors.right: parent.right
    anchors.top: parent.top
    width: backButton.width + closeButton.width + spacing
    height: root.controlSize
    spacing: root.compact ? 2 : tokens.spaceSmall

    LacunaIconButton {
      id: backButton

      visible: root.canGoBack
      width: visible ? implicitWidth : 0
      icon: "‹"
      foreground: root.foreground
      muted: root.muted
      accent: root.accent
      hoverAccent: root.accent
      fontFamily: root.bodyFontFamily
      buttonSize: root.controlSize
      iconSize: root.compact ? 16 : 18
      disabled: !visible
      onTriggered: root.backRequested()
    }

    LacunaIconButton {
      id: closeButton

      icon: "×"
      foreground: root.foreground
      muted: root.muted
      accent: root.danger
      hoverAccent: root.danger
      fontFamily: root.bodyFontFamily
      buttonSize: root.controlSize
      iconSize: root.compact ? 13 : tokens.textIcon
      onTriggered: root.closeRequested()
    }
  }

  LacunaRect {
    anchors.left: headerGlyph.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: root.accent
    opacity: 0.24
  }

  LacunaRect {
    anchors.left: headerGlyph.left
    anchors.bottom: parent.bottom
    width: root.compact ? 26 : 34
    height: 2
    color: root.accent
    opacity: 0.75
  }

  LacunaTokens {
    id: tokens
  }
}
