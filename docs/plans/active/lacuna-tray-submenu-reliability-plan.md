# Lacuna Tray Submenu Reliability Plan

Status: implemented in repository; live deployment and manual validation pending

Purpose: make `lacuna.tray` submenu drill-down safe across synchronous QML
model swaps and asynchronous DBusMenu lifecycle changes, and protect the new
state machine with runtime behavior tests rather than source-string contracts
alone.

## 1. Required Outcome

Tray menus with nested DBusMenu entries remain usable without requiring
Quickshell's `QApplication` mode. Entering and leaving a submenu must not allow
a rapid follow-up click to activate an unrelated row, and removing a menu entry
while its submenu is open must return the popup to the nearest valid level
instead of leaving stale navigation state.

The implementation must satisfy these invariants:

1. One live `QsMenuOpener` is retained per active menu level so every child
   entry remains owned by its parent model for as long as it is displayed.
2. Nested openers are destroyed deepest-first, after reactive state no longer
   references them.
3. A synchronous `Repeater` model swap cannot turn a rapid second click into an
   action on the replacement row.
4. If an opener loses its menu handle, that level and all descendants are
   pruned without re-entrant teardown or stale titles.
5. Closing, switching tray items, and fullscreen suppression clear submenu
   state deterministically.
6. Existing root-menu rendering, action triggering, popup dismissal, scrolling,
   and tray-item activation behavior remain unchanged.
7. The lifecycle is covered by a runtime QML behavior test. Contract tests may
   pin integration points but are not the only evidence.

## 2. Current Risks

### 2.1 Input retargeting during model replacement

`enterSubmenu()` and `leaveSubmenu()` replace the model used by the menu-row
`Repeater` synchronously. A second click delivered before the pointer moves can
land on a newly created row at the same coordinates and trigger an unrelated
entry.

### 2.2 Stale depth after asynchronous menu destruction

Quickshell clears a `QsMenuOpener` menu when its `QsMenuHandle` is destroyed and
then exposes an empty children model. DBusMenu layout updates may remove entries
while the popup is open. The current stack does not observe that invalidation,
so it can retain an obsolete title and depth with no rows.

### 2.3 Insufficient behavioral coverage

The current additions to `tests/test_qml_contracts.py` assert source strings.
They do not execute multi-level navigation, input settling, delayed menu
invalidation, or deepest-first teardown.

## 3. Implementation Plan

### Phase 1 — Introduce a testable navigator

Create `lacuna.tray/TrayMenuNavigator.qml` as the single owner of submenu
navigation state. It should provide:

- the opener stack, current depth, current title, and current children;
- `enterSubmenu(entry, title)`, `leaveSubmenu()`, `reset()`, and invalid-level
  pruning;
- a configurable opener component so production uses `QsMenuOpener` while the
  runtime test can supply deterministic fake opener objects;
- a configurable owner for dynamically created openers;
- an input-settling state and timer.

`lacuna.tray/Widget.qml` should render the navigator's state and forward menu
interactions to it. The root `trayMenuOpener` remains responsible for the active
tray item's root menu.

### Phase 2 — Guard level-changing input

When entering or leaving a submenu:

1. reset `trayMenuFlick.contentY` before replacing the model;
2. mark the menu level as settling;
3. restart a short timer, initially 250 ms;
4. ignore menu-row and back-row clicks while settling;
5. clear and stop settling during reset and close.

The delay is not a general debounce for actions. It applies only immediately
after a level-changing model swap, so normal single-click activation remains
responsive.

### Phase 3 — Prune invalid menu levels

Observe `menuChanged` on every dynamically created opener. If an opener's menu
becomes `null`:

1. find that opener's index in the active stack;
2. immediately publish the valid prefix as the new stack;
3. destroy the invalid opener and all descendants deepest-first;
4. guard the operation against callbacks caused by the teardown itself;
5. settle the newly exposed parent level.

If the invalid opener is no longer in the stack, ignore the callback. Root-menu
invalidation remains owned by the existing tray-item and popup lifecycle; it
must not be confused with nested-level pruning.

### Phase 4 — Add runtime behavior coverage

Add `tests/test_qml_behavior_tray.py` using `tests/qml_harness.py`. Instantiate
`TrayMenuNavigator.qml` with fake opener-like `QtObject` instances so the tests
do not depend on a live StatusNotifier application.

Cover at least:

1. entering two levels updates depth, title, and active children;
2. entering and leaving enable the settling guard;
3. a level-changing action is rejected while settling and accepted after the
   timer clears;
4. invalidating the current opener returns to its parent;
5. invalidating a parent removes it and every descendant;
6. invalidation callbacks during teardown do not prune valid ancestors twice;
7. reset publishes an empty stack before destroying openers deepest-first;
8. switching root tray items resets the old nested hierarchy before the root
   opener changes.

Keep focused assertions in `tests/test_qml_contracts.py` for the navigator's
presence and removal of platform submenu display calls, but avoid duplicating
its internal implementation as source-string pins.

### Phase 5 — Live validation

After repository tests pass, deploy the changed plugin with:

```bash
./scripts/dev deploy lacuna.tray
```

Manually verify:

- single-level and multi-level submenu drill-down;
- deliberate and rapid double-clicks on submenu rows;
- back navigation after scrolling a long submenu;
- a tray application whose menu updates while open;
- outside-click dismissal and reopening at the root level;
- switching between tray items while nested;
- fullscreen suppression and shell restart;
- no QML, QsMenu, or DBusMenu lifecycle errors in the user journal.

## 4. Validation Commands

```bash
python3 -m pytest tests/test_qml_behavior_tray.py tests/test_qml_contracts.py -q
qmllint -I /usr/lib/qt6/qml \
  lacuna.tray/Widget.qml \
  lacuna.tray/TrayMenuNavigator.qml
./scripts/check.sh
./scripts/dev deploy lacuna.tray
```

If `./scripts/check.sh` still reports the existing vendored
`lacuna.bar/BarModel.js` mismatch, record it separately and verify that no new
failure is attributable to the tray changes.

## 5. Acceptance Criteria

The plan is complete when:

- a rapid second click after changing levels cannot trigger a replacement row;
- asynchronous destruction of the current or ancestor menu handle leaves no
  stale title, depth, or empty trapped level;
- reset and invalidation teardown are deterministic and deepest-first;
- runtime QML tests cover settling, multi-level navigation, invalidation,
  re-entrancy, and reset ordering;
- contract, runtime, lint, and repository checks have recorded results;
- the repository plugin is deployed to the live install and submenu behavior is
  manually verified inside Omarchy shell.

## 6. Scope Exclusions

This work does not redesign tray-menu visuals, enable `QApplication` mode,
replace Quickshell's StatusNotifier or DBusMenu services, or address unrelated
repository state. In particular, the existing vendored `BarModel.js` mismatch
and the untracked package archive are separate housekeeping decisions.
