# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The Omarchy plugin integration path for Lacuna: a set of standalone plugin directories installed into `~/.config/omarchy/plugins/` and loaded by Omarchy shell (Quickshell). No plugin may start a second Quickshell process. The older standalone Lacuna shell is a source reference only; new work happens here.

Plugin directories live flat at the repo root as `lacuna.*` — this layout is required because Omarchy's repo-source installer scans only top-level folders containing a `manifest.json`. Also see `AGENTS.md` for detailed flyout-geometry and style rules.

## Repository exploration

This checkout includes a Graphify knowledge graph in `graphify-out/`. For architecture questions, file-relationship tracing, or locating where a behavior lives, query Graphify before broad grep/ripgrep exploration:

```bash
graphify query "<question>"
```

Use the graph answer to narrow the search, then verify exact code with targeted `rg`, `sed`, and file reads before making changes.

## Commands

```bash
./scripts/check.sh        # full check: manifest/config JSON validation, qmllint on all plugin QML, pytest
python3 -m pytest         # all tests (pytest.ini sets testpaths=tests, pythonpath=.)
python3 -m pytest tests/test_qml_contracts.py -k <name>   # single test
qmllint <file.qml>        # lint changed QML
python3 -m json.tool <plugin>/manifest.json   # validate a manifest
```

Installer (menu-driven without args; profiles: `full`, `core`, `theme`, `native`):

```bash
./scripts/lacuna
./scripts/lacuna install --profile full --dry-run
./scripts/lacuna uninstall --all --purge-state
```

Developer live deploy and smoke testing:

```bash
./scripts/dev deploy lacuna.menu --dry-run
./scripts/dev deploy lacuna.menu
omarchy shell shell rescanPlugins
omarchy plugin list
OMARCHY_PATH="$HOME/.local/share/omarchy" omarchy shell shell toggle lacuna.menu '{}'
hyprctl layers
```

Live-fix rule: do not call a user-visible Omarchy plugin issue fixed just because the repo changed or tests pass. First run the developer deploy helper:

```bash
./scripts/dev deploy <id>
```

The helper deploys the changed plugin from this checkout into `~/.config/omarchy/plugins/<id>/`, runs `omarchy shell shell rescanPlugins`, restarts Omarchy shell by default, and verifies the installed files match the repo. Use `--all --only-changed` to deploy every repo plugin whose live copy differs or is missing, or add `--dry-run` to preview the exact live steps.

`omarchy plugin update <id>` installs from committed source state and will not include uncommitted fixes. Prefer `./scripts/dev deploy` for active development fixes. If only the repo has been changed, say it is implemented in the repo but not deployed live.

## Architecture

### Plugin contracts (Omarchy)

Each plugin's `manifest.json` declares `kinds` and `entryPoints`:

- **bar-widget** → `Widget.qml`, root must be an `Item`; Omarchy injects `bar`, `moduleName`, and `settings` properties.
- **menu** → `Menu.qml`, must implement `open(payloadJson)` and `close()`.
- **service** → `Service.qml` with `activation: "persistent"` (e.g. `lacuna.state`).
- Desktop ambience plugins use `Overlay.qml` (e.g. `lacuna.crt-overlay`, `lacuna.aurora-drift`).

Plugins must be self-contained: never import across plugin directories or rely on the repo root as a runtime import path. Resolve script paths via `manifest.__sourceDir` or another plugin-relative path. Simple topbar widgets each carry vendored copies of `ColorProfile.qml` and `MotionTokens.qml`; the canonical templates live in `shared/qml/simple-bar/` — update those first, then re-vendor.

### Lacuna dependency metadata

Omarchy ignores the `lacuna` block in each manifest; Lacuna's installer, tests, and docs use it (see `docs/plugins/README.md`):

- `lacuna.standalone` / `lacuna.bundle` (`standalone` | `core` | `theme` | `legacy`), plus `requires` / `recommends`.
- Core menu bundle (never installed individually): `lacuna.state`, `lacuna.shell-settings`, `lacuna.menu`, `lacuna.menu-button`.
- Theme bundle: `lacuna.theme`, `lacuna.wallpaper`, `lacuna.theme-preloader`.
- `lacuna.compact-pill` is legacy; prefer `lacuna.bar-size-pill`.

### Settings split

- Per-widget bar options belong in the manifest's `barWidget.schema`; Omarchy Settings writes them inline into `~/.config/omarchy/shell.json` (`bar.layout` placement too).
- `~/.config/omarchy/lacuna/settings.json` is Lacuna runtime/app state only (global `colorProfile` of `semantic` or `colorful`, `customQuickLaunchApps`, `preferredApps`). Scripts that rewrite it must preserve existing keys — `tests/test_state_scripts.py` enforces this against `tests/fixtures/full-settings.json`.

### lacuna.menu

The largest plugin and the heart of the core bundle: `menu/` (surfaces, flyouts, panel windows), `services/` (`LacunaSettings.qml`, `Theme.qml`, `PanelController.qml`, `SidebarState.qml`, …), `components/` (Lacuna design primitives), `settings/` (settings panels). It owns Lacuna panel motion and sidebar choreography; specialized widgets own only their own interaction animation. The menu uses a unified color model: normal entries share the active theme accent, destructive actions use the danger color (`docs/lacuna-design-system/01-color.md`). The full Lacuna Design Language lives in `docs/lacuna-design-system/` (philosophy, color, geometry, motion, typography, components, roadmap).

Flyout panels attached to the sidebar follow strict geometry rules (square attachment edge, Omarchy-style molding connectors using the `curveKappa` constant from `lacuna.menu/menu/MenuSurface.qml`, fill-only background shapes, no `Rectangle.radius` on attached edges) — see "Flyout Surface Geometry" in `AGENTS.md` before touching them.

### lacuna.media-player-video

`lacuna.media-player-video/Overlay.qml` renders the Media Player background video and the black fade cover. Treat startup and shutdown as two-phase transitions:

- Startup: raise the black cover first, wait for the fade gate, then assign `activeSource` so the video appears behind black and fades in with the cover reveal.
- Shutdown: keep the last `activeSource` alive while the cover fades to black, clear the source only after the cover is opaque, then fade the cover out to reveal the sidebar/frame.
- Do not stop `backgroundPlayer` directly from `wallpaperDesired` changes; stop it when `activeSource` clears so video teardown stays hidden.
- Use the existing timing properties (`fadeCoverDuration`, `fadeInDuration`, `fadeOutDuration`, `exitFadeToBlackDuration`, `exitFadeFromBlackDuration`) rather than immediate source/visibility toggles.
- `tests/test_qml_contracts.py` intentionally asserts this lifecycle, including the startup fade gate and delayed exit clear.

### Tests

Tests are stdlib `unittest` run via pytest. `tests/test_qml_contracts.py` is source-contract style: it asserts specific strings/structures exist in QML files, so renaming functions or signals in covered files will break tests intentionally. `tests/test_state_scripts.py` executes plugin shell/Python scripts against a temp `XDG_CONFIG_HOME`. `tests/test_lacuna_installer.py` covers `scripts/lacuna`.

## Conventions

- 2-space indentation for QML and JSON.
- Plugin directories use full IDs (`lacuna.script-pill`).
- Runtime actions inside Lacuna go through Omarchy commands (e.g. `omarchy restart shell`); do not port standalone Lacuna process controls into plugins.
- Prefer Omarchy-native services/widgets for already-rich system surfaces (audio, network, battery, tray, …). `lacuna.script-pill` is the experiment path; promote a script-backed widget only when it proves a durable non-native workflow. See `docs/architecture/omarchy-integration.md` for the provider inventory (the `omarchy.battery`/`omarchy.media`/`omarchy.idle` services + `Color`/`Style` singletons), the `shell`-vs-`bar` injection rule, and the standing consumption policy.
- The desktop clock shells out to ImageMagick's `magick` for wallpaper contrast sampling but must degrade gracefully without it.
- Commits are concise and imperative (`Add script pill manifest`).
