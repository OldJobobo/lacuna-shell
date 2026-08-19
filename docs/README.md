# Lacuna documentation portal

Status: audience map

The published documentation begins at [`docs/index.md`](index.md). It is written
for people using the complete Lacuna shell and follows a task-first journey.

## Use Lacuna

1. [Start here](getting-started/index.md)
2. [Install Lacuna](getting-started/installation.md)
3. [Take the first-run tour](getting-started/first-run.md)
4. [Choose the right settings surface](configuration/index.md)
5. [Learn the main features](guides/sidebar-and-launchers.md)
6. [Update safely](getting-started/upgrading.md)
7. [Troubleshoot or recover](help/troubleshooting.md)
8. [Get support](help/support.md)

User content lives in:

- `getting-started/`
- `guides/`
- `configuration/`
- `operations/`
- `help/`
- `releases/`

`install.md` and `configuration.md` remain concise compatibility entry points
for older inbound links; they are not independent copies of current guidance.

## Develop Lacuna

Contributor and implementation authority remains separate from user guidance:

- [Development workflow](development/workflow.md)
- [Contributor setup](development/setup.md)
- [Testing](development/testing.md)
- [Developer troubleshooting](development/troubleshooting.md)
- [Release workflow](development/release.md)
- [Architecture overview](architecture/overview.md)
- [Plugin contracts](architecture/plugin-contracts.md)
- [Services and state](architecture/services-and-state.md)
- [Omarchy integration](architecture/omarchy-integration.md)
- [Compatibility ledger](architecture/quattro-compatibility.md)
- [Plugin inventory](plugins/README.md)

## Design Lacuna

- [Design-language entry point](lacuna-design-system/README.md)
- [Current UI reference captures](screenshots/reference/README.md)

The design system is an implementation contract. User feature guides explain
outcomes and controls rather than repeating its geometry internals.

## Project history and evidence

The following material is retained for maintainers but intentionally excluded
from the primary published navigation and search:

- [Roadmap](roadmap.md)
- [Issue map](issues.md)
- [Plan lifecycle index](plans/README.md)
- `benchmarks/`
- `project/historical/`
- `screenshots/reference/`

Plans belong only under `plans/active/`, `plans/proposed/`,
`plans/completed/`, or `plans/archive/`. Update `plans/README.md` whenever a
plan changes lifecycle.

## Documentation source boundaries

Current facts come from machine-readable or executable authorities wherever
possible: `VERSION`, `CHANGELOG.md`, `scripts/lacuna`,
`config/omakase-profile.json`, `config/quattro-compatibility.json`, and plugin
manifests. `VERSION` identifies the checkout; the first published heading in
`CHANGELOG.md` identifies the release described by user documentation when the
checkout is on a `.dev.0` version. User prose summarizes those sources; it must
not invent another version, command, plugin count, default, or support range.
