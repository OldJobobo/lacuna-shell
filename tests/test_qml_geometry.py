from __future__ import annotations

import math
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def frame_geometry(
    *,
    width: int = 1920,
    height: int = 1080,
    active: bool,
    bar_position: str,
    bar_size: int,
    thickness: int,
    radius: int,
    left_occupied: int = 0,
    right_occupied: int = 0,
    top_occupied: bool = False,
    bottom_occupied: bool = False,
) -> dict[str, float]:
    t = max(1, thickness)
    r = max(t, radius)
    top_bar = bar_position == "top"
    bottom_bar = bar_position == "bottom"
    left_bar = bar_position == "left"
    right_bar = bar_position == "right"
    top_inset = max(0, bar_size) if top_bar or top_occupied else t
    bottom_inset = max(0, bar_size) if bottom_bar or bottom_occupied else t
    left_inset = max(0, bar_size) if left_bar else t
    right_inset = max(0, bar_size) if right_bar else t
    outer_x = max(0, bar_size) if left_bar else 0
    outer_y = max(0, bar_size) if top_bar or top_occupied else 0
    outer_right = max(outer_x + 1, width - max(0, bar_size)) if right_bar else width
    outer_bottom = max(outer_y + 1, height - max(0, bar_size)) if bottom_bar or bottom_occupied else height
    hole_x = max(0, left_occupied if left_occupied > 0 else left_inset)
    hole_y = max(0, top_inset)
    hole_right = max(hole_x + 1, width - (right_occupied if right_occupied > 0 else right_inset))
    hole_bottom = max(hole_y + 1, height - bottom_inset)
    hole_width = max(1, hole_right - hole_x)
    hole_height = max(1, hole_bottom - hole_y)
    hole_radius = max(0, min(r, hole_width / 2, hole_height / 2))
    is_renderable = active and width > 0 and height > 0 and hole_width > 0 and hole_height > 0
    caster_hole_x = hole_x if is_renderable else (max(0, bar_size) if left_bar else 0)
    caster_hole_y = hole_y if is_renderable else (max(0, bar_size) if top_bar or top_occupied else 0)
    caster_hole_right = (
        hole_right
        if is_renderable
        else (max(caster_hole_x + 1, width - max(0, bar_size)) if right_bar else width)
    )
    caster_hole_bottom = (
        hole_bottom
        if is_renderable
        else (max(caster_hole_y + 1, height - max(0, bar_size)) if bottom_bar or bottom_occupied else height)
    )
    return {
        "outerX": outer_x,
        "outerY": outer_y,
        "outerRight": outer_right,
        "outerBottom": outer_bottom,
        "holeX": hole_x,
        "holeY": hole_y,
        "holeRight": hole_right,
        "holeBottom": hole_bottom,
        "holeRadius": hole_radius,
        "casterHoleX": caster_hole_x,
        "casterHoleY": caster_hole_y,
        "casterHoleRight": caster_hole_right,
        "casterHoleBottom": caster_hole_bottom,
    }


def content_rect(
    *,
    screen_width: int,
    screen_height: int,
    frame_enabled: bool,
    position: str,
    bar_size: int,
    thickness: int,
    radius: int,
    corner_pieces: bool = True,
    sidebar_on_left: int = 0,
    sidebar_on_right: int = 0,
    companion_edge: str = "",
) -> dict[str, float | bool]:
    t = max(1, thickness)
    top_inset = max(0, bar_size) if position == "top" or companion_edge == "top" else t
    bottom_inset = max(0, bar_size) if position == "bottom" or companion_edge == "bottom" else t
    left_inset = max(0, bar_size) if position == "left" else t
    right_inset = max(0, bar_size) if position == "right" else t
    x = max(0, sidebar_on_left if sidebar_on_left > 0 else left_inset)
    y = max(0, top_inset)
    right = max(x + 1, screen_width - (sidebar_on_right if sidebar_on_right > 0 else right_inset))
    bottom = max(y + 1, screen_height - bottom_inset)
    bleed = max(t + 2, int((radius * 0.5) + 0.999999)) if frame_enabled else 0
    if not frame_enabled or screen_width <= 0 or screen_height <= 0:
        return {"x": 0, "y": 0, "width": max(1, screen_width), "height": max(1, screen_height), "framed": False}
    return {
        "x": max(0, x - bleed),
        "y": max(0, y - bleed),
        "width": max(1, min(screen_width, right + bleed) - max(0, x - bleed)),
        "height": max(1, min(screen_height, bottom + bleed) - max(0, y - bleed)),
        "radius": max(t, radius) if corner_pieces else 0,
        "bleed": bleed,
        "framed": True,
        "innerX": x,
        "innerY": y,
        "innerWidth": max(1, right - x),
        "innerHeight": max(1, bottom - y),
    }


def frame_border_geometry(
    *,
    width: int = 1920,
    height: int = 1080,
    bar_position: str = "top",
    bar_size: int = 32,
    thickness: int = 24,
    radius: int = 32,
    border_width: int = 2,
    left_occupied: int = 0,
    right_occupied: int = 0,
    attached_flyout_visible: bool = False,
    attached_flyout_y: int = 0,
    attached_flyout_height: int = 0,
) -> dict[str, float | bool]:
    base = frame_geometry(
        width=width,
        height=height,
        active=True,
        bar_position=bar_position,
        bar_size=bar_size,
        thickness=thickness,
        radius=radius,
        left_occupied=left_occupied,
        right_occupied=right_occupied,
    )
    border_inset = max(0, border_width / 2)
    border_top = base["holeY"] + border_inset
    border_bottom = base["holeBottom"] - border_inset
    border_radius = max(0, base["holeRadius"] - border_inset)
    left_gap_visible = left_occupied > 0 and attached_flyout_visible and attached_flyout_height > 0
    right_gap_visible = right_occupied > 0 and attached_flyout_visible and attached_flyout_height > 0
    gap_top = max(border_top + border_radius, attached_flyout_y + border_inset)
    gap_bottom = min(border_bottom - border_radius, attached_flyout_y + attached_flyout_height - border_inset)
    gap_renderable = gap_bottom > gap_top + border_width
    return {
        "leftAttachmentGapVisible": left_gap_visible,
        "rightAttachmentGapVisible": right_gap_visible,
        "attachmentGapTop": gap_top,
        "attachmentGapBottom": gap_bottom,
        "attachmentGapRenderable": gap_renderable,
        "rightVerticalUpperEndY": gap_top if right_gap_visible and gap_renderable else border_bottom - border_radius,
        "rightVerticalLowerStartY": gap_bottom if right_gap_visible and gap_renderable else border_bottom - border_radius,
        "leftVerticalLowerEndY": gap_bottom if left_gap_visible and gap_renderable else border_top + border_radius,
        "leftVerticalUpperStartY": gap_top if left_gap_visible and gap_renderable else border_top + border_radius,
    }


def clamped_popup_x(
    *,
    target_width: int,
    window_width: int,
    implicit_width: int,
    margin: int,
    join_radius: int,
    panel_width: int,
    shadow_margin: int = 0,
    target_window_x: int,
) -> int:
    local_x = target_width / 2 - (shadow_margin + join_radius + panel_width / 2)
    point_x = target_window_x + local_x
    return round(max(margin, min(point_x, window_width - implicit_width - margin)))


def interpolated_flyout_geometry(
    *,
    progress: float,
    from_y: float,
    from_width: float,
    from_height: float,
    from_connector_width: float,
    to_y: float,
    to_width: float,
    to_height: float,
    to_connector_width: float,
) -> dict[str, float]:
    p = max(0.0, min(1.0, progress))
    blend = lambda start, end: math.floor(start + (end - start) * p + 0.5)
    return {
        "y": blend(from_y, to_y),
        "width": blend(from_width, to_width),
        "height": blend(from_height, to_height),
        "connectorWidth": blend(from_connector_width, to_connector_width),
    }


def calendar_surface_geometry(edge: str, panel_width: int = 350, panel_height: int = 440, join_radius: int = 13) -> dict[str, int]:
    horizontal = edge in {"top", "bottom"}
    return {
        "width": panel_width + (join_radius * 2 if horizontal else join_radius),
        "height": panel_height + (join_radius if horizontal else join_radius * 2),
        "panelLeft": join_radius if edge in {"top", "bottom", "left"} else 0,
        "panelTop": join_radius if edge in {"top", "left", "right"} else 0,
    }


def calendar_shadow_margins(edge: str, blur_max: int = 28, offset_x: int = 2, offset_y: int = 3) -> dict[str, int]:
    margin = math.ceil(blur_max + max(abs(offset_x), abs(offset_y)))
    far_left = math.ceil(margin + blur_max * 0.6 + max(0, -offset_x))
    far_right = math.ceil(margin + blur_max * 0.6 + max(0, offset_x))
    far_top = math.ceil(margin + blur_max * 0.6 + max(0, -offset_y))
    far_bottom = math.ceil(margin + blur_max * 0.6 + max(0, offset_y))
    return {
        "left": 0 if edge == "left" else (far_left if edge == "right" else margin),
        "right": 0 if edge == "right" else (far_right if edge == "left" else margin),
        "top": 0 if edge == "top" else (far_top if edge == "bottom" else margin),
        "bottom": 0 if edge == "bottom" else (far_bottom if edge == "top" else margin),
    }


def frame_sidebar_occlusion(*, visible: bool, autohide: bool, width: int) -> int:
    return max(0, width) if visible and not autohide else 0


def autohide_visible_body_width(*, panel_width: int, surface_width: int, progress: float) -> float:
    surface_x = -surface_width * (1 - max(0.0, min(1.0, progress)))
    return max(0.0, panel_width + min(0.0, surface_x))


def frame_paint_bounds(*, width: int, outer_left: int, outer_right: int,
                       sidebar_left: float = 0, sidebar_right: float = 0) -> tuple[float, float]:
    return max(outer_left, sidebar_left), min(outer_right, width - sidebar_right)


def attached_flyout_shadow_exclusion(*, sidebar_edge: float, flyout_x: float,
                                     flyout_y: float, flyout_width: float,
                                     flyout_height: float, connector_width: float,
                                     connector_visible: bool) -> tuple[float, float, float, float]:
    top = flyout_y - connector_width if connector_visible else flyout_y
    height = flyout_height + connector_width * 2 if connector_visible else flyout_height
    return sidebar_edge, top, max(0, flyout_x + flyout_width - sidebar_edge), height


def sidebar_window_bar_geometry(
    *, screen_height: int, bar_position: str, bar_size: int, exclusive: bool, autohide: bool
) -> dict[str, int]:
    avoids_bar = exclusive or autohide
    top_inset = bar_size if bar_position == "top" and avoids_bar else 0
    bottom_inset = bar_size if bar_position == "bottom" and avoids_bar else 0
    window_height = max(0, screen_height - top_inset - bottom_inset)
    local_bar_bottom = bar_size if bar_position == "top" and top_inset == 0 else 0
    local_bottom_bar = bar_size if bar_position == "bottom" and bottom_inset == 0 else 0
    return {
        "topInset": top_inset,
        "bottomInset": bottom_inset,
        "barBottomY": local_bar_bottom,
        "hotZoneY": local_bar_bottom,
        "hotZoneHeight": max(0, window_height - local_bar_bottom - local_bottom_bar),
    }


class QmlGeometryTests(unittest.TestCase):
    def test_autohide_overlay_border_uses_sidebar_animation_clock(self):
        widths = [
            autohide_visible_body_width(panel_width=310, surface_width=324, progress=p)
            for p in (0, 0.25, 0.5, 0.75, 1)
        ]
        self.assertEqual([0, 67, 148, 229, 310], widths)
        self.assertEqual(sorted(widths), widths)

    def test_frame_paint_meets_live_sidebar_edge_without_overlap(self):
        visible_widths = [
            autohide_visible_body_width(panel_width=310, surface_width=324, progress=p)
            for p in (0, 0.25, 0.5, 0.75, 1)
        ]
        left_bounds = [
            frame_paint_bounds(width=2560, outer_left=0, outer_right=2560,
                               sidebar_left=visible)[0]
            for visible in visible_widths
        ]
        self.assertEqual(visible_widths, left_bounds)

        shadow_bounds = [
            frame_paint_bounds(width=2560, outer_left=0, outer_right=2560,
                               sidebar_left=visible + (14 if visible > 0 else 0))[0]
            for visible in visible_widths
        ]
        self.assertEqual([0, 81, 162, 243, 324], shadow_bounds)

    def test_attached_flyout_masks_complete_frame_shadow_envelope(self):
        with_connector = attached_flyout_shadow_exclusion(
            sidebar_edge=310, flyout_x=328, flyout_y=220,
            flyout_width=560, flyout_height=660, connector_width=18,
            connector_visible=True,
        )
        self.assertEqual((310, 202, 578, 696), with_connector)

        without_connector = attached_flyout_shadow_exclusion(
            sidebar_edge=310, flyout_x=310, flyout_y=220,
            flyout_width=560, flyout_height=660, connector_width=0,
            connector_visible=False,
        )
        self.assertEqual((310, 220, 560, 660), without_connector)

    def test_autohide_sidebar_does_not_reflow_frame_or_vignette_geometry(self):
        hidden = content_rect(
            screen_width=1920, screen_height=1080, frame_enabled=True,
            position="top", bar_size=32, thickness=8, radius=14,
            sidebar_on_left=frame_sidebar_occlusion(visible=False, autohide=True, width=310),
        )
        revealed = content_rect(
            screen_width=1920, screen_height=1080, frame_enabled=True,
            position="top", bar_size=32, thickness=8, radius=14,
            sidebar_on_left=frame_sidebar_occlusion(visible=True, autohide=True, width=310),
        )
        self.assertEqual(hidden, revealed)
        self.assertEqual(0, frame_sidebar_occlusion(visible=True, autohide=True, width=310))
        self.assertEqual(310, frame_sidebar_occlusion(visible=True, autohide=False, width=310))

    def test_autohide_sidebar_avoids_top_bar_without_double_offset(self):
        geometry = sidebar_window_bar_geometry(
            screen_height=1440, bar_position="top", bar_size=32,
            exclusive=False, autohide=True,
        )
        self.assertEqual(32, geometry["topInset"])
        self.assertEqual(0, geometry["barBottomY"])
        self.assertEqual(0, geometry["hotZoneY"])
        self.assertEqual(1408, geometry["hotZoneHeight"])

    def test_persistent_overlay_keeps_local_top_bar_offset(self):
        geometry = sidebar_window_bar_geometry(
            screen_height=1440, bar_position="top", bar_size=32,
            exclusive=False, autohide=False,
        )
        self.assertEqual(0, geometry["topInset"])
        self.assertEqual(32, geometry["barBottomY"])
        self.assertEqual(32, geometry["hotZoneY"])

    def test_autohide_sidebar_avoids_bottom_bar_without_double_subtraction(self):
        geometry = sidebar_window_bar_geometry(
            screen_height=1080, bar_position="bottom", bar_size=28,
            exclusive=False, autohide=True,
        )
        self.assertEqual(28, geometry["bottomInset"])
        self.assertEqual(1052, geometry["hotZoneHeight"])

    def test_calendar_surface_orients_attachment_and_reveal_on_all_bar_edges(self):
        surface = read("lacuna.clock/BarFlyoutSurface.qml")
        flyout = read("lacuna.clock/CalendarFlyout.qml")

        self.assertEqual(
            {"width": 376, "height": 453, "panelLeft": 13, "panelTop": 13},
            calendar_surface_geometry("top"),
        )
        self.assertEqual(
            {"width": 376, "height": 453, "panelLeft": 13, "panelTop": 0},
            calendar_surface_geometry("bottom"),
        )
        self.assertEqual(
            {"width": 363, "height": 466, "panelLeft": 13, "panelTop": 13},
            calendar_surface_geometry("left"),
        )
        self.assertEqual(
            {"width": 363, "height": 466, "panelLeft": 0, "panelTop": 13},
            calendar_surface_geometry("right"),
        )

        for edge in ("top", "bottom", "left", "right"):
            self.assertIn(f'visible: root.attachmentEdge === "{edge}"', surface)
        self.assertEqual(4, surface.count("strokeWidth: 0"))
        self.assertNotIn("radius:", surface)
        self.assertIn("readonly property real curveKappa: lacunaGeometry.curveKappa", surface)
        self.assertIn('x: root.attachmentEdge === "right" ? root.implicitWidth - width : 0', flyout)
        self.assertIn('y: root.attachmentEdge === "bottom" ? root.implicitHeight - height : 0', flyout)
        self.assertIn("point.x = surface.constrainedHorizontalPopupX(", flyout)
        self.assertIn("point.y = Math.max(root.margin", flyout)

    def test_calendar_shadow_padding_stays_off_the_attached_edge(self):
        flyout = read("lacuna.clock/CalendarFlyout.qml")

        self.assertEqual({"left": 31, "right": 31, "top": 0, "bottom": 51}, calendar_shadow_margins("top"))
        self.assertEqual({"left": 31, "right": 31, "top": 48, "bottom": 0}, calendar_shadow_margins("bottom"))
        self.assertEqual({"left": 0, "right": 50, "top": 31, "bottom": 31}, calendar_shadow_margins("left"))
        self.assertEqual({"left": 48, "right": 0, "top": 31, "bottom": 31}, calendar_shadow_margins("right"))
        self.assertIn('readonly property int shadowLeftMargin: attachmentEdge === "left"', flyout)
        self.assertIn('readonly property int shadowRightMargin: attachmentEdge === "right"', flyout)
        self.assertIn('readonly property int shadowTopMargin: attachmentEdge === "top"', flyout)
        self.assertIn('readonly property int shadowBottomMargin: attachmentEdge === "bottom"', flyout)
        self.assertIn("implicitWidth: surface.fullWidth + shadowLeftMargin + shadowRightMargin", flyout)
        self.assertIn("implicitHeight: surface.fullHeight + shadowTopMargin + shadowBottomMargin", flyout)

    def test_weather_surface_and_shadow_follow_all_bar_edges(self):
        surface = read("lacuna.weather/BarFlyoutSurface.qml")
        flyout = read("lacuna.weather/WeatherFlyout.qml")

        self.assertEqual(
            {"width": 456, "height": 393, "panelLeft": 13, "panelTop": 13},
            calendar_surface_geometry("top", 430, 380),
        )
        self.assertEqual(
            {"width": 456, "height": 393, "panelLeft": 13, "panelTop": 0},
            calendar_surface_geometry("bottom", 430, 380),
        )
        self.assertEqual(
            {"width": 443, "height": 406, "panelLeft": 13, "panelTop": 13},
            calendar_surface_geometry("left", 430, 380),
        )
        self.assertEqual(
            {"width": 443, "height": 406, "panelLeft": 0, "panelTop": 13},
            calendar_surface_geometry("right", 430, 380),
        )
        for edge in ("top", "bottom", "left", "right"):
            self.assertIn(f'visible: root.attachmentEdge === "{edge}"', surface)
        self.assertEqual(4, surface.count("strokeWidth: 0"))
        self.assertNotIn("radius:", surface)
        self.assertIn("readonly property real curveKappa: lacunaGeometry.curveKappa", surface)
        self.assertIn('x: root.attachmentEdge === "right" ? root.implicitWidth - width : 0', flyout)
        self.assertIn('y: root.attachmentEdge === "bottom" ? root.implicitHeight - height : 0', flyout)
        self.assertIn("point.x = surface.constrainedHorizontalPopupX(", flyout)
        self.assertIn("point.y = Math.max(root.margin", flyout)

        self.assertEqual({"left": 31, "right": 31, "top": 0, "bottom": 51}, calendar_shadow_margins("top"))
        self.assertEqual({"left": 31, "right": 31, "top": 48, "bottom": 0}, calendar_shadow_margins("bottom"))
        self.assertEqual({"left": 0, "right": 50, "top": 31, "bottom": 31}, calendar_shadow_margins("left"))
        self.assertEqual({"left": 48, "right": 0, "top": 31, "bottom": 31}, calendar_shadow_margins("right"))
        self.assertIn('readonly property int shadowLeftMargin: attachmentEdge === "left"', flyout)
        self.assertIn('readonly property int shadowRightMargin: attachmentEdge === "right"', flyout)
        self.assertIn('readonly property int shadowTopMargin: attachmentEdge === "top"', flyout)
        self.assertIn('readonly property int shadowBottomMargin: attachmentEdge === "bottom"', flyout)

    def test_panel_host_switch_geometry_uses_one_interpolated_set(self):
        host = read("lacuna.menu/menu/LacunaPanelHost.qml")
        self.assertIn("readonly property var requestedPanelGeometry", host)
        self.assertIn("property var fromPanelGeometry", host)
        self.assertIn("property var targetPanelGeometry", host)
        self.assertIn("readonly property var effectivePanelGeometry", host)
        self.assertIn("function requestPanelGeometry(geometry, key)", host)
        self.assertIn("var current = copyPanelGeometry(effectivePanelGeometry)", host)
        self.assertIn("function pixelSnap(value)", host)
        self.assertIn("connectorWidth: pixelSnap(interpolateValue", host)
        self.assertIn("connectorOverlap: pixelSnap(interpolateValue", host)
        self.assertIn("panelRadius: pixelSnap(interpolateValue", host)
        self.assertIn("readonly property real effectivePanelRadius", host)
        self.assertIn("readonly property bool effectiveConnectorVisible", host)
        self.assertIn("effectiveConnectorWidth > connectorEpsilon", host)
        self.assertIn("readonly property real flyoutMaskWidth: flyoutRenderable ? flyoutCurrentWidth : 0", host)
        self.assertIn("readonly property real connectorMaskWidth: flyoutRenderable && effectiveConnectorVisible", host)
        self.assertIn("readonly property real connectorMaskHeight: flyoutRenderable && effectiveConnectorVisible", host)

        start = interpolated_flyout_geometry(
            progress=0, from_y=80, from_width=560, from_height=620, from_connector_width=18,
            to_y=160, to_width=420, to_height=440, to_connector_width=0,
        )
        middle = interpolated_flyout_geometry(
            progress=0.5, from_y=80, from_width=560, from_height=620, from_connector_width=18,
            to_y=160, to_width=420, to_height=440, to_connector_width=0,
        )
        end = interpolated_flyout_geometry(
            progress=1, from_y=80, from_width=560, from_height=620, from_connector_width=18,
            to_y=160, to_width=420, to_height=440, to_connector_width=0,
        )
        self.assertEqual(start, {"y": 80, "width": 560, "height": 620, "connectorWidth": 18})
        self.assertEqual(middle, {"y": 120, "width": 490, "height": 530, "connectorWidth": 9})
        self.assertEqual(end, {"y": 160, "width": 420, "height": 440, "connectorWidth": 0})

        # A newest-wins C request captures the currently painted A->B shape,
        # rather than restarting from stale A or jumping to B.
        interrupted = interpolated_flyout_geometry(
            progress=0.4, from_y=80, from_width=560, from_height=620, from_connector_width=18,
            to_y=160, to_width=420, to_height=440, to_connector_width=0,
        )
        newest_mid = interpolated_flyout_geometry(
            progress=0.5,
            from_y=interrupted["y"], from_width=interrupted["width"],
            from_height=interrupted["height"], from_connector_width=interrupted["connectorWidth"],
            to_y=40, to_width=600, to_height=500, to_connector_width=18,
        )
        self.assertEqual(interrupted, {"y": 112, "width": 504, "height": 548, "connectorWidth": 11})
        self.assertEqual(newest_mid, {"y": 76, "width": 552, "height": 524, "connectorWidth": 15})

        menu = read("lacuna.menu/menu/MenuWindow.qml")
        for binding in (
            "surfaceRightInset: Math.max(panelHost.effectiveConnectorWidth, root.frameMoldingPieces ? root.frameRadius : 0)",
            "sidebarMoldingWidth: root.frameMoldingPieces ? root.frameRadius : 0",
            "connectorWidth: panelHost.effectiveConnectorWidth",
            "x: panelHost.connectorX",
            "openX: panelHost.flyoutX",
            "connectorMaskWidth: panelHost.connectorMaskWidth",
            "flyoutMaskWidth: panelHost.flyoutMaskWidth",
            "panelRadius: panelHost.effectivePanelRadius",
        ):
            self.assertIn(binding, menu)
        self.assertEqual(3, menu.count("panelRadius: panelHost.effectivePanelRadius"))
        self.assertIn("function maxFlyoutExtentFor(screen)", menu)
        self.assertIn("flyoutGeometryFor(screen, kinds[i], 0).width", menu)
        self.assertIn("connectorWidth + flyoutGeometryFor(screen, kinds[i], connectorWidth).width", menu)
        self.assertIn("- Math.max(0, Number(effectiveConnectorWidth) || 0)", menu)

        # Reserve the larger endpoint plus one pixel because independently
        # snapped odd connector/flyout widths can exceed both endpoint sums.
        js_round = lambda value: math.floor(value + 0.5)
        for off_width, on_width, connector in (
            (560, 560, 18),
            (432, 414, 18),
            (432, 417, 15),
            (432, 415, 17),
        ):
            reserved = max(off_width, connector + on_width) + 1
            for progress in (0, 0.25, 0.5, 0.75, 1):
                effective_flyout = js_round(off_width + (on_width - off_width) * progress)
                effective_connector = js_round(connector * progress)
                self.assertLessEqual(effective_flyout + effective_connector, reserved)
                lane = reserved - effective_connector
                self.assertEqual(reserved, effective_connector + lane)

    def test_theme_aware_corner_policy_feeds_frame_and_attached_surfaces(self):
        bar = read("lacuna.bar/Bar.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")
        tokens = read("lacuna.menu/services/DesignTokens.qml")
        adapter = read("lacuna.bar/OmarchyBarAdapter.qml")
        omarchy_bar = read("lacuna.bar/OmarchyBar.qml")
        panel_border = read("lacuna.menu/menu/LacunaPanelBorder.qml")
        frame_border = read("lacuna.bar/LacunaFrameBorderWindow.qml")
        overlay = read("lacuna.menu/menu/LacunaFrameOverlay.qml")

        for host in (bar, window):
            self.assertIn('cornerMode === "square" ? 0', host)
            self.assertIn('cornerMode === "custom" ? customCornerRadius : Math.max(0, Math.round(Style.cornerRadius))', host)
            self.assertIn("readonly property int frameRadius: resolvedCornerRadius", host)
            self.assertNotIn("numberSetting(frameSettings.radius, 14)", host)

        self.assertIn("exposedCornerRadius: root.resolvedCornerRadius", window)
        self.assertIn("resolvedCornerRadius: root.resolvedCornerRadius", bar)
        self.assertIn("property int resolvedCornerRadius: 0", adapter)
        self.assertIn("resolvedCornerRadius: root.resolvedCornerRadius", adapter)
        self.assertIn("readonly property int resolvedCornerRadius: root.resolvedCornerRadius", omarchy_bar)
        self.assertIn("fullFrameEnabled: root.frameEnabled", bar)
        self.assertIn("readonly property int attachedFlyoutRadius: designTokens.panelRadius", window)
        self.assertIn("readonly property int lacunaJoinRadius: designTokens.joinRadius", window)
        self.assertIn("property real exposedCornerRadius: -1", tokens)
        self.assertIn("? Math.max(0, Math.round(exposedCornerRadius))", tokens)
        self.assertIn("readonly property int joinRadius: panelRadius", tokens)
        self.assertIn("readonly property real strokeRadius: Math.max(0,", panel_border)
        self.assertIn("joinStyle: ShapePath.MiterJoin", panel_border)
        self.assertIn("readonly property real borderRadius: Math.max(0, holeRadius - borderInset)", frame_border)
        self.assertIn("strokeWidth: root.borderRadius > 0 ? root.moldingBorderWidth : 0", frame_border)
        self.assertIn("strokeWidth: root.borderRadius > 0 ? root.moldingBorderWidth : 0", overlay)
        self.assertIn(": (moldingPieces ? moldingSize : 0)", overlay)
        frame_window = read("lacuna.bar/LacunaFrameWindow.qml")
        self.assertIn("readonly property real minArcRadius: 0", frame_window)
        self.assertIn("? Math.max(0, Math.min(shadowRecordRadius", frame_window)
        self.assertIn("shadowGeometryRecord: root.lacunaFrameGeometryRecord(modelData)", bar)

    def test_universal_corner_radius_owns_frame_and_connector_molding(self):
        bar = read("lacuna.bar/Bar.qml")
        window = read("lacuna.menu/menu/MenuWindow.qml")
        settings = read("lacuna.menu/settings/SettingsWindow.qml")
        overlay = read("lacuna.menu/menu/LacunaFrameOverlay.qml")
        surface = read("lacuna.menu/menu/MenuSurface.qml")
        self.assertIn("readonly property bool frameMoldingPieces: resolvedCornerRadius > 0", bar)
        self.assertIn("readonly property bool universalMoldingEnabled: resolvedCornerRadius > 0", window)
        self.assertIn("readonly property bool effectiveConnectorPieces: sidebarSurfaceVisible && universalMoldingEnabled && !panelOnRight", window)
        self.assertIn("readonly property bool frameMoldingPieces: universalMoldingEnabled", window)
        self.assertNotIn("sidebarState.connectorPieces && !panelOnRight", window)
        self.assertNotIn('"Sidebar Connectors"', settings)
        self.assertNotIn('"Frame Molding Pieces"', settings)
        self.assertNotIn('entry.action === "toggle-sidebar-connectors"', window)
        self.assertNotIn('entry.action === "toggle-frame-molding-pieces"', window)
        self.assertIn("moldingPieces: root.frameMoldingPieces", window)
        self.assertIn("sidebarMoldingVisible: menuWindow.sidebarRenderable && root.frameMoldingPieces", window)
        self.assertIn("frameMoldingPieces: root.frameMoldingPieces", window)
        self.assertIn("property bool moldingPieces: true", overlay)
        self.assertIn("property bool sidebarMoldingVisible: false", overlay)
        self.assertIn("property bool frameMoldingPieces: true", surface)
        self.assertNotIn("sidebarMoldingVisible: menuWindow.sidebarRenderable && panelHost.effectiveConnectorVisible", window)
        self.assertNotIn("frameMoldingPieces: panelHost.effectiveConnectorVisible", window)

        # The top bar rail terminates at the sidebar molding tangent. Opening a
        # wider flyout connector lower on that edge must not move the tangent.
        self.assertNotIn("surfaceInset = Math.max(surfaceInset, Number(panelGeometry.connectorWidth || 0))", bar)
        panel_width = 340
        frame_radius = 14
        expected_tangent = panel_width + frame_radius - 1
        self.assertEqual(expected_tangent, 353)
        for connector_width in (0, 14, 18, 32):
            top_tangent = panel_width + frame_radius - 1
            self.assertEqual(top_tangent, expected_tangent, connector_width)
        self.assertNotEqual(panel_width + max(frame_radius, 18) - 1, expected_tangent)

    def test_bar_frame_geometry_transaction_is_newest_wins_and_per_output(self):
        bar = read("lacuna.bar/Bar.qml")
        for contract in (
            "readonly property string requestedFrameGeometryKey",
            "property var fromFrameGeometrySnapshot",
            "property var targetFrameGeometrySnapshot",
            "readonly property var effectiveFrameGeometrySnapshot",
            "property int lacunaFrameGeometryRevision",
            "function selectedOutputGeometrySignature()",
            "values.sort()",
            "function requestFrameGeometrySnapshot()",
            "var current = copyFrameGeometrySnapshot(effectiveFrameGeometrySnapshot)",
            "frameGeometryAnimation.restart()",
            "function commitFrameGeometrySnapshot()",
            "onReducedMotionChanged: if (reducedMotion) commitFrameGeometrySnapshot()",
            "function lacunaFrameGeometryRecord(screen)",
            "function lacunaTargetFrameGeometryRecord(screen)",
            "geometryRecord: root.lacunaFrameGeometryRecord(modelData)",
            "shadowGeometryRecord: root.lacunaFrameGeometryRecord(modelData)",
            "revision: root.lacunaFrameGeometryRevision",
        ):
            self.assertIn(contract, bar)

        def blend(start: dict[str, int], target: dict[str, int], progress: float) -> dict[str, int]:
            return {key: math.floor(start[key] + (target[key] - start[key]) * progress + 0.5)
                    for key in start}

        initial = {"holeX": 8, "holeY": 32, "holeRight": 1912, "radius": 14}
        target = {"holeX": 310, "holeY": 32, "holeRight": 1912, "radius": 0}
        midpoint = blend(initial, target, 0.5)
        self.assertEqual({"holeX": 159, "holeY": 32, "holeRight": 1912, "radius": 7}, midpoint)
        newest_target = {"holeX": 270, "holeY": 40, "holeRight": 1900, "radius": 18}
        newest_midpoint = blend(midpoint, newest_target, 0.5)
        self.assertEqual({"holeX": 215, "holeY": 36, "holeRight": 1906, "radius": 13}, newest_midpoint)

    def test_frame_geometry_never_paints_under_owning_bar_or_sidebar_edge(self):
        frame = read("lacuna.bar/LacunaFrameWindow.qml")
        self.assertIn("readonly property real outerY: hasGeometryRecord ? Number(geometryRecord.outerY || 0)", frame)
        self.assertIn("readonly property real outerX: hasGeometryRecord ? Number(geometryRecord.outerX || 0)", frame)
        self.assertIn("id: shadowClip", frame)
        self.assertIn("id: framePaintClip", frame)
        self.assertIn("readonly property real paintLeft: Math.max(outerX, Math.max(0, paintOcclusionLeft))", frame)
        self.assertIn("readonly property real paintRight: Math.min(outerRight, width - Math.max(0, paintOcclusionRight))", frame)
        self.assertIn("readonly property real shadowPaintLeft: Math.max(outerX, Math.max(0, shadowOcclusionLeft))", frame)
        self.assertIn("readonly property real shadowPaintRight: Math.min(outerRight, width - Math.max(0, shadowOcclusionRight))", frame)
        self.assertIn("x: root.paintLeft", frame)
        self.assertIn("x: root.shadowPaintLeft", frame)
        self.assertIn("y: root.outerY", frame)
        self.assertGreaterEqual(frame.count("clip: true"), 2)
        self.assertIn("property var shadowGeometryRecord: null", frame)
        self.assertIn("readonly property bool shadowFrameRenderable:", frame)
        self.assertIn("readonly property real shadowRecordHoleX: hasShadowGeometryRecord ? Number(shadowGeometryRecord.holeX || 0) : holeX", frame)

        for position in ("top", "bottom", "left", "right"):
            g = frame_geometry(active=True, bar_position=position, bar_size=32, thickness=8, radius=14)
            if position == "top":
                self.assertEqual(g["outerY"], 32)
                self.assertEqual(g["holeY"], 32)
            if position == "bottom":
                self.assertEqual(g["outerBottom"], 1048)
                self.assertEqual(g["holeBottom"], 1048)
            if position == "left":
                self.assertEqual(g["outerX"], 32)
                self.assertEqual(g["holeX"], 32)
            if position == "right":
                self.assertEqual(g["outerRight"], 1888)
                self.assertEqual(g["holeRight"], 1888)

    def test_portrait_companion_occupies_both_horizontal_frame_edges(self):
        top_primary = frame_geometry(
            active=True, bar_position="top", bar_size=32, thickness=8, radius=14, bottom_occupied=True
        )
        bottom_primary = frame_geometry(
            active=True, bar_position="bottom", bar_size=32, thickness=8, radius=14, top_occupied=True
        )
        for geometry in (top_primary, bottom_primary):
            self.assertEqual(geometry["outerY"], 32)
            self.assertEqual(geometry["outerBottom"], 1048)
            self.assertEqual(geometry["holeY"], 32)
            self.assertEqual(geometry["holeBottom"], 1048)

        rect = content_rect(
            screen_width=1080,
            screen_height=1920,
            frame_enabled=True,
            position="top",
            companion_edge="bottom",
            bar_size=32,
            thickness=8,
            radius=14,
        )
        self.assertEqual(rect["innerY"], 32)
        self.assertEqual(rect["innerHeight"], 1856)

    def test_frame_shadow_caster_collapses_to_bar_edge_when_frame_off(self):
        for position in ("top", "bottom", "left", "right"):
            g = frame_geometry(active=False, bar_position=position, bar_size=32, thickness=8, radius=14)
            if position == "top":
                self.assertEqual(g["casterHoleY"], 32)
                self.assertEqual(g["casterHoleX"], 0)
                self.assertEqual(g["casterHoleRight"], 1920)
            elif position == "bottom":
                self.assertEqual(g["casterHoleBottom"], 1048)
            elif position == "left":
                self.assertEqual(g["casterHoleX"], 32)
                self.assertEqual(g["casterHoleBottom"], 1080)
            elif position == "right":
                self.assertEqual(g["casterHoleRight"], 1888)

    def test_frame_shadow_caster_matches_paint_hole_when_frame_on(self):
        g = frame_geometry(
            active=True,
            bar_position="top",
            bar_size=32,
            thickness=24,
            radius=32,
            left_occupied=248,
        )
        self.assertEqual(g["casterHoleX"], g["holeX"])
        self.assertEqual(g["casterHoleY"], g["holeY"])
        self.assertEqual(g["casterHoleRight"], g["holeRight"])
        self.assertEqual(g["casterHoleBottom"], g["holeBottom"])
        self.assertEqual(g["holeX"], 248)

    def test_lacuna_frame_content_rect_accounts_for_bleed_and_sidebar_occlusion(self):
        bar = read("lacuna.bar/Bar.qml")
        self.assertIn("function lacunaFrameContentRect(screen)", bar)
        self.assertIn("hostedSidebarFrameOcclusionWidth", bar)

        unframed = content_rect(
            screen_width=1920,
            screen_height=1080,
            frame_enabled=False,
            position="top",
            bar_size=32,
            thickness=24,
            radius=32,
        )
        self.assertFalse(unframed["framed"])
        self.assertEqual(unframed["width"], 1920)
        framed = content_rect(
            screen_width=1920,
            screen_height=1080,
            frame_enabled=True,
            position="top",
            bar_size=32,
            thickness=24,
            radius=32,
            sidebar_on_left=248,
        )
        self.assertTrue(framed["framed"])
        self.assertEqual(framed["innerX"], 248)
        self.assertEqual(framed["innerY"], 32)
        self.assertEqual(framed["bleed"], 26)
        self.assertEqual(framed["x"], 222)
        self.assertEqual(framed["y"], 6)

    def test_multi_monitor_matrix_keeps_sidebar_occlusion_on_selected_output(self):
        outputs = [
            {"name": "DP-1", "width": 2560, "height": 1440, "transform": 0},
            {"name": "DP-2", "width": 1920, "height": 1080, "transform": 0},
            {"name": "DP-3", "width": 2560, "height": 1440, "transform": 1},
        ]

        for focused_name in ("DP-1", "DP-3"):
            for output in outputs:
                selected = output["name"] == focused_name
                geometry = content_rect(
                    screen_width=output["width"],
                    screen_height=output["height"],
                    frame_enabled=True,
                    position="top",
                    bar_size=32,
                    thickness=8,
                    radius=14,
                    sidebar_on_left=310 if selected else 0,
                )

                self.assertTrue(geometry["framed"], output["name"])
                self.assertEqual(310 if selected else 8, geometry["innerX"], output["name"])
                self.assertGreater(geometry["innerWidth"], 0, output["name"])
                self.assertGreater(geometry["innerHeight"], 0, output["name"])

    def test_frame_border_attachment_gap_only_when_flyout_attached_and_renderable(self):
        border = read("lacuna.bar/LacunaFrameBorderWindow.qml")
        self.assertIn("readonly property bool leftAttachmentGapVisible", border)
        self.assertIn("readonly property bool rightAttachmentGapVisible", border)
        self.assertIn("readonly property bool attachmentGapRenderable", border)
        self.assertIn("PathMove", border)

        closed = frame_border_geometry(left_occupied=248, attached_flyout_visible=False)
        self.assertFalse(closed["leftAttachmentGapVisible"])
        self.assertFalse(closed["attachmentGapRenderable"])

        too_short = frame_border_geometry(
            left_occupied=248,
            attached_flyout_visible=True,
            attached_flyout_y=40,
            attached_flyout_height=2,
        )
        self.assertTrue(too_short["leftAttachmentGapVisible"])
        self.assertFalse(too_short["attachmentGapRenderable"])

        attached = frame_border_geometry(
            right_occupied=248,
            attached_flyout_visible=True,
            attached_flyout_y=180,
            attached_flyout_height=360,
        )
        self.assertTrue(attached["rightAttachmentGapVisible"])
        self.assertTrue(attached["attachmentGapRenderable"])
        self.assertEqual(attached["rightVerticalUpperEndY"], attached["attachmentGapTop"])
        self.assertEqual(attached["rightVerticalLowerStartY"], attached["attachmentGapBottom"])

    def test_notification_and_usage_popup_x_positions_are_clamped_to_window(self):
        notifications = read("lacuna.notifications/NotificationsFlyout.qml")
        claude = read("lacuna.claude-usage/ClaudeUsageFlyout.qml")
        codex = read("lacuna.codex-usage/CodexUsageFlyout.qml")
        for text in (notifications, claude, codex):
            self.assertIn("point.x = surface.constrainedHorizontalPopupX(", text)
            self.assertIn("point.y = Math.max(root.margin, Math.min(point.y, root.anchorWindow.height - root.implicitHeight - root.margin))", text)
            self.assertIn("popupAnchor.rect.x = Math.round(point.x)", text)

        self.assertEqual(
            clamped_popup_x(
                target_width=32,
                window_width=800,
                implicit_width=420,
                margin=8,
                join_radius=13,
                panel_width=420,
                target_window_x=4,
            ),
            8,
        )
        self.assertEqual(
            clamped_popup_x(
                target_width=32,
                window_width=800,
                implicit_width=420,
                margin=8,
                join_radius=13,
                panel_width=420,
                target_window_x=760,
            ),
            372,
        )
        self.assertEqual(
            clamped_popup_x(
                target_width=32,
                window_width=1000,
                implicit_width=360,
                margin=8,
                join_radius=13,
                panel_width=292,
                shadow_margin=36,
                target_window_x=500,
            ),
            321,
        )

    def test_all_rich_bar_flyouts_support_four_attachment_edges(self):
        inventory = {
            "audio": "AudioFlyout.qml",
            "bluetooth": "BluetoothFlyout.qml",
            "network": "NetworkFlyout.qml",
            "power": "PowerFlyout.qml",
            "notifications": "NotificationsFlyout.qml",
            "claude-usage": "ClaudeUsageFlyout.qml",
            "codex-usage": "CodexUsageFlyout.qml",
            "system-stats": "TelemetryFlyout.qml",
            "temperature": "ThermalFlyout.qml",
            "theme": "ThemeFlyout.qml",
            "wallpaper": "WallpaperFlyout.qml",
            "clock": "CalendarFlyout.qml",
            "weather": "WeatherFlyout.qml",
        }
        canonical_surface = read("lacuna.clock/BarFlyoutSurface.qml")
        for plugin, flyout_name in inventory.items():
            with self.subTest(plugin=plugin):
                surface = read(f"lacuna.{plugin}/BarFlyoutSurface.qml")
                flyout = read(f"lacuna.{plugin}/{flyout_name}")
                self.assertEqual(canonical_surface, surface)
                self.assertIn('property string attachmentEdge: "top"', surface)
                for edge in ("top", "bottom", "left", "right"):
                    self.assertIn(f'visible: root.attachmentEdge === "{edge}"', surface)
                self.assertGreaterEqual(surface.count("strokeWidth: 0"), 4)
                self.assertEqual(4, surface.count("strokeWidth: root.borderWidth"))
                self.assertEqual(4, surface.count("visible: root.borderEnabled && root.attachmentEdge"))
                self.assertEqual(4, surface.count("asynchronous: false"))
                self.assertEqual(4, surface.count("antialiasing: true"))
                self.assertIn("property bool borderEnabled: bar && bar.frameBorderEnabled === true", surface)
                self.assertIn("property color borderColor: bar && bar.frameBorderColor", surface)
                self.assertIn("readonly property int attachmentOverlap: bar && bar.fullFrameEnabled === true ? 0 : 1", surface)
                self.assertIn("readonly property real borderGapLength: horizontalAttachment", surface)
                self.assertIn("readonly property real strokeCornerRadius: Math.max(0, cornerRadius - borderInset)", surface)
                self.assertNotIn("Math.max(0.01", surface)
                self.assertEqual(4, surface.count("joinStyle: ShapePath.MiterJoin"))
                self.assertIn("bar && bar.resolvedCornerRadius !== undefined", flyout)
                self.assertIn("property int cornerRadius: joinRadius", flyout)
                self.assertEqual(flyout.count("BarFlyoutSurface {"), flyout.count("cornerRadius: root.cornerRadius"))
                self.assertIn("? Math.max(0, fullWidth - 1) : Math.max(0, fullHeight - 1)", surface)
                self.assertIn("function constrainedHorizontalPopupX(", surface)
                self.assertIn("leftInset - surfaceOffset", surface)
                self.assertIn("Number(windowWidth) - rightInset - surfaceOffset - root.fullWidth", surface)
                self.assertIn("capStyle: ShapePath.FlatCap", surface)
                border_section = surface.split("// Continue the frame outline", 1)[1]
                self.assertEqual(16, border_section.count("joinRadius"))
                self.assertEqual(16, border_section.count("PathCubic {"))
                self.assertEqual(2, border_section.count("startX: root.fullWidth - root.borderInset"))
                self.assertEqual(1, border_section.count("startX: root.fullWidth\n"))
                self.assertIn("PathLine { x: root.fullWidth - root.borderInset; y: root.borderInset }", border_section)
                self.assertIn("control1X: root.fullWidth - root.borderInset - root.joinRadius * root.curveKappa", border_section)
                self.assertEqual(1, border_section.count("startX: root.borderInset"))
                self.assertIn("readonly property string attachmentEdge: bar && /^(top|bottom|left|right)$/.test(bar.position)", flyout)
                self.assertIn("bar: root.bar", flyout)
                self.assertIn('root.attachmentEdge === "left"', flyout)
                self.assertIn('root.attachmentEdge === "right"', flyout)
                self.assertIn("readonly property bool horizontalReveal", flyout)
                self.assertIn("attachmentEdge: root.attachmentEdge", flyout)
                self.assertEqual(4, flyout.count("surface.attachmentOverlap"))
                shadowed = plugin in {"claude-usage", "codex-usage", "system-stats", "temperature", "theme", "wallpaper", "clock", "weather"}
                if shadowed:
                    self.assertIn("root.implicitWidth, root.shadowLeftMargin, root.margin)", flyout)
                    self.assertIn("var localY = target.height - root.shadowTopMargin - surface.attachmentOverlap", flyout)
                    self.assertIn("localY = -(root.shadowTopMargin + surface.fullHeight) + surface.attachmentOverlap", flyout)
                    self.assertIn("localX = target.width - root.shadowLeftMargin - surface.attachmentOverlap", flyout)
                    self.assertIn("localX = -(root.shadowLeftMargin + surface.fullWidth) + surface.attachmentOverlap", flyout)
                else:
                    self.assertIn("root.implicitWidth, 0, root.margin)", flyout)
                    self.assertIn("var localY = target.height - surface.attachmentOverlap", flyout)
                    self.assertIn("localY = -surface.fullHeight + surface.attachmentOverlap", flyout)
                    self.assertIn("localX = target.width - surface.attachmentOverlap", flyout)
                    self.assertIn("localX = -surface.fullWidth + surface.attachmentOverlap", flyout)
                self.assertIn("point.y = Math.max(root.margin", flyout)
                if shadowed:
                    self.assertIn("readonly property int shadowLeftMargin", flyout)
                    self.assertIn("readonly property int shadowRightMargin", flyout)
                    self.assertIn("readonly property int shadowTopMargin", flyout)
                    self.assertIn("readonly property int shadowBottomMargin", flyout)
                    self.assertIn("implicitWidth: surface.fullWidth + shadowLeftMargin + shadowRightMargin", flyout)
                    self.assertIn("implicitHeight: surface.fullHeight + shadowTopMargin + shadowBottomMargin", flyout)


if __name__ == "__main__":
    unittest.main()
