# TouchOSC control surface

A native TouchOSC (Hexler) iPad layout that drives the AV-Live SuperCollider
engine over OSC and reflects live engine state back onto the surface. Generated
by code (gzipped XML), versioned in this repo, iterated by diff. Replaces the
`web_realart/public/control/` web surface as the **control** method
(`web_realart` stays for Hydra/WebGL visual sync).

## What it is

- `gen/schema.py` — TouchOSC `.tosc` v3 serializer (gzip-XML). Single format
  choke point. See `docs/superpowers/specs/2026-06-28-tosc-schema-reference.md`.
- `gen/layout.py` — data-driven 3-page layout model + widget builders.
- `gen/lua/*.lua` — per-widget Lua (pad arm-color, rhythm grid, melody faders,
  beat/RMS feedback, preset labels). Embedded at build time.
- `gen/build_layout.py` — entrypoint → `dist/av-live-control.tosc`.
- SC feedback: `sound_algo/data_only/touchosc_feedback.scd` (loaded by
  `sound_algo/data_only/boot.scd` after `launchpad.scd`).

### Pages
1. **LIVE** — tempo fader, CLEAR ALL, master VU, beat flash, 4×4 grid of 16
   pads (arm button + volume fader + name, armed-state reflection).
2. **FX / HARMONIE / CONCERT** — filter, FX one-shots, breakdown in/out;
   harmony root/scale/octave/phrase; morceau next, concert, body-play.
3. **SÉQUENCEURS** — rhythm (8 presets + 3×16 grid) and melody (8 presets + 8
   step faders) with arm buttons.

## Build

```bash
cd touchosc
uv run python -m gen.build_layout      # writes dist/av-live-control.tosc
uv run pytest -q                       # 20 tests
```

`*.tosc` build outputs under `dist/` are the deliverable and are committed.

## Validate on GrosMac (before deploying to the iPad)

1. **Fidelity gate (do this first):** in TouchOSC desktop, **File > Open** →
   `touchosc/dist/av-live-control.tosc`. Confirm all 3 pages render and there
   are no parse/script errors. (`open -a TouchOSC <file>` from the shell was
   observed to open an "Untitled" window — use File > Open inside the app.)
   If a layout fails to load, fix `gen/schema.py` against the schema reference
   and rebuild — no other file changes.
2. **OSC connection:** TouchOSC → Connections → OSC (UDP):
   - **Host** = `supra-m1.local` (macm1 — the SC engine host)
   - **Send port** = `57121` (the SC OSCdef port)
   - **Receive port** = `9000` (matches `~toscPort` in `touchosc_feedback.scd`)
   - Ensure the layout targets **Connection 1** (`CONN_DEFAULT="00001"`).
3. **Control smoke test:** with the SC engine running on macm1 (boot the
   data-only patch), enter play mode, tap pads and move the tempo / a volume
   fader. Watch the macm1 sclang post window for `/launch`, `/launch/tempo`,
   `/launch/vol` and confirm audio responds.
4. **Feedback check:** armed pads light, the beat box flashes, the master VU
   moves, and selecting a rhythm/melody preset loads its steps + name into the
   editor widgets.

## Deploy to the iPad

1. Get `dist/av-live-control.tosc` onto the iPad (AirDrop, or TouchOSC document
   sync / iCloud).
2. On the iPad, set the same OSC connection: host `supra-m1.local`, send
   `57121`, receive `9000`.
3. Confirm landscape canvas. Default canvas is **1194×834** (iPad 11"/Air) with
   proportional anchoring; if your model differs, set `CANVAS` in
   `gen/layout.py` and rebuild.

## OSC contract (engine routes are reused unchanged)

Control (surface → SC, port 57121): `/launch <name> <0|1>`,
`/launch/vol <name> <0..1.5>`, `/launch/tempo <60..200>`, `/launch/clear`,
`/control/fx/{filter,stutter,crash,kick,swell,breakdown}`,
`/control/harmony/{root(±delta),scale(name),octave(0..2),phrase(0..3)}`,
`/control/concertNext`, `/control/doScene <play|concert|all>`,
`/seq/{melody,rhythm} <idx>`, `/seq/{melody,rhythm}/set ...`,
arm sequencers via `/launch melseq|rhythmseq <0|1>`.

Feedback (SC → surface, port 9000, all created by `touchosc_feedback.scd`):
`/armed/<name> <0|1>`, `/sync/beat <1>`, `/sync/rms <amp>`,
`/seq/rhythm/state <idx> <k> <s> <h> <name>`,
`/seq/melody/state <idx> <degrees...>`.

## Known limitations / pending

- **Visual fidelity gate** (step 1 above) is the one check not automatable here;
  confirm it on GrosMac before relying on the layout.
- **Lua API** (Hexler control API: `onReceiveOSC`, `sendOSC`, `Color()`,
  `self.children`, `table.unpack`, GRID dimension props) is verified at the
  fidelity gate; each script carries an `API verified on GrosMac` marker. If a
  script errors in the editor console, adjust against the TouchOSC manual.
- **Per-voice VU** (spec §4) is **deferred**: the data-only engine sums all
  voices to bus 0, so per-voice live levels are not producible without
  re-routing the audio. The master RMS VU + beat + per-pad armed reflection
  cover the live-feedback need.
