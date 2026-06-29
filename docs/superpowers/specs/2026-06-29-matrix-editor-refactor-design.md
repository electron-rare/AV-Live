# Matrix Instrument + Colour Editor Refactor — Design

Date: 2026-06-29
Scope: `web_realart/public/control/` (front) + a small `sound_algo/data_only/matrix.scd` engine extension.

## Context & Goals

The matrix control surface (`control.js`, 1151 lines, vanilla JS, no build step) drives the
SuperCollider data-only engine over a WebSocket-wrapped OSC bridge. The per-voice
instrument + per-(voice,colour) variation editor has grown tangled. Three goals,
validated with the user:

1. **Unify instrument + colour editing** into one coherent per-voice editor.
2. **Better live UX** on **desktop** (mouse/keyboard, large screen) — keep the grid visible.
3. **Maintainability** — split the monolith into ES modules, single source of truth.

Two feature additions requested during design:

4. **Adaptive step sequencer** — note pitch (piano-roll) for melodic voices, drum-machine
   (on/off + accent) for percussion, with a per-voice toggle.
5. **A SYNTH/FX tab** to edit the instrument's parameters and effects (full scope:
   cutoff, resonance, reverb send, pan, amp, octave, stretch — requires a small engine
   extension since `res`/`rev` are not yet driven statically).

## Current State (frictions, from code audit)

- **Instrument chosen in two places**: the `.minst` dropdown in each grid row (per-voice,
  `matInst`) AND the per-colour `inst` field inside the modal — no shared widget.
- **`colordef-modal` is a full-screen overlay** (`position:fixed; inset:0`) → it hides the
  grid while editing.
- **Six-colour palette triplicated**: CSS `.mcell.m1..m6`, CSS `.cd-row/.seq-row`, and JS
  `COLORS` array — must diverge eventually.
- **Monolithic OSC inbound handler** (~250 lines, l.34-286) mutates every state global and
  calls every renderer — the central coupling hub.
- **Two voice-addressing schemes**: grid/colordef use index `vi`, mixer uses voice-name.
- **Engine params**: SynthDefs accept `cutoff, res, pan, rev` (reverb send); the matrix only
  pushes `cutoff`/`pan` statically (gated by `~matModTargets`), `rev` only via modulation,
  `res` not at all.

## Design

### A. Voice editor — inline accordion with tabs

Each grid voice row becomes:

```
[label] [instrument ▾] [▷]   ■·■·■·■·…  (64 colour cells)
```

- **One instrument dropdown per voice** (removes the grid/modal duplication — the unification).
- Clicking **▷** (or the label) **expands an editor row directly under the voice**, in the grid.
  **Only one voice expanded at a time** (opening another collapses the previous) so height stays
  bounded with 22 voices. The grid stays visible — no full-screen modal.
- The `colordef-modal` overlay is **removed**.
- The expanded editor is **tabbed**:
  - **STEPS** — the adaptive step sequencer (section B), for the currently selected colour.
  - **SYNTH/FX** — instrument params + effects (section C), for the currently selected colour.
  - **MOD / POSE** — capture-modulation (source→target→depth) and pose bindings
    (poseId→action), as today, grouped in one tab.
- A **colour selector ①–⑥** sits above the tabs; it sets the active colour all tabs edit.
- **AUDITION** button moves from the modal head into the editor row.
- **Advanced (collapsed by default): per-colour instrument override.** The engine supports
  `spec.inst`; expose it as an optional "advanced" disclosure, default "= voice instrument".

### B. Step sequencer — adaptive Pitch / Drum

The step model is unchanged: `steps[s] = {degree, vel}` or `null`, 16 steps, sent via
`/matrix/step vi colour step degree vel`. This is purely a better UI over the same data.

- **Pitch mode (piano-roll)** for melodic voices: vertical axis = scale degrees (default ~2
  octaves, vertically scrollable for very low `sub` / high `bells`), horizontal = 16 steps.
  Click places/moves a note at (step, degree); velocity via wheel or a per-step level. Shows
  the actual melody contour.
- **Drum mode (beat box)** for percussion: 16 on/off pads + accent/velocity (no pitch;
  `degree` written as 0).
- **Per-voice toggle Pitch/Drum** with a smart default by voice class (section below).
  `perc`/`tom` default to Drum but can switch to Pitch (the engine treats them as pitched).

### C. SYNTH/FX tab (+ small engine extension)

Per **(voice, colour)** the tab edits: **cutoff, resonance (res), reverb send (rev), pan,
amp, octave, stretch**. `cutoff/res/rev/pan` are shown only for voices whose SynthDef accepts
them (gated, see classification).

Engine extension (`matrix.scd`) — minimal, the SynthDefs already accept `res`/`rev`:

1. `~matDefaultColorDefs`: add `res: nil, rev: nil` to each colour def.
2. `~matVariationOverlay` and `~matColorStepPattern`: push `\res` and `\rev` to the Pbind when
   non-nil and the voice supports them (same pattern as the existing `\cutoff`/`\pan` push).
3. `~matLoadFile`: add `\res, \rev` to the per-colour field copy list (currently
   `[\stretch,\octave,\amp,\inst,\cutoff,\pan]`).
4. OSC: `/matrix/colordefs` push and `/matrix/colordef vi colour field value` set already carry
   arbitrary fields — extend the bulk-push arg layout to include res/rev; `setCD` works as-is.

No new FX buses (delay/distortion were considered and deferred — see Non-goals).

### D. Code architecture — ES modules

`index.html` switches `control.js` to `<script type="module">`. Split into:

- **`osc.js`** — `ws`, `send`, and a dispatch registry `on(address, fn)` replacing the 250-line
  switch. Each concern registers its own handlers.
- **`matrix-state.js`** — `MATRIX_VOICES`, `MATRIX_BARS`, `INST_CHOICES`, mod sources/targets,
  the **single colour palette**, voice classification, `matGrid/matInst/matColorDefs`, `mkColor`,
  `saveMatState/loadMatState`. Pure data + persistence, no DOM.
- **`matrix-grid.js`** — grid render (accordion rows), `applyMatCellColor`, `cellRefs`, glow,
  timeline.
- **`voice-editor.js`** — the tabbed accordion editor (colour selector, STEPS, SYNTH/FX,
  MOD/POSE) + its own OSC handlers (`/matrix/colordefs|steps|colormod|colorpose`).
- **`mixer.js`** — fader/mute strips.
- **`sequencer.js`**, **`launchpad.js`**, **`scenes.js`**, **`transport.js`** — orthogonal concerns.
- **`main.js`** — bootstrap, tab switching, top-level wiring.

### E. Single palette + OSC registry

- **One colour palette** in `matrix-state.js` (`['#c22','#1a8','#25b','#990','#c60','#82a']`),
  exposed to CSS as custom properties `--m1..--m6`; CSS `.mcell`/cell classes consume the vars.
  Removes the CSS/CSS/JS triplication.
- **OSC dispatch registry** in `osc.js`: `on('/matrix/grid', fn)` etc. Eliminates the monolithic
  handler and the modal-DOM coupling (`!document.getElementById('colordef-modal').hidden` checks).

## Voice classification (melodic vs drum)

A single map in `matrix-state.js` drives both the step-mode default and which SYNTH/FX controls
show:

- **Melodic (Pitch default; cutoff+res+rev+pan)**: `sub, acid, arp, lead, stab, pad, reese,
  bells, melody, chord`.
- **Percussion (Drum default; pan+rev only, no cutoff/res)**: `kick, hats, clap, snare, shaker,
  ride, rim, crash, fx, sweep`.
- **Semi-tonal (Drum default, Pitch allowed)**: `perc, tom`.

(Aligned with the engine `pitched` set; `res` shown only where the SynthDef has a filter.)

## Compatibility & persistence

- **OSC protocol**: same addresses; only the `colordef` field set gains `res`/`rev` values
  (backward-compatible — older presets simply omit them, defaulting nil).
- **Persistence** `localStorage avlive.matrix` keeps shape `{grid, inst, cdef}`; colour defs
  gain optional `res`/`rev` (back-filled to nil on load, like the existing steps/pose/mod).
- **`.matrix` preset files**: unchanged; `res`/`rev` are optional new colour-def fields.
- The v3 presets just shipped (`8ebd028`) keep working unchanged.

## Non-goals

- No new FX buses (delay/distortion sends) — would require SC bus architecture; deferred.
- No change to the matrix grid arrangement model, the 22×64 dimensions, or the SC scene/boot.
- No framework/build-step introduction — stay vanilla ES modules, no bundler.
- No mixer redesign (fader/mute strips stay as-is).

## Testing & verification

- Keep `web_realart/test/matrix_glow.test.mjs` green; add light unit tests for `matrix-state`
  (palette source-of-truth, save/load round-trip, voice classification).
- Re-run `sound_algo/data_only/test/test_matrix.scd` after the engine extension (res/rev).
- Re-run the headless preset validator (`validate_presets.scd`) — 28/28 must still load+stream.
- Browser smoke test (Playwright/Chrome) on `supra-m1.local:4400/control/`: expand a voice,
  switch tabs, edit a step in Pitch and Drum mode, set cutoff/res/reverb, AUDITION, confirm OSC
  egress and no regressions in grid/mixer/transport.
- Fix the stale "16×32" comments → "22×64".

## Risks

- Large front rewrite → UI regression risk. Mitigated by unchanged OSC protocol + persistence,
  and the browser smoke test.
- Engine `res`/`rev` push must be gated to voices whose SynthDef accepts them (drums lack a
  filter `res`) — wrong gating would send dead params (harmless) or miss controls.
- The user iterates in parallel on these files — coordinate before large edits.

## Module / file plan (deliverables)

```
web_realart/public/control/
  index.html         (script type=module; remove colordef-modal; accordion markup)
  control.css        (palette via --m1..--m6; accordion + tab styles; drop .cd-modal)
  js/
    osc.js
    matrix-state.js
    matrix-grid.js
    voice-editor.js
    mixer.js
    sequencer.js
    launchpad.js
    scenes.js
    transport.js
    main.js
sound_algo/data_only/matrix.scd   (res/rev colour-def fields + push + load + OSC)
```
