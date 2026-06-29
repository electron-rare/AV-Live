# Matrix presets v4 — intro/live/outro + families — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) — creative musical content (56 hand-written arcs + ~38 pattern families); subagent delegation can't judge musicality. The author with full context writes it; the validity/section-shape/SC-load tests + the user's ear are the gates. Checkbox (`- [ ]`) steps.

**Goal:** Regenerate the matrix presets as 84 files — each of the 28 morceaux split into intro/live/outro (live = existing arc, intro+outro = hand-written) — and hand-author new pattern families (dub/psy/house/ambient + drum families).

**Architecture:** Restructure `generate_presets.py` from a flat `PRESETS` dict to a `MORCEAUX` dict carrying 3 section arcs per morceau; `main()` emits `<name>_<section>.matrix` (84). 56 new fully-independent `arc_intro_<m>`/`arc_outro_<m>` functions. New 6-colour families added to `DRUMS`/`MEL` in `patterns.py`. Tests gate validity/section-shape/family-contrast + SC loads all 84.

**Tech Stack:** Python 3 (`uv run python`), the rhythm DSL + `_mel`, SC validation harness.

## Global Constraints

- Python: **uv** only. No emojis in code/docs/commits. Commits: subject ≤ 50 chars, body ≤ 72/line, no AI attribution, no underscore in commit scope.
- 84 presets = 28 morceaux × {intro, live, outro}. `live` = the morceau's existing arc (unchanged). `intro`/`outro` = 56 fully-independent hand-written arc functions (no shared helper). Naming `<morceau>_<section>`.
- Grid = 22 voices × 64 bars, cells 0-6. Section semantics: intro builds (sparse→full, voices enter), live = full groove, outro breaks down (full→sparse, voices exit).
- Hand-authored 6-colour pattern families (NOT derived); existing families + every `default` untouched (SP-C1 derivation stays for `default`).
- SC validation: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/validate_presets.scd` (no `timeout`). Push only on user request; macm1 rig is up for batch ear review.

## Existing structure (generate_presets.py)

- 8 shared arcs: `arc_four_floor` (+`ff(True)`), `arc_rolling`, `arc_acid`, `arc_breaks`, `arc_electro`, `arc_trance`, `arc_ambient`, `arc_industrial`.
- `PRESETS = { name: (arc_fn, instkit, melodies, extra) }` (28). `kit(...)`, `ex_*`. `to_sc(name, arc_fn, instkit, melodies, extra)` → one `.matrix`. `main()` loops + writes + `validate_kit`.
- `blank()` = empty 22×64 grid; `apply_colors(g)` = the section-colour overlay (cols 2-6 by section). The arcs fill grid cells with colour 1 then `apply_colors` adds variation; `~matMigrateGrid`/`emit` downstream.

## File structure

| File | Change |
|------|--------|
| `generate_presets.py` | `MORCEAUX` dict; 56 `arc_intro_*`/`arc_outro_*`; `main()` emits 84; `PRESET_FAMILY` per 84 (in patterns.py) |
| `patterns.py` | new hand-authored `DRUMS`/`MEL` families; `PRESET_FAMILY` for the 84 names |
| `test_families.py` | (exists) family validity/contrast |
| `test_sections.py` | create — section-shape + 84-count |
| `*.matrix` | regenerated (84) |
| `launcher/concert/launch_concert.sh` | `MATRIX_PRESET` default → `techno_drive_live` |

---

### Task 1: generator restructure → MORCEAUX, emit 84, section-shape test

**Files:** Modify `generate_presets.py`; create `test_sections.py`.

**Interfaces:** Produces `MORCEAUX = { name: dict(live=arc, intro=arc, outro=arc, instkit, melodies, extra) }`; `main()` writes `<name>_<sec>.matrix` for sec in (intro,live,outro). `arc_intro_*`/`arc_outro_*` initially alias the live arc (placeholder) so 84 files generate; the section-shape test then drives authoring.

- [ ] **Step 1: Write the failing section test** `test_sections.py`:

```python
"""Section-shape checks: each morceau -> intro/live/outro; intro builds, outro
breaks down, live is densest. Run: cd .../matrix_presets && uv run python test_sections.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_presets as G

ok = True
def check(c, m):
    global ok
    if not c: ok = False; print("FAIL:", m)

def grid_of(name, sec):
    m = G.MORCEAUX[name]
    g = G.blank(); m[sec](g)
    if m.get("extra"): m["extra"](g)
    G.apply_colors(g)
    return g

def active_in(g, lo, hi):  # count non-zero cells in bar range [lo,hi)
    return sum(1 for row in g for b in range(lo, hi) if row[b] != 0)

check(len(G.MORCEAUX) == 28, "28 morceaux, got %d" % len(G.MORCEAUX))
for name, m in G.MORCEAUX.items():
    for sec in ("intro", "live", "outro"):
        check(sec in m and callable(m[sec]), "%s missing %s arc" % (name, sec))
    intro, live, outro = grid_of(name, "intro"), grid_of(name, "live"), grid_of(name, "outro")
    # intro builds: last quarter denser than first quarter
    check(active_in(intro, 48, 64) > active_in(intro, 0, 16), "%s intro not building" % name)
    # outro breaks down: first quarter denser than last quarter
    check(active_in(outro, 0, 16) > active_in(outro, 48, 64), "%s outro not breaking down" % name)
    # live is the densest section overall
    check(active_in(live, 0, 64) >= active_in(intro, 0, 64)
          and active_in(live, 0, 64) >= active_in(outro, 0, 64), "%s live not densest" % name)

print("TEST PASS" if ok else "TEST FAIL")
sys.exit(0 if ok else 1)
```

- [ ] **Step 2: Restructure `generate_presets.py`.** Replace the `PRESETS` dict with `MORCEAUX` — keep each morceau's existing arc as `live`, add `intro`/`outro` keys initially set to the live arc (placeholders, replaced in Tasks 3-N):
```python
MORCEAUX = {
  "techno_drive": dict(live=arc_four_floor, intro=arc_four_floor, outro=arc_four_floor,
                       instkit=kit(K_909, {"sub":"lp_sub","chord":"juno"}),
                       melodies={"sub": BASS_TECHNO}, extra=None),
  # ... all 28, live = the current arc, intro=outro=live for now ...
}
```
Update `main()` to loop sections:
```python
for name, m in MORCEAUX.items():
    for sec in ("intro", "live", "outro"):
        sc = to_sc(f"{name}_{sec}", m[sec], m["instkit"], m["melodies"], m.get("extra"))
        # write to <name>_<sec>.matrix
```
(Carry over `validate_kit`. Keep `to_sc`'s signature.)

- [ ] **Step 3: Run section test — expect FAIL** (intro/outro alias live → not building/breaking).

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_sections.py`
Expected: `TEST FAIL` — `intro not building` / `outro not breaking down` for all morceaux (placeholders). The 28-count + per-section-present checks pass.

- [ ] **Step 4: Regenerate (84 files) + SC load.**

Run: `uv run python generate_presets.py` → 84 `.matrix`. Then `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/validate_presets.scd` → `VALIDATE PASS` (84/84) — the placeholder triplets all load.

- [ ] **Step 5: Commit.**
```bash
git add sound_algo/data_only/matrix_presets/generate_presets.py sound_algo/data_only/matrix_presets/test_sections.py sound_algo/data_only/matrix_presets/*.matrix
git commit -m "feat(presets): morceaux x intro/live/outro skeleton"
```

---

### Task 2: hand-authored pattern families (merged SP-C2)

**Files:** Modify `patterns.py` (`DRUMS`/`MEL`); `test_families.py` (exists).

- [ ] **Step 1: Author the families.** Add explicit 6-colour entries to `DRUMS`/`MEL` per the SP-C2 matrix (mel `dub`: reese/pad/chord/bells/melody; `psy`: sub/reese/arp/lead/stab; `house`: pad/chord/stab/bells/lead/melody; `ambient`: pad/bells/melody/sub/reese — sub `dub`+acid `psy` already exist; drum `ride/shaker/crash/rim/fx/sweep` families + complete techno/breaks/dnb). Each = 6 hand-written colours (base/busier/broken/double/sparse/fill, humanized vels). Existing families + `default` untouched.

- [ ] **Step 2: Run the family harness.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_families.py`
Expected: `TEST PASS` — every NEW (voice, family) present, 6 valid colours, ≥4 distinct; existing untouched.

- [ ] **Step 3: Commit.**
```bash
git add sound_algo/data_only/matrix_presets/patterns.py
git commit -m "feat(presets): hand-authored pattern families"
```

---

### Tasks 3-9: author intro/outro arcs by style batch

Author the 56 independent `arc_intro_<m>`/`arc_outro_<m>` functions and point each morceau's `intro`/`outro` at them, in style batches. Each batch: write the arcs (intro builds voices in over 64 bars; outro drops them out), point `MORCEAUX[name]["intro"|"outro"]` at the new fns, run `test_sections.py` (those morceaux now pass building/breaking), regenerate, SC load, commit.

Arc-writing convention (grid `g` is 22×64; `VIDX` maps voice→row; set cells to colour 1, `apply_colors` adds variation): an intro enters voices on bar boundaries (e.g. kick from 0, hats +8, bass +16, pad +32, lead +48) and is fullest in its last 16 bars; an outro starts full and removes voices toward the end (sparsest in its last 16 bars). Reuse the morceau's voice set (from its live arc / instkit).

- [ ] **Task 3 — four-on-the-floor (5):** techno_drive, detroit_soul, peak_drop, rave_stab, dub_techno. Author `arc_intro_*`/`arc_outro_*` for each; wire; `test_sections.py` PASS for these; regen; SC load; commit `feat(presets): four-floor intro/outro arcs`.
- [ ] **Task 4 — acid (2):** acid_journey, schranz_drive. Same flow; commit `feat(presets): acid intro/outro arcs`.
- [ ] **Task 5 — trance/melodic (5):** trance_euphoria, melodic_builder, melodic_deep, progressive_lift, hypnotic_arp. Commit `feat(presets): trance intro/outro arcs`.
- [ ] **Task 6 — psy/rolling/minimal (2):** psytrance_roll, minimal_hypno. Commit `feat(presets): psy intro/outro arcs`.
- [ ] **Task 7 — breaks/dnb (7):** breakbeat, bass_science, jungle_amen, dnb_roller, footwork_chop, neuro_reese, tribal_perc. Commit `feat(presets): breaks intro/outro arcs`.
- [ ] **Task 8 — electro/ebm (4):** electro_808, ebm_body, synthwave_drive, electro_funk. Commit `feat(presets): electro intro/outro arcs`.
- [ ] **Task 9 — industrial+ambient (3):** industrial_grind, hardcore_punk, ambient_intro. Commit `feat(presets): industrial/ambient intro/outro arcs`.

Each task's gate: `uv run python test_sections.py` (the batch's morceaux pass), `uv run python generate_presets.py`, `sclang validate_presets.scd` → 84/84.

---

### Task 10: family wiring + final regen + validate + launch default

**Files:** `patterns.py` (`PRESET_FAMILY`), `launcher/concert/launch_concert.sh`, regenerated `*.matrix`.

- [ ] **Step 1: Wire `PRESET_FAMILY` for the 84 names.** Map each `<morceau>_<section>` to `(drum_family, mel_family)` so genre presets use the new families (e.g. `dub_techno_* -> ("techno","dub")`, `psytrance_roll_* -> (drum,"psy")`, house/electro presets -> mel `house`, `ambient_intro_* -> (drum,"ambient")`). A section inherits its morceau's families. Unmapped → `("default","default")`.

- [ ] **Step 2: Full run.** `uv run python test_families.py` PASS · `uv run python test_sections.py` PASS · `uv run python generate_presets.py` (84, deterministic — 2nd run zero diff) · `sclang validate_presets.scd` → `VALIDATE PASS` 84/84.

- [ ] **Step 3: launch default → live.** In `launch_concert.sh`, change `MATRIX_PRESET="${MATRIX_PRESET:-techno_drive}"` to `:-techno_drive_live`.

- [ ] **Step 4: Commit.**
```bash
git add sound_algo/data_only/matrix_presets launcher/concert/launch_concert.sh
git commit -m "feat(presets): wire families, 84 presets, live default"
```

- [ ] **Step 5: User batch ear review.** Push (on request) + macm1 pull; reload `<morceau>_intro/live/outro` of several morceaux on the live rig; iterate on weak arcs/families.

---

## Self-review

**Spec coverage:** 84 = 28×{intro,live,outro} → Task 1 + 3-9. Live = existing arc → Task 1. 56 independent intro/outro arcs → Tasks 3-9. Hand-authored families → Task 2. PRESET_FAMILY wiring → Task 10. 84/84 SC load → each task. launch default → Task 10. User ear review → Task 10 Step 5. Section semantics (intro builds/outro breaks/live densest) → `test_sections.py`. ✓

**Placeholder scan:** The 56 arc bodies + the family patterns are creative content authored at execution (inline); the plan supplies the restructure (complete code), both test harnesses (complete), the arc-writing + family conventions, and the morceau batches. Mechanical parts have no TBD. The section-shape + family-validity tests are the automated gates; musicality is the user's ear (Task 10 Step 5).

**Type consistency:** `MORCEAUX[name]` = dict(live/intro/outro=callable(g), instkit=dict, melodies=dict, extra=callable|None) — consumed by `to_sc(name, arc, instkit, melodies, extra)` (unchanged signature) and `test_sections.py` (`m[sec]`, `m["extra"]`). Section names `intro/live/outro` consistent across `main()`, MORCEAUX, and the tests. Family shapes per `test_families.py` (drum=6×16-char strings, mel=6×`_mel` lists).
