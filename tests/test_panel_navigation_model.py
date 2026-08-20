import json
import shutil
import subprocess
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("node"), "node is not installed")
class PanelNavigationModelTests(unittest.TestCase):
    def run_model(self, body: str) -> dict:
        script = textwrap.dedent(
            f"""
            const model = require("./lacuna.bar/PanelNavigationModel.js");
            function panelItem(visible = true) {{
              return {{ visible, opened: false, open() {{}}, close() {{}} }};
            }}
            function slot(id, options = {{}}) {{
              return {{
                moduleName: id,
                region: options.region || "right",
                surfaceScreenName: options.screen || "DP-1",
                band: options.band || "primary",
                visible: options.slotVisible !== false,
                width: options.width === undefined ? 24 : options.width,
                height: options.height === undefined ? 24 : options.height,
                activeItem: options.item === undefined ? panelItem(options.itemVisible !== false) : options.item
              }};
            }}
            {body}
            """
        )
        result = subprocess.run(
            [shutil.which("node"), "-e", script],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        return json.loads(result.stdout)

    def test_filters_non_panels_and_non_drawn_slots(self):
        data = self.run_model(
            """
            const slots = [
              slot("good"),
              slot("no-open", { item: { visible: true, opened: false, close() {} } }),
              slot("no-close", { item: { visible: true, opened: false, open() {} } }),
              slot("no-opened", { item: { visible: true, open() {}, close() {} } }),
              slot("hidden-item", { itemVisible: false }),
              slot("hidden-slot", { slotVisible: false }),
              slot("zero-width", { width: 0 }),
              slot("zero-height", { height: 0 })
            ];
            const entries = slots.map(candidate => candidate.moduleName);
            const resolved = model.panelNavigationSlots(entries, slots, "right", "", "");
            console.log(JSON.stringify({ ids: resolved.map(candidate => candidate.moduleName) }));
            """
        )
        self.assertEqual(["good"], data["ids"])

    def test_uses_layout_order_and_respects_surface_scope(self):
        data = self.run_model(
            """
            const entries = [{ id: "audio" }, "network", { id: "power" }];
            const slots = [
              slot("power", { screen: "DP-1", band: "primary" }),
              slot("network", { screen: "DP-1", band: "companion" }),
              slot("audio", { screen: "DP-2", band: "primary" }),
              slot("audio", { screen: "DP-1", band: "primary" }),
              slot("network", { screen: "DP-1", band: "primary", itemVisible: false })
            ];
            const all = model.panelNavigationSlots(entries, slots, "right", "", "");
            const primary = model.panelNavigationSlots(entries, slots, "right", "DP-1", "primary");
            const companion = model.panelNavigationSlots(entries, slots, "right", "DP-1", "companion");
            console.log(JSON.stringify({
              all: all.map(candidate => candidate.moduleName + "@" + candidate.surfaceScreenName + "/" + candidate.band),
              primary: primary.map(candidate => candidate.moduleName),
              companion: companion.map(candidate => candidate.moduleName)
            }));
            """
        )
        self.assertEqual(
            ["audio@DP-2/primary", "network@DP-1/companion", "power@DP-1/primary"],
            data["all"],
        )
        self.assertEqual(["audio", "power"], data["primary"])
        self.assertEqual(["network"], data["companion"])

    def test_positional_lookup_counts_portrait_routed_copies_in_configured_section(self):
        data = self.run_model(
            """
            const entries = ["theme", "system-stats", "temperature"];
            const slots = [
              slot("temperature", { region: "center", band: "companion" }),
              slot("theme", { region: "right", band: "primary" }),
              slot("system-stats", { region: "center", band: "companion" })
            ];
            const lookup = value => model.panelWidgetIdAt(entries, slots, "right", value);
            console.log(JSON.stringify({
              first: lookup(1),
              second: lookup(2),
              third: lookup(3)
            }));
            """
        )
        self.assertEqual("theme", data["first"])
        self.assertEqual("system-stats", data["second"])
        self.assertEqual("temperature", data["third"])

    def test_positional_lookup_is_one_based_rounded_and_bounded(self):
        data = self.run_model(
            """
            const entries = ["audio", "tray", "network"];
            const slots = [
              slot("network"),
              slot("tray", { item: { visible: true } }),
              slot("audio")
            ];
            const lookup = value => model.panelWidgetIdAt(entries, slots, "right", value);
            console.log(JSON.stringify({
              one: lookup(1),
              stringOne: lookup("1"),
              roundsDown: lookup(1.4),
              roundsUp: lookup(1.6),
              zero: lookup(0),
              negative: lookup(-1),
              missing: lookup(3),
              invalid: lookup("not-a-number"),
              infinity: lookup(Infinity)
            }));
            """
        )
        self.assertEqual("audio", data["one"])
        self.assertEqual("audio", data["stringOne"])
        self.assertEqual("audio", data["roundsDown"])
        self.assertEqual("network", data["roundsUp"])
        for key in ["zero", "negative", "missing", "invalid", "infinity"]:
            self.assertEqual("", data[key], key)


class PanelNavigationForwardingContracts(unittest.TestCase):
    def test_active_bar_forwards_positional_lookup_to_runtime_model(self):
        outer = (ROOT / "lacuna.bar/Bar.qml").read_text(encoding="utf-8")
        inner = (ROOT / "lacuna.bar/OmarchyBar.qml").read_text(encoding="utf-8")

        self.assertIn('import "PanelNavigationModel.js" as PanelNavigationModel', inner)
        self.assertIn("function panelWidgetIdAt(region, index)", inner)
        self.assertIn("PanelNavigationModel.panelWidgetIdAt(", inner)
        self.assertIn("function panelWidgetIdAt(region, index)", outer)
        self.assertIn("return omarchyBar.panelWidgetIdAt(region, index)", outer)


if __name__ == "__main__":
    unittest.main()
