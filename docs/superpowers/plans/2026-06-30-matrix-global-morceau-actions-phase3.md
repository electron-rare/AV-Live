# Matrix global morceau actions — Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a matrix tempo route (`/matrix/bpm`) and a tempo slider in the Morceau panel. (Per the user's decision the existing global controls — evolve/rate, full-loop, charger-suivant — STAY where they are; Phase 3 only ADDS the tempo control.)

**Architecture:** A new self-contained `~matSetBpm` sets the matrix clock tempo (`(~lp[\clock] ? TempoClock.default).tempo = bpm/60`) and echoes `/matrix/bpm`; the web Morceau panel gains a single tempo slider wired to it. No existing controls are moved; `main.js` is not touched.

**Tech Stack:** SuperCollider (sclang), vanilla ES modules + `node --test`.

## Global Constraints

- SC env vars `~xxx` lowercase. `matrix.scd` stays ONE top-level block — `awk` balance `P:0 B:0` after every edit:
  `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/data_only/matrix.scd`
- sclang: `/Applications/SuperCollider.app/Contents/MacOS/sclang <file>` (NOT on PATH; no `timeout`). Harness: `cd sound_algo/data_only/matrix_presets && sclang test_global_actions.scd` → `GLOBALACT PASS`.
- Web tests: `cd web_realart && node --test test/*.test.mjs` (GLOB).
- Commit subject ≤ 50, no underscore in scope, no AI attribution, no `--no-verify`. No emojis.
- BPM range clamp `[20, 300]`. The matrix clock is `~lp[\clock] ? TempoClock.default`. BPM is a LIVE global param (NOT persisted per-morceau in this phase) — synced via `/matrix/bpm` echo + `/matrix/bpm/get`.
- ADD ONLY a tempo control. Do NOT move, delete, or re-id the existing matrix controls (`matrix-evolve`, `matrix-evolve-rate`, `matrix-loop-full`, `matrix-loadnext`). Do NOT touch `main.js`.
- No `data_only_viz` changes. Deploy on user request only (live rig).

## File Structure

- `sound_algo/data_only/matrix.scd` — `~matBpm`, `~matSetBpm`, `~matBpmPush`, OSCdefs `/matrix/bpm` + `/matrix/bpm/get`.
- `sound_algo/data_only/matrix_presets/test_global_actions.scd` — bpm harness check.
- `web_realart/public/control/index.html` — a tempo control appended inside `#morceau-panel` (no other element moved).
- `web_realart/public/control/js/morceau-panel.js` — wire `#matrix-bpm` → `/matrix/bpm` + inbound sync.
- `web_realart/public/control/control.css` — tempo-control styles.

---

### Task 1: SC — `/matrix/bpm` tempo route

**Files:** Modify `sound_algo/data_only/matrix.scd` (global-actions block + OSCdefs near `\mat_globalsettings`). Modify `sound_algo/data_only/matrix_presets/test_global_actions.scd`.

**Interfaces:**
- Consumes: `~lp[\clock]`, `~toscSend`/`~toscTouch`.
- Produces: `~matBpm` (Float), `~matSetBpm.(bpm)`, `~matBpmPush.()`, OSC `/matrix/bpm` (set+echo) + `/matrix/bpm/get`.

- [ ] **Step 1: Append failing harness check** to `test_global_actions.scd`, before the final `pass.if(...)`:
```supercollider
// -- O: bpm sets the matrix clock tempo + tracks ~matBpm --
~matSetBpm.(140);
(~matBpm == 140).not.if({ pass = false; "FAIL: ~matBpm not 140".postln });
(((~lp[\clock] ? TempoClock.default).tempo - (140 / 60)).abs < 1e-6).not.if({ pass = false; "FAIL: clock tempo not 140 bpm".postln });
~matSetBpm.(500);                                       // clamps to 300
(~matBpm == 300).not.if({ pass = false; "FAIL: bpm not clamped to 300".postln });
~matSetBpm.(120);                                       // restore
```

- [ ] **Step 2: Run — expect FAIL** (`~matSetBpm` undefined).
Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: error on `~matSetBpm` or `GLOBALACT FAIL`.

- [ ] **Step 3: Add the bpm setter + push.** In the global-actions block (e.g. after `~matGlobalSettingsPush`), add:
```supercollider
~matBpm = ~matBpm ? 120;
~matSetBpm = { |bpm|
    var b = bpm.asFloat.clip(20, 300);
    ~matBpm = b;
    (~lp[\clock] ? TempoClock.default).tempo = b / 60;
    ~toscSend !? { ~toscSend.("/matrix/bpm", b) };
};
~matBpmPush = { ~toscSend !? { ~toscSend.("/matrix/bpm", ~matBpm) } };
```

- [ ] **Step 4: Add the OSC routes.** After the `\mat_globalsettings_get` OSCdef, add:
```supercollider
OSCdef(\mat_bpm, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetBpm.((msg[1] ? 120))
}, '/matrix/bpm');
OSCdef(\mat_bpm_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matBpmPush.()
}, '/matrix/bpm/get');
```

- [ ] **Step 5: Balance + harness.**
`awk` balance → `P:0 B:0`; `sclang test_global_actions.scd` → `GLOBALACT PASS` (A–O).

- [ ] **Step 6: Commit.**
```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_global_actions.scd
git commit -m "feat(matrix): matrix bpm tempo route"
```

---

### Task 2: Web — tempo slider in the Morceau panel

**Files:** Modify `web_realart/public/control/index.html`, `web_realart/public/control/js/morceau-panel.js`, `web_realart/public/control/control.css`. Do NOT modify `main.js`. Do NOT move/delete any existing element.

**Interfaces:**
- Consumes: `send`/`on`/`onOpen` from `osc.js`; the SC `/matrix/bpm` route from Task 1.
- Produces: a `#matrix-bpm` tempo slider (with a live readout) inside `#morceau-panel`, wired to `/matrix/bpm`.

- [ ] **Step 1: Add the tempo control in `index.html`.** Inside `#morceau-panel`, as the FIRST child (before `<div class="morceau-title">Actions globales (morceau)</div>`), add:
```html
    <div class="morceau-global">
      <label class="morceau-bpm">Tempo <input id="matrix-bpm" type="range" min="20" max="300" step="1" value="120"><output id="matrix-bpm-out">120</output></label>
    </div>
```
Do not touch any other element.

- [ ] **Step 2: Wire the tempo slider in `morceau-panel.js`.** Inside `init()`, after the Réglages block (before the function ends), add:
```javascript
  // --- Global: matrix tempo slider (existing evolve/loop/suivant stay in place) ---
  const bpm = document.getElementById("matrix-bpm");
  const bpmOut = document.getElementById("matrix-bpm-out");
  if (bpm) {
    bpm.addEventListener("input", () => { if (bpmOut) bpmOut.textContent = bpm.value; });
    bpm.addEventListener("change", () => send("/matrix/bpm", +bpm.value));
    on("/matrix/bpm", (args) => {
      const v = Math.round(Number(args[0]));
      if (Number.isFinite(v)) { bpm.value = v; if (bpmOut) bpmOut.textContent = v; }
    });
    onOpen(() => send("/matrix/bpm/get"));
    send("/matrix/bpm/get");
  }
```

- [ ] **Step 3: Style the control.** Append to `control.css`:
```css
.morceau-global { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin-bottom: 8px; }
.morceau-global .morceau-bpm { display: inline-flex; align-items: center; gap: 4px; font-size: 12px; color: #ccc; }
.morceau-global .morceau-bpm output { min-width: 2.5em; text-align: right; color: #8c8; }
```

- [ ] **Step 4: Parse + suite + no-collision check.**
Run: `cd web_realart && node --check public/control/js/morceau-panel.js` (no output) and `node --test test/*.test.mjs` (all green). Confirm `#matrix-bpm` is unique and the existing four controls are untouched:
`grep -c 'id="matrix-bpm"' public/control/index.html` → `1`; `for id in matrix-evolve matrix-evolve-rate matrix-loop-full matrix-loadnext; do echo -n "$id: "; grep -c "id=\"$id\"" public/control/index.html; done` → each `1`.

- [ ] **Step 5: Commit.**
```bash
git add web_realart/public/control/index.html web_realart/public/control/js/morceau-panel.js web_realart/public/control/control.css
git commit -m "feat(control): matrix tempo slider in panel"
```

---

### Task 3: Deploy + live smoke (macm1)

**Files:** none.

- [ ] **Step 1:** On user OK: `git push origin main`; `ssh macm1 'cd ~/Documents/Projets/AV-Live && git pull --ff-only'`; SC-only reboot (kill `sclang boot.scd` + `scsynth`; relaunch `cd ~/Documents/Projets/AV-Live/sound_algo/data_only && MATRIX_ONLY=1 nohup script -q /tmp/sc_boot.log /Applications/SuperCollider.app/Contents/MacOS/sclang boot.scd &`; wait for `[matrix] ready`). Hard-reload the web page.
- [ ] **Step 2:** Confirm the Morceau panel shows a Tempo slider; dragging it changes the matrix speed live and the value echoes back; the existing ÉVOLUE / BOUCLE / SUIVANT controls remain in their original place and still work; Réglages + gesture slots unaffected. Report to the user.

---

## Self-review

**Spec coverage (Phase 3, scoped down per user):** matrix tempo route `/matrix/bpm` → Task 1; tempo slider in the panel → Task 2; controls left in place (no consolidation, per user) → Constraints + Task 2 (add-only). Smoke → Task 3. ✓

**Placeholder scan:** all code present; BPM clamp `[20,300]`, ids exact, no TBD.

**Type consistency:** `~matSetBpm.(bpm)` sets `~matBpm` (Float) + clock tempo; `~matBpmPush`/`\mat_bpm`/`\mat_bpm_get` all use `/matrix/bpm` with a single Float arg; the web `#matrix-bpm` sends `+bpm.value` (Number) and `on("/matrix/bpm")` reads `args[0]` — same single-value contract. No existing id is moved or duplicated; `main.js` untouched.
