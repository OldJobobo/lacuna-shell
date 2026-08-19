# Testing

Status: reference

The risk classes and Tier 0–3 evidence requirements are defined in the
[development workflow](workflow.md). Run the full local check before publishing
changes:

```bash
./scripts/check.sh
```

It validates:

- example JSON
- plugin manifests
- vendored-file equality
- the Python test suite
- optional `qmllint` checks when installed
- optional `shellcheck` checks when installed

Run Python tests directly with:

```bash
python3 -m pytest
```

Run docs contract tests with:

```bash
python3 -m pytest tests/test_docs_contracts.py
```

## Omarchy Smoke Tests

Deploy visible or stateful changes through the transactional developer helper,
which rescans, restarts, and verifies the installed files match the checkout:

```bash
./scripts/dev deploy <plugin-id>
./scripts/dev deploy --all --only-changed
```

Then smoke test loaded plugins with:

```bash
omarchy plugin list
OMARCHY_PATH="$HOME/.local/share/omarchy" omarchy-shell shell summon lacuna.menu "{}"
hyprctl layers
```

Confirm that each changed widget appears in Omarchy Settings, can be placed in
`bar.layout`, survives shell restart, and uses injected `bar`, `moduleName`,
and `settings` properties. Record exact Omarchy and Quickshell versions and any
journal errors with the pull-request evidence.

For the current Quattro core shell, run the read-only P0 smoke matrix from a
live session:

```bash
scripts/quattro-p0-smoke
```
