# Matrix `_live` continuous groove — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Checkbox (`- [ ]`) steps.

**Goal:** Make every morceau's `_live` section a full continuous loop (plateau tiled across 64 bars) instead of re-introducing with a sparse intro + breakdown.

**Architecture:** Add `make_live_continuous(g)` (tiles the P plateau over all 64 bars), apply it after `apply_colors` for the live section only via a new `to_sc(post=)` param. Mirror it in `test_sections.py` and assert the live is full-from-start with no breakdown dip.

**Tech Stack:** Python 3 (`uv run python`), the SC validation harness.

## Global Constraints

- Python: uv only. No emojis in code/commits. Commit subject ≤ 50, body ≤ 72/line, no AI attribution, no underscore in scope.
- `SECTIONS["P"] == (32, 16)`. Transform moves cells only; never touches mods/poses/instruments/colorDefs.
- SC validate: `sclang sound_algo/data_only/matrix_presets/validate_presets.scd` → `84/84 PASS` + `DEFAULTS PASS`. Deterministic regen. Push/deploy on user request (rig is live).

---

### Task 1: make_live_continuous + wiring + test

**Files:** Modify `generate_presets.py` (`make_live_continuous`, `to_sc`, `main`), `test_sections.py`, regenerated `*.matrix`.

- [ ] **Step 1: Update `test_sections.py` to the new expectation (failing).** In `grid_of`, apply the live transform; add the "full from start, no breakdown dip" assertion:

```python
def grid_of(name, sec):
    m = G.MORCEAUX[name]
    g = G.blank(); m[sec](g)
    if m.get("extra"): m["extra"](g)
    G.apply_colors(g)
    if sec == "live":
        G.make_live_continuous(g)        # mirror the generator
    return g
```
Add, after the existing per-morceau checks (intro builds / outro breaks / live densest):
```python
    # live is a full continuous loop: every 16-bar block ~ the plateau (no intro
    # ramp, no breakdown dip).
    p022 = active_in(live, 0, 16); p3248 = active_in(live, 32, 48)
    p4864 = active_in(live, 48, 64)
    check(p3248 > 0 and abs(p022 - p3248) <= 0.15 * p3248,
          "%s live not full from start (%d vs plateau %d)" % (name, p022, p3248))
    check(p3248 > 0 and abs(p4864 - p3248) <= 0.15 * p3248,
          "%s live has a breakdown dip (%d vs plateau %d)" % (name, p4864, p3248))
```

- [ ] **Step 2: Run it — expect FAIL** (`make_live_continuous` undefined + the raw live is not full from start).

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_sections.py`
Expected: `TEST FAIL` (AttributeError on `make_live_continuous`, or the full-from-start check fails).

- [ ] **Step 3: Add `make_live_continuous`** to `generate_presets.py` (near `apply_colors`):

```python
def make_live_continuous(g):
    """Live = the plateau groove tiled across all 64 bars: full from bar 0, no
    intro ramp, no breakdown. The intro builds to it, the outro descends from it."""
    ps, pn = SECTIONS["P"]            # (32, 16)
    for row in g:
        plateau = row[ps:ps + pn]
        for b in range(len(row)):
            row[b] = plateau[(b - ps) % pn]
    return g
```

- [ ] **Step 4: Thread `post` through `to_sc` + `main`.** In `to_sc`, add the param and call it after `apply_colors`:
```python
def to_sc(name, arc_fn, instkit, melodies, extra, post=None):
    ...
    apply_colors(g)
    if post is not None:
        post(g)
    ...
```
In `main()`, pass it for the live section only:
```python
    for name, m in MORCEAUX.items():
        for sec in ("intro", "live", "outro"):
            post = make_live_continuous if sec == "live" else None
            sc = to_sc("%s_%s" % (name, sec), m[sec], m["instkit"], m["melodies"], m["extra"], post)
            ...
```

- [ ] **Step 5: Run `test_sections.py` — expect PASS.**

Run: `uv run python test_sections.py`
Expected: `TEST PASS` (intro builds, outro breaks, live densest + full-from-start + no breakdown dip).

- [ ] **Step 6: Regenerate + determinism + SC validate.**

Run: `uv run python generate_presets.py` (84 files); run twice → zero diff. Then
`sclang validate_presets.scd` → `OK: 84/84` + `DEFAULTS PASS` + `VALIDATE PASS`.
Also `uv run python test_families.py` → `TEST PASS` (unaffected).

- [ ] **Step 7: Commit.**
```bash
git add sound_algo/data_only/matrix_presets/generate_presets.py sound_algo/data_only/matrix_presets/test_sections.py sound_algo/data_only/matrix_presets/*.matrix
git commit -m "feat(presets): live = continuous full loop"
```

---

### Task 2: deploy + live smoke

- [ ] **Step 1:** `git push gitea-https main`; macm1 `git pull` + `uv run python generate_presets.py`; reload a `_live` preset (`/matrix/load techno_drive_live` + `/matrix/play`).
- [ ] **Step 2:** Confirm the live plays full from bar 0, loops cleanly, no intro/breakdown; `_intro`/`_outro` unchanged. Report to the user (their ear).

---

## Self-review

**Spec coverage:** `make_live_continuous` (plateau tiled) → Task 1 Step 3. Applied post-apply_colors, live only, via `to_sc(post=)` → Steps 3-4. test_sections mirror + full-from-start + no-breakdown asserts → Steps 1-2,5. 84/84 + DEFAULTS + determinism → Step 6. Smoke → Task 2. ✓

**Placeholder scan:** all code present; no TBD. The 15% tolerance is explicit.

**Type consistency:** `make_live_continuous(g)` mutates+returns the grid (list of rows), called in `to_sc` (post) and `test_sections.grid_of`. `to_sc` signature gains `post=None` (default keeps intro/outro callers correct). `SECTIONS["P"]` = (32,16) used identically in transform + asserts.
