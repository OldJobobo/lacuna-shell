# Development Workflow

Status: canonical maintainer and contributor protocol

Lacuna uses lightweight trunk-based development. `master` is the only
long-lived integration branch and should remain releasable. Work moves from an
issue or approved plan through a short-lived branch, pull request, risk-matched
validation, and—when behavior is visible or stateful—verified deployment in the
running Omarchy shell.

## Work Lifecycle

```text
Reported → Triaged → Ready → In progress → Review
→ Live verification when required → Done
```

Create an issue for behavioral bugs, features, state/schema changes,
installer/migration/packaging work, release blockers, and cross-plugin
refactors. Documentation typos and mechanical maintenance may go directly to a
pull request.

Triage records:

- affected plugin or subsystem;
- acceptance criteria;
- regression risk and change class;
- required validation tier;
- whether live deployment is required;
- target release or milestone;
- recovery or rollback implications.

Use a repository plan only when work spans multiple pull requests or plugins,
changes architecture, state migration, geometry, focus, layer stacking,
installation, rollback, packaging, or release scope. GitHub issues remain the
actionable tracker. Link issues and plans both ways.

## Branches And Merges

Branch from current `master` using:

```text
fix/<issue>-<summary>
feat/<issue>-<summary>
refactor/<issue>-<summary>
docs/<summary>
release/<version>
hotfix/<version>-<summary>
```

Keep branches short-lived and diffs focused. Open a draft pull request early
for risky or cross-plugin changes. Prefer squash merge and delete the branch
after merge. Preserve multiple commits only when they materially explain a
migration or staged compatibility change.

Use concise imperative commit subjects, such as `Fix tray submenu teardown`.
Do not force-push `master`, move published tags, or commit directly to the
protected branch.

## Change Classes

| Class | Typical work | Minimum evidence |
| --- | --- | --- |
| Documentation/mechanical | prose, metadata, formatting | targeted checks and Tier 1 CI |
| Runtime behavior | QML interaction, services, scripts | regression test, Tier 1, Tier 2 |
| Visual/geometry | layout, frame, layers, transitions | geometry/runtime test, Tier 1, Tier 2, screenshot when useful |
| State/schema/migration | persistence, normalization, migration | success/failure/migration tests, Tier 1, Tier 2, rollback notes |
| Installer/release | install, update, rollback, package, release | transaction tests, Tier 1, focused Tier 2, Tier 3 before publication |

Source-contract tests may protect deliberate QML structure, but visible or
stateful behavior also needs runtime, geometry, integration, or opt-in live
coverage.

## Validation Tiers

### Tier 0 — Iteration

Run the smallest useful loop while editing:

```bash
python3 -m pytest <targeted-tests> -q
qmllint <changed-qml-files>
shellcheck <changed-shell-files>
git diff --check
```

### Tier 1 — Every pull request

```bash
./scripts/check.sh
```

CI is authoritative when optional local lint tools are unavailable. Vendored
copies must be synchronized before review.

### Tier 2 — Visible or stateful changes

Deploy the repository copy transactionally:

```bash
./scripts/dev deploy <plugin-id>
# Cross-plugin change:
./scripts/dev deploy --all --only-changed
```

Record the helper's installed-file verification, exact Omarchy and Quickshell
versions, shell restart result, primary scenario, dismissal/failure path,
restart persistence where relevant, and any journal errors. Evidence must match
the latest substantive pull-request revision.

### Tier 3 — Release candidate

Run the complete release gate:

```bash
./scripts/check.sh
scripts/release-check
scripts/release-version check
scripts/release-inventory --check
scripts/build-release-archive --check-reproducible
scripts/rehearse-aur-package
scripts/check-aur-package
scripts/quattro-compatibility --check
scripts/quattro-p0-smoke
./scripts/lacuna install --dry-run
./scripts/lacuna update --dry-run
./scripts/lacuna status
git diff --check
```

Every beta, RC, stable, and patch release also records clean install, restart,
update failure and rollback, uninstall, stock-shell recovery, and published
artifact smoke evidence on the declared supported environment.

## Review Order

Review changes in this order:

1. scope matches the issue and does not bundle unrelated cleanup;
2. plugin ownership and Omarchy-native service boundaries remain intact;
3. lifecycle, asynchronous state, and failure paths are correct;
4. geometry, focus, input, and layer-stacking contracts remain intact;
5. tests match the risk and are not source-string assertions alone;
6. state, migration, and installer changes have recovery coverage;
7. live evidence is current when Tier 2 applies;
8. changelog, migration notes, documentation, and screenshots match the user contract.

## Release And Hotfix Flow

Prepare every published version in a `release/<version>` pull request. Finalize
`CHANGELOG.md`, current release documentation, compatibility evidence,
inventory, package metadata, and Tier 3 evidence before tagging the exact merged
commit. Tags and release assets are immutable.

If `master` contains unrelated work when a shipped regression needs repair,
branch from the shipped tag, add the smallest fix and regression test, publish
the next prerelease or patch, then merge the fix back to `master`. Packaging-only
AUR changes increment `pkgrel`; upstream behavior changes require a new suite
version.

## Repository Protection

The repository cannot configure its own remote protection settings. Maintainers
must configure GitHub to require pull requests and the `Check` status for
`master`, require resolved conversations, reject force pushes, and protect
`v*` tags from deletion or replacement. When another maintainer is available,
require one approval; a solo maintainer records the same structured review and
evidence in the pull request.

## Maintenance Cadence

- During beta, triage issues and release blockers weekly.
- Reconcile plans, stale branches, workflow/tool pins, and release facts monthly.
- Run full compatibility and recovery rehearsal for every release.
- Keep only current delivery work in `docs/plans/active/`; move unscheduled work
  to `proposed/` rather than using active plans as a backlog.
