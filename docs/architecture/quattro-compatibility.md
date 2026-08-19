# Quattro Compatibility Ledger

Status: reference

This is the compatibility record for the Lacuna core bundle on Omarchy
Quattro. It is intentionally a ledger, not a promise that every future
Omarchy development build is supported.

## Current tested host

| Component | Observed value |
| --- | --- |
| Omarchy package | `omarchy-dev 4.0.0.r1438.g9b693cc-1` |
| Quickshell package | `quickshell-git 0.3.0.r18.g10b439f-3` |
| Omarchy path | `/usr/share/omarchy` |
| Upstream bar source | `/usr/share/omarchy/shell/plugins/bar/` |
| Bar source revision | package revision `9b693cc` (encoded in the Omarchy package version) |
| Reviewed commit | `9b693cca63d111fc3faba16aea149d226881b427` |
| Baseline review date | 2026-07-28 |

## Release-tested records

`config/quattro-compatibility.json` is the machine-readable authority. Each
published suite version records the exact Omarchy package and commit,
Quickshell package, test date, and gate result. The current record is:

| Suite | Omarchy | Quickshell | Tested | Result |
| --- | --- | --- | --- | --- |
| `0.1.0-beta.5` | `4.0.0.r1438.g9b693cc-1` / `9b693cc` | `0.3.0.r18.g10b439f-3` | 2026-08-11 | Compatibility baseline passed; destructive rehearsal remains a separate gate |

Repository-only checks report `declared`, not `compatible`, because they do not
inspect live packages, installed files, vendored parity, or plugin validation.
A release tag requires a matching release-tested record; only a live check can
claim compatibility.

The current upstream bar source is package-managed rather than a Git checkout,
so the package version and source hashes are the authoritative revision record
on this machine:

| File | SHA-256 |
| --- | --- |
| `shell/plugins/bar/Bar.qml` | `d516e6393c8946955d08d71cb310751c832389d3a2636b9b2d3aacccf819be55` |
| `shell/plugins/bar/BarModel.js` | `ee5ecdfa1883b0eda57f417050e139f6927b3332d032d03d7f1d7afbcb2bf292` |
| `shell/Ui/BarWidget.qml` | `8be00e2553a486b3dbfcb4f99de976035f323c4061b993dbc1842c75ff8b9022` |
| `shell/shell.qml` | `80bc9dd4ed7dfdc8290a93fa535471dd3a5ad510ce8317a6c05b502c3eb045ca` |

`lacuna.bar/BarModel.js` matches the upstream `BarModel.js`. The copied
`lacuna.bar/OmarchyBar.qml` is intentionally Lacuna-owned and diverges from
the upstream `Bar.qml`; that divergence is declared in
`lacuna.bar/manifest.json` and must not be silently synchronized.

### r1043 to r1054 review

The cached r1043 and r1054 packages differ in exactly one reviewed bar-host
line: upstream `Bar.qml` adds `surfaceFormat.opaque: false`. Upstream
`BarModel.js` and `shell.qml` are byte-identical across the two packages. The
new surface-format declaration supports the stock bar's transparent mode; it
does not change Lacuna's host, injection, layout, slot-measurement, registry,
geometry, or layer contracts. No source port is required because `lacuna.bar`
deliberately renders an opaque unified bar/frame/sidebar surface and activation
normalizes `bar.transparent` to `false`.

### r1054 to r1180 review

The r1180 update includes substantial stock bar and shell work. The reviewed
compatibility-sensitive changes are:

- Upstream commit `d4d1b518` removes `omarchy-hyprland-launch`, removes
  `Util.hyprExecCommand()`, and replaces the bar's detached `Process` launcher
  with `Util.execDetached()`. This was a breaking change for Lacuna: every
  action routed through `lacuna.bar`'s copied `run()` method failed at the
  removed API. Lacuna now uses `Util.execDetached()` too.
- Upstream commits `6e3b69b8` and `52ecb4ea` add `BarIconButton`, optical glyph
  alignment, and shared status-slot sizing. These are optional visual APIs;
  Lacuna's self-contained widget geometry does not depend on them.
- Upstream commits `18233046` and `9aa1dcd6` split bar CLI responsibilities,
  add whole-bar edge dragging, remove the stock `BarConfigPanel.qml`, and
  remove the shell `openBarConfig` IPC method. Lacuna retains its own config
  panel and does not invoke that removed IPC route or the removed CLI helpers.
- `BarModel.js` is byte-identical to the previous reviewed baseline. The
  shell entry-point delta is limited to removing `openBarConfig`; plugin
  discovery, custom bar selection, injection, and summon routing remain
  compatible.

The copied `OmarchyBar.qml` remains intentionally divergent, but its command
execution boundary is now synchronized with r1180 and later. Core plugin
validation, vendored parity, and the live P0 smoke all pass against this
baseline.

### r1180 to r1193 review

The three tracked compatibility files (`Bar.qml`, `BarModel.js`, and
`shell.qml`) are byte-identical across r1180 and r1193. The intervening shell
changes affect OSD feedback, service startup polling, display text sizing, and
theme layering; none changes Lacuna's bar host, plugin discovery, injection,
or summon contracts. The r1193 package is therefore accepted with the same
reviewed hashes.

### r1193 to r1333 review

`BarModel.js` remains byte-identical. Upstream `Bar.qml` adds
`moduleWidgets(pluginId)`, which returns every per-monitor instance of a bar
widget so `Ui/BarWidget.qml` can broadcast refresh operations across outputs.
Lacuna now exposes the equivalent lookup from its custom host and each
surface-local injected bar context. Existing injection, layout normalization,
slot measurement, dragging, geometry, and summon/hide/toggle contracts are
unchanged.

Upstream `shell.qml` adds the shared `AppLibrary` service used by the stock
menu's QML-native Apps provider; the remaining tracked delta is comment-only.
Lacuna keeps its own application catalog and does not consume this additive
service, so no menu port is required. Core plugin validation, vendored parity,
and the live P0 smoke pass on Omarchy r1333 with Quickshell git r18.

### r1333 to r1438 review

Upstream fixed duplicate center-widget instances and ambiguous panel routing.
`BarModel.js` adds `isDrawnSlot()` and `pickDrawnSlot()` so panel commands select
the visible, non-zero slot instead of an anchored placeholder. Lacuna vendors
the updated model and uses the same selection in its custom host.

Upstream `Bar.qml` also deactivates hidden module-list loaders, preventing the
anchored and unanchored center arrangements from running widgets, timers, and
IPC handlers simultaneously. Lacuna ports that lifecycle guard. The new
optional `openPanelIndicatorWidth` and `openPanelIndicatorHeight` widget hints
are also honored while retaining Lacuna's screen-local indicator offset.

The tracked `shell.qml` delta deduplicates asynchronous plugin-widget component
loads. That fix belongs to the Omarchy host and requires no Lacuna copy.
`Ui/BarWidget.qml` is unchanged. Core plugin validation, vendored parity, and
the live P0 smoke pass on Omarchy r1438 with Quickshell git r18.

## Compatibility check

Run the read-only checker from the repository root:

```bash
scripts/quattro-compatibility --check
```

It records the live Omarchy and Quickshell package versions, verifies the
upstream bar and shell files exist, checks the declared vendored pairs, and
validates the core plugin folders. It also compares the live files with the
reviewed hashes in `config/quattro-compatibility.json`; upstream drift returns
`review-required` until those contracts are inspected and the baseline is
updated. For CI or a machine without a live Omarchy installation, use the
repository-only mode:

```bash
scripts/quattro-compatibility --repo-only --check
```

When the Omarchy bar source changes, run the checker and then review the
following contract-sensitive areas before accepting the new revision:

1. `Bar.qml` injection properties, layout normalization, slot measurement,
   overflow, drag behavior, and per-screen variants.
2. `BarModel.js` entry shape, string-entry handling, tray pinning, and custom
   module paths.
3. `PluginRegistry` discovery, `shell.json` bar selection, plugin rescan, and
   shell restart behavior.
4. Bar position, size, orientation, transparency, theme/color access, and
   widget registry APIs.
5. `lacuna.bar` frame/sidebar ownership, `lacuna.menu` summon compatibility,
   and the layer/geometry contract.
6. Live bar-widget summon/hide/toggle routing through `open()`, `close()`, and
   `opened`, including behavior after the bar reloads widget instances.

Required source and runtime checks after an upgrade:

```bash
./scripts/check.sh
scripts/sync-vendored --check
scripts/quattro-p0-smoke
./scripts/dev deploy lacuna.bar lacuna.menu lacuna.state --dry-run
omarchy plugin list
omarchy-shell shell listPlugins
omarchy-shell shell debugBarGeometry
hyprctl layers
```

`quattro-p0-smoke` is read-only. It combines the compatibility report with
core plugin enablement, bar geometry registration, and per-output frame-layer
checks; it requires a live Wayland/Omarchy session.

The stock recovery path remains:

```bash
omarchy bar reset
```

This resets only the active bar choice while leaving the current layout and
Lacuna runtime state in `~/.config/omarchy/lacuna/settings.json`. The broader
`omarchy bar defaults` command also restores Omarchy's packaged default layout.

## Multi-monitor policy

`lacuna.bar` filters `Quickshell.screens` before creating per-output bar,
frame, border, reserve, tooltip, or drag surfaces. Nameless, zero-sized, and
duplicate-name screens are treated as transient QtWayland placeholders. If an
output owning a tooltip, popout, or drag disappears, the transient interaction
state is cleared and routing falls back to the first currently valid output.

Bar-originated menu calls carry a screen-local `popupContext`. In `auto` and
`all` modes the invoking bar output becomes the interactive sidebar/flyout
output; `pinned` mode still constrains routing to its configured output set.
The context also reports the invoking surface edge, so a bottom portrait
companion does not inherit the globally configured top edge (and vice versa).

When `barPresentation.portraitSplit` is enabled, each valid logical portrait
output with a horizontal bar derives primary and companion bands from the same
normalized `shell.json` layout. Landscape outputs remain unsplit. Companion
surfaces stay mapped on every valid output but are transparent, click-through,
and non-exclusive when inactive. The per-surface proxy preserves Omarchy's
widget injection, shared popout owner, registry and shell access, while
overriding edge-sensitive position/orientation. Primary dragging continues to
mutate the full canonical layout; companion dragging is disabled so filtered
entries cannot be lost.

`lacuna.menu` resolves the focused monitor name from the Omarchy shell-settings
state and selects the matching `Quickshell.screens` entry. The persisted
`sidebar.monitorPolicy` setting controls the target set:

- `auto` (default): the focused output, with the first live output as a
  deterministic fallback when focus data is unavailable or stale.
- `pinned`: the live outputs named by `sidebar.monitorNames`; selecting one or
  several outputs is supported. If no pinned name is currently present, the
  focused-output fallback is used until a valid output is selected.
- `all`: every live output.

Focus and monitor add/remove events recalculate the target set. The sidebar,
frame cutout, border attachment, and reserve surfaces are instantiated for
every selected output. The interactive flyout is different: it is rendered
only on the active/focused selected output, including when the sidebar policy
is `all`; its connector, input mask, and attached frame-border gap follow that
same output. In `pinned` mode, if the focused output is not pinned, the
flyout falls back to the first valid pinned output. Monitor names are output
names such as `DP-1`, not Hyprland workspace IDs; the policy therefore pins
the surface to a physical/logical output while that output's active workspace
can continue to change normally. The menu does not persist an open state, so a
restart cannot resurrect it on a stale output.

For the 2026-07-10 live smoke, the outputs were `DP-1`, `DP-2`, and `DP-3`,
with `DP-3` focused; `auto` therefore selected `DP-3` rather than the previous
`Quickshell.screens[0]` (`DP-1`).

## Layer-order reconciliation

The source declaration in `lacuna.bar/Bar.qml` keeps frame surfaces before the
bar adapter and the hosted menu. On the current Quattro build, `hyprctl layers`
reports the mapped top-layer order as `omarchy-bar`, `lacuna-bar-frame`, then
`lacuna-menu` on the sidebar output. The Omarchy bar maps on its own host
schedule, so its runtime map order is not controlled by the Lacuna declaration.

Correctness therefore comes from both constraints: the source declaration is
kept deterministic for Lacuna-owned surfaces, and `LacunaFrameWindow.qml`
excludes the bar strip from frame paint so the custom frame cannot cover the
bar even when Quattro maps `omarchy-bar` first. The frame, border, and reserve
surfaces remain pinned by `tests/test_qml_contracts.py` and the geometry tests.
