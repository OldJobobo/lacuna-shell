# Lacuna for Omarchy

A connected visual shell for Omarchy: a custom bar and full-screen frame, an
attached utility sidebar, focused controls, expressive widgets, media, and
optional desktop ambience—all inside the Omarchy shell you already use.

![Lacuna desktop with its connected bar, frame, sidebar, widgets, and desktop clock](docs/screenshots/readme/lacuna-desktop.webp)

> [!IMPORTANT]
> Lacuna is public beta software on the `0.1.0-beta.5` line. It is usable and
> transactionally installed, but the stable compatibility range is not yet
> frozen. Read the [known limitations](docs/help/known-limitations.md).

## One shell, connected at the seams

- **Bar, frame, and sidebar as one surface** rather than unrelated widgets.
- **Apps and system controls** for media, audio, network, Bluetooth, power,
  notifications, weather, workspaces, and common session actions.
- **Theme-native presentation**: Omarchy owns hue; Lacuna owns form, depth,
  seams, and reveal motion.
- **Customizable experience** through Lacuna Settings and Omarchy Settings.
- **Optional ambience** including grain, rain, aurora, CRT, VHS, light, and
  desktop-clock treatments.
- **Safe lifecycle commands** for preview, install, update, reset, recovery,
  and uninstall.

<table>
  <tr>
    <td><img src="docs/screenshots/readme/lacuna-appearance.webp" alt="Lacuna Appearance settings attached to the sidebar"></td>
    <td><img src="docs/screenshots/readme/lacuna-animations.webp" alt="Lacuna ordered desktop animation settings"></td>
  </tr>
  <tr>
    <td align="center"><strong>Appearance and frame controls</strong></td>
    <td align="center"><strong>Ordered desktop ambience</strong></td>
  </tr>
</table>

## Install

Lacuna's reviewed host pair is Omarchy `4.0.0.r1438.g9b693cc-1` with
Quickshell `0.3.0.r18.g10b439f-3`. Nearby versions may work but are not
promised; compare your host before installing or updating it. Install from the
AUR through Omarchy, then open the guided installer:

```bash
omarchy pkg aur add lacuna-shell
lacuna-shell
```

Choose **Full Lacuna install** for the canonical setup. Preview it without
changing your shell:

```bash
lacuna-shell install --dry-run
```

For the source-bootstrap alternative and complete safety notes, read
[Installation](docs/getting-started/installation.md).

## Start using Lacuna

- [Documentation home](docs/index.md)
- [Requirements and compatibility](docs/getting-started/requirements.md)
- [First-run tour](docs/getting-started/first-run.md)
- [Configuration ownership](docs/configuration/index.md)
- [Update](docs/getting-started/upgrading.md)
- [Troubleshooting and recovery](docs/help/troubleshooting.md)
- [Support and bug reports](docs/help/support.md)
- [Release notes](docs/releases/index.md)

## Project and development

Lacuna runs in Omarchy's single Quickshell process and follows Omarchy's plugin,
service, IPC, and shell-configuration contracts. Technical references remain
available without being part of the normal user journey:

- [Contributing](CONTRIBUTING.md)
- [design-system entry point](DESIGN.md)
- [Architecture overview](docs/architecture/overview.md)
- [Plugin catalog](docs/plugins/README.md)
- [Project roadmap](docs/roadmap.md)
- [Planning and historical ledger](docs/plans/README.md)
- [Changelog](CHANGELOG.md)

Before publishing a change, run:

```bash
./scripts/check.sh
```

## License

Lacuna is released under the [MIT License](LICENSE).
