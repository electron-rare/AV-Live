# palette/ — Generators & banques

Source de verite pour scales, melodies, harmonies, rythmes, timbres,
chords, FX genre. Charge automatiquement par `00_load.scd`.

## Structure

| Sous-dossier | Charge via |
| --- | --- |
| `palette/scales.scd` | direct (avant melodies + harmonics) |
| `palette/melodies/` | `melodies/index.scd` |
| `palette/harmonics/` | `harmonics/index.scd` |
| `palette/rhythm/` | `rhythm/fills.scd` (auto), reste manuel |
| `palette/{timbres,styles,chords_progressions,fx_genre}.scd` | manuel |

## Conventions de nommage

- Scales : `~scaleMinor`, `~scaleHijaz`, `~scaleVietnamMaj`, ...
  (toutes basees sur C/60, octaves +/-)
- Melodies : `~m{N}` (32 pas), `~ml{N}` (64), `~mxl{N}` (96), `~mepic{N}` (128)
- Generators : verb-first (`~genMelody`, `~mutate`, `~enableHarmony`)
- Banques exposees via `live/melodies.scd` et `live/patterns.scd`

## Patterns generators

```supercollider
~genMelody = { |density = 0.55, scale, len = 32|
    var s = scale ?? { ~scaleMinorPent };
    len.collect { if (density.coin) { s.choose } { 0 } };
};
```

- Generators retournent toujours un Array de notes MIDI (0 = silence)
- Density = 0..1 (0 = vide, 1 = plein)
- Scale par defaut via `??` fallback, jamais nil

## Anti-patterns

- Ne pas dupliquer une scale qui existe deja dans `scales.scd`
- Ne pas creer de generator qui mute `~xxx` directement -- retourner la valeur
- Ne pas indexer une scale hors bornes (utiliser `.wrapAt` ou `.choose`)
- Ne pas creer de fichier `index.scd` qui charge en dehors de `palette/`
- Ne pas charger `palette/melodies/*` avant `palette/scales.scd`
