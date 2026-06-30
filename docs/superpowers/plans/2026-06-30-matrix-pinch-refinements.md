# Matrix pinch refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make finger pinches hold-to-fire (held ≥ an adjustable duration) with a per-slot progress indicator and a 2-column MG/MD menu, and run the pinch detector without the air-piano.

**Architecture:** `data_only_viz` emits pinch ENGAGE/RELEASE edges (`/pose/pinch [pid, hand, finger, state]`); the SC engine times the hold (`Main.elapsedTime` vs `~matPinchHoldMs`), fires the mapped global action only past the threshold, and streams `/matrix/pinchprogress [slot, 0..1]` to the panel. The decouple (`PINCH_ENABLE`) is already committed; the launcher switch + the menu (2 columns, hold slider, progress fill) follow.

**Tech Stack:** Python 3 (uv), SuperCollider (sclang), vanilla ES modules + `node --test`, zsh launcher.

## Global Constraints

- SC env vars `~xxx` lowercase. `matrix.scd` stays ONE top-level block — `awk` balance `P:0 B:0` after every edit:
  `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/data_only/matrix.scd`
- sclang: `/Applications/SuperCollider.app/Contents/MacOS/sclang <file>` (NOT on PATH; no `timeout`). Harness: `cd sound_algo/data_only/matrix_presets && sclang test_global_actions.scd` → `GLOBALACT PASS`.
- Python: `data_only_viz/.venv/bin/python -m pytest tests/<file> -q` from the `data_only_viz` dir. `finger_strike.py` + `pose_bridge.py` tests need NO torch (run locally); `action_head*` tests need torch (NOT runnable on GrosMac — that path is already committed + verified on macm1 at deploy).
- Generator: `cd sound_algo/data_only/matrix_presets && uv run python ...`. Web: `cd web_realart && node --test test/*.test.mjs` (GLOB).
- Commit subject ≤ 50, no underscore in scope, no AI attribution, no `--no-verify`. No emojis.
- Slot = `hand*4 + (finger-1)` (0..7). `/pose/pinch` msg: `hand=msg[2]`, `finger=msg[3]`, `state=msg[4]` (1=engage, 0=release).
- Hold is REAL-TIME (`Main.elapsedTime`, ms), default `~matPinchHoldMs = 300`, clamp 50..2000, live via `/matrix/pinchhold`, saved per `.matrix` as top-level `pinchHoldMs` (separate from `globalSettings`). Per-voice pinch bindings still fire on ENGAGE (no hold). No `data_only_viz` change beyond the edges (the air-piano decouple is committed at 4bccbc1).

## File Structure

- `data_only_viz/finger_strike.py` — `PinchEvent.state`; emit engage(1)+release(0) edges (+ release on hand-disappear).
- `data_only_viz/pose_bridge.py` — `send_pinch` adds `state`.
- `data_only_viz/tests/{test_finger_strike.py,test_pose_bridge_finger.py}` — edge + state coverage.
- `launcher/concert/launch_concert.sh` — `PINCH_ENABLE` instead of `FINGER_PIANO`.
- `sound_algo/data_only/matrix.scd` — `~matPinchHoldMs`/`~matPinchHeld`/`~matPinchFired`/`~matPinchTick`/poller; `\mat_ev_pinch` rework; `/matrix/pinchhold[/get]` + `/matrix/pinchprogress`; save/load.
- `sound_algo/data_only/matrix_presets/{generate_presets.py,test_global_actions.{py,scd}}` — `pinchHoldMs` emit + harness P rework.
- `web_realart/public/control/{js/matrix-state.js,js/morceau-panel.js,index.html,control.css}` + `web_realart/test/matrix-state.test.mjs`.

---

### Task 1: data_only_viz pinch edges + launcher

**Files:** Modify `data_only_viz/finger_strike.py`, `data_only_viz/pose_bridge.py`, `data_only_viz/tests/test_finger_strike.py`, `data_only_viz/tests/test_pose_bridge_finger.py`, `launcher/concert/launch_concert.sh`.

**Interfaces:**
- Produces: `/pose/pinch [0, hand, finger, state]` with `state` 1=engage / 0=release; `PinchEvent(hand, finger, state)`.

- [ ] **Step 1: Failing tests.** Read `tests/test_finger_strike.py` to match its hand-builder helpers, then add a test that an engage→release sequence emits a `state=1` then a `state=0` `PinchEvent` for the same (hand, finger). Add to `tests/test_pose_bridge_finger.py` a test that `send_pinch` puts the state as the 4th arg of `/pose/pinch` (build a fake event with `.state`). (Use the files' existing patterns; the detector fires a pinch when the thumb tip is within `ratio_on*size` of a finger tip, and releases above `ratio_off*size`.)

- [ ] **Step 2: Run — expect FAIL.**
Run: `cd data_only_viz && .venv/bin/python -m pytest tests/test_finger_strike.py tests/test_pose_bridge_finger.py -q`
Expected: new tests FAIL (no `state` field / no release event / 3-arg pinch).

- [ ] **Step 3: Add the `state` edges in `finger_strike.py`.** Change `PinchEvent`:
```python
@dataclass
class PinchEvent:
    hand: int          # 0 = left slot (leftmost cx), 1 = right slot
    finger: int        # 1..4 = index, middle, ring, pinky (thumb is trigger)
    state: int = 1     # 1 = engage edge, 0 = release edge
```
In `PinchDetector.step`, emit both edges. Replace:
```python
                if st.engaged:
                    if ratio > self.ratio_off:
                        st.engaged = False
                elif ratio < self.ratio_on and (
                        t_now - st.last_t) >= self.refractory_s:
                    st.engaged = True
                    st.last_t = t_now
                    events.append(PinchEvent(hand=slot, finger=i + 1))
```
with:
```python
                if st.engaged:
                    if ratio > self.ratio_off:
                        st.engaged = False
                        events.append(PinchEvent(hand=slot, finger=i + 1, state=0))
                elif ratio < self.ratio_on and (
                        t_now - st.last_t) >= self.refractory_s:
                    st.engaged = True
                    st.last_t = t_now
                    events.append(PinchEvent(hand=slot, finger=i + 1, state=1))
```
And emit a release when an engaged hand disappears. Replace:
```python
        for slot in range(len(self._state)):
            if slot not in present:
                for i in range(4):
                    self._state[slot][i].engaged = False
        return events
```
with:
```python
        for slot in range(len(self._state)):
            if slot not in present:
                for i in range(4):
                    if self._state[slot][i].engaged:
                        self._state[slot][i].engaged = False
                        events.append(PinchEvent(hand=slot, finger=i + 1, state=0))
        return events
```

- [ ] **Step 4: Add `state` to `send_pinch` in `pose_bridge.py`.** Replace:
```python
    def send_pinch(self, ev) -> None:
        """Emit one thumb-to-finger pinch event (clip toggle trigger)."""
        args = [0, int(ev.hand), int(ev.finger)]
```
with:
```python
    def send_pinch(self, ev) -> None:
        """Emit a thumb-to-finger pinch edge (state 1=engage, 0=release)."""
        args = [0, int(ev.hand), int(ev.finger), int(getattr(ev, "state", 1))]
```

- [ ] **Step 5: Run — expect PASS.**
Run: `cd data_only_viz && .venv/bin/python -m pytest tests/test_finger_strike.py tests/test_pose_bridge_finger.py -q`
Expected: all green.

- [ ] **Step 6: Launcher → `PINCH_ENABLE`.** In `launcher/concert/launch_concert.sh`, replace:
```bash
# Finger pinches drive the matrix global actions (8 slots). Enabling the pinch
# detector also enables the air-piano finger-strike detector, inert unless a
# voice has a finger binding (none by default).
export FINGER_PIANO="${FINGER_PIANO:-1}"
```
with:
```bash
# Finger pinches drive the matrix global actions (8 slots). PINCH_ENABLE gates
# ONLY the pinch detector; the air-piano finger-strike (FINGER_PIANO) stays off.
export PINCH_ENABLE="${PINCH_ENABLE:-1}"
```
Verify: `zsh -n launcher/concert/launch_concert.sh` → no output.

- [ ] **Step 7: Commit.**
```bash
git add data_only_viz/finger_strike.py data_only_viz/pose_bridge.py data_only_viz/tests/test_finger_strike.py data_only_viz/tests/test_pose_bridge_finger.py launcher/concert/launch_concert.sh
git commit -m "feat(pose): pinch engage/release edges + launcher"
```

---

### Task 2: SC — hold-to-fire timing + progress

**Files:** Modify `sound_algo/data_only/matrix.scd` + `sound_algo/data_only/matrix_presets/test_global_actions.scd`.

**Interfaces:**
- Consumes: `~matFireGlobal`, `~matEventPinch`, `~matPoseFire`, `~toscSend`/`~toscTouch`, `~matSave`/`~matLoadFile`.
- Produces: `~matPinchHoldMs`, `~matPinchHeld`, `~matPinchFired`, `~matPinchTick`, `~matPinchHoldPush`; `/matrix/pinchhold[/get]` set+echo; `/matrix/pinchprogress [slot, prog]` stream; `pinchHoldMs` saved per `.matrix`.

- [ ] **Step 1: Rework harness group P (failing).** In `test_global_actions.scd`, REPLACE the existing `// -- P:` block with:
```supercollider
// -- P: pinch hold-to-fire (engage doesn't fire; fires past hold; release cancels) --
~matPinchRoutine !? { ~matPinchRoutine.stop };
~matGlobalActions = [\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next];
~matPinchHoldMs = 300; ~matTransient = nil;
~matPinchHeld = Array.fill(8, nil); ~matPinchFired = Array.fill(8, false);
OSCdef(\mat_ev_pinch).func.value(['/pose/pinch', 0, 0, 1, 1]);   // L index engage -> slot 0 held
(~matTransient.isNil).not.if({ pass = false; "FAIL: engage fired immediately".postln });
(~matPinchHeld[0].isNil).if({ pass = false; "FAIL: engage did not record hold".postln });
~matPinchHeld[0] = Main.elapsedTime - 0.5;                       // simulate 500ms held (> 300)
~matPinchTick.();
(~matTransient.notNil and: { ~matTransient[\kind] == \fill }).not.if({ pass = false; "FAIL: hold did not fire fill".postln });
~matTransient = nil;
~matPinchHeld = Array.fill(8, nil); ~matPinchFired = Array.fill(8, false);
OSCdef(\mat_ev_pinch).func.value(['/pose/pinch', 0, 1, 1, 1]);   // R index engage -> slot 4
OSCdef(\mat_ev_pinch).func.value(['/pose/pinch', 0, 1, 1, 0]);   // release before hold
~matPinchTick.();
(~matTransient.isNil).not.if({ pass = false; "FAIL: released-early pinch fired".postln });
(~matPinchHeld[4].isNil).not.if({ pass = false; "FAIL: release did not clear hold".postln });
OSCdef(\mat_pinchhold).func.value(['/matrix/pinchhold', 500]);
(~matPinchHoldMs == 500).not.if({ pass = false; "FAIL: pinchhold not set".postln });
~matPinchHoldMs = 300;
// pinchHoldMs save/load roundtrip
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, { \default });
~matColorDefs   = ~matColorDefs   ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
~matSavedNames  = ~matSavedNames  ? Set.new;
~matPinchHoldMs = 420;
~matSave.("zz_phms_test");
~matPinchHoldMs = 300;
~matLoadFile.(~matDir +/+ "zz_phms_test.matrix");
(~matPinchHoldMs == 420).not.if({ pass = false; "FAIL: pinchHoldMs not restored".postln });
("rm -f '" ++ (~matDir +/+ "zz_phms_test.matrix") ++ "'").systemCmd;
```

- [ ] **Step 2: Run — expect FAIL** (`~matPinchTick`/`~matPinchHeld` undefined; old `\mat_ev_pinch` fires immediately).
Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: `GLOBALACT FAIL` / undefined errors.

- [ ] **Step 3: Add the hold state + tick + push.** In the global-actions block (after `~matGlobalActionsPush`), add:
```supercollider
~matPinchHoldMs = ~matPinchHoldMs ? 300;
~matPinchHeld   = ~matPinchHeld   ? Array.fill(8, nil);    // engage time (Main.elapsedTime) or nil
~matPinchFired  = ~matPinchFired  ? Array.fill(8, false);
~matPinchHoldPush = { ~toscSend !? { ~toscSend.("/matrix/pinchhold", ~matPinchHoldMs) } };
~matPinchTick = {
    8.do { |slot|
        (~matPinchHeld[slot].notNil).if({
            var prog = (((Main.elapsedTime - ~matPinchHeld[slot]) * 1000) / ~matPinchHoldMs).clip(0, 1);
            ~toscSend !? { ~toscSend.("/matrix/pinchprogress", slot, prog) };
            ((prog >= 1.0) and: { ~matPinchFired[slot].not }).if({
                ~matPinchFired[slot] = true;
                ~matFireGlobal.(slot);
            });
        });
    };
};
```

- [ ] **Step 4: Rework `\mat_ev_pinch` for engage/release.** Replace the existing OSCdef:
```supercollider
OSCdef(\mat_ev_pinch, { |msg|
    var hand = (msg[2] ? 0).asInteger;
    var finger = (msg[3] ? 1).asInteger;
    ~matPoseFire.(~matEventPinch.(hand, finger));          // per-voice pinch bindings (unchanged)
    ~matFireGlobal.((hand * 4) + (finger - 1));            // global action by pinch slot 0..7
}, '/pose/pinch');
```
with:
```supercollider
OSCdef(\mat_ev_pinch, { |msg|
    var hand = (msg[2] ? 0).asInteger;
    var finger = (msg[3] ? 1).asInteger;
    var state = (msg[4] ? 1).asInteger;
    var slot = (hand * 4) + (finger - 1);
    (state == 1).if({
        ~matPoseFire.(~matEventPinch.(hand, finger));      // per-voice pinch bindings on engage
        (slot >= 0 and: { slot < 8 }).if({
            ~matPinchHeld[slot] = Main.elapsedTime;
            ~matPinchFired[slot] = false;
        });
    }, {
        (slot >= 0 and: { slot < 8 }).if({
            ~matPinchHeld[slot] = nil;
            ~matPinchFired[slot] = false;
            ~toscSend !? { ~toscSend.("/matrix/pinchprogress", slot, 0) };
        });
    });
}, '/pose/pinch');
```

- [ ] **Step 5: Add the OSC routes + the poller.** After `\mat_globalsettings_get` (or near the other matrix OSCdefs), add:
```supercollider
OSCdef(\mat_pinchhold, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matPinchHoldMs = (msg[1] ? 300).asFloat.clip(50, 2000);
    ~matPinchHoldPush.()
}, '/matrix/pinchhold');
OSCdef(\mat_pinchhold_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matPinchHoldPush.()
}, '/matrix/pinchhold/get');
```
Near the engine-tail (where other routines start, e.g. after `~matModValuesRoutine`), add the poller:
```supercollider
~matPinchRoutine !? { ~matPinchRoutine.stop };
~matPinchRoutine = Routine({ loop { ~matPinchTick.(); (1/30).wait } }).play(AppClock);
```

- [ ] **Step 6: Persist `pinchHoldMs`.** In `~matSave`'s `payload`, add after `globalSettings: ~matGlobalSettings`:
```supercollider
        globalSettings: ~matGlobalSettings,
        pinchHoldMs: ~matPinchHoldMs
```
In `~matLoadFile`, just after the `globalSettings` restore block, add:
```supercollider
            ~matPinchHoldMs = ((raw.isArray.not) and: { raw[\pinchHoldMs].notNil }).if({ raw[\pinchHoldMs].asFloat.clip(50, 2000) }, { 300 });
```
And after `~matGlobalSettingsPush.();` add `~matPinchHoldPush.();`.

- [ ] **Step 7: Balance + harness.**
`awk` balance → `P:0 B:0`; `sclang test_global_actions.scd` → `GLOBALACT PASS` (A–P).

- [ ] **Step 8: Commit.**
```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_global_actions.scd
git commit -m "feat(matrix): pinch hold-to-fire + progress"
```

---

### Task 3: Generator — emit `pinchHoldMs`

**Files:** Modify `generate_presets.py` (`to_sc`), `test_global_actions.py`; regenerate `*.matrix`.

- [ ] **Step 1: Test (failing).** In `test_global_actions.py`, add after the `EXPECT_SET` block:
```python
EXPECT_PHMS = "'pinchHoldMs': 300"
check(EXPECT_PHMS in sample, "to_sc output missing pinchHoldMs")
missing_phms = [os.path.basename(f) for f in files
                if EXPECT_PHMS not in open(f, encoding="utf-8").read()]
check(not missing_phms, "pinchHoldMs missing in: %s" % missing_phms[:5])
```

- [ ] **Step 2: Run — expect FAIL.**
Run: `cd sound_algo/data_only/matrix_presets && uv run python test_global_actions.py`
Expected: `FAIL: to_sc output missing pinchHoldMs`.

- [ ] **Step 3: Emit it.** In `to_sc`, change the tail so `globalSettings` ends with a comma and `pinchHoldMs` is the last field. Replace:
```python
            "'globalSettings': ( 'transientBars': 1, "
            "'breakdownKeep': [ \\kick, \\sub ] )\n)\n"
```
with:
```python
            "'globalSettings': ( 'transientBars': 1, "
            "'breakdownKeep': [ \\kick, \\sub ] ),\n"
            "'pinchHoldMs': 300\n)\n"
```

- [ ] **Step 4: Regen (twice) + gates.**
`uv run python generate_presets.py` (twice). Then `uv run python test_global_actions.py` (`GLOBALACT-PY PASS`), `uv run python test_sections.py` (`TEST PASS`), `uv run python test_families.py` (`TEST PASS`), `/Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd` (`GLOBALACT PASS`).

- [ ] **Step 5: Commit.**
```bash
git add sound_algo/data_only/matrix_presets/generate_presets.py sound_algo/data_only/matrix_presets/test_global_actions.py sound_algo/data_only/matrix_presets/*.matrix
git commit -m "feat(presets): emit default pinch hold ms"
```

---

### Task 4: Web — 2-column menu, hold slider, progress fill

**Files:** Modify `web_realart/public/control/js/matrix-state.js`, `js/morceau-panel.js`, `index.html`, `control.css`, `web_realart/test/matrix-state.test.mjs`.

**Interfaces:**
- Consumes: `GLOBAL_SLOTS` (8), the SC `/matrix/pinchhold` + `/matrix/pinchprogress` routes.
- Produces: `matPinchHoldMs` state + persistence; a hold slider; per-slot progress fill; 2-column MG/MD layout.

- [ ] **Step 1: State test (failing).** Append to `matrix-state.test.mjs`:
```javascript
import { matPinchHoldMs, setPinchHoldMs } from "../public/control/js/matrix-state.js";
test("default pinch hold ms + setter", () => {
  assert.equal(matPinchHoldMs, 300);
  setPinchHoldMs(450);
  assert.equal(matPinchHoldMs, 450);
  setPinchHoldMs(300);
});
```

- [ ] **Step 2: Run — expect FAIL.**
Run: `cd web_realart && node --test test/matrix-state.test.mjs`
Expected: import failure.

- [ ] **Step 3: Add the state.** In `matrix-state.js`, after `matGlobalSettings`, add:
```javascript
export let matPinchHoldMs = 300;
export function setPinchHoldMs(v) { matPinchHoldMs = v; }
```
In `saveMatState`, add `phms: matPinchHoldMs` to the blob; in `loadMatState`, after the `gset` restore, add:
```javascript
      if (Number.isFinite(raw.phms)) matPinchHoldMs = raw.phms;
```

- [ ] **Step 4: 2-column layout.** In `control.css`, change `.morceau-slots` to fill column-first so slots 0-3 (MG) form the left column and 4-7 (MD) the right. Replace the `.morceau-slots` rule with:
```css
.morceau-slots { display: grid; grid-auto-flow: column; grid-template-rows: repeat(4, auto);
  grid-template-columns: 1fr 1fr; gap: 6px 12px; }
.morceau-slot { position: relative; }
.morceau-slot-fill { position: absolute; left: 0; bottom: 0; height: 2px; width: 0%;
  background: #8c8; transition: width 60ms linear; pointer-events: none; }
.morceau-slot-fill.fired { background: #cc2; height: 100%; opacity: 0.25; }
```

- [ ] **Step 5: Progress fill + hold slider in `morceau-panel.js`.**
In the slot-render loop, append a fill element to each slot label and keep a reference:
```javascript
    const fill = document.createElement("div");
    fill.className = "morceau-slot-fill";
    wrap.appendChild(fill);
    fills[slot.key] = fill;
```
(declare `const fills = [];` next to `const selects = [];`). After the slots loop, add the progress handler:
```javascript
  on("/matrix/pinchprogress", (args) => {
    const slot = Math.round(Number(args[0]));
    const prog = Number(args[1]) || 0;
    const f = fills[slot];
    if (!f) return;
    f.style.width = (prog * 100) + "%";
    f.classList.toggle("fired", prog >= 1);
  });
```
Add the hold slider into the Réglages group (next to the transient-duration slider), wired to `/matrix/pinchhold`:
```javascript
    const holdRow = document.createElement("label");
    holdRow.className = "morceau-set-row";
    const hSpan = document.createElement("span"); hSpan.textContent = "Maintien pince (ms)";
    const hInp = document.createElement("input");
    hInp.type = "range"; hInp.min = 50; hInp.max = 2000; hInp.step = 10; hInp.value = matPinchHoldMs;
    const hOut = document.createElement("output"); hOut.textContent = matPinchHoldMs;
    hInp.addEventListener("input", () => { hOut.textContent = hInp.value; });
    hInp.addEventListener("change", () => { setPinchHoldMs(+hInp.value); send("/matrix/pinchhold", +hInp.value); saveMatState(); });
    holdRow.append(hSpan, hInp, hOut);
    sHost.appendChild(holdRow);
    on("/matrix/pinchhold", (args) => {
      const v = Math.round(Number(args[0]));
      if (Number.isFinite(v)) { hInp.value = v; hOut.textContent = v; setPinchHoldMs(v); saveMatState(); }
    });
    onOpen(() => send("/matrix/pinchhold/get"));
    send("/matrix/pinchhold/get");
```
Add `matPinchHoldMs, setPinchHoldMs` to the `matrix-state.js` import.

- [ ] **Step 6: Parse + suite.**
Run: `cd web_realart && node --check public/control/js/morceau-panel.js` (no output) and `node --test test/*.test.mjs` (all green).

- [ ] **Step 7: Commit.**
```bash
git add web_realart/public/control/js/matrix-state.js web_realart/public/control/js/morceau-panel.js web_realart/public/control/index.html web_realart/public/control/control.css web_realart/test/matrix-state.test.mjs
git commit -m "feat(control): pinch hold slider, progress, 2-col menu"
```

---

### Task 5: Deploy + live smoke (macm1)

**Files:** none.

- [ ] **Step 1:** On user OK: `git push origin main`; `ssh macm1 'cd ~/Documents/Projets/AV-Live && git pull --ff-only'`. Verify the decouple on macm1 (torch present): `ssh macm1 'cd ~/Documents/Projets/AV-Live/data_only_viz && .venv/bin/python -m pytest tests/test_action_head_finger_emit.py -q'` → all green. Then FULL launcher restart (`launch_concert.sh` relaunches the pose pipeline with `PINCH_ENABLE=1`). Hard-reload the web page.
- [ ] **Step 2:** Pinch-AND-HOLD a finger → the slot cell fills 0→1 and fires at the threshold; a quick pinch fires nothing; the "Maintien pince (ms)" slider changes the required hold live; the air-piano makes no sound; the menu shows MG (left) / MD (right) columns. Report to the user.

---

## Self-review

**Spec coverage:** decouple (committed 4bccbc1) + launcher → Task 1; pinch edges → Task 1; SC hold-to-fire + progress + hold route + save/load → Task 2; generator pinchHoldMs → Task 3; web 2-col + hold slider + progress → Task 4; smoke + decouple verify → Task 5. ✓

**Placeholder scan:** complete code; hold 300/clamp 50-2000, slot math, OSC routes concrete; no TBD.

**Type consistency:** `/pose/pinch [pid, hand, finger, state]` produced by `send_pinch` (Task 1) ↔ read `state=msg[4]` in `\mat_ev_pinch` (Task 2). `~matPinchHoldMs` (Float) set by `/matrix/pinchhold` (Task 2) ↔ web `matPinchHoldMs`/`setPinchHoldMs` + slider send (Task 4) — single-value contract. `/matrix/pinchprogress [slot, prog]` emitted in `~matPinchTick`/release (Task 2) ↔ web `on("/matrix/pinchprogress")` fill (Task 4). `pinchHoldMs` save field consistent in `~matSave`/`~matLoadFile` (Task 2) ↔ generator literal (Task 3). Slot 0..7 = `hand*4+(finger-1)` everywhere. Per-voice `~matPoseFire` still on engage only.
