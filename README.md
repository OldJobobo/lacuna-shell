# Lacuna

Lacuna is a Quickshell bar experiment for Omarchy.

It borrows `omabar-v2`'s proven script contract and layout, then uses Lacuna as a quieter design influence: slim negative space, muted pauses between clusters, and less visual mass around the same information rhythm.

## Run

```bash
~/Projects/lacuna/run.sh
```

To stop the running instance:

```bash
quickshell kill -p ~/Projects/lacuna/shell.qml
```

## Current Scope

- top Quickshell `PanelWindow`
- per-screen rendering
- Omarchy button
- native Hyprland workspace state
- native Quickshell system tray drawer
- script-backed weather, Codex, Claude, update, idle, recording, voxtype, network, wifi, bluetooth, and power profile status
- native MPRIS media, PipeWire audio, UPower battery, clock, compact mode, theme, wallpaper, CPU, memory, and temperature status, with shared disk usage probing
- omabar-style audio click, right-click mute, and scroll volume controls through PipeWire
- persistent compact mode at `~/.local/state/omarchy/lacuna/compact.state`
- theme color loading from `~/.config/omarchy/current/theme/colors.toml`

## Design Notes

Lacuna keeps the `omabar-v2` idea of a slim status band with colored text modules. The Lacuna influence is restrained: the modules breathe a little more, the center cluster has small muted pauses, and active states are indicated by a quiet underline instead of heavy containers.

This first version favors stable parity while moving high-churn status into native Quickshell services where it helps. Weather, Claude, Codex, updates, idle, recording, voxtype, network, wifi, bluetooth, and power profile status remain script-backed, with Lacuna-local fallbacks for slow or unavailable helpers. Workspaces, MPRIS media, PipeWire audio, UPower battery, clock, theme, wallpaper, compact state, tray icons, and shared system stats are native enough to validate the shell.
