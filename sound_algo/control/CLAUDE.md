# control/ — MIDI, jump, playlist

Outils de pilotage : controleur MIDI, saut direct dans une track,
playlist auto-fade. SETUP manuel apres `00_load.scd`.

## Fichiers

| Fichier | Role |
| --- | --- |
| `midi.scd` | INIT MIDIClient + MAPPING DEFAULT (CC + Notes) |
| `jump.scd` | `~jumpTo.(\X, \section_slug)` |
| `playlist.scd` | `~playPlaylist.([...])` avec fades |

## Pattern SETUP

Chaque fichier expose un bloc SETUP (a evaluer 1x) puis des
helpers `~xxx`. Bloc SETUP enrobe en `(...)` pour eval atomique.

```supercollider
( // SETUP JUMP
~sections = ();
~jumpTo = { |trackLetter, sectionSlug| ... };
"[OK] SETUP JUMP".postln;
)
```

## Jump : invariants

`~jumpTo` doit :
1. Stopper toutes les Routines actives (`~track`, `~filterSweep`, ...)
2. Appliquer la section (mute `~xxx` vars)
3. `~reload.value` pour rebuild Pdef
4. Relancer les Pdef principaux (`\kickSeq`, `\hatSeq`, ...)

Sections enregistrees par chaque track via :
```supercollider
~sections[\A] = (
    \intro: { ~bpm = 124; ~melodyInst = \pad; ... },
    \drop:  { ~bpm = 132; ~melodyInst = \lead; ... }
);
```

## MIDI

- `MIDIClient.init` puis `MIDIIn.connectAll` une seule fois
- `MIDIdef.cc(\name, { |val, num, chan, src| ... }, ccNum, chan)`
- Toujours `MIDIdef.freeAll` avant un re-mapping pour eviter les doublons

## Anti-patterns

- Ne pas evaluer SETUP plusieurs fois sans `MIDIdef.freeAll` -> CC empiles
- Ne pas oublier de stopper les Routines dans `~jumpTo` -> superposition
- Ne pas hardcoder un device MIDI (utiliser device index ou nom)
- Ne pas mapper sur `~xxx` sans `~reload.value` derriere si Pdef-related
- Ne pas appeler `~jumpTo` sur une section non enregistree (silencieux mais inutile)
