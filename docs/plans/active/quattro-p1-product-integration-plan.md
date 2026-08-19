# Quattro P1 — Product Integration Plan

Status: in progress; beta product-readiness track (reviewed 2026-07-16)

P1 builds on the P0 core foundation and makes Lacuna feel like a complete,
native Quattro desktop layer while preserving its custom bar and frame.

## Goal

Every core interaction should have a clear owner, a reliable setting path, a
native Omarchy integration boundary, and a predictable failure mode.

## Dependencies

- P0 state and layout schema
- P0 custom-bar compatibility record
- P0 geometry and monitor policy
- P0 installer/recovery workflow

## Closeout Execution

The ordered subagent implementation, review, deployment, and beta-evidence
workflow is defined in the
[Quattro P1 Closeout Execution Plan](quattro-p1-closeout-execution-plan.md).
This document remains the product and acceptance authority.

## Approved Phase 0 / Phase 6 Product Decisions

These decisions are frozen for the beta line and encoded machine-readably in
[`../../../config/omakase-profile.json`](../../../config/omakase-profile.json).
They record the checkpoint only; no P1 workstream is complete by this record.

1. **Omakase membership:** normal install uses the exact checked 46-root list:
   every supported manifest including experimental plugins, but excluding
   deprecated/migration-only `lacuna.compact-pill`. It activates `lacuna.bar`
   and all applicable menu, persistent/service, and overlay entries. Bar
   widgets are limited to the exact canonical 23-entry `LACUNA_BAR_LAYOUT`;
   empty script-pill and other optional widgets are not placed automatically.
2. **Media scope:** `lacuna.media-player` and
   `lacuna.media-player-video` are installed and enabled by default. Missing
   provider credentials degrade to disabled/unavailable providers without
   breaking the shell.
3. **Reset boundary:** `lacuna reset` is safe-only, has no purge mode, and owns
   only the canonical Lacuna activation, `bar.id`, `bar.layout`,
   `bar.centerAnchor`, `bar.transparent`, and the settings keys enumerated by
   the profile with defaults from `config/settings.example.json`. It preserves
   provider credentials/config, favorites, queue/history, auth/reminder files,
   preferred/custom apps, unrelated Omarchy state, other bar keys, and unknown
   JSON-safe fields.
4. **Stability vocabulary:** manifests use exactly `stable`, `beta`,
   `experimental`, or `deprecated`. Current supported manifests remain `beta`
   except `lacuna.script-pill=experimental` and
   `lacuna.compact-pill=deprecated`; maturity is independent of the suite
   channel and is never inferred.
5. **Release rehearsal:** destructive rehearsal is approved only for the
   current user and machine after automatic backups, verified restoration
   capability, and a fresh explicit confirmation immediately before destructive
   steps. This records authorization; no destructive rehearsal was run here.

## Progress Summary

| Workstream | Status | Current evidence | Remaining beta boundary |
| --- | --- | --- | --- |
| Native service integration | Mostly complete | Ownership policy, service implementations, and capability-aware Codex/Claude quota states exist. | Finish the complete owner/action/failure matrix and coexistence checks. |
| Settings and subsettings | In progress | Versioned state, migration, corrupt-state recovery, and nested helpers exist. | Inventory every control/key and close deterministic round-trip gaps. |
| Interaction and focus safety | In progress; general keyboard navigation removed from scope | Pointer interaction, semantic labels, scoped text entry, Escape dismissal, and click-away dismissal exist. | Keep the passive sidebar pointer-driven, allow bounded flyout focus for dismissal and intentional text entry, add Backspace dismissal outside text editing, and prove focus restoration without turning flyouts into keyboard-navigated surfaces. |
| Media reliability | In progress | Playback services, provider scripts, video transition behavior, and failure tests exist. | Document ownership; cover provider cancellation, redaction, restart, and fallback. |
| Omakase setup and customization | In progress | The installer already has a full default, manifest metadata, and catalog grouping. | Define one canonical designed setup and prove safe customization and reset behavior. |
| P1 validation | Pending | Repository and P0 checks pass. | Complete the beta product matrix and live smoke record. |

## Workstream 1 — Native service integration matrix

Tasks:

- Document the owner of state, commands, notifications, and presentation for
  battery, media, idle, audio, Bluetooth, network, temperature, tray,
  notifications, updates, and system statistics.
- Use Omarchy services where they already provide authoritative state.
- Keep Lacuna presentation where the custom layout or visual treatment is the
  product value.
- Prevent duplicate low-battery notifications, idle orchestration, media
  state, and other user-visible side effects.
- Verify simple bar widgets use the correct injected properties and direct
  Quickshell service access.
- Treat optional provider quota windows as capabilities: suppress absent windows
  in the bar, retain a clearly unavailable flyout row, and restore the window
  automatically if the provider reports it again.
- Distinguish an explicitly absent provider window from an unknown state caused
  by expired authentication, unavailable endpoints, or local probe failures.

Primary files:

- `docs/architecture/omarchy-integration.md`
- `lacuna.audio/`
- `lacuna.bluetooth/`
- `lacuna.network/`
- `lacuna.power/`
- `lacuna.mpris/`
- `lacuna.notifications/`
- `lacuna.tray/`
- `lacuna.system-stats/`

Acceptance:

- Every rich system surface has one documented state owner.
- Actions use the correct Omarchy command or service boundary.
- Native widgets can coexist with the Lacuna bar without duplicate output.
- Service failures degrade to a clear unavailable state rather than breaking
  the bar or menu.
- Provider-dependent usage widgets never present stale historical windows as
  current limits and never claim suppression when provider capability is merely
  unknown.

## Workstream 2 — Settings and subsetting UX

Tasks:

- Inventory every core and bundled setting exposed by manifests, menu controls,
  shell settings, and runtime state.
- Ensure every setting has a visible default, valid range, persistence path,
  reset behavior, and migration rule.
- Remove controls that write a different shape than the state service reads.
- Make settings changes transactional and report failed writes clearly.
- Preserve unknown JSON-safe fields during read-modify-write operations.
- Add round-trip tests for nested settings and provider-specific settings.

Primary files:

- `lacuna.menu/settings/SettingsWindow.qml`
- `lacuna.shell-settings/settings/`
- `lacuna.menu/services/LacunaSettings.qml`
- `lacuna.state/Service.qml`
- `docs/configuration.md`

Required artifact:

- A checked settings inventory in `docs/configuration.md` or a linked generated
  inventory. It must name the default, valid values, persistence owner, reset
  behavior, and migration behavior for every beta-supported setting.

Acceptance:

- A settings inventory has no orphaned controls or undocumented keys.
- Every control can be changed, restarted, reloaded, and restored.
- Invalid values are clamped or rejected consistently.
- Settings UI and state services agree on nested objects and defaults.

## Workstream 3 — Pointer interaction and focus safety

Product decision: the Lacuna sidebar is a semi-persistent desktop surface, not
a keyboard-navigated application window. General keyboard navigation, Tab
traversal, arrow-key traversal, and keyboard activation of ordinary flyout
controls are out of scope. A mapped sidebar without an interactive flyout must
remain pointer-driven and must not acquire keyboard focus. An open interactive
flyout may temporarily acquire bounded compositor focus only to support
click-away dismissal, `Escape` or `Backspace` dismissal, focus restoration, and
intentional text entry. Backspace edits text when consumed by an active text
field; otherwise it dismisses the flyout.

Tasks:

- Keep the mapped sidebar at `WlrKeyboardFocus.None` when no interactive flyout
  is open.
- Allow an interactive flyout to use bounded `WlrKeyboardFocus.OnDemand` and a
  focus grab for dismissal; end that lifecycle immediately when the flyout
  closes.
- Allow a scoped text-entry focus state for explicitly activated fields such as
  Media Search; do not turn that state into general control navigation.
- Support `Escape` dismissal for every interactive flyout and `Backspace`
  dismissal whenever an active text field does not consume the key.
- Preserve click-away dismissal for interactive flyouts, with the focus grab
  limited to the flyout lifecycle and never activated solely because the
  persistent sidebar is mapped.
- Restore focus to the previously active application after Escape, Backspace,
  click-away, or explicit close.
- Retain meaningful accessible names and roles without enabling Tab, arrow-key,
  or keyboard-activation paths for ordinary pointer controls.
- Keep tooltip targets and hover affordances understandable through visible
  labels or pointer-accessible controls.
- Move workflows requiring broader keyboard navigation than direct text entry
  into a separate transient/modal surface with an explicit focus lifecycle; do
  not turn the persistent sidebar host into a keyboard-navigated surface.
- Ensure click-through frame and overlay surfaces do not steal input.

Primary files:

- `lacuna.bar/`
- `lacuna.menu/menu/`
- `lacuna.menu/settings/`
- `lacuna.shell-settings/`
- `tests/test_qml_contracts.py`

Testing boundary:

- Extend focused runtime behavior tests under `tests/test_qml_behavior_*.py`;
  string-presence contracts alone do not satisfy this workstream.

Acceptance:

- Opening the sidebar without an interactive flyout does not steal keyboard
  focus from the active application.
- Interactive flyouts use focus only for their bounded dismissal lifecycle and
  intentional text entry, never for general keyboard navigation.
- Escape, unconsumed Backspace, click-away, and explicit close dismiss an
  interactive flyout and restore application focus.
- Active text fields consume Backspace normally instead of dismissing their
  flyout.
- Pointer-operated controls have meaningful labels and reliable hit regions
  without becoming generally keyboard-navigable.
- Input masks, outside-click behavior, dismissal keys, and layer-shell focus
  policy are covered by runtime smoke tests.

## Workstream 4 — Media lifecycle and provider reliability

Tasks:

- Validate inline, background, and automatic presentation handoffs.
- Keep one authoritative playback owner and make secondary surfaces recoverable.
- Test provider search cancellation, result merging, queue progression, and
  renderer failure fallback.
- Verify Jellyfin and YouTube settings migration and credential redaction.
- Ensure shell restart, plugin rescan, and provider failure do not leave stale
  UI state or broken controls.
- Keep the media feature separable from the core shell release.

Primary files:

- `lacuna.media-player/Service.qml`
- `lacuna.media-player/scripts/`
- `lacuna.media-player-video/Overlay.qml`
- `lacuna.menu/menu/MediaPlayerTile.qml`
- a new `docs/architecture/media-player.md`
- existing `tests/test_qml_behavior_video.py`
- existing media/provider coverage in `tests/test_status_scripts.py`
- new focused provider tests where the existing suites do not cover the
  acceptance cases below

Acceptance:

- Every handoff has success, timeout, cancellation, and failure behavior.
- Provider credentials never appear in command arguments or logs.
- Failed media surfaces fall back to an available presentation.
- Settings and queue state survive restart according to documented policy.

## Workstream 5 — Omakase setup and customization

Tasks:

- Define one canonical omakase installation: the designed Lacuna bar, sidebar,
  layout, settings baseline, and supported plugin collection.
- Make the normal install path activate that setup without asking the user to
  choose between architectural profiles.
- Keep the result customizable after installation without weakening the
  quality or coherence of the default experience.
- Provide a safe reset path back to the canonical layout and settings baseline.
- Mark optional, experimental, or provider-dependent plugins clearly without
  turning them into competing beta installation profiles.
- Keep lower-level selective installation available only where useful for
  development, recovery, or advanced manual customization.

Primary files:

- `scripts/lacuna`
- `docs/install.md`
- `docs/plugins/README.md`
- plugin `manifest.json` files

Acceptance:

- A clean normal install produces the complete designed Lacuna experience.
- The installer, README, catalog, default layout, and settings baseline agree
  on what the omakase setup contains.
- Users can customize the installed setup and safely reset it to the canonical
  default without deleting unrelated state.
- Selective installation mechanisms do not appear as required product choices
  in the beta onboarding path.

## Workstream 6 — P1 validation

Required checks:

```bash
./scripts/check.sh
python3 -m pytest tests/test_qml_contracts.py tests/test_qml_behavior_*.py
python3 -m pytest tests/test_status_scripts.py tests/test_qml_behavior_video.py
./scripts/dev deploy --all --only-changed --dry-run
omarchy-shell shell listShellConfig
omarchy-shell shell summon lacuna.menu "{}"
```

P1 is complete when core workflows, native services, settings, pointer/focus
safety, and media recovery behave as one coherent product.

## Delivered Checkpoint — 2026-07-16

- `lacuna.codex-usage` now rejects stale historical 5-hour windows, switches the
  bar to weekly-only when the current provider payload omits the session window,
  and dims the retained flyout row as suppressed.
- `lacuna.claude-usage` now reads the authenticated provider usage endpoint when
  available, distinguishes explicit window absence from probe uncertainty, and
  falls back to calibrated local estimates without making a false suppression
  claim.
- Both widgets automatically restore normal session/weekly rotation when the
  provider reports the session window again.
- Runtime behavior, QML contracts, script fixtures, live deployment, and
  installed-copy verification cover the transition in both directions.
- This closes the usage-widget capability-state slice of Workstream 1. It does
  not close the remaining native integration matrix or the P1 beta exit gate.

## Beta Exit Record

Do not mark P1 complete from repository tests alone. Record the supported
environment, packaged artifact, clean-install result, shell restart result,
settings round trip, sidebar focus-safety smoke, and media failure fallback in
this section when the beta gate is actually run.

### 2026-07-26 partial beta-gate evidence

- Environment: Omarchy `4.0.0.r1333.ga466dcc-1`, Quickshell
  `0.3.0.r18.g10b439f-3`, three active outputs.
- Repository validation: `368 passed, 5 skipped, 14 subtests passed`;
  Quattro compatibility and the three-monitor P0 smoke pass.
- Packaging: deterministic archive/AUR rehearsal passes with 47 plugins and a
  517-entry package payload. GitHub CI still requires a pushed rerun of the
  reviewed namcap host-runtime warning policy.
- Live install: all 47 plugin copies match the checkout. The new ambience host
  keeps Bottom and Overlay surfaces mapped on every output, suppresses legacy
  fallback windows only while healthy, and changes real pixel composition when
  `activeEffects` order reverses without changing the layer list.
- Visual parity: hosted-versus-legacy reduced-motion captures were exact for
  six effects, near-exact for tracking lines (normalized RMSE `0.00147`), and
  within expected animated variation for aurora drift (`0.0791`).
- State/failure evidence: bar-size mode round-trips without unrelated state
  loss; failed nightlight application remains failed in the runtime QML probe;
  media provider filtering activates only the visible result, and paste/focus
  dismissal behavior passes its component probe.

This is not the final Beta Exit Record. A packaged destructive clean install,
forced update failure and rollback, uninstall, stock-bar recovery, and a green
GitHub workflow for the candidate commit remain required before P1 is marked
complete.
