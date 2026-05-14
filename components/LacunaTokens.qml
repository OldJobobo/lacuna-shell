import QtQuick

QtObject {
  id: root

  readonly property string monoFont: "BlexMono Nerd Font Propo"

  readonly property int animFast: 120
  readonly property int animNormal: 180
  readonly property int animSlow: 260
  readonly property int animPulse: 900
  readonly property int animSweep: 2400
  readonly property int animColor: 160

  readonly property int spaceTiny: 2
  readonly property int spaceSmall: 4
  readonly property int spaceNormal: 8
  readonly property int spaceLarge: 10
  readonly property int spaceXLarge: 14

  readonly property int textHint: 9
  readonly property int textSmall: 10
  readonly property int textNormal: 12
  readonly property int textPrimary: 13
  readonly property int textTitle: 16
  readonly property int textIcon: 15
  readonly property int textGlyph: 20

  readonly property int controlSmall: 30
  readonly property int controlNormal: 34
}
