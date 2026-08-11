import QtQuick
import Quickshell.Widgets
import "../components"
import "../modules"
import "../services"

Column {
  id: root

  signal activated(var entry)
  signal collapseRequested()
  signal quickLaunchMoveRequested(string appId, int targetIndex)
  signal quickLaunchRenameRequested(string appId, string label)
  signal quickLaunchRemoveRequested(string appId)
  signal settingsRequested()
  signal shellSettingsRequested()
  signal mediaPlayerRequested()
  signal closeRequested()

  required property var menuState
  required property var registry
  property bool open: true
  property bool compact: false
  property string currentView: menuState.currentView
  property string version: ""
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
  // Visible "seam" hairline (docs/lacuna-design-system/02-geometry.md). Stronger
  // under the lacuna style so structural joins are shown, not hidden.
  readonly property color seam: Qt.rgba(foreground.r, foreground.g, foreground.b, designTokens.lacuna ? 0.16 : 0.08)
  property string bodyFontFamily: "Hack Nerd Font Propo"
  property string itemFontFamily: itemFont.name !== "" ? itemFont.name : "Tektur"
  property int iconRailWidth: 32
  property var designTokens: fallbackDesignTokens
  property var mediaPlayerService: null
  property string mediaPlayerSurfaceId: "inline"
  readonly property int mediaPlayerReserveHeight: mediaPlayerSlot.visible ? mediaPlayerSlot.height + root.spacing : 0
  property var collapsedSections: ({})
  property bool quickLaunchOrderingUnlocked: false
  property bool quickLaunchContextOpen: false
  property real quickLaunchContextX: 0
  property real quickLaunchContextY: 0
  property string quickLaunchContextAppId: ""
  property string quickLaunchContextLabel: ""
  property bool quickLaunchRenameOpen: false
  property string quickLaunchRenameAppId: ""
  property string quickLaunchRenameText: ""
  property real quickLaunchRenameX: 0
  property real quickLaunchRenameY: 0
  property string draggingQuickLaunchAppId: ""
  property int quickLaunchDropIndex: -1
  property real quickLaunchDropY: 0
  property int sectionRevision: 0
  readonly property var rows: visibleItems()
  property MotionTokens motionTokens: defaultMotionTokens

  MotionTokens {
    id: defaultMotionTokens
  }

  function toneAccent(tone) {
    if (tone === "danger") return root.dangerAccent
    return root.accent
  }

  function openSettings() {
    root.settingsRequested()
  }

  function openShellSettings() {
    root.shellSettingsRequested()
  }

  function sectionKey(entry, index) {
    return root.menuState.currentView + "::" + String(entry.label || entry.group || "section").toLowerCase() + "::" + index
  }

  function isSectionCollapsed(key) {
    var revision = root.sectionRevision
    return root.collapsedSections && root.collapsedSections[key] === true
  }

  function toggleSection(key) {
    var next = {}
    for (var existingKey in root.collapsedSections) next[existingKey] = root.collapsedSections[existingKey]
    next[key] = !isSectionCollapsed(key)
    root.collapsedSections = next
    root.sectionRevision++
  }

  function visibleItems() {
    // Read every reactive dependency up front so the `model: visibleItems()`
    // binding re-evaluates when any of them changes. Using root.currentView
    // (a tracked string property) instead of the nested menuState.currentView,
    // and reading catalogRevision, is what makes the list rebuild once the view
    // settles and the catalog loads — without this the binding only tracked
    // sectionRevision and stayed stale until a manual section toggle.
    var revision = root.sectionRevision
    var view = root.currentView
    var catalogRevision = root.registry ? root.registry.catalogRevision : 0
    if (!root.registry || !root.menuState) return []
    var source = root.registry.itemsFor(view)
    var counts = {}
    var headerIndex = 0
    var activeKey = ""

    for (var i = 0; i < source.length; i++) {
      var sourceEntry = source[i]
      if (sourceEntry.kind === "header") {
        activeKey = sectionKey(sourceEntry, headerIndex)
        counts[activeKey] = 0
        headerIndex++
      } else if (activeKey !== "") {
        counts[activeKey] += sourceEntry.kind === "grid" && sourceEntry.gridItems ? sourceEntry.gridItems.length : 1
      }
    }

    var rows = []
    headerIndex = 0
    activeKey = ""
    var activeCollapsed = false

    for (var j = 0; j < source.length; j++) {
      var entry = source[j]
      if (entry.kind === "header") {
        activeKey = sectionKey(entry, headerIndex)
        activeCollapsed = isSectionCollapsed(activeKey)
        var header = entry
        header.sectionKey = activeKey
        header.sectionCollapsed = activeCollapsed
        header.sectionCount = counts[activeKey] || 0
        rows.push(header)
        headerIndex++
      } else if (!activeCollapsed) {
        rows.push(entry)
      }
    }

    return rows
  }

  function quickLaunchIndexForSceneY(sceneY) {
    return quickLaunchDropPositionForSceneY(sceneY).index
  }

  function quickLaunchDropPositionForSceneY(sceneY) {
    var target = 0
    var markerY = 0
    var seen = false
    var children = itemList.children

    for (var i = 0; i < children.length; i++) {
      var child = children[i]
      if (!child || !child.entry || child.entry.reorderable !== true) continue

      var center = child.mapToItem(null, 0, child.height / 2).y
      if (!seen) {
        markerY = Math.max(0, child.y - root.designTokens.itemSpacing / 2)
        seen = true
      }

      if (sceneY > center) {
        target = child.entry.quickLaunchIndex + 1
        markerY = child.y + child.height + root.designTokens.itemSpacing / 2
      }
    }

    return { index: target, y: markerY, valid: seen }
  }

  function updateQuickLaunchDrop(sceneY) {
    var position = quickLaunchDropPositionForSceneY(sceneY)
    quickLaunchDropIndex = position.valid ? position.index : -1
    quickLaunchDropY = position.y
  }

  function openQuickLaunchRename(appId, label) {
    quickLaunchRenameAppId = appId
    quickLaunchRenameText = label
    var popoverWidth = Math.min(itemList.width, root.compact ? 190 : 218)
    quickLaunchRenameX = Math.max(0, Math.min(itemList.width - popoverWidth, quickLaunchContextX))
    quickLaunchRenameY = quickLaunchContextY
    quickLaunchContextOpen = false
    quickLaunchRenameOpen = true

    Qt.callLater(function() {
      renameInput.forceActiveFocus()
      renameInput.selectAll()
    })
  }

  function openQuickLaunchContext(appId, label, item, x, y) {
    if (String(appId || "") === "" || !item) return
    var point = item.mapToItem(itemList, x, y)
    root.quickLaunchContextAppId = appId
    root.quickLaunchContextLabel = label
    root.quickLaunchRenameOpen = false
    root.quickLaunchContextX = Math.max(0, Math.min(itemList.width - quickLaunchContextMenu.width, point.x))
    root.quickLaunchContextY = Math.max(0, Math.min(Math.max(0, itemList.height - quickLaunchContextMenu.height), point.y))
    root.quickLaunchContextOpen = true
  }

  function saveQuickLaunchRename() {
    root.quickLaunchRenameRequested(quickLaunchRenameAppId, renameInput.text)
    quickLaunchRenameOpen = false
  }

  function removeQuickLaunchApp() {
    root.quickLaunchRemoveRequested(quickLaunchContextAppId)
    quickLaunchContextOpen = false
    quickLaunchRenameOpen = false
    draggingQuickLaunchAppId = ""
    quickLaunchDropIndex = -1
  }

  spacing: designTokens.sectionSpacing
  // Pointer-first contract: the passive sidebar never requests keyboard
  // focus. Explicit TextInput editors below may take bounded focus on demand.
  focus: false
  onCurrentViewChanged: {
    viewProgress = 0
    quickLaunchContextOpen = false
    quickLaunchRenameOpen = false
    draggingQuickLaunchAppId = ""
    quickLaunchDropIndex = -1
    viewReveal.restart()
  }
  // Always reveal the content when the sidebar opens. Otherwise viewProgress
  // can be left at 0 (e.g. a view reset while closed) and the grid/list stays
  // invisible until a view change is triggered.
  onOpenChanged: {
    if (open) {
      viewProgress = 0
      viewReveal.restart()
    }
  }

  // Visibility follows `open` directly (with the fade Behavior below) so content
  // can never be stranded invisible if the reveal animation fails to run — e.g.
  // when viewProgress is reset during startup before the content is ready.
  // viewProgress now only drives the slide-in offset, never visibility.
  opacity: open ? 1 : 0
  x: open ? -6 * (1 - viewProgress) : -6

  Behavior on opacity {
    LacunaAnim { motion: "normal"; motionTokens: root.motionTokens }
  }

  // The item model (visibleItems) is rebuilt from the registry, but only
  // re-evaluates on sectionRevision/currentView changes. If the registry's
  // catalog finishes loading after the menu first renders, the list/grid would
  // stay empty until a manual refresh (clicking a section header). Refresh it
  // whenever the catalog revision changes so items appear on their own.
  Connections {
    target: root.registry
    function onCatalogRevisionChanged() { root.sectionRevision++ }
  }

  NumberAnimation {
    id: viewReveal

    target: root
    property: "viewProgress"
    to: 1
    duration: root.motionTokens.reveal
    easing.type: Easing.OutCubic
  }

  FontLoader {
    id: itemFont

    source: "../assets/fonts/Tektur-SemiBold.ttf"
  }

  MenuHeader {
    width: parent.width
    title: root.registry.titleFor(root.menuState.currentView)
    version: root.version
    subtitle: ""
    canGoBack: root.menuState.stack.length > 1
    foreground: root.foreground
    muted: root.muted
    accent: root.accent
    danger: root.dangerAccent
    compact: root.compact
    canCollapse: false
    designTokens: root.designTokens
    bodyFontFamily: root.bodyFontFamily
    motionTokens: root.motionTokens
    onBackRequested: root.menuState.back()
    onCollapseRequested: root.collapseRequested()
    onCloseRequested: root.menuState.close()
  }

  Item {
    // Redundant under lacuna: the header's own accent rule plus the content
    // well's top lip already separate the header from the content.
    visible: !root.designTokens.lacuna
    width: parent.width
    height: 1
    opacity: root.designTokens.headerTreatment === "accent-line" ? 1 : 0.55

    LacunaRect {
      anchors.left: parent.left
      height: 1
      width: root.designTokens.dividerGap > 0 ? (parent.width - root.designTokens.dividerGap) / 2 : parent.width
      color: root.seam
    }

    LacunaRect {
      visible: root.designTokens.dividerGap > 0
      anchors.right: parent.right
      height: 1
      width: (parent.width - root.designTokens.dividerGap) / 2
      color: root.seam
    }
  }

  Flickable {
    id: itemFlick

    width: parent.width
    height: Math.max(0, root.height - y - root.mediaPlayerReserveHeight - settingsFooter.height - root.spacing)
    contentWidth: width
    contentHeight: itemList.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: itemList

      width: parent.width
      spacing: root.designTokens.itemSpacing

      Repeater {
        id: itemRepeater
        model: root.rows

        Loader {
          property var entry: modelData
          property int flatIndex: index

          width: parent.width
          // Track the loaded delegate's height reactively. Item rows set
          // height from designTokens (0 until it loads); without this the
          // Loader sizes once to that stale 0 and the row stays invisible
          // until a rebuild — section headers use a static height, which is
          // why headers showed but items did not.
          height: item ? item.height : 0
          sourceComponent: entry.kind === "header" ? sectionDelegate : (entry.kind === "grid" ? gridDelegate : itemDelegate)
        }
      }
    }

    Item {
      id: quickLaunchDropMarker

      visible: root.draggingQuickLaunchAppId !== "" && root.quickLaunchDropIndex >= 0
      z: 24
      x: 4
      y: root.quickLaunchDropY - height / 2
      width: Math.max(0, itemList.width - 8)
      height: 8

      Behavior on y {
        LacunaAnim { motion: "fast"; motionTokens: root.motionTokens }
      }

      LacunaRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 2
        radius: 1
        color: root.accent
        opacity: 0.88
      }

      LacunaRect {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: 6
        radius: 3
        color: root.accent
      }

      LacunaRect {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: 6
        radius: 3
        color: root.accent
      }
    }

    LacunaRect {
      id: quickLaunchContextMenu

      visible: root.quickLaunchContextOpen
      z: 30
      x: root.quickLaunchContextX
      y: root.quickLaunchContextY
      width: root.compact ? 106 : 118
      height: root.compact ? 84 : 93
      radius: root.designTokens.material ? 8 : root.designTokens.controlRadius
      color: root.background
      border.width: root.designTokens.lacuna ? 0 : 1
      border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
      clip: true

      Column {
        anchors.fill: parent
        spacing: 0

        Item {
          width: parent.width
          height: root.compact ? 28 : 31

          LacunaText {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            text: root.quickLaunchOrderingUnlocked ? "Lock order" : "Unlock order"
            color: root.foreground
            fontFamily: root.bodyFontFamily
            font.pixelSize: root.compact ? typeTokens.textHint : typeTokens.textSmall
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          LacunaStateLayer {
            anchors.fill: parent
            stateColor: root.accent
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            onTriggered: {
              root.quickLaunchOrderingUnlocked = !root.quickLaunchOrderingUnlocked
              root.quickLaunchContextOpen = false
            }
          }
        }

        Item {
          width: parent.width
          height: root.compact ? 28 : 31

          LacunaRect {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.seam
          }

          LacunaText {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            text: "Rename"
            color: root.foreground
            fontFamily: root.bodyFontFamily
            font.pixelSize: root.compact ? typeTokens.textHint : typeTokens.textSmall
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          LacunaStateLayer {
            anchors.fill: parent
            stateColor: root.accent
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            onTriggered: root.openQuickLaunchRename(root.quickLaunchContextAppId, root.quickLaunchContextLabel)
          }
        }

        Item {
          width: parent.width
          height: root.compact ? 28 : 31

          LacunaRect {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.seam
          }

          LacunaText {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            text: "Delete"
            color: root.dangerAccent
            fontFamily: root.bodyFontFamily
            font.pixelSize: root.compact ? typeTokens.textHint : typeTokens.textSmall
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          LacunaStateLayer {
            anchors.fill: parent
            stateColor: root.dangerAccent
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            onTriggered: root.removeQuickLaunchApp()
          }
        }
      }
    }

    LacunaRect {
      id: quickLaunchRenamePopover

      visible: root.quickLaunchRenameOpen
      z: 31
      x: root.quickLaunchRenameX
      y: root.quickLaunchRenameY
      width: Math.min(itemList.width, root.compact ? 190 : 218)
      height: root.compact ? 34 : 38
      radius: root.designTokens.material ? 9 : root.designTokens.controlRadius
      color: root.background
      border.width: root.designTokens.lacuna ? 0 : 1
      border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.34)
      clip: true

      TextInput {
        id: renameInput

        anchors.left: parent.left
        anchors.right: saveRenameButton.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        height: parent.height
        text: root.quickLaunchRenameText
        color: root.foreground
        selectionColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.36)
        selectedTextColor: root.foreground
        font.family: root.bodyFontFamily
        font.pixelSize: root.compact ? typeTokens.textSmall : typeTokens.textNormal
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        clip: true
        onTextChanged: root.quickLaunchRenameText = text
        Keys.onReturnPressed: root.saveQuickLaunchRename()
        Keys.onEnterPressed: root.saveQuickLaunchRename()
        Keys.onEscapePressed: root.quickLaunchRenameOpen = false
      }

      LacunaIconButton {
        id: saveRenameButton

        anchors.right: cancelRenameButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        icon: "check"
        foreground: root.foreground
        muted: root.muted
        accent: root.accent
        buttonSize: root.compact ? 22 : 24
        iconSize: root.compact ? 12 : 13
        buttonRadius: root.designTokens.controlRadius
        hoverOpacity: root.designTokens.hoverOpacity
        pressOpacity: root.designTokens.activeOpacity
        fontFamily: root.bodyFontFamily
        onTriggered: root.saveQuickLaunchRename()
      }

      LacunaIconButton {
        id: cancelRenameButton

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        icon: "x"
        foreground: root.foreground
        muted: root.muted
        accent: root.dangerAccent
        buttonSize: root.compact ? 22 : 24
        iconSize: root.compact ? 12 : 13
        buttonRadius: root.designTokens.controlRadius
        hoverOpacity: root.designTokens.hoverOpacity
        pressOpacity: root.designTokens.activeOpacity
        fontFamily: root.bodyFontFamily
        onTriggered: root.quickLaunchRenameOpen = false
      }
    }

    Component {
      id: sectionDelegate

      MenuSection {
        width: itemList.width
        title: parent.entry.label
        foreground: root.foreground
        muted: root.muted
        accent: root.toneAccent(parent.entry.tone)
        band: parent.entry.tone === "lacuna" || parent.entry.tone === "danger"
        collapsible: parent.entry.sectionCount > 0
        collapsed: parent.entry.sectionCollapsed || false
        count: parent.entry.sectionCount || 0
        options: parent.entry.options || []
        optionValue: parent.entry.optionValue || ""
        actionIcon: parent.entry.headerActionIcon || ""
        actionTooltip: parent.entry.headerActionTooltip || ""
        compact: root.compact
        designTokens: root.designTokens
        fontFamily: root.bodyFontFamily
        hoverOpacity: root.designTokens.hoverOpacity
        pressOpacity: root.designTokens.activeOpacity
        motionTokens: root.motionTokens
        onToggled: root.toggleSection(parent.entry.sectionKey)
        onOptionSelected: function(value) {
          root.activated({
            kind: "item",
            action: (parent.entry.optionActionPrefix || "") + value,
            view: "",
            command: ""
          })
        }
        onActionTriggered: {
          root.activated({
            kind: "item",
            action: parent.entry.headerAction || "",
            view: "",
            command: ""
          })
        }
      }
    }

    Component {
      id: itemDelegate

      LacunaMenuItem {
        width: parent.width
        focused: false
        kind: parent.entry.kind
        icon: parent.entry.icon
        iconSource: parent.entry.iconSource || ""
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
        switchVisible: parent.entry.switchVisible || false
        switchChecked: parent.entry.switchChecked || false
        badgeText: parent.entry.badgeText || ""
        trailingAction: parent.entry.trailingAction || ""
        trailingIcon: parent.entry.trailingIcon || ""
        trailingTooltip: parent.entry.trailingTooltip || ""
        reorderHandleVisible: root.quickLaunchOrderingUnlocked && parent.entry.reorderable === true
        reorderActive: root.draggingQuickLaunchAppId !== "" && root.draggingQuickLaunchAppId === parent.entry.appId
        optionValue: parent.entry.optionValue || ""
        options: parent.entry.options || []
        background: root.background
        fontFamily: root.bodyFontFamily
        labelFontFamily: root.itemFontFamily
        iconRailWidth: root.iconRailWidth
        compact: root.compact
        designTokens: root.designTokens
        motionTokens: root.motionTokens
        onTriggered: root.activated(parent.entry)
        onContextRequested: function(x, y) {
          if (parent.entry.reorderable !== true) return
          root.openQuickLaunchContext(parent.entry.appId, parent.entry.label, parent, x, y)
        }
        onReorderDragStarted: function(sceneY) {
          if (parent.entry.reorderable !== true) return
          root.draggingQuickLaunchAppId = parent.entry.appId
          root.updateQuickLaunchDrop(sceneY)
        }
        onReorderDragged: function(sceneY) {
          if (parent.entry.reorderable !== true) return
          root.updateQuickLaunchDrop(sceneY)
        }
        onReorderDropped: function(sceneY) {
          if (parent.entry.reorderable !== true) return
          var targetIndex = root.quickLaunchDropIndex >= 0 ? root.quickLaunchDropIndex : root.quickLaunchIndexForSceneY(sceneY)
          root.draggingQuickLaunchAppId = ""
          root.quickLaunchDropIndex = -1
          root.quickLaunchMoveRequested(parent.entry.appId, targetIndex)
        }
        onTrailingActionTriggered: function(action) {
          var next = {
            kind: parent.entry.kind,
            action: action,
            appId: parent.entry.appId || "",
            view: "",
            command: ""
          }
          root.activated(next)
        }
        onOptionSelected: function(value) {
          root.activated({
            kind: "item",
            action: (parent.entry.optionActionPrefix || "set-design-style-") + value,
            view: "",
            command: ""
          })
        }
      }
    }

    Component {
      id: gridDelegate

      Item {
        id: gridRoot

        property var entry: parent.entry
        readonly property var gridItems: entry.gridItems || []
        readonly property int columns: 3
        readonly property int gap: root.compact ? 7 : 8
        readonly property int tileWidth: Math.floor((width - gap * (columns - 1)) / columns)
        readonly property int tileHeight: root.compact ? 62 : 72
        width: parent.width
        height: toolGrid.implicitHeight

        Grid {
          id: toolGrid

          width: parent.width
          columns: gridRoot.columns
          columnSpacing: gridRoot.gap
          rowSpacing: gridRoot.gap

          Repeater {
            model: gridRoot.gridItems

            LacunaRect {
              id: tile

              required property var modelData

              readonly property color itemAccent: root.toneAccent(modelData.tone || "session")
              readonly property bool itemDanger: modelData.danger === true
              readonly property bool hasIconSource: String(modelData.iconSource || "") !== ""
              readonly property bool hovered: stateLayer.containsMouse
              readonly property real reveal: stateLayer.reveal
              property real gapBreath: 0

              width: gridRoot.tileWidth
              height: gridRoot.tileHeight
              radius: root.designTokens.material ? 8 : root.designTokens.radius
              color: "transparent"
              border.width: 0
              clip: true

              LacunaRect {
                id: tileBackground

                anchors.centerIn: parent
                width: Math.max(0, parent.width - (root.compact ? 6 : 8))
                height: Math.max(0, parent.height - (root.compact ? 6 : 8))
                radius: root.designTokens.material ? 8 : root.designTokens.radius
                color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, tile.itemDanger ? 0.07 + tile.reveal * 0.07 : 0.035 + tile.reveal * 0.06)
                border.width: root.designTokens.lacuna ? 0 : 1
                border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, tile.hovered ? 0.42 : 0.20)

                Behavior on color {
                  LacunaColorAnim {}
                }

                // Seam frame (lacuna): a fine carved-cell border. The bottom
                // edge is broken by a centered gap — the lacuna notch — and is
                // where the hover highlight lives, mirroring the header rule's
                // notched line with the breathing gap glow. The top edge stays a
                // plain seam.
                readonly property int notch: root.compact ? 10 : 14

                LacunaRect {
                  visible: root.designTokens.lacuna
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  height: 1
                  color: root.seam
                }

                LacunaRect {
                  visible: root.designTokens.lacuna
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: 1
                  color: root.seam
                }

                LacunaRect {
                  visible: root.designTokens.lacuna
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: 1
                  color: root.seam
                }

                // Bottom edge stays a plain seam (like the header rule's faint
                // line); only the gap centerpiece glows on hover.
                LacunaRect {
                  visible: root.designTokens.lacuna
                  anchors.left: parent.left
                  anchors.bottom: parent.bottom
                  height: 1
                  width: Math.max(0, (parent.width - parent.notch) / 2)
                  color: root.seam
                }

                LacunaRect {
                  visible: root.designTokens.lacuna
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: 1
                  width: Math.max(0, (parent.width - parent.notch) / 2)
                  color: root.seam
                }

                // The centerpiece: an accent glow at the gap that fades in on
                // hover, breathes (Timer-driven sine, like the header rule), and
                // spreads out across the bottom — brightest at the gap centre.
                Item {
                  visible: root.designTokens.lacuna && tile.hovered
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.verticalCenter: parent.bottom
                  width: Math.round(parent.width * 0.88)
                  height: 8

                  LacunaRect {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 5
                    radius: 2.5
                    color: tile.itemAccent
                    opacity: (0.03 + tile.gapBreath * 0.17) * tile.reveal
                  }

                  LacunaRect {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.45)
                    height: 3
                    radius: 1.5
                    color: tile.itemAccent
                    opacity: (0.10 + tile.gapBreath * 0.32) * tile.reveal
                  }

                  LacunaRect {
                    anchors.centerIn: parent
                    width: Math.max(6, Math.round(parent.width * 0.16))
                    height: 2
                    radius: 1
                    color: tile.itemAccent
                    opacity: (0.28 + tile.gapBreath * 0.62) * tile.reveal
                  }
                }

                Timer {
                  running: root.designTokens.lacuna && tile.hovered
                  interval: 50
                  repeat: true
                  onTriggered: tile.gapBreath = 0.5 + 0.5 * Math.sin(Date.now() / 620)
                }
              }

              LacunaRect {
                id: iconBubble

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -tile.reveal * (root.compact ? 7 : 9)
                width: root.compact ? 38 : 44
                height: width
                scale: 1 + tile.reveal * 0.06
                radius: root.designTokens.material ? width / 2 : root.designTokens.controlRadius
                color: "transparent"
                border.width: 0
                transformOrigin: Item.Center

                IconImage {
                  id: gridIconImage

                  anchors.centerIn: parent
                  width: root.compact ? 22 : 25
                  height: width
                  implicitSize: width
                  source: tile.modelData.iconSource || ""
                  visible: tile.hasIconSource && status === Image.Ready
                  opacity: tile.hovered ? 1 : 0.92
                  scale: 1 + tile.reveal * 0.12
                  transformOrigin: Item.Center
                }

                LacunaTablerIcon {
                  id: gridIcon

                  anchors.centerIn: parent
                  name: tile.modelData.icon || ""
                  color: tile.hovered ? root.foreground : tile.itemAccent
                  iconSize: root.compact ? 22 : 25
                  scale: 1 + tile.reveal * 0.14
                  transformOrigin: Item.Center
                  visible: (!tile.hasIconSource || gridIconImage.status === Image.Error) && valid
                }

                LacunaText {
                  anchors.centerIn: parent
                  width: parent.width
                  visible: (!tile.hasIconSource || gridIconImage.status === Image.Error) && !gridIcon.valid
                  text: tile.modelData.icon || ""
                  color: tile.hovered ? root.foreground : tile.itemAccent
                  fontFamily: root.bodyFontFamily
                  font.pixelSize: root.compact ? typeTokens.textTitle : typeTokens.textFeature
                  horizontalAlignment: Text.AlignHCenter
                  scale: 1 + tile.reveal * 0.12
                  transformOrigin: Item.Center
                }
              }

              LacunaText {
                id: tileLabel

                anchors.horizontalCenter: tileBackground.horizontalCenter
                anchors.bottom: tileBackground.bottom
                anchors.bottomMargin: root.compact ? 5 : 7
                width: Math.max(0, tileBackground.width - 8)
                text: tile.modelData.label || ""
                color: root.foreground
                opacity: tile.hovered ? 1 : 0
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                fontFamily: root.bodyFontFamily
                font.pixelSize: typeTokens.textHint
                font.weight: Font.DemiBold

                // Name eases in after a slight delay and slowly; fades out
                // quickly so it doesn't linger when the cursor leaves.
                Behavior on opacity {
                  SequentialAnimation {
                    PauseAnimation { duration: tile.hovered ? 220 : 0 }
                    NumberAnimation { duration: tile.hovered ? 820 : 200; easing.type: Easing.OutCubic }
                  }
                }
              }

              LacunaStateLayer {
                id: stateLayer

                anchors.fill: parent
                stateColor: tile.itemAccent
                hoverOpacity: root.designTokens.hoverOpacity
                pressOpacity: root.designTokens.activeOpacity
                showFill: !root.designTokens.lacuna
                onTriggered: root.activated(tile.modelData)
                onSecondaryClicked: function(x, y) {
                  if (tile.modelData.reorderable !== true) return
                  root.openQuickLaunchContext(tile.modelData.appId, tile.modelData.label, tile, x, y)
                }
              }
            }
          }
        }

      }
    }
  }

  MediaPlayerTile {
    id: mediaPlayerSlot

    width: parent.width
    height: visible ? tileHeight : 0
    visible: root.mediaPlayerService !== null
    service: root.mediaPlayerService
    surfaceId: root.mediaPlayerSurfaceId
    compact: root.compact
    designTokens: root.designTokens
    foreground: root.foreground
    background: root.background
    accent: root.accent
    muted: root.muted
    bodyFontFamily: root.bodyFontFamily
    onOpenRequested: root.mediaPlayerRequested()
  }

  Item {
    id: settingsFooter

    width: parent.width
    height: root.compact ? 68 : 78

    Row {
      id: collapseRow

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: root.compact ? 34 : 38

      LacunaIconButton {
        id: collapseButton

        anchors.verticalCenter: parent.verticalCenter
        icon: "sidebar-collapse"
        foreground: root.foreground
        muted: root.muted
        accent: root.accent
        hoverAccent: root.accent
        buttonSize: root.compact ? 32 : 36
        buttonRadius: root.designTokens.controlRadius
        hoverOpacity: root.designTokens.hoverOpacity
        pressOpacity: root.designTokens.activeOpacity
        iconSize: root.compact ? 18 : 20
        onTriggered: root.collapseRequested()
      }
    }

    Item {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: collapseRow.bottom
      height: 1

      LacunaRect {
        anchors.left: parent.left
        height: 1
        width: root.designTokens.dividerGap > 0 ? (parent.width - root.designTokens.dividerGap) / 2 : parent.width
        color: root.seam
      }

      LacunaRect {
        visible: root.designTokens.dividerGap > 0
        anchors.right: parent.right
        height: 1
        width: (parent.width - root.designTokens.dividerGap) / 2
        color: root.seam
      }
    }

    Row {
      id: settingsRow

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: root.compact ? 34 : 38
      spacing: root.compact ? 6 : 8

      LacunaIconButton {
        id: settingsButton

        anchors.verticalCenter: parent.verticalCenter
        icon: "gear"
        foreground: root.foreground
        muted: root.muted
        accent: root.accent
        hoverAccent: root.accent
        buttonSize: root.compact ? 32 : 36
        buttonRadius: root.designTokens.controlRadius
        hoverOpacity: root.designTokens.hoverOpacity
        pressOpacity: root.designTokens.activeOpacity
        iconSize: root.compact ? 18 : 20
        onTriggered: root.openSettings()
      }

      LacunaIconButton {
        id: shellSettingsButton

        anchors.verticalCenter: parent.verticalCenter
        icon: "settings"
        foreground: root.foreground
        muted: root.muted
        accent: root.accent
        hoverAccent: root.accent
        buttonSize: root.compact ? 32 : 36
        buttonRadius: root.designTokens.controlRadius
        hoverOpacity: root.designTokens.hoverOpacity
        pressOpacity: root.designTokens.activeOpacity
        iconSize: root.compact ? 18 : 20
        onTriggered: root.openShellSettings()
      }
    }

    LacunaRect {
      visible: settingsButton.hovered
      x: settingsRow.x + settingsButton.x + settingsButton.width + 8
      y: settingsRow.y + settingsButton.y - height - 4
      width: 118
      height: 28
      radius: root.designTokens.tooltipTreatment === "tonal" ? root.designTokens.radius : 0
      color: root.background
      border.width: root.designTokens.tooltipTreatment === "accent-strip" ? 1 : root.designTokens.borderWidth
      border.color: root.designTokens.tooltipTreatment === "bordered" ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24)

      LacunaRect {
        visible: root.designTokens.tooltipTreatment === "accent-strip"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.accent
        opacity: 0.82
      }

      LacunaText {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "Lacuna Settings"
        color: root.foreground
        fontFamily: root.bodyFontFamily
        font.pixelSize: typeTokens.textNormal
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
    }

    LacunaRect {
      visible: shellSettingsButton.hovered
      x: settingsRow.x + shellSettingsButton.x + shellSettingsButton.width + 8
      y: settingsRow.y + shellSettingsButton.y - height - 4
      width: 142
      height: 28
      radius: root.designTokens.tooltipTreatment === "tonal" ? root.designTokens.radius : 0
      color: root.background
      border.width: root.designTokens.tooltipTreatment === "accent-strip" ? 1 : root.designTokens.borderWidth
      border.color: root.designTokens.tooltipTreatment === "bordered" ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24)

      LacunaRect {
        visible: root.designTokens.tooltipTreatment === "accent-strip"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.accent
        opacity: 0.82
      }

      LacunaText {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "Omarchy Shell Settings"
        color: root.foreground
        fontFamily: root.bodyFontFamily
        font.pixelSize: typeTokens.textNormal
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
    }
  }

  DesignTokens {
    id: fallbackDesignTokens
    designStyle: "lacuna"
    compact: root.compact
    foreground: root.foreground
    background: root.background
    accent: root.accent
  }

  LacunaTokens { id: typeTokens }

}
