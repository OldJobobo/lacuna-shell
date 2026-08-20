function isPanelSlot(slot, region, screenName, band) {
  if (!slot || (region && slot.region !== region)) return false
  if (screenName && slot.surfaceScreenName !== screenName) return false
  if (band && slot.band !== band) return false

  var item = slot.activeItem
  if (!item || item.visible !== true) return false
  if (slot.visible !== true || slot.width <= 0 || slot.height <= 0) return false
  return typeof item.open === "function"
    && typeof item.close === "function"
    && item.opened !== undefined
}

// Resolve panel-capable slots in shell.json layout order rather than runtime
// registration order. The first drawn copy is enough for positional lookup:
// invoking the returned widget id still routes through the bar's normal
// multi-monitor panel selection.
function panelNavigationSlots(entries, slots, region, screenName, band) {
  var layout = Array.isArray(entries) ? entries : []
  var candidates = Array.isArray(slots) ? slots : []
  var resolvedRegion = String(region || "")
  var result = []

  for (var i = 0; i < layout.length; i++) {
    var entry = layout[i]
    var id = typeof entry === "string"
      ? entry
      : (entry && entry.id !== undefined && entry.id !== null ? String(entry.id) : "")
    if (!id) continue

    for (var j = 0; j < candidates.length; j++) {
      var slot = candidates[j]
      if (!slot || slot.moduleName !== id) continue
      if (!isPanelSlot(slot, resolvedRegion, screenName, band)) continue
      result.push(slot)
      break
    }
  }
  return result
}

// Positional panel shortcuts are one-based. Keep Omarchy's numeric coercion
// and rounding contract, while returning no id for invalid or out-of-range
// positions.
function panelWidgetIdAt(entries, slots, region, index) {
  // `entries` already scopes lookup to the configured shell.json section.
  // Do not filter by the rendered region here: portrait routing may move a
  // configured-right widget onto a companion center surface.
  var resolved = panelNavigationSlots(entries, slots, "", "", "")
  var offset = Math.round(Number(index)) - 1
  if (!isFinite(offset) || offset < 0 || offset >= resolved.length) return ""
  return String(resolved[offset].moduleName || "")
}

if (typeof module !== "undefined") {
  module.exports = {
    isPanelSlot: isPanelSlot,
    panelNavigationSlots: panelNavigationSlots,
    panelWidgetIdAt: panelWidgetIdAt
  }
}
