# Design — Hand-driven modulation of the `data_only` subsystem

**Date:** 2026-06-26
**Status:** Approved (brainstorming) — ready for implementation plan
**Scope:** Vertical slice "hands end-to-end" of the AV-Live body→mesh→sound loop

## 1. Goal

Turn the performer's **hands** into an expressive control signal that modulates
the running `data_only` material — sculpting the existing FX/scene rather than
generating new notes — and that **visibly** drives the Metal scene at the same
time. One hand-feature vector, computed once in Python, feeds both the audio
(SuperCollider) and the visual (Metal shader). The coupling is therefore
guaranteed coherent and is legible to the audience because the scene reacts to
the same gesture the sound does.

This slice is the first increment of a larger roadmap (body → mesh → sound).
The objective behind it is twofold: **coupling quality** (gesture reads richly
and legibly into both ends) and **reliability** (solidify the existing plumbing
along the way). There is no performance deadline.

## 2. Non-goals (explicitly out of this slice)

- No dense MANO/HaMeR hand mesh — HaMeR stays a scaffold; hands are represented
  by the existing 21 MediaPipe landmarks.
- No note/melody/harmony generation — modulation only.
- No routing to the main live engine (tracks A–W, `01_live.scd`) — we stay in
  the autonomous `data_only` subsystem.
- No articulated LBS rigging.
- No iPhone hands — `ARBodyTrackingConfiguration` does not provide hand joints;
  hand capture is MediaPipe on the Mac only.

These are deliberate widenings for later increments.

## 3. Architecture — one signal, two consumers

```
multi.py  (MediaPipe HandLandmarker, 21 lm/hand)            [exists]
   └─ state.persons_hands / persons_hands_ids               [exists, state.py:104,113]
   └─ state.left_hand_kp / right_hand_kp / hands_present     [exists, state.py:90-93]
        │
   HandFeatureExtractor                                       [NEW]
   (mirrors FeatureExtractor.kinetics, action_head.py:118-132)
        │  per hand: cx, cy, openness, speed   +  two-hand distance
        │
        ├──► pose_bridge.py  →  OSC /pose/hands  ──► SC OSCdef ~handFeat ──► audio
        │      (PoseSoundBridge, pose_bridge.py:80, SimpleUDPClient :57121)
        │
        └──► renderer.py _update_uniforms (renderer.py:251-299)
               →  SceneUniforms  ──► scene.metal  ──► visual
                  (struct scene.metal:18-39; hand uniforms already at 15-18)
```

The extractor is the single source of truth. Audio and visual both subscribe to
its output; neither recomputes hand kinematics.

## 4. Components

### 4.1 `HandFeatureExtractor` (Python, NEW)

- **Location:** new module in `data_only_viz/` (e.g. `hand_features.py`), or a
  class added next to `FeatureExtractor` in `action_head.py`. Decision deferred
  to the plan; it must not bloat `multi.py`.
- **Input:** `state.persons_hands[i]` (list of 21 `PoseKp(x,y,z,c)`,
  `x,y` normalized [0,1]) with stable ids from `state.persons_hands_ids`.
- **Per-hand features:**
  - `cx, cy` — centroid of the 21 landmarks (more stable than the wrist alone).
  - `openness ∈ [0,1]` — finger spread: distance(thumb_tip, pinky_tip) divided
    by a hand-size normalizer (e.g. wrist→middle-MCP distance), clamped 0..1.
    Calibrated so a closed fist → ~0, a flat open hand → ~1.
  - `speed` — norm of centroid velocity over a per-hand ring buffer (5 frames),
    following the `kinetics` pattern (diff of stacked frames, mean norm).
- **Aggregate feature:**
  - `dist` — normalized distance between the two hand centroids (0 = together,
    1 = arms wide); 0 when only one hand is present.
- **Ring buffer:** per-hand-id deque (~5 frames), mirroring `PerPersonBuffer`
  (action_head.py:159-189). Resets on id loss.
- **Guards:** all features pass a finite check; non-finite → fall back to last
  good value or neutral default (0.5 for positions, 0 for speed/openness).
  Values clamped to their declared ranges before emission.

### 4.2 OSC contract `/pose/hands` (NEW)

- **Sender:** `pose_bridge.py`, a new `send_hands(pid, feats, t)` method
  alongside `send_kin` (pose_bridge.py:311-322). Reuses `self._client`
  (sclang `127.0.0.1:57121`). Silent on unreachable receiver (existing pattern).
- **Message:** `/pose/hands [pid, lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist]`
  — fixed 1 int + 9 floats, one message per tracked person per tick. Missing
  hand → its 4 floats are 0 and a presence bit is implied by all-zero.
  (Raw `/hand/kp` 21-landmark route stays as-is; not used by this slice.)
- **Cadence:** emitted from the same tick as `/pose/kin` (action_head_pub.py:138
  orchestration point), so audio and visual stay frame-aligned.

### 4.3 SuperCollider ingestion + mapping

- **OSCdef (NEW)** in `sound_algo/control/data_feeds.scd`, next to the existing
  pose handlers (data_feeds.scd:464-496). Populates a new `~handFeat`
  dictionary keyed by pid: `(lx:, ly:, lopen:, lspeed:, rx:, ry:, ropen:,
  rspeed:, dist:)`. Mirrors the `~poseKin` OSCdef shape.
- **Mapping (NEW)** extends `~mapPoseToFx` (scene_pose_action.scd:33-83) — or a
  parallel `~mapHandsToFx` called on the same `~paConfig[\rate]` clock — to read
  `~handFeat`, average across active people, and drive the FX stubs.
- **FX stubs → real targets (NEW).** Today `~fxCut/~fxRev/~fxSt/~fxDrive` are
  unimplemented closures. Wire them:
  - `~fxCut(hz)` → set cutoff of a **new global filter** (see 4.4).
  - `~fxRev(mix)` → `~doRev.set(\mix, mix)` (engine.scd:34-37).
  - `~fxSt(w)` → stereo width control (new, see 4.4).
  - `~fxDrive(amt)` → drive amount (new control synth or master-stage param).
- **Mapping table (approved):**

  | Hand feature        | Audio target                       | Visual target (scene.metal) |
  |---------------------|------------------------------------|-----------------------------|
  | height `1 - cy`     | global filter cutoff 200→8000 Hz   | brightness / scale          |
  | `openness`          | reverb mix (space)                 | bloom / dispersion          |
  | `speed`             | drive / grain density              | turbulence                  |
  | two-hand `dist`     | stereo width                       | zoom / field of view        |

  Aggregation across people: mean of per-person averages (same approach as the
  existing `~mapPoseToFx` `n = max(1, ~poseKin.size)` averaging).

### 4.4 FX rack additions (SuperCollider, NEW)

The `data_only` rack currently has only `\do_reverb` and `\do_master`
(engine.scd:34-59) — no global filter or width control, so "sculpting" has
nothing to sweep. Add, on the master path (bus 0, before `\do_master`):

- `\do_master_filter` — global resonant low-pass (e.g. `RLPF`/`MoogFF`) with a
  `cutoff` arg (lagged), default wide-open so it is inaudible until hands move.
- A **stereo width** control — either a `\do_width` stage (mid/side) or a width
  arg folded into the filter synth.
- A **drive** control — gentle `tanh` saturation arg, default unity.

These follow the strict `sound_algo` SynthDef convention (lagged controls,
`ReplaceOut`/`Out` on the master path, no zombie synths). Use the
`adding-synthdef` skill when creating them.

### 4.5 Metal visual reactivity

- **Uniforms.** `scene.metal` already exposes `hand_l_x/y`, `hand_r_x/y`
  (struct lines 33-36) fed from `renderer.py:259-264`, with `_pad0/_pad1` free
  (lines 37-38) and `UNIFORM_FLOATS=20` (renderer.py:118). Extend the struct and
  `UNIFORM_FLOATS` to carry the **expressive** features actually used by the
  table: `hand_height`, `hand_openness`, `hand_speed`, `hand_dist` (4 floats →
  bump `UNIFORM_FLOATS` to 24, keep 16-byte alignment). Pack them in
  `_update_uniforms` from the same `HandFeatureExtractor` output.
- **Shader usage.** Today only mode 8 (`hands3d`, scene.metal:392-427) reads
  hand uniforms; modes 0–7 only read `pose_alive`. Add a light, shared reaction
  in the active scene modes so the coupling is visible regardless of mode:
  brightness/scale ← height, bloom ← openness, turbulence ← speed, zoom ← dist.
  Keep it subtle (multiplicative on existing terms), not a new mode.

## 5. Reliability work folded in

- **Boot fix:** `boot.scd` (boot.scd:114-142) loads engine → synthdefs →
  data_feeds → scenes but **not** `scene_pose_action.scd`, so `~mapPoseToFx` is
  currently dead code. Add it to the load sequence (after scenes) so both pose
  and hand modulation actually run.
- **Finite guards** on every hand feature (4.1) — MediaPipe z and fast id
  switches can produce spikes; One Euro smoothing exists upstream (multi.py:453)
  but the derived features need their own guard + clamp.
- **OSC robustness:** reuse the existing silent-on-unreachable send pattern; the
  new route degrades gracefully when SC is down.
- **Documentation:** record the `/pose/hands` contract (route, fields, ranges,
  cadence) in the `data_only_viz` docs/README and the `sound_algo/data_only`
  notes, replacing nothing but adding the new route.

## 6. Data flow summary (per tick)

1. `multi.py` produces `state.persons_hands` (already happening).
2. `HandFeatureExtractor` reads state, updates per-hand ring buffers, emits the
   feature vector (guarded, clamped).
3. `pose_bridge.send_hands` emits `/pose/hands` to SC `:57121`.
4. `renderer._update_uniforms` packs the same features into `SceneUniforms`.
5. SC `~handFeat` OSCdef stores the message; `~mapHandsToFx` (on the `~paConfig`
   clock) averages and drives the FX stubs → global filter / reverb / width /
   drive.
6. `scene.metal` renders the active mode with brightness/bloom/turbulence/zoom
   modulated by the same features.

## 7. Testing

- **Unit (Python):** `HandFeatureExtractor` on synthetic landmark sets — closed
  fist → openness ≈ 0; flat open hand → openness ≈ 1; static hand → speed ≈ 0;
  translated hand across frames → speed > 0; one hand → `dist` = 0; finite-guard
  test with a NaN-injected landmark → neutral fallback, no exception.
- **`.scd` validation:** run the `validating-scd-files` skill on every modified
  `.scd` (balanced parens/brackets P:0 B:0; single top-level block where
  required) — mandated by `sound_algo/CLAUDE.md`.
- **Smoke end-to-end:** with `data_only` booted, inject a synthetic
  `/pose/hands` (height sweep) via a small OSC sender and confirm (a) the SC
  global filter cutoff moves (audible / `.poll`), and (b) the Metal uniform
  changes (logged or visibly reacting). Confirm graceful no-op when SC is down.

## 8. Open decisions deferred to the plan

- Exact home of `HandFeatureExtractor` (new file vs. `action_head.py` class).
- Whether `~mapHandsToFx` is a new closure or an extension of `~mapPoseToFx`.
- Filter type for `\do_master_filter` (`RLPF` vs `MoogFF`) and width
  implementation (dedicated stage vs. folded arg).
- Ring-buffer length (start at 5 frames; tune to the loop fps).

## 9. Key file/line anchors (for the implementer)

| Area | File | Lines |
|------|------|-------|
| MediaPipe hand output | `data_only_viz/multi.py` | 426-457 |
| Hand state fields | `data_only_viz/state.py` | 90-93, 104, 113 |
| OSC sender (PoseSoundBridge) | `data_only_viz/pose_bridge.py` | 80-90, 233-261, 311-322 |
| Kinematics pattern | `data_only_viz/action_head.py` | 118-132, 148-189 |
| Tick orchestration | `data_only_viz/action_head_pub.py` | 138 |
| Metal uniforms host | `data_only_viz/renderer.py` | 118-123, 251-299 |
| Shader uniforms/struct | `data_only_viz/shaders/scene.metal` | 18-39, 392-427 |
| SC pose OSCdefs | `sound_algo/control/data_feeds.scd` | 464-496 |
| `~mapPoseToFx` + stubs | `sound_algo/data_only/scene_pose_action.scd` | 26-83 |
| FX rack | `sound_algo/data_only/engine.scd` | 34-59 |
| Body scene | `sound_algo/data_only/scenes.scd` | 108-139 |
| Boot + OSC port | `sound_algo/data_only/boot.scd` | 99-142 |
