import QtQuick

LacunaButton {
  id: root

  property bool shortMode: false
  property bool wide: false
  property color moduleAccent: "#88c0d0"
  property date now: new Date()

  minButtonWidth: wide ? 120 : 32
  accent: moduleAccent
  text: shortMode ? formatShortTime(now) : formatLongTime(now)
  tooltip: calendarTooltip(now)

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  function formatShortTime(value) {
    var hours = value.getHours()
    var minutes = String(value.getMinutes()).padStart(2, "0")
    var hour12 = hours % 12 || 12
    return hour12 + ":" + minutes
  }

  function formatLongTime(value) {
    return weekdayName(value) + " " + value.getDate() + ordinalSuffix(value.getDate()) + " " + formatShortTime(value) + " " + (value.getHours() >= 12 ? "PM" : "AM")
  }

  function weekdayName(value) {
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][value.getDay()]
  }

  function monthName(value) {
    return ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][value.getMonth()]
  }

  function ordinalSuffix(day) {
    if (day === 1 || day === 21 || day === 31) return "st"
    if (day === 2 || day === 22) return "nd"
    if (day === 3 || day === 23) return "rd"
    return "th"
  }

  function calendarTooltip(value) {
    var year = value.getFullYear()
    var month = value.getMonth()
    var today = value.getDate()
    var firstDay = new Date(year, month, 1).getDay()
    var days = new Date(year, month + 1, 0).getDate()
    var rows = []
    var day = 1

    for (var row = 0; row < 6 && day <= days; row++) {
      var cells = []
      for (var col = 0; col < 7; col++) {
        if ((row === 0 && col < firstDay) || day > days) {
          cells.push("&nbsp;&nbsp;")
        } else {
          var text = day < 10 ? "&nbsp;" + day : String(day)
          cells.push(day === today ? "<font color='#c0daf6'><b>" + text + "</b></font>" : text)
          day += 1
        }
      }
      rows.push(cells.join("&nbsp;"))
    }

    return "<b><font color='#c9a554'>" + monthName(value) + " " + year + "</font></b><br/><br/><font color='#ab9191'>Su&nbsp;Mo&nbsp;Tu&nbsp;We&nbsp;Th&nbsp;Fr&nbsp;Sa</font><br/>" + rows.join("<br/>")
  }
}
