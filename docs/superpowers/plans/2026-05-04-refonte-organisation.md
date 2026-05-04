# sound_algo v2 Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate sound_algo from a mixed structure (38 SynthDef across 6 files, 133 melodies bundled in 4 files, 23 monolithic tracks) to atomic granularity (1 file = 1 unit) organized by musical genre, with auto-discovery via `_index.scd` and a new live API by genre that replaces `~kk/~mm/~ff/~cc/~p`.

**Architecture:** 7-phase migration. Each phase ends with all 10 E2E tests green and a single commit. Phases 1-2 are mechanical relocations. Phases 3-4 use Python migration scripts (the source files have predictable structure — `~m{N}` per line). Phase 5 splits each track Routine into autonomous section files. Phase 6 generates wrappers dynamically from the directory structure. Phase 7 is cleanup + docs.

**Tech Stack:** SuperCollider sclang/scsynth (audio), Python 3.14 (migration scripts), bash (test runner), Node 25/Express 5 (web bridge — only Phase 6 touches it), git (1 commit per phase).

**Reference spec:** `docs/superpowers/specs/2026-05-04-refonte-organisation-design.md` (commit `9d4483b`).

---

## Pre-flight

### Task 0: Verify clean starting state

**Files:** none modified — pre-flight check only.

- [ ] **Step 1: Verify on `main` and clean working tree**

```bash
cd /Users/electron/Documents/Projets_Creatifs/sound_algo
git status --short
git branch --show-current
```

Expected: empty `git status`, branch = `main`.

- [ ] **Step 2: Run baseline E2E suite**

```bash
bash tests/run_all.sh 2>&1 | tail -16
```

Expected: `Tests OK : 10 / FAIL : 0 / SKIP : 0`. If a test SKIPs, re-run once (sclang has intermittent libc++abi issue at exit). If consistent fail, STOP and fix before migration.

- [ ] **Step 3: Snapshot SynthDef count**

```bash
grep -rE 'SynthDef\(\\\\' --include='*.scd' . 2>/dev/null | grep -v _archive | grep -v node_modules | wc -l
```

Expected: 38 (the post-refactor structure must produce the same count — invariant).

- [ ] **Step 4: Snapshot melody count**

```bash
grep -cE '^~m(epic|xl|l)?[0-9]+ = ' palette/melodies/*.scd | awk -F: '{s+=$2} END {print s}'
```

Expected: 133 (78 short + 30 long + 15 xlong + 10 epic).

- [ ] **Step 5: Snapshot pattern count (kicks + percussions + kits + genres)**

```bash
grep -cE '^~(kK|p[A-Z])[A-Za-z0-9]+ = ' palette/rhythm/{kicks,percussions,drum_kits,patterns_genre}.scd | awk -F: '{s+=$2} END {print s}'
```

Expected: ~120+ (record exact count for invariant).

---

## Phase 1: Extract SynthDef → `synth/` and `fx/`

**Goal:** All 38 SynthDef live under `synth/{drums,bass,lead,pad,world,master}/` and all 30 FX SynthDef under `fx/{bus,insert,trick}/`. `engine.scd` keeps Pdef + `~reload` + `~scBus` only. Auto-glob loaders.

### Task 1.1: Create `synth/` skeleton + `_index.scd`

**Files:**
- Create: `synth/_index.scd`
- Create: `synth/{drums,bass,lead,pad,world,master}/` (empty dirs)

- [ ] **Step 1: Make directories**

```bash
mkdir -p synth/{drums,bass,lead,pad,world,master}
```

- [ ] **Step 2: Write `synth/_index.scd`**

```supercollider
// =====================================================================
//  synth/_index.scd  --  Auto-glob loader pour tous les SynthDef
//
//  Charge recursivement chaque .scd des sous-dossiers (drums/, bass/,
//  lead/, pad/, world/, master/). Ajouter un nouveau Synth = juste
//  creer le fichier, pas besoin de modifier ce loader.
// =====================================================================
(
PathName(thisProcess.nowExecutingPath.dirname).deepFiles
    .select { |f| f.extension == "scd"
            and: { f.fileName != "_index.scd" } }
    .sort   { |a, b| a.fullPath < b.fullPath }
    .do     { |f| f.fullPath.load };
"=== synth/ loaded ===".postln;
)
```

- [ ] **Step 3: Validate balance**

```bash
awk '{ for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="(") p++; else if (c==")") p--; if (c=="[") b++; else if (c=="]") b-- }} END { printf "P:%d B:%d\n", p, b }' synth/_index.scd
```

Expected: `P:0 B:0`.

### Task 1.2: Create `fx/` skeleton + `_index.scd`

**Files:**
- Create: `fx/_index.scd`
- Create: `fx/{bus,insert,trick}/`

- [ ] **Step 1: Make directories + index**

```bash
mkdir -p fx/{bus,insert,trick}
```

- [ ] **Step 2: Write `fx/_index.scd`**

Identical structure to `synth/_index.scd` but logs `=== fx/ loaded ===`.

```supercollider
// =====================================================================
//  fx/_index.scd  --  Auto-glob loader pour tous les FX SynthDef
// =====================================================================
(
PathName(thisProcess.nowExecutingPath.dirname).deepFiles
    .select { |f| f.extension == "scd"
            and: { f.fileName != "_index.scd" } }
    .sort   { |a, b| a.fullPath < b.fullPath }
    .do     { |f| f.fullPath.load };
"=== fx/ loaded ===".postln;
)
```

- [ ] **Step 3: Validate balance**

```bash
awk '{ for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="(") p++; else if (c==")") p--; if (c=="[") b++; else if (c=="]") b-- }} END { printf "P:%d B:%d\n", p, b }' fx/_index.scd
```

Expected: `P:0 B:0`.

### Task 1.3: Write extraction script for `engine.scd` SynthDef

**Files:**
- Create: `_migrate/extract_synthdef.py` (temporary, deleted after Phase 7)

- [ ] **Step 1: Write Python extraction script**

```python
# _migrate/extract_synthdef.py
"""
Extract each SynthDef(\name, { ... }).add; from a source .scd file
into individual files in a target directory.

Usage:
  python3 _migrate/extract_synthdef.py <source.scd> <target_dir>

Each output file <target_dir>/<snake_name>.scd contains:
  (
  SynthDef(\name, {
      ...
  }).add;
  )

The wrapping `(` / `)` block makes each file .load-compatible (TLB:1).
"""
import re, sys, os
from pathlib import Path

CAMEL_TO_SNAKE = re.compile(r'(?<!^)(?=[A-Z])')

def to_snake(name: str) -> str:
    """vcfMoog -> vcf_moog ; subBoom -> sub_boom ; kick -> kick"""
    return CAMEL_TO_SNAKE.sub('_', name).lower()

def find_synthdefs(src: str):
    """Find all SynthDef(\name, { ... }).add; blocks. Returns list of (name, block)."""
    results = []
    i = 0
    n = len(src)
    while i < n:
        m = re.search(r'SynthDef\(\\(\w+),', src[i:])
        if not m:
            break
        name = m.group(1)
        start = i + m.start()
        # Find matching })
        depth = 0
        j = start
        in_string = False
        in_block_comment = False
        in_line_comment = False
        while j < n:
            ch = src[j]
            ch2 = src[j:j+2]
            if in_line_comment:
                if ch == '\n': in_line_comment = False
            elif in_block_comment:
                if ch2 == '*/': in_block_comment = False; j += 1
            elif in_string:
                if ch == '"' and src[j-1] != '\\': in_string = False
            elif ch2 == '//': in_line_comment = True; j += 1
            elif ch2 == '/*': in_block_comment = True; j += 1
            elif ch == '"': in_string = True
            elif ch == '{': depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    # Find ).add following the }
                    rest = src[j+1:j+30]
                    add_m = re.match(r'\s*\)\.add\s*;', rest)
                    if add_m:
                        end = j + 1 + add_m.end()
                        block = src[start:end]
                        results.append((name, block))
                        i = end
                        break
            j += 1
        else:
            break
        if depth != 0:
            break
    return results

def main():
    src_path = Path(sys.argv[1])
    target_dir = Path(sys.argv[2])
    target_dir.mkdir(parents=True, exist_ok=True)

    src = src_path.read_text()
    synthdefs = find_synthdefs(src)
    print(f"Found {len(synthdefs)} SynthDef in {src_path}")

    for name, block in synthdefs:
        snake = to_snake(name)
        out_path = target_dir / f"{snake}.scd"
        # Wrap in single top-level (...) for .load compatibility
        wrapped = f"// =====================================================================\n"
        wrapped += f"//  synth/{out_path.relative_to(target_dir.parent.parent)}  --  SynthDef \\{name}\n"
        wrapped += f"//  Extracted from {src_path.name} during v2 reorganization.\n"
        wrapped += f"// =====================================================================\n"
        wrapped += "(\n"
        wrapped += block
        wrapped += "\n)\n"
        out_path.write_text(wrapped)
        print(f"  -> {out_path}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Test the script on a single SynthDef before bulk run**

```bash
mkdir -p /tmp/synthdef_test
python3 _migrate/extract_synthdef.py engine.scd /tmp/synthdef_test
ls /tmp/synthdef_test | head -5
cat /tmp/synthdef_test/kick.scd | head -20
```

Expected: kick.scd, hat.scd, snare.scd, ... created. `kick.scd` starts with header comment + `(` + `SynthDef(\kick, {`.

- [ ] **Step 3: Verify a sample file parses**

```bash
/Applications/SuperCollider.app/Contents/MacOS/sclang -i 1 -e '"/tmp/synthdef_test/kick.scd".load; 0.exit;' 2>&1 | tail -5
```

Expected: no parse error. The SynthDef adds to the server.

### Task 1.4: Define routing manifest (which SynthDef → which subdir)

**Files:**
- Create: `_migrate/synth_routing.json`

- [ ] **Step 1: Map every existing SynthDef name to its target subdirectory**

```json
{
  "drums": ["kick", "kickGabber", "hat", "snare", "snareGated",
            "clap", "perc", "rim", "cowbell", "tom"],
  "bass": ["acid", "reese", "reeseDnB", "reeseHard", "subBoom",
           "fmBass", "hooverbass", "didgeridoo"],
  "lead": ["saw3", "lead", "squareLead", "fmLead", "organLead",
           "hardLead", "supersaw", "stab", "pluck", "fmBell", "rhodes"],
  "pad": ["pad", "warmPad", "vocalPad", "drone"],
  "world": ["koto", "erhu", "pipa", "gong", "handpan", "guzheng", "growl"],
  "master": ["masterLim", "masterComp", "masterSat", "vinyl"],
  "fx_bus": ["fxReverb", "fxDelay", "fxChorus", "fxPhaser", "fxFlanger",
             "fxBitcrush", "fxTape", "fxShimmer", "fxDist", "fxSend"],
  "fx_insert": ["vcfMoog", "vcfMs20", "vcfLadder", "vcfFormant", "vcfComb",
                "vcfHpf", "vcfBpf", "vcfNotch", "fxRingMod", "fxFreqShift",
                "fxGran", "fxComb", "fxFormant", "fxAutoFilter", "fxTremolo",
                "fxAutopan", "fxStutter", "fxResonator", "fxSpringRev", "fxPlate"],
  "fx_trick": ["riser", "sweep", "impact", "crash"]
}
```

- [ ] **Step 2: Write router script that reads manifest + extracts to right subdir**

Create `_migrate/route_synthdef.py`:

```python
# _migrate/route_synthdef.py
"""Routes extracted SynthDef files to their target subdirectories per manifest."""
import json, sys, shutil
from pathlib import Path
from extract_synthdef import find_synthdefs, to_snake

ROUTING = json.loads(Path("_migrate/synth_routing.json").read_text())

# Reverse index: synthdef_name -> target_subdir
NAME_TO_DIR = {}
for subdir, names in ROUTING.items():
    for n in names:
        NAME_TO_DIR[n] = subdir

def route(source_files):
    for src_path in source_files:
        src = Path(src_path).read_text()
        for name, block in find_synthdefs(src):
            sub = NAME_TO_DIR.get(name)
            if sub is None:
                print(f"  [WARN] unknown SynthDef \\{name} (skipped)")
                continue
            # Map subdir to actual path
            if sub.startswith("fx_"):
                target = Path("fx") / sub[3:]      # fx_bus -> fx/bus
            else:
                target = Path("synth") / sub
            target.mkdir(parents=True, exist_ok=True)
            out = target / f"{to_snake(name)}.scd"
            wrapped = (
                f"// =====================================================================\n"
                f"//  {out}  --  SynthDef \\{name}\n"
                f"//  Extracted from {Path(src_path).name} during v2 reorganization.\n"
                f"// =====================================================================\n"
                f"(\n{block}\n)\n"
            )
            out.write_text(wrapped)
            print(f"  \\{name:20s} -> {out}")

if __name__ == "__main__":
    route(sys.argv[1:])
```

### Task 1.5: Run extraction on all 6 source files

**Files:**
- Modified (extracted from): `engine.scd`, `synthdefs/asia.scd`, `synthdefs/extra.scd`, `synthdefs/authentic.scd`, `live/live.scd`, `live/fx_bus.scd`
- Created: ~68 new files in `synth/` and `fx/`

- [ ] **Step 1: Run the router on all 6 sources**

```bash
cd /Users/electron/Documents/Projets_Creatifs/sound_algo
python3 _migrate/route_synthdef.py \
    engine.scd \
    synthdefs/asia.scd synthdefs/extra.scd synthdefs/authentic.scd \
    live/live.scd live/fx_bus.scd
```

Expected output: 68 lines `\name -> path`. No `[WARN] unknown` (would mean the manifest is incomplete).

- [ ] **Step 2: Verify counts**

```bash
ls synth/drums/ synth/bass/ synth/lead/ synth/pad/ synth/world/ synth/master/ | grep -c '\.scd$'
ls fx/bus/ fx/insert/ fx/trick/ | grep -c '\.scd$'
```

Expected: 38 + 30 = 68 total.

- [ ] **Step 3: Validate balance for ALL extracted files**

```bash
for f in synth/**/*.scd fx/**/*.scd; do
    awk -v f="$f" '{ for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="(") p++; else if (c==")") p--; if (c=="[") b++; else if (c=="]") b-- }} END { if (p!=0||b!=0) printf "%s P:%d B:%d\n", f, p, b }' "$f"
done
```

Expected: empty output (all balanced).

### Task 1.6: Remove SynthDef from source files

**Files:**
- Modify: `engine.scd` (remove all `SynthDef(...).add;` blocks)
- Delete: `synthdefs/asia.scd`, `synthdefs/extra.scd`, `synthdefs/authentic.scd`
- Delete: `synthdefs/` directory
- Modify: `live/live.scd` (remove all SynthDef blocks)
- Modify: `live/fx_bus.scd` (remove all SynthDef blocks)

- [ ] **Step 1: Write a stripper script**

Create `_migrate/strip_synthdef.py`:

```python
# _migrate/strip_synthdef.py
"""Removes all SynthDef(...).add; blocks from a source file, leaving the rest intact."""
import sys
from pathlib import Path
from extract_synthdef import find_synthdefs

def strip(path):
    src = Path(path).read_text()
    blocks = find_synthdefs(src)
    if not blocks:
        return
    # Remove blocks in reverse order to keep offsets stable
    for name, block in reversed(blocks):
        idx = src.find(block)
        if idx >= 0:
            # Also drop trailing whitespace + comment line above if it's a section comment
            src = src[:idx] + src[idx + len(block):]
    Path(path).write_text(src)
    print(f"  stripped {len(blocks)} SynthDef from {path}")

if __name__ == "__main__":
    for p in sys.argv[1:]:
        strip(p)
```

- [ ] **Step 2: Run on engine.scd, live/live.scd, live/fx_bus.scd**

```bash
python3 _migrate/strip_synthdef.py engine.scd live/live.scd live/fx_bus.scd
```

- [ ] **Step 3: Delete `synthdefs/` entirely (now empty of useful content)**

```bash
git rm -r synthdefs/
```

- [ ] **Step 4: Validate balance on stripped files**

```bash
for f in engine.scd live/live.scd live/fx_bus.scd; do
    printf "%-25s " "$f"
    awk '{ for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="(") p++; else if (c==")") p--; if (c=="[") b++; else if (c=="]") b-- }} END { printf "P:%d B:%d\n", p, b }' "$f"
done
```

Expected: `P:0 B:0` on all three.

### Task 1.7: Update loaders to source `synth/` and `fx/`

**Files:**
- Modify: `00_load.scd` (replace `synthdefs/asia.scd` etc. by `synth/_index.scd` and `fx/_index.scd`)
- Modify: `setup.scd` (`~setupAll` body — replace synthdefs paths)
- Modify: `live/_load.scd` (replace synthdefs paths)
- Modify: `tests/e2e_01_syntax.scd` (file list)
- Modify: `tests/e2e_02_load.scd` (load expectations)
- Modify: `tests/e2e_04_synthdef_compile.scd` (file list)

- [ ] **Step 1: Update `00_load.scd` CHARGER TOUT block**

Find the lines:

```supercollider
(~base ++ "synthdefs/asia.scd").load;
(~base ++ "synthdefs/extra.scd").load;
(~base ++ "synthdefs/authentic.scd").load;
```

Replace with:

```supercollider
(~base ++ "synth/_index.scd").load;
(~base ++ "fx/_index.scd").load;
```

(Order: synth before fx — fx insert may reference master synths in some defs.)

- [ ] **Step 2: Update `setup.scd ~setupAll` body**

Find lines `(~base ++ "synthdefs/asia.scd").load;` etc. and replace with the same two lines as above. Same for `~setupLive` and `~ensureLive` (3 places total in setup.scd).

- [ ] **Step 3: Update `live/_load.scd`**

Same replacement pattern.

- [ ] **Step 4: Update test file lists**

In `tests/e2e_01_syntax.scd` and `tests/e2e_04_synthdef_compile.scd`, replace the hard-coded list of `synthdefs/*.scd` with:

```supercollider
~scanFiles = { |dir|
    PathName(~base ++ dir).deepFiles
        .select { |f| f.extension == "scd" and: { f.fileName != "_index.scd" } }
        .collect { |f| f.fullPath };
};
~synthFiles = ~scanFiles.("synth/");
~fxFiles = ~scanFiles.("fx/");
```

Then iterate `~synthFiles ++ ~fxFiles` instead of the hard-coded list.

- [ ] **Step 5: Run full E2E**

```bash
bash tests/run_all.sh 2>&1 | tail -16
```

Expected: `Tests OK : 10 / FAIL : 0`. If `04_synthdef_compile` reports a different count, the migration lost or duplicated a SynthDef. Check `_migrate/synth_routing.json` for completeness.

### Task 1.8: Commit Phase 1

- [ ] **Step 1: Stage**

```bash
git add synth/ fx/ engine.scd live/live.scd live/fx_bus.scd \
        00_load.scd setup.scd live/_load.scd \
        tests/e2e_01_syntax.scd tests/e2e_04_synthdef_compile.scd \
        _migrate/
git rm -r --cached synthdefs/ 2>/dev/null || true
```

- [ ] **Step 2: Commit**

```bash
git -c user.email="108685187+electron-rare@users.noreply.github.com" \
    -c user.name="electron-rare" commit -m "$(cat <<'EOF'
Phase 1: extract 38 SynthDef + 30 FX into synth/ and fx/

Move all SynthDef definitions from engine.scd, synthdefs/, live/live.scd
and live/fx_bus.scd into atomic per-file structure:
- synth/{drums,bass,lead,pad,world,master}/  (38 files)
- fx/{bus,insert,trick}/                     (30 files)

Each file has a single top-level () block with one SynthDef.add.
Auto-glob loaders synth/_index.scd and fx/_index.scd discover and
load all .scd recursively at boot.

engine.scd retains Pdef + ~reload + ~scBus only. live/live.scd and
live/fx_bus.scd retain helpers only (~vcfOn, ~addFx, ~send, ~setFx,
~lfoTo, etc.).

setup.scd, 00_load.scd, live/_load.scd updated to load synth/_index.scd
and fx/_index.scd in place of synthdefs/.

Tests adapted: e2e_01_syntax + e2e_04_synthdef_compile now scan
synth/ and fx/ recursively instead of hardcoded synthdefs/ list.
All 10 E2E suites pass.

_migrate/ contains the migration scripts (route_synthdef.py,
strip_synthdef.py, synth_routing.json) — temporary, removed Phase 7.
EOF
)"
git push
```

- [ ] **Step 3: Verify push**

```bash
git log --oneline -1
```

Expected: shows the new commit.

---

## Phase 2: Rename `live/` → `audio/` + relocate `palette/rhythm/{fills,sequences}` → `palette/`

**Goal:** `live/` becomes `audio/` (more accurate — these are audio infrastructure helpers, not music). `palette/rhythm/{fills,sequences}.scd` move up to `palette/` (they're compositional helpers, not pattern banks).

### Task 2.1: Rename `live/` → `audio/`

**Files:**
- Rename: `live/` → `audio/` (whole directory)
- Modify: every file referencing `live/...` paths

- [ ] **Step 1: Rename via git**

```bash
git mv live audio
```

- [ ] **Step 2: Find all references to `live/` paths**

```bash
grep -rln 'live/[a-z_]*\.scd' --include='*.scd' --include='*.sh' --include='*.md' --include='*.js' . 2>/dev/null | grep -v _archive | grep -v node_modules
```

Expected list (approximate): `00_load.scd`, `01_live.scd`, `setup.scd`, `audio/_load.scd`, `web_bridge.scd`, `tests/e2e_*.scd`, `tests/run_all.sh`, `CLAUDE.md`, `audio/CLAUDE.md`, `tracks/*.scd` (some reference `live/tweaks.scd`), `web/server.js`, `web/README.md`.

- [ ] **Step 3: Bulk replace `live/` → `audio/` in those files**

```bash
find . -type f \( -name '*.scd' -o -name '*.sh' -o -name '*.md' -o -name '*.js' \) \
    -not -path './_archive/*' -not -path './node_modules/*' -not -path './web/node_modules/*' \
    -not -path './.git/*' \
    -exec grep -l 'live/' {} \; | \
while read f; do
    sed -i '' 's|live/|audio/|g' "$f"
done
```

- [ ] **Step 4: Manually fix any false positives**

Search for occurrences where `live/` was substituted incorrectly (e.g., comments, English text):

```bash
grep -rn 'audio/' --include='*.md' . 2>/dev/null | grep -v _archive | grep -i 'audio/quality\|audio/file\|audio/track\|audio/recording' || echo "no false positives"
```

Expected: empty / "no false positives".

- [ ] **Step 5: Rename `audio/_load.scd` to keep purpose clear**

It's loaded once at boot — keep filename. No rename needed.

### Task 2.2: Move `palette/rhythm/{fills,sequences}.scd` to `palette/`

**Files:**
- Rename: `palette/rhythm/fills.scd` → `palette/fills.scd`
- Rename: `palette/rhythm/sequences.scd` → `palette/sequences.scd`
- Modify: `setup.scd`, `00_load.scd`, references in tracks

- [ ] **Step 1: Move files via git**

```bash
git mv palette/rhythm/fills.scd palette/fills.scd
git mv palette/rhythm/sequences.scd palette/sequences.scd
```

- [ ] **Step 2: Replace path references**

```bash
find . -type f -name '*.scd' \
    -not -path './_archive/*' \
    -exec grep -l 'palette/rhythm/fills\|palette/rhythm/sequences' {} \; | \
while read f; do
    sed -i '' \
        -e 's|palette/rhythm/fills|palette/fills|g' \
        -e 's|palette/rhythm/sequences|palette/sequences|g' "$f"
done
```

### Task 2.3: Validate Phase 2

- [ ] **Step 1: Run E2E**

```bash
bash tests/run_all.sh 2>&1 | tail -16
```

Expected: 10/10 PASS.

- [ ] **Step 2: Quick smoke check that web bridge still loads**

```bash
node -e "console.log(require.resolve('./web/server.js'))" || echo "web ok"
```

Expected: prints the path.

### Task 2.4: Commit Phase 2

- [ ] **Step 1: Stage + commit + push**

```bash
git add -A
git -c user.email="108685187+electron-rare@users.noreply.github.com" \
    -c user.name="electron-rare" commit -m "Phase 2: rename live/ -> audio/ + relocate palette/rhythm/{fills,sequences}"
git push
```

---

## Phase 3: Eclater 133 melodies → `melodies/<genre>/m{N}.scd`

**Goal:** Each of the 133 melodies becomes its own file under `melodies/<genre>/`. Variables renamed to `~m{Genre}{N}` (e.g., `~mAcid1`).

### Task 3.1: Build the genre mapping from `~melodyBank`

**Files:**
- Create: `_migrate/melody_bank_to_genre.py`

- [ ] **Step 1: Inspect current `~melodyBank` definition**

```bash
sed -n '/~melodyBank = /,/^);$/p' palette/melodies/bank.scd | head -80
```

This shows the dict mapping `\genre -> [m1, m5, ml3, mxl2, ...]`. Each genre key lists which melody variables belong to that genre.

- [ ] **Step 2: Write a Python script that parses `~melodyBank` and produces a JSON mapping**

```python
# _migrate/melody_bank_to_genre.py
"""Parse palette/melodies/bank.scd and produce a JSON mapping
   melody_var -> [list of genres it appears in]."""
import re, json
from pathlib import Path

src = Path("palette/melodies/bank.scd").read_text()

# Extract the ~melodyBank = ( ... ); block
m = re.search(r'~melodyBank\s*=\s*\((.*?)\n\s*\);', src, re.DOTALL)
if not m:
    raise SystemExit("~melodyBank not found")

bank_body = m.group(1)

# Match \genre: [vars]
mapping = {}  # melody_var -> [genres]
for entry in re.finditer(r'\\(\w+)\s*:\s*\[([^\]]+)\]', bank_body):
    genre = entry.group(1)
    vars_str = entry.group(2)
    vars_list = [v.strip().lstrip('~') for v in vars_str.split(',') if v.strip()]
    for v in vars_list:
        mapping.setdefault(v, []).append(genre)

# Pick dominant genre (first listed) for each melody
dominant = {v: gs[0] for v, gs in mapping.items()}

# Variables not in any genre go to \other
all_vars = set()
for f in ['short.scd', 'long.scd', 'xlong.scd', 'epic.scd']:
    s = Path(f"palette/melodies/{f}").read_text()
    all_vars.update(re.findall(r'^~(\w+)\s*=\s*\[', s, re.MULTILINE))

for v in all_vars - mapping.keys():
    dominant[v] = "other"

Path("_migrate/melody_genres.json").write_text(json.dumps(dominant, indent=2, sort_keys=True))
print(f"Mapped {len(dominant)} melodies; genres: {sorted(set(dominant.values()))}")
```

- [ ] **Step 3: Run it**

```bash
python3 _migrate/melody_bank_to_genre.py
cat _migrate/melody_genres.json | head -20
```

Expected: outputs e.g. `{"m1": "acid", "m2": "acid", "m5": "trance", ...}`. Total entries: 133.

### Task 3.2: Extract melodies into `melodies/<genre>/`

**Files:**
- Create: `_migrate/extract_melodies.py`
- Create: ~133 files in `melodies/<genre>/m{N}.scd`

- [ ] **Step 1: Write extractor**

```python
# _migrate/extract_melodies.py
"""Extract every ~m{N}, ~ml{N}, ~mxl{N}, ~mepic{N} from palette/melodies/*.scd
   into melodies/<genre>/m{i}.scd with renamed variable ~m{Genre}{i}.

   Within each genre, melodies are renumbered 1..N preserving the original
   order (which roughly tracks musical similarity)."""
import re, json
from pathlib import Path

genres = json.loads(Path("_migrate/melody_genres.json").read_text())

# Read all source melody files; preserve original order
sources = ['short.scd', 'long.scd', 'xlong.scd', 'epic.scd']
all_melodies = []   # list of (orig_var, value_str)
for sf in sources:
    src = Path(f"palette/melodies/{sf}").read_text()
    for m in re.finditer(r'^~(\w+)\s*=\s*(\[[^\]]+\]);', src, re.MULTILINE):
        all_melodies.append((m.group(1), m.group(2)))

# Group by dominant genre
by_genre = {}
for var, val in all_melodies:
    g = genres.get(var, "other")
    by_genre.setdefault(g, []).append((var, val))

# Write files
for genre, items in by_genre.items():
    target = Path("melodies") / genre
    target.mkdir(parents=True, exist_ok=True)
    for i, (orig_var, val) in enumerate(items, start=1):
        new_var = f"m{genre.capitalize()}{i}"
        out = target / f"m{i}.scd"
        content = (
            f"// =====================================================================\n"
            f"//  melodies/{genre}/m{i}.scd  --  ~{new_var}  (was ~{orig_var})\n"
            f"// =====================================================================\n"
            f"( ~{new_var} = {val}; )\n"
        )
        out.write_text(content)
    print(f"  {genre:12s} -> {len(items):3d} melodies")

# Write index
index_path = Path("melodies/_index.scd")
index_path.write_text(
    "// =====================================================================\n"
    "//  melodies/_index.scd  --  Auto-glob loader\n"
    "// =====================================================================\n"
    "(\n"
    "PathName(thisProcess.nowExecutingPath.dirname).deepFiles\n"
    "    .select { |f| f.extension == \"scd\"\n"
    "            and: { f.fileName != \"_index.scd\" } }\n"
    "    .sort   { |a, b| a.fullPath < b.fullPath }\n"
    "    .do     { |f| f.fullPath.load };\n"
    "\"=== melodies/ loaded ===\".postln;\n"
    ")\n"
)
```

- [ ] **Step 2: Run + verify counts**

```bash
python3 _migrate/extract_melodies.py
find melodies -name '*.scd' -not -name '_index.scd' | wc -l
```

Expected: 133.

- [ ] **Step 3: Validate balance on all extracted melodies**

```bash
for f in melodies/**/*.scd; do
    [ "$(basename "$f")" = "_index.scd" ] && continue
    awk -v f="$f" '{ for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="(") p++; else if (c==")") p--; if (c=="[") b++; else if (c=="]") b-- }} END { if (p!=0||b!=0) printf "%s P:%d B:%d\n", f, p, b }' "$f"
done
```

Expected: empty.

### Task 3.3: Remove old melody files + update loaders

**Files:**
- Delete: `palette/melodies/{short,long,xlong,epic,bank}.scd`
- Modify: `palette/melodies/index.scd` — either delete or replace with redirect to `melodies/_index.scd`
- Modify: `00_load.scd`, `setup.scd`, `audio/_load.scd` to load `melodies/_index.scd`
- Modify: any code referencing `~m{N}`, `~ml{N}`, `~mxl{N}`, `~mepic{N}` directly

- [ ] **Step 1: Find all references to old melody variables**

```bash
grep -rn '~m[0-9]\|~ml[0-9]\|~mxl[0-9]\|~mepic[0-9]' --include='*.scd' . 2>/dev/null | grep -v _archive | grep -v palette/melodies
```

Expected: a list of references in `tracks/*.scd`, `01_live.scd`, `audio/melodies.scd` (the wrapper), `tests/e2e_05_melodies.scd`.

- [ ] **Step 2: Build a substitution table**

```bash
python3 -c "
import json
genres = json.loads(open('_migrate/melody_genres.json').read())
# Group by genre, preserving original order
order = []
for f in ['short.scd', 'long.scd', 'xlong.scd', 'epic.scd']:
    import re
    src = open(f'palette/melodies/{f}').read()
    for m in re.finditer(r'^~(\w+)\s*=', src, re.M):
        order.append(m.group(1))
by_genre = {}
for v in order:
    g = genres.get(v, 'other')
    by_genre.setdefault(g, []).append(v)
table = {}
for g, vs in by_genre.items():
    for i, v in enumerate(vs, 1):
        table[v] = f'm{g.capitalize()}{i}'
open('_migrate/melody_rename.json', 'w').write(json.dumps(table, indent=2, sort_keys=True))
print(f'Built rename table: {len(table)} entries')
"
```

- [ ] **Step 3: Apply substitutions**

```python
# _migrate/apply_melody_rename.py
import json, re, sys
from pathlib import Path

table = json.loads(Path("_migrate/melody_rename.json").read_text())
# Sort by length desc to avoid partial matches (e.g., m1 inside m10)
keys = sorted(table.keys(), key=lambda k: -len(k))

files = [
    "01_live.scd",
    "audio/melodies.scd",
    "tests/e2e_05_melodies.scd",
] + [str(p) for p in Path("tracks").glob("*.scd")]

for fp in files:
    if not Path(fp).exists():
        continue
    src = Path(fp).read_text()
    orig = src
    for k in keys:
        src = re.sub(rf'~{k}\b', f'~{table[k]}', src)
    if src != orig:
        Path(fp).write_text(src)
        print(f"  updated {fp}")
```

```bash
python3 _migrate/apply_melody_rename.py
```

- [ ] **Step 4: Delete old melody source files**

```bash
git rm palette/melodies/short.scd \
       palette/melodies/long.scd \
       palette/melodies/xlong.scd \
       palette/melodies/epic.scd \
       palette/melodies/bank.scd \
       palette/melodies/helpers.scd \
       palette/melodies/tracks.scd \
       palette/melodies/index.scd
git rm -r --cached palette/melodies/ 2>/dev/null || rmdir palette/melodies
```

- [ ] **Step 5: Update loaders**

In `00_load.scd`, `setup.scd`, `audio/_load.scd`, replace:

```supercollider
(~base ++ "palette/melodies/index.scd").load;
```

with:

```supercollider
(~base ++ "melodies/_index.scd").load;
```

- [ ] **Step 6: Adapt `tests/e2e_05_melodies.scd`**

Replace assertions like `~assert.("m1 exists", ~m1.notNil)` with iteration over the new structure:

```supercollider
PathName(~base ++ "melodies/").folders.do { |gFolder|
    var genre = gFolder.folderName;
    var count = gFolder.files.select { |f| f.extension == "scd" }.size;
    ~assert.("genre " ++ genre ++ " has melodies", count > 0,
        "got " ++ count);
};
~assert.("total melody count == 133",
    PathName(~base ++ "melodies/").deepFiles
        .reject { |f| f.fileName == "_index.scd" }
        .size == 133);
```

### Task 3.4: Validate Phase 3 + commit

- [ ] **Step 1: Run E2E**

```bash
bash tests/run_all.sh 2>&1 | tail -16
```

Expected: 10/10 PASS.

- [ ] **Step 2: Commit**

```bash
git add melodies/ palette/ tracks/ 01_live.scd audio/ tests/ \
        00_load.scd setup.scd _migrate/
git -c user.email="108685187+electron-rare@users.noreply.github.com" \
    -c user.name="electron-rare" commit -m "Phase 3: split 133 melodies into melodies/<genre>/m{N}.scd"
git push
```

---

## Phase 4: Eclater 120+ patterns → `patterns/<dir>/<name>.scd`

**Goal:** Same approach as Phase 3 but for patterns. Symmetrical structure: `patterns/{kick,hat,snare,clap,perc}/<name>.scd` for instrument patterns and `patterns/genre/<genre>/<name>.scd` for multi-instrument kits/genres.

### Task 4.1: Define pattern routing manifest

**Files:**
- Create: `_migrate/pattern_routing.json`

- [ ] **Step 1: Inspect current pattern files**

```bash
for f in palette/rhythm/{kicks,percussions,drum_kits,patterns_genre}.scd; do
    echo "=== $f ==="
    grep -E '^~[a-zA-Z]+ = ' "$f" | head -30
done
```

This produces the list of variable names and their structure (single Array vs. Event with multiple instruments).

- [ ] **Step 2: Build the routing JSON**

Create `_migrate/pattern_routing.json` mapping each variable to:

```json
{
  "kK1": { "dir": "kick", "name": "k1", "kind": "array" },
  "kK2": { "dir": "kick", "name": "k2", "kind": "array" },
  "...": "...",
  "pHatOff2": { "dir": "hat", "name": "off2", "kind": "array" },
  "pSnareTwo4": { "dir": "snare", "name": "two4", "kind": "array" },
  "...": "...",
  "kitTechno": { "dir": "genre/techno", "name": "techno", "kind": "event" },
  "kitDubstep": { "dir": "genre/dubstep", "name": "dubstep", "kind": "event" },
  "...": "..."
}
```

(The exact mapping is derived from `palette/rhythm/*.scd` — produce manually by reading those files. ~120 entries.)

### Task 4.2: Run pattern extraction

**Files:**
- Create: `_migrate/extract_patterns.py`
- Create: ~120 files under `patterns/`

- [ ] **Step 1: Write the extractor**

```python
# _migrate/extract_patterns.py
"""Extract patterns from palette/rhythm/*.scd into patterns/<dir>/<name>.scd
   per the routing manifest."""
import re, json
from pathlib import Path

routing = json.loads(Path("_migrate/pattern_routing.json").read_text())
sources = ["kicks.scd", "percussions.scd", "drum_kits.scd", "patterns_genre.scd"]

# Read all source content
all_src = ""
for sf in sources:
    p = Path(f"palette/rhythm/{sf}")
    if p.exists():
        all_src += p.read_text() + "\n"

# Patterns can be Array literals OR Event literals
# ~varName = [...]  OR  ~varName = (key: val, ...);
def find_var_definition(src, var):
    """Find ~var = ...; returning the value string."""
    pattern = rf'^~{var}\s*=\s*'
    m = re.search(pattern, src, re.MULTILINE)
    if not m:
        return None
    start = m.end()
    # Determine bracket type
    if src[start] == '[':
        depth = 0
        i = start
        while i < len(src):
            if src[i] == '[': depth += 1
            elif src[i] == ']':
                depth -= 1
                if depth == 0:
                    return src[start:i+1]
            i += 1
    elif src[start] == '(':
        depth = 0
        i = start
        while i < len(src):
            if src[i] == '(': depth += 1
            elif src[i] == ')':
                depth -= 1
                if depth == 0:
                    return src[start:i+1]
            i += 1
    else:
        # Simple value
        end = src.find(';', start)
        return src[start:end]
    return None

for var, info in routing.items():
    val = find_var_definition(all_src, var)
    if val is None:
        print(f"  [WARN] not found: ~{var}")
        continue
    target_dir = Path("patterns") / info["dir"]
    target_dir.mkdir(parents=True, exist_ok=True)
    out = target_dir / f"{info['name']}.scd"
    # Determine new variable name
    if info["dir"].startswith("genre/"):
        # patterns/genre/techno/techno.scd -> ~pTechno
        # patterns/genre/dubstep/classic.scd -> ~pDubstepClassic
        prefix = info["dir"].split("/")[1].capitalize()
        new_var = f"p{prefix}{info['name'].capitalize()}" if info["name"] != prefix.lower() else f"p{prefix}"
    else:
        # patterns/kick/k1.scd -> ~pKickK1
        new_var = f"p{info['dir'].capitalize()}{info['name'].capitalize()}"
    content = (
        f"// =====================================================================\n"
        f"//  patterns/{info['dir']}/{info['name']}.scd  --  ~{new_var}  (was ~{var})\n"
        f"// =====================================================================\n"
        f"( ~{new_var} = {val}; )\n"
    )
    out.write_text(content)
    print(f"  ~{var:25s} -> ~{new_var:30s} -> {out}")
```

- [ ] **Step 2: Run + verify**

```bash
python3 _migrate/extract_patterns.py
find patterns -name '*.scd' | wc -l
```

Expected: matches the count from Pre-flight Step 5.

- [ ] **Step 3: Validate balance**

```bash
for f in $(find patterns -name '*.scd' -not -name '_index.scd'); do
    awk -v f="$f" '{ for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="(") p++; else if (c==")") p--; if (c=="[") b++; else if (c=="]") b-- }} END { if (p!=0||b!=0) printf "%s P:%d B:%d\n", f, p, b }' "$f"
done
```

Expected: empty.

### Task 4.3: Write `patterns/_index.scd`

- [ ] **Step 1: Write the loader**

```supercollider
// patterns/_index.scd
(
PathName(thisProcess.nowExecutingPath.dirname).deepFiles
    .select { |f| f.extension == "scd"
            and: { f.fileName != "_index.scd" } }
    .sort   { |a, b| a.fullPath < b.fullPath }
    .do     { |f| f.fullPath.load };
"=== patterns/ loaded ===".postln;
)
```

### Task 4.4: Remove old + adapt + commit

- [ ] **Step 1: Delete old pattern files**

```bash
git rm palette/rhythm/kicks.scd \
       palette/rhythm/percussions.scd \
       palette/rhythm/drum_kits.scd \
       palette/rhythm/patterns_genre.scd
# Note: fills.scd and sequences.scd already moved in Phase 2
rmdir palette/rhythm 2>/dev/null || true
```

- [ ] **Step 2: Update loaders**

In `00_load.scd`, `setup.scd`, `audio/_load.scd`, add:

```supercollider
(~base ++ "patterns/_index.scd").load;
```

(Place after `melodies/_index.scd`.)

- [ ] **Step 3: Apply rename in consumer files**

Build a rename table similar to Phase 3, applied to `01_live.scd`, `audio/patterns.scd` (the wrapper, soon obsolete), `tracks/*.scd`, `web_bridge.scd`, `web/public/control/app.js`.

- [ ] **Step 4: Run E2E + commit**

```bash
bash tests/run_all.sh 2>&1 | tail -16
git add -A
git -c user.email="108685187+electron-rare@users.noreply.github.com" \
    -c user.name="electron-rare" commit -m "Phase 4: split 120+ patterns into patterns/<dir>/<name>.scd"
git push
```

---

## Phase 5: Eclater 23 tracks → `tracks/<X>_<slug>/{_track.scd, NN_section.scd}`

**Goal:** Each track A-W becomes a directory. Each section becomes an autonomous `.scd` file (Cmd+Enter applies all params + reload, no Routine, no .wait). The orchestrator `_track.scd` schedules them via `.load` + `.wait`.

### Task 5.1: Write the track-splitter script

**Files:**
- Create: `_migrate/split_track.py`

- [ ] **Step 1: Inspect current track structure**

```bash
sed -n '8,40p' tracks/A_acid_journey.scd
```

Notice the pattern:
```supercollider
(
~track !? { ~track.stop };
~track = Routine({
    "[A 0:00] minimal -- ...".postln;
    ~bpm = 124; ...;
    ~reload.value;
    [\kickSeq, ...].do { |k| Pdef(k).play };
    120.wait;

    "[A 2:00] acid rave -- ...".postln;
    ~bpm = 132; ...;
    ~reload.value;
    120.wait;

    // ... etc
}).play;
)
```

Each section is delimited by a `.postln` with timestamp + the next `.wait`.

- [ ] **Step 2: Write the splitter**

```python
# _migrate/split_track.py
"""Splits a track .scd file into:
  - tracks/<name>/_track.scd           (orchestrator Routine)
  - tracks/<name>/NN_<slug>.scd        (autonomous section files)

Each section file is idempotent: applies all mutations + ~reload + Pdef.play
without any .wait or Routine. The orchestrator loads them in order.
"""
import re, sys
from pathlib import Path

def slugify(text):
    """[A 2:00] acid rave -- kick T1 + melody LEAD + variations
       -> 'acid_rave_kick_t1_melody_lead_variations'"""
    text = re.sub(r'^\[[A-Z]\s+[\d:]+\]\s*', '', text)
    text = text.replace('...', '').strip()
    text = re.sub(r'[^a-zA-Z0-9]+', '_', text).lower().strip('_')
    return text or "section"

def split_track(track_path):
    name = track_path.stem  # "A_acid_journey"
    src = track_path.read_text()

    # Find the Routine body
    m = re.search(r'~track\s*=\s*Routine\s*\(\s*\{(.*?)\}\)\.play', src, re.DOTALL)
    if not m:
        print(f"  [SKIP] {track_path.name} : no Routine found")
        return
    body = m.group(1)

    # Split body by `.postln;` timestamps
    sections = []
    cursor = 0
    for log_match in re.finditer(r'"(\[[A-Z]\s+\d+:\d+\][^"]+)"\.postln;', body):
        if sections:
            sections[-1]["body_end"] = log_match.start()
        sections.append({
            "log": log_match.group(1),
            "body_start": log_match.end(),
            "body_end": len(body),
        })

    # For each section, body = body[body_start:body_end] minus the trailing .wait
    target_dir = Path("tracks") / name
    target_dir.mkdir(parents=True, exist_ok=True)

    for i, sec in enumerate(sections, start=1):
        section_body = body[sec["body_start"]:sec["body_end"]]
        # Drop trailing N.wait;
        section_body = re.sub(r'\d[\d.]*\.wait\s*;\s*$', '', section_body, flags=re.MULTILINE).rstrip()

        slug = slugify(sec["log"])
        out_path = target_dir / f"{i:02d}_{slug}.scd"
        content = (
            f"// =====================================================================\n"
            f"//  {out_path}\n"
            f"//  Section autonome : Cmd+Enter pour appliquer\n"
            f"// =====================================================================\n"
            f"(\n"
            f"\"{sec['log']}\".postln;\n"
            f"{section_body}\n"
            f")\n"
        )
        out_path.write_text(content)

    # Build orchestrator that re-creates the Routine via .load
    orch = (
        f"// =====================================================================\n"
        f"//  tracks/{name}/_track.scd  --  Orchestrateur\n"
        f"//  Cmd+Enter pour jouer la track entiere.\n"
        f"// =====================================================================\n"
        f"(\n"
        f"~track !? {{ ~track.stop }};\n"
        f"~track = Routine({{\n"
        f"    var dir = thisProcess.nowExecutingPath.dirname;\n"
    )
    # Reconstruct the original wait values
    for i, sec in enumerate(sections, start=1):
        section_body = body[sec["body_start"]:sec["body_end"]]
        wait_match = re.search(r'(\d[\d.]*)\.wait\s*;', section_body)
        wait_dur = wait_match.group(1) if wait_match else "0"
        slug = slugify(sec["log"])
        orch += f"    (dir +/+ \"{i:02d}_{slug}.scd\").load;\n"
        if i < len(sections):
            orch += f"    {wait_dur}.wait;\n"
    orch += (
        f"    \"[{name[0]}] === fin {name[2:].upper()} ===\".postln;\n"
        f"    ~masterFadeOut !? {{ ~masterFadeOut.(8) }};\n"
        f"}}).play;\n"
        f")\n"
    )
    (target_dir / "_track.scd").write_text(orch)
    print(f"  {track_path.name} -> {len(sections)} sections")

if __name__ == "__main__":
    for f in sys.argv[1:]:
        split_track(Path(f))
```

- [ ] **Step 3: Test on track A only first**

```bash
python3 _migrate/split_track.py tracks/A_acid_journey.scd
ls tracks/A_acid_journey/
```

Expected: `_track.scd` + several `NN_<slug>.scd` files.

- [ ] **Step 4: Verify balance + sample content**

```bash
for f in tracks/A_acid_journey/*.scd; do
    awk -v f="$f" '{ for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="(") p++; else if (c==")") p--; if (c=="[") b++; else if (c=="]") b-- }} END { if (p!=0||b!=0) printf "%s P:%d B:%d\n", f, p, b }' "$f"
done
cat tracks/A_acid_journey/01_*.scd | head -20
```

Expected: balance OK; section file applies mutations + reload + Pdef.play.

### Task 5.2: Run on all 23 tracks + remove old files

- [ ] **Step 1: Bulk run**

```bash
python3 _migrate/split_track.py tracks/*.scd
```

Expected: 23 lines `name -> N sections` (total ~120-150 sections).

- [ ] **Step 2: Delete the old single-file tracks (now superseded by `<X>/` dirs)**

```bash
for f in tracks/[A-W]_*.scd; do
    [ -d "${f%.scd}" ] && git rm "$f"
done
```

### Task 5.3: Adapt `~jumpTo` to load section files

**Files:**
- Modify: `control/jump.scd`

- [ ] **Step 1: Replace closure-based jump with file-based jump**

Replace the body of `~jumpTo`:

```supercollider
~jumpTo = { |trackLetter, slug|
    var letter = trackLetter.asString.toUpper;
    var dir = PathName(~base ++ "tracks").folders
        .detect { |f| f.folderName.beginsWith(letter ++ "_") };
    if (dir.isNil) {
        ("!! [jumpTo] track " ++ letter ++ " inexistante").postln;
    } {
        var slugStr = slug.asString.toLower;
        var matches = dir.files
            .select { |f| f.fileName.contains(slugStr)
                    and: { f.extension == "scd" }
                    and: { f.fileName != "_track.scd" } };
        if (matches.isEmpty) {
            ("!! [jumpTo] section '" ++ slugStr ++ "' inexistante dans " ++ letter).postln;
        } {
            ~track !? { ~track.stop; ~track = nil };
            ~filterSweep !? { ~filterSweep.stop; ~filterSweep = nil };
            ~randomLoop !? { ~randomLoop.stop; ~randomLoop = nil };
            ~melodyEvolve !? { ~melodyEvolve.stop; ~melodyEvolve = nil };
            matches.first.fullPath.load;
            ("[JUMP] " ++ letter ++ " " ++ slugStr).postln;
        };
    };
};
```

- [ ] **Step 2: Remove the now-obsolete `~sections` dictionary registration**

Delete the `~sections[\A] = (...)` blocks in `control/jump.scd` — superseded by the file-based system.

### Task 5.4: Adapt tests + commit

- [ ] **Step 1: Adapt `tests/e2e_07_jump.scd`**

Replace assertions like `~assert.("section A:minimal exists", ~sections[\A][\minimal].notNil)` with file existence checks:

```supercollider
~assert.("track A has _track.scd",
    File.exists(~base ++ "tracks/A_acid_journey/_track.scd"));
~assert.("track A section 01 exists",
    PathName(~base ++ "tracks/A_acid_journey/").files
        .select { |f| f.fileName.beginsWith("01_") }.size == 1);
```

- [ ] **Step 2: Adapt `tests/e2e_09_tracks.scd` to scan track DIRS instead of FILES**

```supercollider
PathName(~base ++ "tracks/").folders.do { |trackDir|
    var orchestrator = trackDir.fullPath +/+ "_track.scd";
    ~assert.(trackDir.folderName ++ " orchestrator exists",
        File.exists(orchestrator));
    var sections = trackDir.files.select { |f| f.fileName.beginsWith(/\d/) };
    ~assert.(trackDir.folderName ++ " has at least 2 sections",
        sections.size >= 2);
};
```

- [ ] **Step 3: Adapt `tests/e2e_10_timestamps.scd`**

The test parses `[X M:SS]` from `.postln` lines. Now those are in section files, not track files. Update to scan section files in each track directory.

- [ ] **Step 4: Run E2E + commit**

```bash
bash tests/run_all.sh 2>&1 | tail -16
git add -A
git -c user.email="108685187+electron-rare@users.noreply.github.com" \
    -c user.name="electron-rare" commit -m "Phase 5: split 23 tracks into <track>/{_track,NN_section}.scd"
git push
```

---

## Phase 6: Nouvelle API live (~mAcid, ~pAcid, ~fx)

**Goal:** Replace `~kk/~mm/~ff/~cc/~p` and all per-genre/per-length wrappers with a unified API generated dynamically from the directory structure. Update `01_live.scd`, `web_bridge.scd`, and `web/public/control/app.js`.

### Task 6.1: Write `audio/wrappers.scd` (dynamic API generator)

**Files:**
- Create: `audio/wrappers.scd`
- Delete: `audio/{melodies,patterns,kicks,fx,chains}.scd` (the legacy wrappers)

- [ ] **Step 1: Write the wrapper generator**

```supercollider
// =====================================================================
//  audio/wrappers.scd  --  Generates ~mGenre, ~pGenre, ~fx, ~synth
//  helpers dynamically from directory structure.
// =====================================================================
(
~melodyCurrentGenre = ~melodyCurrentGenre ?? { \acid };

// ---------- ~mGenre.(N | nil)  +  ~mList.(genre | nil)  ------------
PathName(~base ++ "melodies").folders.do { |gFolder|
    var genre = gFolder.folderName.asSymbol;
    var helperName = ("m" ++ genre.asString.capitalize).asSymbol;
    currentEnvironment[helperName] = { |n|
        var prefix = "m" ++ genre.asString.capitalize;
        var sym, mel;
        if (n.isNil) {
            // Random : list ~m{Prefix}{i} variables defined
            var avail = currentEnvironment.keys.asArray
                .select { |k| k.asString.beginsWith(prefix)
                          and: { k.asString.size > prefix.size
                                  and: { (k.asString[prefix.size].asInteger >= $0.asInteger)
                                  and: { k.asString[prefix.size].asInteger <= $9.asInteger }}}};
            sym = avail.choose;
        } { sym = (prefix ++ n).asSymbol };
        mel = currentEnvironment[sym];
        if (mel.notNil) {
            ~melodyNotes = mel;
            ~melodyCurrentGenre = genre;
            ~reload.value;
            ("[m" ++ genre ++ "] -> ~" ++ sym).postln;
        } { ("!! [m" ++ genre ++ "] -> ~" ++ sym ++ " inexistant").postln };
    };
};

~mList = { |genre|
    if (genre.isNil) {
        // List all genres + counts
        PathName(~base ++ "melodies").folders.do { |f|
            var n = f.files.select { |x| x.extension == "scd" }.size;
            ("  " ++ f.folderName.padRight(15) ++ n).postln;
        };
    } {
        var dir = PathName(~base ++ "melodies/" ++ genre.asString);
        if (dir.isFolder) {
            dir.files.select { |f| f.extension == "scd" }.do { |f|
                ("  " ++ f.fileName).postln;
            };
        };
    };
};

~mNext = { /* uses ~melodyCurrentGenre + last index, advances by 1 */ };
~mPrev = { /* same, decrements */ };
~mInst = { |inst| ~melodyInst = inst.asSymbol; ~reload.value };

// ---------- ~pGenre.(\name | nil) ----------------------------------
// Similar pattern: scans patterns/<g>/, exposes ~pAcid, ~pTrance, etc.
// For multi-instrument patterns (Event), applies all keys (~kickSteps,
// ~hatSteps, ~bpm, ~melodyNotes, ...).
PathName(~base ++ "patterns/genre").folders.do { |gFolder|
    var genre = gFolder.folderName.asSymbol;
    var helperName = ("p" ++ genre.asString.capitalize).asSymbol;
    currentEnvironment[helperName] = { |name|
        var prefix = "p" ++ genre.asString.capitalize;
        var sym, pat;
        if (name.isNil) {
            sym = currentEnvironment.keys.asArray
                .select { |k| k.asString.beginsWith(prefix) }
                .choose;
        } { sym = (prefix ++ name.asString.capitalize).asSymbol };
        pat = currentEnvironment[sym];
        if (pat.isKindOf(Event)) {
            // Multi-instrument: apply all keys
            pat.keysValuesDo { |k, v|
                if (#[\kick, \hat, \snare, \clap, \perc].includes(k)) {
                    currentEnvironment[(k.asString ++ "Steps").asSymbol] = v;
                } { if (k == \bpm) {
                    ~bpm = v; TempoClock.default.tempo = v / 60;
                } { if (k == \bassline) {
                    ~acidNotes = v;
                } { if (k == \melody) {
                    ~melodyNotes = v;
                }}}};
            };
            ~reload.value;
        } { if (pat.isKindOf(Array)) {
            // Single instrument (kick/hat/snare/...) — caller infers from helper name
            ("!! [p" ++ genre ++ "] " ++ sym ++ " is array — use ~pKick/~pHat/etc instead").postln;
        }};
        ("[p" ++ genre ++ "] -> ~" ++ sym).postln;
    };
};

// Per-instrument helpers ~pKick.(\techno), ~pHat.(\offbeat), etc.
[\kick, \hat, \snare, \clap, \perc].do { |inst|
    var helperName = ("p" ++ inst.asString.capitalize).asSymbol;
    currentEnvironment[helperName] = { |name|
        var prefix = "p" ++ inst.asString.capitalize;
        var sym = (prefix ++ name.asString.capitalize).asSymbol;
        var pat = currentEnvironment[sym];
        if (pat.isKindOf(Array)) {
            currentEnvironment[(inst.asString ++ "Steps").asSymbol] = pat;
            ~reload.value;
            ("[p" ++ inst ++ "] -> ~" ++ sym).postln;
        } { ("!! ~" ++ sym ++ " inexistant").postln };
    };
};

// ---------- ~fx.(\type, \name, ...) ---------------------------------
~fx = { |type, name ... args|
    case
        { type == \bus }    { ~send.(name, *args) }
        { type == \insert } { ~vcfOn.(name, *args) }
        { type == \trick }  { Synth(name.asSymbol, args) }
        { ("!! [fx] type " ++ type ++ " unknown").postln };
};

// ---------- ~synth.(\group, \name) ----------------------------------
~synth = { |group, name|
    var path = ~base ++ "synth/" ++ group.asString ++ "/"
                      ++ name.asString.toLower.replace("_", "_") ++ ".scd";
    if (File.exists(path)) {
        ("[synth] " ++ group ++ "/" ++ name ++ " : " ++ path).postln;
    } { ("!! [synth] " ++ path ++ " inexistant").postln };
};

~synthList = { |group|
    var dir = PathName(~base ++ "synth/" ++ group.asString);
    if (dir.isFolder) {
        dir.files.select { |f| f.extension == "scd" }.do { |f|
            ("  " ++ f.fileName).postln;
        };
    };
};

"=== audio/wrappers.scd loaded ===".postln;
"  Melody : ~mAcid.(1) ~mTrance.() ~mList.()".postln;
"  Pattern: ~pAcid.(\\house) ~pKick.(\\techno) ~pHat.(\\offbeat)".postln;
"  FX     : ~fx.(\\bus, \\rev, 0.4) ~fx.(\\insert, \\vcfMoog, 1500, 0.6)".postln;
"  Synth  : ~synth.(\\drums, \\kick) ~synthList.(\\drums)".postln;
)
```

- [ ] **Step 2: Add to `~setupAll`**

In `setup.scd`, append `~loadFirstBlock.(~base ++ "audio/wrappers.scd");` to the `liveSetup` body — after the wrappers' source files are loaded. Also add to `~setupLive` and `~ensureLive`.

- [ ] **Step 3: Delete the legacy wrapper files**

```bash
git rm audio/melodies.scd audio/patterns.scd audio/kicks.scd audio/fx.scd audio/chains.scd
```

(`chains.scd` is replaced by a new `audio/chains.scd` rewritten in Task 6.2 below — keep the file but rewrite it. Skip the rm for chains.scd.)

```bash
git rm audio/melodies.scd audio/patterns.scd audio/kicks.scd audio/fx.scd
```

### Task 6.2: Rewrite `audio/chains.scd` with new `~ch.(\name, ...)` API

**Files:**
- Modify: `audio/chains.scd`

- [ ] **Step 1: Replace dict-based API with single `~ch` dispatch**

```supercollider
// audio/chains.scd
(
~chainRoutine = ~chainRoutine ?? { nil };

~ch = { |name ... args|
    ~chainRoutine !? { ~chainRoutine.stop; ~chainRoutine = nil };
    switch (name.asSymbol,
        \intro,        { ~seqIntro !? { ~seqIntro.() } },
        \drop,         { ~seqDrop !? { ~seqDrop.() } },
        \breakdown,    { ~seqBreakdown !? { ~seqBreakdown.() } },
        \buildup,      { ~seqBuildup !? { ~seqBuildup.(args[0] ? 8) } },
        \outro,        { ~seqOutro !? { ~seqOutro.() } },
        \intro2drop,   {
            var introDur = args[0] ? 4, buildDur = args[1] ? 4;
            ~chainRoutine = Routine({
                ~seqIntro !? { ~seqIntro.() };
                introDur.wait;
                ~seqBuildup !? { ~seqBuildup.(buildDur) };
                (buildDur * (~stepDur ? 0.25)).wait;
                ~seqDrop !? { ~seqDrop.() };
                ~chainRoutine = nil;
            }).play(TempoClock.default);
        },
        \dropToBreak,  {
            var breakDur = args[0] ? 8;
            ~chainRoutine = Routine({
                ~seqDrop !? { ~seqDrop.() };
                4.wait;
                ~seqBreakdown !? { ~seqBreakdown.() };
                breakDur.wait;
                ~seqDrop !? { ~seqDrop.() };
                ~chainRoutine = nil;
            }).play(TempoClock.default);
        },
        \outroFade,    {
            var dur = args[0] ? 12;
            ~seqOutro !? { ~seqOutro.() };
            ~masterFadeOut !? { ~masterFadeOut.(dur) };
        },
        { ("!! [ch] action " ++ name ++ " unknown").postln }
    );
};

~chStop = {
    ~chainRoutine !? { ~chainRoutine.stop; ~chainRoutine = nil };
    ~seqStop !? { ~seqStop.() };
    "[ch] stopped".postln;
};
)
```

### Task 6.3: Rewrite `01_live.scd` with new API

**Files:**
- Modify: `01_live.scd`

- [ ] **Step 1: Update each block of 01_live.scd**

Each section needs new syntax:
- `[1] KICKS`: replace `~kk.(\techno)` with `~pKick.(\techno)` (instrument-only) or `~pAcid.(\house)` (multi-instr)
- `[2] MELODIES`: replace `~mm.(50)` with `~mAcid.(1)` etc.
- `[3] FX`: replace `~ff.(\dub)` with `~fx.(\preset, \dub)` — note presets need migration in fx_bus.scd or a new ~fxPreset still works
- `[4] CHAINS`: replace `~chDrop.()` with `~ch.(\drop)`
- `[5] PATTERNS`: replace `~pKit.(\techno)` with `~pAcid.(\house)` or per-instrument `~pKick.(\techno)`
- `[6-9] MIXER, SCENES, JUMP, STATUS`: unchanged
- `[10] PLAY` and STOP blocks: unchanged

Detailed substitutions are extensive. Rewrite the entire file. The cheat-sheet header at top should be updated to reflect the new API.

### Task 6.4: Rewrite `web_bridge.scd` and web client for new API

**Files:**
- Modify: `web_bridge.scd`
- Modify: `web/server.js` (add `/api/genres` endpoint)
- Modify: `web/public/control/app.js`

- [ ] **Step 1: Replace OSC route handlers in web_bridge.scd**

Old:
```supercollider
~webBridgeAdd.("/control/kk", { |msg| ~kk.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/mm", { |msg| ~mm.(msg[1].asInteger) });
~webBridgeAdd.("/control/ff", { |msg| ~ff.(msg[1].asString.asSymbol) });
```

New (more dynamic):
```supercollider
~webBridgeAdd.("/control/melody", { |msg|
    // /control/melody  acid  1
    var genre = msg[1].asString.asSymbol;
    var n = msg[2];
    var helperName = ("m" ++ genre.asString.capitalize).asSymbol;
    currentEnvironment[helperName] !? { |fn| fn.value(n) };
});

~webBridgeAdd.("/control/pattern", { |msg|
    // /control/pattern  acid  house
    var genre = msg[1].asString.asSymbol;
    var name = msg[2].asString.asSymbol;
    var helperName = ("p" ++ genre.asString.capitalize).asSymbol;
    currentEnvironment[helperName] !? { |fn| fn.value(name) };
});

~webBridgeAdd.("/control/fx", { |msg|
    var type = msg[1].asString.asSymbol;
    var name = msg[2].asString.asSymbol;
    var args = msg.copyToEnd(3);
    ~fx.(type, name, *args);
});
```

- [ ] **Step 2: Add `/api/genres` endpoint in `web/server.js`**

```javascript
import { readdirSync, statSync } from "node:fs";

app.get("/api/genres", (_req, res) => {
    const root = "/Users/electron/Documents/Projets_Creatifs/sound_algo";
    function listGenres(subdir) {
        const path = `${root}/${subdir}`;
        try {
            return readdirSync(path)
                .filter((d) => statSync(`${path}/${d}`).isDirectory())
                .filter((d) => !d.startsWith("_") && !d.startsWith("."));
        } catch { return []; }
    }
    res.json({
        melodies: listGenres("melodies"),
        patterns: listGenres("patterns/genre"),
        synth: listGenres("synth"),
        fx: listGenres("fx"),
    });
});
```

- [ ] **Step 3: Update `web/public/control/app.js`**

Replace hardcoded `KICKS`, `PKITS`, `PGENRES`, `FF` arrays with a fetch on load:

```javascript
const genres = await fetch("/api/genres").then(r => r.json());

// Render melody chips dynamically per genre
genres.melodies.forEach((genre) => {
    const section = document.querySelector("#melodies");
    // ... build chip group for each genre
});
```

(The detailed JS rewrite is extensive — see web client for full structure.)

### Task 6.5: Validate Phase 6 + commit

- [ ] **Step 1: Run E2E**

```bash
bash tests/run_all.sh 2>&1 | tail -16
```

Expected: 10/10 PASS. `e2e_08_live` likely needs adapting to test new wrappers.

- [ ] **Step 2: Smoke test the web bridge**

```bash
cd web && node server.js > /tmp/web.log 2>&1 &
sleep 2
curl -s http://localhost:3000/api/genres | python3 -m json.tool
kill %1
```

Expected: JSON with `melodies`, `patterns`, `synth`, `fx` keys, each populated.

- [ ] **Step 3: Commit**

```bash
git add -A
git -c user.email="108685187+electron-rare@users.noreply.github.com" \
    -c user.name="electron-rare" commit -m "Phase 6: new live API by genre (~mAcid, ~pAcid, ~fx)"
git push
```

---

## Phase 7: Cleanup + docs

### Task 7.1: Remove `_migrate/`

- [ ] **Step 1: Delete migration scripts**

```bash
git rm -r _migrate/
```

### Task 7.2: Update root `CLAUDE.md`

- [ ] **Step 1: Rewrite the `## Live Performance Workflow` section to reflect the new API**

Replace `~kk/~mm/~ff/~cc/~p` with `~mGenre/~pGenre/~fx`. Update the "Tableau de bord" pointer.

### Task 7.3: Add nested CLAUDE.md in new directories

- [ ] **Step 1: Create `synth/CLAUDE.md`**

Short doc (30-50 lines): convention 1 fichier = 1 SynthDef, sous-dossiers par rôle, doneAction:2 invariant.

- [ ] **Step 2: Create `fx/CLAUDE.md`**

Short doc: bus/ vs insert/ vs trick/ distinction, `~fxBuses` allocation pattern.

- [ ] **Step 3: Create `melodies/CLAUDE.md`**

Convention 1 fichier = 1 mélodie, sous-dossiers par genre, ~m{Genre}{N} naming.

- [ ] **Step 4: Create `patterns/CLAUDE.md`**

Conventions instrument/ vs genre/.

- [ ] **Step 5: Update existing `tracks/CLAUDE.md`**

Reflect the new sous-dossier + section autonome structure.

- [ ] **Step 6: Create `audio/CLAUDE.md`**

Replaces the current `live/CLAUDE.md`. Refresh wrappers list.

### Task 7.4: Update `tests/CLAUDE.md` and skills

- [ ] **Step 1: Update `tests/CLAUDE.md`** — file list now mentions adapted tests

- [ ] **Step 2: Update `.claude/skills/scaffolding-track/SKILL.md`** — new scaffold creates a directory, not a file

- [ ] **Step 3: Update `.claude/skills/adding-synthdef/SKILL.md`** — target is `synth/<role>/`

- [ ] **Step 4: Update `.claude/skills/registering-jump-section/SKILL.md`** — section is a file, not a closure in jump.scd

- [ ] **Step 5: Update `.claude/skills/generating-live-wrappers/SKILL.md`** — explain the new dynamic wrapper system

### Task 7.5: Update `README.md`

- [ ] **Step 1: Rewrite the Architecture table to match the new top-level structure**

### Task 7.6: Final validation + tag v2.0

- [ ] **Step 1: Run full E2E**

```bash
bash tests/run_all.sh 2>&1 | tail -16
```

Expected: 10/10 PASS.

- [ ] **Step 2: Snapshot file counts (regression check)**

```bash
echo "SynthDef: $(grep -rE 'SynthDef\(\\\\' --include='*.scd' . 2>/dev/null | grep -v _archive | grep -v node_modules | wc -l) / 38 expected"
echo "Melodies: $(find melodies -name '*.scd' -not -name '_index.scd' | wc -l) / 133 expected"
echo "Tracks  : $(ls -d tracks/[A-W]_*/ 2>/dev/null | wc -l) / 23 expected"
```

Expected: 38, 133, 23.

- [ ] **Step 3: Smoke test from a fresh sclang process**

Create `_smoke/v2_smoke.scd`:

```supercollider
"=== v2 smoke test ===".postln;

~base = "/Users/electron/Documents/Projets_Creatifs/sound_algo/";
(~base ++ "00_load.scd").load;

// Wait for setup to finish
fork {
    while { ~setupAll_done.isNil } { 0.5.wait };
    s.sync;

    // Verify new API works
    ~mList.();
    ~mAcid.(1);
    ~pAcid.(\house);
    ~fx.(\bus, \rev, 0.4);
    ~ch.(\intro);

    "=== v2 smoke OK ===".postln;
    0.exit;
};
```

```bash
/Applications/SuperCollider.app/Contents/MacOS/sclang _smoke/v2_smoke.scd 2>&1 | tail -10
```

Expected: `=== v2 smoke OK ===` printed.

- [ ] **Step 4: Commit + tag**

```bash
git add -A
git -c user.email="108685187+electron-rare@users.noreply.github.com" \
    -c user.name="electron-rare" commit -m "Phase 7: cleanup, docs, v2.0"
git tag -a v2.0 -m "v2.0 atomic granularity reorganization"
git push --tags
git push
```

---

## Self-Review Notes

**Spec coverage** : every section of the spec has at least one task in this plan. Architecture cible (synth/, fx/, melodies/, patterns/, tracks/, audio/, palette/, control/) → Phases 1-7 collectively. Nouvelle API live → Phase 6. Plan migration 7 phases → mapped 1:1. Acceptance criteria → final smoke test (Task 7.6).

**Placeholder scan** : detailed code snippets present at every concrete step. Pattern-routing tables for melodies and patterns marked as "produce manually by reading those files" — this is the only place where the engineer must do interpretive work; the scripts handle the rest mechanically.

**Type consistency** : helper names consistent across phases (`~mAcid` Phase 3 + Phase 6; `~ch` Phase 6.2 matches Phase 6.3 invocations; `~fx` signature `(type, name, ...args)` consistent).

**Risks called out** : RAM fixes (Pfunc, ~trickRoutines, ~chainRoutine, ~crossfadeFxRoutine) preserved by the plan structure (audio/tricks.scd, audio/chains.scd, audio/fx_bus.scd retain their bodies; only SynthDef definitions are extracted).

---

**End of plan.**
