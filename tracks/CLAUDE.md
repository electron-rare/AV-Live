# tracks/ — Tracks autonomes A-W

23 tracks live, une lettre par track, ~5-10 minutes chacune.
Cmd+Entree sur le bloc `(...)` pour lancer.

## Structure type

```supercollider
(
~track !? { ~track.stop };           // stop l'ancienne Routine
~track = Routine({
    "[X 0:00] section ...".postln;
    ~bpm = 124; ~kickFreq = 42; ~melodyInst = \pad;
    ~melodyNotes = [60,0,...];
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;                    // rebuild Pdef
    [\kickSeq, \hatSeq, ...].do { |k| Pdef(k).play };
    120.wait;                         // 2 minutes

    "[X 2:00] next section ...".postln;
    ~bpm = 132; ...
    ~reload.value;
    ...
}).play;
)
```

## Conventions

- En-tete commentaire : nom + duree + sections + timestamps (0:00 -> X:XX)
- `~track.stop` AVANT chaque relance pour eviter superposition
- `~reload.value` apres chaque modification de `~xxx` -> Pdef
- Sections delimitees par `.wait` (secondes) + log `"[X M:SS] ...".postln`
- BPM via `TempoClock.default.tempo = ~bpm/60`
- Variations live via `if (0.20.coin) { ... }` dans des `.do` loops
- Nommage : `<LETTER>_<slug>.scd`, ex `A_acid_journey.scd`

## Section helpers

Chaque section devrait etre referencee dans `control/jump.scd`
via `~sections[\X][\slug] = { ... }` pour permettre `~jumpTo.(\X, \slug)`.

## Anti-patterns

- Ne pas oublier `~track !? { ~track.stop }` -> Routines empilees
- Ne pas omettre `~reload.value` apres modif `~xxx` -> Pdef stale
- Ne pas appeler `Pdef(k).play` sans avoir defini les patterns dans engine
- Ne pas hardcoder de chemins absolus (utiliser `~base`)
- Ne pas creer de tracks > 10 min sans transition (fatigue auditive)
