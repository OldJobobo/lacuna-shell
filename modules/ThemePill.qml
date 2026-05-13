import QtQuick

LacunaButton {
  id: root

  required property var themeService
  property color moduleAccent: "#88c0d0"
  property int maxTextLength: 32

  minButtonWidth: 32
  accent: moduleAccent
  text: clipped("󰸉 " + themeService.themeTitle)
  tooltip: themeTooltip()
  visible: themeService.themeTitle.length > 0

  function clipped(value) {
    if (!value) return ""
    if (value.length <= maxTextLength) return value
    return value.slice(0, Math.max(1, maxTextLength - 1)) + "…"
  }

  function swatchRow(start, end) {
    var row = ""
    for (var i = start; i <= end; i++) {
      row += "<font color='" + themeService.rawColor("color" + i) + "' size='+2'>■</font> "
    }
    return row
  }

  function themeTooltip() {
    return "<b>" + themeService.themeTitle + "</b><br/>Current Omarchy theme<br/><br/><b>Palette</b><br/>"
      + swatchRow(0, 7) + "<br/>"
      + swatchRow(8, 15) + "<br/><br/>"
      + "<font color='" + themeService.rawColor("color0") + "'>■</font> base00  "
      + "<font color='" + themeService.rawColor("color7") + "'>■</font> base07  "
      + "<font color='" + themeService.rawColor("color11") + "'>■</font> accent"
  }
}
