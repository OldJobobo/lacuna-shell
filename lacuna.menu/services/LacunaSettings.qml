import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  signal loaded()

  // Keep this version separate from plugin manifest schemaVersion values. It
  // describes the on-disk Lacuna runtime settings contract only.
  readonly property int settingsSchemaVersion: 3
  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy/lacuna"
  readonly property string settingsFile: configDir + "/settings.json"
  readonly property bool primarySettingsService: String(Qt.resolvedUrl(".")).indexOf("/lacuna.state/") >= 0
  readonly property string settingsIpcTarget: primarySettingsService ? "lacuna-settings-state" : "lacuna-menu-settings-state"
  property var data: defaultData()
  property bool settingsPermissionChangePending: false
  property var lastLoadedData: defaultData()
  property var pendingSave: null
  property bool pendingSaveTouchedQuickLaunch: false
  property bool pendingSaveTouchedSidebar: false
  property string queuedSavePayload: ""
  property int queuedSaveRevision: 0
  property string inFlightSavePayload: ""
  property int inFlightSaveRevision: 0
  property string lastConfirmedSavePayload: ""
  property string retrySavePayload: ""
  property int retrySaveRevision: 0
  property int retryWriteNonce: 0
  property bool writeInFlight: false
  property int requestedSaveRevision: 0
  property int confirmedSaveRevision: 0
  property string persistenceState: "idle"
  property string persistenceError: ""
  property int suppressFileReloads: 0
  property bool hasLoaded: false
  property bool recoveredFromCorruptSettings: false
  // Runtime-only visual bridges. Publishers keep QML objects here so
  // foreground ambience can repaint the authoritative frame border above its
  // effects without persisting animation state or duplicating its clock.
  property var foregroundFrameSources: ({})

  function publishForegroundFrameSource(screenName, owner, bridge) {
    var key = String(screenName || "")
    var sourceOwner = String(owner || "")
    if (key === "" || sourceOwner === "" || !bridge) return
    var next = {}
    for (var screenKey in foregroundFrameSources) {
      next[screenKey] = {}
      for (var ownerKey in foregroundFrameSources[screenKey])
        next[screenKey][ownerKey] = foregroundFrameSources[screenKey][ownerKey]
    }
    if (!next[key]) next[key] = {}
    next[key][sourceOwner] = bridge
    foregroundFrameSources = next
  }

  function clearForegroundFrameSource(screenName, owner, bridge) {
    var key = String(screenName || "")
    var sourceOwner = String(owner || "")
    if (!foregroundFrameSources[key]
        || foregroundFrameSources[key][sourceOwner] !== bridge) return
    var next = {}
    for (var screenKey in foregroundFrameSources) {
      next[screenKey] = {}
      for (var ownerKey in foregroundFrameSources[screenKey]) {
        if (screenKey !== key || ownerKey !== sourceOwner)
          next[screenKey][ownerKey] = foregroundFrameSources[screenKey][ownerKey]
      }
    }
    foregroundFrameSources = next
  }

  function foregroundFrameSource(screenName) {
    var sources = foregroundFrameSources[String(screenName || "")]
    if (!sources) return null
    return sources.menu || sources.bar || null
  }

  function defaultData() {
    return {
      version: root.settingsSchemaVersion,
      designStyle: "lacuna",
      designStyles: {
        lacuna: {},
        omarchy: {},
        material: {}
      },
      colorProfile: "semantic",
      geometry: {
        cornerMode: "theme",
        cornerRadius: 14
      },
      compact: false,
      reduceMotion: false,
      barSizeMode: "theme",
      barPresentation: {
        portraitSplit: true
      },
      quickLaunchLayout: "list",
      dailyLaunchLayout: "list",
      shortcutsLayout: "list",
      controlsLayout: "grid",
      barSizeSnapshot: null,
      sizeTransition: {
        holdCompact: false,
        holdUntil: 0
      },
      customQuickLaunchApps: [],
      customQuickLaunchNames: {},
      preferredApps: {
        files: "system",
        editor: "system",
        email: "system",
        discord: "system"
      },
      power: {
        instantRestart: false
      },
      shellSettings: {
        surface: "flyout"
      },
      mediaProviders: {
        youtube: {
          enabled: false,
          cookiesFromBrowser: "",
          cookiesFile: ""
        },
        jellyfin: {
          enabled: false,
          serverUrl: "",
          apiKey: "",
          userId: "",
          preferredAudioLanguage: "English"
        }
      },
      mediaPlayer: {
        presentationMode: "auto",
        videoQuality: "adaptive",
        providerFilter: "all"
      },
      sidebar: {
        defaultMode: "off",
        collapsed: false,
        exclusive: true,
        connectorPieces: true,
        // One-release downgrade alias. It follows connectorPieces only; once
        // frame and connector settings diverge a v1 reader cannot preserve both.
        cornerPieces: true,
        monitorPolicy: "auto",
        monitorNames: [],
        autoHide: {
          enabled: false,
          hotZoneWidth: 3,
          revealDelayMs: 120,
          hideDelayMs: 350
        }
      },
      backgroundEffects: {
        enabled: true,
        foregroundOverlay: false,
        opacity: 1,
        activeEffect: "trackingLines",
        activeEffects: [
          "trackingLines"
        ],
        effects: {
          trackingLines: {
            enabled: true
          },
          filmGrain: {
            enabled: true,
            intensity: 0.28,
            speed: 1,
            grainCount: 180,
            grainSize: 1.35,
            accentBlend: 0.18
          },
          dustMotes: {
            enabled: true,
            intensity: 0.5,
            speed: 0.7,
            moteCount: 72,
            moteSize: 2.6,
            accentBlend: 0.42,
            mouseReactive: true,
            mouseInfluence: 0.28
          },
          auroraDrift: {
            enabled: true
          },
          rainfall: {
            enabled: true
          },
          cinematicLight: {
            enabled: true
          },
          godRays: {
            enabled: true
          },
          crt: {
            enabled: true
          }
        }
      },
      backgroundVignette: {
        enabled: false,
        intensity: 0.85,
        ignoreBackgroundAnimationLayer: false
      },
      frame: {
        mode: "off",
        reserveMode: "auto",
        shadow: false,
        border: false,
        moldingPieces: true,
        // One-release schema-v2 alias for builds that used this interim name.
        roundedContentCorners: true,
        thickness: 8,
        radius: 14,
        shadowDirection: "bottom_right",
        shadowOffsetX: 2,
        shadowOffsetY: 3
      }
    }
  }

  function migrateSettings(value) {
    var source = {}
    if (value && typeof value === "object") {
      for (var key in value) {
        var safe = normalizeJsonValue(value[key])
        if (safe !== undefined) source[key] = safe
      }
    }

    var version = Number(source.version)
    if (!isFinite(version) || version < 1) {
      if (source.sidebar === undefined && source.sidebarMode !== undefined) {
        source.sidebar = { defaultMode: source.sidebarMode }
      }
      if (source.designStyles === undefined && source.stylePresets !== undefined) {
        source.designStyles = source.stylePresets
      }
    }
    if (version > root.settingsSchemaVersion) {
      console.warn("Lacuna settings.json is newer than this plugin; preserving known JSON-safe fields")
    }
    source.version = root.settingsSchemaVersion
    return source
  }

  function preserveUnknownJson(target, source, knownKeys) {
    if (!target || !source || typeof source !== "object") return
    for (var key in source) {
      if (knownKeys && knownKeys[key] === true) continue
      var safe = normalizeJsonValue(source[key])
      if (safe !== undefined) target[key] = safe
    }
  }

  function normalize(value) {
    var source = migrateSettings(value)
    value = value && typeof value === "object" ? value : ({})
    var next = defaultData()
    if (source && typeof source === "object") {
      var sourceGeometry = source.geometry && typeof source.geometry === "object" ? source.geometry : ({})
      var sourceSidebar = source.sidebar && typeof source.sidebar === "object" ? source.sidebar : ({})
      var sourceAutoHide = sourceSidebar.autoHide && typeof sourceSidebar.autoHide === "object" ? sourceSidebar.autoHide : ({})
      var sourceFrame = source.frame && typeof source.frame === "object" ? source.frame : ({})
      var legacyFrameRadius = boundedInt(sourceFrame.radius, 14, 0, 32)
      var inferredCornerMode = sourceGeometry.cornerMode !== undefined
        ? normalizeCornerMode(sourceGeometry.cornerMode)
        : (sourceFrame.radius !== undefined && legacyFrameRadius === 0
          ? "square"
          : (sourceFrame.radius !== undefined && legacyFrameRadius !== 14 ? "custom" : "theme"))
      next.geometry.cornerMode = inferredCornerMode
      next.geometry.cornerRadius = boundedInt(sourceGeometry.cornerRadius,
        inferredCornerMode === "custom" ? legacyFrameRadius : 14, 0, 32)
      preserveUnknownJson(next.geometry, sourceGeometry, {
        cornerMode: true,
        cornerRadius: true
      })
      var legacyCornerPieces = sourceSidebar.cornerPieces !== false
      next.sidebar.connectorPieces = typeof sourceSidebar.connectorPieces === "boolean"
        ? sourceSidebar.connectorPieces : legacyCornerPieces
      next.sidebar.cornerPieces = next.sidebar.connectorPieces
      var legacyFrameMolding = typeof sourceFrame.roundedContentCorners === "boolean"
        ? sourceFrame.roundedContentCorners : legacyCornerPieces
      next.frame.moldingPieces = typeof sourceFrame.moldingPieces === "boolean"
        ? sourceFrame.moldingPieces : legacyFrameMolding
      next.frame.roundedContentCorners = next.frame.moldingPieces
      preserveUnknownJson(next, source, {
        version: true,
        designStyle: true,
        designStyles: true,
        stylePresets: true,
        designStylePresets: true,
        colorProfile: true,
        geometry: true,
        quickLaunchLayout: true,
        quickLaunchView: true,
        dailyLaunchLayout: true,
        launchLayout: true,
        dailyLaunchView: true,
        shortcutsLayout: true,
        shortcutLayout: true,
        shortcutsView: true,
        controlsLayout: true,
        controlLayout: true,
        controlsView: true,
        barSizeMode: true,
        barPresentation: true,
        compact: true,
        reduceMotion: true,
        barSizeSnapshot: true,
        sizeTransition: true,
        customQuickLaunchApps: true,
        quickLaunch: true,
        customQuickLaunchNames: true,
        quickLaunchNames: true,
        preferredApps: true,
        defaultLaunchers: true,
        appDefaults: true,
        power: true,
        session: true,
        system: true,
        shellSettings: true,
        omarchySettings: true,
        mediaProviders: true,
        providers: true,
        mediaPlayer: true,
        player: true,
        sidebar: true,
        backgroundEffects: true,
        bgEffects: true,
        backgroundVignette: true,
        bgVignette: true,
        vignette: true,
        frame: true
      })
      next.designStyle = normalizeDesignStyle(source.designStyle)
      next.designStyles = normalizeDesignStyles(source.designStyles || source.stylePresets || source.designStylePresets)
      next.colorProfile = String(source.colorProfile || "").toLowerCase() === "colorful" ? "colorful" : "semantic"
      next.quickLaunchLayout = normalizeLayoutMode(source.quickLaunchLayout || source.quickLaunchView, "list")
      next.dailyLaunchLayout = normalizeLayoutMode(source.dailyLaunchLayout || source.launchLayout || source.dailyLaunchView, "list")
      next.shortcutsLayout = normalizeLayoutMode(source.shortcutsLayout || source.shortcutLayout || source.shortcutsView, "list")
      next.controlsLayout = normalizeControlsLayout(source.controlsLayout || source.controlLayout || source.controlsView)
      next.barSizeMode = normalizeBarSizeMode(source.barSizeMode, source.compact === true)
      if (source.barPresentation && typeof source.barPresentation === "object") {
        next.barPresentation.portraitSplit = typeof source.barPresentation.portraitSplit === "boolean"
          ? source.barPresentation.portraitSplit
          : defaultData().barPresentation.portraitSplit
        preserveUnknownJson(next.barPresentation, source.barPresentation, {
          portraitSplit: true
        })
      }
      next.compact = next.barSizeMode === "compact"
      next.reduceMotion = value.reduceMotion === true
      next.barSizeSnapshot = normalizeBarSizeSnapshot(source.barSizeSnapshot)
      next.sizeTransition = normalizeSizeTransition(source.sizeTransition)
      next.customQuickLaunchApps = normalizeCustomQuickLaunchApps(source.customQuickLaunchApps || source.quickLaunch)
      next.customQuickLaunchNames = normalizeCustomQuickLaunchNames(source.customQuickLaunchNames || source.quickLaunchNames, next.customQuickLaunchApps)
      next.preferredApps = normalizePreferredApps(source.preferredApps || source.defaultLaunchers || source.appDefaults)
      next.power = normalizePowerSettings(source.power || source.session || source.system)
      next.shellSettings = normalizeShellSettings(source.shellSettings || source.omarchySettings)
      next.mediaProviders = normalizeMediaProviders(source.mediaProviders || source.providers)
      next.mediaPlayer = normalizeMediaPlayer(source.mediaPlayer || source.player)
      if (source.sidebar && typeof source.sidebar === "object") {
        next.sidebar.defaultMode = normalizeSidebarDefaultMode(sourceSidebar.defaultMode)
        next.sidebar.collapsed = sourceSidebar.collapsed === true
        next.sidebar.exclusive = sourceSidebar.exclusive !== false
        next.sidebar.connectorPieces = typeof sourceSidebar.connectorPieces === "boolean"
          ? sourceSidebar.connectorPieces : legacyCornerPieces
        // Persist the legacy v1 alias as the sidebar connector value only.
        next.sidebar.cornerPieces = next.sidebar.connectorPieces
        next.sidebar.monitorPolicy = normalizeSidebarMonitorPolicy(sourceSidebar.monitorPolicy)
        next.sidebar.monitorNames = normalizeSidebarMonitorNames(sourceSidebar.monitorNames)
        next.sidebar.autoHide.enabled = sourceAutoHide.enabled === true
        next.sidebar.autoHide.hotZoneWidth = boundedInt(sourceAutoHide.hotZoneWidth, 3, 2, 8)
        next.sidebar.autoHide.revealDelayMs = boundedInt(sourceAutoHide.revealDelayMs, 120, 0, 1000)
        next.sidebar.autoHide.hideDelayMs = boundedInt(sourceAutoHide.hideDelayMs, 350, 0, 3000)
        preserveUnknownJson(next.sidebar.autoHide, sourceAutoHide, {
          enabled: true,
          revealMode: true,
          hotZoneWidth: true,
          revealDelayMs: true,
          hideDelayMs: true
        })
        preserveUnknownJson(next.sidebar, sourceSidebar, {
          defaultMode: true,
          collapsed: true,
          exclusive: true,
          connectorPieces: true,
          cornerPieces: true,
          monitorPolicy: true,
          monitorNames: true,
          autoHide: true
        })
      }
      next.backgroundEffects = normalizeBackgroundEffects(source.backgroundEffects || source.bgEffects)
      next.backgroundVignette = normalizeBackgroundVignette(source.backgroundVignette || source.bgVignette || source.vignette)
      if (source.frame && typeof source.frame === "object") {
        next.frame.mode = normalizeFrameMode(sourceFrame.mode)
        next.frame.reserveMode = normalizeFrameReserveMode(sourceFrame.reserveMode)
        next.frame.shadow = sourceFrame.shadow === true
        next.frame.border = sourceFrame.border === true
        next.frame.moldingPieces = typeof sourceFrame.moldingPieces === "boolean"
          ? sourceFrame.moldingPieces : legacyFrameMolding
        // Temporary compatibility alias; future black outer corner pieces are
        // a separate feature and are intentionally not represented here.
        next.frame.roundedContentCorners = next.frame.moldingPieces
        next.frame.thickness = boundedInt(sourceFrame.thickness, 8, 2, 24)
        next.frame.shadowDirection = normalizeShadowDirection(sourceFrame.shadowDirection)
        var offset = shadowOffsetFor(next.frame.shadowDirection)
        next.frame.shadowOffsetX = boundedInt(source.frame.shadowOffsetX, offset.x, -8, 8)
        next.frame.shadowOffsetY = boundedInt(source.frame.shadowOffsetY, offset.y, -8, 8)
        preserveUnknownJson(next.frame, sourceFrame, {
          mode: true,
          reserveMode: true,
          shadow: true,
          border: true,
          moldingPieces: true,
          roundedContentCorners: true,
          thickness: true,
          radius: true,
          shadowDirection: true,
          shadowOffsetX: true,
          shadowOffsetY: true
        })
      }
      // Compatibility alias for schema-v2 readers. Runtime geometry uses
      // geometry.cornerMode/cornerRadius and never reads this value.
      next.frame.radius = next.geometry.cornerMode === "square"
        ? 0 : next.geometry.cornerRadius
    }
    next.version = root.settingsSchemaVersion
    return next
  }

  function normalizeBackgroundVignette(value) {
    var defaults = defaultData().backgroundVignette
    var next = {
      enabled: defaults.enabled,
      intensity: defaults.intensity,
      ignoreBackgroundAnimationLayer: defaults.ignoreBackgroundAnimationLayer
    }

    if (value === true || value === false) {
      next.enabled = value === true
      return next
    }

    if (value && typeof value === "object") {
      next.enabled = value.enabled === true
      next.intensity = boundedReal(value.intensity, defaults.intensity, 0, 1)
      next.ignoreBackgroundAnimationLayer = value.ignoreBackgroundAnimationLayer === true
        || value.ignoreBackgroundAnimations === true
        || value.ignoreAnimationLayer === true
      preserveUnknownJson(next, value, {
        enabled: true,
        intensity: true,
        ignoreBackgroundAnimationLayer: true,
        ignoreBackgroundAnimations: true,
        ignoreAnimationLayer: true
      })
    }

    return next
  }

  function normalizePowerSettings(value) {
    var next = defaultData().power
    if (value && typeof value === "object") {
      next.instantRestart = value.instantRestart === true || value.instantReboot === true
      preserveUnknownJson(next, value, {
        instantRestart: true,
        instantReboot: true
      })
    }
    return next
  }

  function normalizeShellSettings(value) {
    var next = defaultData().shellSettings
    if (value && typeof value === "object") {
      var surface = String(value.surface || value.mode || "").toLowerCase()
      next.surface = surface === "window" || surface === "floating" || surface === "panel" ? "window" : "flyout"
      preserveUnknownJson(next, value, {
        surface: true,
        mode: true
      })
    }
    return next
  }

  function normalizeMediaProviders(value) {
    var next = defaultData().mediaProviders
    if (value && typeof value === "object") {
      var youtube = value.youtube && typeof value.youtube === "object" ? value.youtube : ({})
      var legacyYoutubeMusic = value.youtubeMusic && typeof value.youtubeMusic === "object" ? value.youtubeMusic : ({})
      next.youtube = {
        enabled: youtube.enabled === true || legacyYoutubeMusic.enabled === true,
        cookiesFromBrowser: String(youtube.cookiesFromBrowser || ""),
        cookiesFile: String(youtube.cookiesFile || legacyYoutubeMusic.authPath || "")
      }
      // Preserve future legacy-provider fields while migrating them into the
      // canonical youtube object. Apply canonical fields second so they win
      // unknown-key collisions as well as the documented known-key aliases.
      preserveUnknownJson(next.youtube, legacyYoutubeMusic, {
        enabled: true,
        authPath: true,
        cookiesFromBrowser: true,
        cookiesFile: true
      })
      preserveUnknownJson(next.youtube, youtube, {
        enabled: true,
        cookiesFromBrowser: true,
        cookiesFile: true
      })
      var jellyfin = value.jellyfin && typeof value.jellyfin === "object" ? value.jellyfin : ({})
      next.jellyfin = {
        enabled: jellyfin.enabled === true,
        serverUrl: String(jellyfin.serverUrl || ""),
        apiKey: String(jellyfin.apiKey || ""),
        userId: String(jellyfin.userId || ""),
        preferredAudioLanguage: normalizeJellyfinAudioLanguage(jellyfin.preferredAudioLanguage)
      }
      preserveUnknownJson(next.jellyfin, jellyfin, {
        enabled: true,
        serverUrl: true,
        apiKey: true,
        userId: true,
        preferredAudioLanguage: true
      })
      preserveUnknownJson(next, value, {
        youtube: true,
        youtubeMusic: true,
        jellyfin: true
      })
    }
    return next
  }

  function normalizeJellyfinAudioLanguage(value) {
    var language = String(value || "English").trim()
    if (language === "") return "English"
    var lowered = language.toLowerCase()
    if (lowered === "default" || lowered === "original" || lowered === "auto") return "Default"
    if (lowered === "english" || lowered === "eng" || lowered === "en") return "English"
    if (lowered === "japanese" || lowered === "jpn" || lowered === "ja") return "Japanese"
    return language
  }

  function normalizeMediaPlayer(value) {
    var defaults = defaultData().mediaPlayer
    var source = value && typeof value === "object" ? value : ({})
    var presentationMode = String(source.presentationMode || defaults.presentationMode).toLowerCase()
    var videoQuality = String(source.videoQuality || defaults.videoQuality).toLowerCase()
    var providerFilter = String(source.providerFilter || defaults.providerFilter).toLowerCase()
    var next = {
      presentationMode: presentationMode === "inline" || presentationMode === "background" ? presentationMode : "auto",
      videoQuality: videoQuality === "stable" ? "stable" : "adaptive",
      providerFilter: providerFilter === "youtube" || providerFilter === "jellyfin" ? providerFilter : "all"
    }
    preserveUnknownJson(next, source, {
      presentationMode: true,
      videoQuality: true,
      providerFilter: true
    })
    return next
  }

  function normalizeBackgroundEffects(value) {
    var defaults = defaultData().backgroundEffects
    var next = {
      enabled: true,
      foregroundOverlay: defaults.foregroundOverlay === true,
      opacity: defaults.opacity,
      activeEffect: defaults.activeEffect,
      activeEffects: defaults.activeEffects.slice(),
      effects: {}
    }

    for (var defaultId in defaults.effects) {
      next.effects[defaultId] = normalizeBackgroundEffectConfig(defaultId, defaults.effects[defaultId])
    }

    if (value && typeof value === "object") {
      next.enabled = value.enabled !== false
      next.foregroundOverlay = value.foregroundOverlay === true
      next.opacity = boundedReal(value.opacity, defaults.opacity, 0, 1)
      next.activeEffects = normalizeBackgroundEffectStack(value.activeEffects, value.activeEffect || value.selectedEffect || value.currentEffect)
      next.activeEffect = next.activeEffects.length > 0 ? next.activeEffects[0] : normalizeBackgroundEffectId(value.activeEffect || value.selectedEffect || value.currentEffect, defaults.activeEffect)

      var sourceEffects = value.effects && typeof value.effects === "object" ? value.effects : {}
      for (var effectId in sourceEffects) {
        next.effects[effectId] = normalizeBackgroundEffectConfig(effectId, sourceEffects[effectId])
      }
      preserveUnknownJson(next, value, {
        enabled: true,
        foregroundOverlay: true,
        opacity: true,
        activeEffect: true,
        activeEffects: true,
        selectedEffect: true,
        currentEffect: true,
        effects: true
      })
    }

    if (!next.effects.trackingLines) next.effects.trackingLines = normalizeBackgroundEffectConfig("trackingLines", true)
    if (!next.effects.filmGrain) next.effects.filmGrain = normalizeBackgroundEffectConfig("filmGrain", true)
    if (!next.effects.dustMotes) next.effects.dustMotes = normalizeBackgroundEffectConfig("dustMotes", true)
    if (!next.effects.auroraDrift) next.effects.auroraDrift = normalizeBackgroundEffectConfig("auroraDrift", true)
    if (!next.effects.rainfall) next.effects.rainfall = normalizeBackgroundEffectConfig("rainfall", true)
    if (!next.effects.cinematicLight) next.effects.cinematicLight = normalizeBackgroundEffectConfig("cinematicLight", true)
    if (!next.effects.godRays) next.effects.godRays = normalizeBackgroundEffectConfig("godRays", true)
    if (!next.effects.crt) next.effects.crt = normalizeBackgroundEffectConfig("crt", true)
    if (!value || typeof value !== "object") {
      next.activeEffect = next.activeEffects.length > 0 ? next.activeEffects[0] : defaults.activeEffect
    }
    return next
  }

  function normalizeBackgroundEffectConfig(effectId, value) {
    var defaults = defaultData().backgroundEffects.effects[String(effectId || "")] || { enabled: true }
    var next = {}
    for (var key in defaults) next[key] = defaults[key]

    if (value === true || value === false) {
      next.enabled = value === true
      return next
    }

    if (value && typeof value === "object") {
      next.enabled = value.enabled !== false
      if (effectId === "filmGrain") {
        next.intensity = boundedReal(value.intensity, defaults.intensity, 0, 1)
        next.speed = boundedReal(value.speed, defaults.speed, 0.2, 5)
        next.grainCount = boundedInt(value.grainCount, defaults.grainCount, 32, 520)
        next.grainSize = boundedReal(value.grainSize, defaults.grainSize, 0.6, 3.5)
        next.accentBlend = boundedReal(value.accentBlend, defaults.accentBlend, 0, 1)
      } else if (effectId === "dustMotes") {
        next.intensity = boundedReal(value.intensity, defaults.intensity, 0, 1)
        next.speed = boundedReal(value.speed, defaults.speed, 0.15, 4)
        next.moteCount = boundedInt(value.moteCount, defaults.moteCount, 12, 180)
        next.moteSize = boundedReal(value.moteSize, defaults.moteSize, 1, 8)
        next.accentBlend = boundedReal(value.accentBlend, defaults.accentBlend, 0, 1)
        next.mouseReactive = value.mouseReactive !== false
        next.mouseInfluence = boundedReal(value.mouseInfluence, defaults.mouseInfluence, 0, 1)
      }
      preserveUnknownJson(next, value, backgroundEffectKnownKeys(effectId))
    }

    return next
  }

  function backgroundEffectKnownKeys(effectId) {
    var known = { enabled: true }
    if (effectId === "filmGrain") {
      known.intensity = true
      known.speed = true
      known.grainCount = true
      known.grainSize = true
      known.accentBlend = true
    } else if (effectId === "dustMotes") {
      known.intensity = true
      known.speed = true
      known.moteCount = true
      known.moteSize = true
      known.accentBlend = true
      known.mouseReactive = true
      known.mouseInfluence = true
    }
    return known
  }

  function normalizeBackgroundEffectStack(value, fallback) {
    var source = Array.isArray(value) ? value : [fallback || defaultData().backgroundEffects.activeEffect]
    var seen = {}
    var next = []
    for (var i = 0; i < source.length; i++) {
      var id = normalizeBackgroundEffectId(source[i], "")
      if (id === "" || seen[id] === true) continue
      seen[id] = true
      next.push(id)
    }
    return next
  }

  function normalizeBackgroundEffectId(value, fallback) {
    var id = String(value || "").trim()
    if (id === "trackingLines" || id === "filmGrain" || id === "dustMotes" || id === "auroraDrift" || id === "rainfall" || id === "cinematicLight" || id === "godRays" || id === "crt") return id
    if (fallback === "filmGrain" || fallback === "dustMotes" || fallback === "auroraDrift" || fallback === "rainfall" || fallback === "cinematicLight" || fallback === "godRays" || fallback === "crt") return fallback
    if (fallback === "trackingLines") return fallback
    if (fallback === "") return ""
    return "trackingLines"
  }

  function boundedReal(value, fallback, minimum, maximum) {
    var parsed = Number(value)
    if (!isFinite(parsed)) return fallback
    return Math.max(minimum, Math.min(maximum, parsed))
  }

  function boundedInt(value, fallback, minimum, maximum) {
    var parsed = Math.round(Number(value))
    if (!isFinite(parsed)) return fallback
    return Math.max(minimum, Math.min(maximum, parsed))
  }

  function normalizeCornerMode(value) {
    var mode = String(value || "").toLowerCase()
    if (mode === "square" || mode === "custom") return mode
    return "theme"
  }

  function normalizeFrameMode(value) {
    var mode = String(value || "").toLowerCase()
    if (mode === "fullframe" || mode === "on" || mode === "true" || mode === "1") return "fullframe"
    return "off"
  }

  function normalizeFrameReserveMode(value) {
    var mode = String(value || "").toLowerCase()
    if (mode === "comfort" || mode === "flush") return mode
    return "auto"
  }

  function normalizeShadowDirection(value) {
    var direction = String(value || "").toLowerCase()
    var valid = {
      top_left: true,
      top: true,
      top_right: true,
      left: true,
      center: true,
      right: true,
      bottom_left: true,
      bottom: true,
      bottom_right: true
    }
    return valid[direction] ? direction : "bottom_right"
  }

  function shadowOffsetFor(value) {
    var direction = normalizeShadowDirection(value)
    if (direction === "top_left") return Qt.point(-2, -2)
    if (direction === "top") return Qt.point(0, -3)
    if (direction === "top_right") return Qt.point(2, -2)
    if (direction === "left") return Qt.point(-3, 0)
    if (direction === "center") return Qt.point(0, 0)
    if (direction === "right") return Qt.point(3, 0)
    if (direction === "bottom_left") return Qt.point(-2, 2)
    if (direction === "bottom") return Qt.point(0, 3)
    return Qt.point(2, 3)
  }

  function normalizeBarSizeMode(value, compactFallback) {
    var mode = String(value || "").toLowerCase()
    if (mode === "theme" || mode === "compact" || mode === "full") return mode
    return compactFallback === true ? "compact" : "full"
  }

  function normalizeControlsLayout(value) {
    return normalizeLayoutMode(value, "grid")
  }

  function normalizeSidebarDefaultMode(value) {
    var mode = String(value || "").toLowerCase()
    if (mode === "off" || mode === "rail" || mode === "full") return mode
    return "off"
  }

  function normalizeSidebarMonitorPolicy(value) {
    var policy = String(value || "").toLowerCase()
    if (policy === "pinned" || policy === "fixed" || policy === "selected") return "pinned"
    if (policy === "all" || policy === "everywhere") return "all"
    return "auto"
  }

  function normalizeSidebarMonitorNames(value) {
    var source = Array.isArray(value) ? value : String(value || "").split(",")
    var names = []
    var seen = {}
    for (var i = 0; i < source.length && names.length < 16; i++) {
      var name = String(source[i] || "").trim()
      if (name === "" || seen[name]) continue
      seen[name] = true
      names.push(name)
    }
    return names
  }

  function normalizeLayoutMode(value, fallback) {
    var layout = String(value || "").toLowerCase()
    if (layout === "grid" || layout === "list") return layout
    return fallback === "list" ? "list" : "grid"
  }

  function normalizeBarSizeSnapshot(value) {
    if (!value || typeof value !== "object") return null

    var themeName = String(value.themeName || "").trim()
    var sizeHorizontal = Math.round(Number(value.sizeHorizontal))
    var sizeVertical = Math.round(Number(value.sizeVertical))

    if (themeName === "" || !isFinite(sizeHorizontal) || !isFinite(sizeVertical)) return null
    if (sizeHorizontal <= 0 || sizeVertical <= 0) return null

    var next = {
      themeName: themeName,
      sizeHorizontal: sizeHorizontal,
      sizeVertical: sizeVertical
    }
    preserveUnknownJson(next, value, {
      themeName: true,
      sizeHorizontal: true,
      sizeVertical: true
    })
    return next
  }

  function normalizeSizeTransition(value) {
    if (!value || typeof value !== "object") return defaultData().sizeTransition
    var next = {
      holdCompact: value.holdCompact === true,
      holdUntil: boundedInt(value.holdUntil, 0, 0, 9999999999999)
    }
    preserveUnknownJson(next, value, {
      holdCompact: true,
      holdUntil: true
    })
    return next
  }

  function normalizeCustomQuickLaunchApps(value) {
    var list = []
    if (!value || !Array.isArray(value)) return list

    for (var i = 0; i < value.length; i++) {
      var id = String(value[i] || "").trim()
      if (id.indexOf("role:") === 0) continue
      if (id !== "" && list.indexOf(id) === -1) list.push(id)
    }

    return list.slice(0, 12)
  }

  function normalizeCustomQuickLaunchNames(value, ids) {
    var names = {}
    if (!value || typeof value !== "object") return names

    for (var i = 0; i < ids.length; i++) {
      var id = String(ids[i] || "")
      var name = String(value[id] || "").trim()
      if (id !== "" && name !== "") names[id] = name.slice(0, 48)
    }

    return names
  }

  function normalizePreferredApps(value) {
    var defaults = defaultData().preferredApps
    var next = {
      files: defaults.files,
      editor: defaults.editor,
      email: defaults.email,
      discord: defaults.discord
    }

    if (!value || typeof value !== "object") return next

    var roles = ["files", "editor", "email", "discord"]
    for (var i = 0; i < roles.length; i++) {
      var role = roles[i]
      var id = String(value[role] || "").trim()
      next[role] = id === "" ? "system" : id
    }
    preserveUnknownJson(next, value, {
      files: true,
      editor: true,
      email: true,
      discord: true
    })

    return next
  }

  function normalizeDesignStyle(value) {
    var style = String(value || "").toLowerCase()
    if (style === "lacuna" || style === "carbon") return "lacuna"
    if (style === "omarchy" || style === "material") return style
    return "lacuna"
  }

  function normalizeDesignStyles(value) {
    var next = defaultData().designStyles
    if (!value || typeof value !== "object") return next

    preserveUnknownJson(next, value, {
      lacuna: true,
      omarchy: true,
      material: true
    })
    var styles = ["lacuna", "omarchy", "material"]
    for (var i = 0; i < styles.length; i++) {
      var style = styles[i]
      var source = value[style]
      if (!source || typeof source !== "object") continue

      var preset = {}
      var bar = normalizeDesignStyleBar(source.bar || source.barLayout)
      if (bar !== null) preset.bar = bar
      preserveUnknownJson(preset, source, { bar: true, barLayout: true })
      next[style] = preset
    }

    return next
  }

  function normalizeDesignStyleBar(value) {
    if (!value || typeof value !== "object") return null
    var sourceLayout = value.layout && typeof value.layout === "object" ? value.layout : value
    var layout = normalizeBarLayout(sourceLayout)
    var centerAnchor = String(value.centerAnchor || "").trim()

    if (centerAnchor === ""
        && layout.left.length === 0
        && layout.center.length === 0
        && layout.right.length === 0) return null

    var next = { layout: layout }
    if (centerAnchor !== "") next.centerAnchor = centerAnchor
    if (value.layout && typeof value.layout === "object") {
      preserveUnknownJson(next, value, { layout: true, centerAnchor: true })
    }
    return next
  }

  function normalizeBarLayout(value) {
    var next = { left: [], center: [], right: [] }
    if (!value || typeof value !== "object") return next

    var sections = ["left", "center", "right"]
    for (var i = 0; i < sections.length; i++) {
      var section = sections[i]
      var source = Array.isArray(value[section]) ? value[section] : []
      for (var j = 0; j < source.length; j++) {
        var entry = normalizeBarLayoutEntry(source[j])
        if (entry !== null) next[section].push(entry)
      }
    }
    preserveUnknownJson(next, value, {
      left: true,
      center: true,
      right: true
    })

    return next
  }

  function normalizeBarLayoutEntry(value) {
    if (typeof value === "string") {
      var stringId = String(value).trim()
      return stringId === "" ? null : { id: stringId }
    }
    if (!value || typeof value !== "object") return null
    var id = String(value.id || "").trim()
    if (id === "") return null

    var next = { id: id }
    for (var key in value) {
      if (key === "id") continue
      var normalized = normalizeJsonValue(value[key])
      if (normalized !== undefined) next[key] = normalized
    }
    return next
  }

  function designStyleBar(style) {
    var key = normalizeDesignStyle(style)
    var styles = data && data.designStyles ? data.designStyles : ({})
    var preset = styles[key]
    return preset && preset.bar ? preset.bar : null
  }

  function saveDesignStyleBar(style, value) {
    var key = normalizeDesignStyle(style)
    var next = normalize(data)
    if (!next.designStyles || typeof next.designStyles !== "object") next.designStyles = {}
    if (!next.designStyles[key] || typeof next.designStyles[key] !== "object") next.designStyles[key] = {}
    var bar = normalizeDesignStyleBar(value)
    if (bar === null) delete next.designStyles[key].bar
    else next.designStyles[key].bar = bar
    save(next)
  }

  function normalizeJsonValue(value) {
    if (value === null) return null
    var t = typeof value
    if (t === "string" || t === "boolean") return value
    if (t === "number") return isFinite(value) ? value : undefined
    if (Array.isArray(value)) {
      var list = []
      for (var i = 0; i < value.length; i++) {
        var item = normalizeJsonValue(value[i])
        if (item !== undefined) list.push(item)
      }
      return list
    }
    if (t === "object") {
      var object = {}
      for (var key in value) {
        var child = normalizeJsonValue(value[key])
        if (child !== undefined) object[key] = child
      }
      return object
    }
    return undefined
  }

  function nextDesignStyle(value) {
    var style = normalizeDesignStyle(value)
    if (style === "lacuna") return "omarchy"
    if (style === "omarchy") return "material"
    return "lacuna"
  }

  function load() {
    settingsFileView.reload()
  }

  function applyLoadedText(raw) {
    var parsed
    try {
      parsed = normalize(JSON.parse(String(raw || "{}")))
    } catch (e) {
      console.warn("Lacuna settings.json is not valid JSON; backing up and restoring defaults:", e)
      var corrupt = String(raw || "")
      if (corrupt.trim().length > 0 && corrupt.trim() !== "{}") {
        settingsBackupFileView.setText(corrupt)
        recoveredFromCorruptSettings = true
      }
      parsed = defaultData()
    }

    data = parsed
    lastLoadedData = data
    if (!writeInFlight) lastConfirmedSavePayload = JSON.stringify(data, null, 2) + "\n"
    hasLoaded = true
    loaded()
    if (pendingSave) {
      var queuedTouchedQuickLaunch = pendingSaveTouchedQuickLaunch
      var queuedTouchedSidebar = pendingSaveTouchedSidebar
      var queued = mergePendingSave(lastLoadedData, pendingSave, queuedTouchedQuickLaunch, queuedTouchedSidebar)
      pendingSave = null
      pendingSaveTouchedQuickLaunch = false
      pendingSaveTouchedSidebar = false
      save(queued, queuedTouchedQuickLaunch, queuedTouchedSidebar)
    }
  }

  function writePayload(payload, revision) {
    var nextRevision = Math.max(1, Number(revision) || 0)
    if (writeInFlight) {
      // If the newest intent is byte-identical to the active write, advance
      // that write's revision and discard an older queued detour. Otherwise
      // retain only the newest complete normalized payload.
      if (payload === inFlightSavePayload) {
        inFlightSaveRevision = nextRevision
        queuedSavePayload = ""
        queuedSaveRevision = 0
      } else {
        queuedSavePayload = payload
        queuedSaveRevision = nextRevision
      }
      persistenceState = "saving"
      return
    }

    writeInFlight = true
    inFlightSavePayload = payload
    inFlightSaveRevision = nextRevision
    persistenceState = persistenceState === "retrying" ? "retrying" : "saving"
    persistenceError = ""
    suppressFileReloads += 1
    settingsFileView.setText(payload)
  }

  function handleSaveSucceeded() {
    if (!writeInFlight) return
    confirmedSaveRevision = Math.max(confirmedSaveRevision, inFlightSaveRevision)
    lastConfirmedSavePayload = inFlightSavePayload
    retrySavePayload = ""
    retrySaveRevision = 0
    writeInFlight = false
    inFlightSavePayload = ""
    inFlightSaveRevision = 0
    secureSettingsFile()

    if (queuedSavePayload !== "") {
      var nextPayload = queuedSavePayload
      var nextRevision = queuedSaveRevision
      queuedSavePayload = ""
      queuedSaveRevision = 0
      persistenceState = "saving"
      writePayload(nextPayload, nextRevision)
    } else {
      persistenceState = "saved"
      persistenceError = ""
      retryWriteNonce = 0
    }
  }

  function handleSaveFailed(error) {
    if (!writeInFlight) return
    // Failed writes do not emit fileChanged, so release the matching reload
    // suppression token here instead of swallowing a future external edit.
    suppressFileReloads = Math.max(0, suppressFileReloads - 1)
    var failedPayload = inFlightSavePayload
    var failedRevision = inFlightSaveRevision
    writeInFlight = false
    inFlightSavePayload = ""
    inFlightSaveRevision = 0

    if (queuedSavePayload !== "") {
      // A newer intent supersedes this failure and gets an immediate chance to
      // converge. If it also fails, that newest payload becomes retryable.
      var nextPayload = queuedSavePayload
      var nextRevision = queuedSaveRevision
      queuedSavePayload = ""
      queuedSaveRevision = 0
      persistenceState = "saving"
      writePayload(nextPayload, nextRevision)
      return
    }

    retrySavePayload = failedPayload
    retrySaveRevision = failedRevision
    persistenceState = "failed"
    persistenceError = "Could not save Lacuna settings (" + String(error) + ")"
  }

  function retryPersistence() {
    if (writeInFlight || retrySavePayload === "") return false
    writeInFlight = true
    inFlightSavePayload = retrySavePayload
    inFlightSaveRevision = retrySaveRevision || requestedSaveRevision
    persistenceState = "retrying"
    persistenceError = ""
    suppressFileReloads += 1
    // setText() suppresses identical assignments even when the prior write
    // failed. Add harmless trailing JSON whitespace so every explicit retry
    // schedules a fresh atomic write without changing the document value.
    retryWriteNonce += 1
    var retryText = retrySavePayload
    for (var i = 0; i < retryWriteNonce; i++) retryText += "\n"
    settingsFileView.setText(retryText)
    return true
  }

  function secureSettingsFile() {
    permissionsTimer.restart()
  }

  function save(next, touchedQuickLaunch, touchedSidebar) {
    if (!hasLoaded) {
      pendingSave = normalize(next)
      pendingSaveTouchedQuickLaunch = pendingSaveTouchedQuickLaunch || touchedQuickLaunch === true
      pendingSaveTouchedSidebar = pendingSaveTouchedSidebar || touchedSidebar === true
      load()
      return
    }

    data = normalize(next)
    var json = JSON.stringify(data, null, 2) + "\n"
    requestedSaveRevision += 1
    if (!writeInFlight && json === lastConfirmedSavePayload) {
      confirmedSaveRevision = requestedSaveRevision
      persistenceState = "saved"
      persistenceError = ""
      return
    }
    writePayload(json, requestedSaveRevision)
  }

  function mergePendingSave(base, queued, queuedTouchedQuickLaunch, queuedTouchedSidebar) {
    var merged = normalize(queued)
    var loadedBase = normalize(base)

    if (queuedTouchedQuickLaunch !== true
        && (!merged.customQuickLaunchApps || merged.customQuickLaunchApps.length === 0)
        && loadedBase.customQuickLaunchApps && loadedBase.customQuickLaunchApps.length > 0) {
      merged.customQuickLaunchApps = loadedBase.customQuickLaunchApps
      merged.customQuickLaunchNames = loadedBase.customQuickLaunchNames || {}
    }

    if (queuedTouchedSidebar !== true
        && JSON.stringify(merged.sidebar) === JSON.stringify(defaultData().sidebar)
        && JSON.stringify(loadedBase.sidebar) !== JSON.stringify(defaultData().sidebar)) {
      merged.sidebar = loadedBase.sidebar
    }

    return merged
  }

  Component.onCompleted: {
    secureSettingsFile()
    load()
  }

  Timer {
    id: permissionsTimer
    interval: 150
    repeat: false
    onTriggered: {
      root.settingsPermissionChangePending = true
      permissionsProc.running = false
      permissionsProc.command = ["chmod", "600", root.settingsFile, root.settingsFile + ".bak"]
      permissionsProc.running = true
      permissionsResetTimer.restart()
    }
  }

  Timer {
    id: permissionsResetTimer
    interval: 500
    repeat: false
    onTriggered: root.settingsPermissionChangePending = false
  }

  FileView {
    id: settingsFileView

    path: root.settingsFile
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyLoadedText(text())
    onSaved: root.handleSaveSucceeded()
    onSaveFailed: function(error) { root.handleSaveFailed(error) }
    onFileChanged: {
      if (root.settingsPermissionChangePending) {
        root.settingsPermissionChangePending = false
        return
      }
      if (root.suppressFileReloads > 0) {
        root.suppressFileReloads -= 1
      } else {
        reload()
      }
    }
    // Missing at startup seeds defaults; a transient failure after a valid
    // load retains the last known-good document instead of resetting state.
    onLoadFailed: if (!root.hasLoaded) root.applyLoadedText("{}")
  }

  FileView {
    id: settingsBackupFileView

    path: root.settingsFile + ".bak"
    atomicWrites: true
    printErrors: false
  }

  IpcHandler {
    target: root.settingsIpcTarget

    function status(): string {
      var geometry = root.data && root.data.geometry ? root.data.geometry : ({})
      var sidebar = root.data && root.data.sidebar ? root.data.sidebar : ({})
      return JSON.stringify({
        ready: root.hasLoaded,
        settingsFile: root.settingsFile,
        schemaVersion: root.settingsSchemaVersion,
        cornerMode: root.normalizeCornerMode(geometry.cornerMode),
        cornerRadius: root.boundedInt(geometry.cornerRadius, 14, 0, 32),
        sidebarAutoHideEnabled: sidebar.autoHide && sidebar.autoHide.enabled === true,
        persistenceState: root.persistenceState,
        persistenceError: root.persistenceError,
        requestedRevision: root.requestedSaveRevision,
        confirmedRevision: root.confirmedSaveRevision,
        queuedRevision: root.queuedSaveRevision,
        retryAvailable: root.retrySavePayload !== ""
      })
    }

    function retry(): string {
      return JSON.stringify({ ok: root.retryPersistence(), state: root.persistenceState })
    }

    function patchBarSize(payload: string): string {
      if (!root.hasLoaded) return JSON.stringify({ ok: false, error: "settings not loaded" })
      var patch
      try {
        patch = JSON.parse(String(payload || "{}"))
      } catch (e) {
        return JSON.stringify({ ok: false, error: "invalid patch" })
      }
      if (!patch || typeof patch !== "object" || !Array.isArray(patch.keys) || !patch.values || typeof patch.values !== "object") {
        return JSON.stringify({ ok: false, error: "invalid patch" })
      }

      var next = root.normalize(root.data)
      for (var i = 0; i < patch.keys.length; i++) {
        var key = String(patch.keys[i] || "")
        if (key === "barSizeMode" || key === "compact" || key === "barSizeSnapshot" || key === "sizeTransition") {
          next[key] = patch.values[key]
        }
      }
      root.save(next)
      return JSON.stringify({ ok: true, data: root.data })
    }
  }

  Process {
    id: permissionsProc
  }
}
