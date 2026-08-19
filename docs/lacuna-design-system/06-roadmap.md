# 06 · Roadmap — migrating the QML onto the language

**Status: A–F complete** (branch `lacuna-design-system`). A — de-Carbon `DesignTokens`;
B — named token vocabulary + `recess` wired; C — theme-derived color roles in `Theme.qml` /
`ColorProfile.qml`; D — one named `reveal` motion scale; E — Hack Nerd Font adopted;
F — docs/contract sync. The reduced-motion hook (`animationDisabled`/`animationSpeed`) exists
centrally but is not yet bound to a user setting — the one tracked follow-up.

This is the living migration guide from today's code to the language defined in 00–05. It is
**staged and reversible**: each phase is independently shippable, and each phase that renames a
token also updates the tests that assert on it (the contract tests are deliberately strict).

## Constraints that shape every phase

- **No second Quickshell process; no cross-plugin runtime imports.** Tokens stay vendored per
  plugin and reconciled by `scripts/sync-vendored`. The spec is the source of truth for intent;
  `shared/qml/simple-bar/` is the source of truth for vendored code.
- **`tests/test_qml_contracts.py` asserts exact strings**, and `tests/test_vendored_files.py`
  asserts copy equality. Any rename or token change intentionally breaks these — fix them in the
  *same* phase, never as a follow-up.
- **2-space indentation; concise imperative commits.**
- **Color stays theme-derived throughout.** No phase introduces a fixed hue.

## Phase A — De-Carbon the foundation
**Goal:** `lacuna` becomes an original style; the Carbon lineage is retired.

- In `lacuna.menu/services/DesignTokens.qml`: remove the `carbon: lacuna` alias and the
  `"carbon" → "lacuna"` branch in `normalize()`. Keep `omarchy` and `material` as alternates.
- Update any consumer referencing `carbon`.
- Update the corresponding assertions in `tests/test_qml_contracts.py`.

**Verify:** `./scripts/check.sh`; grep shows no remaining `carbon` references.

## Phase B — Token vocabulary
**Goal:** the metaphor-named families exist as documented properties, not inline literals.

- Introduce `field / void / plate / ink / whisper / soft / seam / accent / danger / recess /
  threshold / reveal` as named tokens. Extend `lacuna.menu/components/LacunaTokens.qml` and/or add
  a `LacunaDesignLanguage.qml`; keep `lacuna.menu/components/LacunaGeometry.qml` as the sole
  `curveKappa` home.
- Replace inline literals in components with token references (no behavior change yet).

**Verify:** `qmllint` clean; visual diff is nil (pure indirection).

## Phase C — Color roles via Theme
**Goal:** every surface reads color through a named, theme-derived role.

- Formalize the role→theme derivations in `lacuna.menu/services/Theme.qml` and
  `shared/qml/simple-bar/ColorProfile.qml` (reuse existing `withAlpha`/parsers).
- Preserve `semantic`/`colorful` profiles and the `toneAccent(tone)` danger rule.
- Re-vendor (`scripts/sync-vendored`); update `tests/test_vendored_files.py`.

**Verify:** menu + widgets render correctly under **two** themes (proves Principle 4);
`tests/test_vendored_files.py` passes.

## Phase D — Unify motion
**Goal:** one `reveal` scale replaces the two timing sets.

- Reconcile `lacuna.menu/services/MotionTokens.qml` and `shared/qml/simple-bar/MotionTokens.qml`
  to the named scale in [03-motion.md](03-motion.md); map legacy/noctalia names across.
- Route `LacunaAnim`/`LacunaColorAnim`/`LacunaStateLayer` through the new names; remove inline
  millisecond literals in consumers.
- Wire the reduced-motion switch centrally.
- Re-vendor; update both contract and vendored-file tests.

**Verify:** reveal choreography unchanged in feel; reduced-motion collapses time but keeps the
edge-origin structure; tests pass.

## Phase E — Typography migration + component alignment
**Goal:** Hack Nerd Font adopted; primitives speak the families.

- Swap `monoFont` from `JetBrains Mono` to **Hack Nerd Font** in
  `lacuna.menu/components/LacunaTokens.qml` (and any `LacunaText.qml` default); confirm Tektur
  title usage is unchanged. One-line change because components reference the token, not a literal.
- Re-express primitive/control states against the families: interaction = `recess`
  (`LacunaStateLayer`), selection = `seam`/`accent` strip, surfaces fill-only.
- Re-vendor widget copies; update tests.

**Verify:** Hack Nerd Font renders across menu + bar (glyphs intact); no flooded-fill selections
remain; `./scripts/check.sh` passes.

## Phase F — Docs & contract sync
**Goal:** the repo's own docs point at this language; tests are green.

- Replace the "Flyout Surface Geometry" section in `AGENTS.md` with a pointer to
  [02-geometry.md](02-geometry.md).
- Fold `docs/plans/archive/lacuna-menu-unified-color-model.md` into [01-color.md](01-color.md) (leave a stub
  link if other docs reference it).
- Final `python3 -m pytest tests/test_qml_contracts.py tests/test_vendored_files.py` and full
  `./scripts/check.sh`.

## End-to-end verification

1. `./scripts/check.sh` — manifests/JSON, `qmllint` on all plugin QML, full pytest.
2. `scripts/sync-vendored` then `tests/test_vendored_files.py` — zero drift.
3. Live smoke: symlink plugins into `~/.config/omarchy/plugins/`, then
   `omarchy shell shell rescanPlugins` and
   `OMARCHY_PATH="$HOME/.local/share/omarchy" omarchy shell shell toggle lacuna.menu '{}'`.
   Confirm, across **two** Omarchy themes: the reveal choreography (geometry-first, threshold
   content fade), the molding seams, fill-only surfaces, Hack Nerd Font, and that *all* color came
   from the theme (Principle 4 — no Lacuna hue leaked in).

## Sequencing note

A–B are pure groundwork (safe, invisible). C–E are the visible adoption and should each ship with
their re-vendor + test updates attached. F is cleanup. Phases can ship one PR each; do not batch a
rename with an unrelated change, so a contract-test break always points at one cause.
