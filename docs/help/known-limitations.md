# Known limitations

Status: user-facing beta limitations

Lacuna `0.1.0-beta.5` is a public beta. The shell is usable and the lifecycle
tools are designed to protect user state, but the stable support boundary is
not frozen.

## Compatibility range

The project publishes an exact reviewed Omarchy/Quickshell pair rather than a
minimum supported range. A host update can expose an upstream contract change
before Lacuna's compatibility ledger is refreshed.

## Reset interruption boundary

Reset replaces each handled configuration file atomically. A sudden process or
power loss between replacing `shell.json` and `settings.json` can leave a
cross-file partial update. Installer backups and the reported recovery path are
the supported response.

## Optional services

Media, weather, usage, adaptive wallpaper contrast, and similar integrations
can depend on network access, local commands, authenticated tools, or provider
credentials. Their unavailability should not prevent the core shell from
loading, but it can leave an individual surface disabled or visibly
unavailable.

## Experimental plugin

The script-pill experiment is included in the supported installation inventory
but remains explicitly experimental. It executes a user-configured command;
install and configure it only when you trust that command and understand its
output.

## Deprecated migration component

`lacuna.compact-pill` is retained for migration compatibility, excluded from
the normal setup, and targeted for removal in `0.2.0`. Use the current bar-size
control instead.

## Documentation versioning

These docs track the latest release line. Fully versioned documentation is
planned after `1.0`; consult the changelog and migration notes when using an
older beta.
