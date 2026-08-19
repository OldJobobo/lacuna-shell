# Lacuna Development Lifecycle Plan

Status: implemented in repository; remote protection and clean full-gate validation pending

Purpose: connect Lacuna's existing issue, plan, branch, review, test, live-deploy,
version, packaging, and release machinery into one enforceable software
development lifecycle without adding a long-lived development branch or
enterprise ceremony.

## Required Outcome

The repository maintains a protected, releasable `master`; delivers focused
changes through short-lived branches and reviewed pull requests; applies test
and live-verification requirements according to risk; distinguishes product,
plugin-maturity, and data-schema versions; and publishes immutable beta, RC,
stable, and patch releases from recorded compatibility evidence.

## Fixed Decisions

1. Use lightweight trunk-based development. Do not add a permanent `develop`
   branch.
2. `master` is the integration branch and should remain releasable.
3. Use a single suite SemVer in `VERSION`, mirrored to plugin manifests.
4. Keep plugin maturity and runtime/configuration schema versions independent
   from the suite version.
5. Use GitHub issues for executable work and plans only for cross-PR,
   architectural, migration, geometry/focus/layer, installer, or release work.
6. Behavioral QML changes require runtime, geometry, integration, or opt-in live
   coverage in addition to source contracts.
7. User-visible or stateful fixes are not complete until the changed plugin is
   deployed with `scripts/dev` and verified in Omarchy shell.
8. Release tags and artifacts are immutable. AUR-only revisions use `pkgrel`;
   upstream code changes use a new suite version.

## Implementation Phases

### Phase 1 — Working protocol

- Add `docs/development/workflow.md` as the canonical issue-to-release protocol.
- Update contributor, testing, issue, PR-template, documentation-index, and
  release guidance to reference the protocol and `scripts/dev deploy`.
- Define branch names, merge discipline, review order, risk classes, and test
  tiers.
- Document required GitHub branch/tag protection as a maintainer action.

### Phase 2 — Version authority

- Expand release-version validation to support published beta/RC/stable/patch
  versions and non-publishable `.dev.0` development states.
- Allow `stable` as a plugin maturity value without promoting every plugin.
- Separate and test product, manifest, settings, inventory, and persistence
  schema namespaces.
- Remove stale beta literals from current documentation and derive current
  release assertions from `VERSION`.
- Record release-tested Omarchy and Quickshell facts in the compatibility
  ledger.

### Phase 3 — Release enforcement

- Add one release-check command that validates version parity, publishability,
  changelog links, current-release documentation, inventory, compatibility
  evidence, and tag parity when run from a tag.
- Run the release check in pull-request CI and strict tag mode in release CI.
- Use the matching changelog section as the GitHub release body.
- Preserve deterministic archive and AUR rehearsal gates.

### Phase 4 — Operational adoption

Repository implementation can document but cannot itself enable remote GitHub
settings. Maintainers must configure:

- pull requests and the `Check` status as requirements for `master`;
- resolved review conversations;
- no force pushes to `master`;
- protection against deleting or moving `v*` tags.

Review active plans monthly and keep only current delivery work in `active/`.
Prune merged or abandoned branches after confirming they contain no unique work.

## Acceptance Criteria

- The canonical workflow is linked from contributor and published developer
  documentation.
- Pull requests capture issue/plan linkage, risk, automated evidence, live
  evidence, host versions, screenshots, and rollback notes.
- Development and published version forms are validated and covered by tests.
- Current docs agree with `VERSION`; tests no longer preserve stale release
  literals.
- Stable plugin maturity is accepted independently of the suite channel.
- `lacuna status` reports the actual settings schema expectation.
- Release compatibility evidence includes suite, Omarchy, Quickshell, date, and
  result.
- PR and tag CI invoke the unified release authority checks.
- Existing project, documentation, runtime, packaging, and release tests pass.

## Validation

```bash
python3 -m pytest tests/test_release_version.py \
  tests/test_manifest_contracts.py \
  tests/test_release_inventory.py \
  tests/test_quattro_compatibility.py \
  tests/test_docs_contracts.py -q
scripts/release-version check
scripts/release-inventory --check
scripts/release-check
./scripts/check.sh
```

Remote branch protection, destructive lifecycle rehearsal, AUR publication,
and branch deletion require separate maintainer action and are not performed by
recording or implementing this repository plan.
