# Lacuna Issue Map

Status: active issue tracker mirror

This file mirrors the intended organization of GitHub issues for
`OldJobobo/lacuna-shell`. GitHub remains the actionable tracker; this
file explains how the issues fit together.

## Labels

Use labels as a lightweight routing layer:

| Label | Meaning |
| --- | --- |
| `bug` | Behavior is broken, incomplete, or regressed. |
| `enhancement` | New capability or deliberate expansion. |
| `documentation` | Docs-only work. |
| `area:state` | Settings/state persistence, normalization, and migration. |
| `area:bar` | Bar host, slots, sizing, frame/bar layout, or visible bar behavior. |
| `area:tests` | Test coverage, regression harnesses, or validation tooling. |

## Milestones

### M1: State model stabilization

Purpose: stabilize the layout/settings state contract before expanding features.

Issues:

- [#4 Persist per-style bar layout settings in Lacuna settings state](https://github.com/OldJobobo/lacuna-shell/issues/4) — `area:state`
- [#5 Normalize per-style bar layout entries consistently across menu and state services](https://github.com/OldJobobo/lacuna-shell/issues/5) — `area:state`
- [#6 Preserve JSON-safe metadata on bar layout entries instead of dropping valid fields](https://github.com/OldJobobo/lacuna-shell/issues/6) — `area:state`
- [#7 Handle string-form bar layout entries consistently or reject them explicitly](https://github.com/OldJobobo/lacuna-shell/issues/7) — `area:state`
- [#8 Do not collapse active bar items solely because the loaded item reports visible false](https://github.com/OldJobobo/lacuna-shell/issues/8) — `area:bar`
- [#9 Add contract tests for bar slot measurement and settings normalization regressions](https://github.com/OldJobobo/lacuna-shell/issues/9) — `area:tests`, `area:state`, `area:bar`

Recommended implementation order:

1. #9 first or in parallel: pin expected contracts before behavior changes.
2. #4 and #5 together: define the canonical per-style settings shape.
3. #6 and #7 together: define entry-level normalization policy.
4. #8 after tests clarify bar slot measurement expectations.
5. Close #9 only after all contract tests for #4–#8 are present.

## Closed Historical Issues

Closed issues retained for context:

- [#1 Stabilize AI usage plugin widths and clean up Claude bar text](https://github.com/OldJobobo/lacuna-shell/issues/1)
- [#2 Make vignette follow the current frame size](https://github.com/OldJobobo/lacuna-shell/issues/2)
- [#3 Persist full sidebar layout setting instead of reverting to off](https://github.com/OldJobobo/lacuna-shell/issues/3)

## Issue Hygiene Rules

Follow the intake and triage protocol in
[`development/workflow.md`](development/workflow.md).

- Require an issue for behavioral bugs, features, state/schema changes,
  installer/migration/packaging work, release blockers, and cross-plugin
  refactors. Documentation typos and mechanical maintenance may go directly to
  a pull request.
- Every triaged issue records the affected plugin, acceptance criteria, change
  class, regression risk, required validation tier, live-verification need,
  target release, and rollback implications.
- Every open issue should have at least one area label once triaged.
- Milestones should represent deliverable slices, not vague themes.
- Keep implementation details in issue bodies or linked plans; keep this file as a map.
- When a repo plan graduates into actionable work, create issues and link the plan both ways.
- When an issue closes, update this file only if its closure changes the project roadmap.
