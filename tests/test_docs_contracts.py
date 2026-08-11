import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLANS = ROOT / "docs" / "plans"


class DocsContractTests(unittest.TestCase):
    def test_root_design_entry_point_links_authoritative_design_system(self):
        design = (ROOT / "DESIGN.md").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("docs/lacuna-design-system/README.md", design)
        for name in ["00-philosophy.md", "01-color.md", "02-geometry.md", "03-motion.md", "04-typography.md", "05-components.md"]:
            self.assertIn(name, design)
        self.assertIn("[design-system entry point](DESIGN.md)", readme)

    def test_aur_policy_and_user_install_path_are_current(self):
        release = (ROOT / "docs/development/release.md").read_text(encoding="utf-8")
        user_install = (ROOT / "docs/getting-started/installation.md").read_text(encoding="utf-8")
        release_notes = (ROOT / "docs/releases/index.md").read_text(encoding="utf-8")
        package = (ROOT / "packaging/aur/README.md").read_text(encoding="utf-8")
        submission = (ROOT / "packaging/aur/SUBMISSION.md").read_text(encoding="utf-8")
        for text in [release, package, submission]:
            self.assertIn("beta", text)
            self.assertIn("RC", text)
            self.assertIn("stable", text)
        self.assertIn("0.1.0beta.4", release)
        self.assertIn("0.1.0beta.4", release_notes)
        self.assertIn("omarchy pkg aur add lacuna-shell", user_install)
        self.assertIn("sudo pacman -U", user_install)
        self.assertIn("releases/download/v0.1.0-beta.5", user_install)
        self.assertIn("single", submission)
        self.assertIn("`lacuna-shell` AUR package", submission)
        self.assertNotIn("GitHub prereleases only", package)
        self.assertNotIn("Do not submit beta or RC", release)

    def test_typography_spec_defines_distinct_tracking_roles(self):
        typography = (ROOT / "docs/lacuna-design-system/04-typography.md").read_text(encoding="utf-8")
        self.assertIn("## Tracking roles", typography)
        self.assertIn("`trackingTitle` | `2.0px` | `1.4px`", typography)
        self.assertIn("`trackingMenuItem` | `0.9px` | `0.6px`", typography)
        self.assertIn("`trackingSection` | `0px` | `0px`", typography)
        self.assertIn("`trackingBody` | `0px` | `0px`", typography)

    def test_docs_have_status_markers(self):
        for path in sorted((ROOT / "docs").glob("*.md")):
            head = "\n".join(path.read_text(encoding="utf-8").splitlines()[:20])
            self.assertIn("Status:", head, str(path.relative_to(ROOT)))

    def test_first_class_docs_structure_exists(self):
        user_pages = [
            "docs/index.md",
            "docs/getting-started/index.md",
            "docs/getting-started/requirements.md",
            "docs/getting-started/installation.md",
            "docs/getting-started/first-run.md",
            "docs/getting-started/upgrading.md",
            "docs/guides/sidebar-and-launchers.md",
            "docs/guides/bar-and-widgets.md",
            "docs/guides/appearance-and-themes.md",
            "docs/guides/media-player.md",
            "docs/guides/desktop-ambience.md",
            "docs/guides/multiple-monitors.md",
            "docs/configuration/index.md",
            "docs/configuration/lacuna-settings.md",
            "docs/configuration/omarchy-settings.md",
            "docs/configuration/advanced-state-files.md",
            "docs/operations/reset-and-recovery.md",
            "docs/operations/uninstall.md",
            "docs/operations/restore-stock-omarchy.md",
            "docs/help/troubleshooting.md",
            "docs/help/compatibility.md",
            "docs/help/known-limitations.md",
            "docs/help/faq.md",
            "docs/help/support.md",
            "docs/releases/index.md",
            "docs/releases/migration-notes.md",
        ]
        technical_references = [
            "docs/README.md",
            "docs/install.md",
            "docs/configuration.md",
            "docs/architecture/overview.md",
            "docs/architecture/plugin-contracts.md",
            "docs/architecture/services-and-state.md",
            "docs/architecture/omarchy-integration.md",
            "docs/development/setup.md",
            "docs/development/testing.md",
            "docs/development/release.md",
            "docs/development/troubleshooting.md",
            "docs/plugins/README.md",
            "docs/plugins/bar.md",
            "docs/plugins/menu.md",
            "docs/plugins/widgets.md",
            "docs/plugins/overlays.md",
        ]
        for name in [*user_pages, *technical_references, "mkdocs.yml", "docs/requirements.txt", ".github/workflows/docs.yml"]:
            self.assertTrue((ROOT / name).exists(), name)

        mkdocs = (ROOT / "mkdocs.yml").read_text(encoding="utf-8")
        for name in user_pages:
            self.assertIn(name.removeprefix("docs/"), mkdocs, name)
        exclusion_block = mkdocs.split("nav:", 1)[0]
        for excluded in [
            "/configuration.md",
            "/install.md",
            "/requirements.txt",
            "plans/**",
            "project/historical/**",
        ]:
            self.assertIn(excluded, exclusion_block)
        self.assertNotIn("navigation.sections", mkdocs)
        self.assertIn("assets/javascripts/accessibility.js", mkdocs)

        workflow = (ROOT / ".github/workflows/docs.yml").read_text(encoding="utf-8")
        self.assertIn('- "VERSION"', workflow)
        self.assertIn("python -m unittest discover -s tests -p 'test_docs*.py'", workflow)
        self.assertIn("mkdocs build --strict", workflow)
        self.assertIn("python scripts/check_docs_links.py site --site-prefix /lacuna-shell/", workflow)
        top_permissions = workflow.split("jobs:", 1)[0]
        self.assertIn("contents: read", top_permissions)
        self.assertNotIn("pages: write", top_permissions)
        self.assertNotIn("id-token: write", top_permissions)

    def test_user_docs_use_current_release_and_aur_truth(self):
        user_paths = [ROOT / "README.md", ROOT / "docs/index.md"]
        for directory in ["getting-started", "guides", "configuration", "operations", "help", "releases"]:
            user_paths.extend(sorted((ROOT / "docs" / directory).glob("*.md")))

        current_version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        combined = "\n".join(path.read_text(encoding="utf-8") for path in user_paths)
        self.assertIn(current_version, combined)
        self.assertIn("omarchy pkg aur add lacuna-shell", combined)
        for stale in [
            "AUR publishing is unavailable",
            "preparing for its first public beta",
            "currently report the `0.1.0-beta.1` candidate",
            "AUR maintenance",
            "maintainer SSH pushes",
            "pushes were temporarily paused",
            "pushes are temporarily paused",
        ]:
            self.assertNotIn(stale.lower(), combined.lower())
        self.assertNotIn("AUR publishing is\nunavailable", (ROOT / "install.sh").read_text(encoding="utf-8"))

    def test_user_safety_facts_match_runtime_contracts(self):
        reviewed_omarchy = "4.0.0.r1438.g9b693cc-1"
        reviewed_quickshell = "0.3.0.r18.g10b439f-3"
        for relative in ["README.md", "docs/getting-started/requirements.md", "docs/help/compatibility.md"]:
            text = (ROOT / relative).read_text(encoding="utf-8")
            self.assertIn(reviewed_omarchy, text, relative)
            self.assertIn(reviewed_quickshell, text, relative)
            self.assertNotIn("current Omarchy installation", text, relative)

        requirements = (ROOT / "docs/getting-started/requirements.md").read_text(encoding="utf-8")
        self.assertIn("Do not update Omarchy solely to install Lacuna", requirements)
        self.assertNotIn("Finish any pending Omarchy update", requirements)

        installation = (ROOT / "docs/getting-started/installation.md").read_text(encoding="utf-8")
        self.assertIn("`shell.json`", installation)
        self.assertIn("`settings.json`", installation)
        self.assertNotIn("and Lacuna state,", installation)

        upgrading = (ROOT / "docs/getting-started/upgrading.md").read_text(encoding="utf-8")
        for phrase in ["Do not update\nthe host solely for Lacuna", "changed\ninstalled plugin copies", "rescan plugins", "restores the touched plugin copies", "omarchy restart shell"]:
            self.assertIn(phrase, upgrading)
        self.assertIn("does\nnot mutate or roll back `shell.json`", upgrading)
        self.assertNotIn("restores the touched plugin\ncopies and shell configuration", upgrading)

        uninstall = (ROOT / "docs/operations/uninstall.md").read_text(encoding="utf-8")
        for phrase in ["packaged bar host", "packaged bar\nlayout", "replacing the current bar composition", "`omarchy bar reset`"]:
            self.assertIn(phrase, uninstall)
        self.assertIn("preserves the current layout", uninstall)

        media = (ROOT / "docs/guides/media-player.md").read_text(encoding="utf-8")
        self.assertIn("server URL and API key", media)
        self.assertIn("advanced `userId` field is optional", media)
        self.assertNotIn("server URL, API key, and user ID", media)

        xdg_media_path = "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/lacuna/media-player.json"
        for relative in ["docs/configuration.md", "docs/configuration/advanced-state-files.md"]:
            self.assertIn(xdg_media_path, (ROOT / relative).read_text(encoding="utf-8"), relative)

    def test_docs_assets_and_accessibility_contracts(self):
        for relative in [
            "docs/assets/fonts/Hack-Regular.ttf",
            "docs/assets/fonts/Hack-LICENSE.txt",
            "docs/assets/fonts/Tektur-SemiBold.ttf",
            "docs/assets/fonts/Tektur-OFL.txt",
            "docs/assets/javascripts/accessibility.js",
            "docs/screenshots/user/hero-attached-settings.webp",
            "docs/screenshots/user/connected-shell.webp",
            "docs/screenshots/user/appearance-settings.webp",
            "docs/screenshots/user/desktop-ambience.webp",
            "docs/screenshots/user/sources.json",
            "scripts/check_docs_links.py",
        ]:
            path = ROOT / relative
            self.assertTrue(path.is_file(), relative)
            self.assertGreater(path.stat().st_size, 0, relative)

        css = (ROOT / "docs/assets/stylesheets/lacuna.css").read_text(encoding="utf-8")
        for phrase in [
            '@font-face',
            'font-display: swap',
            '[data-md-color-scheme="default"]',
            '[data-md-color-scheme="slate"] .md-logo img',
            '--md-text-font: system-ui',
            'font-family: "Lacuna Tektur"',
            '--lacuna-prose: 68ch',
            '--lacuna-type-body: 0.8rem',
            '--lacuna-canvas: #f7f8fa',
            '--lacuna-surface: #ffffff',
            '--lacuna-accent: #5b5bd6',
            '--lacuna-canvas: #0b0c0f',
            '--lacuna-accent: #a5a3ff',
            '--lacuna-reveal: 300ms',
            '--lacuna-reveal-curve: cubic-bezier(0.2, 0, 0.32, 1)',
            '.md-nav__item .md-nav__link--active',
            '.md-sidebar--primary .md-nav__source',
            '[data-md-toggle="search"]:checked ~ .md-header .md-search__form',
            '.lacuna-hero__specimen',
            'grid-template-columns: minmax(18rem, 0.85fr) minmax(0, 1.15fr)',
            '.lacuna-gallery',
            'grid-template-columns: minmax(0, 1.35fr) minmax(16rem, 0.65fr)',
            '@media (prefers-reduced-motion: reduce)',
            'clip-path: none !important',
            'outline: 2px solid var(--lacuna-focus)',
        ]:
            self.assertIn(phrase, css)
        for discarded_ornament in [
            'background-size: 3rem 3rem',
            '.md-content::before',
            'border-top: 0.18rem solid var(--lacuna-accent)',
        ]:
            self.assertNotIn(discarded_ornament, css)

        javascript = (ROOT / "docs/assets/javascripts/accessibility.js").read_text(encoding="utf-8")
        for phrase in [
            '.md-header__button[for="__drawer"]',
            '.md-header__button[for="__search"]',
            'setAttribute("role", "button")',
            'setAttribute("tabindex", "0")',
            'setAttribute("aria-expanded"',
            'setAttribute("aria-haspopup", "dialog")',
            'removeAttribute("aria-haspopup")',
            'event.key !== "Enter"',
            'event.key !== " "',
            'label.click()',
            'const enhancementByLabel = new WeakMap()',
            'removeEventListener("change"',
            'removeEventListener("keydown"',
            'event.key !== "Escape"',
            'document.addEventListener("keydown", closeOpenHeaderControl)',
            'document$.subscribe(enhanceHeaderControls)',
        ]:
            self.assertIn(phrase, javascript)
        self.assertNotIn("control.checked = !control.checked", javascript)

        home = (ROOT / "docs/index.md").read_text(encoding="utf-8")
        self.assertIn('<div class="lacuna-hero" markdown="1">', home)
        self.assertIn("# The desktop lives in the seam.", home)
        self.assertIn('<div class="lacuna-release">', home)
        current_version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        self.assertEqual(1, home.count(current_version))
        self.assertIn(f'<span class="lacuna-release__version">{current_version}</span>', home)
        self.assertIn('href="help/compatibility/"', home)
        self.assertIn('class="lacuna-hero__specimen"', home)
        self.assertIn('class="lacuna-gallery"', home)
        self.assertIn('width="1387" height="1100"', home)
        self.assertLess(home.index("[Start here]"), home.index("[Installation]"))
        self.assertNotIn("## Where to go next", home)
        self.assertNotIn("screenshots/reference/", home)

        source_manifest = json.loads((ROOT / "docs/screenshots/user/sources.json").read_text(encoding="utf-8"))
        expected_images = {
            "hero-attached-settings.webp": [1387, 1100],
            "connected-shell.webp": [900, 990],
            "appearance-settings.webp": [1000, 870],
            "desktop-ambience.webp": [1100, 815],
        }
        expected_source_commits = {
            "hero-attached-settings.webp": "1a066cc",
            "connected-shell.webp": "1a066cc",
            "appearance-settings.webp": "1a066cc",
            "desktop-ambience.webp": "01c0934",
        }
        self.assertEqual(set(expected_images), set(source_manifest))
        for filename, dimensions in expected_images.items():
            entry = source_manifest[filename]
            self.assertEqual(dimensions, entry["dimensions"])
            self.assertEqual("0.1.0", entry["capturedVersion"])
            self.assertEqual(expected_source_commits[filename], entry["sourceCommit"])
            self.assertTrue(entry["state"])
            self.assertTrue(entry["treatment"])
            self.assertTrue((ROOT / "docs/screenshots/user" / entry["source"]).resolve().is_file())

    def test_user_documentation_plan_is_active_and_indexed_once(self):
        relative = "active/lacuna-user-documentation-plan.md"
        plan = (PLANS / relative).read_text(encoding="utf-8")
        index = (PLANS / "README.md").read_text(encoding="utf-8")
        self.assertIn("Status: active", "\n".join(plan.splitlines()[:8]))
        self.assertEqual(1, index.count(f"(./{relative})"))
        for heading in [
            "## Source Of Truth",
            "## Migration Map",
            "## Delivery Phases",
            "## Documentation Quality Gates",
            "## Acceptance Criteria",
        ]:
            self.assertIn(heading, plan)

    def test_stale_publication_material_is_historical(self):
        old_paths = [
            ROOT / "docs/discord-beta-announcement.md",
            ROOT / "docs/lacuna-suite-polish-review.md",
        ]
        self.assertTrue(all(not path.exists() for path in old_paths))
        historical = [
            ROOT / "docs/project/historical/discord-beta-2-announcement.md",
            ROOT / "docs/project/historical/lacuna-suite-polish-review.md",
        ]
        for path in historical:
            head = "\n".join(path.read_text(encoding="utf-8").splitlines()[:10])
            self.assertIn("Status: historical", head)

    def test_plan_docs_are_separated_from_reference_docs(self):
        root_plan_docs = sorted((ROOT / "docs").glob("*plan*.md"))
        self.assertEqual([], root_plan_docs)

        plan_docs = sorted(path for path in PLANS.rglob("*.md") if path.name != "README.md")
        self.assertTrue(plan_docs, "docs/plans should contain implementation plans")
        for path in plan_docs:
            head = "\n".join(path.read_text(encoding="utf-8").splitlines()[:8])
            self.assertIn("Status:", head, str(path.relative_to(ROOT)))

        index = (PLANS / "README.md").read_text(encoding="utf-8")
        for path in plan_docs:
            relative = path.relative_to(PLANS).as_posix()
            self.assertEqual(1, index.count(f"(./{relative})"), relative)

    def test_lacuna_bar_refactor_plan_tracks_current_architecture_decisions(self):
        plan = (PLANS / "completed" / "lacuna-bar-refactor-plan.md").read_text(encoding="utf-8")

        self.assertIn("Status: complete", plan)
        self.assertIn("Keep `lacuna.bar` as the Lacuna Bar plugin ID", plan)
        self.assertIn("Keep `shell.json` as the public composition interface", plan)
        self.assertIn("Keep `lacuna.menu` as a compatibility summon target", plan)
        self.assertIn("Use Noctalia as an architectural reference", plan)
        self.assertIn("Keep reusable plugin extraction evaluative", plan)
        self.assertIn("- [x] Pin current `lacuna.bar` host behavior with tests.", plan)
        self.assertIn('- [x] Keep installer activation aligned with `bar.id = "lacuna.bar"`', plan)
        self.assertIn("- [x] Move any remaining frame/sidebar ownership assumptions", plan)
        self.assertIn("- [x] Preserve flyout geometry rules", plan)
        self.assertIn("- [x] Run `python3 -m pytest` after each meaningful slice.", plan)
        self.assertIn("- [x] Run `./scripts/check.sh` before publishing the refactor.", plan)

    def test_plugin_dependency_docs_identify_reusable_candidates(self):
        docs = (ROOT / "docs" / "plugins" / "README.md").read_text(encoding="utf-8")

        self.assertIn("## Reusable Extraction Candidates", docs)
        for plugin_id in [
            "lacuna.theme",
            "lacuna.wallpaper",
            "lacuna.claude-usage",
            "lacuna.codex-usage",
        ]:
            self.assertIn(f"- `{plugin_id}`", docs)
        self.assertIn("keep the current plugin IDs", docs)

    def test_lacuna_bar_docs_define_the_opaque_surface_contract(self):
        bar = (ROOT / "docs" / "plugins" / "bar.md").read_text(encoding="utf-8")
        configuration = (ROOT / "docs" / "configuration" / "omarchy-settings.md").read_text(encoding="utf-8")

        self.assertIn("The Lacuna bar is deliberately opaque", bar)
        self.assertIn("normalizes `bar.transparent` to `false`", bar)
        self.assertIn("stock bar's double-click", bar)
        self.assertIn("transparency gesture is not part of the Lacuna bar contract", bar)
        self.assertIn("normalizes the host transparency setting to false", configuration)

    def test_completed_panel_and_frame_plans_are_not_left_active(self):
        for path in [
            PLANS / "archive" / "lacuna-panel-ui-overhaul-plan.md",
            PLANS / "archive" / "lacuna-panel-control-refactor-plan.md",
            PLANS / "completed" / "lacuna-fake-fullscreen-frame-plan.md",
        ]:
            text = path.read_text(encoding="utf-8")
            head = "\n".join(text.splitlines()[:8])
            self.assertNotIn("Status: active", head, path.name)
            self.assertIn("Completion note 2026-06-14", text, path.name)

    def test_quattro_roadmap_and_phase_plans_are_canonical(self):
        roadmap = (ROOT / "docs" / "roadmap.md").read_text(encoding="utf-8")
        plans_index = (PLANS / "README.md").read_text(encoding="utf-8")
        historical_tracker = (PLANS / "archive" / "lacuna-suite-improvement-plan.md").read_text(encoding="utf-8")

        self.assertIn("Status: active project control (updated 2026-08-04)", roadmap)
        self.assertIn("`lacuna.bar` is the intentional custom bar host", roadmap)
        self.assertIn("P0 — Core foundation", roadmap)
        self.assertIn("P1 — Product integration", roadmap)
        self.assertIn("P2 — Release and evolution", roadmap)
        self.assertIn("0.1.0-beta.1", roadmap)
        self.assertIn("0.1.0-rc.1", roadmap)
        self.assertIn("Optional visual-surface work is not a beta gate.", roadmap)
        self.assertIn("The semi-persistent sidebar remains pointer-driven", roadmap)
        self.assertIn("Interactive flyouts may take", roadmap)
        self.assertIn("unconsumed Backspace", roadmap)
        self.assertIn("must not expose general keyboard", roadmap)
        self.assertIn("canonical omakase setup", roadmap)
        self.assertIn("provider-capability-aware usage widgets", roadmap)
        self.assertIn("Codex currently reports a weekly-only quota window", roadmap)
        self.assertNotIn("`core`, `native`, and `advanced` profiles have documented boundaries", roadmap)
        self.assertIn("## Active", plans_index)
        self.assertIn("## Proposed And Draft", plans_index)
        self.assertIn("## Completed", plans_index)
        self.assertIn("## Archive", plans_index)
        self.assertIn("lacuna-reliability-and-optimization-plan.md", plans_index)
        self.assertIn("lacuna-clock-calendar-flyout-plan.md", plans_index)
        self.assertIn("lacuna-weather-flyout-plan.md", plans_index)
        self.assertIn("Implemented and live-verified 2026-07-13", plans_index)
        self.assertIn("Clock And Calendar Flyout", roadmap)

        expected_plans = {
            "completed": [
                "sidebar-settings-flyout-stability-plan.md",
                "quattro-p0-core-foundation-plan.md",
                "lacuna-clock-calendar-flyout-plan.md",
                "lacuna-weather-flyout-plan.md",
            ],
            "active": [
                "quattro-p1-product-integration-plan.md",
                "quattro-p2-release-and-evolution-plan.md",
            ],
        }
        for category, names in expected_plans.items():
            for name in names:
                self.assertIn(name, plans_index)
                self.assertTrue((PLANS / category / name).exists(), name)

        stability_plan = (PLANS / "completed" / "sidebar-settings-flyout-stability-plan.md").read_text(encoding="utf-8")
        self.assertIn("Status: completed and user-verified", stability_plan)
        self.assertIn("flyoutLaneWidthFor(screen)", stability_plan)
        self.assertIn("the user visually confirmed", stability_plan)
        self.assertIn("Do not add another timeout, debounce, delayed reopen", stability_plan)
        self.assertIn("LACUNA_LIVE_VISUAL=1", stability_plan)

        self.assertIn("Status: superseded historical tracker (2026-07-10)", historical_tracker)
        self.assertIn("Use [`../../roadmap.md`](../../roadmap.md)", historical_tracker)

        p1 = (PLANS / "active" / "quattro-p1-product-integration-plan.md").read_text(encoding="utf-8")
        p2 = (PLANS / "active" / "quattro-p2-release-and-evolution-plan.md").read_text(encoding="utf-8")
        release = (ROOT / "docs" / "development" / "release.md").read_text(encoding="utf-8")
        self.assertIn("Status: in progress; beta product-readiness track", p1)
        self.assertIn("quattro-p1-closeout-execution-plan.md", p1)
        closeout = (PLANS / "active" / "quattro-p1-closeout-execution-plan.md").read_text(encoding="utf-8")
        self.assertIn("The execution must use pi subagents.", closeout)
        self.assertIn("## Reusable Parent-Orchestrator Prompt", closeout)
        self.assertIn("Delivered Checkpoint — 2026-07-16", p1)
        self.assertIn("never present stale historical windows", p1)
        self.assertIn("never claim suppression", p1)
        self.assertIn("General keyboard navigation, Tab", p1)
        self.assertIn("intentional text entry", p1)
        self.assertIn("Support `Escape` dismissal", p1)
        self.assertIn("unconsumed Backspace", p1)
        self.assertIn("click-away dismissal", p1)
        self.assertIn("## Workstream 5 — Omakase setup and customization", p1)
        self.assertIn("choose between architectural profiles", p1)
        self.assertIn("tests/test_qml_behavior_video.py", p1)
        self.assertNotIn("tests/test_media_player_worker.py", p1)
        self.assertIn("Status: in progress; beta/RC release-readiness track", p2)
        self.assertIn("P2 runs alongside P1", p2)
        self.assertIn("Current development target accepted", p2)
        self.assertIn("Accepted Omarchy `4.0.0.r1438.g9b693cc-1`", p2)
        self.assertIn("0.1.0-beta.N -> 0.1.0-rc.N -> 0.1.0", release)

    def test_omakase_decisions_are_recorded_without_p1_completion_claim(self):
        p1 = (PLANS / "active" / "quattro-p1-product-integration-plan.md").read_text(encoding="utf-8")
        closeout = (PLANS / "active" / "quattro-p1-closeout-execution-plan.md").read_text(encoding="utf-8")
        roadmap = (ROOT / "docs/roadmap.md").read_text(encoding="utf-8")
        recovery = (ROOT / "docs/operations/reset-and-recovery.md").read_text(encoding="utf-8")
        catalog = (ROOT / "docs/plugins/README.md").read_text(encoding="utf-8")
        release = (ROOT / "docs/development/release.md").read_text(encoding="utf-8")

        for document in (p1, closeout):
            self.assertIn("exact checked 46", document)
            self.assertIn("lacuna.media-player-video", document)
            self.assertIn("safe-only", document)
            self.assertIn("`stable` is reserved", document)
            self.assertIn("fresh explicit confirmation", document)
            self.assertNotRegex(document, r"(?m)^P1 workstream is complete\b")
        self.assertIn("no P1 workstream is complete by this record.", p1)
        self.assertIn("No P1 workstream is complete by this checkpoint.", closeout)
        self.assertIn("checked 46-root omakase profile", roadmap)
        self.assertIn("reset does not replace installed plugin payloads", recovery.lower())
        self.assertIn("Adding\na manifest cannot silently add it", catalog)
        self.assertIn("automatic backups, verified restoration capability", release)
        self.assertIn("no destructive rehearsal was run", release)
        self.assertIn("complete normal Lacuna plugin set", recovery)
        self.assertIn("lacuna-shell install --profile full --reinstall --yes", recovery)
        self.assertIn("replaced atomically", recovery)
        self.assertIn("power loss between replacing `shell.json` and `settings.json`", recovery)
        self.assertNotIn("atomically merges only reset-owned state", recovery)

    def test_quattro_compatibility_docs_match_reviewed_baseline(self):
        compatibility = json.loads((ROOT / "config" / "quattro-compatibility.json").read_text(encoding="utf-8"))
        ledger = (ROOT / "docs" / "architecture" / "quattro-compatibility.md").read_text(encoding="utf-8")
        roadmap = (ROOT / "docs" / "roadmap.md").read_text(encoding="utf-8")

        version = compatibility["reviewedOmarchyVersion"]
        self.assertIn(version, ledger)
        self.assertIn(version, roadmap)
        for digest in compatibility["upstreamFiles"].values():
            self.assertIn(digest, ledger)
        self.assertIn("r1043 to r1054 review", ledger)
        self.assertIn("`surfaceFormat.opaque: false`", ledger)
        self.assertIn("r1054 to r1180 review", ledger)
        self.assertIn("`Util.execDetached()`", ledger)
        self.assertIn("r1180 to r1193 review", ledger)
        self.assertIn("r1193 to r1333 review", ledger)
        self.assertIn("`moduleWidgets(pluginId)`", ledger)
        self.assertIn("`AppLibrary`", ledger)
        self.assertIn("r1333 to r1438 review", ledger)
        self.assertIn("`pickDrawnSlot()`", ledger)
        self.assertIn("`openPanelIndicatorWidth`", ledger)

    def test_current_docs_use_r1438_bar_commands(self):
        documents = {
            "docs/operations/restore-stock-omarchy.md": ROOT / "docs/operations/restore-stock-omarchy.md",
            "docs/architecture/quattro-compatibility.md": ROOT / "docs/architecture/quattro-compatibility.md",
            "docs/plugins/README.md": ROOT / "docs/plugins/README.md",
            "docs/plugins/bar.md": ROOT / "docs/plugins/bar.md",
            "docs/plans/proposed/lacuna-portrait-split-bar-plan.md": PLANS / "proposed" / "lacuna-portrait-split-bar-plan.md",
        }
        contents = {name: path.read_text(encoding="utf-8") for name, path in documents.items()}
        for name, text in contents.items():
            self.assertNotIn("omarchy plugin bar", text, name)

        for name in (
            "docs/operations/restore-stock-omarchy.md",
            "docs/architecture/quattro-compatibility.md",
            "docs/plans/proposed/lacuna-portrait-split-bar-plan.md",
        ):
            self.assertIn("omarchy bar reset", contents[name], name)
        self.assertIn("omarchy bar use lacuna.bar", contents["docs/plugins/README.md"])
        self.assertIn("omarchy bar use lacuna.bar", contents["docs/plugins/bar.md"])
        for name in ("docs/operations/restore-stock-omarchy.md", "docs/architecture/quattro-compatibility.md"):
            self.assertIn("omarchy bar defaults", contents[name], name)

    def test_beta_candidate_changelog_is_honest_and_scoped(self):
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn("## [Unreleased]", changelog)
        self.assertIn("## [0.1.0-beta.5] - 2026-08-11", changelog)
        self.assertLess(changelog.index("## [Unreleased]"), changelog.index("## [0.1.0-beta.5]"))
        self.assertIn("### Beta scope", changelog)
        self.assertIn("### Migration", changelog)
        self.assertIn("### Known limitations", changelog)
        self.assertIn("`beta`,\n  `experimental`, `deprecated`", changelog)
        self.assertIn("this is not a declaration of minimum supported", changelog)
        self.assertIn("P1 completion and destructive lifecycle rehearsal are separate", changelog)
        self.assertIn("compare/v0.1.0-beta.5...HEAD", changelog)
        self.assertNotIn("(`stable`,\n  `experimental`, `deprecated`)", changelog)

    def test_distribution_scaffolding_exists(self):
        for name in [
            "CHANGELOG.md",
            "CONTRIBUTING.md",
            ".github/PULL_REQUEST_TEMPLATE.md",
            ".github/ISSUE_TEMPLATE/bug_report.md",
            ".github/ISSUE_TEMPLATE/feature_request.md",
            ".pre-commit-config.yaml",
            ".shellcheckrc",
            "ruff.toml",
        ]:
            self.assertTrue((ROOT / name).exists(), name)
        self.assertIn("## [Unreleased]", (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
