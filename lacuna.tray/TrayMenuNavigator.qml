import QtQuick

QtObject {
  id: root

  property Component openerComponent: null
  property var openerOwner: root
  property var rootChildren: []
  property var rootIdentity: null
  property int settleDuration: 250
  property var levels: []
  property bool teardownActive: false

  readonly property int depth: levels.length
  readonly property string currentTitle: depth > 0 ? levels[depth - 1].title : ""
  readonly property var currentChildren: depth > 0 ? levels[depth - 1].opener.children : rootChildren
  readonly property bool inputSettling: settleTimer.running

  property Timer settleTimer: Timer {
    interval: root.settleDuration
    repeat: false
  }

  function inputAllowed() {
    return !inputSettling
  }

  function beginSettling() {
    settleTimer.restart()
  }

  function levelIndex(opener) {
    for (var i = 0; i < levels.length; i++) {
      if (levels[i].opener === opener) return i
    }
    return -1
  }

  function destroyLevels(openers) {
    teardownActive = true
    for (var i = openers.length - 1; i >= 0; i--) {
      if (openers[i] && openers[i].opener) openers[i].opener.destroy()
    }
    teardownActive = false
  }

  function handleMenuChanged(opener) {
    if (teardownActive || !opener || opener.menu !== null) return
    var index = levelIndex(opener)
    if (index < 0) return

    var removed = levels.slice(index)
    levels = levels.slice(0, index)
    destroyLevels(removed)
    beginSettling()
  }

  function enterSubmenu(entry, title) {
    if (!inputAllowed() || !openerComponent || !entry) return false
    var opener = openerComponent.createObject(openerOwner || root, { menu: entry })
    if (!opener) return false

    opener.menuChanged.connect(function() {
      root.handleMenuChanged(opener)
    })
    if (opener.menu === null) {
      opener.destroy()
      return false
    }

    var next = levels.slice()
    next.push({ opener: opener, title: String(title || "") })
    levels = next
    beginSettling()
    return true
  }

  function leaveSubmenu() {
    if (!inputAllowed() || levels.length === 0) return false
    var removed = levels.slice(levels.length - 1)
    levels = levels.slice(0, levels.length - 1)
    destroyLevels(removed)
    beginSettling()
    return true
  }

  function reset() {
    settleTimer.stop()
    var removed = levels
    levels = []
    destroyLevels(removed)
  }

  function resetForRoot(nextRoot) {
    reset()
    rootIdentity = nextRoot || null
  }
}
