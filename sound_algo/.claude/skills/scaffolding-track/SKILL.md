---
name: scaffolding-track
description: Use when the user asks to "create a new track", "ajouter une track", "scaffolder une track X", or names a new track letter (A-W are taken, so X/Y/Z or beyond, OR overwriting an existing letter). Generates `tracks/<LETTER>_<slug>.scd` following the strict 23-track convention used in sound_algo: header banner, `~track !? { ~track.stop }` guard, `Routine` with timed sections, `~bpm`/`~kickFreq`/`~melodyInst`/`~melodyNotes` mutations, `TempoClock.default.tempo = ~bpm/60`, `~reload.value`, Pdef list `[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]`, section logs `[L M:SS] description`, and `.wait` between sections. Forgetting any of these breaks live performance — this skill enforces them.
---

# Scaffolding a new track

## Inputs to gather

Ask the user (or infer from context):

1. **Letter** : single uppercase letter. A-W are taken; default to next free letter (X, Y, ...).
2. **Slug** : short snake_case name (`acid_journey`, `dub_techno`, `phonk`).
3. **Sections** : list of `(timestamp, name, BPM, vibe)` tuples. Minimum 3 sections (intro, drop, outro).
4. **Total duration** : sum of section waits. Typical track = 5-10 minutes.
5. **Style** : melody instrument (\pad/\lead/\saw3/\rhodes/\koto/...), kick timbre, scale.

## Template

```supercollider
// =====================================================================
//  <LETTER>_<slug>.scd
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  PREREQUIS : engine.scd evalue (les SynthDef + helpers doivent exister).
// =====================================================================

// --- TRACK <LETTER> : "<TITLE>" <DURATION> minutes -------------------
//   0:00 <s1> -> M:SS <s2> -> M:SS <s3> -> ... -> M:SS outro
(
~track !? { ~track.stop };
~track = Routine({
    "[<LETTER> 0:00] <section 1 description>...".postln;
    ~bpm = <BPM1>;
    ~kickFreq = 42; ~kickPitchAmt = 2.0; ~kickDecay = 0.5;
    ~kickAmp = 0.5; ~hatAmp = 0.08; ~melodyAmp = 0.14;
    ~melodyInst = \<inst1>;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 1500;
    ~melodyNotes = [60,0,0,0, 0,0,0,0, 67,0,0,0, 0,0,0,0,
                    60,0,0,0, 0,0,0,0, 65,0,0,0, 0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
     \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
    <WAIT1>.wait;

    "[<LETTER> M:SS] <section 2 description>...".postln;
    ~bpm = <BPM2>;
    // ...mutations...
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    <WAIT2>.wait;

    // ... more sections ...

    "[<LETTER> END] outro".postln;
    ~masterFadeOut.(8);
}).play;
)
```

## Mandatory invariants

- `~track !? { ~track.stop }` BEFORE creating the new Routine. Without this, multiple Routines stack up.
- `~reload.value` after **every** mutation of `~xxx` parameters that feed Pdef.
- `TempoClock.default.tempo = ~bpm/60` whenever `~bpm` changes.
- One `.postln` log per section, format `"[<L> M:SS] <description>..."` -- this is parsed by tooling.
- `.wait` after each section (in seconds) -- sum should match total duration.
- Final `~masterFadeOut.(N)` (or stop Pdef explicitly) to avoid hanging Pdef.

## Variations within a section

Standard pattern for live mutations every 2-4 seconds inside a section :

```supercollider
30.do { |k|
    if (0.25.coin) { ~acidCutoff = rrand(600, 1400); ~reload.value };
    if (0.20.coin) {
        ~melodyNotes = ~genMelody.(0.55,
            [~scaleMinorPent, ~scaleDorian].choose);
        ~reload.value;
    };
    4.wait;  // 30 * 4 = 120s = 2 minutes
};
```

## After scaffolding

1. Run `validating-scd-files` skill on the new file (P:0 B:0, TLB:N OK for tracks).
2. Optionally use `registering-jump-section` skill to expose sections via `~jumpTo.(\<L>, \<slug>)`.
3. Add the track to `tests/e2e_09_tracks.scd` parse list.

## Anti-patterns to avoid

- **Hardcoded path** : never write absolute paths, use `~base`.
- **Section without log** : silent debug nightmare during live.
- **Total duration > 10 min without transition** : auditory fatigue.
- **Mutations without `~reload.value`** : Pdef stays stale, audible disconnect.
- **Reusing an A-W letter** : will overwrite an existing track.
