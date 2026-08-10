# Services And State

Status: reference

Lacuna keeps user-visible Omarchy plugin settings separate from Lacuna runtime
state.

## Omarchy Settings

Per-widget bar options belong in each plugin manifest's `barWidget.schema`.
Omarchy Settings writes those options into:

```text
~/.config/omarchy/shell.json
```

Bar layout placement also lives in `shell.json`.

## Lacuna Runtime Settings

Lacuna runtime/app state lives in:

```text
~/.config/omarchy/lacuna/settings.json
```

This includes shared Lacuna preferences such as:

- `colorProfile`
- `customQuickLaunchApps`
- `preferredApps`
- sidebar/frame settings

Sidebar monitor targeting is part of the canonical `sidebar` object:

```json
{
  "monitorPolicy": "auto",
  "monitorNames": []
}
```

`monitorPolicy` accepts `auto`, `pinned`, and `all`. `monitorNames` stores
unique output names for `pinned` mode and can contain one or several names.
The sidebar may be mirrored to every selected output, but an open flyout is
kept on the active/focused selected output only.

Scripts that rewrite this file must preserve existing keys. The bar-size
helper routes live mutations through `lacuna.state`'s `lacuna-settings-state`
IPC target so updates serialize with the QML owner. When the shell is not
running, it takes the shared `settings.lock`, re-reads at commit time, overlays
only bar-size-owned keys, and uses an operation-owned atomic temporary file.

### Canonical settings shape

`lacuna.state/Service.qml` is the canonical settings implementation. The
menu's `LacunaSettings.qml` copy is kept identical by `scripts/sync-vendored`.
Both services normalize the same runtime shape:

```json
{
  "version": 3,
  "designStyle": "lacuna",
  "designStyles": {
    "lacuna": {
      "bar": {
        "centerAnchor": "lacuna.clock",
        "layout": {
          "left": [],
          "center": [],
          "right": []
        }
      }
    },
    "omarchy": {},
    "material": {}
  },
  "geometry": {
    "cornerMode": "theme",
    "cornerRadius": 14
  }
}
```

The `designStyles.<style>.bar` object is optional and persists a style's bar
layout independently of the active `designStyle`. Layout entries may be
objects or strings; strings normalize to `{ "id": "..." }`. Object entries
require a non-empty `id` and preserve recursively JSON-safe metadata (strings,
booleans, finite numbers, nulls, arrays, and objects). Unsupported values are
discarded. `migrateSettings()` owns version handling and always emits the
current `settingsSchemaVersion`.

Settings schema v2 introduced separate `sidebar.connectorPieces` and
`frame.moldingPieces` switches. Schema v3 retains those keys and their interim
aliases only for settings-file rollback compatibility; runtime geometry no
longer treats them as independent user controls.

Settings schema v3 adds one exposed-corner policy. `geometry.cornerMode` is
`theme`, `square`, or `custom`; theme mode consumes Omarchy's live
`Style.cornerRadius`, square resolves to zero, and custom consumes the clamped
`geometry.cornerRadius` value. Migration maps legacy `frame.radius: 0` to
square, non-default legacy radii to custom, and the materialized v2 default 14
(or a missing radius) to theme inheritance. `frame.radius` remains a one-release
compatibility alias, but runtime frame and flyout geometry no longer reads it.
The resolved radius also owns trim visibility and Hyprland application-window
rounding: zero disables sidebar connector and frame molding pieces and writes a
zero window override; a positive Custom value writes that exact radius; Theme
removes the override and resumes theme inheritance. Independent trim and Window
Corners settings rows are therefore removed. Unknown JSON-safe fields nested
under `geometry` are preserved.

The unqualified term **corner pieces** is reserved for a future, separate
feature: black masks in the physical outer screen corners that make the outer
shell silhouette appear rounded, similar to Noctalia. Those masks are not part
of schema v2 and are not implemented by `frame.moldingPieces`.

### Persistence confirmation

Canonical settings writes are serialized by revision. `requestedSaveRevision`
advances for every normalized user intent, `confirmedSaveRevision` advances
only from `FileView.saved`, and a write in progress retains only the newest
queued payload. The public persistence states are `idle`, `saving`, `saved`,
`failed`, and `retrying`. A failed newest payload remains available through
`retryPersistence()` and the `lacuna-settings-state retry` IPC method; the
Settings UI exposes the same retry when needed. Optimistic in-memory state may
update controls immediately, but the UI does not call it durable until the
confirmed revision catches the requested revision.

Unknown recursively JSON-safe fields are preserved in every normalized domain.
The supported ownership inventory is:

| Domain | Owner | UI/reset | Migration | Restart |
| --- | --- | --- | --- | --- |
| top-level presentation and layouts | `lacuna.state` | Lacuna Settings; defaults from `defaultData()` | schema normalization | live |
| `designStyles.*.bar` | `lacuna.state` | style/bar controls | string entries become `{id}` | live |
| `preferredApps`, custom launch data | `lacuna.state` | Preferred Apps/launcher controls | invalid IDs fall back safely | live |
| `mediaProviders`, `mediaPlayer` | `lacuna.state` | Media Player | YouTube Music alias folds into YouTube | live |
| `sidebar` | `lacuna.state` + `SidebarState` | Layout | schema-v1 corner alias | live |
| `frame`, `barPresentation` | `lacuna.state` | Appearance/Layout | schema-v2 molding aliases | live |
| `backgroundEffects`, `backgroundVignette` | `lacuna.state` | Animations | legacy effect/vignette aliases normalize | live |
| managed idle/nightlight snapshot | `lacuna.settings-persistence` | persistence panel | v2 state payload | restored at service start |

Canonical and vendored normalizer parity plus the future-field behavior matrix
mechanically validate these owned domains, including bounded numeric settings
and migration aliases. Widget-local options remain in manifest schemas and are
not part of `settings.json`.

When adding a settings key, update the canonical service first, run
`scripts/sync-vendored`, and extend the normalization contract tests before
changing the UI.

## Managed idle/nightlight state

`lacuna.settings-persistence` writes
`$XDG_STATE_HOME/omarchy/lacuna/settings-persistence.json`. Saves are
latest-write-wins and use a restrictive `umask` plus a temporary file created
inside the destination directory before atomic rename. Its IPC status exposes
requested, queued, confirmed, failed, and retryable state. Apply failures and
persistence failures remain distinct; successful retry clears only the matching
persistence error.

## Persistent Services

`lacuna.state` is the persistent shared state service for the core bundle.
Menu/bar/panel plugins can also consume Omarchy services through the injected
`shell` reference. Simple bar widgets do not receive `shell`; they read
appropriate `Quickshell.Services.*` APIs directly.
