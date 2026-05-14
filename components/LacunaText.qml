import QtQuick

Text {
  id: root

  property bool accentText: false
  property string fontFamily: tokens.monoFont

  color: "#d8dee9"
  font.family: fontFamily
  font.pixelSize: tokens.textNormal
  renderType: Text.NativeRendering
  textFormat: Text.PlainText
  elide: Text.ElideRight
  maximumLineCount: 1

  Behavior on color {
    LacunaColorAnim {}
  }

  LacunaTokens {
    id: tokens
  }
}
