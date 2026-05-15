# Lacuna Sidebar UI Cleanup Plan

## Goal

Make the Lacuna sidebar easier to understand at a glance by separating navigation from commands, reducing competing visual emphasis, and making rail mode stable and predictable.

The current sidebar mixes destination rows, command rows, system controls, appearance tools, and shell maintenance in one surface. The cleanup should keep the Lacuna visual language, but make each row's purpose obvious.

## Current Problems

1. Navigation and actions look too similar.
   - `Apps` opens a view.
   - `Theme` opens a picker and applies a result.
   - `System` opens a view.
   - `Restart Lacuna` runs a command.
   These rows share similar visual weight, so the user has to remember behavior instead of reading it from the UI.

2. Rail mode changes meaning based on the current view.
   - The rail currently derives icons from the active view's items.
   - That makes the rail feel unstable because the same physical rail can represent different command sets.

3. Appearance controls are scattered.
   - `Wallpaper Catalog`, `Theme`, and `Background` sit beside launchers and system tools.
   - Sidebar layout controls live under preferences.
   - These should be grouped under a single customization path.

4. Too many rows look primary.
   - Accent rails, featured layouts, and high-emphasis rows compete with each other.
   - The main screen needs fewer high-priority targets.

5. Header text is noisy.
   - The title is useful.
   - The subtitle repeats implementation detail and does not help with navigation.

## Target Structure

### Main View

```text
Lacuna
  Apps
  Customize
  System

Launch
  Terminal
  Browser

Status Tools
  Wi-Fi
  Bluetooth
  Audio
  Record Screen
  Idle

Maintenance
  Update Lacuna
  Restart Lacuna
```

### Customize View

```text
Customize
  Wallpaper Catalog
  Theme
  Background

Layout
  Bar Density
  Icon Rail
  Sidebar Mode
```

### Lacuna Settings View

```text
Lacuna Settings
  Runtime
  Layout
  Open Source
  Open Log
```

### System View

```text
Session
  Screensaver
  Lock
  Logout

Power
  Restart
  Shutdown
```

## Navigation Model

### Destination Rows

Destination rows open another sidebar view and should show a clear trailing arrow.

Examples:
- `Apps`
- `Customize`
- `System`
- `Lacuna Settings`
- `Runtime`
- `Layout`

### Command Rows

Command rows run an immediate action and should not show the trailing arrow.

Examples:
- `Terminal`
- `Browser`
- `Wallpaper Catalog`
- `Theme`
- `Background`
- `Update Lacuna`
- `Restart Lacuna`

### Toggle Rows

Toggle rows should show state in the label and icon, but stay visually quieter than destination rows.

Examples:
- `Icon Rail`
- `Sidebar Mode`
- `Bar Density`
- `Idle`

## Rail Mode

Rail mode should become stable primary navigation, not a compressed version of the current view.

### Stable Rail Items

```text
Lacuna
Apps
Customize
System
Terminal
Browser
```

### Rail Behavior

1. Clicking a destination rail item should expand the sidebar if it is collapsed and navigate to that view.
2. Clicking a command rail item should run the command directly.
3. Rail contents should not change when the user navigates into nested views.
4. Rail tooltips should use the stable labels above.

## Visual Hierarchy

### Featured Rows

Use featured styling only for top-level destinations:
- `Apps`
- `Customize`
- `System`

### Primary Rows

Use primary styling for important but non-featured actions:
- `Terminal`
- `Browser`
- `Wallpaper Catalog`
- `Theme`
- `Background`

### Normal Rows

Use normal styling for lower-risk commands and toggles:
- `Wi-Fi`
- `Bluetooth`
- `Audio`
- `Record Screen`
- `Idle`
- `Bar Density`
- `Icon Rail`
- `Sidebar Mode`

### Danger Rows

Keep danger styling only for:
- `Restart`
- `Shutdown`

## Label Changes

Apply these renames for clarity:

| Current | Proposed |
| --- | --- |
| `Control surface` | `Lacuna Settings` |
| `Shell settings` | `Runtime` |
| `Preferences` | `Layout` |
| `Collapse to icon rail` | `Icon Rail` |
| `Expand sidebar` | `Full Sidebar` |
| `Use overlay mode` | `Sidebar Overlay` |
| `Reserve screen space` | `Sidebar Docked` |
| `Background` | `Theme Background` if confusion remains |

## Header Cleanup

1. Keep the current view title.
2. Remove or shorten the subtitle.
3. Use these titles:
   - `Lacuna`
   - `Apps`
   - `Customize`
   - `System`
   - `Runtime`
   - `Layout`
4. Keep back and close controls.
5. Keep the Lacuna glyph, but reduce competing text around it.

## Implementation Plan

## Implementation Status

- Phase 1: Completed. The registry now has a `Customize` view, appearance controls moved under it, and clearer `Runtime` / `Layout` labels.
- Phase 2: Completed. Rail mode now uses a stable top-level rail list instead of the active view's item list.
- Phase 3: Completed. Only `Apps`, `Customize`, and `System` use featured styling on the main view; secondary actions and toggles are quieter rows.
- Phase 4: Completed. The noisy subtitle was removed, and the header collapses unused subtitle space.
- Phase 5: Completed for automated/runtime checks. State persistence, command logging, command wrapper syntax, restart behavior, and selector cleanup were validated. Final manual smoke checks from the actual sidebar UI are still recommended.

### Phase 1: Registry Restructure

Files:
- `modules/menu/MenuRegistry.qml`

Tasks:
1. Add a `customize` view.
2. Move `Wallpaper Catalog`, `Theme`, and `Background` into `customize`.
3. Move `Toggle bar density`, `Icon Rail`, and `Sidebar Mode` into a `layout` or `lacuna-preferences` view.
4. Rename main `Control surface` to `Lacuna Settings`.
5. Keep command strings unchanged unless the row is moving.

Validation:
- Run `qmllint modules/menu/MenuRegistry.qml`.
- Restart Lacuna.
- Confirm all moved commands still execute.

### Phase 2: Stable Rail

Files:
- `modules/menu/MenuRail.qml`
- `modules/menu/MenuRegistry.qml`
- `modules/menu/MenuWindow.qml`

Tasks:
1. Add a `railItems()` function to `MenuRegistry.qml` that returns only stable top-level rail entries.
2. Update `MenuRail.qml` to use `registry.railItems()` instead of filtering `itemsFor(currentView)`.
3. Keep rail tooltips based on the stable rail item labels.
4. Ensure destination clicks expand from rail mode before navigation.

Validation:
- Run `qmllint modules/menu/MenuRail.qml modules/menu/MenuRegistry.qml modules/menu/MenuWindow.qml`.
- Toggle rail mode.
- Navigate into nested views.
- Confirm the rail contents stay unchanged.

### Phase 3: Visual Priority Pass

Files:
- `modules/menu/MenuRegistry.qml`
- `modules/LacunaMenuItem.qml`
- `modules/menu/MenuSection.qml`

Tasks:
1. Set only `Apps`, `Customize`, and `System` to `layout: "featured"` on the main view.
2. Reduce secondary command rows to `layout: "row"` and `priority: "normal"` where possible.
3. Keep danger treatment only in the system power section.
4. Review icon and accent choices so each section has one dominant signal.

Validation:
- Run `qmllint` on touched files.
- Restart Lacuna.
- Visually confirm the main view has three clear primary destinations and quieter secondary commands.

### Phase 4: Header Simplification

Files:
- `modules/menu/MenuHeader.qml`
- `modules/menu/MenuContent.qml`
- `modules/menu/MenuRegistry.qml`

Tasks:
1. Shorten the subtitle to either an empty string or a concise context label.
2. Add a conditional so empty subtitles do not reserve vertical space.
3. Keep the current title prominent.
4. Preserve back and close controls.

Validation:
- Run `qmllint modules/menu/MenuHeader.qml modules/menu/MenuContent.qml modules/menu/MenuRegistry.qml`.
- Restart Lacuna.
- Check compact and normal sidebar modes.

### Phase 5: Behavior Audit

Files:
- `services/LacunaMenuState.qml`
- `services/SidebarState.qml`
- `services/CommandRunner.qml`
- `modules/menu/MenuWindow.qml`

Tasks:
1. Confirm open/closed sidebar state still persists across restart.
2. Confirm rail/full state persists across restart.
3. Confirm command failures are logged with stderr.
4. Confirm moved commands still save menu state before running.

Validation:
- Open sidebar in full mode, restart Lacuna, confirm full mode restores.
- Open sidebar in rail mode, restart Lacuna, confirm rail mode restores.
- Run Theme and Background commands from the sidebar.
- Check `/tmp/lacuna-quickshell.log` for errors.

Automated/runtime validation completed:
- Confirmed `menu.state` persists as `open/main` across Lacuna restart.
- Confirmed `sidebar.state` persists as `exclusive/full` across Lacuna restart.
- Confirmed Theme and Background command wrappers parse with the prepended synchronous menu-state save.
- Confirmed Restart Lacuna command wrapper parses with the prepended synchronous menu-state save.
- Confirmed `/tmp/lacuna-quickshell.log` ends with `Configuration Loaded` after restart.
- Cleared a stale Omarchy image-selector instance and socket so Theme/Background opens from a clean selector state.

Manual smoke checks still recommended:
- Toggle rail/full from the sidebar and restart Lacuna to visually confirm restoration.
- Open `Customize` from the sidebar and select Theme / Background to confirm visible picker and applied result.
- Trigger one known-bad command during development to confirm stderr appears in the command failure log path.

## Success Criteria

1. The main view has no more than three visually dominant rows.
2. The user can tell whether a row navigates or runs a command without trial and error.
3. Rail mode is stable and does not change contents by nested view.
4. Appearance controls live under `Customize`.
5. Runtime and layout controls live under `Lacuna Settings`.
6. The sidebar restores open/closed and rail/full state after restart.
7. Existing commands continue to work:
   - Terminal
   - Browser
   - Wallpaper Catalog
   - Theme
   - Background
   - Wi-Fi
   - Bluetooth
   - Audio
   - Update Lacuna
   - Restart Lacuna

## Rollout Notes

Implement this in phases rather than one large rewrite. The registry restructure and stable rail can be reviewed independently. Avoid changing the visual component internals until the menu structure is clear.

After each QML phase:

```bash
qmllint <touched files>
bash -lc 'quickshell kill -p /home/oldjobobo/Projects/lacuna/shell.qml; setsid /home/oldjobobo/Projects/lacuna/run.sh >/tmp/lacuna-quickshell.log 2>&1 &'
tail -80 /tmp/lacuna-quickshell.log
```
