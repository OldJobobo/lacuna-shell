# Layer Stacking Policy

Status: reference

Every Lacuna plugin window is a wlr-layer-shell surface. The compositor gives
us exactly two stacking controls, and nothing else:

1. **Layer level** (`WlrLayershell.layer`): background < bottom < top < overlay.
2. **Map order within a level**: a surface mapped later stacks above surfaces
   mapped earlier in the same level, and cannot be restacked afterwards.

Map order is whatever the runtime happens to do — it changes with toggle
timing, restarts, and code motion. Two regressions came from relying on it:
the video fade cover rendering under the video (separate cover window), and
the full frame painting over the bar and sidebar (frame window mapped at
toggle time). Hence the rules below.

## Rules

1. **Pick the correct level first.** Never compensate for a wrong level with
   map-order tricks.
2. **Surfaces that must sit under later same-level UI stay mapped
   permanently** unless an explicit resource-lifecycle exception below applies.
   Toggling `visible` remaps a surface to the top of its level.
3. **Declaration order in the host is the intended order for Lacuna-owned
   surfaces, not a guarantee about the Omarchy bar.** In `lacuna.bar/Bar.qml`
   the frame surface is declared before `OmarchyBarAdapter`, which is
   declared before `MenuWindow`, and the layer-policy contract test pins this.
   Quattro maps the host-owned `omarchy-bar` on its own schedule; on the
   current build `hyprctl layers` reports `omarchy-bar` before
   `lacuna-bar-frame`. The frame therefore excludes the bar strip by geometry
   so correctness does not depend on controlling the host's map order.
4. **Compose within one window when elements must stack against each other**
   (deterministic sibling z-order) instead of using a second layer surface —
   e.g. the video wallpaper's black fade cover lives inside the video window.
   `lacuna.ambience-host` applies this rule to background effects: index 0 in
   `activeEffects` is frontmost, and reorder changes sibling `z` only.
5. **Prefer geometry over stacking against surfaces we do not control.** The
   vendored Omarchy bar maps on its own schedule, so the frame never paints
   the strip the bar occupies (`outerX/outerY/outerRight/outerBottom` in
   `LacunaFrameWindow.qml`); the bar itself is the frame edge on its side and
   the stacking between the two becomes irrelevant.
6. **Every `WlrLayershell.layer` assignment is pinned** by
   `test_layer_stacking_policy` in `tests/test_qml_contracts.py`. Adding a
   window or changing a layer must update the table there and this document.
7. **A real Hyprland fullscreen window is always visually topmost.** Lacuna
   Top paint, borders, bars, reserves, popups, and Overlay effects must suppress
   their paint, input, and exclusive zones on that output while its active
   workspace reports fullscreen. Persistent surfaces stay mapped and become
   transparent where map-order stability requires it; transient surfaces close.

## Level assignments

| Level | Surfaces | Notes |
| --- | --- | --- |
| background | `omarchy-background` (Omarchy), `lacuna-media-player-video`, `lacuna-background-vignette` (ignore-animations mode) | Video surfaces remain mapped to preserve reliable background-layer presentation and carry their fade cover internally. |
| bottom | `lacuna-ambience-host-bottom` (enabled bottom mode only), fallback ambience overlays, `lacuna-desktop-clock`, `lacuna-background-vignette` (default) | Disabled ambience maps no host surface. |
| top | `omarchy-bar`, `lacuna-bar-portrait-companion` (portrait split outputs only), `lacuna-bar-frame` (always mapped), frame/sidebar reserve windows | The frame surface owns border paint except on the hosted-sidebar screen, where its border is disabled and the Overlay menu window recomposes the complete border above the opaque sidebar. No additional layer surface is created. All Top paint and reserves suppress per output during real fullscreen. |
| overlay | `lacuna-menu` sidebar and attached flyouts, `lacuna-ambience-host-overlay` (enabled foreground mode only), transient panels, `omarchy-bar-drag-ghost`, non-exclusive Lacuna panels | The complete menu surface stays above the Top frame by layer level, so frame fill and shadow cannot cover a flyout regardless of map order. Foreground ambience may paint above existing Overlay UI and repaints the authoritative frame-border path inside its own window. No Overlay paint appears above a real fullscreen window. |

## Verifying live

```bash
hyprctl layers
```

Within `Layer level 2 (top)` the current Quattro list is expected to show
`omarchy-bar`, one `lacuna-bar-portrait-companion` per portrait split output,
and `lacuna-bar-frame`; there is no `lacuna-bar-frame-border` namespace.
The open `lacuna-menu` sidebar appears at Overlay, above the Top frame. Foreground
ambience also appears at Overlay when enabled and may paint above existing
Overlay UI under the documented resource-first mapping policy. Disabled ambience
has no host namespaces; enabled ambience has exactly one selected host per output.
While an output has a real fullscreen window, its Lacuna bar/frame/sidebar and
foreground ambience hosts may remain listed but must paint nothing, accept no
input, and reserve no exclusive zone.
The exact bar/frame order is
host-controlled; verify that `LacunaFrameWindow.qml` still excludes the bar
strip. Frame surfaces appear even when their paint is inactive and are
intentionally always mapped (rule 2). The Lacuna installer also owns
`~/.local/state/omarchy/toggles/hypr/zz-lacuna-layer-animation.lua`, which
matches both possible full-frame border owners (`lacuna-bar-frame` and the
hosted `lacuna.menu-menu-*` surface) with `no_anim = true`. This keeps theme
layer animations from translating persistent frame chrome while leaving the
sidebar and flyout's in-window QML animations intact. Portrait companion surfaces exist only
where the split is effective. On a portrait split output, verify that the
companion edge is owned by its bar-sized exclusive zone rather than the frame
reserve.

## Resource policy

Mapped shells and heavyweight content share explicit resource lifecycles:

- Disabled ambience maps neither host. Enabled ambience maps exactly the chosen
  Bottom or Overlay host and instantiates only selected effects. Dynamic Bottom
  mapping may place ambience above an already-mapped desktop clock or default
  Bottom vignette; foreground Overlay mode likewise accepts overpainting
  already-mapped Overlay UI. These are explicit resource-first semantics.
- Media-player video surfaces remain mapped because dynamically revealing a
  previously hidden Background `PanelWindow` is not reliable in the live shell.
  Decoder/player content remains lazy and the existing black-cover lifecycle
  still gates entry, playback, normal/failure exit, and fade settlement.
- The persistent Top frame owns fill and shadow. It also owns border paint on
  screens without the hosted sidebar. On the hosted-sidebar screen, the
  Overlay menu window receives the same frame geometry record and owns the
  complete border path; the frame copy is disabled there. There is
  no separate frame-border surface. Portrait companions exist only on
  effective portrait split outputs. Fullscreen suppression gates both copies,
  the owning bar, and every frame reserve without remapping persistent paint.
- Sidebar autohide reuses the existing Overlay `lacuna-menu` surface. This keeps
  the complete sidebar/connector/flyout assembly above the persistent Top frame
  by layer level rather than fragile same-layer map order. Foreground ambience
  remains at Overlay and accepts the resource-first mapping semantics described
  above. The frame still clips its fill at the sidebar's live body edge. The existing frame shadow remains authoritative:
  its reveal hole follows the live sidebar body edge, and the caster's existing
  radius produces the molding's outer tangent. Opening the sidebar therefore moves
  the same full-frame shadow contour around the sidebar instead of disabling
  the rail shadow or joining separately rasterized shadows. While an attached
  flyout is visible, its complete attachment envelope is added to the inverse
  shadow mask so the sidebar contour cannot paint over the flyout; the flyout's
  own outer shadow remains visible. Foreground ambience remains
  above ordinary windows, and its own window repaints only the crisp authoritative
  border afterward. No extra layer-shell surface is added, and the menu remains
  above the frame regardless of map order. The sidebar surface
  remains mapped while its narrow left-edge input zone is armed; only
  its paint and input mask change. Because it is transient shell paint, it
  never mutates the persistent background-content rectangle consumed by
  wallpaper, video, or vignette surfaces; the visible frame border still
  follows the sidebar edge. The vignette rasterizes its SVG once per output
  size and lets the scene graph scale the cached texture. Autohide adds no
  namespace or layer level, and fullscreen clears the hot-zone input region on
  the affected output.
- The frame animation override is installed transactionally when `lacuna.bar`
  is activated, restored if activation fails, and removed with Lacuna-owned
  Hyprland overrides during core/full uninstall. It is deliberately separate
  from user dotfiles and theme files.
- Shared status followers such as Voxtype belong to one shell service, not to
  each monitor-local widget instance.

Raw layer count is therefore not a proxy for active decoder/effect/process
cost. Validate both namespace order and loaded-content/process counts.
