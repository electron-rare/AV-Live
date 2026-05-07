---
name: registering-jump-section
description: Use when the user asks to "register a section", "add a jump target", "make section X jumpable", or after `scaffolding-track` finishes. Adds `~sections[\<LETTER>][\<slug>] = { ... }` to `control/jump.scd` so `~jumpTo.(\<LETTER>, \<slug>)` works during live play. The slug must match the timestamp log line in the track Routine. Without this skill, sections written in tracks are NOT jumpable from `01_live.scd` block [8].
---

# Registering a jump section

## Why this skill exists

`control/jump.scd` is a 2225-line append-only file that mirrors every section
of every track A-W. Each section is registered as a closure :

```supercollider
~sections[\A] = (
    \minimal_kick_t5_sub_melody_pad: {
        ~bpm = 124; ~kickFreq = 42; ~melodyInst = \pad;
        ~melodyNotes = [60,0,0,0, ...];
    },
    \acid_rave_kick_t1_melody_lead_variations: {
        ~bpm = 132; ~melodyInst = \lead; ~acidCutoff = 800;
        // ...
    }
);
```

`~jumpTo.(\A, \acid_rave_kick_t1_melody_lead_variations)` then :

1. Stops `~track` and any pending Routines (`~filterSweep`, `~melodyEvolve`, ...)
2. Calls the closure (mutates `~xxx` vars)
3. Calls `~reload.value`
4. Replays the 8 standard Pdef

## Inputs to gather

1. **Track letter** : `\A` to `\W`.
2. **Section slug** : derived from the track's `.postln` log. Convert `"[A 2:00] acid rave kick t1 melody lead variations..."` to `\acid_rave_kick_t1_melody_lead_variations` (lowercase, underscores, no leading article).
3. **Mutation block** : the body of the section in the track Routine, **without** `TempoClock.default.tempo`, `~reload.value`, `Pdef.play` (the `~jumpTo` helper does those).

## Slug derivation rules

- Take the description after `[<L> M:SS] ` and before `...`.
- Lowercase everything.
- Replace spaces and punctuation with `_`.
- Strip leading articles ("the ", "le ", "la ").
- Collapse multiple underscores.

Examples :

| Log line | Slug |
| --- | --- |
| `[A 0:00] minimal -- kick T5 sub + melody PAD...` | `\minimal_kick_t5_sub_melody_pad` |
| `[E 3:30] DROP 1 -- growl dubstep + sub kick...` | `\drop_1_growl_dubstep_sub_kick` |
| `[F 2:00] uplifter 138 BPM...` | `\uplifter_138_bpm` |

## Insertion

Append to the existing `~sections[\<L>]` entry in `control/jump.scd`. If
`~sections[\<L>]` doesn't exist yet, create it (alphabetical order with
existing tracks).

```supercollider
~sections[\<L>][\<slug>] = {
    ~bpm = <N>;
    // ... mutations from the track section, sans TempoClock/Pdef/reload
};
```

## Validation

After insertion :

1. Run `validating-scd-files` skill on `control/jump.scd` (P:0 B:0, TLB:1).
2. Test in SC : `~jumpTo.(\<L>, \<slug>)` should print `[JUMP] [<L> <slug>]`
   and audibly switch the section.
3. Add a check in `tests/e2e_07_jump.scd` if the section is critical.

## Anti-patterns

- **Slug mismatch with track log** : silent jump lookup failure (just prints
  `!! [<L> <slug>] inexistante`).
- **Including `~reload.value` in the closure** : called twice = potential
  Pdef glitch.
- **Including `Pdef(...).play` in the closure** : `~jumpTo` already does it.
- **Calling `TempoClock.default.tempo` in the closure** : `~jumpTo` derives
  it from `~bpm` if you set `~bpm`.
- **Forgetting to stop a custom Routine** : add it to `~jumpTo`'s stop list
  if your section spawns its own (`~filterSweep`, `~melodyEvolve`, etc.).
