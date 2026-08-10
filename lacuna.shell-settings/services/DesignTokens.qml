import QtQuick

QtObject {
  id: root

  property string designStyle: "lacuna"
  property bool compact: false
  property real compactProgress: compact ? 1 : 0
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color accent: "#88c0d0"
  // Negative keeps the design-style fallback for standalone consumers.
  // Shell hosts inject the one resolved theme/user exposed-corner radius.
  property real exposedCornerRadius: -1

  readonly property string style: normalize(designStyle)
  readonly property bool lacuna: style === "lacuna"
  readonly property bool omarchy: style === "omarchy"
  readonly property bool material: style === "material"

  readonly property int radius: lacuna ? 0 : omarchy ? 2 : 8
  readonly property int panelRadius: exposedCornerRadius >= 0
    ? Math.max(0, Math.round(exposedCornerRadius))
    : (lacuna ? 14 : omarchy ? 2 : 12)
  readonly property int controlRadius: lacuna ? 0 : omarchy ? 2 : 9
  readonly property int borderWidth: lacuna ? 0 : 1
  readonly property real surfaceOpacity: lacuna ? 1.0 : omarchy ? 0.98 : 0.96
  readonly property real surfaceBorderOpacity: lacuna ? 0.0 : omarchy ? 0.24 : 0.16
  readonly property real hoverOpacity: lacuna ? 0.06 : omarchy ? 0.08 : 0.10
  readonly property real activeOpacity: lacuna ? 0.11 : omarchy ? 0.12 : 0.16
  readonly property int itemHeight: Math.round(mix(material ? 40 : 38, material ? 34 : 32))
  readonly property int primaryItemHeight: Math.round(mix(material ? 42 : 40, material ? 36 : 34))
  readonly property int featuredItemHeight: Math.round(mix(material ? 50 : 48, material ? 44 : 42))
  readonly property int compactItemHeight: Math.round(mix(32, 28))
  readonly property string headerTreatment: lacuna ? "accent-line" : omarchy ? "body-border" : "tonal"
  readonly property string switchStyle: lacuna ? "compact" : omarchy ? "native" : "material"
  readonly property string railTreatment: lacuna ? "linework" : omarchy ? "contained" : "tonal"
  readonly property string tooltipTreatment: lacuna ? "accent-strip" : omarchy ? "bordered" : "tonal"
  readonly property bool decorativeLinework: lacuna
  readonly property bool accentStrips: lacuna
  readonly property bool gappedDividers: lacuna
  readonly property int dividerGap: gappedDividers ? 22 : 0
  readonly property int contentInset: Math.round(mix(material ? 16 : 14, material ? 12 : 10))
  readonly property int topInset: Math.round(mix(material ? 10 : 8, material ? 8 : 6))
  readonly property int bottomInset: Math.round(mix(material ? 18 : 16, material ? 12 : 10))
  readonly property int itemSpacing: Math.round(mix(material ? 5 : 2, material ? 4 : 2))
  readonly property int sectionSpacing: Math.round(mix(material ? 11 : 10, material ? 8 : 7))
  readonly property int railSpacing: Math.round(mix(material ? 8 : 7, material ? 6 : 5))
  readonly property int railLeftInset: Math.round(mix(material ? 10 : 9, material ? 8 : 7))
  readonly property int railRightInset: railLeftInset
  // Connector molding shares the same resolved radius as exposed corners.
  readonly property int joinRadius: panelRadius
  readonly property int connectorOverlap: lacuna ? Math.round(mix(33, 25)) : omarchy ? 0 : Math.round(mix(28, 20))
  readonly property color borderColor: Qt.rgba(foreground.r, foreground.g, foreground.b, surfaceBorderOpacity)
  readonly property color stateColor: material ? foreground : accent

  function normalize(value) {
    var styleName = String(value || "").toLowerCase()
    if (styleName === "lacuna") return "lacuna"
    if (styleName === "omarchy" || styleName === "material") return styleName
    return "lacuna"
  }

  function mix(fullValue, compactValue) {
    var p = Math.max(0, Math.min(1, compactProgress))
    return Number(fullValue) + (Number(compactValue) - Number(fullValue)) * p
  }
}
