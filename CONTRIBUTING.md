# Contributing to Lacuna

Lacuna is a suite of Omarchy shell (Quickshell/QML) plugins. Thanks for helping
improve it. This guide covers the workflow; deeper architecture and geometry
rules live in [`AGENTS.md`](AGENTS.md) and [`CLAUDE.md`](CLAUDE.md).

## Ground rules

- **One Quickshell process.** No plugin may start a second Quickshell instance.
- **Plugins are self-contained.** Never import across plugin directories or rely
  on the repo root as a runtime import path. The only sanctioned cross-plugin
  imports are those backed by a hard dependency declared in `lacuna.requires`
  (enforced by `tests/test_plugin_load_smoke.py`).
- **Prefer Omarchy-native services** for already-rich surfaces (audio, network,
  battery, tray…). `lacuna.script-pill` is the experiment path.
- **Shared templates are vendored.** Edit the canonical copy first (see
  `shared/qml/simple-bar/` and `lacuna.shell-settings/components/`), then run
  `scripts/sync-vendored --fix`. Divergent copies are declared per plugin via
  `manifest.lacuna.vendorExclude`.

## Development workflow

The canonical issue-to-release protocol, branch names, review order, risk
classes, and validation tiers live in
[`docs/development/workflow.md`](docs/development/workflow.md).

1. Start from current `master` and create a short-lived `fix/`, `feat/`,
   `refactor/`, `docs/`, `release/`, or `hotfix/` branch. Never commit directly
   to `master`.
2. Link behavioral, feature, state, installer, migration, packaging, and
   cross-plugin work to an issue. Keep the diff focused and match surrounding
   style.
3. Run targeted checks while iterating, then the full gate before review:

   ```bash
   python3 -m pytest tests/test_qml_contracts.py -k <name>
   qmllint path/to/Changed.qml
   ./scripts/check.sh
   ```

4. For visible or stateful changes, deploy the exact repository copy and record
   live evidence:

   ```bash
   ./scripts/dev deploy <plugin-id>
   # Or for cross-plugin work:
   ./scripts/dev deploy --all --only-changed
   ```

5. Open a pull request with exact test results, host versions, rollback notes,
   and screenshots when useful. Prefer squash merge and delete the branch.

Optional but recommended: `pip install pre-commit && pre-commit install` to run
ruff, shellcheck, vendored-parity, and pytest before each commit.

## Conventions

- 2-space indentation for QML and JSON.
- Plugin directories use full IDs (`lacuna.script-pill`).
- Runtime actions go through Omarchy commands (e.g. `omarchy restart shell`).
- Commits are concise and imperative (`Add script pill manifest`).
- Tests are stdlib `unittest` run via pytest. `tests/test_qml_contracts.py` is
  source-contract style — it asserts exact strings/structures, so renaming a
  covered symbol intentionally breaks tests. Update them in the same change.

## Adding a plugin

1. Create `lacuna.<name>/` at the repo root with a `manifest.json` declaring
   `kinds`, `entryPoints`, and a `lacuna` dependency block.
2. Add it to the relevant bundle/profile in `docs/plugins/README.md` and
   the installer (`scripts/lacuna`) if it belongs to a profile.
3. Vendor any shared helpers and run `scripts/sync-vendored --check`.
4. Add contract tests and ensure `./scripts/check.sh` is green.

## Releasing

Every beta, RC, stable, and patch release uses a `release/<version>` pull
request and the Tier 3 gate in the canonical workflow. Use
[`scripts/release-version`](scripts/release-version) to synchronize `VERSION`,
manifests, and Arch metadata, finalize `CHANGELOG.md`, run
`scripts/release-check`, and follow
[`docs/development/release.md`](docs/development/release.md). Never move a
published tag or replace a release artifact.
