# Repository Guidelines

## Project Structure & Module Organization

Lacuna is a Quickshell/QML desktop shell. The root `shell.qml` wires together the top bar and menu state. `LacunaBar.qml` owns the main bar layout. Reusable UI primitives live in `components/`, service/state objects live in `services/`, and feature widgets live in `modules/`. The side menu is split under `modules/menu/` (`MenuWindow.qml`, `MenuRegistry.qml`, `MenuRail.qml`, etc.). Status command helpers are shell scripts in `scripts/`. Static visual assets and fonts are in `assets/`; design notes live in `docs/`.

## Build, Test, and Development Commands

- `./run.sh`: starts Lacuna with `quickshell -p shell.qml`.
- `quickshell kill -p /home/oldjobobo/Projects/lacuna/shell.qml`: stops the running Lacuna instance.
- `qmllint <files>`: validates QML syntax and common type issues.
- `bash -lc 'quickshell kill -p /home/oldjobobo/Projects/lacuna/shell.qml; setsid /home/oldjobobo/Projects/lacuna/run.sh >/tmp/lacuna-quickshell.log 2>&1 &'`: restart and capture runtime logs.
- `tail -80 /tmp/lacuna-quickshell.log`: inspect startup/runtime errors.

There is no compile step; runtime verification happens through Quickshell.

## Coding Style & Naming Conventions

Use two-space indentation in QML. Keep components focused and named in PascalCase, e.g. `LacunaButton.qml`, `MenuSurface.qml`. Prefer shared primitives from `components/` before adding new styling patterns. Keep stateful services in `services/` and avoid embedding process/state logic inside visual-only components. Use existing tone names (`lacuna`, `shell`, `session`, `danger`, `nav`) and registry item fields when adding menu entries.

## Testing Guidelines

No formal test framework is present. For QML changes, run `qmllint` on touched files and any direct dependents. For UI behavior changes, restart Lacuna and confirm `/tmp/lacuna-quickshell.log` ends with `Configuration Loaded`. For scripts in `scripts/`, run them directly and verify they emit valid JSON where expected.

## Commit & Pull Request Guidelines

Git history uses short imperative commit subjects, for example `Refine Lacuna menu sidebar` and `Restore sidebar mode toggle`. Keep commits focused around one UI or behavior change. Before opening a PR, include a short description, affected modules, validation commands, and screenshots or screen recordings for visible UI changes. Mention any state-file or user-config impact, especially changes involving sidebar mode, compact mode, or shell persistence.

## Agent-Specific Instructions

Do not revert unrelated user changes. Preserve the running desktop workflow: after meaningful QML edits, lint first, then restart Lacuna and check the log. Keep menu/sidebar changes scoped to `modules/menu/`, `services/SidebarState.qml`, and shared primitives unless the bar itself must change.
