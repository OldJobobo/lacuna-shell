# Lacuna Menu Panel Design Plan

## Direction

The Lacuna menu should behave like a control aperture: a carved command surface that opens from the bar, with a quiet interior, a distinctive seam, and clear command hierarchy.

## Plan

1. Define the panel model:
   - left edge: screen origin
   - right edge: carved seam
   - interior: quiet command surface
   - section groups: low-contrast signal bands
   - active view: seam tone and header indicator

2. Upgrade `MenuSurface.qml`:
   - base fill from the active theme
   - inner seam near the carved edge
   - subtle aperture glow while open
   - `openProgress`, `seamColor`, and `surfaceDepth` properties

3. Upgrade `MenuContent.qml`:
   - content opacity follows menu visibility
   - content shifts slightly into place
   - view changes crossfade or slide lightly

4. Upgrade `MenuRegistry.qml`:
   - add `layout`: `row`, `featured`, or `compact`
   - retain `tone` and `priority`
   - add optional `danger` and `group`

5. Upgrade `LacunaMenuItem.qml`:
   - `featured`: taller command slab, stronger rail, larger icon, visible hint
   - `primary`: strong row
   - `compact`: tighter secondary rows
   - `danger`: warning rail and stronger press state

6. Add `MenuSection.qml`:
   - section title
   - subtle top tick
   - optional background band for primary command groups
   - consistent spacing

7. Improve header:
   - glyph
   - current view title
   - theme/status subtitle
   - active seam indicator
   - shared icon buttons

8. Navigation feel:
   - shell remains stable
   - contents fade and shift on view changes
   - no tooltip behavior for menu or workspace controls

## Success Criteria

- Lacuna command is visually primary.
- Omarchy actions feel secondary but scannable.
- Session and power actions are distinct.
- The carved edge becomes a recognizable Lacuna signature.
- QML remains split into primitives, surface, content, registry, and row components.
