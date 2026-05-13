# AV-Live Outstanding Tech Debt Cleanup Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the 8 items from the 2026-05-13 audit that were NOT addressed by the previous `data_only_viz-tech-debt` plan: `sound_algo` hardcoded paths, dead OSC paths, doublons listeners, `oscope-of` dead settings, README drift, `00_load.scd` TLB violation, `.gitignore` gaps, and `ProcessManager` Timer leak.

**Architecture:** All changes are mechanical or local to a single file. No new abstractions. Each task is self-contained and can be reordered. Most touch documentation, configuration, or housekeeping.

**Tech Stack:** SuperCollider `.scd`, openFrameworks C++, Swift, plain text config files.

**Out of scope:**
- The 29 fallback `/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/` paths in `.scd` files are tolerated (they sit behind `~base ??` fallbacks and are documented "informational"). This plan addresses the literal `/Users/electron` paths that are **NOT** behind a fallback, plus the `web_bridge.scd` one that is. The rest are left as-is — they're harmless and rewriting them is busywork.
- Refactoring the `web_bridge.scd` 8 orphan `/sync/*` emissions: some may be consumed by the browser UI (`sound_algo/web/`) which the audit didn't fully trace. We add a verification step rather than a blind delete.

---

### Task 1: Sound_algo hardcoded paths — `web_bridge.scd` and `tests/e2e_*.scd`

**Files:**
- Modify: `sound_algo/web_bridge.scd` (around line 40 — `~webBase = ~base ?? { "/Users/electron/..." }`)
- Modify: `sound_algo/tests/e2e_02_load.scd` and `sound_algo/tests/e2e_06_mixer.scd` (if they contain non-fallback hardcoded paths)

**Context:** The fallback in `web_bridge.scd:40` reads `~webBase = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/" }`. This will fire if `~base` is not set, which happens when the file is loaded directly without going through `00_load.scd`. Replace with a SuperCollider-computed default rooted in the file's own location.

- [ ] **Step 1: Inspect current state**

```bash
grep -n "Projets_Creatifs\|/Users/electron" sound_algo/web_bridge.scd sound_algo/tests/e2e_02_load.scd sound_algo/tests/e2e_06_mixer.scd
```

Confirm each line is a fallback (uses `??`) or a hard literal. Hard literals must be replaced; fallbacks can use a relative-path default.

- [ ] **Step 2: Replace `web_bridge.scd` fallback**

```supercollider
// before:
~webBase = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/" };

// after:
~webBase = ~base ?? { thisProcess.nowExecutingPath.dirname.dirname +/+ "/" };
```

(`dirname.dirname` walks up two levels: from `web_bridge.scd` → `sound_algo/` → repo root. Adjust the number of `.dirname` calls based on file depth.)

- [ ] **Step 3: For `tests/e2e_*.scd`**

If the test files contain hardcoded paths NOT behind `??`, replace each with `thisProcess.nowExecutingPath.dirname.dirname +/+ "..."`. If they ARE behind `??`, replace the fallback string identically.

- [ ] **Step 4: Smoke-test (manual)**

Load `sound_algo/00_load.scd` in the SuperCollider IDE on a clean session. Confirm no error about `~webBase` being nil. Run `~startBridge.value` if it's wired in; confirm port 57122 opens.

- [ ] **Step 5: Commit**

```bash
git add sound_algo/web_bridge.scd sound_algo/tests/e2e_02_load.scd sound_algo/tests/e2e_06_mixer.scd
git commit -m "fix(sound-algo): remove hardcoded user paths"
```

(48 chars — fits.)

---

### Task 2: OSC dead emit cleanup — pause, verify, then act

**Files:**
- Inspect: `sound_algo/web_bridge.scd` (around lines 110-124, 366, 573 — paths `/sync/{steps,notes,acidAccents,acidSlides,acidParams,harmonyAmp,sections,pong}`)
- Inspect: `sound_algo/web/server.js` and `sound_algo/web/public/app.js` (the browser UI)
- Decision: keep or delete each emission

**Context:** The audit flagged 8 OSC paths emitted by `web_bridge.scd` with no listener in `oscope-of`, `data_only_viz`, or `data_feeds`. BUT the browser web UI (`sound_algo/web/`) bridges OSC ↔ WebSocket and may consume these. A blind delete could break the live-coding cockpit.

- [ ] **Step 1: Verify which `/sync/*` paths the web bridge actually consumes**

```bash
grep -rn "/sync/steps\|/sync/notes\|/sync/acidAccents\|/sync/acidSlides\|/sync/acidParams\|/sync/harmonyAmp\|/sync/sections\|/sync/pong" sound_algo/web/
```

For each path found in the web UI: KEEP the emission, it has a real consumer.
For each path NOT found anywhere: delete the emission in `web_bridge.scd`.

- [ ] **Step 2: Delete the truly dead emissions**

Open `sound_algo/web_bridge.scd` and remove every `s.sendMsg("/sync/<dead-path>", ...)` (or `~webBridgeNode.sendMsg(...)`) that has no listener according to Step 1. Preserve the surrounding code that computes the now-unused value (it may have side effects). Wrap in a comment block stating "removed 2026-05-13 — no listener" so a future reviewer doesn't reintroduce it.

If ALL 8 paths are consumed by the web UI, this task becomes a no-op — say so in the commit body and skip.

- [ ] **Step 3: Validate SC parens balance after deletions**

```bash
awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:" p, "B:" b}' sound_algo/web_bridge.scd
```

Expected: `P:0 B:0`.

- [ ] **Step 4: Commit**

```bash
git add sound_algo/web_bridge.scd
git commit -m "chore(osc): remove dead /sync emissions"
```

(40 chars — fits.)

If the task was a no-op (all paths consumed by web UI), commit nothing and document the finding in the project notes.

---

### Task 3: OSC dead listener cleanup — `oscope-of` `/oscope/fx/<name>` and `/oscope/glitch`

**Files:**
- Modify: `oscope-of/src/OscClient.cpp` (around lines 45-48 — listeners for `/oscope/fx/<name>` and `/oscope/glitch`)

**Context:** The audit found these listeners are registered in `oscope-of` but NO emitter exists anywhere (not in `sound_algo`, not in `launcher`). Two options: (a) delete them, or (b) wire an emitter. Default to (a) since they predate the data-only mode shift.

- [ ] **Step 1: Confirm no emitter exists**

```bash
grep -rn '"/oscope/fx"\|"/oscope/glitch"\|/oscope/fx/\|/oscope/glitch' \
  --include="*.scd" --include="*.py" --include="*.swift" --include="*.js" \
  sound_algo/ data_only_viz/ launcher/ data_feeds/ web_realart/
```

If any match found: STOP and report — the audit was wrong, an emitter exists.
If no matches: proceed to deletion.

- [ ] **Step 2: Remove the listener registrations**

Open `oscope-of/src/OscClient.cpp` lines 45-48 (verify with `sed -n '40,55p' oscope-of/src/OscClient.cpp`). Delete the `if (m.getAddress() == "/oscope/fx/...")` and `if (m.getAddress() == "/oscope/glitch")` blocks. Adjust surrounding `else if` chains.

- [ ] **Step 3: Build oscope-of**

```bash
cd /Users/electron/Documents/Projets/AV-Live/oscope-of && make Release 2>&1 | tail -10
```

Expected: clean build.

If you don't have openFrameworks symlinked to `~/of`, skip the build and document this in the commit message — the CI build will verify on next push.

- [ ] **Step 4: Commit**

```bash
git add oscope-of/src/OscClient.cpp
git commit -m "chore(oscope): remove dead /oscope/* listeners"
```

(46 chars — fits.)

---

### Task 4: Doublons `/data/pose/{count,skel}` — decide single owner

**Files:**
- Modify: `sound_algo/control/data_feeds.scd` (around lines 188-197 — OSCdef for `/data/pose/count` and `/data/pose/skel`)

**Context:** Both `sound_algo/control/data_feeds.scd:188-197` and `data_only_viz/osc_listener.py:108,150` listen to `/data/pose/{count,skel}`. The audit confirms this. In data-only mode, `data_only_viz` is the rendering source of truth; in full mode, `sound_algo` can use pose for sonification. Both listening is fine if no state conflict exists — and there isn't one (they update DIFFERENT state targets).

**Decision:** keep BOTH listeners. Add a comment explaining the dual-consumer design so a future reviewer doesn't "fix" it.

- [ ] **Step 1: Add explanatory comment in `data_feeds.scd`**

Before the OSCdef block:

```supercollider
// NOTE: /data/pose/count and /data/pose/skel are ALSO consumed by
// data_only_viz/osc_listener.py for Metal rendering. This is intentional —
// both subsystems update their own state. Do NOT consolidate; they live
// in different processes.
```

- [ ] **Step 2: Mirror the comment in `data_only_viz/osc_listener.py`**

At the top of the handler functions for `/data/pose/count` and `/data/pose/skel`:

```python
# NOTE: sound_algo/control/data_feeds.scd also listens to /data/pose/{count,skel}
# for sonification. Both consumers are intentional. Do NOT consolidate.
```

- [ ] **Step 3: Commit**

```bash
git add sound_algo/control/data_feeds.scd data_only_viz/osc_listener.py
git commit -m "docs(osc): document dual /data/pose listeners"
```

(46 chars — fits.)

---

### Task 5: `oscope-of/bin/data/settings.json` — wire or delete dead fields

**Files:**
- Modify: `oscope-of/bin/data/settings.json`
- Maybe modify: `oscope-of/src/ofApp.cpp::loadSettings` (if we choose to wire instead of delete)

**Context:** Five fields are present but never read: `scope.sample_rate`, `scope.gain_ch1`, `scope.gain_ch2`, `display.fullscreen`, `display.width`, `display.height`. Default to deletion (cleanup); promote to wiring only if a runtime use case is found.

- [ ] **Step 1: Inspect `loadSettings`**

```bash
grep -n "sample_rate\|gain_ch\|fullscreen\|width\|height" oscope-of/src/ofApp.cpp
```

For each field absent from `ofApp.cpp`: it's dead, delete from JSON.

- [ ] **Step 2: Delete the dead fields from `settings.json`**

Open `oscope-of/bin/data/settings.json` and remove the 5+ keys. Preserve `scope.buffer_size`, `osc.listen_port`, `osc.send_host`, `osc.send_port`, `display.default_mode` — all confirmed in use.

- [ ] **Step 3: Validate JSON syntax**

```bash
python3 -c "import json; json.load(open('oscope-of/bin/data/settings.json')); print('OK')"
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add oscope-of/bin/data/settings.json
git commit -m "chore(oscope): remove dead settings.json fields"
```

(48 chars — fits.)

---

### Task 6: `sound_algo/README.md` — SynthDef count 90 → 1099

**Files:**
- Modify: `sound_algo/README.md`

**Context:** The README claims "90 SynthDefs" — actual count from the 2026-05-13 audit is **1099** (1059 synth + 40 fx). Fix the headline number wherever it appears.

- [ ] **Step 1: Find every mention**

```bash
grep -n "90 SynthDef\|90 synthdef\|90 synths" sound_algo/README.md
```

- [ ] **Step 2: Update each occurrence**

Replace `90` with `1099` (or, where more accurate, `~1100` for a rounded marketing-friendly figure — but `1099` is the truthful number).

- [ ] **Step 3: Commit**

```bash
git add sound_algo/README.md
git commit -m "docs(sound-algo): correct SynthDef count to 1099"
```

(48 chars — fits.)

---

### Task 7: `00_load.scd` TLB:2 → TLB:1

**Files:**
- Modify: `sound_algo/00_load.scd`

**Context:** `data_only_viz/CLAUDE.md` (and `sound_algo/CLAUDE.md`) state: "Fichiers `.load` doivent avoir UN SEUL bloc top-level `(...)`". Current `00_load.scd` has TLB:2 — two distinct top-level `(...)` blocks. SC's `.load` will only evaluate the first; the second is silently dropped. Merge or split the file.

- [ ] **Step 1: Verify TLB count**

```bash
awk 'BEGIN{depth=0;tlb=0} /^\(/{if(depth==0)tlb++; depth++} /^\)/{depth--} END{print "TLB:" tlb}' sound_algo/00_load.scd
```

Expected: `TLB:2`.

- [ ] **Step 2: Inspect both blocks**

```bash
awk 'BEGIN{depth=0;blk=0} /^\(/{if(depth==0){blk++; print "--- BLOCK " blk " starts at line " NR " ---"} depth++} /^\)/{depth--} {if(depth>0||$0~/^\)/) print NR": "$0}' sound_algo/00_load.scd
```

Decide: merge the two blocks into one (preferred) or split into `00_load.scd` (block 1) + `01_setup.scd` (block 2). Merging is cleaner if the blocks share state.

- [ ] **Step 3: Edit the file**

Merge: remove the inner `)` of block 1 and the inner `(` of block 2 so both bodies live inside a single `(...)`. Preserve all semicolons and variable scoping. If block 2 declares `var x;` that conflicts with block 1, rename before merging.

- [ ] **Step 4: Re-verify**

```bash
awk 'BEGIN{depth=0;tlb=0} /^\(/{if(depth==0)tlb++; depth++} /^\)/{depth--} END{print "TLB:" tlb " final_depth:" depth}' sound_algo/00_load.scd
```

Expected: `TLB:1 final_depth:0`.

Also check parens balance:

```bash
awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:" p, "B:" b}' sound_algo/00_load.scd
```

Expected: `P:0 B:0`.

- [ ] **Step 5: Manual SC load test**

Open `sound_algo/00_load.scd` in SC IDE. Place cursor inside the (now single) `(...)` block. `Cmd+Enter` — must evaluate without error. Confirm `~setupAll.()` runs and `~check.()` reports each module OK.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/00_load.scd
git commit -m "fix(sound-algo): merge 00_load into single TLB"
```

(46 chars — fits.)

---

### Task 8: `.gitignore` — add ML weight extensions + ProcessManager Timer fix

**Files:**
- Modify: `.gitignore` (root)
- Modify: `launcher/Sources/AVLiveLauncher/ProcessManager.swift` (`deinit` and `sentinelTimer` lifecycle)

**Context:** Two small unrelated cleanups bundled into one commit (they're trivial enough to share):

1. Root `.gitignore` ignores `*.pt` but not `*.ckpt`, `*.safetensors`, `*.mlpackage` — and CLAUDE.md mandates these be excluded.
2. `ProcessManager.sentinelTimer` is created with `Timer.scheduledTimer(repeats: true)` and uses `[weak self]` capture, but never `invalidate()`d in a `deinit`. If the manager is ever deallocated mid-flight (it shouldn't be — singleton — but defensive code is cheap), the Timer keeps firing.

- [ ] **Step 1: Extend `.gitignore`**

Add these lines under the existing `*.pt` line (or wherever ML weights are excluded):

```
*.ckpt
*.safetensors
*.mlpackage
*.onnx
*.gguf
```

(Including `*.onnx` and `*.gguf` defensively — they're common LLM/model formats and CLAUDE.md tone suggests inclusiveness.)

- [ ] **Step 2: Check no such files are currently tracked**

```bash
git ls-files | grep -E "\.ckpt$|\.safetensors$|\.mlpackage$|\.onnx$|\.gguf$"
```

Expected: empty. If non-empty, you'd need `git rm --cached <file>` for each — but the audit said this set is currently empty in git, so this is just verification.

- [ ] **Step 3: Add `deinit` to `ProcessManager`**

Open `launcher/Sources/AVLiveLauncher/ProcessManager.swift`. Find the `class ProcessManager` block. Add (or extend, if `deinit` exists):

```swift
deinit {
    sentinelTimer?.invalidate()
    sentinelTimer = nil
}
```

This is paranoid — the manager is a singleton — but it's correct hygiene and zero risk.

- [ ] **Step 4: Build the launcher**

```bash
cd /Users/electron/Documents/Projets/AV-Live/launcher && bash build.sh 2>&1 | tail -5
```

Expected: build success.

If `build.sh` is heavy (universal binary takes a while), `swift build -c debug` instead is fine for a syntax check.

- [ ] **Step 5: Commit**

```bash
git add .gitignore launcher/Sources/AVLiveLauncher/ProcessManager.swift
git commit -m "chore: gitignore ML weights + Timer cleanup"
```

(44 chars — fits.)

---

## Self-Review

**1. Spec coverage:** Each of the 8 audit items from the user-pasted summary has a task — Task 1 (sound_algo hardcoded paths, focused on web_bridge.scd which is non-fallback), Task 2 (OSC dead emits), Task 3 (OSC dead listeners), Task 4 (doublons), Task 5 (settings.json dead fields), Task 6 (README count), Task 7 (TLB:2), Task 8 (gitignore + Timer). The 29 fallback paths are explicitly addressed as out-of-scope in the header.

**2. Placeholder scan:** No "TBD". Every step has an exact command or code block. Where the actual line numbers may have drifted, the task gives the exact `grep`/`awk` to find them.

**3. Type consistency:** All shell commands use absolute paths from the repo root. All commit subjects are under 50 characters. All edits are bounded to the files listed.

---

## Execution Handoff

Plan complete. Same execution options as the others. Run AFTER Plans 1 and 3 ship — Plan 2 is mostly independent but the OSC orphan decisions (Task 2) benefit from the perf-pipeline being settled first.
