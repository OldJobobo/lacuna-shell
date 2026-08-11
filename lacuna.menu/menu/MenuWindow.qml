import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.Commons
import "../services"
import "../components"
import "../settings"
import "MonitorPolicy.js" as MonitorPolicy
import "MenuFlyoutGeometry.js" as MenuFlyoutGeometry

Item {
  id: root

  signal flyoutContentRegistered(string kind)

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property bool hostManaged: false
  property int hostBarSize: 0
  property bool hostFrameBorderEnabled: false
  property var hostFrameGeometryProvider: null
  property var hostBarPopoutBorderGapProvider: null
  property string pluginId: manifest && manifest.id ? manifest.id : "lacuna.menu"
  property var menuState: localMenuState
  property var flyoutContentRefs: ({})
  property var autohideContentHolds: ({})
  property string settingsSection: "overview"
  property string requestedInteractionMonitorName: ""
  property bool initialSidebarDefaultApplied: false
  property string lacunaPath: manifest && manifest.__sourceDir ? manifest.__sourceDir : localPath(Qt.resolvedUrl(".."))
  property var sharedCompactState: null
  property var sharedSidebarState: null
  readonly property var lacunaSettings: resolveLacunaSettings()
  readonly property var compactState: sharedCompactState || localCompactState
  readonly property var sidebarState: sharedSidebarState || localSidebarState
  readonly property bool sidebarAutoHideEnabled: sidebarState.autoHideEnabled === true
  readonly property int sidebarAutoHideHotZoneWidth: Math.max(2, Math.min(8, Number(sidebarState.autoHideHotZoneWidth) || 3))
  readonly property int sidebarAutoHideRevealDelayMs: Math.max(0, Math.min(1000, Number(sidebarState.autoHideRevealDelayMs) || 0))
  readonly property int sidebarAutoHideHideDelayMs: Math.max(0, Math.min(3000, Number(sidebarState.autoHideHideDelayMs) || 0))
  readonly property string sidebarAutoHideActiveScreenName: sidebarAutohide.activeScreenName
  readonly property bool effectiveSidebarExclusive: sidebarState.exclusive && !sidebarAutoHideEnabled
  // These aliases keep shared services visible inside per-output Variants.
  // Variant delegates have their own lexical scope and cannot resolve sibling
  // ids such as registry or designTokens directly.
  readonly property var menuAppCatalogRef: appCatalog
  readonly property var menuThemeRef: menuTheme
  readonly property var menuDesignTokensRef: designTokens
  readonly property var menuRailDesignTokensRef: railDesignTokens
  readonly property var menuRegistryRef: registry
  readonly property var menuMotionTokensRef: sharedMotion
  readonly property var menuPanelControllerRef: panelController
  property color foreground: menuTheme.foreground
  property color background: menuTheme.background
  property color surfaceBackground: menuTheme.panelBackground
  property color panelColor: surfaceBackground
  property color accent: menuTheme.accent
  property color shellAccent: menuTheme.color("color6")
  property color sessionAccent: menuTheme.color("color11")
  property color dangerAccent: menuTheme.color("color9")
  property color navAccent: menuTheme.soft
  property color muted: menuTheme.muted
  property color providerYoutube: menuTheme.providerYoutube
  property color providerJellyfin: menuTheme.providerJellyfin
  property string version: ""
  property string bodyFontFamily: "Hack Nerd Font Propo"
  property bool compact: compactState.compact
  property real compactProgress: compact ? 1 : 0
  property bool forceCompactRail: false
  property bool railCompact: forceCompactRail ? true : compact
  property string designStyle: lacunaSettings.data && lacunaSettings.data.designStyle ? lacunaSettings.data.designStyle : "lacuna"
  readonly property string barPosition: currentBarPosition()
  readonly property bool topBar: barPosition === "top"
  readonly property bool bottomBar: barPosition === "bottom"
  readonly property bool leftBar: barPosition === "left"
  readonly property bool rightBar: barPosition === "right"
  readonly property bool hostBarHidden: shell && shell.bar && shell.bar.barHidden === true
  readonly property bool barOwnsLacunaFrame: hostManaged || (shell && shell.bar && shell.bar.lacunaFrameHost === true)
  readonly property bool lacunaEnabled: !hostBarHidden
  // Lacuna is its own left sidebar. The Omarchy bar position only affects
  // offsets and sizing, not which edge Lacuna owns.
  readonly property bool panelOnRight: false
  readonly property bool sidebarSurfaceVisible: lacunaEnabled && panelController.menuRenderable
  // Universal shell corners own all molding visibility. Theme/Square radius 0
  // removes connector and frame trim; any positive Theme/Custom radius enables it.
  readonly property bool universalMoldingEnabled: resolvedCornerRadius > 0
  readonly property bool effectiveConnectorPieces: sidebarSurfaceVisible && universalMoldingEnabled && !panelOnRight
  property int defaultTopBarHeight: 26
  property int barHeight: topBarHeight()
  property int fullPanelWidth: Math.round(sizeMix(310, 270))
  property real barControlSize: currentBarSize()
  property int railReferenceBarHeight: Math.max(1, root.topBar && root.barHeight > 0 ? root.barHeight : configBarHeight())
  property int railPanelWidth: Math.round(railReferenceBarHeight)
  property int railButtonWidth: railPanelWidth
  property int railLeftInset: 0
  property int railRightInset: 0
  property int panelWidth: sidebarSurfaceVisible ? (sidebarState.collapsed ? railPanelWidth : fullPanelWidth) : 0
  readonly property int lacunaJoinRadius: designTokens.joinRadius
  readonly property int attachedFlyoutRadius: designTokens.panelRadius
  property int joinRadius: effectiveConnectorPieces ? lacunaJoinRadius : 0
  property int connectorOverlap: effectiveConnectorPieces ? designTokens.connectorOverlap : 0
  property int railTopGap: Math.round(sizeMix(10, 6))
  property int bodyRightInset: effectiveConnectorPieces ? joinRadius : 0
  property int surfaceRightInset: bodyRightInset
  property int settingsConnectorWidth: effectiveConnectorPieces ? joinRadius : 0
  property int barEdgeCasterSize: frameThickness
  property int frameReservePadding: 4
  property int sidebarReserveExtra: 0
  property int flyoutLaneWidth: lacunaEnabled && panelController.menuRenderable ? maxFlyoutWidthFor(sidebarScreen) + panelShadowOutset : 0
  // When the sidebar window is inset around the bar, the bar edge is local
  // y=0. A persistent non-exclusive overlay still starts at screen top and
  // therefore uses the live bar height as its local content offset.
  property int barBottomY: root.topBar && visualTopInset === 0 ? barHeight : 0
  property bool panelVisible: panelController.panelVisible
  readonly property bool settingsPanelOpen: panelController.isFlyoutOpen("settings")
  readonly property bool settingsPanelVisible: panelController.isFlyoutVisible("settings")
  property int settingsPanelWidth: Math.round(sizeMix(560, 500))
  readonly property bool shellSettingsPanelOpen: panelController.isFlyoutOpen("shellSettings")
  readonly property bool shellSettingsPanelVisible: panelController.isFlyoutVisible("shellSettings")
  property int shellSettingsPanelWidth: Math.round(sizeMix(520, 440))
  readonly property bool appPickerOpen: panelController.isFlyoutOpen("appPicker")
  readonly property bool appPickerVisible: panelController.isFlyoutVisible("appPicker")
  readonly property bool mediaPlayerOpen: panelController.isFlyoutOpen("mediaPlayer")
  readonly property bool mediaPlayerVisible: panelController.isFlyoutVisible("mediaPlayer")
  readonly property bool flyoutOpen: panelController.flyoutOpen
  readonly property bool flyoutRenderable: panelController.flyoutRenderable
  readonly property bool flyoutInteractive: panelController.flyoutInteractive
  property string appPickerMode: "customQuickLaunchApp"
  property string preferredAppPickerRole: ""
  property string shellSettingsSection: "apps"
  property int appPickerWidth: Math.round(sizeMix(300, 260))
  property int mediaPlayerWidth: Math.round(sizeMix(420, 360))
  readonly property int maxFlyoutLaneWidth: Math.max(settingsPanelWidth, shellSettingsPanelWidth, appPickerWidth, mediaPlayerWidth)
  readonly property int panelShadowBlurMax: 28
  readonly property int panelShadowOutset: frameShadow ? Math.ceil(panelShadowBlurMax + Math.abs(frameShadowOffsetX)) : 0
  readonly property string visibleFlyout: panelController.visibleFlyout
  readonly property string outgoingFlyout: panelController.outgoingFlyout
  readonly property string retainedFlyout: panelController.retainedFlyout
  readonly property string closingFlyout: panelController.closingFlyout
  readonly property string incomingFlyout: panelController.incomingFlyout
  readonly property string geometryTargetFlyout: incomingFlyout !== "" ? incomingFlyout
    : panelController.activeFlyout !== "" ? panelController.activeFlyout
    : visibleFlyout !== "" ? visibleFlyout
    : outgoingFlyout !== "" ? outgoingFlyout
    : closingFlyout
  readonly property bool activeFlyoutSettings: panelController.activeFlyout === "settings"
  readonly property bool activeFlyoutShellSettings: panelController.activeFlyout === "shellSettings"
  readonly property bool activeFlyoutAppPicker: panelController.activeFlyout === "appPicker"
  readonly property bool activeFlyoutMediaPlayer: panelController.activeFlyout === "mediaPlayer"
  readonly property bool renderSettingsContent: settingsPanelVisible || outgoingFlyout === "settings" || retainedFlyout === "settings" || closingFlyout === "settings"
  readonly property bool renderShellSettingsContent: shellSettingsPanelVisible || outgoingFlyout === "shellSettings" || retainedFlyout === "shellSettings" || closingFlyout === "shellSettings"
  readonly property bool renderAppPickerContent: appPickerVisible || outgoingFlyout === "appPicker" || retainedFlyout === "appPicker" || closingFlyout === "appPicker"
  readonly property bool renderMediaPlayerContent: mediaPlayerVisible || outgoingFlyout === "mediaPlayer" || retainedFlyout === "mediaPlayer" || closingFlyout === "mediaPlayer"
  readonly property int activeFlyoutWidth: activeFlyoutWidthFor(sidebarScreen)
  readonly property int activeFlyoutHeight: activeFlyoutHeightFor(sidebarScreen)
  readonly property int activeFlyoutY: activeFlyoutYFor(sidebarScreen)
  property var panelGeometryByScreen: ({})
  property int panelGeometryRevision: 0
  property var sidebarPaintOcclusionByScreen: ({})
  property int sidebarPaintOcclusionRevision: 0
  readonly property bool frameBorderAttachedFlyoutVisible: lacunaEnabled && panelController.flyoutRenderable && panelController.flyoutProgress > 0.001
  readonly property bool frameBorderAttachedConnectorVisible: frameBorderAttachedFlyoutVisible
    && panelGeometryFor(sidebarScreen).connectorVisible === true
  readonly property real frameBorderWindowY: visualTopInset
  readonly property real frameBorderAttachedFlyoutY: frameBorderAttachedFlyoutYFor(sidebarScreen)
  readonly property real frameBorderAttachedFlyoutHeight: frameBorderAttachedFlyoutHeightFor(sidebarScreen)
  readonly property int frameOverlayWidth: frameOverlayWidthFor(sidebarScreen)
  readonly property bool frameReserveActive: !barOwnsLacunaFrame && lacunaEnabled && effectiveSidebarExclusive && (panelController.menuRenderable || frameMode === "fullframe") && frameMode !== "off"
  readonly property bool sidebarReserveActive: lacunaEnabled && effectiveSidebarExclusive && panelController.menuRenderable && sidebarSurfaceVisible
  readonly property bool frameReserveFlush: frameReserveMode === "flush" || hyprWindowGapsDisabled || (frameReserveMode === "auto" && fakeFullscreenWorkspaceActive())
  readonly property int reservePadding: lacunaEnabled && frameMode !== "off" && !frameReserveFlush ? frameReservePadding : 0
  readonly property int effectiveSidebarReserveExtra: frameReserveFlush ? 0 : sidebarReserveExtra
  readonly property bool externalLeftFrameReserveActive: frameMode === "fullframe" && !root.leftBar && !root.panelOnRight
  readonly property int barOwnedLeftFrameReserve: barOwnsLacunaFrame && externalLeftFrameReserveActive && !sidebarSurfaceVisible ? frameThickness : 0
  readonly property int sidebarReserveSize: sidebarReserveActive ? Math.max(0, panelWidth + effectiveSidebarReserveExtra - barOwnedLeftFrameReserve) : 0
  readonly property int visualTopInset: lacunaEnabled && root.topBar
    && (effectiveSidebarExclusive || sidebarAutoHideEnabled) ? root.barHeight : 0
  // The standalone sidebar border shares the top bar's final pixel row. Pull
  // this Overlay window up by one pixel so both strokes have the same tangent
  // center instead of placing the sidebar curve one pixel below the bar rail.
  readonly property int standaloneBorderWindowOverlap: lacunaEnabled && frameBorder
    && frameMode === "off" && root.topBar ? 1 : 0
  readonly property int visualBottomInset: lacunaEnabled && root.bottomBar
    && (effectiveSidebarExclusive || sidebarAutoHideEnabled) ? root.barHeight : 0
  readonly property int visualLeftInset: lacunaEnabled && root.leftBar
    && (effectiveSidebarExclusive || sidebarAutoHideEnabled) ? root.barControlSize : 0
  readonly property int visualRightInset: lacunaEnabled && root.rightBar
    && (effectiveSidebarExclusive || sidebarAutoHideEnabled) ? root.barControlSize : 0
  readonly property int frameShadowRightReserve: frameShadow ? Math.max(0, frameShadowOffsetX) : 0
  readonly property int frameReserveTop: frameReserveActive && frameMode === "fullframe" && !root.topBar ? frameThickness + reservePadding : 0
  readonly property int frameReserveBottom: frameReserveActive && frameMode === "fullframe" && !root.bottomBar ? frameThickness + reservePadding : 0
  readonly property int frameReserveLeft: frameReserveActive && frameMode === "fullframe" && !root.leftBar && (root.panelOnRight || !root.sidebarSurfaceVisible || sidebarAutoHideEnabled) ? frameThickness + reservePadding : 0
  readonly property int frameReserveRight: frameReserveActive && frameMode === "fullframe" && !root.panelOnRight && !root.rightBar ? frameThickness + reservePadding : 0
  readonly property int topBarShadowReserve: frameReserveActive && root.topBar ? reservePadding : 0
  // Fallback for the standalone menu only: when the Lacuna bar hosts the
  // frame window, that always-mapped surface casts the bar shadow in every
  // frame mode, and it must not be doubled here.
  readonly property bool topBarPanelShadowVisible: lacunaEnabled && !barOwnsLacunaFrame && frameShadow && frameMode === "off" && root.topBar
  readonly property int topBarPanelShadowVisualWidth: topBarPanelShadowVisualWidthFor(sidebarScreen)
  readonly property real topBarPanelShadowX: 0
  readonly property real topBarPanelShadowWidth: topBarPanelShadowVisualWidth
  readonly property real topBarPanelShadowHeight: Math.max(10, Math.round(barEdgeCasterSize * 0.62))
  readonly property real frameOverlayProgress: !lacunaEnabled ? 0 : frameMode === "fullframe" ? 1 : panelController.menuProgress
  property string pendingFlyoutFocus: ""
  property string focusDismissReason: "transition"
  // Semantic debounce for settings activation; deliberately independent of
  // reduced-motion and animation-speed preferences.
  readonly property int flyoutActivationFocusGuardMs: 900
  readonly property bool transitionTraceEnabled: Quickshell.env("LACUNA_TRANSITION_TRACE") === "1"
  property bool pendingSystemRestartConfirmation: false
  property int pluginStateRevision: 0
  property int hyprWorkspaceRevision: 0
  readonly property var shellConfig: shell && shell.shellConfig ? shell.shellConfig : ({})
  readonly property var shellBarConfig: shellConfig && shellConfig.bar ? shellConfig.bar : ({})
  readonly property var shellIdleConfig: shellConfig && shellConfig.idle ? shellConfig.idle : ({})
  readonly property int shellIdleScreensaver: positiveInt(shellIdleConfig.screensaver, 150)
  readonly property int shellIdleLock: positiveInt(shellIdleConfig.lock, 300)
  readonly property var desktopClockSettings: shellPluginSettings("lacuna.desktop-clock", {
    anchor: "bottom-right",
    offsetX: 0,
    offsetY: 0,
    scale: 1,
    use12Hour: false
  })
  readonly property bool desktopClockEnabled: shellPluginEnabled("lacuna.desktop-clock")
  readonly property string desktopClockAnchor: validClockAnchor(desktopClockSettings.anchor)
  readonly property int desktopClockOffsetX: numberSetting(desktopClockSettings.offsetX, 0)
  readonly property int desktopClockOffsetY: numberSetting(desktopClockSettings.offsetY, 0)
  readonly property real desktopClockScale: numberSetting(desktopClockSettings.scale, 1)
  readonly property bool desktopClockUse12Hour: boolSetting(desktopClockSettings.use12Hour, false)
  readonly property var backgroundEffectsSettings: lacunaSettings.data && lacunaSettings.data.backgroundEffects ? lacunaSettings.data.backgroundEffects : ({})
  readonly property var backgroundVignetteSettings: lacunaSettings.data && lacunaSettings.data.backgroundVignette ? lacunaSettings.data.backgroundVignette : ({})
  readonly property var barPresentationSettings: lacunaSettings.data && lacunaSettings.data.barPresentation ? lacunaSettings.data.barPresentation : ({})
  readonly property bool portraitSplit: boolSetting(barPresentationSettings.portraitSplit, true)
  readonly property var mediaProvidersSettings: lacunaSettings.data && lacunaSettings.data.mediaProviders ? lacunaSettings.data.mediaProviders : ({})
  readonly property var shellSettingsSettings: lacunaSettings.data && lacunaSettings.data.shellSettings ? lacunaSettings.data.shellSettings : ({})
  readonly property string shellSettingsSurface: validShellSettingsSurface(shellSettingsSettings.surface)
  readonly property var shellSettingsService: resolveShellSettingsService()
  readonly property var mediaPlayerService: resolveMediaPlayerService()
  readonly property var shellHyprState: shellSettingsService && shellSettingsService.state && shellSettingsService.state.hypr ? shellSettingsService.state.hypr : ({})
  readonly property bool hyprWindowGapsDisabled: shellHyprState.windowGapsEnabled === false || (hyprGapValue(shellHyprState.gapsIn) === 0 && hyprGapValue(shellHyprState.gapsOut) === 0)
  readonly property bool reduceMotionEnabled: lacunaSettings.data && lacunaSettings.data.reduceMotion === true
  readonly property var powerSettings: lacunaSettings.data && lacunaSettings.data.power ? lacunaSettings.data.power : ({})
  readonly property bool instantRestart: boolSetting(powerSettings.instantRestart, false)
  readonly property var geometrySettings: lacunaSettings.data && lacunaSettings.data.geometry ? lacunaSettings.data.geometry : ({})
  readonly property string cornerMode: validCornerMode(geometrySettings.cornerMode)
  readonly property int customCornerRadius: Math.max(0, Math.min(32, Math.round(numberSetting(geometrySettings.cornerRadius, 14))))
  readonly property int resolvedCornerRadius: cornerMode === "square" ? 0
    : (cornerMode === "custom" ? customCornerRadius : Math.max(0, Math.round(Style.cornerRadius)))
  property bool cornerWindowSyncReady: false
  onCornerModeChanged: if (cornerWindowSyncReady) cornerWindowSyncTimer.restart()
  onCustomCornerRadiusChanged: if (cornerWindowSyncReady && cornerMode === "custom") cornerWindowSyncTimer.restart()
  readonly property var frameSettings: lacunaSettings.data && lacunaSettings.data.frame ? lacunaSettings.data.frame : ({})
  readonly property string frameMode: validFrameMode(frameSettings.mode)
  readonly property string frameReserveMode: validFrameReserveMode(frameSettings.reserveMode)
  readonly property bool frameShadow: boolSetting(frameSettings.shadow, false)
  readonly property bool frameBorder: boolSetting(frameSettings.border, false)
  readonly property bool frameMoldingPieces: universalMoldingEnabled
  readonly property int frameThickness: positiveInt(frameSettings.thickness, 8)
  readonly property int frameRadius: resolvedCornerRadius
  readonly property int frameShadowOffsetX: numberSetting(frameSettings.shadowOffsetX, 2)
  readonly property int frameShadowOffsetY: numberSetting(frameSettings.shadowOffsetY, 3)
  // The default policy follows the focused Hyprland output. Pinned mode keeps
  // the sidebar on the configured output set, and all mode mirrors it to every
  // live output. The settings-state helper reads the same focused monitor that
  // Omarchy exposes to its shell settings.
  readonly property var sidebarSettingsData: lacunaSettings.data && lacunaSettings.data.sidebar
    ? lacunaSettings.data.sidebar : ({})
  readonly property string sidebarMonitorPolicy: MonitorPolicy.normalizeMonitorPolicy(sidebarSettingsData.monitorPolicy)
  readonly property string liveFocusedMonitorName: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor
    ? String(Hyprland.focusedWorkspace.monitor.name || "")
    : (Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : "")
  property string settledFocusedMonitorName: ""
  readonly property string focusedMonitorName: settledFocusedMonitorName !== ""
    ? settledFocusedMonitorName
    : (liveFocusedMonitorName !== "" ? liveFocusedMonitorName
    : (shellSettingsService && shellSettingsService.focusedMonitorName ? String(shellSettingsService.focusedMonitorName) : "")
    )
  // Auto means workspace focus owns the sidebar. A popup's source screen is
  // useful for choosing an interaction surface in mirrored/pinned modes, but
  // must never become a sticky override that effectively pins auto mode.
  readonly property string activeMonitorName: sidebarMonitorPolicy === "auto" || requestedInteractionMonitorName === ""
    ? focusedMonitorName : requestedInteractionMonitorName
  readonly property var sidebarMonitorNames: MonitorPolicy.normalizeMonitorNames(sidebarSettingsData.monitorNames)
  readonly property var sidebarScreens: MonitorPolicy.chooseSidebarScreens(Quickshell.screens, sidebarMonitorPolicy, activeMonitorName, sidebarMonitorNames)
  readonly property var sidebarScreen: MonitorPolicy.choosePrimarySidebarScreen(Quickshell.screens, sidebarMonitorPolicy, activeMonitorName, sidebarMonitorNames)
  readonly property var flyoutScreen: MonitorPolicy.chooseFlyoutScreen(Quickshell.screens, sidebarMonitorPolicy, activeMonitorName, sidebarMonitorNames)
  readonly property var sidebarMonitorOptions: MonitorPolicy.monitorOptions(Quickshell.screens, sidebarMonitorNames)

  onLiveFocusedMonitorNameChanged: {
    if (liveFocusedMonitorName !== "") monitorHandoffTimer.restart()
  }

  onSidebarScreensChanged: Qt.callLater(root.syncSidebarAutohideScreens)
  onSidebarAutoHideEnabledChanged: {
    Qt.callLater(root.syncSidebarAutohideScreens)
    if (sidebarAutoHideEnabled) {
      focusDismissReason = "autohide-enabled"
      pendingFlyoutFocus = ""
      panelController.closeActiveFlyout()
      panelController.closeMenu()
    } else if (initialSidebarDefaultApplied) {
      applySidebarDefaultState()
    }
  }

  function sidebarVisibleOnScreen(screen) {
    if (!sidebarSurfaceVisible || !MonitorPolicy.isSidebarScreen(sidebarScreens, screen)
        || fullscreenWorkspaceOnScreen(screen)) return false
    if (!sidebarAutoHideEnabled) return true
    return MonitorPolicy.screenName(screen) === sidebarAutoHideActiveScreenName
  }

  function sidebarAutohideScreenName(screen) {
    return MonitorPolicy.screenName(screen)
  }

  function sidebarScreenNames() {
    var names = []
    var screens = sidebarScreens || []
    for (var i = 0; i < screens.length; i++) {
      var name = MonitorPolicy.screenName(screens[i])
      if (name !== "") names.push(name)
    }
    return names
  }

  function syncSidebarAutohideScreens() {
    sidebarAutohide.setEligibleScreens(sidebarScreenNames())
  }

  function setSidebarAutohideContentHeld(screen, held) {
    var name = sidebarAutohideScreenName(screen)
    if (name === "") return
    var next = {}
    for (var key in autohideContentHolds) next[key] = autohideContentHolds[key]
    if (held === true) next[name] = true
    else delete next[name]
    autohideContentHolds = next
  }

  function sidebarAutohideContentHeld() {
    var name = sidebarAutoHideActiveScreenName
    return name !== "" && autohideContentHolds[name] === true
  }

  function sidebarAutohideRequestScreenName() {
    var requested = requestedInteractionMonitorName
    if (requested !== "" && sidebarAutohide.screenEligible(requested)) return requested
    var screen = flyoutScreen || sidebarScreen
    return MonitorPolicy.screenName(screen)
  }

  function revealSidebarFromAutohide(screenName, reason) {
    if (!sidebarAutoHideEnabled || !lacunaEnabled) return
    requestedInteractionMonitorName = String(screenName || "")
    panelController.openMenu()
  }

  function concealSidebarFromAutohide(reason) {
    if (!sidebarAutoHideEnabled) return
    focusDismissReason = String(reason || "pointer-leave")
    pendingFlyoutFocus = ""
    panelController.closeActiveFlyout()
    panelController.closeMenu()
  }

  function ownsHostFrameBorderOnScreen(screen) {
    return hostManaged && hostFrameBorderEnabled && lacunaEnabled
      && !fullscreenWorkspaceOnScreen(screen)
      && frameMode === "fullframe"
      && typeof hostFrameGeometryProvider === "function"
      && MonitorPolicy.isSidebarScreen(sidebarScreens, screen)
  }

  function hostBarPopoutBorderGapFor(screen) {
    if (!ownsHostFrameBorderOnScreen(screen)
        || typeof hostBarPopoutBorderGapProvider !== "function") return null
    var source = hostBarPopoutBorderGapProvider(screen)
    if (!source || typeof source !== "object") return null
    var edge = String(source.edge || "")
    var axisInset = edge === "top" || edge === "bottom" ? visualLeftInset : visualTopInset
    return {
      edge: edge,
      start: Number(source.start || 0) - axisInset,
      length: Math.max(0, Number(source.length || 0))
    }
  }

  function hostFrameGeometryFor(screen) {
    if (!ownsHostFrameBorderOnScreen(screen)) return null
    var source = hostFrameGeometryProvider(screen)
    if (!source || typeof source !== "object") return null
    var record = {}
    for (var key in source) record[key] = source[key]
    // The exclusive menu window begins inside its bar edge; authoritative bar
    // geometry is monitor-local. Translate once into this window's coordinates.
    record.holeX = Number(source.holeX) - visualLeftInset
    record.holeRight = Number(source.holeRight) - visualLeftInset
    record.holeY = Number(source.holeY) - visualTopInset
    record.holeBottom = Number(source.holeBottom) - visualTopInset
    return record
  }

  function flyoutTargetsScreen(screen) {
    if (!screen || !flyoutScreen) return false
    if (flyoutScreen === screen) return true
    var targetName = MonitorPolicy.screenName(flyoutScreen)
    var screenName = MonitorPolicy.screenName(screen)
    return targetName !== "" && targetName === screenName
  }

  function flyoutVisibleOnScreen(screen) {
    if (!flyoutRenderable || fullscreenWorkspaceOnScreen(screen)) return false
    return flyoutTargetsScreen(screen)
  }

  function flyoutOpenOnScreen(screen) {
    return flyoutOpen && flyoutVisibleOnScreen(screen)
  }

  function flyoutInteractiveOnScreen(screen) {
    return flyoutInteractive && flyoutOpenOnScreen(screen)
  }

  function flyoutLaneWidthFor(screen, effectiveConnectorWidth) {
    // Reserve the larger complete extent of connector-off and connector-on
    // targets, then subtract the transaction's effective connector width.
    // panel + effective connector + lane is therefore constant on both bounded
    // and unconstrained outputs throughout either toggle direction.
    if (!sidebarVisibleOnScreen(screen)) return 0
    return Math.max(0, maxFlyoutExtentFor(screen)
      - Math.max(0, Number(effectiveConnectorWidth) || 0) + panelShadowOutset)
  }

  function frameBorderAttachedFlyoutVisibleOnScreen(screen) {
    return frameBorderAttachedFlyoutVisible && flyoutVisibleOnScreen(screen)
  }

  Behavior on compactProgress {
    NumberAnimation {
      duration: root.menuMotionTokensRef.quick
      easing.type: Easing.OutCubic
    }
  }

  Behavior on barControlSize {
    NumberAnimation {
      duration: root.menuMotionTokensRef.quick
      easing.type: Easing.OutCubic
    }
  }

  onLacunaEnabledChanged: {
    if (!lacunaEnabled) {
      focusDismissReason = "shell-rescan"
      pendingFlyoutFocus = ""
      panelController.closeMenu()
    } else {
      applyInitialSidebarDefault()
    }
  }

  onFlyoutContentRegistered: root.applyPendingFlyoutFocus()

  function localPath(url) {
    return valueHelpers.localPath(url)
  }

  function screenNamespace(screen) {
    var name = MonitorPolicy.screenName(screen)
    return name === "" ? "screen" : name.replace(/[^A-Za-z0-9_-]/g, "-")
  }

  function registerFlyoutContent(screen, kind, content) {
    if (!screen || !kind || !content) return

    var next = {}
    for (var screenKey in flyoutContentRefs) {
      var screenRefs = flyoutContentRefs[screenKey]
      var copied = {}
      for (var kindKey in screenRefs) copied[kindKey] = screenRefs[kindKey]
      next[screenKey] = copied
    }

    var key = screenNamespace(screen)
    if (!next[key]) next[key] = {}
    next[key][String(kind)] = content
    flyoutContentRefs = next
    flyoutContentRegistered(String(kind))
  }

  function unregisterFlyoutContent(screen, kind, content) {
    if (!screen || !kind) return

    var key = screenNamespace(screen)
    var existing = flyoutContentRefs[key]
    if (!existing || (content && existing[String(kind)] !== content)) return

    var next = {}
    for (var screenKey in flyoutContentRefs) {
      var screenRefs = flyoutContentRefs[screenKey]
      var copied = {}
      for (var kindKey in screenRefs) copied[kindKey] = screenRefs[kindKey]
      next[screenKey] = copied
    }
    delete next[key][String(kind)]
    flyoutContentRefs = next
  }

  function activeFlyoutContent(kind) {
    if (!flyoutScreen) return null
    var screenRefs = flyoutContentRefs[screenNamespace(flyoutScreen)]
    return screenRefs && screenRefs[String(kind)] ? screenRefs[String(kind)] : null
  }

  function flyoutContentOpacity(kind) {
    return panelController.contentSwitchOpacity(kind)
  }

  function resolvedOmarchyPath() {
    return root.omarchyPath || Quickshell.env("OMARCHY_PATH") || (Quickshell.env("HOME") + "/.local/share/omarchy")
  }

  function resolveLacunaSettings() {
    if (root.shell && typeof root.shell.ensureService === "function") {
      var ensured = root.shell.ensureService("lacuna.state")
      if (ensured) return ensured
    }
    if (root.shell && typeof root.shell.serviceFor === "function") {
      var service = root.shell.serviceFor("lacuna.state")
      if (service) return service
    }
    return localLacunaSettings
  }

  function resolveShellSettingsService() {
    if (root.shell && typeof root.shell.ensureService === "function") {
      var ensured = root.shell.ensureService("lacuna.shell-settings")
      if (ensured) return ensured
    }
    if (root.shell && typeof root.shell.serviceFor === "function") {
      var service = root.shell.serviceFor("lacuna.shell-settings")
      if (service) return service
    }
    return localShellSettingsService
  }

  function resolveMediaPlayerService() {
    if (root.shell && typeof root.shell.ensureService === "function") {
      var ensured = root.shell.ensureService("lacuna.media-player")
      if (ensured) return ensured
    }
    if (root.shell && typeof root.shell.serviceFor === "function") {
      var service = root.shell.serviceFor("lacuna.media-player")
      if (service) return service
    }
    return null
  }

  function applyInitialSidebarDefault() {
    if (root.initialSidebarDefaultApplied) return
    if (!sidebarSettingsLoaded()) {
      initialSidebarDefaultRetry.restart()
      return
    }
    Qt.callLater(root.applyInitialSidebarDefaultNow)
  }

  function applyInitialSidebarDefaultNow() {
    if (root.initialSidebarDefaultApplied) return
    if (!sidebarSettingsLoaded()) {
      initialSidebarDefaultRetry.restart()
      return
    }
    if (!applySidebarDefaultState()) {
      initialSidebarDefaultRetry.restart()
      return
    }
    root.initialSidebarDefaultApplied = true
  }

  function shellIpcCommand(target, method, args) {
    var path = resolvedOmarchyPath()
    var command = "OMARCHY_PATH=" + commands.quote(path) + " omarchy shell"
      + " " + commands.quote(target) + " " + commands.quote(method)
    for (var i = 0; i < args.length; i++) command += " " + commands.quote(args[i])
    return command
  }

  function positiveInt(value, fallback) {
    return valueHelpers.positiveInt(value, fallback)
  }

  function sizeMix(fullValue, compactValue) {
    return Number(fullValue) + (Number(compactValue) - Number(fullValue)) * compactProgress
  }

  function safeValue(value, fallback) {
    return valueHelpers.safeValue(value, fallback)
  }

  function configBarHeight() {
    var barConfig = shell && shell.barConfig ? shell.barConfig : null
    if (!barConfig || typeof barConfig !== "object") return defaultTopBarHeight
    return positiveInt(barConfig.height !== undefined ? barConfig.height : barConfig.size, defaultTopBarHeight)
  }

  function currentBarSize() {
    var liveBar = shell && shell.bar ? shell.bar : null
    var verticalFallback = (barPosition === "left" || barPosition === "right") ? 28 : configBarHeight()
    if (hostBarSize > 0) return positiveInt(hostBarSize, verticalFallback)
    if (liveBar && liveBar.barSize !== undefined) return positiveInt(liveBar.barSize, verticalFallback)
    return verticalFallback
  }

  function currentBarPosition() {
    var liveBar = shell && shell.bar ? shell.bar : null
    var livePosition = liveBar && liveBar.position ? String(liveBar.position) : ""
    var configPosition = shell && shell.barConfig && shell.barConfig.position ? String(shell.barConfig.position) : ""
    var shellConfigPosition = shell && shell.shellConfig && shell.shellConfig.bar && shell.shellConfig.bar.position
      ? String(shell.shellConfig.bar.position) : ""

    // shell.bar can briefly expose its default before the persisted config is
    // applied. Prefer the config source for offset and size decisions.
    return configPosition || shellConfigPosition || livePosition || "top"
  }

  function topBarHeight() {
    var liveBar = shell && shell.bar ? shell.bar : null
    var position = currentBarPosition()

    if (position !== "top") return 0
    if (hostBarSize > 0) return positiveInt(hostBarSize, configBarHeight())
    if (liveBar && !liveBar.barHidden && liveBar.barSize !== undefined) {
      return positiveInt(liveBar.barSize, configBarHeight())
    }
    return configBarHeight()
  }

  function sidebarWindowHeightFor(screen) {
    var screenHeight = screen && screen.height !== undefined ? Number(screen.height) : 1080
    if (!isFinite(screenHeight) || screenHeight <= 0) screenHeight = 1080
    return Math.max(1, Math.round(screenHeight) - visualTopInset - visualBottomInset)
  }

  function preferredFlyoutWidth(kind) {
    if (kind === "settings") return settingsPanelWidth
    if (kind === "shellSettings") return shellSettingsPanelWidth
    if (kind === "appPicker") return appPickerWidth
    if (kind === "mediaPlayer") return mediaPlayerWidth
    return 0
  }

  function preferredFlyoutHeight(kind) {
    if (kind === "appPicker") return compact ? 430 : 520
    if (kind === "mediaPlayer") return compact ? 520 : 600
    return compact ? 560 : 660
  }

  function flyoutGeometryFor(screen, kind, connectorWidthOverride) {
    var windowHeight = sidebarWindowHeightFor(screen)
    var screenWidth = screen && screen.width !== undefined ? Number(screen.width) : 1920
    if (!isFinite(screenWidth) || screenWidth <= 0) screenWidth = 1920
    var topLimit = barBottomY + designTokens.topInset
    var preferredHeight = preferredFlyoutHeight(kind)
    var preferredY = kind === "appPicker"
      ? topLimit + (compact ? 38 : 52)
      : windowHeight - preferredHeight - designTokens.bottomInset - (compact ? 72 : 112)
    var geometryConnectorWidth = connectorWidthOverride === undefined
      ? settingsConnectorWidth : Math.max(0, Number(connectorWidthOverride) || 0)
    return MenuFlyoutGeometry.boundedGeometry({
      screenWidth: screenWidth,
      screenHeight: windowHeight,
      leftInset: panelWidth + geometryConnectorWidth,
      rightInset: panelShadowOutset + designTokens.contentInset,
      topInset: topLimit,
      bottomInset: designTokens.bottomInset,
      preferredWidth: preferredFlyoutWidth(kind),
      preferredHeight: preferredHeight,
      preferredY: preferredY
    })
  }

  function maxFlyoutWidthFor(screen) {
    var kinds = ["settings", "shellSettings", "appPicker", "mediaPlayer"]
    var width = 0
    for (var i = 0; i < kinds.length; i++) width = Math.max(width, flyoutGeometryFor(screen, kinds[i]).width)
    return width
  }

  function maxFlyoutExtentFor(screen) {
    var kinds = ["settings", "shellSettings", "appPicker", "mediaPlayer"]
    var connectorWidth = Math.max(0, Number(designTokens.joinRadius) || 0)
    var extent = 0
    for (var i = 0; i < kinds.length; i++) {
      var withoutConnector = flyoutGeometryFor(screen, kinds[i], 0).width
      var withConnector = connectorWidth + flyoutGeometryFor(screen, kinds[i], connectorWidth).width
      extent = Math.max(extent, withoutConnector, withConnector)
    }
    // Independently snapped flyout and connector widths can sum to one pixel
    // above both endpoints for odd connector sizes. Reserve that pixel here.
    return extent + 1
  }

  function activeFlyoutKind() {
    if (activeFlyoutSettings) return "settings"
    if (activeFlyoutShellSettings) return "shellSettings"
    if (activeFlyoutAppPicker) return "appPicker"
    if (activeFlyoutMediaPlayer) return "mediaPlayer"
    return ""
  }

  function activeFlyoutWidthFor(screen) {
    var kind = activeFlyoutKind()
    return kind === "" ? 0 : flyoutGeometryFor(screen, kind).width
  }

  function activeFlyoutHeightFor(screen) {
    var kind = activeFlyoutKind()
    return kind === "" ? 0 : flyoutGeometryFor(screen, kind).height
  }

  function activeFlyoutYFor(screen) {
    var kind = activeFlyoutKind()
    return kind === "" ? 0 : flyoutGeometryFor(screen, kind).y
  }

  function publishSidebarPaintOcclusion(screen, width) {
    var key = screenNamespace(screen)
    var next = {}
    for (var existing in sidebarPaintOcclusionByScreen)
      next[existing] = sidebarPaintOcclusionByScreen[existing]
    next[key] = Math.max(0, Number(width) || 0)
    sidebarPaintOcclusionByScreen = next
    sidebarPaintOcclusionRevision += 1
  }

  function sidebarPaintOcclusionWidthFor(screen) {
    sidebarPaintOcclusionRevision
    return Math.max(0, Number(sidebarPaintOcclusionByScreen[screenNamespace(screen)]) || 0)
  }

  function publishPanelGeometry(screen, host) {
    if (!host) return
    var key = screenNamespace(screen)
    var next = {}
    for (var existing in panelGeometryByScreen) next[existing] = panelGeometryByScreen[existing]
    next[key] = {
      x: host.flyoutMaskX,
      y: host.effectiveFlyoutY,
      width: host.effectiveFlyoutWidth,
      height: host.effectiveFlyoutHeight,
      connectorWidth: host.effectiveConnectorWidth,
      connectorVisible: host.effectiveConnectorVisible,
      revision: host.panelGeometryRevision,
      key: host.targetPanelGeometryKey
    }
    panelGeometryByScreen = next
    panelGeometryRevision += 1
  }

  function panelGeometryFor(screen) {
    panelGeometryRevision
    var value = panelGeometryByScreen[screenNamespace(screen)]
    if (value && typeof value === "object") return value
    return { x: 0, y: 0, width: 0, height: 0, connectorWidth: 0, connectorVisible: false }
  }

  function frameShadowAttachedFlyoutXFor(screen) {
    var geometry = panelGeometryFor(screen)
    if (panelOnRight) return Math.max(0, Number(geometry.x) || 0)
    return sidebarPaintOcclusionWidthFor(screen)
  }

  function frameShadowAttachedFlyoutWidthFor(screen) {
    var geometry = panelGeometryFor(screen)
    var x = frameShadowAttachedFlyoutXFor(screen)
    var sidebarEdge = panelOnRight
      ? Math.max(0, Number(screen && screen.width || 0) - sidebarPaintOcclusionWidthFor(screen))
      : Math.max(x, (Number(geometry.x) || 0) + (Number(geometry.width) || 0))
    return Math.max(0, sidebarEdge - x)
  }

  function frameBorderAttachedFlyoutYFor(screen) {
    var geometry = panelGeometryFor(screen)
    var connectorVisible = geometry.connectorVisible === true && flyoutVisibleOnScreen(screen)
    return frameBorderWindowY + (connectorVisible ? geometry.y - geometry.connectorWidth : geometry.y)
  }

  function frameBorderAttachedFlyoutHeightFor(screen) {
    var geometry = panelGeometryFor(screen)
    var connectorVisible = geometry.connectorVisible === true && flyoutVisibleOnScreen(screen)
    return connectorVisible ? geometry.height + geometry.connectorWidth * 2 : geometry.height
  }

  function frameOverlayWidthFor(screen) {
    if (!lacunaEnabled || frameMode === "off") return 0
    if (barOwnsLacunaFrame && !ownsHostFrameBorderOnScreen(screen)) return 0
    var width = screen && screen.width !== undefined ? Number(screen.width) : 0
    return Math.max(0, Math.round(width) + 100)
  }

  function topBarPanelShadowVisualWidthFor(screen) {
    if (!topBarPanelShadowVisible || !screen) return 0
    return Math.max(0, Math.round(Number(screen.width) || 0))
  }

  function validShellSettingsSurface(value) {
    return valueHelpers.validShellSettingsSurface(value)
  }

  function open(payloadJson) {
    if (!lacunaEnabled) return
    var payload = openPayload(payloadJson)
    requestedInteractionMonitorName = payload && payload.popupContext && payload.popupContext.screenName
      ? String(payload.popupContext.screenName) : ""
    if (sidebarAutoHideEnabled) {
      var targetName = sidebarAutohideRequestScreenName()
      if (!sidebarAutohide.explicitOpen(targetName)) return
    } else {
      panelController.openMenu()
    }
    openPayloadFlyout(payload)
  }

  function openPayload(payloadJson) {
    if (!payloadJson) return ({})
    try {
      var parsed = JSON.parse(String(payloadJson))
      return parsed && typeof parsed === "object" ? parsed : ({})
    } catch (error) {
      return ({})
    }
  }

  function openPayloadFlyout(payload) {
    var flyout = payload && payload.flyout ? String(payload.flyout) : ""
    if (flyout === "") return

    if (flyout === "settings") {
      if (payload.section) settingsSection = String(payload.section)
      panelController.openFlyout("settings")
      if (sidebarState.collapsed) sidebarState.expand()
      requestFlyoutFocus("settings")
      return
    }

    if (flyout === "shellSettings") {
      shellSettingsSection = String(payload.section || "apps")
      panelController.openFlyout("shellSettings")
      requestFlyoutFocus("shellSettings")
      return
    }

    if (flyout === "appPicker") {
      openCustomQuickLaunchPicker()
      return
    }

    if (flyout === "mediaPlayer") {
      openMediaPlayerPanel()
    }
  }

  function close() {
    focusDismissReason = "explicit-close"
    pendingFlyoutFocus = ""
    if (sidebarAutoHideEnabled) sidebarAutohide.explicitClose("explicit-close")
    else panelController.closeMenu()
  }

  function closeFlyouts(reason) {
    var nextReason = String(reason || "explicit-close")
    traceSurface("dismiss:" + nextReason)
    // Settings activation can transiently clear focus. Suppress only that
    // click-away path; explicit keyboard and close-button intent always wins.
    if (flyoutFocusClearHold.running && nextReason === "click-away") return
    focusDismissReason = nextReason
    pendingFlyoutFocus = ""
    panelController.closeActiveFlyout()
  }

  function holdFlyoutAfterSettingsActivation() {
    flyoutFocusClearHold.restart()
  }

  function traceSurface(event) {
    if (!transitionTraceEnabled) return
    panelController.trace(event, {
      pendingFlyoutFocus: pendingFlyoutFocus,
      sidebarSurfaceVisible: sidebarSurfaceVisible,
      sidebarCollapsed: sidebarState.collapsed,
      panelWidth: panelWidth,
      sidebarReserveSize: sidebarReserveSize,
      focusedMonitor: focusedMonitorName,
      sidebarScreen: sidebarScreen ? String(sidebarScreen.name || "") : "",
      flyoutScreen: flyoutScreen ? String(flyoutScreen.name || "") : ""
    })
  }

  // While this one-shot is running, closeFlyouts() is suppressed so a focus
  // change triggered by activating a settings control does not immediately
  // dismiss the flyout it just opened.
  Timer {
    id: flyoutFocusClearHold
    interval: root.flyoutActivationFocusGuardMs
    repeat: false
  }

  Timer {
    id: initialSidebarDefaultRetry
    interval: 80
    repeat: false
    onTriggered: root.applyInitialSidebarDefaultNow()
  }

  function sidebarSettingsLoaded() {
    return lacunaSettings && lacunaSettings.hasLoaded === true
  }

  function applySidebarDefaultState() {
    if (!lacunaEnabled) return false
    if (!sidebarSettingsLoaded()) return false

    var mode = sidebarDefaultMode()
    focusDismissReason = "explicit-close"
    pendingFlyoutFocus = ""
    panelController.closeActiveFlyout()
    if (sidebarAutoHideEnabled) {
      sidebarAutohide.explicitHeld = false
      panelController.closeMenu()
      return true
    }
    if (menuState) {
      menuState.stack = ["main"]
      if (typeof menuState.save === "function") menuState.save()
    }

    if (mode === "rail") {
      sidebarState.setDisplay("rail")
      panelController.openMenu()
      return true
    }

    if (mode === "full") {
      sidebarState.setDisplay("full")
      panelController.openMenu()
      return true
    }

    sidebarState.setDisplay("full")
    panelController.closeMenu()
    return true
  }

  function sidebarDefaultMode() {
    var sidebar = sidebarSettingsData
    var mode = sidebar && sidebar.defaultMode !== undefined ? String(sidebar.defaultMode).toLowerCase() : String(sidebarState.defaultMode || "off").toLowerCase()
    if (mode === "rail" || mode === "full") return mode
    return "off"
  }

  function setSidebarMonitorPolicy(policy) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    var normalized = MonitorPolicy.normalizeMonitorPolicy(policy)
    next.sidebar.monitorPolicy = normalized
    next.sidebar.monitorNames = MonitorPolicy.normalizeMonitorNames(next.sidebar.monitorNames)

    if (normalized === "pinned" && next.sidebar.monitorNames.length === 0) {
      var seed = MonitorPolicy.chooseFocusedScreen(Quickshell.screens, focusedMonitorName)
      var seedName = MonitorPolicy.screenName(seed)
      if (seedName !== "") next.sidebar.monitorNames = [seedName]
    }

    lacunaSettings.save(next, false, true)
  }

  function toggleSidebarMonitor(name, enabled) {
    var target = String(name || "").trim()
    if (target === "") return

    var next = lacunaSettings.normalize(lacunaSettings.data)
    var names = MonitorPolicy.normalizeMonitorNames(next.sidebar.monitorNames)
    var index = names.indexOf(target)
    if (enabled === true && index < 0) names.push(target)
    if (enabled !== true && index >= 0) names.splice(index, 1)
    next.sidebar.monitorNames = MonitorPolicy.normalizeMonitorNames(names)
    lacunaSettings.save(next, false, true)
  }

  function sidebarDefaultKeepsMenuOpen() {
    if (!sidebarSettingsLoaded()) return true
    if (sidebarAutoHideEnabled) return false
    var mode = sidebarDefaultMode()
    return mode === "rail" || mode === "full"
  }

  function viewToneAccent() {
    return root.accent
  }

  function setDesignStyle(style) {
    var nextStyleSettings = lacunaSettings.normalize(lacunaSettings.data)
    nextStyleSettings.designStyle = lacunaSettings.normalizeDesignStyle(style)
    lacunaSettings.save(nextStyleSettings)
  }

  function setControlsLayout(layout) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.controlsLayout = layout === "list" ? "list" : "grid"
    lacunaSettings.save(next)
  }

  function setShortcutsLayout(layout) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.shortcutsLayout = layout === "grid" ? "grid" : "list"
    lacunaSettings.save(next)
  }

  function setShellSettingsSurface(surface) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.shellSettings || typeof next.shellSettings !== "object") next.shellSettings = {}
    next.shellSettings.surface = validShellSettingsSurface(surface)
    lacunaSettings.save(next)
  }

  function setDailyLaunchLayout(layout) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.dailyLaunchLayout = layout === "grid" ? "grid" : "list"
    lacunaSettings.save(next)
  }

  function setQuickLaunchLayout(layout) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.quickLaunchLayout = layout === "grid" ? "grid" : "list"
    lacunaSettings.save(next)
  }

  function customQuickLaunchContains(id) {
    var ids = lacunaSettings.data && lacunaSettings.data.customQuickLaunchApps ? lacunaSettings.data.customQuickLaunchApps : []
    for (var i = 0; i < ids.length; i++) {
      if (String(ids[i]) === String(id)) return true
    }
    return false
  }

  function addCustomQuickLaunchApp(id) {
    if (!id || customQuickLaunchContains(id)) return

    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.customQuickLaunchApps = next.customQuickLaunchApps.concat([String(id)]).slice(0, 12)
    lacunaSettings.save(next, true)
  }

  function moveCustomQuickLaunchApp(id, targetIndex) {
    var appId = String(id || "")
    if (appId === "") return

    var next = lacunaSettings.normalize(lacunaSettings.data)
    var ids = next.customQuickLaunchApps.slice()
    var from = ids.indexOf(appId)
    if (from < 0) return

    var target = Math.max(0, Math.min(ids.length, Math.round(Number(targetIndex) || 0)))
    ids.splice(from, 1)
    if (target > from) target--
    target = Math.max(0, Math.min(ids.length, target))
    if (target === from) return

    ids.splice(target, 0, appId)
    next.customQuickLaunchApps = ids
    lacunaSettings.save(next, true)
  }

  function renameCustomQuickLaunchApp(id, label) {
    var appId = String(id || "")
    if (appId === "" || !customQuickLaunchContains(appId)) return

    var next = lacunaSettings.normalize(lacunaSettings.data)
    var names = {}
    var source = next.customQuickLaunchNames || {}
    for (var key in source) names[key] = source[key]

    var trimmed = String(label || "").trim().slice(0, 48)
    if (trimmed === "") delete names[appId]
    else names[appId] = trimmed

    next.customQuickLaunchNames = names
    lacunaSettings.save(next, true)
  }

  function removeCustomQuickLaunchApp(id) {
    var appId = String(id || "")
    if (appId === "" || !customQuickLaunchContains(appId)) return

    var next = lacunaSettings.normalize(lacunaSettings.data)
    var ids = []
    var sourceIds = next.customQuickLaunchApps || []
    for (var i = 0; i < sourceIds.length; i++) {
      if (String(sourceIds[i]) !== appId) ids.push(String(sourceIds[i]))
    }

    var names = {}
    var sourceNames = next.customQuickLaunchNames || {}
    for (var key in sourceNames) {
      if (String(key) !== appId) names[key] = sourceNames[key]
    }

    next.customQuickLaunchApps = ids
    next.customQuickLaunchNames = names
    lacunaSettings.save(next, true)
  }

  function setPreferredApp(role, id) {
    if (!role) return

    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.preferredApps[role] = String(id || "system").trim() || "system"
    lacunaSettings.save(next)
    closeFlyouts("explicit-close")
  }

  function openCustomQuickLaunchPicker() {
    if (!lacunaEnabled) return

    if (appPickerOpen && appPickerMode === "customQuickLaunchApp") {
      closeFlyouts("explicit-close")
      return
    }

    if (!appCatalog.ready) appCatalog.reload()
    var picker = activeFlyoutContent("appPicker")
    if (picker) picker.resetSearch()
    appPickerMode = "customQuickLaunchApp"
    preferredAppPickerRole = ""
    panelController.openFlyout("appPicker")
    if (sidebarState.collapsed) sidebarState.expand()
    requestFlyoutFocus("appPicker")
  }

  function openPreferredAppPicker(role) {
    if (!lacunaEnabled) return

    if (!appCatalog.ready) appCatalog.reload()
    var picker = activeFlyoutContent("appPicker")
    if (picker) picker.resetSearch()
    appPickerMode = "preferredApp"
    preferredAppPickerRole = role
    panelController.openFlyout("appPicker")
    if (sidebarState.collapsed) sidebarState.expand()
    requestFlyoutFocus("appPicker")
  }

  function openMediaPlayerPanel() {
    if (!lacunaEnabled || !mediaPlayerService) return
    panelController.openFlyout("mediaPlayer")
    if (sidebarState.collapsed) sidebarState.expand()
    requestFlyoutFocus("mediaPlayer")
  }

  function toggleSettingsPanel() {
    if (!lacunaEnabled) return
    if (settingsPanelOpen) {
      closeFlyouts("explicit-close")
      return
    }
    panelController.openFlyout("settings")
    if (!menuState.open) panelController.openMenu()
    requestFlyoutFocus("settings")
  }

  function openSettingsSection(sectionId) {
    if (!lacunaEnabled) return

    var nextSection = String(sectionId || "overview")
    if (settingsPanelOpen && settingsSection === nextSection) {
      closeFlyouts("explicit-close")
      return
    }

    settingsSection = nextSection
    panelController.openFlyout("settings")
    if (sidebarState.collapsed) sidebarState.expand()
    requestFlyoutFocus("settings")
  }

  function openShellSettingsPanel(sectionId) {
    if (root.shellSettingsSurface === "flyout") {
      openShellSettingsSection(sectionId)
      return
    }

    var payload = JSON.stringify({ section: String(sectionId || "apps") })
    if (root.shell && typeof root.shell.summon === "function") {
      root.shell.summon("lacuna.shell-settings", payload)
      return
    }
    commands.run(shellIpcCommand("shell", "summon", ["lacuna.shell-settings", payload]))
  }

  function toggleShellSettingsPanel() {
    openShellSettingsPanel("apps")
  }

  function openShellSettingsSection(sectionId) {
    if (!lacunaEnabled) return

    var nextSection = String(sectionId || "apps")
    if (shellSettingsPanelOpen && shellSettingsSection === nextSection) {
      closeFlyouts("explicit-close")
      return
    }

    shellSettingsSection = nextSection
    panelController.openFlyout("shellSettings")
    requestFlyoutFocus("shellSettings")
  }

  function requestFlyoutFocus(id) {
    if (!lacunaEnabled) return

    var target = String(id || "")
    if (target !== "appPicker" && target !== "mediaPlayer"
        && target !== "settings" && target !== "shellSettings") {
      pendingFlyoutFocus = ""
      return
    }
    pendingFlyoutFocus = target
    Qt.callLater(applyPendingFlyoutFocus)
  }

  function applyPendingFlyoutFocus() {
    if (!lacunaEnabled) {
      pendingFlyoutFocus = ""
      return
    }

    if (pendingFlyoutFocus === "" || !panelController.flyoutInteractive) return
    var appPicker = activeFlyoutContent("appPicker")
    var mediaPlayer = activeFlyoutContent("mediaPlayer")
    var settings = activeFlyoutContent("settings")
    var shellSettings = activeFlyoutContent("shellSettings")
    if (pendingFlyoutFocus === "appPicker" && appPickerOpen && appPicker) {
      appPicker.forceSearchFocus()
      pendingFlyoutFocus = ""
    } else if (pendingFlyoutFocus === "mediaPlayer" && mediaPlayerOpen && mediaPlayer) {
      mediaPlayer.forceSearchFocus()
      pendingFlyoutFocus = ""
    } else if (pendingFlyoutFocus === "settings" && settingsPanelOpen && settings) {
      settings.forceActiveFocus()
      pendingFlyoutFocus = ""
    } else if (pendingFlyoutFocus === "shellSettings" && shellSettingsPanelOpen && shellSettings) {
      shellSettings.forceActiveFocus()
      pendingFlyoutFocus = ""
    }
  }

  function shellPluginEnabled(id) {
    var revision = pluginStateRevision
    if (pluginRegistry && typeof pluginRegistry.isEnabled === "function") {
      return pluginRegistry.isEnabled(id)
    }

    var config = root.shellConfig
    var bar = config && config.bar ? config.bar : null
    var layout = bar && bar.layout ? bar.layout : null
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = layout && Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
      for (var j = 0; j < list.length; j++) {
        if (list[j] && list[j].id === id) return true
      }
    }

    var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    for (var i = 0; i < plugins.length; i++) {
      if (plugins[i] && plugins[i].id === id) return true
    }
    return false
  }

  function shellPluginSettings(id, defaults) {
    var revision = pluginStateRevision
    var merged = {}
    for (var key in defaults) merged[key] = defaults[key]

    var config = root.shellConfig
    var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    for (var i = 0; i < plugins.length; i++) {
      var entry = plugins[i]
      if (!entry || entry.id !== id) continue
      for (var entryKey in entry) {
        if (entryKey !== "id") merged[entryKey] = entry[entryKey]
      }
      break
    }

    return merged
  }

  function setWorkspaceActiveOnly(enabled) {
    if (!pluginRegistry || typeof pluginRegistry.setBarWidget !== "function") {
      console.warn("Lacuna settings: bar widget persistence is unavailable")
      return false
    }

    var error = pluginRegistry.setBarWidget(
      "lacuna.workspaces", "activeWorkspaceOnly", enabled === true, ({})
    )
    if (error) {
      console.warn("Lacuna settings: failed to update workspace widget: " + error)
      return false
    }

    pluginStateRevision += 1
    return true
  }

  function numberSetting(value, fallback) {
    return valueHelpers.numberSetting(value, fallback)
  }

  function boolSetting(value, fallback) {
    return valueHelpers.boolSetting(value, fallback)
  }

  function validCornerMode(value) {
    var mode = String(value || "theme").toLowerCase()
    if (mode === "square" || mode === "custom") return mode
    return "theme"
  }

  function validFrameMode(value) {
    return valueHelpers.validFrameMode(value)
  }

  function validFrameReserveMode(value) {
    return valueHelpers.validFrameReserveMode(value)
  }

  function activeHyprWorkspaceForScreen(screen) {
    hyprWorkspaceRevision
    var monitor = screen && Hyprland.monitorFor ? Hyprland.monitorFor(screen) : null
    if (monitor && monitor.activeWorkspace) return monitor.activeWorkspace

    var focused = Hyprland.focusedWorkspace || null
    var focusedScreenName = focused && focused.monitor ? String(focused.monitor.name || "") : ""
    return focusedScreenName !== "" && focusedScreenName === MonitorPolicy.screenName(screen) ? focused : null
  }

  function activeHyprWorkspace() {
    return activeHyprWorkspaceForScreen(root.sidebarScreen) || Hyprland.focusedWorkspace || null
  }

  function fullscreenWorkspaceOnScreen(screen) {
    return MonitorPolicy.workspaceHasFullscreen(activeHyprWorkspaceForScreen(screen))
  }

  function activeWorkspaceWindowCount() {
    var workspace = activeHyprWorkspace()
    if (!workspace) return 0
    if (workspace.toplevels && workspace.toplevels.values) return Number(workspace.toplevels.values.length || 0)
    if (workspace.lastIpcObject && workspace.lastIpcObject.windows !== undefined) return Number(workspace.lastIpcObject.windows || 0)
    return 0
  }

  function hyprGapValue(value) {
    var parsed = Number(value)
    return isFinite(parsed) ? Math.round(parsed) : -1
  }

  function fakeFullscreenWorkspaceActive() {
    var workspace = activeHyprWorkspace()
    if (!workspace) return false
    if (workspace.hasFullscreen === true) return true
    return activeWorkspaceWindowCount() <= 1
  }

  function gapslessWorkspaceActive() {
    return hyprWindowGapsDisabled || fakeFullscreenWorkspaceActive()
  }

  function refreshHyprWorkspaceState() {
    if (Hyprland.refreshWorkspaces) Hyprland.refreshWorkspaces()
    if (Hyprland.refreshToplevels) Hyprland.refreshToplevels()
    hyprWorkspaceRevision += 1
  }

  function setFrameMode(mode) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.frame.mode = validFrameMode(mode)
    lacunaSettings.save(next)
  }

  function setFrameReserveMode(mode) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.frame.reserveMode = validFrameReserveMode(mode)
    lacunaSettings.save(next)
  }

  function cleanJellyfinServerUrl(value) {
    return String(value || "").trim().replace(/\/+$/, "")
  }

  function ensureMediaProviders(settings) {
    if (!settings.mediaProviders || typeof settings.mediaProviders !== "object") settings.mediaProviders = lacunaSettings.normalizeMediaProviders({})
    if (!settings.mediaProviders.jellyfin || typeof settings.mediaProviders.jellyfin !== "object") {
      settings.mediaProviders.jellyfin = {
        enabled: false,
        serverUrl: "",
        apiKey: "",
        userId: "",
        preferredAudioLanguage: "English"
      }
    }
    if (settings.mediaProviders.jellyfin.userId === undefined || settings.mediaProviders.jellyfin.userId === null) settings.mediaProviders.jellyfin.userId = ""
    if (settings.mediaProviders.jellyfin.preferredAudioLanguage === undefined || settings.mediaProviders.jellyfin.preferredAudioLanguage === null || String(settings.mediaProviders.jellyfin.preferredAudioLanguage).trim() === "") settings.mediaProviders.jellyfin.preferredAudioLanguage = "English"
  }

  function setJellyfinProviderEnabled(enabled) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    ensureMediaProviders(next)
    next.mediaProviders.jellyfin.enabled = enabled === true
    lacunaSettings.save(next)
  }

  function setJellyfinServerUrl(value) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    ensureMediaProviders(next)
    next.mediaProviders.jellyfin.serverUrl = cleanJellyfinServerUrl(value)
    lacunaSettings.save(next)
  }

  function setJellyfinApiKey(value) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    ensureMediaProviders(next)
    next.mediaProviders.jellyfin.apiKey = String(value || "").trim()
    lacunaSettings.save(next)
  }

  function setJellyfinAudioLanguage(value) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    ensureMediaProviders(next)
    next.mediaProviders.jellyfin.preferredAudioLanguage = lacunaSettings.normalizeJellyfinAudioLanguage(value)
    lacunaSettings.save(next)
  }

  function setBackgroundEffectsEnabled(enabled) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.backgroundEffects || typeof next.backgroundEffects !== "object") next.backgroundEffects = lacunaSettings.normalizeBackgroundEffects({})
    next.backgroundEffects.enabled = enabled === true
    lacunaSettings.save(next)
    if (enabled === true) ensureAmbienceHostPlugin()
  }

  function setBackgroundVignetteEnabled(enabled) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.backgroundVignette || typeof next.backgroundVignette !== "object") next.backgroundVignette = lacunaSettings.normalizeBackgroundVignette({})
    next.backgroundVignette.enabled = enabled === true
    lacunaSettings.save(next)

    if (enabled === true && !shellPluginEnabled("lacuna.background-vignette")) {
      setShellPluginEnabled("lacuna.background-vignette", true)
    }
  }

  function setBackgroundVignetteIntensity(value) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.backgroundVignette || typeof next.backgroundVignette !== "object") next.backgroundVignette = lacunaSettings.normalizeBackgroundVignette({})
    var intensity = Number(value)
    next.backgroundVignette.enabled = true
    next.backgroundVignette.intensity = isNaN(intensity) ? 0.85 : Math.max(0, Math.min(1, intensity))
    lacunaSettings.save(next)

    if (!shellPluginEnabled("lacuna.background-vignette")) {
      setShellPluginEnabled("lacuna.background-vignette", true)
    }
  }

  function setBackgroundAnimationOpacity(value) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.backgroundEffects || typeof next.backgroundEffects !== "object") next.backgroundEffects = lacunaSettings.normalizeBackgroundEffects({})
    var opacity = Number(value)
    next.backgroundEffects.opacity = isNaN(opacity) ? 1 : Math.max(0, Math.min(1, opacity))
    lacunaSettings.save(next)
    ensureAmbienceHostPlugin()
  }

  function desiredChecked(entry, fallback) {
    return valueHelpers.desiredChecked(entry, fallback)
  }

  function setBackgroundEffect(effectId) {
    var id = String(effectId || "").trim()
    if (id === "") return

    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.backgroundEffects || typeof next.backgroundEffects !== "object") next.backgroundEffects = lacunaSettings.normalizeBackgroundEffects({})
    if (!next.backgroundEffects.effects || typeof next.backgroundEffects.effects !== "object") next.backgroundEffects.effects = {}
    next.backgroundEffects.enabled = true
    var normalizedId = lacunaSettings.normalizeBackgroundEffectId(id, "")
    if (normalizedId === "") return
    next.backgroundEffects.activeEffects = [normalizedId]
    next.backgroundEffects.activeEffect = normalizedId
    next.backgroundEffects.effects.trackingLines = { enabled: true }
    next.backgroundEffects.effects.filmGrain = { enabled: true }
    next.backgroundEffects.effects.dustMotes = { enabled: true }
    next.backgroundEffects.effects.auroraDrift = { enabled: true }
    next.backgroundEffects.effects.rainfall = { enabled: true }
    next.backgroundEffects.effects.cinematicLight = { enabled: true }
    next.backgroundEffects.effects.godRays = { enabled: true }
    next.backgroundEffects.effects.crt = { enabled: true }
    lacunaSettings.save(next)

    ensureBackgroundEffectPlugin(normalizedId)
  }

  function ensureAmbienceHostPlugin() {
    var pluginId = registry.ambienceHostPluginId()
    if (pluginId !== "" && !shellPluginEnabled(pluginId)) {
      setShellPluginEnabled(pluginId, true)
    }
  }

  function ensureBackgroundEffectPlugin(effectId) {
    ensureAmbienceHostPlugin()
    var pluginId = registry.backgroundEffectPluginId(effectId)
    if (pluginId !== "" && !shellPluginEnabled(pluginId)) {
      setShellPluginEnabled(pluginId, true)
    }
  }

  function currentBackgroundEffectStack(settings) {
    var backgroundEffects = settings && settings.backgroundEffects ? settings.backgroundEffects : ({})
    var source = Array.isArray(backgroundEffects.activeEffects)
      ? backgroundEffects.activeEffects
      : (backgroundEffects.activeEffect ? [backgroundEffects.activeEffect] : [])
    var stack = []
    var seen = {}
    for (var i = 0; i < source.length; i++) {
      var id = lacunaSettings.normalizeBackgroundEffectId(source[i], "")
      if (id === "" || seen[id] === true) continue
      seen[id] = true
      stack.push(id)
    }
    return stack
  }

  function saveBackgroundEffectStack(stack, enableAnimations) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.backgroundEffects || typeof next.backgroundEffects !== "object") next.backgroundEffects = lacunaSettings.normalizeBackgroundEffects({})
    if (!next.backgroundEffects.effects || typeof next.backgroundEffects.effects !== "object") next.backgroundEffects.effects = {}
    next.backgroundEffects.enabled = enableAnimations === true ? true : next.backgroundEffects.enabled !== false
    next.backgroundEffects.activeEffects = stack
    next.backgroundEffects.activeEffect = stack.length > 0 ? stack[0] : "trackingLines"
    lacunaSettings.save(next)

    for (var i = 0; i < stack.length; i++) {
      ensureBackgroundEffectPlugin(stack[i])
    }
  }

  function setBackgroundEffectStackEnabled(effectId, enabled) {
    var id = lacunaSettings.normalizeBackgroundEffectId(effectId, "")
    if (id === "") return
    var next = lacunaSettings.normalize(lacunaSettings.data)
    var stack = currentBackgroundEffectStack(next)
    var index = stack.indexOf(id)
    if (enabled === true && index < 0) stack.push(id)
    if (enabled !== true && index >= 0) stack.splice(index, 1)
    saveBackgroundEffectStack(stack, enabled === true)
  }

  function moveBackgroundEffectInStack(effectId, direction) {
    var id = lacunaSettings.normalizeBackgroundEffectId(effectId, "")
    if (id === "") return
    var next = lacunaSettings.normalize(lacunaSettings.data)
    var stack = currentBackgroundEffectStack(next)
    var index = stack.indexOf(id)
    var target = direction < 0 ? index - 1 : index + 1
    if (index < 0 || target < 0 || target >= stack.length) return
    var moved = stack[index]
    stack.splice(index, 1)
    stack.splice(target, 0, moved)
    saveBackgroundEffectStack(stack, false)
  }

  function setBackgroundEffectForeground(effectId, enabled) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.backgroundEffects || typeof next.backgroundEffects !== "object") next.backgroundEffects = lacunaSettings.normalizeBackgroundEffects({})
    next.backgroundEffects.foregroundOverlay = enabled === true
    lacunaSettings.save(next)
    ensureAmbienceHostPlugin()
  }

  function setFilmGrainSetting(key, value) {
    var normalizedKey = String(key || "")
    if (normalizedKey !== "intensity"
        && normalizedKey !== "speed"
        && normalizedKey !== "grainCount"
        && normalizedKey !== "grainSize"
        && normalizedKey !== "accentBlend") return

    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.backgroundEffects || typeof next.backgroundEffects !== "object") next.backgroundEffects = lacunaSettings.normalizeBackgroundEffects({})
    if (!next.backgroundEffects.effects || typeof next.backgroundEffects.effects !== "object") next.backgroundEffects.effects = {}
    var grain = next.backgroundEffects.effects.filmGrain && typeof next.backgroundEffects.effects.filmGrain === "object"
      ? next.backgroundEffects.effects.filmGrain
      : ({ enabled: true })

    var parsed = Number(value)
    if (isNaN(parsed)) return
    if (normalizedKey === "intensity") grain.intensity = Math.max(0, Math.min(1, parsed))
    else if (normalizedKey === "speed") grain.speed = Math.max(0.2, Math.min(5, parsed))
    else if (normalizedKey === "grainCount") grain.grainCount = Math.max(32, Math.min(520, Math.round(parsed)))
    else if (normalizedKey === "grainSize") grain.grainSize = Math.max(0.6, Math.min(3.5, parsed))
    else if (normalizedKey === "accentBlend") grain.accentBlend = Math.max(0, Math.min(1, parsed))
    grain.enabled = true
    next.backgroundEffects.effects.filmGrain = grain
    lacunaSettings.save(next)

    ensureBackgroundEffectPlugin("filmGrain")
  }

  function setDustMotesSetting(key, value) {
    var normalizedKey = String(key || "")
    if (normalizedKey !== "intensity"
        && normalizedKey !== "speed"
        && normalizedKey !== "moteCount"
        && normalizedKey !== "moteSize"
        && normalizedKey !== "accentBlend"
        && normalizedKey !== "mouseReactive"
        && normalizedKey !== "mouseInfluence") return

    var next = lacunaSettings.normalize(lacunaSettings.data)
    if (!next.backgroundEffects || typeof next.backgroundEffects !== "object") next.backgroundEffects = lacunaSettings.normalizeBackgroundEffects({})
    if (!next.backgroundEffects.effects || typeof next.backgroundEffects.effects !== "object") next.backgroundEffects.effects = {}
    var dust = next.backgroundEffects.effects.dustMotes && typeof next.backgroundEffects.effects.dustMotes === "object"
      ? next.backgroundEffects.effects.dustMotes
      : ({ enabled: true })

    if (normalizedKey === "mouseReactive") {
      dust.mouseReactive = value === true
    } else {
      var parsed = Number(value)
      if (isNaN(parsed)) return
      if (normalizedKey === "intensity") dust.intensity = Math.max(0, Math.min(1, parsed))
      else if (normalizedKey === "speed") dust.speed = Math.max(0.15, Math.min(4, parsed))
      else if (normalizedKey === "moteCount") dust.moteCount = Math.max(12, Math.min(180, Math.round(parsed)))
      else if (normalizedKey === "moteSize") dust.moteSize = Math.max(1, Math.min(8, parsed))
      else if (normalizedKey === "accentBlend") dust.accentBlend = Math.max(0, Math.min(1, parsed))
      else if (normalizedKey === "mouseInfluence") dust.mouseInfluence = Math.max(0, Math.min(1, parsed))
    }
    dust.enabled = true
    next.backgroundEffects.effects.dustMotes = dust
    lacunaSettings.save(next)

    ensureBackgroundEffectPlugin("dustMotes")
  }

  function toggleBackgroundEffectForeground(effectId) {
    setBackgroundEffectForeground(effectId, !registry.backgroundEffectForegroundEnabled(effectId))
  }

  Timer {
    id: cornerWindowSyncTimer
    interval: 0
    repeat: false
    onTriggered: root.syncWindowCornerRadius(root.cornerMode, root.customCornerRadius)
  }

  Connections {
    target: root.shellSettingsService
    ignoreUnknownSignals: true
    function onStateChanged() {
      if (root.cornerWindowSyncReady) cornerWindowSyncTimer.restart()
    }
  }

  function syncWindowCornerRadius(mode, radius) {
    if (!shellSettingsService) return
    var hypr = shellSettingsService.state && shellSettingsService.state.hypr
      ? shellSettingsService.state.hypr : ({})
    var hasLacunaOverride = hypr.windowRoundingOverride === true
    if (mode === "theme" && typeof shellSettingsService.setWindowRoundingMode === "function") {
      if (hasLacunaOverride) shellSettingsService.setWindowRoundingMode("theme")
      return
    }
    var targetRadius = mode === "square" ? 0 : Math.max(0, Math.min(32, Math.round(Number(radius) || 0)))
    if (hasLacunaOverride && Number(hypr.windowRoundingOverrideRadius) === targetRadius) return
    if (typeof shellSettingsService.setWindowRoundingRadius === "function") {
      shellSettingsService.setWindowRoundingRadius(targetRadius)
    }
  }

  function setCornerMode(mode) {
    var normalizedMode = validCornerMode(mode)
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.geometry.cornerMode = normalizedMode
    // Keep compatibility aliases coherent for one schema generation.
    next.frame.radius = normalizedMode === "square" ? 0 : next.geometry.cornerRadius
    lacunaSettings.save(next)
    cornerWindowSyncTimer.restart()
  }

  function setCornerRadius(value) {
    var parsed = Math.round(Number(value))
    if (!isFinite(parsed)) return
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.geometry.cornerRadius = Math.max(0, Math.min(32, parsed))
    next.geometry.cornerMode = "custom"
    next.frame.radius = next.geometry.cornerRadius
    lacunaSettings.save(next)
    cornerWindowSyncTimer.restart()
  }

  function setFrameShadow(enabled) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.frame.shadow = enabled === true
    lacunaSettings.save(next)
  }

  function toggleFrameShadow() {
    setFrameShadow(!lacunaSettings.normalize(lacunaSettings.data).frame.shadow)
  }

  function setFrameBorder(enabled) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.frame.border = enabled === true
    lacunaSettings.save(next)
  }

  function toggleFrameBorder() {
    setFrameBorder(!lacunaSettings.normalize(lacunaSettings.data).frame.border)
  }

  function setPortraitSplit(enabled) {
    var next = lacunaSettings.normalize(lacunaSettings.data)
    next.barPresentation.portraitSplit = enabled === true
    lacunaSettings.save(next)
  }

  function setSidebarDefaultMode(mode) {
    sidebarState.setDefaultMode(mode)
    if (!sidebarAutoHideEnabled) applySidebarDefaultState()
  }

  function setSidebarAutoHideEnabled(enabled) {
    sidebarState.setAutoHideEnabled(enabled === true)
  }

  function validClockAnchor(value) {
    return valueHelpers.validClockAnchor(value)
  }

  function clockAnchorHorizontal(anchor) {
    return valueHelpers.clockAnchorHorizontal(anchor)
  }

  function clockAnchorVertical(anchor) {
    return valueHelpers.clockAnchorVertical(anchor)
  }

  function clockAnchorFromParts(horizontal, vertical) {
    return valueHelpers.clockAnchorFromParts(horizontal, vertical)
  }

  function setShellPluginEnabled(id, enabled) {
    if (pluginRegistry && typeof pluginRegistry.setEnabled === "function") {
      pluginRegistry.setEnabled(id, enabled)
      pluginStateRevision++
      return
    }

    commands.run(shellIpcCommand("shell", "setPluginEnabled", [id, enabled ? "true" : "false"]))
    pluginStateRevision++
  }

  function setDesktopClockSettings(patch) {
    var next = {
      anchor: root.desktopClockAnchor,
      offsetX: root.desktopClockOffsetX,
      offsetY: root.desktopClockOffsetY,
      scale: root.desktopClockScale,
      use12Hour: root.desktopClockUse12Hour
    }

    for (var key in patch) next[key] = patch[key]

    if (!root.desktopClockEnabled && pluginRegistry && typeof pluginRegistry.setEnabled === "function") {
      pluginRegistry.setEnabled("lacuna.desktop-clock", true)
    }

    if (shell && typeof shell.updateEntryInline === "function") {
      shell.updateEntryInline("lacuna.desktop-clock", next)
      pluginStateRevision++
      return
    }

    commands.run("notify-send 'Lacuna' 'Clock settings require the Omarchy shell plugin registry'")
  }

  function setCinematicLightSetting(key, value) {
    var next = registry.cinematicLightSettings()
    var normalizedKey = String(key || "")
    var normalizedValue = String(value || "")

    if (normalizedKey !== "stylePreset" && normalizedKey !== "intensity") {
      return
    }

    if (normalizedKey === "stylePreset") {
      next.stylePreset = normalizedValue === "cinematicFlare" || normalizedValue === "anamorphicGlow" ? normalizedValue : "lightLeak"
    } else {
      var intensity = Number(normalizedValue)
      next.intensity = isNaN(intensity) ? 1 : Math.max(0, Math.min(1, intensity))
    }

    if (shell && typeof shell.updateEntryInline === "function") {
      shell.updateEntryInline("lacuna.cinematic-light-overlay", next)
      pluginStateRevision++
      return
    }

    commands.run("notify-send 'Lacuna' 'Cinematic Light settings require the Omarchy shell plugin registry'")
  }

  function setCinematicLightMotion(mode, enabled) {
    var normalizedMode = String(mode || "")
    if (normalizedMode !== "slowDrift" && normalizedMode !== "occasionalSweeps" && normalizedMode !== "activeShimmer") return

    var next = registry.cinematicLightSettings()
    var modes = registry.cinematicLightMotionModes()
    modes[normalizedMode] = enabled === true
    if (!modes.slowDrift && !modes.occasionalSweeps && !modes.activeShimmer) modes[normalizedMode] = true

    next.slowDrift = modes.slowDrift
    next.occasionalSweeps = modes.occasionalSweeps
    next.activeShimmer = modes.activeShimmer
    delete next.motionMode

    if (shell && typeof shell.updateEntryInline === "function") {
      shell.updateEntryInline("lacuna.cinematic-light-overlay", next)
      pluginStateRevision++
      return
    }

    commands.run("notify-send 'Lacuna' 'Cinematic Light settings require the Omarchy shell plugin registry'")
  }

  function toggleCinematicLightMotion(mode) {
    var modes = registry.cinematicLightMotionModes()
    setCinematicLightMotion(mode, !modes[String(mode || "")])
  }

  function setDesktopClockAnchorAxis(axis, value) {
    var horizontal = clockAnchorHorizontal(root.desktopClockAnchor)
    var vertical = clockAnchorVertical(root.desktopClockAnchor)

    if (axis === "x") horizontal = value
    else vertical = value

    setDesktopClockSettings({ anchor: clockAnchorFromParts(horizontal, vertical) })
  }

  function nudgeDesktopClock(dx, dy) {
    setDesktopClockSettings({
      offsetX: root.desktopClockOffsetX + dx,
      offsetY: root.desktopClockOffsetY + dy
    })
  }

  function scaleDesktopClock(delta) {
    var nextScale = Math.max(0.5, Math.min(2, Math.round((root.desktopClockScale + delta) * 100) / 100))
    setDesktopClockSettings({ scale: nextScale })
  }

  function resetDesktopClockPosition() {
    setDesktopClockSettings({
      anchor: "bottom-right",
      offsetX: 0,
      offsetY: 0,
      scale: 1
    })
  }

  function runOmarchyCommand(command) {
    if (!command) return
    commands.run(command)
  }

  function requestSystemRestart() {
    if (instantRestart) {
      confirmSystemRestart()
      return
    }

    pendingSystemRestartConfirmation = true
    if (!menuState.open) panelController.openMenu()
  }

  function confirmSystemRestart() {
    pendingSystemRestartConfirmation = false
    focusDismissReason = "explicit-close"
    panelController.closeActiveFlyout()
    commands.run("omarchy system reboot")
    applySidebarDefaultState()
  }

  function cancelSystemRestart() {
    pendingSystemRestartConfirmation = false
  }

  function handleSidebarAction(entry) {
    if (entry.action === "retry-settings-save") {
      if (lacunaSettings && typeof lacunaSettings.retryPersistence === "function")
        lacunaSettings.retryPersistence()
      return true
    }

    if (entry.action === "toggle-sidebar-mode") {
      sidebarState.setExclusive(desiredChecked(entry, !sidebarState.exclusive))
      return true
    }

    if (entry.action === "toggle-sidebar-rail") {
      sidebarState.toggleCollapsed()
      return true
    }

    if (entry.action === "toggle-sidebar-autohide") {
      setSidebarAutoHideEnabled(desiredChecked(entry, !sidebarAutoHideEnabled))
      return true
    }

    if (entry.action.indexOf("set-sidebar-monitor-policy-") === 0) {
      setSidebarMonitorPolicy(entry.action.substring("set-sidebar-monitor-policy-".length))
      return true
    }

    if (entry.action.indexOf("toggle-sidebar-monitor-") === 0) {
      var monitorName = entry.action.substring("toggle-sidebar-monitor-".length)
      toggleSidebarMonitor(
        monitorName,
        desiredChecked(entry, sidebarMonitorNames.indexOf(monitorName) < 0)
      )
      return true
    }

    if (entry.action.indexOf("set-sidebar-default-") === 0) {
      setSidebarDefaultMode(entry.action.substring("set-sidebar-default-".length))
      return true
    }

    if (entry.action === "toggle-bar-density") {
      compactState.toggle()
      return true
    }

    if (entry.action === "toggle-lacuna-density") {
      compactState.toggle()
      return true
    }

    if (entry.action.indexOf("set-bar-size-mode-") === 0) {
      barSizeModeService.setMode(entry.action.substring("set-bar-size-mode-".length))
      return true
    }

    if (entry.action === "toggle-workspaces-active-only") {
      setWorkspaceActiveOnly(desiredChecked(entry, !registry.workspacesActiveOnly()))
      return true
    }

    if (entry.action.indexOf("set-controls-layout-") === 0) {
      setControlsLayout(entry.action.substring("set-controls-layout-".length))
      return true
    }

    if (entry.action.indexOf("set-shortcuts-layout-") === 0) {
      setShortcutsLayout(entry.action.substring("set-shortcuts-layout-".length))
      return true
    }

    if (entry.action.indexOf("set-shell-settings-surface-") === 0) {
      setShellSettingsSurface(entry.action.substring("set-shell-settings-surface-".length))
      return true
    }

    if (entry.action.indexOf("set-daily-launch-layout-") === 0) {
      setDailyLaunchLayout(entry.action.substring("set-daily-launch-layout-".length))
      return true
    }

    if (entry.action.indexOf("set-quick-launch-layout-") === 0) {
      setQuickLaunchLayout(entry.action.substring("set-quick-launch-layout-".length))
      return true
    }

    return false
  }

  function handleLacunaSettingsAction(entry) {
    if (entry.action.indexOf("set-corner-mode-") === 0) {
      setCornerMode(entry.action.substring("set-corner-mode-".length))
      return true
    }

    if (entry.action.indexOf("set-corner-radius-") === 0) {
      setCornerRadius(entry.action.substring("set-corner-radius-".length))
      return true
    }

    if (entry.action.indexOf("set-frame-mode-") === 0) {
      setFrameMode(entry.action.substring("set-frame-mode-".length))
      return true
    }

    if (entry.action.indexOf("set-frame-reserve-mode-") === 0) {
      setFrameReserveMode(entry.action.substring("set-frame-reserve-mode-".length))
      return true
    }

    if (entry.action === "toggle-frame-shadow") {
      setFrameShadow(desiredChecked(entry, !lacunaSettings.normalize(lacunaSettings.data).frame.shadow))
      return true
    }

    if (entry.action === "toggle-frame-border") {
      setFrameBorder(desiredChecked(entry, !lacunaSettings.normalize(lacunaSettings.data).frame.border))
      return true
    }

    if (entry.action === "toggle-portrait-split") {
      setPortraitSplit(desiredChecked(entry, !root.portraitSplit))
      return true
    }

    if (entry.action === "toggle-jellyfin-provider") {
      setJellyfinProviderEnabled(desiredChecked(entry, !registry.jellyfinProviderEnabled))
      return true
    }

    if (entry.action.indexOf("set-jellyfin-server-url-") === 0) {
      setJellyfinServerUrl(entry.action.substring("set-jellyfin-server-url-".length))
      return true
    }

    if (entry.action.indexOf("set-jellyfin-api-key-") === 0) {
      setJellyfinApiKey(entry.action.substring("set-jellyfin-api-key-".length))
      return true
    }

    if (entry.action.indexOf("set-jellyfin-audio-language-") === 0) {
      setJellyfinAudioLanguage(entry.action.substring("set-jellyfin-audio-language-".length))
      return true
    }

    if (entry.action === "toggle-background-effects") {
      setBackgroundEffectsEnabled(desiredChecked(entry, !registry.backgroundEffectsEnabled()))
      return true
    }

    if (entry.action === "toggle-background-vignette") {
      setBackgroundVignetteEnabled(desiredChecked(entry, !registry.backgroundVignetteEnabled()))
      return true
    }

    if (entry.action.indexOf("set-background-vignette-intensity-") === 0) {
      setBackgroundVignetteIntensity(entry.action.substring("set-background-vignette-intensity-".length))
      return true
    }

    if (entry.action.indexOf("set-background-animation-opacity-") === 0) {
      setBackgroundAnimationOpacity(entry.action.substring("set-background-animation-opacity-".length))
      return true
    }

    if (entry.action.indexOf("set-background-effect-") === 0) {
      setBackgroundEffect(entry.action.substring("set-background-effect-".length))
      return true
    }

    if (entry.action.indexOf("toggle-background-effect-") === 0 && entry.action.indexOf("toggle-background-effect-foreground-") !== 0) {
      var toggledEffect = entry.action.substring("toggle-background-effect-".length)
      setBackgroundEffectStackEnabled(toggledEffect, desiredChecked(entry, !registry.backgroundEffectEnabled(toggledEffect)))
      return true
    }

    if (entry.action.indexOf("move-background-effect-up-") === 0) {
      moveBackgroundEffectInStack(entry.action.substring("move-background-effect-up-".length), -1)
      return true
    }

    if (entry.action.indexOf("move-background-effect-down-") === 0) {
      moveBackgroundEffectInStack(entry.action.substring("move-background-effect-down-".length), 1)
      return true
    }

    if (entry.action.indexOf("toggle-background-effect-foreground-") === 0) {
      var foregroundEffect = entry.action.substring("toggle-background-effect-foreground-".length)
      setBackgroundEffectForeground(foregroundEffect, desiredChecked(entry, !registry.backgroundEffectForegroundEnabled(foregroundEffect)))
      return true
    }

    if (entry.action.indexOf("set-film-grain-intensity-") === 0) {
      setFilmGrainSetting("intensity", entry.action.substring("set-film-grain-intensity-".length))
      return true
    }

    if (entry.action.indexOf("set-film-grain-size-") === 0) {
      setFilmGrainSetting("grainSize", entry.action.substring("set-film-grain-size-".length))
      return true
    }

    if (entry.action.indexOf("set-film-grain-count-") === 0) {
      setFilmGrainSetting("grainCount", entry.action.substring("set-film-grain-count-".length))
      return true
    }

    if (entry.action.indexOf("set-film-grain-speed-") === 0) {
      setFilmGrainSetting("speed", entry.action.substring("set-film-grain-speed-".length))
      return true
    }

    if (entry.action.indexOf("set-film-grain-accent-") === 0) {
      setFilmGrainSetting("accentBlend", entry.action.substring("set-film-grain-accent-".length))
      return true
    }

    if (entry.action.indexOf("set-dust-motes-intensity-") === 0) {
      setDustMotesSetting("intensity", entry.action.substring("set-dust-motes-intensity-".length))
      return true
    }

    if (entry.action.indexOf("set-dust-motes-speed-") === 0) {
      setDustMotesSetting("speed", entry.action.substring("set-dust-motes-speed-".length))
      return true
    }

    if (entry.action.indexOf("set-dust-motes-count-") === 0) {
      setDustMotesSetting("moteCount", entry.action.substring("set-dust-motes-count-".length))
      return true
    }

    if (entry.action.indexOf("set-dust-motes-size-") === 0) {
      setDustMotesSetting("moteSize", entry.action.substring("set-dust-motes-size-".length))
      return true
    }

    if (entry.action.indexOf("set-dust-motes-accent-") === 0) {
      setDustMotesSetting("accentBlend", entry.action.substring("set-dust-motes-accent-".length))
      return true
    }

    if (entry.action === "toggle-dust-motes-mouse-reactive") {
      setDustMotesSetting("mouseReactive", desiredChecked(entry, !registry.dustMotesMouseReactive()))
      return true
    }

    if (entry.action.indexOf("set-dust-motes-mouse-influence-") === 0) {
      setDustMotesSetting("mouseInfluence", entry.action.substring("set-dust-motes-mouse-influence-".length))
      return true
    }

    if (entry.action.indexOf("set-cinematic-light-style-") === 0) {
      setCinematicLightSetting("stylePreset", entry.action.substring("set-cinematic-light-style-".length))
      return true
    }

    if (entry.action.indexOf("set-cinematic-light-intensity-") === 0) {
      setCinematicLightSetting("intensity", entry.action.substring("set-cinematic-light-intensity-".length))
      return true
    }

    if (entry.action.indexOf("toggle-cinematic-light-motion-") === 0) {
      var motionMode = entry.action.substring("toggle-cinematic-light-motion-".length)
      setCinematicLightMotion(motionMode, desiredChecked(entry, !registry.cinematicLightMotionModes()[motionMode]))
      return true
    }

    if (entry.action.indexOf("open-settings-section-") === 0) {
      openSettingsSection(entry.action.substring("open-settings-section-".length))
      return true
    }

    if (entry.action === "toggle-color-profile") {
      var next = lacunaSettings.normalize(lacunaSettings.data)
      next.colorProfile = desiredChecked(entry, next.colorProfile !== "colorful") ? "colorful" : "semantic"
      lacunaSettings.save(next)
      return true
    }

    if (entry.action === "toggle-instant-restart") {
      var nextPowerSettings = lacunaSettings.normalize(lacunaSettings.data)
      nextPowerSettings.power.instantRestart = desiredChecked(entry, !root.instantRestart)
      lacunaSettings.save(nextPowerSettings)
      return true
    }

    if (entry.action === "toggle-desktop-clock") {
      setShellPluginEnabled("lacuna.desktop-clock", desiredChecked(entry, !desktopClockEnabled))
      return true
    }

    if (entry.action === "toggle-clock-12-hour") {
      setDesktopClockSettings({ use12Hour: desiredChecked(entry, !root.desktopClockUse12Hour) })
      return true
    }

    if (entry.action.indexOf("set-clock-anchor-x-") === 0) {
      setDesktopClockAnchorAxis("x", entry.action.substring("set-clock-anchor-x-".length))
      return true
    }

    if (entry.action.indexOf("set-clock-anchor-y-") === 0) {
      setDesktopClockAnchorAxis("y", entry.action.substring("set-clock-anchor-y-".length))
      return true
    }

    if (entry.action === "nudge-clock-left") {
      nudgeDesktopClock(-24, 0)
      return true
    }

    if (entry.action === "scale-clock-down") {
      scaleDesktopClock(-0.1)
      return true
    }

    if (entry.action === "scale-clock-up") {
      scaleDesktopClock(0.1)
      return true
    }

    if (entry.action === "nudge-clock-right") {
      nudgeDesktopClock(24, 0)
      return true
    }

    if (entry.action === "nudge-clock-up") {
      nudgeDesktopClock(0, -24)
      return true
    }

    if (entry.action === "nudge-clock-down") {
      nudgeDesktopClock(0, 24)
      return true
    }

    if (entry.action === "reset-clock-position") {
      resetDesktopClockPosition()
      return true
    }

    if (entry.action === "cycle-design-style") {
      var nextStyleSettings = lacunaSettings.normalize(lacunaSettings.data)
      nextStyleSettings.designStyle = lacunaSettings.nextDesignStyle(nextStyleSettings.designStyle)
      lacunaSettings.save(nextStyleSettings)
      return true
    }

    if (entry.action.indexOf("set-design-style-") === 0) {
      setDesignStyle(entry.action.substring("set-design-style-".length))
      return true
    }

    return false
  }

  function handleQuickAccessAction(entry) {
    if (entry.action === "confirm-system-restart") {
      requestSystemRestart()
      return true
    }

    if (entry.action === "open-custom-quick-launch-picker") {
      openCustomQuickLaunchPicker()
      return true
    }

    if (entry.action === "add-custom-quick-launch-app") {
      addCustomQuickLaunchApp(entry.appId)
      return true
    }

    if (entry.action.indexOf("choose-preferred-app-") === 0) {
      openPreferredAppPicker(entry.action.substring("choose-preferred-app-".length))
      return true
    }

    if (entry.action === "reload-apps") {
      appCatalog.reload()
      return true
    }

    if (entry.action === "open-screenrecord-menu") {
      commands.run("omarchy capture screenrecording --stop-recording || "
        + "omarchy menu toggle trigger.capture.screenrecord")
      applySidebarDefaultState()
      return true
    }

    return false
  }

  function activate(entry) {
    if (!entry || entry.kind === "header") return
    if (!lacunaEnabled) return

    if (entry.action) {
      if (handleSidebarAction(entry)) return
      if (handleLacunaSettingsAction(entry)) return
      if (handleQuickAccessAction(entry)) return
    }

    if (entry.view) {
      if (sidebarState.collapsed) sidebarState.expand()
      closeFlyouts("explicit-close")
      menuState.push(entry.view)
      return
    }

    if (entry.command) {
      closeFlyouts("explicit-close")
      commands.run(entry.command)
      applySidebarDefaultState()
    }
  }

  Component.onCompleted: {
    settledFocusedMonitorName = liveFocusedMonitorName
    versionFile.reload()
    syncSidebarAutohideScreens()
    applyInitialSidebarDefault()
    refreshHyprWorkspaceState()
    cornerWindowSyncReady = true
    cornerWindowSyncTimer.restart()
  }

  Component.onDestruction: {
    // Destroying HyprlandFocusGrab releases the compositor grab and restores
    // the client focused before the flyout session.
    focusDismissReason = "shell-rescan"
    pendingFlyoutFocus = ""
  }

  LacunaMenuState {
    id: localMenuState
  }

  LacunaSettings {
    id: localLacunaSettings
  }

  OmarchyShellSettingsService {
    id: localShellSettingsService
    shell: root.shell
    manifest: root.manifest
    pluginRegistry: root.pluginRegistry
    shellConfig: root.shellConfig
  }

  Connections {
    target: root.lacunaSettings
    function onLoaded() { root.applyInitialSidebarDefault() }
  }

  CompactState {
    id: localCompactState
    settingsService: lacunaSettings
  }

  SidebarState {
    id: localSidebarState
    settingsService: lacunaSettings
  }

  BarSizeMode {
    id: barSizeModeService
    settingsService: lacunaSettings
    commandRunner: commands
    themeName: menuTheme.themeName
    omarchyPath: root.resolvedOmarchyPath()
  }

  Timer {
    id: hyprWorkspaceRefreshTimer
    interval: 80
    repeat: false
    onTriggered: root.refreshHyprWorkspaceState()
  }

  // Let Hyprland finish its workspace animation before moving the layer-shell
  // sidebar and frame reserve. Reconfiguring those surfaces mid-transition
  // makes full-screen effects such as the vignette flash and competes with the
  // compositor animation for a frame.
  Timer {
    id: monitorHandoffTimer
    interval: root.menuMotionTokensRef.reveal
    repeat: false
    onTriggered: root.settledFocusedMonitorName = root.liveFocusedMonitorName
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      var name = event.name
      if (name.indexOf("workspace") >= 0 || name === "focusedmon" || name.indexOf("window") >= 0 || name === "fullscreen") {
        hyprWorkspaceRefreshTimer.restart()
      }
    }

    function onFocusedWorkspaceChanged() {
      root.hyprWorkspaceRevision += 1
    }
  }

  Connections {
    target: Hyprland.workspaces

    function onValuesChanged() {
      root.hyprWorkspaceRevision += 1
    }
  }

  AppCatalog {
    id: appCatalog
    lacunaPath: root.lacunaPath
  }

  Theme {
    id: menuTheme
  }

  DesignTokens {
    id: designTokens
    designStyle: root.designStyle
    exposedCornerRadius: root.resolvedCornerRadius
    compact: root.compact
    compactProgress: root.compactProgress
    foreground: root.foreground
    background: root.background
    accent: root.accent
  }

  DesignTokens {
    id: railDesignTokens
    designStyle: root.designStyle
    exposedCornerRadius: root.resolvedCornerRadius
    compact: root.railCompact
    compactProgress: root.forceCompactRail ? 1 : root.compactProgress
    foreground: root.foreground
    background: root.background
    accent: root.accent
  }

  FileView {
    id: versionFile

    path: root.lacunaPath + "/VERSION"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var raw = text().trim()
      root.version = raw === "" ? "" : "v" + raw.replace(/^v/, "")
    }
    onFileChanged: reload()
  }

  MenuRegistry {
    id: registry
    lacunaPath: root.lacunaPath
    sidebarExclusive: sidebarState.exclusive
    sidebarCollapsed: sidebarState.collapsed
    sidebarDefaultMode: root.sidebarDefaultMode()
    sidebarMonitorPolicy: root.sidebarMonitorPolicy
    sidebarMonitorNames: root.sidebarMonitorNames
    sidebarMonitorOptions: root.sidebarMonitorOptions
    sidebarAutoHideEnabled: root.sidebarAutoHideEnabled
    sidebarAutoHideHotZoneWidth: root.sidebarAutoHideHotZoneWidth
    sidebarAutoHideRevealDelayMs: root.sidebarAutoHideRevealDelayMs
    sidebarAutoHideHideDelayMs: root.sidebarAutoHideHideDelayMs
    compact: root.compact
    barSizeMode: barSizeModeService.barSizeMode
    designStyle: root.designStyle
    colorProfile: lacunaSettings.data && lacunaSettings.data.colorProfile ? lacunaSettings.data.colorProfile : "semantic"
    cornerMode: root.cornerMode
    cornerRadius: root.customCornerRadius
    resolvedCornerRadius: root.resolvedCornerRadius
    quickLaunchLayout: lacunaSettings.data && lacunaSettings.data.quickLaunchLayout ? lacunaSettings.data.quickLaunchLayout : "list"
    dailyLaunchLayout: lacunaSettings.data && lacunaSettings.data.dailyLaunchLayout ? lacunaSettings.data.dailyLaunchLayout : "list"
    shortcutsLayout: lacunaSettings.data && lacunaSettings.data.shortcutsLayout ? lacunaSettings.data.shortcutsLayout : "list"
    controlsLayout: lacunaSettings.data && lacunaSettings.data.controlsLayout ? lacunaSettings.data.controlsLayout : "grid"
    shellSettingsSurface: root.shellSettingsSurface
    frameMode: root.frameMode
    frameReserveMode: root.frameReserveMode
    frameShadow: root.frameShadow
    frameBorder: root.frameBorder
    portraitSplit: root.portraitSplit
    mediaProviders: root.mediaProvidersSettings
    backgroundEffects: root.backgroundEffectsSettings
    backgroundVignette: root.backgroundVignetteSettings
    instantRestart: root.instantRestart
    shellBarConfig: root.shellBarConfig
    shellBarPosition: root.barPosition
    shellBarTransparent: root.shellBarConfig && root.shellBarConfig.transparent === true
    shellBarCenterAnchor: root.shellBarConfig && root.shellBarConfig.centerAnchor ? String(root.shellBarConfig.centerAnchor) : ""
    shellIdleScreensaver: root.shellIdleScreensaver
    shellIdleLock: root.shellIdleLock
    shellPlugins: root.shellConfig && Array.isArray(root.shellConfig.plugins) ? root.shellConfig.plugins : []
    barWidgetRegistry: root.barWidgetRegistry
    pluginRegistry: root.pluginRegistry
    desktopClockEnabled: root.desktopClockEnabled
    desktopClockAnchor: root.desktopClockAnchor
    desktopClockOffsetX: root.desktopClockOffsetX
    desktopClockOffsetY: root.desktopClockOffsetY
    desktopClockScale: root.desktopClockScale
    desktopClockUse12Hour: root.desktopClockUse12Hour
    appCatalog: appCatalog
    customQuickLaunchApps: lacunaSettings.data && lacunaSettings.data.customQuickLaunchApps ? lacunaSettings.data.customQuickLaunchApps : []
    customQuickLaunchNames: lacunaSettings.data && lacunaSettings.data.customQuickLaunchNames ? lacunaSettings.data.customQuickLaunchNames : ({})
    preferredApps: lacunaSettings.data && lacunaSettings.data.preferredApps ? lacunaSettings.data.preferredApps : ({})
    settingsPersistenceState: lacunaSettings ? String(lacunaSettings.persistenceState || "idle") : "idle"
    settingsPersistenceError: lacunaSettings ? String(lacunaSettings.persistenceError || "") : ""
    settingsRequestedRevision: lacunaSettings ? Number(lacunaSettings.requestedSaveRevision || 0) : 0
    settingsConfirmedRevision: lacunaSettings ? Number(lacunaSettings.confirmedSaveRevision || 0) : 0
  }

  MotionTokens {
    id: sharedMotion
    animationDisabled: root.reduceMotionEnabled
  }

  SidebarAutohideController {
    id: sidebarAutohide

    enabled: root.sidebarAutoHideEnabled && root.lacunaEnabled
    hotZoneWidth: root.sidebarAutoHideHotZoneWidth
    revealDelayMs: root.sidebarAutoHideRevealDelayMs
    hideDelayMs: root.sidebarAutoHideHideDelayMs
    flyoutHeld: root.flyoutOpen || root.flyoutRenderable || root.pendingFlyoutFocus !== ""
    contentHeld: root.pendingSystemRestartConfirmation || root.sidebarAutohideContentHeld()
    onRevealRequested: function(screenName, reason) {
      root.revealSidebarFromAutohide(screenName, reason)
    }
    onConcealRequested: function(reason) {
      root.concealSidebarFromAutohide(reason)
    }
  }

  PanelController {
    id: panelController
    motionTokens: sharedMotion
    menuState: root.menuState
    retainMenuOnExternalClose: root.sidebarSettingsLoaded() && root.sidebarDefaultKeepsMenuOpen()
    transitionTraceEnabled: root.transitionTraceEnabled
    onMenuProgressChanged: sidebarAutohide.notifyMenuProgress(menuProgress)
    onFlyoutOpenChanged: {
      if (!flyoutOpen) root.pendingFlyoutFocus = ""
      else root.applyPendingFlyoutFocus()
    }
    onFlyoutInteractiveChanged: root.applyPendingFlyoutFocus()
    onActiveFlyoutChanged: root.applyPendingFlyoutFocus()
    onHostHideRequested: {
      if (!root.sidebarSettingsLoaded()) {
        initialSidebarDefaultRetry.restart()
        return
      }
      if (root.sidebarDefaultKeepsMenuOpen()) {
        root.applySidebarDefaultState()
        return
      }
      if (root.hostManaged) return
      if (root.frameMode === "fullframe") return
      if (root.shell && root.shell.hide) root.shell.hide(root.pluginId)
    }
  }

  CommandRunner {
    id: commands
  }

  MenuValueHelpers {
    id: valueHelpers
  }

  Variants {
    model: root.sidebarScreens

    LacunaPanelWindow {
      id: menuWindow
      required property var modelData
      readonly property bool fullscreenSuppressed: root.fullscreenWorkspaceOnScreen(modelData)
      readonly property bool sidebarRenderable: root.sidebarVisibleOnScreen(modelData)
      readonly property string outputName: modelData && modelData.name !== undefined
        ? String(modelData.name) : ""
      readonly property real liveSidebarBodyWidth: sidebarRenderable
        ? (root.sidebarAutoHideEnabled
          ? Math.max(0, root.panelWidth + Math.min(0, panelHost.surfaceX))
          : root.panelWidth)
        : 0

      onLiveSidebarBodyWidthChanged: root.publishSidebarPaintOcclusion(
        modelData, liveSidebarBodyWidth)

    onFullscreenSuppressedChanged: {
      var name = root.sidebarAutohideScreenName(modelData)
      sidebarAutohide.setScreenSuppressed(name, fullscreenSuppressed)
      if (fullscreenSuppressed && root.flyoutTargetsScreen(modelData)) root.closeFlyouts("fullscreen")
    }
    Component.onCompleted: {
      sidebarAutohide.setScreenSuppressed(
        root.sidebarAutohideScreenName(modelData), fullscreenSuppressed)
      root.publishSidebarPaintOcclusion(modelData, liveSidebarBodyWidth)
      if (root.lacunaSettings
          && typeof root.lacunaSettings.publishForegroundFrameSource === "function")
        root.lacunaSettings.publishForegroundFrameSource(
          menuWindow.outputName, "menu", foregroundFrameBridge)
    }
    Component.onDestruction: {
      root.publishSidebarPaintOcclusion(modelData, 0)
      if (root.lacunaSettings
          && typeof root.lacunaSettings.clearForegroundFrameSource === "function")
        root.lacunaSettings.clearForegroundFrameSource(
          menuWindow.outputName, "menu", foregroundFrameBridge)
    }

    targetScreen: modelData
    layerNamespace: root.pluginId + "-menu-" + root.screenNamespace(modelData)
    menuOpen: root.menuState.open
    panelVisible: root.lacunaEnabled && root.panelVisible
      && (menuWindow.sidebarRenderable || root.flyoutVisibleOnScreen(modelData))
    keepMapped: root.lacunaEnabled && (root.sidebarAutoHideEnabled || root.frameMode !== "off" || root.topBarPanelShadowVisible)
    flyoutOpen: root.lacunaEnabled && root.flyoutOpenOnScreen(modelData)
    flyoutInteractive: root.lacunaEnabled && root.flyoutInteractiveOnScreen(modelData)
    keyboardInputActive: root.lacunaEnabled && !menuWindow.fullscreenSuppressed
      && ((root.activeFlyoutMediaPlayer || root.activeFlyoutAppPicker) && root.flyoutInteractiveOnScreen(modelData)
        || menuContent.quickLaunchRenameOpen)
    shortcutInhibitionActive: menuWindow.keyboardInputActive && mediaPlayerContent.searchInputFocused
    dismissActive: root.lacunaEnabled && root.flyoutInteractiveOnScreen(modelData)
    dismissReason: root.focusDismissReason
    exclusive: root.effectiveSidebarExclusive
    panelWidth: root.panelWidth
    surfaceRightInset: Math.max(panelHost.effectiveConnectorWidth, root.frameMoldingPieces ? root.frameRadius : 0)
    flyoutLaneWidth: root.flyoutLaneWidthFor(modelData, panelHost.effectiveConnectorWidth)
    visualWidth: Math.max(root.frameOverlayWidthFor(modelData), root.topBarPanelShadowVisualWidthFor(modelData))
    visualTopInset: Math.max(0, root.visualTopInset - root.standaloneBorderWindowOverlap)
    visualBottomInset: root.visualBottomInset
    visualLeftInset: root.visualLeftInset
    visualRightInset: root.visualRightInset
    anchorRight: root.panelOnRight
    sidebarMaskX: panelHost.sidebarMaskX
    sidebarMaskY: panelHost.sidebarMaskY
    sidebarMaskWidth: panelHost.sidebarMaskWidth
    sidebarMaskHeight: panelHost.sidebarMaskHeight
    connectorMaskX: panelHost.connectorMaskX
    connectorMaskY: panelHost.connectorMaskY
    connectorMaskWidth: panelHost.connectorMaskWidth
    connectorMaskHeight: panelHost.connectorMaskHeight
    flyoutMaskX: panelHost.flyoutMaskX
    flyoutMaskY: panelHost.flyoutMaskY
    flyoutMaskWidth: panelHost.flyoutMaskWidth
    flyoutMaskHeight: panelHost.flyoutMaskHeight
    hotZoneEnabled: root.sidebarAutoHideEnabled && root.lacunaEnabled && !menuWindow.fullscreenSuppressed
    hotZoneX: 0
    hotZoneY: root.barBottomY
    hotZoneWidth: root.sidebarAutoHideHotZoneWidth
    hotZoneHeight: Math.max(0, menuWindow.height - hotZoneY
      - (root.bottomBar && root.visualBottomInset === 0 ? root.barHeight : 0))
    onHotZoneEntered: sidebarAutohide.setHotZoneHovered(root.sidebarAutohideScreenName(modelData), true)
    onHotZoneExited: sidebarAutohide.setHotZoneHovered(root.sidebarAutohideScreenName(modelData), false)
    onFocusGrabCleared: function(reason) { root.closeFlyouts(reason) }
    onDismissRequested: function(reason) { root.closeFlyouts(reason) }

    LacunaPanelHost {
      id: panelHost

      panelWidth: root.panelWidth
      surfaceX: surface.x + surface.surfaceX
      sidebarHeight: menuWindow.height
      anchorRight: root.panelOnRight
      connectorWidth: root.settingsConnectorWidth
      connectorOverlap: root.effectiveConnectorPieces ? root.connectorOverlap : 0
      panelRadius: root.attachedFlyoutRadius
      geometrySemanticKey: root.geometryTargetFlyout
      flyoutY: root.geometryTargetFlyout === "" ? 0
        : root.flyoutGeometryFor(modelData, root.geometryTargetFlyout).y
      flyoutWidth: root.geometryTargetFlyout === "" ? 0
        : Math.max(0, root.flyoutGeometryFor(modelData, root.geometryTargetFlyout).width)
      flyoutHeight: root.geometryTargetFlyout === "" ? 0
        : Math.max(0, root.flyoutGeometryFor(modelData, root.geometryTargetFlyout).height)
      flyoutProgress: root.menuPanelControllerRef.flyoutProgress
      flyoutRenderable: root.lacunaEnabled && root.flyoutVisibleOnScreen(modelData)
      geometryTransitionEnabled: flyoutRenderable && flyoutProgress > 0.001
      reducedMotion: root.menuMotionTokensRef.animationDisabled
      geometryAnimationDuration: root.menuMotionTokensRef.quick
      onEffectivePanelGeometryChanged: root.publishPanelGeometry(modelData, panelHost)
      onEffectiveConnectorVisibleChanged: root.publishPanelGeometry(modelData, panelHost)
      Component.onCompleted: root.publishPanelGeometry(modelData, panelHost)
    }

    QtObject {
      id: foregroundFrameBridge
      readonly property var borderSource: frameOverlay
      readonly property real offsetX: menuWindow.visualLeftInset
      readonly property real offsetY: menuWindow.visualTopInset
    }

    LacunaFrameOverlay {
      id: frameOverlay

      anchors.fill: parent
      z: borderOnly ? 11 : 0
      mode: root.lacunaEnabled && !menuWindow.fullscreenSuppressed
        && !root.barOwnsLacunaFrame ? root.frameMode : "off"
      borderOnly: root.ownsHostFrameBorderOnScreen(modelData)
      // Autohide's border shares the sidebar animation clock. The host frame
      // record intentionally stays on persistent geometry to keep background
      // consumers stable, so use the live clipped body width here instead.
      borderGeometryRecord: root.sidebarAutoHideEnabled ? null : root.hostFrameGeometryFor(modelData)
      shadowEnabled: root.lacunaEnabled && !menuWindow.fullscreenSuppressed
        && !root.barOwnsLacunaFrame && root.frameShadow && root.frameMode !== "off"
      borderEnabled: root.lacunaEnabled && !menuWindow.fullscreenSuppressed
        && root.frameBorder && root.frameMode !== "off"
      barPosition: root.barPosition
      barSize: root.barControlSize
      barBottomY: root.barBottomY
      barEdgeCasterSize: root.barEdgeCasterSize
      frameWidth: modelData && modelData.width !== undefined ? Number(modelData.width) : menuWindow.width
      frameThickness: root.frameThickness
      frameRadius: root.frameRadius
      moldingPieces: root.frameMoldingPieces
      progress: root.frameOverlayProgress
      frameColor: root.panelColor
      borderColor: root.menuThemeRef.frameBorder
      outputScale: modelData && modelData.devicePixelRatio !== undefined
        ? Number(modelData.devicePixelRatio) : 1
      shadowOffsetX: root.frameShadowOffsetX
      shadowOffsetY: root.frameShadowOffsetY
      sidebarX: panelHost.sidebarMaskX
      sidebarY: panelHost.sidebarMaskY
      sidebarWidth: menuWindow.liveSidebarBodyWidth
      sidebarHeight: panelHost.sidebarMaskHeight
      sidebarMoldingWidth: root.frameMoldingPieces ? root.frameRadius : 0
      sidebarMoldingVisible: menuWindow.sidebarRenderable && root.frameMoldingPieces && root.frameRadius > 0
      leftEdgeOccupied: menuWindow.sidebarRenderable && !root.panelOnRight
      rightEdgeOccupied: menuWindow.sidebarRenderable && root.panelOnRight
      connectorX: panelHost.connectorX
      connectorY: panelHost.connectorY
      connectorWidth: panelHost.effectiveConnectorWidth
      connectorHeight: panelHost.effectiveFlyoutHeight + panelHost.effectiveConnectorWidth * 2
      connectorVisible: menuWindow.sidebarRenderable && panelHost.effectiveConnectorVisible
      flyoutX: panelHost.flyoutMaskX
      flyoutY: panelHost.flyoutMaskY
      flyoutWidth: panelHost.flyoutMaskWidth
      flyoutHeight: panelHost.flyoutMaskHeight
      flyoutVisible: root.flyoutVisibleOnScreen(modelData)
      barPopoutBorderGap: root.hostBarPopoutBorderGapFor(modelData)
    }

    LacunaPanelUnifiedSurface {
      id: panelUnifiedSurface

      anchors.fill: parent
      z: 0
      // The durable sidebar is painted by `surface` below. Do not duplicate
      // it inside the mutable MultiEffect source: that offscreen source is
      // rebuilt as flyout geometry changes and intermittently blanks the real
      // sidebar content for a few compositor frames.
      sidebarVisible: false
      flyoutOpen: root.flyoutOpenOnScreen(modelData)
      flyoutRenderable: root.flyoutVisibleOnScreen(modelData)
      connectorRenderable: menuWindow.sidebarRenderable && panelHost.effectiveConnectorVisible
      shadowEnabled: root.lacunaEnabled && root.frameShadow && root.menuPanelControllerRef.flyoutRenderable
      menuProgress: root.menuPanelControllerRef.menuProgress
      flyoutProgress: root.menuPanelControllerRef.flyoutProgress
      contentProgress: root.menuPanelControllerRef.contentProgress
      sidebarX: panelHost.sidebarX
      panelWidth: root.panelWidth
      surfaceRightInset: Math.max(panelHost.effectiveConnectorWidth, root.frameMoldingPieces ? root.frameRadius : 0)
      barHeight: root.barHeight
      barBottomY: root.barBottomY
      joinRadius: root.frameRadius
      connectorOverlap: root.connectorOverlap
      fullFrame: root.frameMode === "fullframe"
      frameThickness: root.frameThickness
      frameMoldingPieces: root.frameMoldingPieces
      openFromRight: root.panelOnRight
      connectorX: panelHost.connectorX
      connectorY: panelHost.connectorY
      connectorWidth: panelHost.effectiveConnectorWidth
      connectorHeight: panelHost.effectiveFlyoutHeight + panelHost.effectiveConnectorWidth * 2
      flyoutX: panelHost.flyoutX
      flyoutY: panelHost.effectiveFlyoutY
      flyoutWidth: panelHost.effectiveFlyoutWidth
      flyoutHeight: panelHost.effectiveFlyoutHeight
      panelRadius: panelHost.effectivePanelRadius
      panelColor: root.panelColor
      foreground: root.foreground
      designTokens: root.menuDesignTokensRef
      shadowOffsetX: root.frameShadowOffsetX
      shadowOffsetY: root.frameShadowOffsetY
      shadowBlurMax: root.panelShadowBlurMax
      topBarShadowEnabled: root.topBarPanelShadowVisible && !menuWindow.fullscreenSuppressed
      topBarShadowX: root.topBarPanelShadowX
      topBarShadowY: root.barBottomY
      topBarShadowWidth: root.topBarPanelShadowWidth
      topBarShadowHeight: root.topBarPanelShadowHeight
    }

    MenuSurface {
      id: surface

      // Explicitly keep the durable sidebar above the mutable flattened
      // shadow/source layer. MultiEffect source updates may render outside
      // ordinary declaration order for a frame; without this pin, that opaque
      // source covers the sidebar content during flyout geometry changes.
      z: 10
      visible: menuWindow.sidebarRenderable
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      x: panelHost.sidebarX
      panelWidth: root.panelWidth
      open: root.menuState.open
      progress: root.menuPanelControllerRef.menuProgress
      barHeight: root.barHeight
      barBottomY: root.barBottomY
      joinRadius: root.frameRadius
      connectorOverlap: root.connectorOverlap
      bodyRightInset: root.frameMoldingPieces ? root.frameRadius : 0
      fullFrame: root.frameMode === "fullframe"
      frameThickness: root.frameThickness
      barPosition: root.barPosition
      frameMoldingPieces: root.frameMoldingPieces
      frameBorder: root.frameBorder && !frameOverlay.borderOnly
      frameBorderColor: root.menuThemeRef.frameBorder
      attachedFlyoutVisible: root.flyoutVisibleOnScreen(modelData)
        && root.menuPanelControllerRef.flyoutProgress > 0.001
      attachedFlyoutY: panelHost.effectiveConnectorVisible
        ? panelHost.connectorY : panelHost.flyoutMaskY
      attachedFlyoutHeight: panelHost.effectiveConnectorVisible
        ? panelHost.effectiveFlyoutHeight + panelHost.effectiveConnectorWidth * 2
        : panelHost.flyoutMaskHeight
      outputScale: modelData && modelData.devicePixelRatio !== undefined
        ? Number(modelData.devicePixelRatio) : 1
      openFromRight: root.panelOnRight
      panelColor: root.panelColor
      foreground: root.foreground
      designTokens: root.menuDesignTokensRef
      // Keep the visible sidebar paint independent of the flattened
      // sidebar+flyout shadow source. The unified source changes geometry on
      // every flyout frame; relying on it for visible sidebar paint makes the
      // whole left sidebar flash/twitch when that texture is rebuilt.
      // This opaque foreground copy covers the identical source silhouette
      // while the unified surface beneath continues to cast one shadow.
      backgroundVisible: true

      HoverHandler {
        id: sidebarSurfaceHover
        onHoveredChanged: sidebarAutohide.setSidebarHovered(root.sidebarAutohideScreenName(modelData), hovered)
      }

      MenuContent {
        id: menuContent

        visible: menuWindow.sidebarRenderable && !sidebarState.collapsed
        motionTokens: root.menuMotionTokensRef
        anchors.fill: parent
        anchors.leftMargin: root.menuDesignTokensRef.contentInset
        anchors.rightMargin: root.menuDesignTokensRef.contentInset
        anchors.topMargin: root.barBottomY + root.menuDesignTokensRef.topInset
        anchors.bottomMargin: root.menuDesignTokensRef.bottomInset
        compact: root.compact
        designTokens: root.menuDesignTokensRef
        open: root.menuState.open
        menuState: root.menuState
        registry: root.menuRegistryRef
        version: root.version
        themeTitle: root.menuThemeRef.themeTitle
        foreground: root.foreground
        background: root.background
        accent: root.accent
        shellAccent: root.shellAccent
        sessionAccent: root.sessionAccent
        dangerAccent: root.dangerAccent
        navAccent: root.navAccent
        muted: root.muted
        iconRailWidth: root.barControlSize
        mediaPlayerService: root.mediaPlayerService
        mediaPlayerSurfaceId: "sidebar:" + menuWindow.outputName
        onActivated: function(entry) {
          root.activate(entry)
        }
        onQuickLaunchMoveRequested: function(appId, targetIndex) {
          root.moveCustomQuickLaunchApp(appId, targetIndex)
        }
        onQuickLaunchRenameRequested: function(appId, label) {
          root.renameCustomQuickLaunchApp(appId, label)
        }
        onQuickLaunchRemoveRequested: function(appId) {
          root.removeCustomQuickLaunchApp(appId)
        }
        onQuickLaunchRenameOpenChanged: root.setSidebarAutohideContentHeld(modelData, quickLaunchRenameOpen)
        Component.onDestruction: root.setSidebarAutohideContentHeld(modelData, false)
        onSettingsRequested: root.toggleSettingsPanel()
        onShellSettingsRequested: root.toggleShellSettingsPanel()
        onMediaPlayerRequested: root.openMediaPlayerPanel()
        onCollapseRequested: sidebarState.toggleCollapsed()
        onCloseRequested: root.close()
      }

      MenuRail {
        visible: menuWindow.sidebarRenderable && sidebarState.collapsed
        anchors.top: parent.top
        anchors.topMargin: root.barBottomY + root.railTopGap
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.menuDesignTokensRef.bottomInset
        anchors.left: parent.left
        anchors.leftMargin: root.railLeftInset
        compact: root.railCompact
        designTokens: root.menuRailDesignTokensRef
        open: root.menuState.open
        fullscreenSuppressed: menuWindow.fullscreenSuppressed
        menuState: root.menuState
        registry: root.menuRegistryRef
        foreground: root.foreground
        panelWindow: menuWindow
        panelColor: root.panelColor
        accent: root.accent
        shellAccent: root.shellAccent
        sessionAccent: root.sessionAccent
        dangerAccent: root.dangerAccent
        navAccent: root.navAccent
        muted: root.muted
        railWidth: root.railButtonWidth
        mediaPlayerService: root.mediaPlayerService
        motionTokens: root.menuMotionTokensRef
        onExpandRequested: sidebarState.toggleCollapsed()
        onActivated: function(entry) {
          root.activate(entry)
        }
        onSettingsRequested: root.toggleSettingsPanel()
        onShellSettingsRequested: root.toggleShellSettingsPanel()
        onMediaPlayerRequested: root.openMediaPlayerPanel()
      }
    }

    LacunaPanelConnector {
      id: flyoutConnector

      z: 20
      open: root.flyoutOpenOnScreen(modelData)
      renderable: menuWindow.sidebarRenderable && panelHost.effectiveConnectorVisible
      progress: root.menuPanelControllerRef.flyoutProgress
      x: panelHost.connectorX
      y: panelHost.connectorY
      connectorWidth: panelHost.effectiveConnectorWidth
      contentHeight: panelHost.effectiveFlyoutHeight
      panelColor: root.panelColor
      foreground: root.foreground
      backgroundVisible: false

      HoverHandler {
        id: connectorSurfaceHover
        onHoveredChanged: sidebarAutohide.setConnectorHovered(root.sidebarAutohideScreenName(modelData), hovered)
      }
    }

    LacunaAttachedFlyout {
      id: attachedFlyout

      z: 20
      open: root.flyoutOpenOnScreen(modelData)
      renderable: root.flyoutVisibleOnScreen(modelData)
      interactive: root.flyoutInteractiveOnScreen(modelData)
      progress: root.menuPanelControllerRef.flyoutRenderable ? root.menuPanelControllerRef.flyoutProgress : 0
      contentProgress: root.menuPanelControllerRef.contentProgress
      openX: panelHost.flyoutX
      openY: panelHost.effectiveFlyoutY
      openToLeft: root.panelOnRight
      panelWidth: panelHost.effectiveFlyoutWidth
      panelHeight: panelHost.effectiveFlyoutHeight
      panelRadius: panelHost.effectivePanelRadius
      panelColor: root.panelColor
      foreground: root.foreground
      designTokens: root.menuDesignTokensRef
      backgroundVisible: false

      HoverHandler {
        id: attachedFlyoutHover
        onHoveredChanged: sidebarAutohide.setFlyoutHovered(root.sidebarAutohideScreenName(modelData), hovered)
      }

      SettingsWindow {
        id: settingsPanel

        anchors.fill: parent
        visible: root.renderSettingsContent
        enabled: root.settingsPanelOpen
        opacity: root.flyoutContentOpacity("settings")
        open: root.settingsPanelOpen
        currentSection: root.settingsSection
        compact: root.compact
        drawBackground: false
        designTokens: root.menuDesignTokensRef
        registry: root.menuRegistryRef
        version: root.version
        themeTitle: root.menuThemeRef.themeTitle
        foreground: root.foreground
        background: root.background
        accent: root.accent
        shellAccent: root.shellAccent
        sessionAccent: root.sessionAccent
        dangerAccent: root.dangerAccent
        navAccent: root.navAccent
        muted: root.muted
        onCurrentSectionChanged: {
          if (root.flyoutScreen === modelData && root.settingsSection !== currentSection)
            root.settingsSection = currentSection
        }
        onActivated: function(entry) {
          root.holdFlyoutAfterSettingsActivation()
          root.activate(entry)
        }
        onCloseRequested: root.closeFlyouts("explicit-close")

        Component.onCompleted: root.registerFlyoutContent(modelData, "settings", settingsPanel)
        Component.onDestruction: root.unregisterFlyoutContent(modelData, "settings", settingsPanel)
      }

      Loader {
        id: shellSettingsPanel

        property var registryRef: root.menuRegistryRef

        anchors.fill: parent
        active: root.renderShellSettingsContent
        visible: root.renderShellSettingsContent
        opacity: root.flyoutContentOpacity("shellSettings")
        onLoaded: {
          if (!item) return
          item.currentSection = root.shellSettingsSection
          root.registerFlyoutContent(modelData, "shellSettings", item)
        }
        onItemChanged: {
          if (item) root.registerFlyoutContent(modelData, "shellSettings", item)
        }
        Component.onDestruction: root.unregisterFlyoutContent(modelData, "shellSettings", item)
        sourceComponent: Component {
          OmarchyShellSettingsWindow {
            currentSection: root.shellSettingsSection
            open: root.shellSettingsPanelOpen
            compact: root.compact
            drawBackground: false
            designTokens: root.menuDesignTokensRef
            registry: shellSettingsPanel.registryRef
            settingsService: root.shellSettingsService
            foreground: root.foreground
            background: root.background
            accent: root.accent
            shellAccent: root.shellAccent
            sessionAccent: root.sessionAccent
            dangerAccent: root.dangerAccent
            navAccent: root.navAccent
            muted: root.muted
            onCurrentSectionChanged: root.shellSettingsSection = currentSection
            onActivated: function(entry) {
              root.holdFlyoutAfterSettingsActivation()
              root.activate(entry)
            }
            onCloseRequested: root.closeFlyouts("explicit-close")
          }
        }
      }

      FlyoutAppPickerContent {
        id: appPickerContent

        anchors.fill: parent
        opacity: root.flyoutContentOpacity("appPicker")
        registry: root.menuRegistryRef
        appCatalog: root.menuAppCatalogRef
        customQuickLaunchApps: lacunaSettings.data && lacunaSettings.data.customQuickLaunchApps ? lacunaSettings.data.customQuickLaunchApps : []
        preferredApps: lacunaSettings.data && lacunaSettings.data.preferredApps ? lacunaSettings.data.preferredApps : ({})
        compact: root.compact
        open: root.appPickerOpen
        contentVisible: root.renderAppPickerContent
        mode: root.appPickerMode
        preferredRole: root.preferredAppPickerRole
        designTokens: root.menuDesignTokensRef
        foreground: root.foreground
        background: root.background
        accent: root.accent
        muted: root.muted
        onCloseRequested: root.closeFlyouts("explicit-close")
        onSystemSelected: root.setPreferredApp(root.preferredAppPickerRole, "system")
        onAppSelected: function(appId) {
          if (root.appPickerMode === "preferredApp") root.setPreferredApp(root.preferredAppPickerRole, appId)
          else root.addCustomQuickLaunchApp(appId)
        }

        Component.onCompleted: root.registerFlyoutContent(modelData, "appPicker", appPickerContent)
        Component.onDestruction: root.unregisterFlyoutContent(modelData, "appPicker", appPickerContent)
      }

      FlyoutMediaPlayerContent {
        id: mediaPlayerContent

        anchors.fill: parent
        opacity: root.flyoutContentOpacity("mediaPlayer")
        service: root.mediaPlayerService
        compact: root.compact
        open: root.mediaPlayerOpen
        contentVisible: root.renderMediaPlayerContent
        designTokens: root.menuDesignTokensRef
        foreground: root.foreground
        background: root.background
        accent: root.accent
        muted: root.muted
        providerYoutube: root.providerYoutube
        providerJellyfin: root.providerJellyfin
        bodyFontFamily: root.bodyFontFamily
        onCloseRequested: root.closeFlyouts("explicit-close")

        Component.onCompleted: root.registerFlyoutContent(modelData, "mediaPlayer", mediaPlayerContent)
        Component.onDestruction: root.unregisterFlyoutContent(modelData, "mediaPlayer", mediaPlayerContent)
      }
    }

    LacunaPanelBorder {
      id: attachedFlyoutBorder

      anchors.fill: parent
      active: root.lacunaEnabled && root.frameBorder
      connectorVisible: menuWindow.sidebarRenderable && panelHost.effectiveConnectorVisible
      flyoutVisible: root.flyoutVisibleOnScreen(modelData) && root.menuPanelControllerRef.flyoutProgress > 0.001
      openToLeft: root.panelOnRight
      connectorX: panelHost.connectorX
      connectorY: panelHost.connectorY
      connectorWidth: panelHost.effectiveConnectorWidth
      flyoutX: panelHost.flyoutMaskX
      flyoutY: panelHost.flyoutMaskY
      flyoutWidth: panelHost.flyoutMaskWidth
      flyoutHeight: panelHost.flyoutMaskHeight
      panelRadius: panelHost.effectivePanelRadius
      borderColor: root.menuThemeRef.frameBorder
    }

    Item {
      id: restartConfirmOverlay

      visible: root.pendingSystemRestartConfirmation && root.sidebarSurfaceVisible
      enabled: visible
      focus: visible
      z: 1000
      x: panelHost.sidebarMaskX
      y: panelHost.sidebarMaskY
      width: root.panelWidth
      height: panelHost.sidebarMaskHeight
      opacity: visible ? 1 : 0
      onVisibleChanged: if (visible) forceActiveFocus()
      Keys.onEscapePressed: root.cancelSystemRestart()
      Keys.onReturnPressed: root.confirmSystemRestart()
      Keys.onEnterPressed: root.confirmSystemRestart()

      Behavior on opacity {
        LacunaAnim { motion: "fast"; motionTokens: root.menuMotionTokensRef }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.cancelSystemRestart()
      }

      LacunaRect {
        id: restartConfirmDialog

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(root.barBottomY + 44, Math.round((parent.height - height) / 2) - 18)
        width: Math.max(220, Math.min(parent.width - 28, root.compact ? 238 : 270))
        height: root.compact ? 164 : 184
        radius: root.designStyle === "material" ? 12 : root.menuDesignTokensRef.radius
        color: root.background
        border.width: root.designStyle === "lacuna" ? 0 : 1
        border.color: Qt.rgba(root.dangerAccent.r, root.dangerAccent.g, root.dangerAccent.b, 0.26)
        clip: true

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {}
        }

        LacunaRect {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: 2
          color: root.dangerAccent
          opacity: 0.86
        }

        LacunaTablerIcon {
          id: restartConfirmIcon

          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.top: parent.top
          anchors.topMargin: root.compact ? 18 : 20
          name: "refresh"
          color: root.dangerAccent
          iconSize: root.compact ? 20 : 22
        }

        LacunaText {
          anchors.left: restartConfirmIcon.right
          anchors.leftMargin: 10
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: restartConfirmIcon.verticalCenter
          text: "Restart System?"
          color: root.safeValue(root.foreground, "#d8dee9")
          fontFamily: root.safeValue(root.bodyFontFamily, "Hack Nerd Font Propo")
          font.pixelSize: root.compact ? 12 : 13
          font.weight: Font.DemiBold
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.top: restartConfirmIcon.bottom
          anchors.topMargin: root.compact ? 16 : 18
          text: "This will reboot the machine now. Unsaved work in other apps may be lost."
          color: root.safeValue(root.muted, "#8b949e")
          font.family: root.safeValue(root.bodyFontFamily, "Hack Nerd Font Propo")
          font.pixelSize: root.compact ? 10 : 11
          wrapMode: Text.WordWrap
          lineHeight: 1.16
          renderType: Text.NativeRendering
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 16
          height: root.compact ? 30 : 34
          spacing: 8

          LacunaRect {
            width: Math.floor((parent.width - parent.spacing) / 2)
            height: parent.height
            radius: root.designStyle === "material" ? height / 2 : root.menuDesignTokensRef.controlRadius
            color: "transparent"
            border.width: root.designStyle === "lacuna" ? 0 : 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)

            LacunaText {
              anchors.centerIn: parent
              width: parent.width - 14
              text: "Cancel"
              color: root.safeValue(root.muted, "#8b949e")
              fontFamily: root.safeValue(root.bodyFontFamily, "Hack Nerd Font Propo")
              font.pixelSize: root.compact ? 10 : 11
              font.weight: Font.DemiBold
              horizontalAlignment: Text.AlignHCenter
            }

            LacunaStateLayer {
              anchors.fill: parent
              stateColor: root.foreground
              hoverOpacity: root.menuDesignTokensRef.hoverOpacity
              pressOpacity: root.menuDesignTokensRef.activeOpacity
              onTriggered: root.cancelSystemRestart()
            }
          }

          LacunaRect {
            width: parent.width - parent.spacing - Math.floor((parent.width - parent.spacing) / 2)
            height: parent.height
            radius: root.designStyle === "material" ? height / 2 : root.menuDesignTokensRef.controlRadius
            color: Qt.rgba(root.dangerAccent.r, root.dangerAccent.g, root.dangerAccent.b, 0.16)
            border.width: root.designStyle === "lacuna" ? 0 : 1
            border.color: Qt.rgba(root.dangerAccent.r, root.dangerAccent.g, root.dangerAccent.b, 0.32)

            LacunaText {
              anchors.centerIn: parent
              width: parent.width - 14
              text: "Restart"
              color: root.safeValue(root.foreground, "#d8dee9")
              fontFamily: root.safeValue(root.bodyFontFamily, "Hack Nerd Font Propo")
              font.pixelSize: root.compact ? 10 : 11
              font.weight: Font.DemiBold
              horizontalAlignment: Text.AlignHCenter
            }

            LacunaStateLayer {
              anchors.fill: parent
              stateColor: root.dangerAccent
              hoverOpacity: root.menuDesignTokensRef.hoverOpacity
              pressOpacity: root.menuDesignTokensRef.activeOpacity
              onTriggered: root.confirmSystemRestart()
            }
          }
        }
      }
    }
  }

  }

  Variants {
    model: root.sidebarScreens

    LacunaFrameReserveWindow {
      required property var modelData

      targetScreen: modelData
      active: !root.fullscreenWorkspaceOnScreen(modelData) && root.sidebarReserveSize > 0
      edge: root.panelOnRight ? "right" : "left"
      reserveSize: root.sidebarReserveSize
      layerNamespace: root.pluginId + "-sidebar-reserve-" + root.screenNamespace(modelData)
    }
  }

  Variants {
    model: root.sidebarScreens

    LacunaFrameReserveWindow {
      required property var modelData

      targetScreen: modelData
      active: !root.fullscreenWorkspaceOnScreen(modelData) && root.frameReserveTop > 0
      edge: "top"
      reserveSize: root.frameReserveTop
      layerNamespace: root.pluginId + "-frame-reserve-" + root.screenNamespace(modelData)
    }
  }

  Variants {
    model: root.sidebarScreens

    LacunaFrameReserveWindow {
      required property var modelData

      targetScreen: modelData
      active: !root.fullscreenWorkspaceOnScreen(modelData) && root.topBarShadowReserve > 0
      edge: "top"
      reserveSize: root.topBarShadowReserve
      layerNamespace: root.pluginId + "-topbar-shadow-reserve-" + root.screenNamespace(modelData)
    }
  }

  Variants {
    model: root.sidebarScreens

    LacunaFrameReserveWindow {
      required property var modelData

      targetScreen: modelData
      active: !root.fullscreenWorkspaceOnScreen(modelData) && root.frameReserveBottom > 0
      edge: "bottom"
      reserveSize: root.frameReserveBottom
      layerNamespace: root.pluginId + "-frame-reserve-" + root.screenNamespace(modelData)
    }
  }

  Variants {
    model: root.sidebarScreens

    LacunaFrameReserveWindow {
      required property var modelData

      targetScreen: modelData
      active: !root.fullscreenWorkspaceOnScreen(modelData) && root.frameReserveLeft > 0
      edge: "left"
      reserveSize: root.frameReserveLeft
      layerNamespace: root.pluginId + "-frame-reserve-" + root.screenNamespace(modelData)
    }
  }

  Variants {
    model: root.sidebarScreens

    LacunaFrameReserveWindow {
      required property var modelData

      targetScreen: modelData
      active: !root.fullscreenWorkspaceOnScreen(modelData) && root.frameReserveRight > 0
      edge: "right"
      reserveSize: root.frameReserveRight
      layerNamespace: root.pluginId + "-frame-reserve-" + root.screenNamespace(modelData)
    }
  }
}
