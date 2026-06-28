# TouchOSC Control Surface — Design Spec

**Date:** 2026-06-28
**Status:** Approved (brainstorm) — pending implementation plan
**Topic:** Full UI/UX redesign of the SuperCollider control surface, moving from
the custom web surface (`web_realart/public/control/`) to a native **TouchOSC**
(Hexler, modern) layout that speaks OSC directly to the macm1 SC engine.

---

## 1. Motivation

The current control surface is a single-page vanilla HTML/CSS/JS app
(`web_realart/public/control/`, ~388 LOC) served at
`http://supra-m1.local:4400/control/`. It works but:

- Everything is stacked on one scrolling page; not optimized for touch.
- No live feedback from the engine (SC already emits `/sync/beat`, `/sync/rms`,
  `/sync/amp`, step data — none of it is reflected in the UI).
- The browser cannot send UDP, so it requires a Node/WebSocket→OSC bridge hop.

TouchOSC is purpose-built for live touch control surfaces and removes these
limitations: it speaks OSC/UDP **directly** to SC (no Node bridge for control),
supports **bidirectional feedback**, native **pages/tabs**, dedicated widgets
(XY pads, grids, faders), and **Lua** scripting for dynamic logic.

## 2. Locked decisions

| Topic | Decision |
|-------|----------|
| Direction | **TouchOSC integral** — the web `/control/` surface is retired as a control method. |
| Play device | **iPad, landscape**. |
| Authoring/validation | **TouchOSC desktop on GrosMac** (open generated `.tosc`, screenshot, OSC smoke-test to macm1). |
| App version | **New TouchOSC (Hexler)** — required for Lua + bidirectional OSC feedback. |
| Build method | **Generate `.tosc` by code** (gzipped XML), versioned in the repo, iterated by diff. |
| Preset naming | Names live in `launchpad.scd`; SC pushes names to TouchOSC as label feedback. On device: **select + edit steps only**, no text entry. |
| Feedback scope | **Full suite** — beat flash, master RMS meter, armed-state reflection on pads, sequencer playhead + per-voice VU. |
| Canvas | Default **1194×834** (iPad 11"/Air) with **proportional anchoring** (responsive); exact model confirmed at test time. |
| Web stack | `web_realart` server **stays** for visual sync (Hydra/WebGL). Only the `/control/` UI role is retired. |

## 3. Architecture & topology

```
TouchOSC (iPad in play / GrosMac in authoring)
   │  OSC/UDP  ──►  macm1 : <SC OSCdef port, 57121 today>     (control)
   ▼
SuperCollider engine on macm1 (launchpad.scd + concert)
   │  OSC/UDP  ──►  <sender IP> : <TouchOSC listen port, 9000 default>  (feedback)
```

- **Control path:** TouchOSC sends the existing OSC routes directly to macm1.
  All current `OSCdef`s are reused unchanged.
- **Feedback path:** a new SC file captures the sender `NetAddr` from incoming
  control messages (`~tosc = addr`) and targets feedback at that address. The
  feedback therefore **follows whoever is controlling** — GrosMac during
  authoring, iPad during the live set — with **no static IP** to configure.
- The existing `web_bridge.scd` → Node sync feeds (`/sync/*` for Hydra/WebGL)
  are **unchanged**; TouchOSC feedback is an additional, parallel send.

## 4. Page layout (3 pages, TouchOSC pager)

### Page 1 — LIVE (primary performance page)
- **Top bar:** master **tempo** fader/encoder + BPM readout · **CLEAR ALL**
  button · **master RMS** VU meter · global **beat-flash** indicator.
- **4×4 grid of 16 pads.** Each pad = arm/disarm button + small vertical
  **volume** fader + **label** (pattern name) + **armed-state feedback** (lit on
  SC confirmation, tracks concert-driven changes).
- Pattern set (from `launchpad.scd`): kick, hats, clap, perc, sub, acid, arp,
  lead, stab, pad, ride, rim, tom, reese, bells, sweep.

### Page 2 — FX / HARMONIE / CONCERT
- **FX:** filter cutoff (large fader 0–1, or XY) · 6 one-shots: stutter, crash,
  kick, swell, breakdown↓, breakdown↑.
- **Harmonie:** root −/+ · scale radio (minor/dorian/phrygian/penta) · octave
  −/+ · phrase radio (0–3).
- **Concert:** morceau suivant · scène concert · body-play.

### Page 3 — SÉQUENCEURS
- **Rhythm:** 8 preset selectors (radio, names pushed by SC) · **3×16 grid**
  (K/S/H rows) of toggles → Lua assembles three 16-char strings →
  `/seq/rhythm/set` · **playhead** column highlight.
- **Melody:** 8 preset selectors (names from SC) · **8 vertical faders** (one per
  step, quantized to integer degrees −7..14) + value label → Lua →
  `/seq/melody/set` · playhead · arm-melody button.
- **Per-voice VU** strip: kick/hat/snare/clap/perc/melody/acid/harmony
  (via `/sync/amp`).

## 5. OSC mapping (reuses existing SC routes — no route changes)

**Control (TouchOSC → SC):**

| Widget | Address | Args |
|--------|---------|------|
| Pad arm | `/launch` | `<name> <0\|1>` |
| Pad volume | `/launch/vol` | `<name> <0..1.5>` |
| Tempo | `/launch/tempo` | `<bpm>` |
| Clear all | `/launch/clear` | — |
| FX filter | `/control/fx/filter` | `<0..1>` |
| FX one-shots | `/control/fx/{stutter,crash,kick,swell,breakdown}` | `<0\|1>` |
| Harmony | `/control/harmony/{root,scale,octave,phrase}` | varies |
| Concert | `/control/concertNext`, `/control/doScene` | — |
| Seq select | `/seq/melody`, `/seq/rhythm` | `<idx>` |
| Seq edit | `/seq/melody/set`, `/seq/rhythm/set` | degrees / `<k> <s> <h>` |

**Feedback (SC → TouchOSC):**

| Source | Address | Effect on TouchOSC |
|--------|---------|--------------------|
| Arm/disarm (incl. concert) | `/armed/<name>` `<0\|1>` | Pad lit/unlit |
| Beat | `/sync/beat` | Global flash |
| Master level | `/sync/rms` | Master VU |
| Per-voice level | `/sync/amp` | Per-voice VU |
| Step position | step index (TBD address) | Sequencer playhead |
| Preset selection/edit | `/seq/{rhythm,melody}/state` + name | Grid/faders + name labels reflect selected preset |

## 6. SC-side additions

New file `sound_algo/data_only/touchosc_feedback.scd`, loaded after
`launchpad.scd` (nil-guarded, inert at load like the other data_only files):

1. **Sender capture:** on any inbound control message, store `~tosc = addr`.
2. **Armed broadcast:** emit `/armed/<name> <0|1>` whenever a pattern arms or
   disarms, including when driven by the concert/morceau engine (not just by
   TouchOSC), so the surface stays in sync.
3. **Sequencer state:** on `/seq/*` select and on edit, send
   `/seq/rhythm/state` (k/s/h strings) and `/seq/melody/state` (degrees) plus
   the preset **name**, so selecting a preset loads its steps and label into the
   editor.
4. **Sync relay:** mirror `/sync/beat`, `/sync/rms`, `/sync/amp`, and the step
   index to `~tosc` (in addition to the existing Node sends).

## 7. Lua responsibilities (TouchOSC side)

- **Pad logic:** toggle → `/launch`; receive `/armed/*` → set pad color/state.
- **Rhythm grid:** on any cell change, read the 3×16 grid → build three
  16-char strings → `/seq/rhythm/set`.
- **Melody faders:** on change, read 8 faders → quantize to int degrees →
  `/seq/melody/set`.
- **Preset select:** send index, then apply `/seq/*/state` from SC onto the
  grid/faders and update name labels.
- **Feedback receivers:** beat→flash, rms→master VU, amp→per-voice VU,
  step index→playhead highlight.

## 8. Build & validation workflow (GrosMac loop)

1. **Format-fidelity probe:** generate a minimal 1-widget `.tosc`, open it in
   TouchOSC on GrosMac to confirm the generated gzip-XML loads correctly
   **before** building the full layout.
2. **Full build:** generate the complete `.tosc` (widgets + OSC + Lua).
3. **Visual check:** open in TouchOSC on GrosMac, screenshot, verify layout.
4. **OSC smoke-test:** from GrosMac TouchOSC, send to macm1 SC; confirm SC
   reacts and feedback lights the surface.
5. **Deploy:** load on the iPad for the live set.

## 9. Out of scope (YAGNI)

- On-device preset text entry (names live in code).
- Deleting `web_realart` or its visual-sync feeds.
- New SC instruments/patterns (the 16 existing patterns are the set).
- Cross-device preset sync / server-side persistence.

## 10. Open parameters & risks

- **Canvas size:** default 1194×834 with proportional anchoring; confirm iPad
  model at test time.
- **`.tosc` format fidelity:** generating gzip-XML by hand carries a risk the
  current TouchOSC rejects it; mitigated by the step-1 probe on GrosMac.
  `tosclib`/`touchosc-generator` are references only (inactive, unaffiliated
  with Hexler).
- **SC OSCdef / TouchOSC ports:** control port assumed 57121 (current);
  TouchOSC listen port assumed 9000 (default) — both confirmed/parameterized
  during implementation.
- **Lua complexity:** the grid→string and state round-trip are the main Lua
  surface; keep scripts small and per-widget where possible.
