# Installation

Status: user guide for the latest beta

The packaged install is the recommended path. It gives the system package
manager ownership of Lacuna while the guided installer safely applies the shell
for your user.

## Install the package

The AUR is temporarily unavailable. Install the verified package attached to
the GitHub prerelease instead:

```bash
curl -fLO https://github.com/OldJobobo/lacuna-shell/releases/download/v0.1.0-beta.5/lacuna-shell-0.1.0beta.5-1-any.pkg.tar.zst
sudo pacman -U ./lacuna-shell-0.1.0beta.5-1-any.pkg.tar.zst
```

When the AUR is available again, the normal command is:

```bash
omarchy pkg aur add lacuna-shell
```

Then start the guided installer:

```bash
lacuna-shell
```

Choose **Full Lacuna install**. Before changing anything, the installer shows
what it will install and activate. It snapshots `shell.json` and Lacuna's
`settings.json`, stages and verifies the plugin set, applies the curated layout,
and reloads the shell.

The temporary direct package and future AUR updates use the same
`lacuna-shell` package identity, so pacman can upgrade it normally.

### Preview without changing the shell

```bash
lacuna-shell install --dry-run
```

A successful preview is useful when you want to see paths and planned changes
before opening the guided interface.

## Install from the source bootstrap

Use this when the AUR route is unavailable on your machine or you intentionally
want a source-managed installation:

```bash
( f="$(mktemp)" && trap 'rm -f "$f"' EXIT && curl -fsSL https://raw.githubusercontent.com/OldJobobo/lacuna-shell/refs/heads/master/install.sh -o "$f" && bash "$f" )
```

The bootstrap:

1. shows its dependency, source, checkout, and install plan;
2. asks for confirmation;
3. keeps a verified checkout under `~/.local/share/lacuna-shell` by default;
4. installs the normal full setup through the same transactional installer.

Rerunning the command refreshes that clean checkout. It refuses to overwrite a
checkout with local changes or an unexpected remote.

## Install from a clone

For development or deliberate source control:

```bash
git clone https://github.com/OldJobobo/lacuna-shell.git "$HOME/lacuna-shell"
cd "$HOME/lacuna-shell"
./scripts/lacuna
```

Choose **Full Lacuna install**. In source instructions, replace
`lacuna-shell` with `./scripts/lacuna`.

## Verify the installation

For a package install:

```bash
lacuna-shell status
```

For a source install:

```bash
./scripts/lacuna status
```

The report should show the host versions, healthy configuration, and the core
Lacuna plugins present and enabled. Continue with the [first-run tour](first-run.md).

If the installer stops or the shell does not return, use
[Troubleshooting](../help/troubleshooting.md) before rerunning commands blindly.

## Advanced selective installation

Lacuna supports profiles and individual plugins for development, recovery, and
specialized setups. They are intentionally not the normal onboarding path.
Inspect available choices with:

```bash
lacuna-shell install --help
```

Start with the complete setup unless you already understand Lacuna's plugin
dependencies and Omarchy activation model.
