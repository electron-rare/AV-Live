# Web OSC control surface (GrosMac → macm1 concert)

Date: 2026-06-27
Status: design approved (web · patterns + concert control · target macm1)
Scope: `web_realart/` (Node bridge + web UI) + `sound_algo/data_only/` (SC launchpad + control OSC)

## Goal

From a browser on GrosMac (or a tablet/phone on the LAN), a control surface that
(a) **launches** a bank of musical patterns/sequences/melodies and (b) **controls
the running concert** (next morceau, harmony, master FX) — all over OSC into the
**macm1** SC engine, layered on the live body-driven concert (same audio out).

## Architecture

```
Browser (GrosMac/tablet)  ⇄ WebSocket ⇄  Node server (GrosMac, extends web_realart)
                                              │  OSC/UDP
                                              ▼
                                    macm1 SC  supra-m1.local:57121
```

- The Node server bridges WebSocket ⇄ OSC. Each UI control sends a `{addr, args}`
  JSON message; the server forwards it as an OSC packet to `AVLIVE_SC_HOST`
  (default `supra-m1.local`) port `57121`. mDNS hostname → DHCP-resilient.
- The concert + patterns play on macm1's audio. GrosMac is only the surface.

## A. SC launchpad (`sound_algo/data_only/launchpad.scd`, new, loaded last by boot)

A bank of **launchable** elements, each a `Pdef` armed/disarmed by OSC, all on a
shared `~lp[\clock]` (TempoClock, permanent, default 126 bpm) and — for pitched
ones — reading `~ccNote`/`~ccHarmony` (so they sit in the body-conducted key).

| name | kind | content |
|------|------|---------|
| `kick` | drums | 4-on-the-floor |
| `hats` | drums | offbeat / 16th hats |
| `clap` | drums | backbeat 2 & 4 |
| `perc` | drums | syncopated percussion |
| `sub` | bass | sustained root `~ccNote.(0,-1)` |
| `acid` | bass | 303-style 16th sequence over `~ccNote` degrees + accent/slide |
| `arp` | melody | 16th arpeggio over `~ccNote` chord tones |
| `lead` | melody | sparse melodic phrase from `~ccNote` |
| `stab` | chords | offbeat chord stab, `~ccNote` triad |
| `pad` | chords | sustained chord, `~ccNote` triad, timbre by `~ccHarmony[\pad]` |

Each pattern uses its own `\lp_<name>` SynthDef (one-shots `doneAction:2`; the pad
gated, released on disarm). `Out.ar(0,…)` → through the existing FX rack.

OSC (one OSCdef each, all guarded):
- `/launch <name> <0|1>` — arm (`Pdef(\lp_<name>).play(~lp[\clock])`) / disarm
  (`.stop`, pad lifts its gate). Unknown name → ignored.
- `/launch/tempo <bpm>` — `~lp[\clock].tempo = bpm/60` (clamp 60–200).
- `/launch/clear` — disarm all patterns.

`~lp[\armed]` (Set) tracks armed names so the UI can be re-synced and `clear` works.

## B. Concert / harmony / FX control OSC (in `launchpad.scd`, after the patterns)

Reuse the concert handles (`~ccHarmony`, `~ccNote`, `~ccMaster`, `~ccFire` from
`scene_concert.scd` + `concert_fx.scd`; load launchpad AFTER them). New OSCdefs:

- Concert: `/control/concertNext` (exists), `/control/doScene <name>` (exists).
- Harmony: `/control/harmony/root <delta>` (`~ccHarmony[\root]` += delta, clip
  33–57) · `/control/harmony/scale <name>` (set `~ccHarmony[\scale]`, validated
  against `~ccScales`) · `/control/harmony/octave <0|1>` · `/control/harmony/phrase <0–3>`.
- FX: `/control/fx/filter <0–1>` (`~ccMaster[\filterTo].(val.linexp(0,1,120,20000),0.2)`)
  · `/control/fx/stutter` (`~ccMaster[\stutterOn].(0.9)`) · `/control/fx/crash|kick|swell`
  (`~ccFire`) · `/control/fx/breakdown <0|1>` (1 → `filterTo(450,1.0)`, 0 → `filterTo(20000,1.5)`).

All nil-guard their handles (`~ccMaster !? {…}`) so launchpad still loads in tests
without the full concert.

## C. Node bridge (extend `web_realart/server.js`)

- Serve a new static page `public/control.html` (+ `control.js`, `control.css`).
- A WebSocket endpoint: on `{addr, args}` JSON, send an OSC message to
  `AVLIVE_SC_HOST:57121` (reuse web_realart's existing OSC client/lib; add a sender
  to the SC host if it only targets oscope today).
- Env: `AVLIVE_SC_HOST` (default `supra-m1.local`), `AVLIVE_SC_PORT` (default 57121).
- Keep the existing feeds functionality intact (additive only).

## D. Web UI (`web_realart/public/control.html` + `control.js` + `control.css`)

Single dark page, large touch targets, sections:
- **Patterns** — a toggle pad per element (lit = armed), grouped drums / bass /
  mélodies / accords. Click → `/launch <name> <0|1>`. A "Tout couper" → `/launch/clear`.
- **Concert** — "Morceau suivant" (`/control/concertNext`), scene buttons
  (`/control/doScene`), tempo slider (`/launch/tempo`).
- **Harmonie** — root −/+ (`/control/harmony/root ∓2`), scale buttons
  (minor/dorian/phrygian/penta), octave toggle, phrase 0–3.
- **FX** — filter fader (`/control/fx/filter`), one-shot pads stutter / crash /
  kick / swell, breakdown toggle.

Pad armed-state is tracked client-side (the SC engine is fire-and-forget). A small
"connecté / déconnecté" indicator on the WebSocket.

## Testing

- **SC** (headless on GrosMac, server output-only, no `timeout` → background+kill):
  balance `P:0 B:0 TLB:1`; load `launchpad.scd` after engine+fx+concert; assert the
  10 `\lp_*` SynthDefs compile and `~lp` exists; fire `/launch acid 1` (+ a synthetic
  `~ccHarmony`) and assert `Pdef(\lp_acid).isPlaying`; `/launch acid 0` stops it;
  `/launch/clear` empties `~lp[\armed]`; `/control/harmony/root 2` bumps the root;
  `/control/fx/crash` runs without error. No live-audio assertion (tuned at smoke).
- **Node** (vitest/node): a WS `{addr:"/launch",args:["kick",1]}` produces one OSC
  packet addressed to the configured host:port (mock the UDP socket).
- **Web UI**: manual — open `http://grosmac.local:<port>/control.html`, click pads,
  confirm OSC reaches macm1 SC (engine posts on `/launch`).
- **Live smoke**: GrosMac browser → arm drums + acid + arp, change harmony + fire
  FX, with the body-concert running on macm1; tune levels/tempo by ear.

## Out of scope (later, additive)

- Per-pattern level faders, pattern variations/fills, a step-sequencer grid editor,
  MIDI-clock sync, saving/recalling pad scenes. All add OSC routes + UI without
  touching the bridge contract.

## Implementation note (for the plan)

Decompose: (1) SC launchpad SynthDefs + `~lp` clock/registry + `/launch` arm/disarm
+ tempo/clear (drums first, pitched second). (2) Concert/harmony/FX control OSCdefs.
(3) Node WS⇄OSC bridge to macm1 (extend server.js, env host/port). (4) Web UI page
(patterns + concert + harmony + FX). (5) Live smoke. Each SC/Node step headless-
testable; UI + audio tuned at the smoke.
