# Repository Guidelines

## Project Structure & Module Organization

This repository is the Omarchy plugin target for Lacuna, with the standalone Lacuna project treated as the source reference. The current structure is intentionally small:

- `docs/`: current project documentation, design-system specs, screenshots, and reference docs.
- `docs/plans/`: lifecycle-organized planning records. Put current work in `active/`, non-blocking ideas and drafts in `proposed/`, finished records in `completed/`, and reverted or superseded history in `archive/`; keep `docs/plans/README.md` synchronized.
- `lacuna.*/`: one top-level Omarchy plugin directory per Lacuna surface or widget. This flattened layout is required for `omarchy plugin source add` repo installs.
- `lacuna.menu/`: menu/sidebar plugin, with `menu/`, `components/`, `services/`, and `assets/`.
- `config/`: example configuration should live here, such as `settings.example.json`.

Keep plugin code self-contained under its plugin directory. Do not depend on the repository root as a runtime import path.

## Repository Exploration

This repo has a checked-in Graphify knowledge graph under `graphify-out/`. For architecture questions, file-relationship tracing, or "where does this behavior live?" investigations, query Graphify first before broad `rg`/grep-style exploration. Use `graphify query "<question>"` from the repository root, then follow up with targeted `rg`, `sed`, or file reads to verify exact implementation details before editing.

## Build, Test, and Development Commands

Use the repository check script for local validation:

- `./scripts/check.sh`: validate example JSON, manifests, vendored-file equality, optional `qmllint`/`shellcheck`, and the Python test suite.
- `python3 -m pytest`: run the test suite directly.
- `rg --files`: list tracked source-like files quickly.
- `find . -maxdepth 2 -path './lacuna.*' -print`: inspect plugin layout.
- `./scripts/dev deploy <plugin-id>`: developer-only live deploy from this checkout into `~/.config/omarchy/plugins/`, rescan, restart Omarchy shell, and verify the installed copy matches the repo.
- `omarchy shell shell rescanPlugins`: ask Omarchy shell to reload installed plugins.
- `OMARCHY_PATH="$HOME/.local/share/omarchy" omarchy-shell shell summon lacuna.menu "{}"`: smoke-test the menu plugin once implemented.

For local testing, copy or symlink a plugin directory into `~/.config/omarchy/plugins/<plugin-id>/`, then rescan or restart Omarchy shell. No plugin should start a second Quickshell process.

## Live Install Verification

When changing behavior that the running Omarchy shell should exhibit, repository edits and tests are not enough. Before saying a user-visible plugin issue is fixed:

- Run `./scripts/dev deploy <plugin-id>` for each changed installed plugin, or `./scripts/dev deploy --all --only-changed` to deploy every repo plugin whose live copy differs from this checkout or is missing.
- Use `./scripts/dev deploy <plugin-id> --dry-run` to preview the deploy/rescan/restart/verify steps.
- If bypassing the helper, deploy the changed plugin into the live install at `~/.config/omarchy/plugins/<plugin-id>/` or confirm that path is a symlink to the edited repo directory.
- If using `omarchy plugin update <plugin-id>`, remember it installs from the committed source state; it will not include uncommitted repo edits. Prefer `./scripts/dev deploy` for uncommitted fixes.
- The dev helper runs `omarchy shell shell rescanPlugins`, restarts Omarchy shell by default, and verifies the installed files match this checkout. Do not skip that verification.
- Only report a live shell issue as fixed after the installed copy and the running shell have been refreshed. If you only changed the repo, say it is implemented in the repo but not yet deployed live.

## Coding Style & Naming Conventions

Use QML for plugin entry points and keep roots compatible with Omarchy plugin contracts: bar widgets expose an `Item`; menu/panel surfaces implement `open(payloadJson)` and `close()`. Name plugin directories with full IDs, for example `lacuna.script-pill`. Prefer `Widget.qml` for bar-widget entry points and `Menu.qml` for the menu entry point.

Use 2-space indentation for JSON and QML unless a copied source file already has a consistent style. Store bar-widget user options in the plugin manifest schema so Omarchy Settings writes them inline to `~/.config/omarchy/shell.json`. Keep `~/.config/omarchy/lacuna/settings.json` for Lacuna runtime/app state only.

## Flyout Surface Geometry

The authoritative spec for Lacuna's seam/connector geometry is
[`docs/lacuna-design-system/02-geometry.md`](docs/lacuna-design-system/02-geometry.md).
Read it before touching any attached flyout. The load-bearing invariants:

- Keep the attachment edge **square** and bridge the gap with an Omarchy-style molding connector — a straight body between the panel's top and bottom plus two `ShapePath` cubic pieces outside the panel bounds — not rounded connector corners. The universal resolved shell-corner radius owns application-window rounding plus sidebar and bar-flyout connector width/visibility: when positive, reserve that `joinRadius` and draw the connector between host and flyout; when zero, disable connector and frame molding pieces and attach directly. Bar flyouts receive this radius only through the injected `bar.resolvedCornerRadius` context.
- Use the single `curveKappa` (`0.5522847498`) from `lacuna.menu/components/LacunaGeometry.qml` for every curve; never copy the constant.
- Round only **exposed** corners with a custom `Shape`; never use `Rectangle.radius` on an attached surface (it rounds all four corners and breaks the connector edge).
- Flyout shells are **fill-only** (`strokeWidth: 0`); reserve borders for internal controls, dividers, or explicit selected states.

## Background Video Transitions

`lacuna.media-player-video/Overlay.qml` owns the Media Player background video layer and its black fade cover. Keep startup and shutdown as two-phase transitions:

- When a new background video becomes available, raise the black cover first and delay assigning `activeSource` until the cover has finished fading to black. This prevents the video from appearing abruptly behind the sidebar.
- When background video is disabled or playback stops, keep the last `activeSource` alive while the black cover fades in, clear the source only after the cover is opaque, then fade the cover back out to reveal the sidebar/frame.
- Do not call `backgroundPlayer.stop()` directly from `wallpaperDesired` changes. Stop the player only after `activeSource` has been cleared so teardown is hidden behind the cover.
- Use `fadeCoverDuration`, `fadeInDuration`, `fadeOutDuration`, `exitFadeToBlackDuration`, and `exitFadeFromBlackDuration` for cover timing. Do not replace this flow with an immediate visibility or source toggle.
- Update `tests/test_qml_contracts.py` when changing this lifecycle; it intentionally asserts the transition primitives.

## Testing Guidelines

For any fix reported against live shell behavior, run `./scripts/dev deploy <plugin-id>` and include its verification result in the final status. Also validate the behavior inside Omarchy shell when the change is visual or stateful. Confirm that each widget appears in Omarchy Settings, can be placed in `bar.layout`, survives shell restart, and uses injected `bar`, `moduleName`, and `settings` properties. Test script paths through `manifest.__sourceDir` or another plugin-relative path.

Visual/UI behavior fixes are not protected by `tests/test_qml_contracts.py`
string pins alone. Add or extend a runtime behavior test in
`tests/test_qml_behavior_*.py`, a deterministic geometry test in
`tests/test_qml_geometry.py`, or an opt-in live probe in
`tests/test_live_visual.py` when changing QML state machines, layer ordering,
frame/sidebar geometry, video transitions, or shadow behavior. The live visual
suite must remain gated behind `LACUNA_LIVE_VISUAL=1` and must restore every
setting it toggles in `finally`/`tearDown` cleanup.

## Commit & Pull Request Guidelines

This checkout has no readable Git history. Use concise, imperative commits such as `Add script pill manifest` or `Port temperature widget shell contract`. Pull requests should describe the plugin affected, list manual Omarchy smoke tests, include screenshots for visible UI changes, and call out any remaining standalone Lacuna dependencies.

## Architecture Notes

Prefer Omarchy-native services and widgets for audio, media, network, Bluetooth, battery, tray, calendar, notifications, idle/update indicators, and other already-rich system surfaces. Keep `script-pill` as the experiment path; promote a script-backed widget only when it proves a durable non-native Lacuna workflow, visual treatment, or sidebar behavior.

## Layer Stacking

Within a wlr-layer-shell level, stacking is map order only and cannot be
restacked. Follow `docs/architecture/layer-stacking.md` before adding or
changing any `WlrLayershell.layer`, toggling a window's `visible`, or adding
a second surface where in-window composition would do. Every layer assignment
is pinned by `test_layer_stacking_policy` in `tests/test_qml_contracts.py`;
surfaces that must sit under later same-level UI (frame paint, frame border)
stay permanently mapped with content-gated paint.
