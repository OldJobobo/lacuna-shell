## Summary

<!-- What does this change and why? Keep unrelated cleanup out of this PR. -->

## Issue and plan

- Closes #
- Plan: <!-- link or N/A -->

## Plugins touched

<!-- e.g. lacuna.menu, lacuna.bar -->

## Change class

- [ ] Documentation/mechanical
- [ ] Runtime behavior
- [ ] Visual/geometry
- [ ] State/schema/migration
- [ ] Installer/release

## Risk and rollback

<!-- Main regression risk and recovery path, or N/A. -->

## Automated validation

<!-- List exact commands and results. -->

```text
command:
result:
```

## Live validation

<!-- Required for visible or stateful changes; otherwise write N/A. -->

- Deploy command:
- Plugins deployed:
- Omarchy version:
- Quickshell version:
- Scenarios verified:
- Restart/persistence result:
- Journal errors:

## User-facing evidence

- [ ] Runtime/geometry/integration coverage accompanies behavioral QML changes
- [ ] Screenshots attached for meaningful visual changes
- [ ] `CHANGELOG.md` updated under `[Unreleased]` when user-visible
- [ ] User documentation or migration notes updated when required

## Final checklist

- [ ] `./scripts/check.sh` passes
- [ ] Vendored copies are synchronized (`scripts/sync-vendored --check`)
- [ ] Live evidence matches the latest substantive revision, or is not applicable
- [ ] The diff contains no unrelated generated files or package artifacts
