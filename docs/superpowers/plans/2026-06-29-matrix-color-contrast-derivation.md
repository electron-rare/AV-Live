# Matrix 6-colour contrast derivation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Derive a well-contrasted 6-colour spectrum (base/busier/broken/double/sparse/fill) for every voice's `default` pattern family from its characteristic colour 1, deterministically, at read time.

**Architecture:** Two pure functions (`derive_drum_colors`, `derive_mel_colors`) transform a 16-step base into colours 2-6. `patterns_for` calls them whenever the resolved family is `default` — so the dicts are NOT edited; the contrast is applied uniformly at read time. Authored style families pass through untouched.

**Tech Stack:** Python 3 (`uv run python`), SuperCollider validation harness.

## Global Constraints

- Python: **uv** only. No emojis in code/docs/commits. Commits: subject ≤ 50 chars, body ≤ 72/line, no AI attribution, no `--no-verify`, no underscore in commit scope.
- Deterministic transforms (no RNG) → byte-for-byte reproducible regeneration.
- Step shapes (from `_rhythm`/`_mel`): drum step = `None` (rest) or `(0, vel)` with `vel ∈ {0.30,0.50,0.80,1.0}`; mel step = `None` or `(int_degree, float_vel)`. Derived colours keep these shapes (16 steps).
- Only the `default` family is derived; all non-`default` (authored style) families are unchanged. Colour 1 (the base) of every voice is unchanged.
- SC validation: `/Applications/SuperCollider.app/Contents/MacOS/sclang <harness>` (binary not on PATH; no `timeout`). Push only on user request.

## Key existing code (patterns.py)

- `_rhythm(s)` (26): 16-char string → 16 steps (`None` / `(0, vel)`).
- `_mel(pairs)` (36): 16 `(deg,vel)|None` → normalized list.
- `DRUMS[role][family]` = 6 rhythm STRINGS; `MEL[role][family]` = 6 already-`_mel`'d motif lists.
- `DRUM_VOICES` (287): the 12 drum voices.
- `_pick(bank, role, family)` (291): `rolebank.get(family) or rolebank.get("default")`.
- `patterns_for(voice, preset)` (299): drums → `[_rhythm(s) for s in _pick(...)]`; mel → `_pick(...)` directly.

## File structure

| File | Change |
|------|--------|
| `sound_algo/data_only/matrix_presets/patterns.py` | add `derive_drum_colors`/`derive_mel_colors`; wire into `patterns_for` (derive when family == default) |
| `sound_algo/data_only/matrix_presets/test_contrast.py` | create — standalone density/validity/determinism assertions |
| `sound_algo/data_only/matrix_presets/*.matrix` | regenerated (28) |

---

### Task 1: derivation functions + unit tests

**Files:**
- Modify: `sound_algo/data_only/matrix_presets/patterns.py` (add the two functions, e.g. after `_mel` ~39)
- Create: `sound_algo/data_only/matrix_presets/test_contrast.py`

**Interfaces:**
- Produces: `derive_drum_colors(base) -> [c2,c3,c4,c5,c6]` (5 step-lists), `derive_mel_colors(base) -> [c2,c3,c4,c5,c6]`. `base` is a 16-element step list; each returned colour is a 16-element step list of the same shape.

- [ ] **Step 1: Write the failing test** `sound_algo/data_only/matrix_presets/test_contrast.py`:

```python
"""Standalone test for the 6-colour contrast derivation.
Run: cd sound_algo/data_only/matrix_presets && uv run python test_contrast.py
Prints TEST PASS / TEST FAIL; exits non-zero on failure."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patterns import derive_drum_colors, derive_mel_colors, _rhythm, _mel

ok = True
def check(c, m):
    global ok
    if not c: ok = False; print("FAIL:", m)

def dens(p): return sum(1 for s in p if s is not None)

# --- drums ---
base = _rhythm("X...x...X...x...")          # 4 hits
c2, c3, c4, c5, c6 = derive_drum_colors(base)
check(all(len(c) == 16 for c in (c2,c3,c4,c5,c6)), "drum colours 16 steps")
check(dens(c2) >= dens(base), "busier >= base")
check(dens(c4) >= dens(base), "double >= base")
check(dens(c5) <= dens(base), "sparse <= base")
check(dens(c3) == dens(base), "broken keeps hit count")
check([i for i in range(16) if (c3[i] is not None) != (base[i] is not None)] != [], "broken displaces")
check(all(c6[i] is not None for i in range(12, 16)), "fill last 4 active")
# velocities legal
legal = {0.30, 0.50, 0.80, 1.0}
for c in (c2, c3, c4, c5, c6):
    check(all(s is None or s[1] in legal for s in c), "drum vel legal")
# determinism
check(derive_drum_colors(base) == derive_drum_colors(base), "drum deterministic")

# --- mel ---
mbase = _mel([(0,0.8),None,(3,0.6),None,(7,0.7),None,None,None,
              (5,0.6),None,(3,0.6),None,(0,0.8),None,None,None])
m2, m3, m4, m5, m6 = derive_mel_colors(mbase)
check(all(len(c) == 16 for c in (m2,m3,m4,m5,m6)), "mel colours 16 steps")
check(dens(m4) >= dens(mbase), "mel double >= base")
check(dens(m5) <= dens(mbase), "mel sparse <= base")
check(all((s is None) or (isinstance(s[0], int) and isinstance(s[1], float)) for s in m4), "mel step shape")
check(all(m6[i] is not None for i in range(12, 16)), "mel fill last 4 active")
check(derive_mel_colors(mbase) == derive_mel_colors(mbase), "mel deterministic")

print("TEST PASS" if ok else "TEST FAIL")
sys.exit(0 if ok else 1)
```

- [ ] **Step 2: Run to verify it FAILS.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_contrast.py`
Expected: ImportError / `TEST FAIL` — the derive functions don't exist.

- [ ] **Step 3: Implement the two functions.** In `patterns.py`, after `_mel` (~39), add:

```python
_DRUM_VELS = (0.30, 0.50, 0.80, 1.0)


def _dhit(v):
    return None if v == 0.0 else (0, round(v, 2))


def derive_drum_colors(base):
    """Colours 2-6 from a 16-step drum base (None | (0, vel))."""
    n = len(base)
    busier = [base[i] if base[i] is not None else (_dhit(0.30) if i % 4 == 2 else None)
              for i in range(n)]
    broken = base[-1:] + base[:-1]                       # rotate right 1: same count, displaced
    double = [base[i] if base[i] is not None else (_dhit(0.80) if i % 2 == 0 else None)
              for i in range(n)]
    sparse = [base[i] if (base[i] is not None and ((base[i][1] >= 1.0) or i % 4 == 0)) else None
              for i in range(n)]
    fill = list(base)
    for k, v in enumerate((0.80, 0.80, 1.0, 1.0)):
        fill[n - 4 + k] = _dhit(v)
    return [busier, broken, double, sparse, fill]


def derive_mel_colors(base):
    """Colours 2-6 from a 16-step melodic base (None | (degree, vel))."""
    n = len(base)
    actives = [base[i][0] for i in range(n) if base[i] is not None]
    last_deg = actives[-1] if actives else 0

    def prev_deg(i):
        for j in range(i, -1, -1):
            if base[j] is not None:
                return base[j][0]
        return last_deg

    busier = [base[i] if base[i] is not None else ((prev_deg(i), 0.5) if i % 4 == 2 else None)
              for i in range(n)]
    broken = [((base[i][0] + 7, base[i][1]) if (base[i] is not None and i % 4 == 0) else base[i])
              for i in range(n)]
    double = [base[i] if base[i] is not None else ((prev_deg(i), 0.6) if i % 2 == 0 else None)
              for i in range(n)]
    sparse = [base[i] if (base[i] is not None and i % 4 == 0) else None for i in range(n)]
    fill = list(base)
    for k in range(4):
        fill[n - 4 + k] = (last_deg + k, round(0.6 + 0.1 * k, 2))
    return [busier, broken, double, sparse, fill]
```

- [ ] **Step 4: Run to verify it PASSES.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_contrast.py`
Expected: `TEST PASS` (exit 0).

- [ ] **Step 5: Commit.**

```bash
git add sound_algo/data_only/matrix_presets/patterns.py sound_algo/data_only/matrix_presets/test_contrast.py
git commit -m "feat(presets): 6-colour contrast derivation fns"
```

---

### Task 2: wire into patterns_for + regenerate + validate

**Files:**
- Modify: `sound_algo/data_only/matrix_presets/patterns.py` (`patterns_for` ~299-306)
- Modify: `sound_algo/data_only/matrix_presets/*.matrix` (regenerated), `test_contrast.py` (add the wiring assertion)

**Interfaces:**
- Consumes Task 1's `derive_drum_colors`/`derive_mel_colors`. Produces: `patterns_for` returns a contrasted `default` family (colour 1 base + derived 2-6) while leaving authored style families unchanged.

- [ ] **Step 1: Add the failing wiring assertion** to `test_contrast.py` (before the final `print`):

```python
from patterns import patterns_for
# A voice whose default family is used (acid in a non-psy preset uses MEL default).
# default-derived: colours 2-6 are NOT all identical to colour 1.
ac = patterns_for("acid", "techno_drive")      # techno_drive maps mel-family default for acid
check(ac is not None and len(ac) == 6, "patterns_for returns 6")
check(ac[4] != ac[0] or ac[3] != ac[0], "default colours are contrasted (derived)")
# kick default colour 5 (sparse) has <= hits than colour 1
def dens2(p): return sum(1 for s in p if s is not None)
kk = patterns_for("kick", "techno_drive")
check(dens2(kk[4]) <= dens2(kk[0]), "kick sparse <= base")
# an authored style family is NOT derived: acid in a psy preset keeps its hand-authored set
# (psytrance_roll maps mel-family 'psy' for acid) -> colour list equals the raw MEL['acid']['psy']
from patterns import MEL
psy = patterns_for("acid", "psytrance_roll")
check(psy == MEL["acid"]["psy"], "authored psy family untouched")
```

- [ ] **Step 2: Run to verify it FAILS.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_contrast.py`
Expected: `TEST FAIL` — `patterns_for` still returns the raw (low-contrast) default colours 2-6.

- [ ] **Step 3: Wire derivation into `patterns_for`.** Replace `patterns_for` (patterns.py ~299-306) with:

```python
def patterns_for(voice, preset_name):
    """Return 6 step-patterns (one per colour 1-6) for `voice` in `preset_name`,
    or None if the voice has no bank. The `default` family's colours 2-6 are
    derived from colour 1 for a consistent base/busier/broken/double/sparse/fill
    contrast; authored style families pass through unchanged."""
    dfam, mfam = PRESET_FAMILY.get(preset_name, ("default", "default"))
    if voice in DRUM_VOICES:
        rolebank = DRUMS.get(voice)
        if rolebank is None:
            return None
        fam = dfam if dfam in rolebank else "default"
        cols = [_rhythm(s) for s in rolebank[fam]]
        if fam == "default":
            cols = [cols[0]] + derive_drum_colors(cols[0])
        return cols
    rolebank = MEL.get(voice)
    if rolebank is None:
        return None
    fam = mfam if mfam in rolebank else "default"
    cols = rolebank[fam]
    if fam == "default":
        cols = [cols[0]] + derive_mel_colors(cols[0])
    return cols
```
(The old `_pick` helper is now unused by `patterns_for`; leave it if anything else imports it — grep `_pick`; if nothing else uses it, remove it.)

- [ ] **Step 4: Run to verify it PASSES.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_contrast.py`
Expected: `TEST PASS` (exit 0).

- [ ] **Step 5: Regenerate the 28 presets.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python generate_presets.py`
Expected: 28 `.matrix` files written, no errors. (Determinism: a second run produces identical files.)

- [ ] **Step 6: SC load validation.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/validate_presets.scd`
Expected: `VALIDATE PASS` (28/28 load). The derived `default` colours parse and play. (If the harness asserts specific preset values from a prior task, confirm they still hold — colour 1 is unchanged so prior DEFAULTS/voiceMods asserts are unaffected.)

- [ ] **Step 7: Commit.**

```bash
git add sound_algo/data_only/matrix_presets
git commit -m "feat(presets): contrasted default colours, regen"
```

---

## Self-review

**Spec coverage:**
- 6-colour convention (base/busier/broken/double/sparse/fill) → Task 1 `derive_*` functions. ✓
- Deterministic, no RNG → Task 1 (fixed rules) + determinism test. ✓
- Applied to the `default` family of ALL 22 voices, keeping colour 1 → Task 2 `patterns_for` (`fam == "default"` branch, `[cols[0]] + derive(...)`). ✓
- Authored style families untouched → Task 2 (`fam != "default"` passes through) + the "authored psy family untouched" assertion. ✓
- Operate on parsed step lists, same shape → Task 1 functions take/return 16-step lists. ✓
- Density/validity invariants → Task 1 tests. ✓
- Regenerate + SC load → Task 2. ✓

**Placeholder scan:** No TBD/TODO. The mel test base uses a single explicit `_mel([...])` assignment (no walrus/throwaway).

**Type consistency:** `derive_drum_colors`/`derive_mel_colors` take a 16-step list and return a list of 5 same-shape lists. `patterns_for` builds `[cols[0]] + derive(cols[0])` → 6 colours, matching the existing 6-per-voice contract consumed by `emit_colordefs`. Drum steps stay `None|(0,vel)`; mel steps stay `None|(degree,vel)`. The `fam == "default"` gate matches `_pick`'s fallback semantics (family present → use it; else default).
