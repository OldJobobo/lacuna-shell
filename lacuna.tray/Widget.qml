import Quickshell
import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "lacuna.tray"

  property bool drawerHovered: false
  property bool trayMenuOpen: false
  property bool managePopupOpen: false
  property var activeTrayItem: null
  property var activeTrayAnchor: null
  readonly property bool expanded: drawerHovered || trayMenuOpen
  readonly property bool fullscreenSuppressed: bar && bar.fullscreenSuppressed === true
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var pinnedIds: Array.isArray(settings.pinned) ? settings.pinned : []
  readonly property var hiddenIds: Array.isArray(settings.hidden) ? settings.hidden : []
  readonly property var pinnedItems: bucket("pinned")
  readonly property var drawerItems: bucket("drawer")
  readonly property var allItems: bucket("all")
  readonly property int drawerCount: drawerItems.length
  readonly property int trayItemExtent: Style.space(16)
  readonly property int topbarIconSize: root.barSize >= 30 ? 15 : 13
  readonly property int trayItemGap: Style.space(17)
  readonly property int trayJoinGap: Style.space(6)
  readonly property int drawerExtent: drawerCount > 0 ? drawerCount * trayItemExtent + (drawerCount - 1) * trayItemGap : 0
  // Match Waybar's group/tray-expander drawer transition-duration.
  readonly property int animationDuration: 600
  property real revealProgress: expanded ? 1 : 0
  readonly property real revealExtent: drawerExtent * revealProgress

  // QsMenuEntry.display() requires QApplication mode, which Omarchy's shell
  // intentionally does not use. The navigator retains one QsMenuOpener per
  // active menu level and owns settling, invalidation, and teardown ordering.
  property var trayMenuFlickItem: null
  readonly property int submenuDepth: trayMenuNavigator.depth
  readonly property string currentTitle: trayMenuNavigator.currentTitle
  readonly property var currentChildren: trayMenuNavigator.currentChildren
  readonly property bool trayMenuSettling: trayMenuNavigator.inputSettling

  Component {
    id: submenuOpenerComponent
    QsMenuOpener {}
  }

  TrayMenuNavigator {
    id: trayMenuNavigator
    openerComponent: submenuOpenerComponent
    openerOwner: root
    rootChildren: trayMenuOpener.children
  }

  function resetTrayMenu() {
    if (trayMenuFlickItem) trayMenuFlickItem.contentY = 0
    trayMenuNavigator.reset()
  }

  function enterSubmenu(entry, title) {
    if (!trayMenuNavigator.inputAllowed()) return false
    if (trayMenuFlickItem) trayMenuFlickItem.contentY = 0
    return trayMenuNavigator.enterSubmenu(entry, title)
  }

  function leaveSubmenu() {
    if (!trayMenuNavigator.inputAllowed()) return false
    if (trayMenuFlickItem) trayMenuFlickItem.contentY = 0
    return trayMenuNavigator.leaveSubmenu()
  }

  function close() {
    managePopupOpen = false
    trayMenuOpen = false
    if (trayMenuFlickItem) trayMenuFlickItem.contentY = 0
    trayMenuNavigator.resetForRoot(null)
    activeTrayItem = null
    activeTrayAnchor = null
  }

  onFullscreenSuppressedChanged: if (fullscreenSuppressed) close()

  function openTrayMenu(item, anchorItem, mouse) {
    if (!item || !anchorItem) return
    if (root.bar && typeof root.bar.activateInteraction === "function") root.bar.activateInteraction(anchorItem, root.moduleName)
    if (root.bar) root.bar.hideTooltip(anchorItem)

    if (!item.menu) {
      var anchorWindow = anchorItem.QsWindow.window
      var localX = Math.round(mouse ? mouse.x : anchorItem.width / 2)
      var localY = Math.round(mouse ? mouse.y : anchorItem.height / 2)
      var point = anchorWindow.contentItem.mapFromItem(anchorItem, localX, localY)
      root.close()
      item.display(anchorWindow, point.x, point.y)
      return
    }

    // Publish an empty nested hierarchy before changing the root opener menu.
    if (trayMenuFlickItem) trayMenuFlickItem.contentY = 0
    trayMenuNavigator.resetForRoot(item)
    activeTrayItem = item
    activeTrayAnchor = anchorItem
    trayMenuOpen = true
  }

  function trayIconSource(icon) {
    var value = String(icon || "")
    var marker = "?path="
    var markerIndex = value.indexOf(marker)
    if (markerIndex === -1) return value

    var name = value.substring(0, markerIndex).split("/").pop()
    var iconPath = value.substring(markerIndex + marker.length).split("&")[0]
    return Util.fileUrl(iconPath + "/hicolor/16x16/status/" + name + ".png")
  }

  function trayIconFallbackSource(icon) {
    var value = String(icon || "")
    var marker = "?path="
    var markerIndex = value.indexOf(marker)
    if (markerIndex === -1) return ""

    var name = value.substring(0, markerIndex).split("/").pop()
    var iconPath = value.substring(markerIndex + marker.length).split("&")[0]
    return Util.fileUrl(iconPath + "/" + name + ".png")
  }

  function trayTooltip(item) {
    return item.tooltipTitle || item.title || item.id || ""
  }

  function classifyItem(item) {
    var iid = String(item.id || "")
    if (hiddenIds.indexOf(iid) !== -1) return "hidden"
    if (pinnedIds.indexOf(iid) !== -1) return "pinned"
    return "drawer"
  }

  function bucket(category) {
    var values = SystemTray.items.values
    var result = []
    for (var i = 0; i < values.length; i++) {
      var item = values[i]
      if (category === "all") {
        result.push(item)
        continue
      }
      if (classifyItem(item) === category) result.push(item)
    }
    return result
  }

  function persistTrayState(pinned, hidden) {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var id = root.moduleName || "lacuna.tray"
    root.bar.shell.updateEntryInline(id, { id: id, pinned: pinned, hidden: hidden })
  }

  function togglePin(iid) {
    var p = pinnedIds.slice(), h = hiddenIds.slice()
    var idx = p.indexOf(iid)
    if (idx !== -1) p.splice(idx, 1)
    else {
      p.push(iid)
      var hi = h.indexOf(iid)
      if (hi !== -1) h.splice(hi, 1)
    }
    persistTrayState(p, h)
  }

  function toggleHide(iid) {
    var p = pinnedIds.slice(), h = hiddenIds.slice()
    var idx = h.indexOf(iid)
    if (idx !== -1) h.splice(idx, 1)
    else {
      h.push(iid)
      var pi = p.indexOf(iid)
      if (pi !== -1) p.splice(pi, 1)
    }
    persistTrayState(p, h)
  }

  visible: pinnedItems.length > 0 || drawerCount > 0
  clip: false
  implicitWidth: root.vertical ? root.barSize : trayContent.implicitWidth
  implicitHeight: root.vertical ? trayContent.implicitHeight : root.barSize

  Behavior on revealProgress {
    NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
  }

  Loader {
    id: trayContent
    anchors.fill: parent
    sourceComponent: root.vertical ? verticalTray : horizontalTray
  }

  Component {
    id: horizontalTray

    Item {
      id: horizontalTrayRoot

      readonly property int pinnedWidth: pinnedRow.implicitWidth
      readonly property int drawerBlockWidth: root.allItems.length > 0 ? expandIcon.implicitWidth + root.drawerExtent : 0

      implicitWidth: pinnedWidth + drawerBlockWidth
      implicitHeight: root.barSize

      // Mask out the empty area the collapsed drawer reserves for its slide-in,
      // so hovering it doesn't trigger expand and clicks pass through.
      containmentMask: QtObject {
        function contains(point: point): bool {
          if (point.y < 0 || point.y > horizontalTrayRoot.height) return false
          // Drawer reveals leftward; chevron sits at the right end when collapsed
          // and slides left as it opens. The visible region starts at the chevron.
          var chevronX = root.drawerExtent - root.revealExtent
          if (point.x >= chevronX && point.x <= horizontalTrayRoot.drawerBlockWidth) return true
          // Pinned items, placed to the right of the drawer block.
          var pinnedStart = horizontalTrayRoot.drawerBlockWidth
          return point.x >= pinnedStart && point.x <= horizontalTrayRoot.implicitWidth
        }
      }

      Item {
        id: drawerArea
        x: 0
        width: horizontalTrayRoot.drawerBlockWidth
        height: root.barSize
        visible: root.allItems.length > 0

        HoverHandler {
          onHoveredChanged: root.drawerHovered = hovered
        }

        WidgetButton {
          id: expandIcon
          bar: root.bar
          width: implicitWidth
          height: implicitHeight
          x: root.drawerExtent - root.revealExtent
          text: "\uf053"
          horizontalMargin: 9
          verticalPadding: 6
          onPressed: function(button) {
            if (button === Qt.RightButton) root.managePopupOpen = !root.managePopupOpen
          }
        }

        Item {
          id: trayClip
          x: expandIcon.width
          anchors.verticalCenter: parent.verticalCenter
          width: root.drawerExtent
          height: root.barSize
          clip: true

          Row {
            id: trayIcons
            x: root.drawerExtent - root.revealExtent
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.trayItemGap
            layer.enabled: true

            Repeater {
              model: root.drawerItems
              TrayItem {}
            }
          }
        }
      }

      Row {
        id: pinnedRow
        x: drawerArea.x + horizontalTrayRoot.drawerBlockWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.trayItemGap
        leftPadding: root.pinnedItems.length > 0 && root.allItems.length > 0 ? root.trayJoinGap : 0
        Repeater {
          model: root.pinnedItems
          TrayItem {}
        }
      }
    }
  }

  Component {
    id: verticalTray

    Item {
      id: verticalTrayRoot

      readonly property int pinnedHeight: pinnedCol.implicitHeight
      readonly property int drawerBlockHeight: root.allItems.length > 0 ? expandIcon.implicitHeight + root.drawerExtent : 0

      implicitWidth: root.barSize
      implicitHeight: pinnedHeight + drawerBlockHeight

      containmentMask: QtObject {
        function contains(point: point): bool {
          if (point.x < 0 || point.x > verticalTrayRoot.width) return false
          var chevronY = root.drawerExtent - root.revealExtent
          if (point.y >= chevronY && point.y <= verticalTrayRoot.drawerBlockHeight) return true
          var pinnedStart = verticalTrayRoot.drawerBlockHeight
          return point.y >= pinnedStart && point.y <= verticalTrayRoot.implicitHeight
        }
      }

      Item {
        id: drawerArea
        y: 0
        width: root.barSize
        height: verticalTrayRoot.drawerBlockHeight
        visible: root.allItems.length > 0

        HoverHandler {
          onHoveredChanged: root.drawerHovered = hovered
        }

        WidgetButton {
          id: expandIcon
          bar: root.bar
          width: implicitWidth
          height: implicitHeight
          y: root.drawerExtent - root.revealExtent
          text: "\uf053"
          textRotation: 90
          horizontalMargin: 9
          verticalPadding: 6
          onPressed: function(button) {
            if (button === Qt.RightButton) root.managePopupOpen = !root.managePopupOpen
          }
        }

        Item {
          id: trayClip
          y: expandIcon.height
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.barSize
          height: root.drawerExtent
          clip: true

          Column {
            id: trayIcons
            y: root.drawerExtent - root.revealExtent
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.trayItemGap
            layer.enabled: true

            Repeater {
              model: root.drawerItems
              TrayItem {}
            }
          }
        }
      }

      Column {
        id: pinnedCol
        y: drawerArea.y + verticalTrayRoot.drawerBlockHeight
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.trayItemGap
        topPadding: root.pinnedItems.length > 0 && root.allItems.length > 0 ? root.trayJoinGap : 0
        Repeater {
          model: root.pinnedItems
          TrayItem {}
        }
      }
    }
  }

  Loader {
    active: !root.fullscreenSuppressed
    sourceComponent: Component {
  PopupCard {
    id: managePopup
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.managePopupOpen
    contentWidth: managePopup.fittedContentWidth(Style.space(300))
    contentHeight: managePopup.fittedContentHeight(manageColumn.implicitHeight)

    Column {
      id: manageColumn
      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        text: "Tray icons"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        text: "Pinned icons stay visible. Hidden icons never show."
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }

      Text {
        visible: root.allItems.length === 0
        text: "No tray items reporting."
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      Repeater {
        model: root.allItems
        delegate: Item {
          id: rowRoot
          required property var modelData
          required property int index
          width: manageColumn.width
          implicitHeight: 28

          readonly property string itemId: String(modelData.id || "")
          readonly property string displayName: {
            var t = String(modelData.title || "").trim()
            if (t) return t
            var tt = String(modelData.tooltipTitle || "").trim()
            if (tt) return tt
            var id = String(modelData.id || "")
            var slash = id.lastIndexOf("/")
            return slash !== -1 ? id.substring(slash + 1) : (id || "Unknown")
          }
          readonly property bool isPinned: root.pinnedIds.indexOf(itemId) !== -1
          readonly property bool isHidden: root.hiddenIds.indexOf(itemId) !== -1

          IconImage {
            id: rowIcon
            property bool fallbackActive: false
            readonly property string primarySource: root.trayIconSource(rowRoot.modelData.icon)
            readonly property string fallbackSource: root.trayIconFallbackSource(rowRoot.modelData.icon)
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            implicitSize: 16
            width: 16
            height: 16
            source: fallbackActive && fallbackSource ? fallbackSource : primarySource
            onPrimarySourceChanged: fallbackActive = false
            onStatusChanged: {
              if (status === Image.Error && fallbackSource && source !== fallbackSource)
                fallbackActive = true
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: rowIcon.right
            anchors.leftMargin: Style.space(10)
            anchors.right: rowHideBtn.left
            anchors.rightMargin: Style.space(8)
            text: rowRoot.displayName
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Button {
            id: rowPinBtn
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            iconText: "\uf08d"
            text: rowRoot.isPinned ? "Unpin" : "Pin"
            foreground: root.foreground
            horizontalPadding: 8
            verticalPadding: 3
            iconSize: Style.font.bodySmall
            fontSize: Style.font.bodySmall
            onClicked: root.togglePin(rowRoot.itemId)
          }

          Button {
            id: rowHideBtn
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: rowPinBtn.left
            anchors.rightMargin: Style.space(6)
            iconText: "\uf06e"
            text: rowRoot.isHidden ? "Show" : "Hide"
            foreground: root.foreground
            horizontalPadding: 8
            verticalPadding: 3
            iconSize: Style.font.bodySmall
            fontSize: Style.font.bodySmall
            onClicked: root.toggleHide(rowRoot.itemId)
          }
        }
      }
    }
  }
    }
  }

  QsMenuOpener {
    id: trayMenuOpener
    menu: root.activeTrayItem ? root.activeTrayItem.menu : null
  }

  Loader {
    active: !root.fullscreenSuppressed
    sourceComponent: Component {
  PopupCard {
    id: trayMenuPopup
    anchorItem: root.activeTrayAnchor || root
    owner: root
    bar: root.bar
    open: root.trayMenuOpen
    padding: Style.space(8)
    borderColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
    contentWidth: trayMenuPopup.fittedContentWidth(Style.space(232))
    contentHeight: trayMenuPopup.fittedContentHeight(trayMenuColumn.implicitHeight)

    Flickable {
      id: trayMenuFlick
      anchors.fill: parent
      Component.onCompleted: root.trayMenuFlickItem = this
      Component.onDestruction: if (root.trayMenuFlickItem === this) root.trayMenuFlickItem = null
      clip: true
      contentWidth: width
      contentHeight: trayMenuColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height

      Column {
        id: trayMenuColumn
        width: parent.width
        spacing: 0

        Item {
          id: submenuBackRow
          visible: root.submenuDepth > 0
          width: trayMenuColumn.width
          implicitHeight: visible ? Style.space(30) : 0

          Rectangle {
            anchors.fill: parent
            radius: Math.max(2, Style.cornerRadius)
            color: backMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.foreground) : "transparent"
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: Style.space(22)
            horizontalAlignment: Text.AlignHCenter
            text: "\u2039"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(28)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            text: root.currentTitle
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.trayMenuSettling
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.leaveSubmenu()
          }
        }

        Repeater {
          model: root.currentChildren

          delegate: Item {
            id: menuRow
            required property var modelData
            required property int index

            readonly property string rowText: String(modelData.text || "")
            readonly property string activeTitle: root.activeTrayItem ? String(root.activeTrayItem.title || root.activeTrayItem.id || "") : ""
            readonly property bool atRoot: root.submenuDepth === 0
            readonly property bool rootTitleEntry: atRoot && index === 0 && modelData.hasChildren && rowText.toLowerCase() === activeTitle.toLowerCase()
            readonly property bool leadingSeparator: atRoot && modelData.isSeparator && index <= 1
            readonly property bool hiddenRow: rootTitleEntry || leadingSeparator

            visible: !hiddenRow
            width: trayMenuColumn.width
            implicitHeight: hiddenRow ? 0 : (modelData.isSeparator ? Style.space(11) : Style.space(30))
            opacity: modelData.enabled ? 1.0 : 0.45

            Rectangle {
              visible: menuRow.modelData.isSeparator
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              height: 1
              color: Color.popups.border
              opacity: 0.45
            }

            Rectangle {
              visible: !menuRow.modelData.isSeparator
              anchors.fill: parent
              radius: Math.max(2, Style.cornerRadius)
              color: rowMouse.containsMouse && menuRow.modelData.enabled ? Style.hoverFillFor(root.foreground, root.foreground) : "transparent"
            }

            Text {
              visible: !menuRow.modelData.isSeparator && menuRow.modelData.buttonType !== QsMenuButtonType.None
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              width: Style.space(22)
              horizontalAlignment: Text.AlignHCenter
              text: menuRow.modelData.checkState === Qt.Checked ? "\uf00c" : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            IconImage {
              id: menuIcon
              visible: !menuRow.modelData.isSeparator && String(menuRow.modelData.icon || "") !== ""
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(24)
              implicitSize: Style.space(16)
              width: Style.space(16)
              height: Style.space(16)
              source: menuRow.modelData.icon
            }

            Text {
              visible: !menuRow.modelData.isSeparator
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: menuIcon.visible ? Style.space(46) : Style.space(28)
              anchors.right: submenuGlyph.left
              anchors.rightMargin: Style.space(8)
              text: menuRow.rowText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              id: submenuGlyph
              visible: !menuRow.modelData.isSeparator && menuRow.modelData.hasChildren
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              text: "\u203a"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              enabled: !menuRow.modelData.isSeparator && menuRow.modelData.enabled
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                if (root.trayMenuSettling) return
                if (menuRow.modelData.hasChildren) {
                  root.enterSubmenu(menuRow.modelData, menuRow.rowText)
                } else {
                  menuRow.modelData.triggered()
                  root.close()
                }
              }
            }
          }
        }
      }
    }
  }
    }
  }

  component TrayItem: Item {
    id: trayItemRoot

    required property var modelData

    implicitWidth: root.trayItemExtent
    implicitHeight: root.trayItemExtent

    function displayMenu(mouse) {
      root.openTrayMenu(trayItemRoot.modelData, trayItemRoot, mouse)
    }

    IconImage {
      id: trayIconImage
      property bool fallbackActive: false
      readonly property string primarySource: root.trayIconSource(trayItemRoot.modelData.icon)
      readonly property string fallbackSource: root.trayIconFallbackSource(trayItemRoot.modelData.icon)
      anchors.centerIn: parent
      implicitSize: root.topbarIconSize
      width: root.topbarIconSize
      height: root.topbarIconSize
      source: fallbackActive && fallbackSource ? fallbackSource : primarySource
      onPrimarySourceChanged: fallbackActive = false
      onStatusChanged: {
        if (status === Image.Error && fallbackSource && source !== fallbackSource)
          fallbackActive = true
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (root.bar) root.bar.showTooltip(trayItemRoot, root.trayTooltip(modelData))
      onExited: if (root.bar) root.bar.hideTooltip(trayItemRoot)
      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          trayItemRoot.displayMenu(mouse)
          mouse.accepted = true
        }
      }
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          mouse.accepted = true
        } else if (mouse.button === Qt.MiddleButton) {
          trayItemRoot.modelData.secondaryActivate()
        } else if (trayItemRoot.modelData.onlyMenu) {
          trayItemRoot.displayMenu(mouse)
        } else {
          trayItemRoot.modelData.activate()
        }
      }
      onWheel: function(wheel) {
        trayItemRoot.modelData.scroll(wheel.angleDelta.y, false)
      }
    }

    readonly property bool tooltipHovered: opacity > 0 && mouseArea.containsMouse
  }
}
