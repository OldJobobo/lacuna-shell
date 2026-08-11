# Media Player Architecture

Status: current

Lacuna Media Player uses one authoritative, headless mpv instance for audio,
timing, transport, and queue progression. QML video surfaces are muted renderers
that follow mpv; they never become a second audio source.

## Runtime Components

- `lacuna.media-player/Service.qml` owns user-visible state, queue/history,
  provider merging, the smoothed playback clock, and presentation handoffs.
- `lacuna.media-player/scripts/media-player-worker` is a persistent JSONL
  worker. It keeps mpv JSON IPC connected, observes playback properties, runs
  provider searches concurrently, and resolves video candidates.
- `lacuna.menu/menu/MediaPlayerTile.qml` renders the inline video surface and
  reports availability, readiness, and failures to the service.
- `lacuna.media-player-video/Overlay.qml` renders the permanently mapped,
  content-gated background surface and owns its black-cover transitions.

The worker accepts `configure`, `play`, `command`, `search`, `resolve-video`,
`cancel`, and `shutdown`. It emits `ready`, `configured`, `playback`, provider
results, video candidates, command results, and scoped errors. Provider
credentials are loaded from the settings file and are not placed in worker or
mpv command arguments.

## Search

Editing the query only searches the 15-minute cache, favorites, history, and
queue. Submitting starts enabled providers concurrently. Each provider result
is published immediately and the ranked All view interleaves YouTube and
Jellyfin without waiting for the slower provider. Initial rendering is capped
at 18 rows and can expand to the configured maximum of 36 by default.

Explicit YouTube searches use public flat-playlist results without loading
browser cookies. Authentication remains scoped to personalized home
suggestions and playback, avoiding cookie startup cost on every cold query.

## Playback Clock

The worker samples mpv over its persistent IPC connection. The service
interpolates the latest sample every 100ms while playing. Stop clears signed
renderer URLs; replay therefore follows the same `playNormalized()` transaction
as a fresh play—new playback revision, candidate resolution, and presentation
reconciliation—rather than restarting audio alone. Muted QML surfaces
use this clock with three correction bands:

- below 400ms: play at normal rate;
- 400ms through 1500ms: correct at `0.97` or `1.03` playback rate;
- above 1500ms: seek, with a 1500ms hard-seek cooldown.

Two failed background seek corrections move an adaptive stream to the stable
progressive candidate. A terminal renderer failure falls back inline until a
new track, explicit presentation choice, or manual stream refresh retries it.

## Presentation

`presentationMode` is `inline`, `background`, or `auto`. Auto uses inline video
while an inline surface is available and promotes to the background otherwise.
Inline availability is registered per output and reduced to an any-visible
projection; hidden output instances cannot overwrite a visible renderer through
a last-writer-wins boolean. `presentationMode` is the user preference and owns
the background-button selected state, while `backgroundVideoEnabled` only
reports transition occupancy until a handoff settles.
The public compatibility state remains `inline`, `promoting`, `background`,
`demoting`, or `recovering`; the old surface remains alive until the destination
reports ready.

Internally, `handoffPhase` distinguishes `idle`, `resolving`, `source-ready`,
`covering`, `loading-renderer`, `converging-outputs`, `presented`, `recovering`,
and `exiting`. Provider resolution does not consume the five-second renderer
budget. The service starts that deadline only after a surface assigns its
source and reports `reportVideoLoading()`.

Every loading/ready/failure callback carries a URL-free handoff token containing
the surface, playback revision, presentation revision, request revision, and a
surface-local source revision. Repeated loading for the same token is
idempotent; stale source, retry, timeout, and recovery callbacks cannot mutate a
newer presentation intent. IPC exposes the internal phase, token, deadline
state, and sanitized output diagnostics without signed URLs or raw backend
errors. Internal URL-bearing refresh keys are reduced to a `set`/empty
compatibility marker at the IPC boundary.

Background source changes raise the black cover for 220ms, hold for at least
80ms, then reveal over an 850ms sine-eased dissolve. Exit uses 240ms to black
and 700ms back to the Lacuna frame. Reduced motion uses 75ms transitions. The
player source is staged on its Loader and committed with the source generation,
so an outgoing player never starts a duplicate network load. Cover release waits
for the first valid decoded frame from a player in `PlayingState`, not merely a
loaded backend status. Because some QtMultimedia backends do not forward
`videoSink` frame notifications through `VideoOutput`, a 140ms bounded fallback
accepts a still-current player only when it is both `PlayingState` and
`LoadedMedia`/`BufferingMedia`/`BufferedMedia`; this prevents permanent
black-cover stalls without
restoring the old metadata-only early reveal. The background layer remains
mapped to preserve layer-shell ordering and gates only its in-window paint.
Its per-output clip consumes the bar-owned effective frame geometry record and
monotonic revision; frame paint, border, background video, and vignette therefore
move through the same immutable transaction rather than sampling mutable frame
settings independently.
The overlay owns only fade settlement, adaptive fallback, drift validation,
and a pre-source output-registration guard. The service is the sole generic
renderer-deadline owner. When forced inline mode is selected while no visible
inline renderer exists, the service does not wait for a destination that cannot
report readiness; it commits the public inline state and lets the background
overlay perform its normal covered exit.

Background readiness is all-or-nothing across matched outputs for the beta: all
players must register, match the source, report ready, and converge to the
service clock. If one output cannot register or the renderer deadline expires,
the whole background presentation falls back cleanly rather than leaving a
partial or indefinitely black desktop. `stop()` is available over IPC so gated
live probes can always restore a zero-player stopped state.

Adaptive quality prefers a 720p-capable HLS candidate. A stable progressive
360p candidate is retained for readiness timeout, playback error, or repeated
drift failure. Inline and background QtMultimedia players are recreated for
each source revision; signal handlers additionally verify the instance and
source generation, so queued events from a destroyed adaptive player cannot be
reported with a newer progressive token.

### Opt-in live validation

`tests/test_live_visual.py` never reads favorites or persisted media URLs. Set
`LACUNA_LIVE_VISUAL=1` and provide explicit non-secret fixtures:

- `LACUNA_LIVE_MEDIA_TEST_URL` enables cold start, inline/background handoff,
  cover-duration, and stop-cleanup checks.
- `LACUNA_LIVE_MEDIA_SWITCH_URL` additionally checks a real playing-track
  source replacement under the opaque cover.
- `LACUNA_LIVE_MEDIA_FAILURE_URL` enables terminal failure and black-cover
  settlement checks.

Physical output hotplug is intentionally not automated because disconnecting a
user display is destructive and compositor-specific. Shell-restart and output
hotplug remain explicit manual release checks: use disposable test media, stop
playback afterward, verify every matched output converges, and verify the cover
settles below `0.001`. These checks must not be claimed unless they were run on
the target compositor and output topology.
