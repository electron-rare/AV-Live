# tracks/ — Albums A-W (15 tracks par lettre)

23 albums live, une lettre par album, 15 tracks par album. Chaque
track est autonome, 4-8 minutes : Cmd+Entree sur le bloc `(...)` pour
la lancer.

## Structure album

```text
tracks/
  <L>_<slug>/             ex: A_acid_journey/
    _album.scd            orchestrateur (~playAlbum.(\A) / ~playTrack.(\A, n))
    <L>01_<sub_slug>.scd  ex: A01_acid_journey.scd  (track 1)
    <L>02_<sub_slug>.scd  ex: A02_minimal_acid.scd  (track 2)
    ...
    <L>15_<sub_slug>.scd  ex: A15_acid_finale.scd   (track 15)
```

Conventions album :

- 15 tracks numerotees `<L>01` a `<L>15`, sub-styles varies (BPM
  progressif, gammes differentes, instruments variant)
- `_album.scd` declare `~albums[\<L>]` (titre, ordre, durees) et
  expose `~playTrack.(\<L>, n)` / `~playAlbum.(\<L>)` / `~stopAlbum.()`
- Le prefixe `_` exclut le fichier du test E2E `e2e_09_tracks`
  (c'est un orchestrateur multi-bloc, pas une track autonome)

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
