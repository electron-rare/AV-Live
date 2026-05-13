# sound_algo — SuperCollider Live Coding System

Generative techno/electronic live performance engine.
1099 SynthDefs (1059 synth + 40 fx), 23 albums × 16 tracks = 368 playable tracks (A–W), 130+ melodies, 8-voice sequencer with sidechain, FX bus, LFO automation, mixer, loops manager.

## Quick Start

1. Open `00_load.scd` in SuperCollider IDE
2. Cmd+Enter on "CHARGER TOUT" block (boots server + loads engine)
3. Open any `tracks/*.scd`, Cmd+Enter to launch
4. Open `live/tweaks.scd` or `live/live_fx_panel.scd` for live tweaks

## Architecture

| Path | Contenu |
|---|---|
| `00_load.scd` | Loader + index (entry point) |
| `engine.scd` | Core SynthDefs + Pdef sequencer + ~reload |
| `synth/` | SynthDef instruments (drums/bass/lead/pad/world/master), auto-loaded via `_index.scd` |
| `fx/` | SynthDef effets (bus/insert/trick), auto-loaded via `_index.scd` |
| `palette/scales.scd` | Scales + melody generation helpers |
| `palette/melodies/` | 130+ melody presets + multi-track |
| `palette/harmonics/` | Harmony generators + ~enableHarmony |
| `palette/rhythm/` | Kicks, percussions, drum kits, patterns, sequences, fills |
| `palette/` | timbres, styles, fx_genre, chords_progressions, tweaks_template |
| `live/` | live.scd, mixer.scd, loops.scd, fx_bus.scd, live_fx_panel.scd, scenes.scd, tweaks.scd |
| `control/` | midi.scd, playlist.scd, jump.scd |
| `tracks/` | 23 autonomous tracks (A-W) |
| `examples/` | 16 step-by-step tutorials |
| `tests/` | E2E test suite |

## Load Order

CHARGER TOUT charge automatiquement dans l'ordre :
1. engine.scd
2. synth/_index.scd + fx/_index.scd (auto-loaders recursifs)
3. palette/scales.scd (scales + helpers melodiques)
4. palette/melodies/index.scd (130+ melodies + multi-track)
5. palette/harmonics/index.scd (~enableHarmony + helpers)
6. palette/rhythm/fills.scd (snareFill, tomFill)

À évaluer manuellement (Cmd+Entrée bloc par bloc) :
- live/live.scd SETUP (LFO, VCF, tricks)
- live/mixer.scd SETUP (faders, mute, solo, master)
- live/fx_bus.scd SETUP (FX bus, presets)
- live/loops.scd SETUP (loops manager)
- live/scenes.scd SETUP (snapshot/recall)
- control/midi.scd INIT + MAPPING DEFAULT
- control/jump.scd SETUP JUMP

## Key Helpers

| Helper | Fichier | Usage |
|---|---|---|
| `~reload.value` | engine.scd | Rebuild Pdef depuis ~xxx vars |
| `~enableHarmony.(\preset)` | palette/harmonics/presets.scd | 10 presets harmonie |
| `~genMelody.(density, scale, len)` | palette/scales.scd | Generateur melodie aleatoire |
| `~lfoTo.(\param, rate, depth)` | live/live.scd | LFO assignable a toute var |
| `~vcfOn.(\type, freq, q)` | live/live.scd | VCF master (8 types) |
| `~drop`, `~breakdown`, `~buildup` | live/live.scd | Tricks sceniques |
| `~send.(\voie, \fx, amount)` | live/fx_bus.scd | Routing audio vers FX |
| `~fxPreset.(\preset)` | live/fx_bus.scd | 10 combos FX |
| `~loopOn.(\name, source)` | live/loops.scd | Loop manager |
| `~setVol/mute/solo` | live/mixer.scd | Mixer 8 voies |
| `~useMelody.(\m50)` | palette/melodies/bank.scd | Charger melodie nommee |
| `~melodyByGenre.(\acid)` | palette/melodies/bank.scd | Random melodie par genre |
| `~jumpTo.(\letter, \slug)` | control/jump.scd | Saut direct dans une track |
| `~playPlaylist.([...])` | control/playlist.scd | Playlist auto-fade |

## Running Tests

```bash
cd tests && bash run_all.sh
```

## Requirements

- SuperCollider 3.13+
- macOS / Linux (testé sur Darwin)
- Pas de Quarks externes requis (toute la synthèse est en UGens natifs)
