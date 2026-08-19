# Lacuna Quattro Roadmap

Status: active project control (updated 2026-08-04)

This is the canonical roadmap for turning Lacuna into a first-class desktop
enhancement for Omarchy Quattro. It is intentionally narrower than the full
plugin inventory: the priority is a dependable custom shell layer with a
coherent frame, bar, sidebar, state model, and upgrade path.

## Product Position

Lacuna is a custom Omarchy/Quickshell desktop layer. It is not a skin that
must fit inside the stock Omarchy bar.

The defining product decisions are:

- `lacuna.bar` is the intentional custom bar host because Lacuna's full-screen
  frame and sidebar choreography require control the stock bar does not expose.
- Lacuna runs inside Omarchy's single Quickshell process and follows Omarchy's
  plugin, service, IPC, and shell configuration contracts.
- Lacuna owns the frame, sidebar, geometry, visual language, and distinctive
  interaction surfaces.
- Omarchy services remain the preferred source of mature system state and
  orchestration.
- Settings and subsettings are durable product behavior: they must survive
  reloads, restarts, updates, and migrations without changing meaning.

The goal is not to reduce Lacuna to stock Omarchy. The goal is to make the
custom shell boundary deliberate, testable, and safe to evolve.

## Scope

### Core Quattro surface

- `lacuna.bar` and its full-screen frame host
- `lacuna.menu`, `lacuna.state`, and `lacuna.shell-settings`
- sidebar, flyout, seam, connector, and frame geometry
- bar layout persistence and settings normalization
- theme integration and design-system contracts
- native Omarchy service interoperability
- installation, update, recovery, and release compatibility

### Product integration surface

- audio, network, Bluetooth, power, tray, notifications, media, and system
  status widgets
- pointer interaction, tooltip behavior, semantic labeling, and compositor
  focus safety
- multi-monitor sidebar and frame policy
- media-player lifecycle, provider settings, and failure recovery
- one canonical omakase installation with post-install customization

### Deferred feature work

Optional visual-surface changes are tracked separately and do not block this
roadmap. Existing surfaces remain protected by their current contracts while
the core shell is stabilized.

- The completed [Clock And Calendar Flyout](plans/completed/lacuna-clock-calendar-flyout-plan.md)
  upgrades `lacuna.clock` with an adaptive time/date face and a read-only visual
  month calendar. It is not a beta or RC gate and does not include events or an
  external calendar backend.

## Operating Rules

1. Preserve the custom bar and full-screen frame architecture. Improve the
   compatibility boundary instead of replacing the product decision.
2. Preserve the geometry language: square attachment edges, molding
   connectors, one shared curve constant, exposed-corner rounding, and
   fill-only attached shells.
3. Keep `shell.json` as the Omarchy composition interface and Lacuna settings
   as the runtime state interface. Do not create a second competing registry.
4. Prefer Omarchy services for state and commands while allowing Lacuna to
   provide the presentation and interaction model.
5. Any implementation change that affects visible or stateful behavior needs
   a runtime, geometry, or integration test in addition to source contracts.
6. Every release must be recoverable to a known-good shell configuration.

## Release Sequence

The repository established the `0.1.0` line before its public beta. Prereleases
therefore use SemVer prerelease identifiers instead of moving backward to
`0.0.1`:

1. `0.1.0-beta.1` established the supported public-beta baseline.
2. `0.1.0-beta.2` through `0.1.0-beta.4` shipped field fixes and product
   refinements; additional `0.1.0-beta.N` builds may close further defects.
3. `0.1.0-rc.1` freezes product scope and proves the release artifact.
4. `0.1.0` promotes the verified RC lineage without feature additions.

P1 product-readiness work and P2 release-readiness work may proceed in
parallel. Beta requires the beta gates from both plans. RC begins only after
all beta blockers are closed or explicitly removed from the supported scope.

## Delivery Phases

### P0 — Core foundation

Status: complete (validated 2026-07-10)

Make the custom bar/frame shell dependable before adding more surface area.

Deliverables:

- canonical settings and layout-entry schema
- reliable state persistence and migrations
- custom bar compatibility ledger and upgrade checks
- geometry and layer-order acceptance coverage
- explicit multi-monitor policy
- installer preflight, staging, rollback, and stock-bar recovery
- core shell smoke matrix on current Quattro

Plan: [P0 Core Foundation](plans/completed/quattro-p0-core-foundation-plan.md)

### P1 — Product integration

Status: in progress; beta product-readiness track

Make the core shell feel complete and native to Omarchy without surrendering
Lacuna's identity.

Deliverables:

- native-service integration matrix
- provider-capability-aware usage widgets that distinguish unavailable,
  suppressed, and temporarily unknown quota windows
- pointer-first interaction that preserves focus for the active application
- settings UI completeness and subsetting round trips
- media lifecycle and provider failure recovery
- one designed omakase default with safe customization and reset behavior
- menu and settings maintenance boundaries

Plan: [P1 Product Integration](plans/active/quattro-p1-product-integration-plan.md)

The Phase 0/Phase 6 decision checkpoint is frozen without closing P1: the
checked 46-root omakase profile includes media and experimental plugins,
excludes deprecated compact-pill, uses safe-only preservation-first reset, and
requires explicit beta-line stability metadata. Destructive rehearsal is
approved only on the current user/machine after backups, restoration proof, and
a fresh immediate confirmation; it has not been run for this checkpoint.

### P2 — Release and evolution

Status: in progress; beta/RC release-readiness track

Make the suite easy to maintain, diagnose, upgrade, and extend.

Deliverables:

- Quattro compatibility matrix and release workflow
- diagnostics and plugin health reporting
- generated or checked documentation inventory
- stable version/migration procedures
- optional bundle curation and upgrade notes
- carefully bounded structural cleanup after behavior is covered

Plan: [P2 Release And Evolution](plans/active/quattro-p2-release-and-evolution-plan.md)

## Historical `0.1.0-beta.1` Acceptance Baseline

The first public beta used these gates as its acceptance baseline:

- P0 remains green on the declared Omarchy/Quickshell pair.
- Core settings have an inventory and deterministic persistence coverage.
- The semi-persistent sidebar remains pointer-driven and does not acquire
  keyboard focus merely because it is visible. Interactive flyouts may take
  bounded focus for click-away, Escape, unconsumed Backspace, and explicit-close
  dismissal plus intentional text entry, but must not expose general keyboard
  navigation; dismissal restores the prior application focus.
- Media is either covered by its documented failure/recovery contract or
  explicitly kept outside the core release profile.
- A clean install activates the canonical omakase setup without asking the user
  to choose an architectural profile; supported customization and reset paths
  preserve a known-good Lacuna default.
- A packaged clean install, restart, update failure, rollback, uninstall, and
  stock-bar recovery rehearsal has been recorded.
- Known limitations and supported versions are included in beta release notes.

Optional visual-surface work is not a beta gate.

## `0.1.0-rc.1` Acceptance Gates

RC is ready when:

- No open shell-breaking, state-loss, credential-exposure, installer,
  rollback, or input/focus-safety defects remain.
- Beta feedback has been resolved or explicitly documented as out of scope.
- Diagnostics distinguish missing, disabled, failed, and stale-installed core
  plugins and provide recovery actions.
- The release archive passes clean install, update, rollback, restart, and
  uninstall validation on the supported environment.
- Version, manifests, changelog, documentation, inventory, tag, and archive
  contents agree.
- RC contains blocker fixes only; feature development moves to the next
  release.

## Stable Release Acceptance Gates

The suite is ready for a first-class Quattro release when all of these are
true:

- `./scripts/check.sh` passes with current documentation and manifest state.
- A clean install can activate `lacuna.bar`, the core bundle, and the intended
  layout without manual repair.
- A failed update can restore the previous plugin copies and shell settings.
- The frame, bar, sidebar, and flyouts preserve geometry across bar sizes,
  themes, restarts, and supported monitor layouts.
- Settings and subsettings round-trip through reload, restart, and migration
  tests.
- Native services and Lacuna widgets do not issue competing orchestration or
  duplicate user-visible state.
- Media failures fall back without trapping the shell in a broken state.
- Pointer dismissal, tooltip, semantic-label, input-mask, and layer-shell
  focus-safety checks cover the core shell.
- The support matrix records the tested Omarchy/Quickshell revisions.
- The documentation index, version, manifests, and release notes agree.

## Source Of Truth Map

| Decision | Canonical document |
| --- | --- |
| Product priorities | This roadmap |
| Core execution | [P0 plan](plans/completed/quattro-p0-core-foundation-plan.md) |
| Product integration | [P1 plan](plans/active/quattro-p1-product-integration-plan.md) |
| Release and maintenance | [P2 plan](plans/active/quattro-p2-release-and-evolution-plan.md) |
| Runtime boundaries | [Architecture overview](architecture/overview.md) |
| Plugin contracts | [Plugin contracts](architecture/plugin-contracts.md) |
| Omarchy services | [Omarchy integration](architecture/omarchy-integration.md) |
| Geometry | [Lacuna geometry specification](lacuna-design-system/02-geometry.md) |
| Layer order | [Layer stacking policy](architecture/layer-stacking.md) |
| Install/update behavior | [Install and update](install.md) |
| Validation | [Testing](development/testing.md) |
| Historical work | [Plans index](plans/README.md) |

## Current Baseline

- Target environment: Omarchy 4.0.0 alpha/Quattro development builds.
- Runtime model: one long-running Quickshell process with top-level Lacuna
  plugin directories.
- Validation on 2026-07-16 reports 305 passing tests and 3 environment skips.
  Treat this as a dated observation, not a pinned expected count.
- `scripts/quattro-compatibility --check` reports compatibility with Omarchy
  `4.0.0.r1438.g9b693cc-1` and Quickshell `0.3.0.r18.g10b439f-3` on the current machine.
- The r1438 review is accepted. Earlier reviews ported `Util.execDetached()` and
  multi-monitor widget broadcast lookup. The r1438 delta adds drawn-slot panel
  routing, hidden center-list lifecycle guards, and optional panel-indicator
  extent hints, now mirrored by Lacuna; host-owned asynchronous component-load
  deduplication requires no Lacuna copy.
- Codex currently reports a weekly-only quota window, so its 5-hour readout is
  suppressed in the bar and dimmed in the flyout. Claude currently reports both
  session and weekly windows through its authenticated usage endpoint. Both
  widgets restore a provider window automatically if it reappears.
- The suite and manifests currently report `0.1.0-beta.5`; the matching public
  beta package is published and installable. P1 completion and destructive
  lifecycle rehearsal remain separate project gates rather than claims that the
  public beta has not shipped.
