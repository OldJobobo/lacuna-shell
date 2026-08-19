# Development Setup

Status: reference

This repository is developed as an Omarchy plugin source. Work from the
repository root:

```bash
cd ~/Projects/lacuna-shell
```

Useful local commands:

```bash
rg --files
find . -maxdepth 2 -path './lacuna.*' -print
python3 -m pytest
./scripts/check.sh
```

For live testing, copy or symlink a plugin into the Omarchy plugin directory:

```text
~/.config/omarchy/plugins/<plugin-id>/
```

Then rescan:

```bash
omarchy shell shell rescanPlugins
```

No plugin should start a second Quickshell process.
