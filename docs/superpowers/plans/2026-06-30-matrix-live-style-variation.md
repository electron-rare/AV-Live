# Matrix `_live` per-style variation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Checkbox (`- [ ]`) steps.

**Goal:** Make each morceau's `_live` loop breathe in a style-appropriate way (per-genre colour variation + phrase-end fills) while staying full.

**Architecture:** `LIVE_STYLE` maps morceau->style; `LIVE_VAR` holds per-style profiles; `make_live_continuous(g, style)` tiles the plateau then `_live_variation(g, style)` recolours active cells per block + adds phrase-end fills. Wired via `to_sc(post=)` in `main`, mirrored in `test_sections`.

**Tech Stack:** Python 3 (`uv run python`) + SC validation harness.

## Global Constraints

- Python uv only; no emojis; commit subject ≤ 50, body ≤ 72/line, no AI attribution, no underscore in scope.
- Variation recolours ACTIVE cells only (`> 0`) -> density unchanged, no voice dropped. `BARS == 64`, blocks of 16. Rhythmic busy -> colour 2/4, melodic -> 3, fills -> 6.
- SC validate -> `84/84 PASS` + `DEFAULTS PASS`, deterministic. Push/deploy on request (rig live).

---

### Task 1: per-style variation + wiring + test

**Files:** Modify `generate_presets.py` (`LIVE_STYLE`, `LIVE_VAR`, `make_live_continuous`, `_live_variation`, `main`), `test_sections.py`, regenerated `*.matrix`.

- [ ] **Step 1: Update `test_sections.py` (failing).** Pass the style + add a "variation present" check.
  In `grid_of`:
  ```python
      if sec == "live":
          G.make_live_continuous(g, G.LIVE_STYLE.get(name, "techno"))
  ```
  After the existing live density checks, add:
  ```python
      # the live loop must vary: its four 16-bar blocks are not all identical
      blocks_differ = any(
          len({tuple(row[i*16:i*16+16]) for i in range(4)}) > 1 for row in live)
      check(blocks_differ, "%s live has no variation (4 identical blocks)" % name)
  ```

- [ ] **Step 2: Run — expect FAIL** (`make_live_continuous` takes 1 arg / `LIVE_STYLE` undefined).

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_sections.py`
Expected: `TEST FAIL` (TypeError / AttributeError).

- [ ] **Step 3: Add `LIVE_STYLE` + `LIVE_VAR` + `_live_variation`** to `generate_presets.py` (just after `make_live_continuous`):
  ```python
  LIVE_STYLE = {}
  for _s, _names in {
      "techno": ("techno_drive", "detroit_soul", "peak_drop", "rave_stab", "acid_journey"),
      "psy":    ("dub_techno", "psytrance_roll", "minimal_hypno", "hypnotic_arp"),
      "trance": ("trance_euphoria", "melodic_builder", "melodic_deep", "progressive_lift", "synthwave_drive"),
      "breaks": ("breakbeat", "bass_science", "jungle_amen", "dnb_roller", "footwork_chop", "neuro_reese", "tribal_perc"),
      "electro": ("electro_808", "ebm_body", "electro_funk"),
      "industrial": ("schranz_drive", "industrial_grind", "hardcore_punk"),
      "ambient": ("ambient_intro",),
  }.items():
      for _n in _names: LIVE_STYLE[_n] = _s

  LIVE_VAR = {
      "techno":     dict(busy=["hats", "perc"],          busy_blocks=[1, 3], busy_color=4, fill=["snare", "clap", "perc"]),
      "psy":        dict(busy=["acid", "arp", "reese"],   busy_blocks=[1, 3], busy_color=3, fill=["perc"]),
      "trance":     dict(busy=["arp", "lead"],            busy_blocks=[2],    busy_color=3, fill=["snare", "clap"]),
      "breaks":     dict(busy=["snare", "shaker"],        busy_blocks=[1, 3], busy_color=2, fill=["snare", "perc", "tom"]),
      "electro":    dict(busy=["hats", "clap"],           busy_blocks=[1, 3], busy_color=2, fill=["clap", "perc"]),
      "industrial": dict(busy=["perc", "tom"],            busy_blocks=[1, 3], busy_color=2, fill=["kick", "perc", "tom"]),
      "ambient":    dict(busy=["bells", "melody"],        busy_blocks=[2],    busy_color=3, fill=[]),
  }

  def _live_variation(g, style):
      """Per-style life in the full loop: recolour active cells in some blocks
      (busier/octave) + phrase-end fills. Active cells only -> density kept."""
      prof = LIVE_VAR.get(style, LIVE_VAR["techno"])
      for blk in prof["busy_blocks"]:
          for v in prof["busy"]:
              vi = VI[v]
              for b in range(blk * 16, blk * 16 + 16):
                  if g[vi][b] > 0: g[vi][b] = prof["busy_color"]
      for blk in range(BARS // 16):
          for v in prof["fill"]:
              vi = VI[v]
              for b in (blk * 16 + 14, blk * 16 + 15):
                  if g[vi][b] > 0: g[vi][b] = 6
      return g
  ```

- [ ] **Step 4: Extend `make_live_continuous` to take + apply the style.** Change its signature to `make_live_continuous(g, style="techno")` and, after the tiling loop (before `return g`), call `_live_variation(g, style)`.

- [ ] **Step 5: Wire the style in `main()`.** Replace the live post-processor:
  ```python
          for sec in ("intro", "live", "outro"):
              post = ((lambda nm: (lambda gg: make_live_continuous(gg, LIVE_STYLE.get(nm, "techno"))))(name)
                      if sec == "live" else None)
              sc = to_sc("%s_%s" % (name, sec), m[sec], m["instkit"], m["melodies"], m["extra"], post)
  ```

- [ ] **Step 6: Run `test_sections.py` — expect PASS** (density asserts hold + variation present).

- [ ] **Step 7: Regen + determinism + validate.**
  `uv run python generate_presets.py` (twice, zero diff); `sclang validate_presets.scd` -> `84/84` + `DEFAULTS PASS` + `VALIDATE PASS`; `uv run python test_families.py` -> PASS.

- [ ] **Step 8: Commit.**
  ```bash
  git add sound_algo/data_only/matrix_presets/generate_presets.py sound_algo/data_only/matrix_presets/test_sections.py sound_algo/data_only/matrix_presets/*.matrix
  git commit -m "feat(presets): per-style variation in live loop"
  ```

---

### Task 2: deploy + smoke

- [ ] `git push gitea-https main`; macm1 `git pull` + regen; reload a couple of `_live` of different genres (techno_drive_live, breakbeat_live, ambient_intro_live) + play; confirm each loops full but varies in a style-fitting way; report to the user (ear).

---

## Self-review

**Spec coverage:** LIVE_STYLE 7 groups -> Step 3. LIVE_VAR profiles + colours -> Step 3. `_live_variation` recolour-active + phrase-fills -> Step 3. `make_live_continuous(g, style)` -> Step 4. main wiring -> Step 5. test mirror + variation-present -> Steps 1,6. 84/84 + DEFAULTS + determinism -> Step 7. smoke -> Task 2. ✓

**Placeholder scan:** all code present; no TBD.

**Type consistency:** `make_live_continuous(g, style="techno")` (default keeps any 1-arg caller working) called with the morceau style in main + test. `LIVE_STYLE` dict[str,str]; `LIVE_VAR` dict[str, dict]. `_live_variation(g, style)` mutates+returns. `VI`/`BARS` existing. Fills applied after busy so a phrase-end cell ends colour 6 (fill wins).
