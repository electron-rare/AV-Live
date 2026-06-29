# Per-voice modulation/pose + expanded iPhone sources + FR names

**Date**: 2026-06-29
**Status**: design approved, pending implementation plan
**Scope**: matrix sequencer modulation/pose binding system, iPhone-derived
value routing, web voice editor MOD/POSE tabs, FR display-label layer, live
value visualization.

## Context

The matrix sequencer (`sound_algo/data_only/matrix.scd`, 22 voices × 64 bars,
6 colours/voice) already supports:

- **Per-colour modulation** binding: one `(source, target, depth)` per
  colorDef, applied live via `~matModPairs` / `~matVariation`.
- **Per-colour pose** bindings: list of `(poseId, action)` where action is
  `trigger` (re-source the colour and play) or `gate` (toggle the Pdef).
- **11 modulation sources** in `~matModCache`, fed by only 3 OSC routes:
  `/pose/hands` → `lHandX/Y, lOpen, handSpeed, rHandX/Y, rOpen, handDist`;
  `/pose/center` → `bodyX, bodyY`; `/pose/sho_span` → `depth`.

`data_only_viz/pose_bridge.py` already emits many more iPhone-derived signals
to SC (`127.0.0.1:57121`) that the matrix ignores: `/pose/kin [speed, accel,
symmetry]`, `/pose/head [x, y, c]`, `/pose/limb_span [span]`, `/pose/action
[idx, p0, p1, p2]` (debout/assise/danse), `/pose/finger [hand, finger,
strike_speed, z, tipx, tipy]`, `/pose/pinch [hand, finger]`. `mouth_open` is
computed (`action_head`) but not yet emitted.

The web voice editor (`web_realart/public/control/js/voice-editor.js`) has a
MOD/POSE tab that mirrors the per-colour model: source × target × depth (one
binding) + free-text `poseId` list.

### Problems addressed

1. **Most iPhone values are unusable as instrument modulation** — kinetics,
   action, head, limb span, mouth are produced but never reach the mod cache.
2. **Association is per-colour and single-binding** — awkward to drive live
   (132 slots, one mod each), no additive layering.
3. **Names are cryptic** (`lHandY`, `depth`) and poses are free-text, with no
   live feedback of incoming values to guide mapping.

## Decisions (from brainstorming)

- **Granularity**: modulation and pose bindings move from **per-colour** to
  **per-voice (instrument)**. A voice's bindings apply to all 6 of its colours.
  STEPS and SYNTH-FX tabs stay per-colour.
- **Binding model**: **free additive list** per voice (add/remove rows). Two
  bindings may target the same param; contributions sum then clip.
- **Discrete vs continuous**: continuous iPhone values become new modulation
  sources; discrete events (finger strike, pinch, action label) stay in the
  POSE trigger/gate system.
- **Names**: **display-label layer** — technical IDs stay on the wire and in
  presets; the web UI shows FR labels. No rename in SC or presets.
- **Poses**: **curated dropdown + custom** — standardized event names
  (finger strikes, pinch, danse/debout/assise) plus a free-text fallback.

## Architecture

### 1. SC data model (`matrix.scd`)

Replace per-colour mod/pose with per-voice state:

```supercollider
~matVoiceMods  = ();   // voice(symbol) -> Array of (source:, target:, depth:)
~matVoicePoses = ();   // voice(symbol) -> Array of (poseId:, action:)
```

- `colorDef[\mod]` and `colorDef[\pose]` are **deprecated**. On preset/save
  load, legacy per-colour bindings are migrated: for each voice, collect the
  bindings present across its 6 colours and dedup into the voice-level list
  (mod: dedup by `target`, keeping the first non-nil; pose: dedup by
  `(poseId, action)`).
- `~matModPairs` / `~matVariation` change to read `~matVoiceMods[voice]`
  instead of the active colorDef's `\mod`.

**Additive application** (per voice, per target param):
- Group the voice's bindings by `target`.
- Each binding contributes a delta in the target's modulation space:
  - `pan`:  Σ `(src*2 - 1) * depth`, clipped to `-1..1`.
  - `rev`:  Σ `src * depth`, clipped to `0..1`.
  - `amp`:  product of `(1 + depth*(src*2-1)).max(0)` over bindings.
  - `cutoff`: log-space — `c0 * Π (linexp(src,0,1,200,6000)/c0).pow(depth)`,
    i.e. the existing single-source formula multiplied per binding.
- Targets with no binding keep their colorDef value unchanged.
- Only targets allowed by `~matModTargets[voice]` are honored; the web UI
  filters the param dropdown accordingly, and SC ignores out-of-range targets.

### 2. New continuous sources (SC OSCdefs → `~matModCache`)

All from routes `pose_bridge.py` already emits (zero data_only change):

| OSC route | New source(s) | 0..1 mapping |
|-----------|---------------|--------------|
| `/pose/kin [pid, speed, accel, sym]` | `bodyVitesse`, `bodyAccel`, `bodySym` | `speed/KIN_SPEED_MAX`, `accel/KIN_ACCEL_MAX` (clip 0..1); `sym → (sym+1)/2` |
| `/pose/head [pid, x, y, c]` | `headX`, `headY` | `headX = x`; `headY = 1 - y` |
| `/pose/limb_span [pid, span]` | `limbSpan` | `span * LIMB_SPAN_GAIN` (clip 0..1) |
| `/pose/action [pid, idx, p0, p1, p2]` | `danse` | `danse = p2` (probability, continuous) |
| `/pose/mouth [pid, open]` *(new emit)* | `mouthOpen` | `open` (clip 0..1) |

Normalization constants (`KIN_SPEED_MAX`, `KIN_ACCEL_MAX`, `LIMB_SPAN_GAIN`)
are defined as env-vars in `matrix.scd` with sensible defaults so they can be
tuned without code edits. Stale handling: `~matModCache` entries decay/clamp;
if a person leaves (`/pose/leave`), continuous body sources relax toward
neutral (no hard reset mid-performance).

**`mouthOpen`** requires one new emit `/pose/mouth [pid, open]` in
`pose_bridge.py`, exposing the already-computed `mouth_open` scalar. This is
the only `data_only_viz` change — routing an existing value, not detection.

Total sources after this change: 11 existing + `bodyVitesse, bodyAccel,
bodySym, headX, headY, limbSpan, danse, mouthOpen` = **19**.

### 3. Pose/event system (per-voice trigger/gate)

New SC OSCdefs map discrete events to canonical `poseId` symbols, then call
`~matPoseFire` (which now iterates `~matVoicePoses` and fires matching voices):

| Route | Canonical poseId |
|-------|------------------|
| `/pose/finger [0, hand, finger, ...]` | `fingerL1..fingerL5`, `fingerR1..fingerR5` (finger 0..4 → 1..5) |
| `/pose/pinch [0, hand, finger]` | `pinchL1..pinchL4`, `pinchR1..pinchR4` |
| `/pose/action [pid, idx, ...]` | `debout` / `assise` / `danse` — fired on label change |

`~matPoseFire(poseId)` iterates all voices; for each voice whose
`~matVoicePoses` contains a matching `poseId`, applies the bound action at the
voice's current colour. The canonical event list is shared with the web UI.

### 4. Display-label layer (web)

New entries in `matrix-state.js`:

```js
export const MOD_SOURCE_LABELS = {
  none: "—",
  lHandY: "Main G ↕", rHandY: "Main D ↕",
  lHandX: "Main G ↔", rHandX: "Main D ↔",
  lOpen: "Main G ouvert", rOpen: "Main D ouvert",
  handSpeed: "Vitesse mains", handDist: "Écart mains",
  bodyX: "Corps ↔", bodyY: "Corps ↕", depth: "Profondeur",
  bodyVitesse: "Vitesse corps", bodyAccel: "Accél. corps",
  bodySym: "Symétrie", headX: "Tête ↔", headY: "Tête ↕",
  limbSpan: "Envergure", danse: "Danse (proba)",
  mouthOpen: "Bouche",
};
export const POSE_EVENT_CHOICES = [
  { id: "danse", label: "Danse" }, { id: "debout", label: "Debout" },
  { id: "assise", label: "Assise" }, { id: "pinchR1", label: "Pincement MD index" },
  // … finger strikes / pinches enumerated, + a "custom…" entry
];
```

IDs are unchanged on the OSC wire and in presets. SC stores and matches
symbols only.

### 5. Live value visualization

- SC pushes `/matrix/modvalues [v0, v1, … vN]` — the current `~matModCache`
  serialized in a **fixed source order** — at ~12 Hz via a `Routine` to the
  feedback port (→ web bridge → all WS clients).
- The fixed source order is a single source-of-truth array in `matrix.scd`,
  mirrored in `matrix-state.js`.
- Web: in the MOD tab, a small live meter next to each source value; bindings
  whose source is currently active are highlighted.

### 6. OSC routes (new / changed)

| Route | Dir | Payload | Purpose |
|-------|-----|---------|---------|
| `/matrix/voicemod` | in | `[vi, n, src1, tgt1, depth1, …]` | set full mod list for voice |
| `/matrix/voicemod/get` | in | `[vi]` | request push of voice's mod list |
| `/matrix/voicepose` | in | `[vi, n, pose1, act1, …]` | set full pose list for voice |
| `/matrix/voicepose/get` | in | `[vi]` | request push of voice's pose list |
| `/matrix/modvalues` | out | `[v0 … vN]` | live mod cache (~12 Hz) |

`/matrix/colormod` and `/matrix/colorpose` are removed as inbound editors;
legacy values are read only during preset/save migration.

### 7. Web UI (`voice-editor.js`)

- **MOD tab** → per-voice free list: rows `[source ▾][param ▾][depth slider]
  [✕]` plus `[+ ajouter]`. FR labels via `MOD_SOURCE_LABELS`. Param dropdown
  filtered by `MATRIX_MOD_TARGETS[voice]`. Live meter per row.
- **POSE tab** → per-voice list: rows `[event ▾ (curated + custom)][action ▾
  trigger|gate][✕]` plus `[+ ajouter]`.
- Both tabs now read/write **voice-level** state, independent of the selected
  colour. STEPS and SYNTH-FX remain per-colour.

### 8. Persistence + migration

- `/matrix/save` and `/matrix/load` serialize `~matVoiceMods` and
  `~matVoicePoses` per voice.
- Loading an old preset (per-colour `\mod`/`\pose`) triggers the migration in
  §1. Migration is idempotent and logged.
- `matrix_presets/generate_presets.py` + `patterns.py`: emit per-voice mod/
  pose blocks (empty by default, with a few demonstrative mappings, e.g.
  `acid: bodyVitesse → cutoff`). Regenerate and re-validate the 28 presets.

### 9. Testing

- **SC** (`test/test_matrix.scd` extended): cache updates for each new OSCdef;
  additive same-target summation/clipping; pose mapping for finger/pinch/
  action; legacy per-colour → per-voice migration; `/matrix/modvalues` shape.
- **Web** (`node --test`): `MOD_SOURCE_LABELS` coverage of all source IDs;
  per-voice state read/write; OSC payload shapes for `/matrix/voicemod` and
  `/matrix/voicepose`; `parseModValues` round-trip.
- **Manual smoke (macm1)**: boot engine + control UI, move/dance in front of
  the iPhone → live meters move, audio responds; save/load a preset and
  confirm bindings persist; load a legacy preset and confirm migration.

## Out of scope

- New detection algorithms or new computed scalars (the values already exist;
  `mouthOpen` just routes an already-computed `mouth_open` scalar).
- Changes to STEPS / SYNTH-FX tabs, the grid, transport, or the launchpad.
- TouchOSC surface parity for the new MOD/POSE layout (can follow later).

## Decided defaults

- `mouthOpen`: **kept** — first-class source via a new `/pose/mouth` emit
  (one line in `pose_bridge.py`).
- `/matrix/colormod`/`colorpose`: **removed as editors**, kept only for load
  migration.
- Normalization constants for kin/limb: **env-var defaults**, tunable live.
