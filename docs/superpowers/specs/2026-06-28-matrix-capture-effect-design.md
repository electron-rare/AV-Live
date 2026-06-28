# Matrix capture→effect per-voice modulation — design

Date: 2026-06-28
Status: approved (brainstorming), pending implementation plan
Scope: `sound_algo/data_only/matrix.scd` + `web_realart/public/control/`
Companion spec: `2026-06-28-matrix-instrument-selection-design.md` (the left-side
instrument menu). This spec is the **right-side menu**: bind a body-capture
source to an audio-effect parameter, per matrix voice.

## Goal

Let the performer's body modulate individual matrix voices: per voice, bind a
continuous capture-derived source (e.g. right-hand height, hand openness, hand
speed) to a per-voice effect parameter (cutoff / amp / pan), with a per-voice
depth amount. Movement then drives that instrument's effect live.

## Decisions (from brainstorming)

- **Free menu** per voice: choose the source AND the target, plus a **depth
  slider** per row.
- Targets are **curated per voice** by what the voice's SynthDef actually
  exposes (no per-voice audio bus exists — all voices sum to bus 0 — so only
  Pbind-level synth args are modulatable per voice; global FX like reverb/master
  filter are out of scope here).
- Modulation is **per-event** (sampled at note-on via Pfunc). Continuous
  within-a-held-note modulation (node `.set` at 30 Hz) is future work.
- SC owns the binding state and the source readers; the web is a surface.

## Approach

**Per-event Pfunc injection into the `~matVariation` overlay** — the same Pchain
overlay that already carries the glow (`\matGlow`) and the instrument override
(companion spec). When a voice has a mod binding, the overlay Pbind gains the
target key as a `Pfunc` that reads the live source value and computes the param.
No new audio bus, no per-voice node tracking.

Rejected: continuous node `.set` (true within-note modulation but needs
per-event node capture + a 30 Hz updater per voice — fragile with Pdef; future).
Global-FX-only routing (loses per-instrument independence — rejected in
brainstorming).

## Capture sources (curated, continuous, normalized 0..1, ~30 Hz)

All already received by SC from `data_only_viz` over OSC (`/pose/*`,
data_feeds.scd) and stored in env dicts. `~matModSourceVal.(key)` returns the
live scalar, clamped to 0..1 and lag-smoothed. The plan resolves exact dict
fields from `data_feeds.scd` (`/pose/hands` handler ~line 502, `/pose/center`
~536). Exposed source keys:

| key | meaning | origin |
|-----|---------|--------|
| `lHandY` / `rHandY` | left/right hand height (raised = 1) | /pose/hands |
| `lOpen` / `rOpen` | left/right hand openness | /pose/hands |
| `handSpeed` | max(left,right) hand speed | /pose/hands |
| `handDist` | distance between hands | /pose/hands |
| `bodyY` | body-center height (raised = 1) | /pose/center |
| `depth` | shoulder-span depth proxy (scaled to 0..1) | /pose/sho_span |

`none` (no source) disables the binding.

## Effect targets (curated per voice by SynthDef args)

| target | reachable voices | reason |
|--------|------------------|--------|
| `amp` | all 16 | every synth takes `\amp` |
| `cutoff` | acid, arp, lead, stab, pad | synth has a `\cutoff` arg |
| `pan` | acid, arp, lead, stab | synth has a `\pan` arg |

Drum/textural voices (kick, hats, clap, perc, ride, rim, tom, sub, reese, bells,
sweep) expose only `amp`. `none` (no target) disables the binding.

## Depth mapping (per target, scaled by the per-row depth `d` in 0..1)

Let `s` = the live source value (0..1).
- **cutoff**: exponential blend from the voice's neutral cutoff `c0` toward a
  full 200..6000 Hz sweep: `out = c0 * (mapped/c0) ** d`, where
  `mapped = s.linexp(0, 1, 200, 6000)`. `d=0` → neutral, `d=1` → full sweep.
- **amp**: multiplier `m = (1 + d * (s*2 - 1)).max(0)` applied to the voice's
  amp. `d=0` → unchanged; `s=0.5` → unchanged; `s=1` → `+d`; `s=0` → `-d`.
- **pan**: `out = (s*2 - 1) * d`. `d=0` → centered; `d=1` → full -1..1 excursion.

Glow stays the FIRST overlay key so it reads the base note velocity before any
mod/variation `\amp` override (glow shows the note; mod shows the body).

## Architecture & data flow

```
Web per voice row (right side): <select source> <select target> <range depth>
        └─/matrix/mod <vi:i> <source:s> <target:s> <depth:f>─→ matrix.scd OSCdef
              ~matMod[vi] = (source, target, depth)  (validated; echo for web sync)
                                     ▼
  ~matApplyBar → ~matVariation overlay: if ~matMod[vi] set, add the target key
     \cutoff|\amp|\pan, Pfunc { compute from ~matModSourceVal.(source) and depth }
                                     ▼
  /matrix/mod feedback relayed (server.js "/matrix/" prefix) → web sync
```

## Components

### SC (`sound_algo/data_only/matrix.scd`)

- `~matMod` — `Array.fill(~matVoices.size, nil)`; each entry nil or
  `(source: \rHandY, target: \cutoff, depth: 0.7)`. nil-guarded/idempotent.
- `~matModSourceReaders` — IdentityDictionary source-key → `{ live 0..1 scalar }`
  reading the capture dicts; `~matModSourceVal.(key)` applies clamp(0,1) + a lag
  (`~matModLag`, e.g. 0.1 s, via a stored `.lag`-style smoother or a simple
  one-pole on each sampled read).
- `~matModTargets` — IdentityDictionary voice-name → array of valid target
  symbols (`[\amp]` for drums; `[\amp,\cutoff,\pan]` / `[\amp,\cutoff]` for the
  filter voices) used to reject invalid `/matrix/mod` target for a voice.
- `~matApplyMod.(vi, sourceOrNil, targetOrNil, depth)` — validate (target in the
  voice's allowed set, source in the source list, depth clipped 0..1); set/clear
  `~matMod[vi]`; force a re-source of that voice; echo `/matrix/mod`.
- `~matVariation.(name, color, vi)` — extended: when `~matMod[vi]` is set, append
  the target key (`\cutoff`/`\amp`/`\pan`) to the overlay Pbind as a `Pfunc` using
  the depth mapping above. `\matGlow` remains first; the mod `\amp` (if any) is
  appended AFTER the variation `\amp` so it scales the final value.
- OSCdef `\mat_mod` on `/matrix/mod` (args: vi:i, source:s, target:s, depth:f;
  empty string / "none" → nil).

### Bridge (`web_realart/server.js`)
- No change (`/matrix/mod` matches the existing `/matrix/` prefix).

### Web (`web_realart/public/control/`)
- Per voice row, right side: a source `<select>`, a target `<select>` (populated
  from that voice's allowed targets), and a depth `<input type="range">`.
- On any change → `send("/matrix/mod", vi, source, target, depth)`; persist to
  localStorage (alongside the matrix grid + instrument state).
- WS handler for `/matrix/mod <vi> <source> <target> <depth>` → reflect the three
  controls (so echoes and cross-client edits sync).
- A small pure helper for the depth-mapping preview is optional; the authoritative
  mapping lives in SC.

## Error handling / robustness

- `/matrix/mod` with an out-of-range `vi`, a target not allowed for that voice, or
  an unknown source → ignored on the SC side; `depth` clipped to 0..1.
- Missing/stale capture (no pose data) → `~matModSourceVal` returns a safe
  neutral (0 for speed/excursion-style, 0.5 where centered makes sense); the
  voice still plays at its un-modulated value.
- Re-source on binding change is quantized like color/instrument changes.
- nil-guarded, idempotent reload.

## Testing

- **SC** (`data_only/test/test_matrix.scd`, headless, P:0 B:0):
  - `~matMod` initialized to 16 nils; `~matModTargets`/source list defined.
  - `~matApplyMod.(5, \rHandY, \cutoff, 0.7)` sets the binding and echoes
    `/matrix/mod` (assert via the `~toscSend` stub).
  - A target not allowed for a voice (e.g. `\cutoff` on `kick`) is rejected
    (state unchanged).
  - `~matModSourceVal.(key)` returns a value clamped to 0..1 for stubbed dict
    inputs out of range.
  - With a binding set, consuming a `~matVariation` stream produces an event
    carrying the target key (extends the existing stream-consumption test).
- **Web**: manual — source/target/depth controls populate per voice, change →
  OSC, echo sync; move the bound body part and hear the effect track it.
- **Manual integration**: with the capture pipeline live, bind
  `acid: rHandY → cutoff (depth 0.7)`, raise the right hand, hear the acid filter
  open in time with the hand.

## Out of scope

- Continuous within-note modulation (node `.set` at 30 Hz) — future.
- Global FX targets (reverb, master filter) per row; new capture sources;
  bipolar/inverted source curves; modulating instrument choice itself.
- The left-side instrument menu and kits (companion spec).
