# Changelog

All notable changes to the Lacuna Omarchy plugin suite are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the suite version lives in [`VERSION`](VERSION) and is mirrored into every
`manifest.json`.

## [Unreleased]

## [0.1.0-beta.5] - 2026-08-11

### Fixed
- Media playback now holds inline video on its thumbnail until mpv advances,
  preventing repeated zero-position startup samples from visibly restarting the
  renderer during provider buffering.
- Inline and background video now prefer stable progressive streams over
  unreliable HLS playback, while retaining adaptive video as a last resort.
- Background and inline presentation handoffs no longer restart an in-flight
  resolution or transition, and stopping playback reliably returns presentation
  mode to inline.

## [0.1.0-beta.4] - 2026-08-10

### Added
- The Lacuna workspace widget can optionally show only the active workspace
  from Settings → Bar; the existing multi-workspace display remains the default.
- GitHub prereleases now include a verified Arch package artifact for temporary
  direct installation when the AUR is unavailable.

### Changed
- Documentation now pairs its user-first content with a calm neutral shell,
  restrained navigation and accent states, readable proportional prose,
  asymmetric product layouts, authentic product crops, and hardened keyboard behavior.

### Fixed
- Attached flyouts and frame surfaces now share the universal theme-aware shell
  corner radius, preserving square attachment edges and consistent molding.
- Settings toggles now use a bright knob with the neutral track when enabled;
  disabled toggles retain the former accent track with its dark knob.
- Sidebar button opens now continue to obey the pointer envelope and hide delay
  while sidebar autohide is enabled instead of creating a held-open session.
- Full uninstall now removes Lacuna-owned Hyprland gap, corner-rounding, and
  single-window-aspect overrides, reloads Hyprland, and transactionally restores
  those overrides if the uninstall reload fails.

## [0.1.0-beta.3] - 2026-07-29

### Fixed
- Background-video renderer retries now force a fresh provider resolution
  instead of reusing the media worker's cached failed stream URL.
- Cancelled provider resolutions can no longer repopulate an invalidated media
  worker cache entry with a stale stream URL.

## [0.1.0-beta.2] - 2026-07-29

### Fixed
- YouTube playback and wallpaper video now resolve public streams before using
  stored login cookies. This avoids signed embedded-client URLs that resolve
  successfully but are rejected by `googlevideo` with HTTP 403.
- The persistent media worker, legacy mpv controller, inline preview resolver,
  and background-video resolver now share the same public-first policy, with
  configured authentication retained as a fallback when public extraction
  fails.

## [0.1.0-beta.1] - 2026-07-29

### Beta scope
- Candidate scope is the checked 46-root omakase setup, including both media
  plugins and the experimental script pill while excluding deprecated
  `lacuna.compact-pill` from normal activation.
- The reviewed development target is Omarchy
  `4.0.0.r1438.g9b693cc-1` with Quickshell
  `0.3.0.r18.g10b439f-3`; this is not a declaration of minimum supported
  versions.

### Migration
- Existing Lacuna settings, credentials, provider configuration, media state,
  reminders, and unrelated Omarchy configuration remain user-owned during
  normal install, update, and safe reset workflows.
- `lacuna.compact-pill` remains available only for migration and is deprecated
  for removal in `0.2.0`; normal installation does not activate it.

### Known limitations
- This is beta candidate content and may still contain product defects found by
  field testing; P1 completion and destructive lifecycle rehearsal are separate
  release gates.
- Reset uses atomic replacement per file. Abrupt process or power loss between
  the `shell.json` and `settings.json` replacements can leave a cross-file
  partial update, recoverable from the required external rehearsal backup.
- Compatibility is reviewed against the environment above; broader minimum
  supported Omarchy and Quickshell versions are not yet declared.

### Fixed
- Safe reset preserves mirrored Media Player preferences as well as
  `media-player.json`, preventing shell restart from overwriting user media
  state with reset defaults.
- Temporary YouTube or Jellyfin unavailability no longer rewrites the selected
  provider filter or its persisted media state.
- Installer reloads tolerate Omarchy's short restart-helper timeout only when a
  new shell process appears and subsequently answers its health ping.
- Safe reset restores direct external state files byte-for-byte when shell
  shutdown or startup rewrites them during the reset reload.
- Settings service no longer shadows its `loaded()` signal; the signal fires
  and the pending-save replay runs (`lacuna.state`, `lacuna.menu`).
- Corrupt `settings.json` is backed up to `settings.json.bak` and flagged via
  `recoveredFromCorruptSettings` instead of silently restoring defaults.
- Shell-settings state load gained a timeout watchdog so a hung helper process
  can no longer wedge the service; failures mark the data stale and retry.
- `BarSizeMode` debounces theme-name changes and verifies a patched
  `shell.toml` re-parses to the intended sizes before writing.
- `MenuWindow` flyout focus-clear debounce uses a `Timer` instead of
  `Date.now()` arithmetic.
- Theme parse fallbacks now emit diagnostics via the new `LacunaLog` helper
  instead of failing silently.
- Media-player worker shutdown now reaps provider subprocesses, preventing the
  process-group lifecycle check from failing under container PID 1.
- GitHub release jobs now run the complete project gate before publishing.
- Selective uninstall now refuses to break installed plugin dependencies unless
  `--cascade` explicitly includes their reverse dependency closure.
- Lacuna's bar host mirrors Omarchy r1438 drawn-slot routing, hidden-list
  lifecycle guards, and panel-indicator extent hints to prevent duplicate live
  widgets and ambiguous panel targets.

### Changed
- The Bézier corner constant `curveKappa` is defined once in a shared
  `LacunaGeometry` component and referenced everywhere (was duplicated across
  seven files in three plugins).
- `sync-vendored` derives its divergent-copy exclusions from each plugin's
  `manifest.lacuna.vendorExclude` and gained an explicit `--fix` alias.
- `SidebarState` names the persisted preference (`desiredDefaultMode`) and the
  session toggle (`runtimeCollapsed`) distinctly and persists the real collapse.
- Extracted pure value validators/converters out of `MenuWindow` into a
  stateless `MenuValueHelpers` component.
- Normal installation now uses the explicit omakase inventory instead of
  discovery-based membership, enables both media surfaces, and offers a
  preservation-first safe reset with no purge mode.

### Added
- `LacunaLog`: a level-gated, prefixed logging helper shared across plugins.
- A structural plugin load-smoke test (`tests/test_plugin_load_smoke.py`)
  enforcing entry-point integrity and self-contained relative imports.
- Plugin stability tiers via `manifest.lacuna.stability` (`beta`,
  `experimental`, `deprecated`); `stable` is reserved for the stable release
  line. `lacuna.compact-pill` is deprecated (removal targeted for `0.2.0`).
- Distribution scaffolding: `CHANGELOG.md`, `CONTRIBUTING.md`, GitHub
  PR/issue templates, lint config (`.shellcheckrc`, `ruff.toml`,
  `.pre-commit-config.yaml`), and a tag-triggered release workflow.
- Test coverage for the ambience overlays, desktop clock,
  settings-persistence, script pill, and `desktop-app-catalog.py`; CI now
  installs pytest and reports coverage.
- AUR packaging scaffold for `lacuna-shell`, including synchronized
  `.SRCINFO`, package validation, system payload layout, and maintainer docs.
- Prerelease-aware version tooling, a generated plugin inventory, deterministic
  single-root release archives, local `makepkg`/`namcap` rehearsal, strict AUR
  publication gates, and a clean-chroot submission runbook.

[Unreleased]: https://github.com/OldJobobo/lacuna-shell/compare/v0.1.0-beta.5...HEAD
[0.1.0-beta.5]: https://github.com/OldJobobo/lacuna-shell/releases/tag/v0.1.0-beta.5
[0.1.0-beta.4]: https://github.com/OldJobobo/lacuna-shell/releases/tag/v0.1.0-beta.4
[0.1.0-beta.3]: https://github.com/OldJobobo/lacuna-shell/releases/tag/v0.1.0-beta.3
[0.1.0-beta.2]: https://github.com/OldJobobo/lacuna-shell/releases/tag/v0.1.0-beta.2
[0.1.0-beta.1]: https://github.com/OldJobobo/lacuna-shell/releases/tag/v0.1.0-beta.1
