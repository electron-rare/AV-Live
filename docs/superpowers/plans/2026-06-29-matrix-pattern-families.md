# Matrix hand-authored pattern families — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) — this is creative musical content authoring; subagent delegation adds little (a fresh agent can't judge musicality and the review can only check validity). The author with full context writes the patterns; the validity/contrast tests + the user's ear are the gates. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Hand-author 6-colour pattern families (dub/psy/house/ambient for mel voices, complete techno/breaks/dnb + percu-voice families for drums) so genre presets feel musically distinct.

**Architecture:** Add explicit 6-pattern entries to the existing `DRUMS`/`MEL` dicts (drum families = 6 sixteen-char strings; mel families = 6 `_mel([...])` motif lists), following the colour-role convention for contrast. Retarget `PRESET_FAMILY` so presets reference the new families. No engine/web change; `patterns_for` and SP-C1 derivation are untouched (they only affect `default`).

**Tech Stack:** Python 3 (`uv run python`), the rhythm DSL + `_mel`, SC validation harness.

## Global Constraints

- Python: **uv** only. No emojis in code/docs/commits. Commits: subject ≤ 50 chars, body ≤ 72/line, no AI attribution, no underscore in commit scope.
- Step shapes: drum family = list of 6 sixteen-char strings over `. o - x X` (= vel 0/.30/.50/.80/1.0); mel family = list of 6 `_mel([...])` results (16 steps of `None`/`(degree, vel)`).
- **Colour-role convention** (each new family's 6 colours, hand-authored): 1 = base · 2 = busier · 3 = broken/syncopated · 4 = double-time/denser · 5 = sparse · 6 = fill (last steps active). Hand-written, NOT derived.
- **Velocity-humanized**: vary `X` accents / `o` ghosts / `-` soft; no all-`x` rows.
- Existing families (`MEL["sub"]["dub"]`, `MEL["acid"]["psy"]`, all drum style families) and every `default` family: UNTOUCHED.
- SC validation: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/validate_presets.scd` (no `timeout` binary). Push only on user request. The macm1 live rig is up for the user's batch review.

## Family × voice matrix (what to author)

**MEL new families** (sub `dub` + acid `psy` already exist — author only the listed voices):
| Family | Voices | Feel |
|--------|--------|------|
| `dub` | reese, pad, chord, bells, melody | deep, sparse, off-beat skank stabs, long rests |
| `psy` | sub, reese, arp, lead, stab | rolling 16th basslines, fast tight arps, minor |
| `house` | pad, chord, stab, bells, lead, melody | chord stabs on off-beats, syncopated, soulful |
| `ambient` | pad, bells, melody, sub, reese | very sparse, long sustained-feel, few notes, wide |

**DRUMS percu-voice families** (the 6 fallback-only voices get authored style families):
| Voice | Families to add | Feel |
|-------|-----------------|------|
| `ride` | techno, house | rolling 8ths / off-beat bell |
| `shaker` | techno, house, breaks | 16th groove with accent swing-feel via velocity |
| `crash` | techno, breaks | downbeat crashes + section-end fill |
| `rim` | techno, dnb | syncopated clicks / ghost-heavy |
| `fx` | techno, ambient | sparse risers/hits |
| `sweep` | trance, ambient | long swells (sparse onsets) |

**Complete skewed drum styles**: add base patterns for voices `techno`/`breaks`/`dnb` currently omit so each genre feels coherent across its active kit (e.g. `breaks` for perc, shaker; `dnb` for perc, ride, shaker).

## File structure

| File | Change |
|------|--------|
| `sound_algo/data_only/matrix_presets/patterns.py` | add new `DRUMS`/`MEL` family entries; retarget `PRESET_FAMILY` |
| `sound_algo/data_only/matrix_presets/test_families.py` | create — validity/contrast/untouched/wiring assertions |
| `sound_algo/data_only/matrix_presets/*.matrix` | regenerated (28) |

---

### Task 1: validity/contrast/wiring test harness

**Files:**
- Create: `sound_algo/data_only/matrix_presets/test_families.py`

**Interfaces:** consumes `DRUMS`, `MEL`, `PRESET_FAMILY`, `_rhythm`, `_mel`, `VOICES`, `DRUM_VOICES`, `patterns_for` from `patterns.py`.

- [ ] **Step 1: Write the harness.** Create `test_families.py`:

```python
"""Validity + contrast + untouched + wiring checks for the pattern bank.
Run: cd sound_algo/data_only/matrix_presets && uv run python test_families.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patterns import DRUMS, MEL, PRESET_FAMILY, _rhythm, _mel, patterns_for

ok = True
def check(c, m):
    global ok
    if not c: ok = False; print("FAIL:", m)

_VELCH = set(". o - x X")
# every drum family = 6 valid 16-char strings
for v, fams in DRUMS.items():
    for fam, cols in fams.items():
        check(len(cols) == 6, "DRUMS[%s][%s] has %d cols" % (v, fam, len(cols)))
        for i, s in enumerate(cols):
            check(isinstance(s, str) and len(s) == 16 and set(s) <= _VELCH,
                  "DRUMS[%s][%s][%d] invalid: %r" % (v, fam, i, s))
# every mel family = 6 valid 16-step motif lists
for v, fams in MEL.items():
    for fam, cols in fams.items():
        check(len(cols) == 6, "MEL[%s][%s] has %d cols" % (v, fam, len(cols)))
        for i, m in enumerate(cols):
            check(isinstance(m, list) and len(m) == 16
                  and all(s is None or (isinstance(s[0], int) and isinstance(s[1], float)) for s in m),
                  "MEL[%s][%s][%d] invalid" % (v, fam, i))

def ddist(cols): return len({c for c in cols})
def mdist(cols): return len({tuple(c) for c in cols})
def dhits(s): return sum(1 for ch in s if ch not in ". ")
# contrast: new (non-default) families have >=4 distinct colours; col5 sparse <= col1; col6 fill last-4 active
for v, fams in DRUMS.items():
    for fam, cols in fams.items():
        if fam == "default": continue
        check(ddist(cols) >= 4, "DRUMS[%s][%s] only %d distinct" % (v, fam, ddist(cols)))
        check(dhits(cols[4]) <= dhits(cols[0]), "DRUMS[%s][%s] sparse !<= base" % (v, fam))
        check(any(ch not in ". " for ch in cols[5][12:16]), "DRUMS[%s][%s] fill last-4 empty" % (v, fam))

# PRESET_FAMILY wiring resolves (no missing-key crash) for every preset
for pname, (dfam, mfam) in PRESET_FAMILY.items():
    for v in DRUMS: check(patterns_for(v, pname) is not None or v not in DRUMS, "drum %s/%s" % (v, pname))
    # mel resolution: family present or falls back to default (which exists)
    for v in MEL: check(("default" in MEL[v]) or (mfam in MEL[v]), "mel %s/%s no default" % (v, pname))

print("TEST PASS" if ok else "TEST FAIL")
sys.exit(0 if ok else 1)
```

- [ ] **Step 2: Run it** (passes against the current bank — it's a validity floor).

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_families.py`
Expected: `TEST PASS` (the existing families already satisfy validity; the contrast checks only apply to non-default families, all currently valid).

- [ ] **Step 3: Commit.**

```bash
git add sound_algo/data_only/matrix_presets/test_families.py
git commit -m "test(presets): pattern family validity harness"
```

---

### Task 2: MEL families — dub, psy, house, ambient

**Files:**
- Modify: `sound_algo/data_only/matrix_presets/patterns.py` (`MEL` dict)
- Test: `test_families.py`

**Interfaces:** adds `MEL[v][fam]` entries per the matrix (dub: reese/pad/chord/bells/melody; psy: sub/reese/arp/lead/stab; house: pad/chord/stab/bells/lead/melody; ambient: pad/bells/melody/sub/reese).

- [ ] **Step 1: Author the motifs.** For each (voice, family) in the MEL matrix, add an entry `MEL[v][fam] = [_mel([...]), ...6 motifs...]` to the `MEL` dict, following the colour-role convention and the family feel (table above). Worked template — `dub` for `reese` (deep off-beat skank, A-minor degrees, long rests, humanized vels):

```python
MEL["reese"]["dub"] = [
  _mel([(0,.8),N,N,N,(0,.5),N,N,N,(3,.6),N,N,N,(0,.5),N,N,N]),          # 1 base: root pulse
  _mel([(0,.8),N,(0,.4),N,(0,.6),N,(3,.4),N,(3,.6),N,N,N,(0,.5),N,(0,.4),N]),  # 2 busier
  _mel([N,N,(0,.7),N,N,(0,.5),N,N,(3,.6),N,N,(0,.4),N,N,(5,.5),N]),     # 3 broken: off-beat skank
  _mel([(0,.8),N,(0,.5),N,(3,.6),N,(3,.5),N,(5,.6),N,(5,.5),N,(3,.6),N,(0,.5),N]),  # 4 double
  _mel([(0,.7),N,N,N,N,N,N,N,(3,.5),N,N,N,N,N,N,N]),                    # 5 sparse
  _mel([(0,.8),N,(0,.5),N,(3,.6),(3,.5),(5,.6),(5,.5),(7,.6),N,(5,.5),N,(3,.6),(3,.5),(0,.7),(0,.5)]),  # 6 fill: rising run
]
```
(`N` is `None`, already defined in patterns.py.) Repeat for every (voice, family) in the MEL matrix — author each by hand to the family's feel, varying degree content per voice register (`BASE_OCT` already shifts octaves: sub/reese low, lead/arp/bells high). Keep colour-5 sparser and colour-6 a fill, vary velocities.

- [ ] **Step 2: Confirm existing-family integrity.** Add to `test_families.py` (before the final print): assert the two pre-existing authored mel families are byte-identical to a captured snapshot — simplest: assert they still parse and that `len(MEL["sub"]["dub"]) == 6` and `len(MEL["acid"]["psy"]) == 6` AND that you did NOT edit those keys (review the diff: the `MEL["sub"]["dub"]` / `MEL["acid"]["psy"]` lines must not appear in the diff).

- [ ] **Step 3: Run the harness.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_families.py`
Expected: `TEST PASS` — all new mel families are 6 valid motif lists.

- [ ] **Step 4: Commit.**

```bash
git add sound_algo/data_only/matrix_presets/patterns.py sound_algo/data_only/matrix_presets/test_families.py
git commit -m "feat(presets): mel dub/psy/house/ambient families"
```

---

### Task 3: DRUMS — percu voices + complete styles

**Files:**
- Modify: `sound_algo/data_only/matrix_presets/patterns.py` (`DRUMS` dict)
- Test: `test_families.py`

**Interfaces:** adds `DRUMS[v][fam]` entries per the percu matrix (ride/shaker/crash/rim/fx/sweep) + the missing voices in techno/breaks/dnb.

- [ ] **Step 1: Author the rhythms.** For each (voice, family) add `DRUMS[v][fam] = [<6 sixteen-char strings>]` following the colour-role convention + the feel table. Worked template — `ride` `techno` (rolling 8ths, accent variation, humanized):

```python
DRUMS["ride"]["techno"] = [
  "x.x.x.x.x.x.x.x.",   # 1 base: straight 8ths
  "xXx.xXx.xXx.xXx.",   # 2 busier: accent each beat
  "x..x.x.x..x.x.x.",   # 3 broken: syncopated
  "xxxxxxxxxxxxxxxx",   # 4 double: 16ths
  "x...x...x...x...",   # 5 sparse: quarters
  "x.x.x.x.x.x.xXXX",   # 6 fill: tail accent roll
]
```
Repeat for every (voice, family) in the DRUMS matrix + the techno/breaks/dnb voice-completion. Keep colour-5 sparse, colour-6 a fill (last steps active = the harness checks this), humanize velocities (`X`/`o`/`-`).

- [ ] **Step 2: Run the harness.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_families.py`
Expected: `TEST PASS` — drum contrast checks (≥4 distinct, sparse ≤ base, fill last-4 active) pass for every new family.

- [ ] **Step 3: Commit.**

```bash
git add sound_algo/data_only/matrix_presets/patterns.py
git commit -m "feat(presets): percu families + complete styles"
```

---

### Task 4: PRESET_FAMILY wiring + regenerate + validate

**Files:**
- Modify: `sound_algo/data_only/matrix_presets/patterns.py` (`PRESET_FAMILY`)
- Modify: `*.matrix` (regenerated), `test_families.py` (wiring assertion)

- [ ] **Step 1: Retarget `PRESET_FAMILY`.** Update entries so genre presets reference the new families, e.g. `dub_techno -> ("techno", "dub")`, `psytrance_roll/minimal_hypno -> (drum, "psy")`, the house/electro presets -> mel `house`, `ambient_intro -> (drum, "ambient")`, trance presets keep/gain mel families that now exist. Only set a mel family for a preset when the voices it activates have that family (else they fall back to `default`, which is fine).

- [ ] **Step 2: Run the harness** (wiring assertions resolve).

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_families.py`
Expected: `TEST PASS`.

- [ ] **Step 3: Regenerate the 28 presets.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python generate_presets.py`
Expected: 28 `.matrix` files, no errors. Run TWICE; 2nd run = zero git diff (determinism).

- [ ] **Step 4: SC load validation.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/validate_presets.scd`
Expected: `VALIDATE PASS` (28/28).

- [ ] **Step 5: Commit.**

```bash
git add sound_algo/data_only/matrix_presets
git commit -m "feat(presets): wire new families, regenerate"
```

- [ ] **Step 6: User batch review.** Push (on request) + macm1 pull; the user reloads the genre presets on the live rig (`dub_techno`, `psytrance_roll`, a house preset, `ambient_intro`) and listens. Capture which families sound wrong → a focused follow-up authoring pass (re-author those specific bases, re-run harness + regen). This is the musical gate the automated tests cannot provide.

---

## Self-review

**Spec coverage:**
- Hand-authored 6-colour families (not derived) → Tasks 2/3 (explicit `MEL`/`DRUMS` entries). ✓
- Mel dub/psy/house/ambient → Task 2 matrix. ✓
- Percu voices + complete techno/breaks/dnb → Task 3. ✓
- Velocity humanization → convention + examples (varied `X`/`o`/`-`). ✓
- Existing families + default untouched → Task 2 Step 2 (diff check) + the harness only adds, never edits existing keys. ✓
- PRESET_FAMILY wiring → Task 4. ✓
- Tests (validity/contrast/untouched/wiring) → Task 1 harness, extended per task. ✓
- Regenerate + SC validate → Task 4. ✓
- Musical review (user, batch) → Task 4 Step 6. ✓

**Placeholder scan:** The per-(voice,family) patterns are authored at execution — this is creative content, not boilerplate; the plan supplies the convention, the exact matrix, a complete worked template per family-type (drum + mel), and the validity/contrast harness as the gate. That is the maximum a plan can specify for hand-authored music without pre-composing every bar (which would defeat the "hand-authored" intent). No TBD/TODO in the mechanical parts (harness, wiring, regen).

**Type consistency:** drum family = `list[str]` of six 16-char strings (parsed by `_rhythm` in `patterns_for`); mel family = `list` of six `_mel([...])` results. Matches the existing dict shapes. `N` = `None` (defined in patterns.py). The harness reads `DRUMS`/`MEL`/`PRESET_FAMILY`/`patterns_for` — all existing names. Colour indices: `cols[4]` = sparse, `cols[5]` = fill (0-based), consistent across the harness and the authoring convention.
