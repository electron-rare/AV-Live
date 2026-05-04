---
name: validating-scd-files
description: Use when editing or creating any `.scd` file in the sound_algo project. Verifies that parentheses and square brackets are balanced (the project hard-requires P:0 B:0) and, for files loaded via `.load` (00_load.scd, live/_load.scd, palette/*/index.scd, engine.scd, palette/scales.scd), that there is exactly one top-level `(...)` block (TLB:1). The CLAUDE.md mandates this check after every modification — sclang gives parse errors at runtime that are far harder to diagnose than a quick awk balance.
---

# Validating `.scd` files

## When to run

Run after every edit to a `.scd` file. Mandatory before claiming a task is done.

## Quick check (one file)

```bash
awk '
{
  for (i = 1; i <= length($0); i++) {
    c = substr($0, i, 1)
    if (c == "(") p++; else if (c == ")") p--
    if (c == "[") b++; else if (c == "]") b--
    # detect top-level "(" at column 1
    if (i == 1 && c == "(") tlb++
  }
}
END { printf "P:%d B:%d TLB:%d\n", p, b, tlb }
' path/to/file.scd
```

Acceptance :

- `P:0 B:0` for **all** `.scd` files
- `TLB:1` **only for files loaded via `.load`** (entry-point files). Multi-block files (tracks/*.scd, examples/*.scd, 01_live.scd) are IDE-only and `TLB:N` is fine there.

## Files that MUST have TLB:1

| File | Reason |
| --- | --- |
| `engine.scd` | Loaded via `00_load.scd` |
| `palette/scales.scd` | Same |
| `palette/melodies/index.scd` | Same |
| `palette/harmonics/index.scd` | Same |
| `palette/rhythm/fills.scd` | Same |
| `live/_load.scd` | Loaded by `01_live.scd` block [0] |
| Any other file referenced by `.load(...)` |

## Files where TLB:N is OK

- `tracks/*.scd` (Cmd+Entree per block during live play)
- `examples/*.scd` (tutorials)
- `01_live.scd` (live dashboard, blocks evaluated independently)
- `live/*.scd` except `_load.scd` (SETUP + examples in same file)

## Whole-project sweep

```bash
cd /Users/electron/Documents/Projets_Creatifs/sound_algo
for f in $(find . -name '*.scd' -not -path './_archive/*'); do
  awk -v f="$f" '
    { for (i=1;i<=length($0);i++) { c=substr($0,i,1)
        if (c=="(") p++; else if (c==")") p--
        if (c=="[") b++; else if (c=="]") b-- }}
    END { if (p!=0 || b!=0) printf "%s P:%d B:%d\n", f, p, b }
  ' "$f"
done
```

Output should be empty. Any line printed = file with unbalanced parens/brackets.

## What this skill does NOT check

- Semantic correctness (does the code work?)  → run `tests/run_all.sh`
- SynthDef compilation                        → `e2e_04_synthdef_compile.scd`
- Pdef behavior                               → `e2e_03_reload_guards.scd`
- Notation pseudo-method `~dict.key.()` traps → see `live/CLAUDE.md`

This skill is **purely lexical**. Pass = parser will at least try to compile.
