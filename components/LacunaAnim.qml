import QtQuick

NumberAnimation {
  property string motion: "normal"

  readonly property int animFast: 120
  readonly property int animNormal: 180
  readonly property int animSlow: 260

  duration: motion === "fast" ? animFast : motion === "slow" ? animSlow : animNormal
  easing.type: Easing.OutCubic
}
