# Default pose→instrument mappings in presets — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bake a fixed, logical, role-adapted default pose→instrument modulation scheme into all 28 matrix presets (soloists→hands, structure→body), so the body controls instruments expressively out of the box.

**Architecture:** Pure content in the preset generator. Two helpers — `default_mods(voice)` and `default_poses(voice)` — return a voice's fixed bindings (from a per-role table, filtered by a Cycle-1 eligibility map). `emit_voicemods`/`emit_voiceposes` call them for each ACTIVE voice instead of the removed `*_DEMO` literals. No SC or web changes (the engine already supports these targets).

**Tech Stack:** Python 3 (`uv run python`), SuperCollider validation harness (`validate_presets.scd`).

## Global Constraints

- Python: **uv** only.
- No emojis in code/docs/commits.
- Commits: subject ≤ 50 chars, body ≤ 72 chars/line, no AI attribution, no `--no-verify`, no underscore in commit scope.
- Source/target IDs are SC symbols on the wire; emitted as `(source: \\x, target: \\y, depth: 0.NN)` Event literals (existing `emit_sc_mod_binding`).
- Bindings MUST respect Cycle-1 target eligibility — never emit an ineligible binding:
  - `cutoff`: perc, acid, arp, lead, stab, pad, reese, melody, chord
  - `res`: sub, acid, arp, lead, stab, pad, reese, bells, melody, chord
  - `pitch`: sub, acid, arp, lead, stab, pad, reese, bells, perc, tom
  - `amp`, `pan`, `rev`: all voices
- SC validation: `/Applications/SuperCollider.app/Contents/MacOS/sclang <harness>` (binary not on PATH; no `timeout` binary). Push only on user request.

## The fixed scheme (verbatim — soloists→hands, structure→body)

| Voices | Bindings (source, target, depth) |
|--------|----------------------------------|
| acid, arp, lead, stab | (rHandX,amp,0.4) (rHandY,pitch,0.4) (lHandY,cutoff,0.5) (lHandX,res,0.4) |
| bells | (rHandX,amp,0.4) (rHandY,pitch,0.4) (lHandX,res,0.4) |
| melody | (rHandX,amp,0.4) (lHandY,cutoff,0.5) (lHandX,res,0.4) |
| reese | (bodyVitesse,cutoff,0.5) (bodyY,pitch,0.3) (limbSpan,res,0.4) (bodyX,pan,0.3) |
| sub | (bodyVitesse,res,0.4) (bodyY,pitch,0.3) (bodyX,pan,0.3) |
| pad, chord | (bodyVitesse,cutoff,0.4) (limbSpan,rev,0.4) (bodyX,pan,0.3) |
| perc | (bodyVitesse,cutoff,0.4) (bodyY,pitch,0.3) (bodyX,pan,0.3) |
| tom | (bodyY,pitch,0.3) (bodyVitesse,amp,0.3) (bodyX,pan,0.3) |
| kick, hats, clap, ride, rim, snare, crash, shaker | (bodyVitesse,rev,0.3) (bodyX,pan,0.3) |
| sweep, fx | (danse,rev,0.5) (bodyVitesse,amp,0.4) |

Poses: `danse→gate` on `fx` and `sweep` only; all other voices none.

## File structure

| File | Change |
|------|--------|
| `sound_algo/data_only/matrix_presets/generate_presets.py` | add eligibility map + `_ROLE_MODS`/`_VOICE_ROLE` + `default_mods`/`default_poses`; rewire `emit_voicemods`/`emit_voiceposes`; remove `VOICE_MODS_DEMO`/`VOICE_POSES_DEMO` |
| `sound_algo/data_only/matrix_presets/test_default_mods.py` | create — standalone assertion test (no pytest dep) |
| `sound_algo/data_only/matrix_presets/*.matrix` | regenerated (28) |
| `sound_algo/data_only/matrix_presets/validate_presets.scd` | extend — assert defaults loaded |

---

### Task 1: generator helpers + wiring + Python test

**Files:**
- Modify: `sound_algo/data_only/matrix_presets/generate_presets.py` (`VOICE_MODS_DEMO`/`VOICE_POSES_DEMO` ~518-529, `emit_voicemods`/`emit_voiceposes` ~542-567)
- Create: `sound_algo/data_only/matrix_presets/test_default_mods.py`

**Interfaces:**
- Produces: `default_mods(voice) -> list[(source,target,depth)]`, `default_poses(voice) -> list[(poseId,action)]`, module-level `_MOD_TARGETS: dict[str,set[str]]`. `emit_voicemods`/`emit_voiceposes` now emit defaults for ACTIVE voices (`patterns_for(voice, preset) is not None`), `[]` otherwise.
- Consumes: existing `VOICES`, `patterns_for`, `emit_sc_mod_binding`, `emit_sc_pose_binding`.

- [ ] **Step 1: Write the failing test** `sound_algo/data_only/matrix_presets/test_default_mods.py`:

```python
"""Standalone test for the default pose->instrument mapping scheme.
Run: cd sound_algo/data_only/matrix_presets && uv run python test_default_mods.py
Prints TEST PASS / TEST FAIL; exits non-zero on failure."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_presets import default_mods, default_poses, _MOD_TARGETS, VOICES

ok = True
def check(cond, msg):
    global ok
    if not cond:
        ok = False
        print("FAIL:", msg)

# lead voices: the 4 hand bindings
for v in ("acid", "arp", "lead", "stab"):
    tgts = [t for (_s, t, _d) in default_mods(v)]
    check(tgts == ["amp", "pitch", "cutoff", "res"], "%s lead bindings, got %s" % (v, tgts))

# bells: no cutoff; melody: no pitch
check([t for (_s, t, _d) in default_mods("bells")] == ["amp", "pitch", "res"], "bells")
check([t for (_s, t, _d) in default_mods("melody")] == ["amp", "cutoff", "res"], "melody")

# sub: res (not cutoff) + pitch + pan ; reese: cutoff+pitch+res+pan
check([t for (_s, t, _d) in default_mods("sub")] == ["res", "pitch", "pan"], "sub")
check([t for (_s, t, _d) in default_mods("reese")] == ["cutoff", "pitch", "res", "pan"], "reese")

# perc: cutoff+pitch+pan (no res) ; tom: pitch+amp+pan (no res/cutoff)
check([t for (_s, t, _d) in default_mods("perc")] == ["cutoff", "pitch", "pan"], "perc")
check([t for (_s, t, _d) in default_mods("tom")] == ["pitch", "amp", "pan"], "tom")

# drums: body rev+pan ; fx: danse rev + body amp
check(default_mods("kick") == [("bodyVitesse", "rev", 0.3), ("bodyX", "pan", 0.3)], "kick")
check([s for (s, _t, _d) in default_mods("fx")] == ["danse", "bodyVitesse"], "fx sources")

# ELIGIBILITY INVARIANT: every emitted binding's target is eligible for its voice
for v in VOICES:
    for (_s, t, _d) in default_mods(v):
        check(t in _MOD_TARGETS[v], "ineligible %s->%s on %s" % (_s, t, v))

# poses: danse->gate on fx/sweep only
check(default_poses("fx") == [("danse", "gate")], "fx pose")
check(default_poses("sweep") == [("danse", "gate")], "sweep pose")
check(default_poses("kick") == [], "kick no pose")

print("TEST PASS" if ok else "TEST FAIL")
sys.exit(0 if ok else 1)
```

- [ ] **Step 2: Run to verify it FAILS.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_default_mods.py`
Expected: ImportError / `TEST FAIL` — `default_mods`, `default_poses`, `_MOD_TARGETS` don't exist yet.

- [ ] **Step 3: Add the eligibility map + scheme + helpers.** In `generate_presets.py`, REPLACE the `VOICE_MODS_DEMO` and `VOICE_POSES_DEMO` blocks (~518-529) with:

```python
# -- Default pose->instrument mapping scheme (fixed, role-adapted) --
# Eligibility mirrors the SC engine ~matModTargets (cycle 1): a binding is only
# emitted if its target is valid for that voice.
_MOD_TARGETS = {v: {"amp", "pan", "rev"} for v in VOICES}
for v in ("perc", "acid", "arp", "lead", "stab", "pad", "reese", "melody", "chord"):
    _MOD_TARGETS[v].add("cutoff")
for v in ("sub", "acid", "arp", "lead", "stab", "pad", "reese", "bells", "melody", "chord"):
    _MOD_TARGETS[v].add("res")
for v in ("sub", "acid", "arp", "lead", "stab", "pad", "reese", "bells", "perc", "tom"):
    _MOD_TARGETS[v].add("pitch")

# Per-role default bindings (source, target, depth). Soloists -> hand sources
# (expressive, close-up); energy/structure -> body sources (robust at distance).
_ROLE_MODS = {
    "lead":   [("rHandX", "amp", 0.4), ("rHandY", "pitch", 0.4), ("lHandY", "cutoff", 0.5), ("lHandX", "res", 0.4)],
    "bells":  [("rHandX", "amp", 0.4), ("rHandY", "pitch", 0.4), ("lHandX", "res", 0.4)],
    "melody": [("rHandX", "amp", 0.4), ("lHandY", "cutoff", 0.5), ("lHandX", "res", 0.4)],
    "reese":  [("bodyVitesse", "cutoff", 0.5), ("bodyY", "pitch", 0.3), ("limbSpan", "res", 0.4), ("bodyX", "pan", 0.3)],
    "sub":    [("bodyVitesse", "res", 0.4), ("bodyY", "pitch", 0.3), ("bodyX", "pan", 0.3)],
    "pad":    [("bodyVitesse", "cutoff", 0.4), ("limbSpan", "rev", 0.4), ("bodyX", "pan", 0.3)],
    "perc":   [("bodyVitesse", "cutoff", 0.4), ("bodyY", "pitch", 0.3), ("bodyX", "pan", 0.3)],
    "tom":    [("bodyY", "pitch", 0.3), ("bodyVitesse", "amp", 0.3), ("bodyX", "pan", 0.3)],
    "drums":  [("bodyVitesse", "rev", 0.3), ("bodyX", "pan", 0.3)],
    "fx":     [("danse", "rev", 0.5), ("bodyVitesse", "amp", 0.4)],
}
_VOICE_ROLE = {
    "acid": "lead", "arp": "lead", "lead": "lead", "stab": "lead",
    "bells": "bells", "melody": "melody",
    "reese": "reese", "sub": "sub",
    "pad": "pad", "chord": "pad",
    "perc": "perc", "tom": "tom",
    "kick": "drums", "hats": "drums", "clap": "drums", "ride": "drums",
    "rim": "drums", "snare": "drums", "crash": "drums", "shaker": "drums",
    "sweep": "fx", "fx": "fx",
}


def default_mods(voice):
    """Fixed default mod bindings for a voice, filtered by target eligibility."""
    role = _VOICE_ROLE.get(voice)
    if role is None:
        return []
    elig = _MOD_TARGETS.get(voice, {"amp", "pan", "rev"})
    return [(s, t, d) for (s, t, d) in _ROLE_MODS[role] if t in elig]


def default_poses(voice):
    """Fixed default pose bindings: danse->gate swells the FX voices."""
    return [("danse", "gate")] if voice in ("fx", "sweep") else []
```

- [ ] **Step 4: Rewire `emit_voicemods` and `emit_voiceposes`** to use the defaults for ACTIVE voices. Replace both functions (~542-567):

```python
def emit_voicemods(preset_name):
    """22-element list of SC sub-arrays: default scheme for active voices, else []."""
    parts = []
    for voice in VOICES:
        active = patterns_for(voice, preset_name) is not None
        bindings = default_mods(voice) if active else []
        if bindings:
            parts.append("[" + ", ".join(emit_sc_mod_binding(*b) for b in bindings) + "]")
        else:
            parts.append("[]")
    return parts


def emit_voiceposes(preset_name):
    """22-element list of SC sub-arrays: default poses for active voices, else []."""
    parts = []
    for voice in VOICES:
        active = patterns_for(voice, preset_name) is not None
        bindings = default_poses(voice) if active else []
        if bindings:
            parts.append("[" + ", ".join(emit_sc_pose_binding(*b) for b in bindings) + "]")
        else:
            parts.append("[]")
    return parts
```
(`patterns_for` is the same active-voice signal `emit_colordefs` uses — `None` ⇒ the voice is silent in this preset ⇒ no mappings.)

- [ ] **Step 5: Run to verify it PASSES.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_default_mods.py`
Expected: `TEST PASS` (exit 0).

- [ ] **Step 6: Commit.**

```bash
git add sound_algo/data_only/matrix_presets/generate_presets.py sound_algo/data_only/matrix_presets/test_default_mods.py
git commit -m "feat(presets): default pose-instrument mod scheme"
```

---

### Task 2: regenerate presets + SC load validation

**Files:**
- Modify: `sound_algo/data_only/matrix_presets/*.matrix` (regenerated), `sound_algo/data_only/matrix_presets/validate_presets.scd`

**Interfaces:**
- Consumes: Task 1's generator. Produces: 28 regenerated `.matrix` files carrying the default `voiceMods`/`voicePoses`.

- [ ] **Step 1: Regenerate the 28 presets.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python generate_presets.py`
Expected: 28 `.matrix` files written, no errors.

- [ ] **Step 2: Spot-check the emitted defaults.**

Run: `grep -c "voiceMods" sound_algo/data_only/matrix_presets/*.matrix | grep -c ":1"` (28 files each with the key) and `grep -o "(source: \\\\rHandX, target: \\\\amp[^)]*)" sound_algo/data_only/matrix_presets/techno_drive.matrix | head -1`
Expected: the lead hand binding present in a preset that has a lead/acid voice; voiceMods key in all 28.

- [ ] **Step 3: Extend `validate_presets.scd`** to assert the defaults loaded. After the existing 28/28 load loop, add (matching the harness's style — it already stubs `~toscSend`, loads `../../matrix.scd`, loops presets):

```supercollider
// assert default mappings landed: load techno_drive, check a lead voice has its
// 4 hand bindings and a drum voice has its 2 body bindings.
~matLoad.("techno_drive");
~vpass = (~matVoiceMods[\acid].size == 4)
    and: { ~matVoiceMods[\acid].any({ |b| b[\target] == \pitch }) }
    and: { ~matVoiceMods[\kick].size == 2 }
    and: { ~matVoiceMods[\kick][0][\source] == \bodyVitesse };
~vpass.if({ "DEFAULTS PASS".postln }, { "DEFAULTS FAIL".postln });
```
(Use the actual voice that `techno_drive` activates for a lead — if `acid` is inactive there, pick an active lead/melodic voice; confirm via the generated file. If `acid` has no steps in techno_drive, its voiceMods is `[]` by the active-voice filter — choose a voice the preset plays.)

- [ ] **Step 4: Run the validation.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/validate_presets.scd`
Expected: `VALIDATE PASS` (28/28 load) AND `DEFAULTS PASS`. If the lead voice chosen is inactive in techno_drive, the harness will reveal a `[]` — switch to an active voice and re-run.

- [ ] **Step 5: Commit.**

```bash
git add sound_algo/data_only/matrix_presets
git commit -m "feat(presets): regenerate with default mappings"
```

---

## Self-review

**Spec coverage:**
- Fixed role-adapted scheme (soloists→hands, structure→body) → Task 1 `_ROLE_MODS`/`_VOICE_ROLE`. ✓
- Eligibility filter (no invalid binding) → Task 1 `_MOD_TARGETS` + `default_mods` filter + the test's eligibility invariant. ✓
- Active-voice-only emission → Task 1 `emit_*` use `patterns_for(...) is not None`. ✓
- DEMO dicts removed → Task 1 Step 3 replaces them. ✓
- Default poses (danse→gate on fx/sweep) → Task 1 `default_poses`. ✓
- Regenerate + SC load validation → Task 2. ✓
- No engine/web change → confirmed (only generator + its test + regenerated data). ✓

**Placeholder scan:** No TBD/TODO. Task 2 Step 3/4 flags the active-voice contingency (pick a lead voice the preset actually plays) with a concrete remedy rather than leaving it vague.

**Type consistency:** `default_mods` returns `(source,target,depth)` tuples consumed by `emit_sc_mod_binding(*b)` (matches its `(source,target,depth)` signature). `default_poses` returns `(poseId,action)` for `emit_sc_pose_binding(*b)`. `_MOD_TARGETS` sets mirror the Global Constraints eligibility lists exactly. The test's expected target-order matches `_ROLE_MODS` insertion order (lead: amp,pitch,cutoff,res; sub: res,pitch,pan; etc.).
