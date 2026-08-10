<!-- Status: user guide for the latest beta -->

<div class="lacuna-hero" markdown="1">
<div class="lacuna-hero__copy" markdown="1">

<p class="lacuna-hero__eyebrow">A visual shell for Omarchy</p>

# The desktop lives in the seam. { .lacuna-hero__title }

<p class="lacuna-hero__lede">Lacuna joins a custom bar, full-screen frame, utility sidebar, focused controls, media, and optional ambience inside the Omarchy shell you already use.</p>

<div class="lacuna-release">
  <span class="lacuna-release__version">0.1.0-beta.4</span>
  <p>Public beta. Check the reviewed host versions before installing.</p>
  <a href="help/compatibility/">Check compatibility <span aria-hidden="true">→</span></a>
</div>

<div class="lacuna-hero__actions" markdown="1">

[Start here](getting-started/index.md){ .md-button .md-button--primary }
[Installation](getting-started/installation.md){ .md-button }

</div>
</div>

<figure class="lacuna-hero__specimen">
  <a class="lacuna-specimen__image" href="screenshots/readme/lacuna-appearance.webp" aria-label="Open the full-size Lacuna appearance screenshot">
    <img src="screenshots/user/hero-attached-settings.webp" width="1387" height="1100" alt="Lacuna sidebar joined to its Appearance settings flyout inside the framed desktop" fetchpriority="high" decoding="async">
  </a>
  <figcaption><span>Attached surface</span> Sidebar, frame, and Appearance settings shown as one connected shell.</figcaption>
</figure>
</div>

Lacuna is a connected desktop layer for Omarchy. It runs inside Omarchy's
existing Quickshell process, follows the active theme, and leaves system
orchestration to Omarchy while giving the shell a distinct form.

## What changes

<div class="lacuna-feature-list" markdown="1">

- **One connected shell.** The bar, frame, sidebar, connectors, and attached
  flyouts read as one surface rather than unrelated widgets.
- **Useful controls close at hand.** Launch applications and reach audio,
  network, Bluetooth, power, notifications, weather, workspaces, and media.
- **A desktop that follows your theme.** Lacuna owns structure and motion while
  Omarchy continues to own color.
- **Optional atmosphere.** Compose film grain, rain, aurora, CRT, VHS, and
  other ambience without starting another shell.
- **Safe lifecycle tools.** Installation, update, reset, and uninstall preview
  their work and preserve user-owned state according to their documented scope.

</div>

<div class="lacuna-paths">
  <section>
    <p class="lacuna-paths__label">01 · Begin</p>
    <h3>Install Lacuna</h3>
    <p>Check the requirements, install the complete shell, and verify it in a few minutes.</p>
    <p><a href="getting-started/">Start here <span aria-hidden="true">→</span></a></p>
  </section>
  <section>
    <p class="lacuna-paths__label">02 · Shape</p>
    <h3>Configure the shell</h3>
    <p>Learn which controls belong to Lacuna Settings and which belong to Omarchy Settings.</p>
    <p><a href="configuration/">Configure Lacuna <span aria-hidden="true">→</span></a></p>
  </section>
  <section>
    <p class="lacuna-paths__label">03 · Recover</p>
    <h3>Recover or report</h3>
    <p>Run the health report, recover the shell, or gather useful details for a bug report.</p>
    <p><a href="help/troubleshooting/">Troubleshoot <span aria-hidden="true">→</span></a></p>
  </section>
</div>

## See the shell

The screenshots below are crops from authentic Lacuna project sessions. They
show representative shell states clearly at documentation size; release details
visible inside a capture may predate the current beta.

<div class="lacuna-gallery">
  <figure class="lacuna-specimen">
    <a class="lacuna-specimen__image" href="screenshots/readme/lacuna-desktop.webp" aria-label="Open the full-size connected shell screenshot">
      <img src="screenshots/user/connected-shell.webp" width="900" height="990" alt="Expanded Lacuna sidebar meeting the top bar and desktop frame" loading="lazy" decoding="async">
    </a>
    <figcaption><span>Connected shell</span> The sidebar, top bar, frame, and media controls share one edge language. <a href="guides/sidebar-and-launchers/">Explore the sidebar →</a></figcaption>
  </figure>
  <figure class="lacuna-specimen">
    <a class="lacuna-specimen__image" href="screenshots/readme/lacuna-appearance.webp" aria-label="Open the full-size Appearance settings screenshot">
      <img src="screenshots/user/appearance-settings.webp" width="1000" height="870" alt="Appearance settings attached directly to the expanded Lacuna sidebar" loading="lazy" decoding="async">
    </a>
    <figcaption><span>Appearance</span> Theme-aware form, frame controls, and connector geometry remain one assembly. <a href="guides/appearance-and-themes/">Shape the appearance →</a></figcaption>
  </figure>
  <figure class="lacuna-specimen">
    <a class="lacuna-specimen__image" href="screenshots/readme/lacuna-animations.webp" aria-label="Open the full-size desktop ambience screenshot">
      <img src="screenshots/user/desktop-ambience.webp" width="1100" height="815" alt="Lacuna desktop with the expanded sidebar and restrained CRT-style ambience" loading="lazy" decoding="async">
    </a>
    <figcaption><span>Ambience</span> Optional texture changes the atmosphere without replacing the desktop shell. <a href="guides/desktop-ambience/">Compose ambience →</a></figcaption>
  </figure>
</div>

## Current status

Lacuna is in public beta. It is suitable for testing and everyday use by people
who are comfortable reporting beta defects, but its supported-version range is
not yet frozen.

Lacuna has been reviewed on an exact Omarchy and Quickshell pair. Nearby
versions may work, but they are not promised. See
[Compatibility](help/compatibility.md) before installing or updating the host.
