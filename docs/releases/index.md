# Release notes

Status: latest-release entry point

The repository [changelog](https://github.com/OldJobobo/lacuna-shell/blob/master/CHANGELOG.md)
is the canonical release history. GitHub Releases presents the same approved
release information alongside immutable artifacts.

## Current release

The current suite version is **0.1.0-beta.4**.

Beta.4 adds active-workspace-only mode, sidebar autohide refinements, universal
theme-aware frame and flyout corner geometry, the redesigned user documentation,
and a verified direct Arch package for use while the AUR is unavailable.

## Before upgrading

- Read every release entry between your version and the target.
- Check [Migration notes](migration-notes.md).
- Preview the update.
- Keep the installer-created backups until the new shell is verified.
- Recheck [Compatibility](../help/compatibility.md) after a host update.

## Release channels

- **Beta** proves supported product behavior and gathers field feedback.
- **RC** freezes product scope and accepts blocker fixes only.
- **Stable** promotes a verified RC lineage without feature additions.

All channels use the same `lacuna-shell` Arch package. Arch prerelease versions
remove the SemVer hyphen, so `0.1.0-beta.4` is packaged as
`0.1.0beta.4`.
