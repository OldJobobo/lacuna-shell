# Theme-Aware Corner Geometry

Status: Complete; implemented, tested, deployed, and live-verified

Date: 2026-08-10

## Goal

Make application windows, every exposed Lacuna shell corner, frame molding piece, sidebar connector, and bar-owned flyout follow one universal resolved corner policy.

By default, Lacuna follows Omarchy's live `Style.cornerRadius`, which reflects the effective Hyprland `decoration:rounding` supplied by the active theme and any user-level Hyprland override. Lacuna settings retain live `square` and `custom` overrides, plus a reset path back to theme inheritance.

## Confirmed Problem

The existing geometry is split across unrelated values:

- frame fill and frame border consume `frame.radius`;
- frame molding and sidebar connector trim were independently controlled by legacy booleans;
- attached sidebar flyouts consume the fixed `DesignTokens.panelRadius`;
- Omarchy shell surfaces consume live `Style.cornerRadius`.

This permits a square frame fill with an apparently curved border and leaves attached flyouts rounded regardless of the active theme or Lacuna frame choice.

## Decisions

### One exposed-corner policy

Add schema-v3 settings:

```json
{
  "geometry": {
    "cornerMode": "theme",
    "cornerRadius": 14
  }
}
```

Valid modes:

- `theme`: use live `Style.cornerRadius`;
- `square`: use `0`;
- `custom`: use the clamped `geometry.cornerRadius` value.

`geometry.cornerRadius` remains stored while another mode is active so switching back to Custom restores the user's last value.

### Semantic derived values

- `resolvedCornerRadius`: result of the precedence above and the exact Hyprland window-rounding override for Square/Custom; Theme removes that override.
- `exposedSurfaceRadius`: the resolved radius used by sidebar-attached and bar-owned flyout fill, border, connector molding, and shadow source; input masks retain the same transactional surface bounds.
- `frameContentRadius`: `resolvedCornerRadius`.
- `trimEnabled`: `resolvedCornerRadius > 0`, shared by frame molding and sidebar connector pieces.
- interior and control radii remain design-style tokens.
- `joinRadius` equals `exposedSurfaceRadius`; `connectorOverlap` remains design-style-owned.

The universal corner control owns both trim radius and visibility. Legacy molding/connector keys remain normalized only for rollback compatibility and are ignored by runtime geometry.

### Geometry ownership

The bar-owned frame geometry record remains authoritative for frame fill, border, shadow, video clipping, and vignette clipping. The menu-owned panel geometry remains authoritative for attached flyout fill, border, shadow, and input-mask bounds. No border renderer may restore a nonzero corner radius after its authoritative geometry record resolves to zero.

For a zero-radius corner, use a square path branch rather than a tiny cubic or rounded path join.

## Migration

Bump settings schema from v2 to v3.

When `geometry.cornerMode` is absent:

1. legacy `frame.radius == 0` becomes `square`;
2. legacy `frame.radius` other than the old default `14` becomes `custom` with that radius;
3. missing radius or legacy default `14` becomes `theme`.

The old explicit value `14` cannot be distinguished from the materialized v2 default, so it migrates to theme inheritance. Preserve `frame.radius` and `frame.roundedContentCorners` as compatibility aliases for one release, but runtime geometry must use the new resolved policy.

Unknown JSON-safe fields under `geometry` must survive normalization and persistence.

## Implementation Slices

1. Add schema-v3 defaults, normalization, compatibility migration, IPC status, and example configuration in canonical `lacuna.state`, then synchronize the vendored menu service.
2. Extend shared design tokens with an injected exposed-corner radius and synchronize the vendored copy.
3. Resolve the live theme/custom/square radius in both `lacuna.bar` and `lacuna.menu` from `Style.cornerRadius` plus normalized Lacuna state.
4. Feed the resolved value through the existing frame and panel geometry records.
5. Make frame-border and attached-panel-border zero-radius paths explicitly square.
6. Add Appearance controls for Theme, Square, and Custom plus a live custom-radius slider.
7. Trigger `Style.scheduleRefresh()` after Lacuna changes the Hyprland window-rounding override.
8. Update geometry documentation, migration tests, runtime geometry tests, and static contracts.
9. Run focused tests, `./scripts/check.sh`, deploy `lacuna.state`, `lacuna.menu`, `lacuna.bar`, and `lacuna.shell-settings`, then verify the installed copies and running shell.

## Acceptance Matrix

- Theme radius `0`: frame, frame border, attached flyout fill, and attached flyout border are square.
- Positive theme radius: those surfaces use the same exposed radius.
- Square override: all exposed corners resolve to zero without changing the active theme.
- Custom override: values `0..32` apply live and persist.
- Reset to Theme: subsequent theme and Hyprland rounding changes propagate live.
- Resolved radius `0`: frame molding and sidebar connector pieces both disable automatically.
- Positive resolved radius: frame molding, sidebar connectors, and bar-flyout connectors all enable automatically and share that radius.
- Bar-owned flyout attachment gaps align standalone, Full-Frame, hosted-overlay, and foreground-ambience border owners on all four bar edges.
- Border/shadow geometry and mask bounds consume the same resolved records at transition progress `0`, `0.5`, and `1`.
- Existing schema-v1/v2 settings and unknown future fields normalize without loss.

## Validation

```bash
python3 -m pytest tests/test_qml_behavior_lacuna_settings.py
python3 -m pytest tests/test_qml_behavior_frame_border.py tests/test_qml_geometry.py
python3 -m pytest tests/test_qml_contracts.py tests/test_docs_contracts.py
./scripts/sync-vendored --check
./scripts/check.sh
./scripts/dev deploy lacuna.state
./scripts/dev deploy lacuna.menu
./scripts/dev deploy lacuna.bar
./scripts/dev deploy lacuna.shell-settings
scripts/quattro-p0-smoke
```

Visual validation must snapshot and restore the live corner mode, custom radius, and frame-border settings; deprecated trim booleans are not test controls.

## Completion Evidence

Completed 2026-08-10.

- Schema v3, reset ownership, settings UI, live Style inheritance, exact application-window synchronization, universal trim ownership, exact square paths, and authoritative frame/panel geometry are implemented.
- Focused QML behavior, geometry, settings, installer, contract, and documentation suites pass.
- The complete suite passes with only three pre-existing Omarchy compatibility/vendored checks deselected; the ordinary full run fails only those same checks because the installed Omarchy 4.0.0.r1512 source differs from the checkout's reviewed `BarModel.js`/compatibility hashes.
- `LACUNA_LIVE_VISUAL=1` corner matrix passed for theme, square, custom zero, custom positive, Omarchy, and Material cases; it verifies exact Hyprland rounding for Square/Custom, override removal for Theme, and restores settings afterward.
- `lacuna.state`, `lacuna.menu`, `lacuna.bar`, and `lacuna.shell-settings` were copied into the live plugin directory, Omarchy shell was restarted, and each installed directory was verified byte-for-byte against this checkout.
- Live IPC reported schema 3 and `cornerMode: theme`; effective Hyprland rounding was 0, so the current theme correctly resolved Lacuna's exposed corners to square.
- `scripts/quattro-p0-smoke` passed all four core plugin checks, bar geometry, and three-monitor layer checks; its overall result remains blocked only by the pre-existing Quattro compatibility drift.
- The repository deploy helper attempted its normal transaction but the installed Omarchy release no longer provides `omarchy plugin rescan`; it restored safely. Deployment was then completed manually with equivalent copy, shell restart, and equality verification.
