# Release Workflow

Status: active release runbook

Every publication is prepared in a `release/<version>` pull request under the
[development workflow](workflow.md). `VERSION` is the machine-readable suite
version for the checkout and every plugin manifest. On a published release it
must also agree with `README.md`, the matching changelog section, Git tag,
archive name, and release notes. During a `.dev.0` checkout, user documentation
continues to identify the latest published changelog/tag version while source
diagnostics identify the development suite version.

The current release line is:

```text
0.1.0-beta.N -> 0.1.0-rc.N -> 0.1.0
```

Do not publish `0.0.1-beta`; the repository established the `0.1.0` release
line before public beta, so that version would move backward. Between published
prereleases, a non-publishable development checkout may use
`0.1.0-beta.N.dev.0` or `0.1.0-rc.N.dev.0`; release tags may not use `.dev` or
`alpha` versions.

## Release Classes

- **Beta:** supported scope is declared and usable, but field testing may find
  product defects.
- **RC:** feature-frozen artifact with no known release-blocking defect.
- **Stable:** promotion of the verified RC lineage without new features.

## Prepare

1. Create `release/<version>` from current `master` and open the release pull
   request. Confirm the target gate in `docs/roadmap.md` and the P1/P2 plans is met.
2. Update `VERSION` and every `manifest.json` to the exact SemVer prerelease or
   stable version.
3. Move relevant changelog entries from `Unreleased` into the target version;
   record migrations, known limitations, and supported environment.
4. Preview the synchronized bump with `scripts/release-version set <version>
   --dry-run`, then use the same command without `--dry-run` to update
   `VERSION`, manifests, `PKGBUILD`, and `.SRCINFO` together. Arch `pkgver`
   removes the supported beta/RC prerelease hyphen.
5. Regenerate `config/release-inventory.json` with `scripts/release-inventory`
   and confirm the exact `config/omakase-profile.json` membership, activation,
   media inclusion, canonical layout, and plugin-maturity vocabulary match
   `docs/plugins/README.md`.
6. Confirm user-visible changes have current screenshots when useful.

## Validate The Tree

```bash
./scripts/check.sh
scripts/release-check
scripts/release-version check
scripts/release-inventory --check
scripts/build-release-archive --allow-dirty --check-reproducible
scripts/check-aur-package
scripts/rehearse-aur-package
scripts/quattro-compatibility --check
scripts/quattro-p0-smoke
./scripts/lacuna install --dry-run
./scripts/lacuna update --dry-run
./scripts/lacuna status
git diff --check
```

Run opt-in live tests from a real Omarchy session where applicable. Record the
exact Omarchy and Quickshell versions; do not substitute a stale test count for
the current command result.

## Rehearse The Artifact

Destructive rehearsal is approved only on the current user and machine after
all three safeguards: automatic backups, verified restoration capability, and
a fresh explicit confirmation immediately before destructive steps. Earlier
planning approval is not that immediate confirmation. Record the backup and
restore proof with the rehearsal. This contract does not authorize unattended
execution, and no destructive rehearsal was run when it was recorded.

Build from committed source, not an arbitrary dirty working tree. Run
`scripts/build-release-archive --check-reproducible` to create a deterministic,
single-root archive, checksum, and machine-readable file inventory. Then run
`scripts/rehearse-aur-package` and test the extracted artifact in a clean install
path:

1. Install and activate the exact canonical omakase profile, including both
   media plugins, and verify credential-free degradation.
2. Rescan/restart the shell and smoke the bar, menu, state, and settings.
3. Change and round-trip representative settings.
4. Inject or reproduce an update failure and verify rollback.
5. Verify uninstall preserves user state unless explicitly requested.
6. Verify the documented stock-bar recovery path.

RC additionally requires diagnostics and recovery output to be usable without
private project knowledge.

## Publish

1. Commit the prepared release tree.
2. Tag the exact commit as `v$(cat VERSION)`.
3. Push the commit and tag.
4. Verify the release workflow runs the full project gate, checks publishable
   tag/version, manifest/version, changelog, current-documentation, inventory,
   and compatibility-record parity, rehearses the Arch package, builds the
   archive, checksum, inventory, and verified Arch package, and creates the
   GitHub release from the matching changelog section. Beta and RC tags must be
   marked as prereleases.
5. Publish each approved beta, RC, and stable release through the same
   `lacuna-shell` AUR package. For every release, replace the
   scaffold's `SKIP` with that release archive's real checksum, regenerate
   `.SRCINFO`, and run `scripts/check-aur-package --publish-check`. Arch
   `pkgver` removes the SemVer prerelease hyphen, so `0.1.0-beta.5` becomes
   `0.1.0beta.5` and sorts before RC and stable versions.
6. Follow `packaging/aur/SUBMISSION.md`, including the clean-chroot build, exact
   package inspection, dedicated AUR repository, and post-publication smoke.
7. Install the published artifact once; do not treat workflow success alone as
   runtime validation.

## Promotion Discipline

- Beta builds may contain fixes required by beta feedback.
- RC builds accept release blockers only.
- Stable must not add features relative to the verified RC lineage.

## Commit And PR Notes

Use concise imperative commit messages, such as:

- `Add script pill manifest`
- `Port temperature widget shell contract`
- `Organize project documentation`

Pull requests should describe the plugin affected, list manual Omarchy smoke
tests, include screenshots for visible UI changes, and call out any remaining
standalone Lacuna dependencies.
