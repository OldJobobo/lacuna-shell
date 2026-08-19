# Quattro P1 Closeout Execution Plan

Status: ready for execution after product-decision checkpoint

This plan turns the acceptance criteria in
[`quattro-p1-product-integration-plan.md`](quattro-p1-product-integration-plan.md)
into an ordered implementation and validation program. The P1 plan remains the
product authority; this document controls how the remaining work is executed.

The execution must use pi subagents. The parent agent orchestrates, resolves
approved scope, and reports results, but does not perform the implementation
itself. Each writable phase has one worker subagent, followed by fresh read-only
reviewers and an independent validator. Parallelism is limited to read-only
reconnaissance and review unless isolated worktrees are deliberately approved.

## Outcome

P1 is closed only when:

- every rich native surface has an explicit ownership, action, side-effect,
  coexistence, and failure contract;
- every beta-supported setting is inventoried and deterministically survives
  mutation, reload, restart, migration, reset, and failed persistence;
- the sidebar and attached flyouts obey the approved pointer-first focus and
  dismissal contract;
- media provider, playback, presentation, credential, restart, and fallback
  behavior is documented and tested;
- normal installation produces one curated omakase setup with safe
  customization and reset behavior;
- the packaged candidate passes the P1 live matrix and the Beta Exit Record is
  populated with actual evidence.

Repository tests alone cannot close P1.

## Locked Product Decisions

These decisions are already approved and must be quoted in every relevant
worker prompt:

1. The mapped sidebar without an interactive flyout uses
   `WlrKeyboardFocus.None` and remains pointer-driven.
2. General keyboard navigation is excluded. Ordinary flyout controls do not
   provide Tab traversal, arrow-key traversal, or keyboard activation.
3. Interactive flyouts may acquire bounded focus for their dismissal lifecycle,
   focus restoration, and intentional text entry.
4. Click-away, `Escape`, unconsumed `Backspace`, and explicit close dismiss an
   interactive flyout and restore the previous application focus.
5. An active text field consumes Backspace normally; Backspace dismisses only
   when it was not consumed by text editing.
6. Accessible names, roles, pointer hit regions, and tooltip behavior remain,
   even when ordinary controls are not keyboard-navigable.
7. Lacuna must not duplicate Omarchy-owned orchestration or user-visible side
   effects.
8. Optional visual-surface work is not a beta gate.

The implementation may use the scoped keyboard-focus mode required for
intentional text input. It must not infer that compositor focus implies general
keyboard navigation.

## Approved Phase 0 / Phase 6 Product Decisions

The answers are frozen below and encoded in
[`../../../config/omakase-profile.json`](../../../config/omakase-profile.json).
No P1 workstream is complete by this checkpoint.

1. **Omakase membership:** normal install uses the exact checked 46 supported
   roots, including experimental plugins, and excludes deprecated/migration-only
   `lacuna.compact-pill`. It activates the Lacuna bar and all applicable menu,
   persistent/service, and overlay entries. Bar placement is exactly the
   canonical 23-entry `LACUNA_BAR_LAYOUT`, not empty script-pill or every
   optional widget.
2. **Media scope:** `lacuna.media-player` and
   `lacuna.media-player-video` are installed and enabled by default; absent
   provider credentials degrade safely to disabled/unavailable providers.
3. **Reset boundary:** `lacuna reset` is safe-only with no purge mode. Its exact
   four owned bar keys, activation entries, and settings branches are listed in
   the checked profile and default from `settings.example.json`. Credentials,
   provider configuration, favorites, queue/history, auth/reminder files,
   preferred/custom apps, unrelated Omarchy state, other bar keys, and unknown
   JSON-safe fields are preserved.
4. **Stability vocabulary:** exactly `stable`, `beta`, `experimental`, and
   `deprecated` are valid maturity values. Current supported manifests remain
   `beta` except `lacuna.script-pill=experimental` and
   `lacuna.compact-pill=deprecated`; maturity is independent of the suite
   channel and is never inferred.
5. **Rehearsal target:** destructive release rehearsal is approved only on the
   current user/machine after automatic backups, verified restoration
   capability, and a fresh explicit confirmation immediately before destructive
   steps. The contract is recorded now; destructive rehearsal is not run now.

## Subagent Execution Protocol

Every phase uses the following parent-orchestrated loop.

### 1. Read-only planning fanout

The parent calls `subagent({ action: "list" })`, then launches two or three
fresh-context `context-builder`, `scout`, `oracle`, or `reviewer` agents in
parallel. Each receives a distinct concern and must return:

- exact files and symbols;
- acceptance criteria covered;
- implementation risks and unresolved decisions;
- focused test commands;
- plugin IDs requiring live deployment;
- explicit stop conditions.

Reconnaissance agents never edit project files.

### 2. Single writer

After recon findings are reconciled, the parent launches exactly one `worker`
subagent for the phase. The prompt includes:

- the approved decisions;
- a narrow file and behavior scope;
- required tests;
- deployment requirements;
- stop/escalation conditions;
- an instruction not to stage, commit, reset, stash, or overwrite unrelated
  changes unless separately authorized.

The writer is the only process editing the active worktree during that phase.
It must report changed files, commands, failures, residual risks, and whether
live deployment occurred.

### 3. Fresh review and validation

After the writer finishes, the parent launches in parallel:

- one or two fresh-context `reviewer` agents with distinct correctness angles;
- one fresh validator agent that runs the phase commands independently.

Reviewers are read-only. Findings must cite files and lines and distinguish
blockers from optional improvements.

### 4. Bounded fix loop

Accepted blocker or high-severity findings return to the same worker session,
when resumable, or to one replacement worker with the complete phase context.
Fresh reviewers and validation run after the fix. Stop after two failed cycles,
on a product-decision conflict, or when a safety stop condition is reached.

### 5. Live deployment and evidence

For user-visible or stateful QML changes, the phase is not complete until the
reviewed repository state is deployed with `./scripts/dev deploy <plugin-id>`
and installed-copy verification passes. Dry-run deployment is planning evidence,
not live verification.

Subagent artifacts and transcripts stay outside tracked project content.

## Phase 0 — Freeze Decisions And Baseline

### Goal

Protect the corrected focus contract, resolve the five product decisions above,
and establish a known baseline without erasing existing user changes.

### Subagent shape

Parallel read-only agents:

1. **Decision consistency reviewer:** compare the P1 plan, roadmap, plans index,
   and docs contracts with the locked focus semantics.
2. **Omakase/media auditor:** propose exact membership classifications from
   manifests, installer behavior, and catalog metadata.
3. **Reset/rehearsal auditor:** identify safe ownership boundaries and a
   non-destructive rehearsal environment.

After user approval, one writer records only the approved decisions and updates
related documentation contracts. Fresh docs and product-scope reviewers verify
consistency.

### Likely files

- `docs/plans/active/quattro-p1-product-integration-plan.md`
- `docs/plans/active/quattro-p1-closeout-execution-plan.md`
- `docs/roadmap.md`
- `docs/plans/README.md`
- `docs/install.md`
- `docs/plugins/README.md`
- `tests/test_docs_contracts.py`

### Exit gate

- all five decisions have explicit, machine-transcribable answers;
- corrected focus semantics remain unchanged;
- no implementation or completion claim has been added;
- `python3 -m pytest tests/test_docs_contracts.py` passes;
- `git diff --check` passes.

## Phase 1 — Close Native Integration Ownership

Covers P1 Workstream 1.

### Goal

Create a complete, auditable matrix for battery, media, idle, audio, Bluetooth,
network, temperature, tray, notifications, updates, and system statistics.

Each row must name:

- state source and owner;
- command/action boundary;
- notification or side-effect owner;
- presentation owner;
- canonical and mixed-layout coexistence rule;
- unavailable, failed, and stale behavior.

### Subagent shape

Parallel read-only agents:

1. source and service-owner tracer;
2. duplicate-side-effect and coexistence reviewer;
3. failure-state and test-coverage reviewer.

One worker updates the matrix, tests, and only those implementations with a
proven ownership or failure defect. Fresh Omarchy-integration and regression
reviewers inspect the result; an independent validator runs the checks.

### Likely files

- `docs/architecture/omarchy-integration.md`
- `tests/test_docs_contracts.py`
- focused tests for affected services
- affected plugins only when the audit proves a behavior defect

### Required validation

```bash
python3 -m pytest tests/test_docs_contracts.py
python3 -m pytest tests/test_qml_contracts.py tests/test_status_scripts.py
scripts/quattro-compatibility --check
./scripts/check.sh
```

If plugin code changes, deploy each affected plugin and exercise its available,
unavailable, and mixed-layout case.

### Exit gate

All eleven surfaces have one documented owner for every responsibility, no
competing orchestration remains, and failure behavior is explicit and tested.

## Phase 2 — Build The Checked Settings Inventory

Covers the inventory portion of P1 Workstream 2.

### Goal

Inventory every beta-supported setting across:

- manifest schemas and `shell.json`;
- Lacuna runtime `settings.json`;
- Omarchy/Hyprland host settings;
- provider configuration;
- separate media queue/history state;
- internal, transient, and intentionally hidden keys.

Every inventory row names its path/control, type, default, valid values or
range, normalization, persistence owner, reset behavior, and migration rule.

### Subagent shape

Parallel read-only agents:

1. manifest/schema enumerator;
2. runtime-default/normalizer enumerator;
3. UI-control and separate-store enumerator.

One worker creates the inventory and a mechanical completeness test. Fresh
settings-architecture and completeness reviewers verify it against source.

### Expected files

- new `docs/settings-inventory.md`
- `docs/configuration.md`
- new `tests/test_settings_inventory.py`
- possibly focused docs/manifest contract tests

### Required validation

```bash
python3 -m pytest tests/test_settings_inventory.py tests/test_docs_contracts.py
python3 -m pytest tests/test_manifest_contracts.py tests/test_qml_contracts.py
./scripts/check.sh
```

### Exit gate

No supported key or control is undocumented or orphaned, and adding an
uninventoried manifest setting causes a deterministic test failure.

## Phase 3 — Make Settings Safe And Deterministic

Completes P1 Workstream 2.

This phase is split into two sequential writer cycles because both touch the
same vendored settings services.

### Phase 3A — Preservation, normalization, migration, and reset

Parallel planners inspect recursive normalization and reset ownership. One
worker then:

- preserves unknown JSON-safe fields in every known nested settings family;
- normalizes known values without reintroducing invalid source values;
- canonicalizes migration aliases;
- implements approved leaf/subtree reset semantics;
- keeps `lacuna.state/Service.qml` and
  `lacuna.menu/services/LacunaSettings.qml` synchronized;
- adds runtime round-trip, future-field, malformed-value, migration, and reset
  tests.

Expected tests include a future-settings fixture and a focused
`tests/test_qml_behavior_settings.py` when existing suites are insufficient.

### Phase 3B — Confirmed persistence and visible failures

Before writing, two read-only agents inspect the installed Quickshell `FileView`
API and design deterministic failure injection. If the API cannot confirm
success or failure reliably, the worker stops and requests approval before
introducing a plugin-local atomic-write helper.

The worker must provide:

- explicit idle/saving/saved/failed state;
- last confirmed data/revision;
- serialized latest-write-wins behavior;
- visible, retryable, redacted save failure;
- correct handling of external reload and corrupt backup;
- no optimistic durable-success claim before confirmation.

### Review angles

- state-loss and migration safety;
- write ordering and failure recovery;
- credential/error redaction;
- vendored-file equality.

### Required validation

```bash
scripts/sync-vendored --check
python3 -m pytest tests/test_qml_behavior_settings.py tests/test_live_behavior.py
python3 -m pytest tests/test_qml_contracts.py tests/test_settings_inventory.py
./scripts/check.sh
```

Then deploy and verify:

```bash
./scripts/dev deploy lacuna.state
./scripts/dev deploy lacuna.menu
omarchy restart shell
```

Use backed-up test state to prove nested mutation, restart, reset, unknown-field
preservation, injected write failure, retry, and installed-copy equality.

### Exit gate

Known values normalize, unknown data survives, resets touch only approved
branches, durable success is confirmed, failure is visible and retryable, and
all representative settings round-trip through restart.

## Phase 4 — Implement The Correct Flyout Contract

Completes P1 Workstream 3.

### Goal

Align runtime behavior with the locked decision without removing required
click-away or text-entry focus.

Required behavior:

- passive sidebar: `WlrKeyboardFocus.None`;
- interactive flyout: bounded dismissal/focus-grab lifecycle;
- intentional text entry: scoped input focus without enabling general control
  navigation;
- Escape, unconsumed Backspace, click-away, and explicit close dismiss and
  restore the prior application;
- text fields consume Backspace normally;
- ordinary controls retain pointer/accessibility behavior but lose general Tab,
  arrow, and keyboard-activation paths;
- every close/interruption clears the grab and leaves no invisible input mask.

### Subagent shape

Parallel read-only agents:

1. focus-grab and key-propagation state-machine planner;
2. ordinary-control keyboard-navigation inventory;
3. live Hyprland/input-mask test designer.

One worker owns all overlapping `lacuna.menu` edits. Fresh focus/compositor,
accessibility, and layer/geometry reviewers inspect the implementation. A
separate validator runs component and geometry tests.

### Likely files

- `lacuna.menu/menu/LacunaPanelWindow.qml`
- `lacuna.menu/menu/MenuWindow.qml`
- attached flyout and shared control QML identified by the inventory
- `tests/test_qml_behavior_accessibility.py`
- `tests/test_qml_behavior_panels.py`
- `tests/test_qml_contracts.py`
- gated live behavior/visual tests

### Required validation

```bash
python3 -m pytest tests/test_qml_behavior_accessibility.py tests/test_qml_behavior_panels.py
python3 -m pytest tests/test_qml_contracts.py tests/test_qml_geometry.py
./scripts/check.sh
./scripts/dev deploy lacuna.menu
```

Live validation records the active Hyprland client before and after every
flyout dismissal path, verifies text Backspace behavior, and checks the focus
grab and input mask after interrupted closes. Use the repository's gated live
visual/behavior convention and restore modified state in cleanup.

### Exit gate

No passive focus theft, no general keyboard navigation, all dismissal paths
work, text editing is preserved, prior application focus returns, and no grab or
input region remains after close.

## Phase 5 — Close Media Reliability And Security

Completes P1 Workstream 4 regardless of whether media is normal-profile or
optional.

### Goal

Prove one authoritative playback owner, credential-safe provider operation,
bounded cancellation/restart, and recoverable presentation behavior.

### Subagent shape

Parallel read-only agents:

1. provider/worker cancellation and restart tracer;
2. credential and URL redaction reviewer;
3. inline/background/automatic presentation-state reviewer.

One media worker applies the narrow changes. Fresh security, state-machine, and
background-video lifecycle reviewers inspect the result. The video reviewer
must enforce the two-phase black-cover/source lifecycle in `AGENTS.md`.

### Required work

- capture argv, stderr, surfaced errors, worker events, and logs with sentinel
  credentials and prove redaction;
- settle busy/provider state after cancellation, worker death, timeout, and
  stale revisions;
- test success, timeout, interruption, cancellation, and failure for each
  supported presentation handoff;
- prove fallback when one renderer fails and a safe terminal state when none is
  available;
- document and test which settings/queue/history state survives restart and
  which playback/search/socket state is ephemeral;
- preserve the existing background-video transition invariants.

### Likely files

- `lacuna.media-player/Service.qml`
- `lacuna.media-player/scripts/`
- `lacuna.media-player-video/Overlay.qml` only for demonstrated defects
- media UI files only after reconciling Phase 4 focus ownership
- `docs/architecture/media-player.md`
- media worker, script, and QML behavior tests

### Required validation

```bash
python3 -m pytest tests/test_media_player_worker.py tests/test_status_scripts.py
python3 -m pytest tests/test_qml_behavior_media_service.py tests/test_qml_behavior_media_ui.py
python3 -m pytest tests/test_qml_behavior_video.py tests/test_qml_behavior_media_overlay.py
python3 -m pytest tests/test_qml_contracts.py tests/test_docs_contracts.py
./scripts/check.sh
./scripts/dev deploy lacuna.media-player
./scripts/dev deploy lacuna.media-player-video
```

Deploy `lacuna.menu` too only if this phase changes it. Live probes cover
provider cancellation/failure, worker death, renderer fallback, restart/rescan,
process cleanup, and secret-free process/log inspection.

### Exit gate

Every media handoff and provider operation has bounded success/failure behavior,
credentials do not leak, an available presentation recovers, and restart
behavior agrees with the documented persistence policy.

## Phase 6 — Curate Omakase And Add Safe Reset

Completes P1 Workstream 5.

### Goal

Replace discovery-based “full” membership with the approved explicit setup and
provide a safe return to that setup.

### Subagent shape

Parallel read-only agents:

1. installer/profile/dependency tracer;
2. layout and settings-baseline reconciler;
3. manifest stability/catalog consistency reviewer.

One installer worker owns all installer, profile contract, catalog, and reset
changes. Fresh rollback/destructive-path, onboarding, and manifest/catalog
reviewers validate it.

### Required work

- add one checked machine-readable omakase contract containing exact roots,
  layout membership, and reset-owned settings;
- make normal installation apply it without an architectural profile decision;
- keep selective/profile installs under advanced, development, or recovery
  documentation;
- ensure adding a new manifest cannot silently change omakase membership;
- implement reset and reset dry-run with snapshot, validation, atomic
  replacement per file, one reload, and transactional rollback for handled
  write/reload failures; abrupt loss between replacements remains a documented
  limitation rather than adding a journal in this scope;
- preserve unrelated plugins, unknown fields, credentials, and media data
  according to the approved reset boundary;
- reconcile README, install docs, examples, catalog, stability vocabulary, and
  manifests.

### Expected files

- new `config/omakase-profile.json`
- `scripts/lacuna`
- configuration examples
- `README.md`
- `docs/install.md`
- `docs/plugins/README.md` and catalog pages
- manifest metadata where needed
- installer, manifest, docs, and inventory tests

### Required validation

```bash
python3 -m pytest tests/test_lacuna_installer.py tests/test_manifest_contracts.py
python3 -m pytest tests/test_plugin_kind_contracts.py tests/test_docs_contracts.py
python3 -m pytest tests/test_settings_inventory.py
./scripts/lacuna install --dry-run --yes
./scripts/lacuna reset --dry-run --yes
./scripts/dev deploy --all --only-changed --dry-run
./scripts/check.sh
```

Rehearse destructive paths first with temporary XDG state and mocked Omarchy
commands. Real install/reset/rollback/uninstall testing requires the approved
rehearsal target.

### Exit gate

Normal installation resolves exactly the approved roots plus dependencies,
reset restores only approved Lacuna-owned state, customization survives within
the documented boundary, rollback works, and documentation presents one normal
product path.

## Phase 7 — Integrated P1 Validation And Beta Exit Record

Completes P1 Workstream 6.

### Freeze rule

Feature implementation stops before this phase. Defects return to the worker
responsible for the affected phase and repeat fresh review. The Beta Exit Record
is written only after the corresponding evidence exists.

### Subagent shape

Parallel fresh validators against the same candidate state:

1. repository and compatibility validator;
2. package/archive inventory validator;
3. product-decision and documentation consistency validator.

A separate live-validation operator runs the approved installed-shell matrix
without editing source. If fixes are needed, exactly one worker handles each
returned phase. After all gates pass, one final writer records the evidence and
a fresh release reviewer checks every claim against raw output.

### Repository gate

```bash
./scripts/check.sh
python3 -m pytest tests/test_qml_contracts.py tests/test_qml_behavior_*.py
python3 -m pytest tests/test_status_scripts.py tests/test_qml_behavior_video.py
python3 -m pytest tests/test_lacuna_installer.py tests/test_docs_contracts.py
python3 -m pytest tests/test_manifest_contracts.py tests/test_aur_packaging.py
scripts/quattro-compatibility --check
scripts/quattro-p0-smoke
./scripts/lacuna install --dry-run --yes
./scripts/lacuna reset --dry-run --yes
./scripts/dev deploy --all --only-changed --dry-run
git diff --check
```

### Artifact and live matrix

Record the exact candidate commit, artifact name/hash, Omarchy version,
Quickshell version, monitor/session context, and results for:

1. clean normal install with no profile choice;
2. exact omakase membership, active bar, layout, and settings baseline;
3. shell restart and menu summon;
4. representative manifest, nested runtime, provider, and host-setting round
   trips;
5. future-field preservation, canonical reset, failed save, visible error, and
   retry;
6. passive sidebar focus and every flyout dismissal/restoration path;
7. media cancellation, provider failure, secret redaction, renderer fallback,
   and restart behavior within the approved media scope;
8. injected update failure and rollback;
9. uninstall and stock-bar recovery;
10. final installed-copy drift verification.

### Exit gate

- every P1 acceptance criterion has repository and required live evidence;
- no blocker or high-severity review finding remains;
- the actual packaged artifact, not a dirty checkout, was rehearsed;
- the P1 Beta Exit Record contains dated commands, versions, hashes, outcomes,
  known limitations, and evidence locations;
- roadmap, P1 status, release notes, and manifest/catalog claims agree.

## Dependency Order

```text
Phase 0: decisions and corrected baseline
  ├─ Phase 1: native ownership matrix
  └─ Phase 2: checked settings inventory
       └─ Phase 3A: preservation/migration/reset
            └─ Phase 3B: confirmed persistence
                 └─ Phase 4: flyout focus and dismissal
                      └─ Phase 5: media reliability
                           └─ Phase 6: omakase and safe reset
                                └─ Phase 7: integrated beta exit
```

Read-only reconnaissance for Phases 1 and 2 may run concurrently after Phase 0.
All writers remain sequential because settings, menu, media, installer, and
release documentation overlap.

## Stop Conditions

The parent stops execution and asks for a decision when:

- an omakase, media, reset, stability, or rehearsal classification is missing;
- a writer would overwrite unrelated local changes;
- more than one writer would touch the same worktree;
- a settings migration or reset could lose unknown data or credentials;
- durable write success cannot be observed without a new helper architecture;
- Backspace consumption cannot be distinguished safely;
- a flyout traps focus or leaves a grab/input region after close;
- a media token appears in argv, logs, errors, or diagnostics;
- a media change violates the background-video transition invariants;
- installer/reset/rollback testing would affect the current user without
  explicit approval;
- two review/fix cycles fail to clear a blocker;
- the installed plugin copy differs from the reviewed repository state.

## Reusable Parent-Orchestrator Prompt

```text
Execute the accepted Quattro P1 closeout plan in
`docs/plans/active/quattro-p1-closeout-execution-plan.md` using pi subagents.

You are the parent orchestrator. Do not implement broad phases yourself. Before
execution, read AGENTS.md, the P1 product plan, roadmap, this execution plan,
and the current git diff. Preserve all user changes.

For each phase:
1. Run `subagent({action: "list"})`.
2. Launch the phase's distinct read-only planners in one parallel fresh-context
   call. Require exact file/symbol evidence, risks, tests, deploy IDs, and stop
   questions.
3. Reconcile their findings and launch exactly one worker with the approved
   decisions, narrow scope, required tests, deployment contract, and stop rules.
4. Launch fresh read-only specialist reviewers and an independent validator in
   parallel.
5. Return accepted blocker/high findings to the same writer, then repeat fresh
   review. Stop after two failed cycles or any plan stop condition.
6. For user-visible/stateful changes, deploy the reviewed plugins with
   `./scripts/dev deploy`, verify installed-copy equality, and run the phase's
   live probes. Dry-run is not live verification.
7. Report changed files, tests, deployment results, evidence, and remaining
   risks before starting the next writer phase.

Do not stage, commit, reset, stash, clean, or publish unless explicitly asked.
Keep subagent artifacts outside tracked project content. Never update P1 status
or the Beta Exit Record from intended results; record it only after the packaged
candidate and live matrix pass.

Locked focus behavior: passive sidebar uses None; interactive flyouts may use
bounded focus for click-away, Escape, unconsumed Backspace, explicit close,
focus restoration, and intentional text entry; text fields consume Backspace;
ordinary controls have no general Tab/arrow/keyboard-activation navigation.
```
