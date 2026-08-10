# Lacuna Reliability And Optimization Plan

Status: Phases 0–6 implemented and live-verified; Phase 7 is the next target

Date: 2026-07-26

## Goal

Make Lacuna dependable under real use before adding more surface area:

- Fix confirmed failures and inconsistent behavior.
- Preserve every working user workflow while repairs land.
- Make state, geometry, media, process, and layer lifecycles explicit.
- Optimize only measured costs; do not rewrite animation or architecture on intuition.
- Require runtime and live-shell evidence for visual or stateful fixes.

This plan complements the Quattro P1/P2 plans. It is the defect-remediation and performance execution track, not a replacement product roadmap.

## Investigation Baseline

The 2026-07-26 audit established this baseline:

- `./scripts/check.sh`: **380 passed, 5 skipped, 14 subtests passed**.
- All 47 live plugin copies match the checkout.
- The five skipped tests are opt-in live visual tests.
- The working tree already contains unrelated frame, ambience, test, release, and documentation edits. Each implementation wave must preserve them.
- The checked-in Graphify graph was queried first, then findings were verified against source, tests, runtime IPC, process state, and layer state.
- Live shell state exposed defects not caught by the green repository suite:
  - Media Player was stopped and inline, but retained `workerError: "Background video handoff timed out"`.
  - `playbackPosition` remained about 969 seconds while `playbackDuration` was zero.
  - The inline Qt multimedia renderer remained buffered and paused while stopped.
  - A defunct `mpv` child remained under the persistent media worker.
- The current corner setting was persisted as false. Its UI describes sidebar connector pieces, but it also globally squares frame and video clipping geometry.
- Layer state matched the new in-window frame-border design, while `scripts/quattro-p0-smoke` still expects the removed frame-border namespace and too many portrait companions.

A passing static suite is therefore a necessary baseline, not proof of correct live behavior.

## Non-Negotiable Invariants

### Compatibility and ownership

1. One Omarchy shell process; no plugin starts a second Quickshell process.
2. Existing plugin IDs, manifest contracts, settings paths, and IPC targets remain compatible unless a documented migration is included.
3. One writer owns each mutable subsystem during an implementation wave.
4. Unknown JSON-safe settings fields survive read-modify-write operations.
5. Existing user settings are snapshotted before live tests and restored in `finally`/cleanup paths.

### Media

1. Headless worker/mpv remains the only audio authority.
2. Inline and background QML players remain muted renderers.
3. Startup/source switch: cover reaches black before assigning the new source.
4. Exit: retain the old source until the cover is opaque, then clear it and reveal the frame.
5. Never stop a background player directly from `wallpaperDesired` changes.
6. Background `PanelWindow`s remain mapped; heavyweight loader/player content remains lazy.
7. Paused may retain a decoder for fast resume; stopped must not.

### Geometry and layers

1. `docs/lacuna-design-system/02-geometry.md` remains authoritative.
2. Attachment edges stay square; only exposed corners round.
3. Connector width and flyout offset use the same effective geometry snapshot.
4. Paint, shadow, border, and input mask consume identical effective bounds.
5. `curveKappa` has one canonical build-time source and verified runtime copies.
6. No layer change relies on same-level remapping order.
7. Every changed user-visible plugin is deployed and the running shell refreshed before a live issue is called fixed.

## System Interaction Map

### Settings path

`SettingsWindow.qml`
→ `MenuRegistry.qml`
→ `MenuWindow.handleSidebarAction()`
→ `SidebarState.qml`
→ `lacuna.state/Service.qml` / vendored `LacunaSettings.qml`
→ consumers in `lacuna.menu`, `lacuna.bar`, background/video overlays, and helper scripts.

Risk: immediate local state and asynchronously persisted shared state can reach separate windows on different frames.

### Attached surface path

`PanelController`
→ `MenuWindow`
→ `LacunaPanelHost` effective geometry
→ `MenuSurface`, `LacunaPanelConnector`, `LacunaAttachedFlyout`, `LacunaPanelBorder`, `LacunaFrameOverlay`
→ `LacunaPanelWindow` input mask.

Risk: raw booleans currently gate connector paint/masks while cached dimensions can still hold the previous connector width.

### Frame and video path

Lacuna settings
→ `lacuna.bar/Bar.qml`
→ per-screen `LacunaFrameWindow`
→ `lacunaFrameContentRect(screen)`
→ `lacuna.media-player-video/Overlay.qml` and background vignette.

Risk: the sidebar connector flag currently changes every screen's frame radius and every background-video clip radius, including screens without a sidebar.

### Media path

Media UI
→ `lacuna.media-player/Service.qml`
→ persistent JSONL worker
→ worker-owned mpv IPC/player and provider subprocesses
→ inline `MediaPlayerTile` and background `Overlay`
→ ready/failure callbacks
→ presentation state reconciliation.

Risk: provider resolution, renderer readiness, fallback, service timeout, overlay timeout, stop, and process teardown overlap without one generation token or one deadline owner.

## Prioritized Confirmed Defect Inventory

### P0 — Trustworthy validation

1. **Stale live smoke oracle** — `scripts/quattro-p0-smoke` expects a removed `lacuna-bar-frame-border` surface and portrait companions on outputs where policy says none should exist.
2. **Live behavior is under-gated** — the normal suite skips the visual tests that can expose frame, connector, stacking, and transition regressions.
3. **Source-contract tests overstate safety** — many media transition tests assert string presence rather than state-machine outcomes.

### P0 — Media lifecycle

1. **Zombie mpv children** — `media-player-worker` owns a `Popen` but never deterministically waits/reaps it after quit or worker shutdown.
2. **Wrong timeout phase** — the five-second presentation handoff timeout starts before video resolution, although resolution may legitimately run for 18–38 seconds.
3. **Contradictory stopped state** — stop clears duration but not position and leaves preview URLs/player source loaded.
4. **Error-domain conflation** — renderer/presentation failures are written into `workerErrorText` and survive ordinary stop/start.
5. **Stale callback risk** — callbacks are scoped to playback session, not presentation/source generation; `presentationRevision` is not used as a guard.
6. **Uncancelled work** — stop invalidates some results but can leave expensive video resolution or legacy preview work running.
7. **Two watchdog owners** — service and overlay timeouts can race and report different failures.

### P0 — Corner and geometry consistency

1. **One flag has incompatible meanings** — UI says sidebar connectors; bar/frame/video treat it as global rounded-content control; attached flyout exposed corners remain rounded.
2. **Connector radius is coupled to frame settings** — `MenuWindow` derives connector/flyout radius from `max(frameThickness, frameRadius)` instead of design tokens.
3. **Dynamic toggle can desynchronize geometry** — connector renderability switches immediately while cached connector width/flyout offset may use the previous state.
4. **Valid frame radius zero is lost** — normalization permits zero, but positive-only helpers replace it with the fallback radius.
5. **Global multi-monitor side effects** — a sidebar setting changes frame/video geometry on every output.
6. **Incomplete invalidation key** — frame geometry key does not encode the full selected sidebar-screen set.
7. **Third geometry family** — bar-widget flyouts hard-code a separate join radius and most copies are not in the vendored parity map.

### P1 — State and interaction correctness

1. Nested media-provider/player normalization drops unknown JSON-safe fields.
2. Main settings persistence reports completion without confirmed durable success/failure.
3. Settings-persistence writes need latest-write-wins queueing and destination-local atomic temporary files.
4. Current accessibility tests protect general keyboard navigation that the approved pointer-first focus contract excludes.
5. Escape dismissal exists, but unconsumed Backspace dismissal and complete focus restoration are not implemented/proven.
6. `SidebarState.save()` reconstructs the sidebar object and can discard future fields.

### P1 — Measured optimization targets

1. System statistics execute duplicate `df` work and approximately 48 child-process starts/minute per output-local widget at the default interval; the snapshot measured roughly 74 ms median.
2. Shell-settings full-state probing measured roughly 319 ms median and still serializes independent probes.
3. Settings persistence can launch two status processes every three seconds, about 40 launch opportunities/minute.
4. Screen recording is probed by service, widget, and grouped indicators.

Do not optimize CRT/VHS/ambience timers or split large QML files until profiling shows a cost or tests establish safe extraction boundaries.

## Execution Strategy

Work in small vertical slices. Every slice follows:

1. Capture the failing behavior in a deterministic test or bounded live probe.
2. Make one subsystem-level change.
3. Run focused tests, then `./scripts/check.sh`.
4. Deploy only affected plugins.
5. Run live IPC/process/layer/visual checks.
6. Record before/after evidence and restore mutated settings.
7. Stop if an unapproved product semantic or migration decision appears.

Do not combine media, corner schema, focus, polling, and structural cleanup in one patch.

## Phase 0 — Repair The Test Oracle And Capture Baselines

### Tasks

1. Update `scripts/quattro-p0-smoke` to current layer policy:
   - one `lacuna-bar-frame` per supported output;
   - no separate frame-border namespace;
   - portrait companion only on effective portrait-split outputs;
   - reserve windows based on bar orientation and selected sidebar outputs.
2. Add deterministic tests for smoke parsing/expectations so future layer refactors cannot silently stale the script.
3. Synchronize authoritative layer guidance in `AGENTS.md`, architecture docs, historical plans, and contracts without rewriting unrelated in-progress changes.
4. Add a reusable diagnostic capture command/script that records, with secrets redacted:
   - media service/video IPC state;
   - relevant process tree and zombie count;
   - layer namespaces per output;
   - selected settings subset;
   - shell/Omarchy/Quickshell versions.
5. Capture idle, menu-open, media-inline, media-background, corner-on, and corner-off baselines.
6. Run the opt-in live visual suite after snapshotting settings and prove restoration.

### Exit gate

- Corrected P0 smoke passes on the current three-output layout.
- Its policy is unit-tested.
- Full suite remains green.
- Baseline artifacts contain no credentials or provider tokens.

## Phase 1 — Media Process And Stop-State Hotfix

### Test first

Add tests that:

1. Start a fake/real controlled mpv through the worker, play, quit, and repeat; assert no child remains and no zombie accumulates.
2. Terminate worker during connected, disconnected, and startup-stalled mpv states; assert bounded teardown and reaping.
3. Seed service position, duration, preview candidates, errors, active resolution, and presentation state; call `stop()`; assert a coherent stopped state.
4. Verify pause retains source/buffer, while stop unloads inline source and reaches stopped/no-media state.
5. Verify late legacy and worker video-resolution results cannot repopulate stopped state.

### Implementation

1. Add one worker-owned mpv teardown routine:
   - request quit when connected;
   - bounded wait;
   - `SIGTERM`, then `SIGKILL` only if required;
   - always `wait()` the owned `Popen`;
   - clear handle/runtime files after termination.
2. Reap a completed child before replacing `self.mpv_process`.
3. Invoke teardown from quit, shutdown, close, failed connection, and failed launch paths.
4. Consolidate service stop resets into one session teardown helper.
5. Reset position, duration, sampled clock, handoff state, renderer state, and transient errors.
6. Cancel/invalidate worker and legacy video resolution on stop.
7. Clear inline player source only on stop; preserve pause behavior.
8. Separate worker/process, provider, playback, and presentation error fields in IPC/UI.

### Exit gate

- Repeated play/stop cycles leave zero mpv descendants and zero zombies.
- Stopped IPC reports position/duration zero, no active renderer, no stale transient error, and retained track metadata only where intentional.
- Pause/resume behavior remains unchanged.
- Media focused tests and full suite pass.
- `lacuna.media-player`, `lacuna.menu`, and `lacuna.media-player-video` are deployed and verified live.

## Phase 2 — Media Resolution And Presentation State Machine

### State model

Add these phases as an internal `handoffPhase`; do not replace the public
`presentationState` contract yet:

1. `idle`
2. `resolving`
3. `source-ready`
4. `covering`
5. `loading-renderer`
6. `converging-outputs`
7. `presented`
8. `recovering`
9. `exiting`

Keep `presentationState` as the compatibility projection
`inline/promoting/background/demoting/recovering` for QML consumers, IPC, and
existing tests. Removing or renaming those values requires a separate documented
compatibility migration.

Use a handoff token containing:

- playback session revision;
- presentation revision;
- background request/source revision;
- target surface.

### Tasks

1. Start provider-resolution deadlines when resolution begins.
2. Add tokenized `reportVideoLoading()` from the overlay immediately after it
   assigns `activeSource` behind the opaque cover.
3. Start the service-owned five-second generic renderer deadline only from that
   callback—not when resolution or promotion starts.
4. Keep overlay timers disjoint: adaptive-candidate readiness, drift validation,
   per-output convergence polling, and fade settlement only. They must not emit a
   competing generic handoff timeout.
5. Pass the handoff token through loading/ready/failure callbacks and reject stale callbacks.
6. Stop or generation-guard recovery timers whenever a new reconcile begins or a handoff succeeds.
7. Preserve the prior background source during re-resolution; swap only after the cover is opaque.
8. Expose per-output registration/readiness/status diagnostics.
9. Decide and document multi-output policy:
   - recommended beta policy: all matched outputs must register; one failed output falls back cleanly for the entire background presentation;
   - future option: degraded per-output presentation after separate product review.
10. Extend `tests/test_qml_behavior_media_service.py` and
    `tests/test_qml_behavior_media_overlay.py` with timed, tokenized state-machine
    cases for rapid toggles, same-source replays, slow resolution, expired URLs,
    adaptive failure, progressive fallback, output hotplug, pause, stop, and shell restart.
11. Add gated live probes to `tests/test_live_visual.py` for cold startup, source
    switch, failure exit, maximum black-cover duration, and multi-output convergence.

### Exit gate

- Slow healthy resolution never becomes a renderer handoff timeout.
- No indefinite black cover.
- Old callbacks/timers cannot override newer user intent.
- Source swaps and teardown still occur behind opaque black.
- Track switch target is visible within the documented budget on normal network conditions.

## Phase 3 — Split Corner Semantics And Make Geometry Transactional

### Required product decision

> Superseded by schema v3 universal shell corners: the persisted v2 booleans below remain only as rollback aliases. Runtime connector and frame molding visibility is now `resolvedCornerRadius > 0`, and the independent settings controls are removed.

The original schema-v2 split was:

```json
{
  "version": 2,
  "sidebar": {
    "connectorPieces": true
  },
  "frame": {
    "moldingPieces": true,
    "radius": 14
  }
}
```

Bar-widget flyout connectors and exposed corners consume the universal resolved Shell Corners radius through the injected bar context. Do not add a separate `barFlyouts.connectorPieces` setting.

### Derived geometry

First add `panelRadius` as an explicit `DesignTokens.qml` property and keep its
vendored consumers synchronized with the documented radius table.

- `trimEnabled = resolvedCornerRadius > 0`
- `sidebarConnectorWidth = trimEnabled ? resolvedCornerRadius : 0`
- `sidebarConnectorOverlap = trimEnabled ? designTokens.connectorOverlap : 0`
- `attachedFlyoutRadius = resolvedCornerRadius`
- `frameContentRadius = resolvedCornerRadius`
- Theme and Square resolving to `0` disable both molding families; positive Theme or Custom values enable both.

### Historical schema-v2 migration

The schema-v2 split and alias migration are complete and superseded by schema v3.
Normalization still preserves `sidebar.connectorPieces`, `sidebar.cornerPieces`,
`frame.moldingPieces`, and `frame.roundedContentCorners` for rollback only.
`SidebarState` does not expose actions for them, IPC does not advertise them,
and runtime geometry ignores their values. New work must use only
`geometry.cornerMode` and `geometry.cornerRadius`.

### Geometry transactions

Keep plugin ownership explicit with two transactions rather than one mutable
cross-plugin object.

`LacunaPanelHost` owns the panel transaction:

```text
requestedPanelGeometry
fromPanelGeometry
targetPanelGeometry
panelGeometryKey
effectivePanelGeometry = interpolate(from, target, progress)
```

On every target-key change—including a setting toggle during another
transition—capture the current effective geometry and restart a newest-wins
transition toward the new target. Reduced motion performs the same transaction
with progress 1.

`lacuna.bar` separately owns the frame-content transaction and returns an
immutable per-screen content rectangle plus geometry revision from
`lacunaFrameContentRect()`. Video and vignette consume that returned rectangle;
they do not mutate or share panel state.

Panel paint, shadow, border, attachment gap, flyout offset, and compositor input
masks consume `effectivePanelGeometry`. Frame paint, frame border, video clip,
and vignette clip consume the bar-owned effective frame rectangle. Connector
visibility is derived from `effectiveConnectorWidth > epsilon`, never directly
from the requested boolean.

### Tests

1. Settings migration matrix: missing, legacy true/false, new keys, mixed keys, precedence, unknown-field preservation, downgrade alias.
2. Geometry matrix at progress 0/0.5/1 for on→off and off→on.
3. Assert paint, shadow, border, and input masks use identical bounds.
4. Runtime toggles while flyout is closed, fully open, opening, closing, and switching kind; every interrupted transition must prove newest-wins behavior.
5. Reduced motion commits the same transaction atomically.
6. Rail/full, exclusive/overlay, frame off/on, border/shadow off/on, top/bottom/vertical bar, and Material/Omarchy/Lacuna style coverage.
7. Multi-monitor auto/pinned/all policies and monitor handoff.
8. Frame/video/vignette invalidation uses a geometry key containing the complete sorted selected-output set.
9. Keep all identical bar flyout surfaces generated from `lacuna.clock/BarFlyoutSurface.qml` through vendored parity.

### Exit gate

- UI labels describe exactly what each control changes.
- Toggling connectors never creates a detached gap, jump, stale border, or input hole.
- Sidebar connector changes no longer square every screen's frame/video.
- Valid radius zero works.
- Live visual captures pass with settings restored.

## Phase 4 — Settings Durability And Forward Compatibility

### Phase 4A — Canonical Lacuna settings

Owner: `lacuna.state/Service.qml`, its vendored menu fallback, and the Settings UI.

1. Complete the nested `preserveUnknownJson()` prerequisite started before the
   Phase 3 schema migration and extend future-field probes to every nested domain.
2. Implement a confirmed persistence state model:
   - `idle`, `saving`, `saved`, `failed`, `retrying`;
   - last confirmed revision;
   - latest-write-wins queued revision;
   - concise error plus Retry.
3. Inject FileView/write failures, concurrent writes, rapid toggles, shell
   restart, and stale completion ordering in tests.
4. Generate or mechanically validate the settings inventory: key, default,
   range, owner, UI, reset, migration, and restart requirement.

### Phase 4B — Managed idle/nightlight persistence

Owner: `lacuna.settings-persistence/Service.qml` and its IPC contract.

1. Add explicit in-flight/latest-write-wins queueing.
2. Use destination-directory atomic temporary files with restrictive permissions from creation.
3. Test injected save failure, rapid queued changes, process exit ordering, and
   successful self-healing after an external idle/nightlight change.

### Exit gate

- No supported or unknown JSON-safe field is lost.
- UI never reports success before confirmed persistence.
- Rapid writes converge to the latest requested state.
- Failed writes remain visible and retryable.

## Phase 5 — Focus, Input, And Interaction Contract

### Tasks

1. Remove tests that require prohibited general Tab/arrow/activation behavior for the passive sidebar.
2. Keep accessibility roles, names, states, and descriptions.
3. Implement unconsumed Backspace dismissal outside active text editing.
4. Bound focus grabs to interactive flyout lifetime.
5. Prove focus restoration after Escape, Backspace, click-away, explicit close, interrupted transition, and shell rescan.
6. Test empty and changing input masks during geometry transitions.

### Exit gate

- Passive sidebar never steals focus.
- Media search text editing works normally.
- Dismissal paths restore the previously focused application.
- Pointer hit regions remain aligned with painted geometry.

## Phase 6 — Measured Performance Work

### Before changing code

Measure only the target scenario plus stock Omarchy, Lacuna Core, menu
closed/open, and media inline/background. Ambience presets remain out of scope
unless profiler evidence implicates them.

For each target, use a checked benchmark script that records environment and
settings, runs a 60-second warmup plus five 120-second samples, and writes JSON
with raw samples, median, and p95 for:

- shell CPU and RSS;
- child-process launches/minute;
- wakeups;
- frame timing;
- startup time;
- 100 open/close cycles;
- per-output scaling.

### First optimization targets

1. **System stats** — remove duplicate `df`, share one snapshot across output-local consumers, and avoid spawning when hidden/unconsumed.
2. **Settings persistence** — replace three-second settled polling with watchers or a 30–60 second reconciliation interval.
3. **Shell settings** — parallelize independent probes or add domain-scoped refreshes.
4. **Screen recording** — make one service authoritative and have widgets/indicators consume it.
5. **Media stopped state** — enforce zero decoder/player children and zero Qt multimedia loaders while stopped.

### Guardrails

- Preserve self-healing after external state changes.
- Compare before/after measurements under the same monitor/layout conditions.
- Reject optimizations that increase race complexity without a material measured gain.
- Do not rewrite ambience timers without profiler evidence.

### Promotion budgets

Record exact thresholds in the baseline artifact before implementation. Initial
required gates are:

- no process-count growth after 100 interaction cycles;
- zero zombies or orphaned helpers;
- zero decoder/player process and zero Qt multimedia loader while media is stopped;
- system-stats recurring process launches reduced by at least 50%;
- settled settings-persistence launch opportunities reduced from about 40/minute to at most 4/minute, unless a watcher makes them zero;
- common shell-settings actions avoid a full 319 ms-class refresh or improve full-refresh median by at least 30%;
- screen-recording has one polling owner;
- shell CPU/RSS/startup/frame-time median and p95 regress by no more than 5% unless an approved accuracy/reliability tradeoff is recorded.

## Phase 7 — Bounded Structural Cleanup

Only after behavior is protected:

1. Extract media session/presentation/error helpers from `Service.qml` behind behavior tests.
2. Extract geometry transaction/state helpers from `MenuWindow.qml` behind deterministic geometry tests.
3. Keep runtime plugins self-contained; use build-time vendoring rather than cross-plugin imports.
4. Retain equality tests for all vendored copies.
5. Remove dead compatibility fields only after one release and migration telemetry/manual validation.
6. Reconcile issue tracker mirror and plan statuses with implemented reality.

Large-file size alone is not a reason to refactor.

## Per-Wave Validation Matrix

### Repository

```bash
./scripts/check.sh
python3 -m pytest tests/test_qml_contracts.py tests/test_qml_behavior_*.py
scripts/sync-vendored --check
scripts/quattro-compatibility --check
```

### Live install

```bash
./scripts/dev deploy <changed-plugin-id>
scripts/quattro-p0-smoke
omarchy-shell shell listShellConfig
omarchy-shell lacuna-media-player status
omarchy-shell lacuna-media-player-video status
hyprctl layers
ps -eo pid,ppid,state,etimes,comm,args
```

### Visual/stateful

```bash
LACUNA_LIVE_VISUAL=1 python3 -m pytest tests/test_live_visual.py
```

Every live test that changes settings must snapshot and restore them even when assertions fail.

### Final rollback and recovery rehearsal

Run this only on the packaged candidate, with backups and explicit confirmation:

1. Record shell/settings/plugin state and artifact hashes.
2. Install the packaged candidate and restart the shell.
3. Exercise settings round trip, media stop/start, corner migration, and live visual probes.
4. Force an update failure and verify transactional rollback.
5. Uninstall Lacuna and verify stock Omarchy bar/background recovery without deleting unrelated state.
6. Reinstall the candidate, restore the saved user state, and verify plugin-copy equality.
7. Record commands, exit codes, restored paths, residual state, and recovery time in the release evidence.

## Definition Of Done

This program is complete when:

1. All confirmed P0/P1 defects above have regression tests and verified fixes.
2. Media has deterministic process ownership, coherent stop/pause states, separate resolve/handoff deadlines, generation-guarded callbacks, and preserved cover transitions.
3. Corner settings have narrow semantics, transactional geometry, safe migration, and consistent multi-output behavior.
4. Persistence confirms writes and preserves unknown fields.
5. Focus/dismissal behavior matches the approved pointer-first contract.
6. Measured recurring process costs are reduced without regressions.
7. Corrected repository, compatibility, smoke, live visual, deployment, rollback, uninstall, and stock-bar recovery gates pass.
8. The final release record includes environment versions, commands, before/after metrics, known residual risks, and artifact hashes.

## Recommended Work Order

1. Phase 0 validation oracle.
2. Phase 1 media process/stop hotfix.
3. Phase 2 media presentation state machine.
4. Phase 3 prerequisite: nested unknown-field preservation, then corner schema and two geometry transactions.
5. Phase 4 canonical and managed-state persistence durability.
6. Phase 5 focus/input contract.
7. Phase 6 measured optimization.
8. Phase 7 structural cleanup and release closeout.

The first implementation patch should not begin with optimization. It should repair the smoke oracle and add failing media lifecycle tests, because current green tests do not detect the live zombie, stale stopped state, or premature handoff timeout.
