# Troubleshooting

Status: reference

## Plugin Does Not Appear

1. Confirm the plugin directory is under:

   ```text
   ~/.config/omarchy/plugins/<plugin-id>/
   ```

2. Confirm the plugin has a valid `manifest.json`.
3. Run:

   ```bash
   omarchy shell shell rescanPlugins
   omarchy plugin list
   ```

4. Restart shell if needed:

   ```bash
   omarchy restart shell
   ```

## Bar Widget Does Not Render

Confirm the widget is present in `bar.layout` and that its root exposes the
bar-widget injection properties:

- `bar`
- `moduleName`
- `settings`

Test script paths through `manifest.__sourceDir` or another plugin-relative
path. Do not depend on the repository root at runtime.

## Quickshell Live Tests Fail In A Sandbox

Quickshell live-load tests need access to the user runtime directory and
Wayland. In restricted sandboxes, they can fail with runtime-directory or
Wayland plugin errors even when the code is correct. Rerun `./scripts/check.sh`
in the real user session before treating those failures as product failures.

## Runtime Actions

Runtime actions inside Lacuna should call Omarchy commands, such as:

```bash
omarchy restart shell
```

Do not port standalone Lacuna process controls into plugins.
