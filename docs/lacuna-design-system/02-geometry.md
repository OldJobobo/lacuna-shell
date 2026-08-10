# 02 · Geometry — the seam language

> Principle 2: **Show the seam.** Principle 3: **Absence has weight.**
> This document absorbs and supersedes the "Flyout Surface Geometry" section of `AGENTS.md`,
> which should link here.

Geometry is where Lacuna's identity lives most visibly. The signature is a deliberate tension:
**sharp, square interior geometry** joined by **curved molding connectors**. Surfaces are honest
rectangles; the only curves in the system are the trim pieces that bridge a gap between two
surfaces, plus the rounding of a surface's *exposed* outer corners.

## The one curve constant

Every curve in Lacuna — every molding connector and every rounded corner — is a quarter-circle
approximated by one cubic Bézier, controlled by a single number:

```qml
// shared/qml/LacunaGeometry.qml — canonical build-time source
readonly property real curveKappa: 0.5522847498   // = 4/3 * (sqrt(2) - 1)
```

`curveKappa` is the cubic-Bézier control-point multiplier that makes a quarter
turn approximate a circular arc. Plugins cannot import across runtime
boundaries, so `scripts/sync-vendored` copies this canonical file into each
plugin and equality tests prevent drift. A second independently maintained
source is a bug; verified vendored runtime copies are required packaging.

Control points for a quarter arc of radius `r` are placed at `r * (1 - curveKappa)` from the
corner. This is the canonical pattern used by `MenuSurface.qml`'s join shapes; reuse it.

## The molding connector

When a flyout attaches to the sidebar, Lacuna does **not** round the meeting corners. Instead:

- The attachment edge (the side that touches) stays **square**.
- A **connector** bridges the gap: a straight body between the panel's top and bottom, plus two
  `ShapePath` cubic pieces *outside* the panel bounds — one above, one a vertical mirror below.
- The connector uses the **same `curveKappa`** as the sidebar/topbar join, so the trim reads as
  one continuous piece of moulding around the whole assembly.

This is the Carbon-era join, re-grounded in the gap metaphor: the connector is *trim over a seam*,
not a corner radius that hides the seam exists.

### Attachment geometry

From `lacuna.menu/menu/MenuSurface.qml` and the corner system:

```
                 connectorWidth = joinRadius
                 ┌──┐
   ┌─────────────┤  ╲────────────────┐
   │   sidebar   │   │   flyout       │   flyout placed at x = panelWidth + connectorWidth
   │  (square    │   │  (square left, │   connector drawn at x = panelWidth
   │   right edge│   │   rounded      │
   │   here)     │   │   right edge)  │
   └─────────────┤   ╱────────────────┘
                 └──┘
```

- If the universal resolved corner radius is **positive**: reserve `connectorWidth = joinRadius`, where
  `joinRadius` is the same resolved theme/square/custom radius as the flyout's exposed corners;
  place the flyout at `panelWidth + connectorWidth`, and draw the connector at `x: panelWidth` so
  it sits *between* sidebar and flyout.
- If the universal resolved corner radius is **zero**: connector pieces are disabled and the
  flyout attaches directly at `panelWidth`. Any positive resolved radius enables connector
  molding. There is no independent sidebar-connector setting.

`LacunaPanelHost` applies this as a newest-wins geometry transaction. Flyout
bounds, connector width/overlap, exposed radius, attachment offset, panel paint,
shadow, border, and compositor input masks all read the same interpolated
`effectivePanelGeometry`. A request that arrives mid-transition captures the
currently painted geometry before targeting the new key. Effective values are
pixel-snapped once at the transaction boundary so paint, shadow, border,
offsets, and compositor masks cannot narrow fractional values differently. The
frame border consumes the exact interpolated frame hole record used by frame
fill; it must never reconstruct hole bounds from discrete occupancy flags.
When an attached flyout interrupts a vertical border edge, the gap splits only
the straight segment: each resumed segment must first reach the canonical
corner tangent before entering its cubic arc. While connector molding is
visible, that gap is bounded by `connectorY` and `connectorY + connectorHeight`,
not by the inset flyout body; otherwise the straight rail overpaints both
connector cubics past their sidebar tangents. The attached-panel outline uses
the same half-stroke inset, color, and width around flyout edges and both
connector molding curves. Its lower connector endpoint is one full connector
radius below the flyout bottom; stopping at the flyout bottom reverses the
cubic and visibly drops the lower-left molding edge.
The mapped flyout lane counterbalances the effective connector width and reserves
one rounding-safety pixel, so it stays constant without clipping independently
snapped odd-width transitions. Connector visibility is derived from
the effective width crossing a small epsilon, so disabling it cannot leave a
detached gap or input hole. Reduced motion commits the same transaction at
progress 1 without animation.

## Frame molding versus future corner pieces

Frame molding pieces are the curved trim that joins frame rails around the
content shell, including the upper and lower joins beside a sidebar. Like the
sidebar connector, they are enabled exactly when the universal resolved corner
radius is positive; there is no independent frame-molding setting.
The four corners and their connecting rails must always have one rendering
owner. On a screen without the hosted sidebar, the bar's Top frame paints the
complete border. On the hosted-sidebar screen, the bar passes its authoritative
interpolated geometry record to the Overlay menu window; that
window paints the complete border once, above the opaque sidebar, and the Top
frame disables its border paint for that screen. Never transfer an individual
corner between renderers or leave both complete paths active: either choice
changes antialias coverage between covered and uncovered corners.

The phrase **corner pieces** is reserved for a future black outer-screen mask
that will visually round the physical shell corners in the Noctalia style.
That feature is intentionally not implemented here and will not reuse frame
molding or attached-flyout connector state.

## Corner states

Selective corner rounding is encoded per corner, not via `Rectangle.radius`. From
`lacuna.menu/menu/LacunaShapeSurface.qml` and `LacunaCornerHelper.qml`:

| State | Meaning |
|---|---|
| `-1` | **square** — an attachment or interior edge; no rounding |
| `0` | **rounded inward** — a normal exposed corner |
| `1` / `2` | **outer / molding curves** — connector trim that bows away from the body |

`LacunaCornerHelper` provides the math: `multX(state)`, `multY(state)`, `arcDirection(mx, my)`
(Clockwise vs Counterclockwise), and `flattenedRadius(dimension, requested)` which clamps a
radius to half the available dimension so curves never overrun.

**For a right-opening flyout attached to the sidebar:** keep the left edge square
(`topLeft`/`bottomLeft = -1`) and round only the top-right and bottom-right corners
(`= 0`). Never `Rectangle.radius` — it rounds all four corners and breaks the seam.

## Fill-only surfaces

> Principle 2 again: the seam, not a frame, defines an edge.

Lacuna surface shells are **fill-only** (`strokeWidth: 0`). Do **not** draw thin outer borders
around a flyout or panel shell. Edges are expressed by the `seam` color used on *internal*
dividers, controls, and explicit selected states — never as a hairline outlining the whole
surface. A bordered shell reads as a card; Lacuna wants a recess in space.

The optional global **Frame Border** is the deliberate exception. When enabled,
its single solid theme-border outline continues around the exposed edges and
molding curves of attached flyouts. Bar-owned flyouts use the same universal
resolved radius for connector molding and exposed corners; radius zero removes
the connector reserve and leaves a square attached panel. In standalone mode
they overlap their bar edge by one pixel so connector fill and curve outlines
meet the bar without a compositor-sized seam. Full Frame uses zero overlap so
the flyout and frame-border centerlines coincide. At the far endpoint, let the
owning border rail resume one pixel beneath the connector cap so half-pixel
curve rasterization cannot open a gap.
The attachment edge remains open so each flyout shares
the frame outline instead of becoming a separately boxed card. When Full Frame is off, the same toggle
draws only the exposed outside seam of the combined bar/sidebar shell, not a
closed box around either surface. A bar rail is clipped at the sidebar molding's
outer tangent; the sidebar then owns that curve and its vertical content edge.
The full-frame shadow remains one authoritative caster. Its application-reveal
hole moves to the live sidebar body edge; the caster radius then produces the
molding's outer tangent, preserving the rail, curve, and vertical sidebar
shadow as one contour. An attached flyout's full connector/flyout envelope
masks that contour, preventing the sidebar shadow from crossing the joined
surface while preserving the flyout's outer shadow. Neither paint path may continue behind the other or into content
space. When a sidebar
flyout attaches, this standalone seam uses the same outer connector bounds as
the full-frame border and stops for the entire molding gap.

The active bar flyout reports one screen-axis attachment interval. Standalone
bar outline, full-frame border, hosted-sidebar overlay border, and foreground
ambience repaint all split the matching top/bottom/left/right rail at that same
interval; no renderer may reconstruct it from popup bounds.

An expanded sidebar is also an exclusion zone for horizontal bar flyouts. If a
flyout's preferred placement would cross the sidebar molding tangent, shift the
complete molded surface to the first clear coordinate while preserving its bar
attachment overlap. The collapsed rail does not trigger this displacement;
normal screen-edge clamping remains the fallback when an output is too narrow
to fit both surfaces.

## Painted treatments (the visible metaphor)

These make the metaphor *visible* rather than implied. All are gated to the `lacuna` design
style (`omarchy`/`material` render flat) and derive their tone from the theme.

> **Why not tonal "void wells"?** An earlier attempt recessed content into a darker well. On a
> near-black theme there is no darkness left to carve into, so it never read — and a light inset
> frame either disappears or looks like a card. Lacuna therefore carries depth and the void
> through **lines** (seams + gaps), which read on any theme, not through tone.

- **Visible seams**. Structural dividers use a single derived `seam` hairline (`ink@0.16` under
  lacuna, `~0.08` otherwise) instead of scattered faint values — joins are *shown*.
- **Gapped dividers** (`gappedDividers` / `dividerGap = 22`). Full-width structural dividers, and
  the seam under each section header, are drawn as two segments with a centered gap — a deliberate
  *lacuna* in the line. Repeated down the menu, it is the signature negative-space mark.

A deliberate seam line is the sanctioned exception to "fill-only" — it is an *explicit edge*, not
a frame around the shell.

## Theme-aware exposed corners

Lacuna has one universal corner policy. Its default `theme` mode removes Lacuna's Hyprland
rounding override and consumes Omarchy's live `Style.cornerRadius` from the active theme. `square`
writes Hyprland `decoration:rounding = 0`; `custom` writes the exact `geometry.cornerRadius`
(0–32). Thus Lacuna surfaces, trim, and application windows share one live radius, and resetting
to `theme` resumes inheritance everywhere.

Sidebar-attached and bar-owned flyout fill, connector molding, exposed border,
and shadow source consume that one resolved radius; compositor input regions
continue to consume the same transactional surface bounds.
Frame fill, frame border, frame shadow, video clipping, and vignette clipping consume
`frameContentRadius = resolvedCornerRadius` from the authoritative frame geometry record. A zero
radius is a genuinely square path, not a tiny cubic with a rounded stroke join, and disables both
frame molding and sidebar connector pieces. Connector `joinRadius` equals the same resolved radius,
so Theme, Square, and Custom own exposed corners and all trim as one geometry system.

## The radius scale

Lacuna's interior is square; its *joins and exposed corners* carry the only radii. Values are
density-aware via `mix(full, compact)` (see [03-motion.md](03-motion.md) and the density note
below). Current `lacuna`-style values in `DesignTokens.qml`:

| Token | Full | Compact | Role |
|---|---|---|---|
| `radius` | `0` | `0` | interior surfaces / item backgrounds — **always square** |
| `controlRadius` | `0` | `0` | controls (buttons, toggles) — **always square** |
| `panelRadius` | theme/custom resolved | theme/custom resolved | exposed outer corners of a surface; standalone token fallback is `14` |
| `joinRadius` | theme/custom resolved | theme/custom resolved | connector trim radius and width; identical to `panelRadius` |
| `connectorOverlap` | `33` | `25` | how far the connector overlaps for a seamless join |
| `borderWidth` | `0` | `0` | **no shell borders** (Principle 2 / fill-only) |

The contrast is the point: **`radius: 0` everywhere inside, real curves only at joins and exposed
corners.** That sharp/curved tension is more Lacuna than any single value.

## Density

Lacuna interpolates between a full and a compact layout with a single progress value, so the shell
can shrink continuously rather than snapping between two states:

```qml
function mix(fullValue, compactValue) {
  var p = Math.max(0, Math.min(1, compactProgress))   // 0 = full, 1 = compact
  return fullValue + (compactValue - fullValue) * p
}
```

Spacing, insets, item heights, and `connectorOverlap` flow through `mix()`. `joinRadius` instead
tracks the resolved exposed-corner radius exactly, independent of density.
Representative spacing scale (`LacunaTokens.qml`): `tiny 2 · small 4 · normal 8 · large 10 ·
xLarge 14`. Representative item heights (`DesignTokens.qml`, full→compact): `item 38→32 ·
primary 40→34 · featured 48→42 · compact 32→28`.

## Alternate styles

`DesignTokens.qml` keeps two non-Lacuna styles selectable. They exist for users who want a more
conventional look; they are **not** the Lacuna language:

| | `lacuna` | `omarchy` | `material` |
|---|---|---|---|
| `radius` | 0 | 2 | 8 |
| `panelRadius` fallback | 14 | 2 | 12 |
| `controlRadius` | 0 | 2 | 9 |
| `borderWidth` | 0 | 1 | 1 |
| `joinRadius` fallback | 14 | 2 | 12 |
| `headerTreatment` | accent-line | body-border | tonal |
| `railTreatment` | linework | contained | tonal |

The Carbon alias that previously made `lacuna === carbon` is **removed** (see
[06-roadmap.md](06-roadmap.md), Phase A). `lacuna` is now original.

## Rules

1. **One canonical `curveKappa`, vendored and verified everywhere.** Never maintain a plugin copy independently.
2. **Square interior, curves only at joins and exposed corners.**
3. **Molding connectors over rounded join corners.** Show the seam.
4. **No `Rectangle.radius` on attached surfaces** — use per-corner `Shape` states.
5. **Fill-only shells (`strokeWidth: 0`).** Borders belong to internal controls, not surfaces.
6. **One resolved exposed-corner radius.** Theme inheritance is the default; Lacuna square/custom state is an explicit live override.
7. **Borders trace authoritative geometry.** If frame molding resolves the frame radius to zero, the frame border is square too.
