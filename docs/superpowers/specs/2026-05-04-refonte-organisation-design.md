# Refonte complète de l'organisation du code et des fichiers

**Date** : 2026-05-04
**Statut** : Design approuvé, en attente de plan d'implémentation
**Cible** : passage à une organisation atomique granulaire (1 fichier = 1 unité)

---

## Contexte

Le projet `sound_algo` a actuellement une structure mixte :

- 6 fichiers contenant 38 SynthDef éparpillés (engine.scd + synthdefs/{asia,extra,authentic}.scd + live/{live,fx_bus}.scd)
- 4 fichiers groupés contenant 133 mélodies (`palette/melodies/{short,long,xlong,epic}.scd`)
- 6 fichiers contenant 120+ patterns rythmiques (`palette/rhythm/`)
- 23 fichiers track monolithiques où chaque section est imbriquée dans une `Routine`
- API live `~kk/~mm/~ff/~cc/~p` classifiée par technique (longueur de mélodie, type de FX) plutôt que par genre musical

**Limites observées** :
- Difficile d'ajouter une mélodie / pattern / SynthDef sans toucher un gros fichier multi-blocs
- Impossible d'exécuter une section de track isolément (tout est dans la Routine parente)
- Classification par technique sépare les mélodies d'un même genre dans 4 fichiers différents
- L'API live force à connaître la longueur (`~mShort/~mLong`) plutôt que l'intention musicale

## Objectif

Refondre l'organisation pour atteindre :

1. **Granularité atomique** : 1 fichier = 1 SynthDef, 1 FX, 1 mélodie, 1 pattern, 1 section de track
2. **Classification par genre musical** (pas par technique) pour mélodies et patterns
3. **Auto-discovery** : ajouter un nouveau fichier suffit (pas de mise à jour d'index manuel)
4. **Sections de track exécutables** Cmd+Enter individuellement, sans dépendre du Routine parent
5. **Nouvelle API live** par genre, l'ancienne disparaît complètement (pas de double maintenance)

## Contraintes

- Les 10 tests E2E doivent rester verts à chaque phase de migration
- Convention SC : variables `~xxx` minuscules ; un seul bloc top-level dans les fichiers `.load`-compatibles ; balance parens P:0 B:0
- `web_bridge.scd` doit continuer à fonctionner (le bridge OSC alimenté par la web surface)
- Les 23 tracks A-W doivent rester jouables (boutons jump, chains, web surface)
- Repo GitHub privé déjà push, branche `main` protégée par convention

---

## Architecture cible

### Structure top-level

```
sound_algo/
├── 00_load.scd            # loader / index — entry point
├── 01_live.scd            # tableau de bord live, Cmd+Enter par bloc
├── engine.scd             # Pdef + ~reload + helpers (plus de SynthDef)
├── setup.scd              # ~check / ~setupAll / ~teardown
├── web_bridge.scd         # OSC bridge SC ↔ web
│
├── synth/                 # 1 fichier = 1 SynthDef, sous-dossiers par rôle
├── fx/                    # 1 fichier = 1 FX, sous-dossiers par routage
├── melodies/              # 1 fichier = 1 mélodie, sous-dossiers par genre
├── patterns/              # 1 fichier = 1 pattern, sous-dossiers par genre
├── tracks/                # 1 sous-dossier par track, 1 fichier par section
│
├── palette/               # banques compositionnelles (scales, chords, ...)
├── audio/                 # ce qui était live/ sans les SynthDef
├── control/               # jump, midi, playlist
│
├── tests/                 # E2E
├── examples/              # tutoriels
├── web/                   # Node bridge + UI
├── _archive/              # legacy (ignoré)
└── docs/
    └── superpowers/specs/
```

### `synth/` — 38 SynthDef en sous-dossiers par rôle

```
synth/
├── _index.scd
├── drums/      kick.scd, kick_gabber.scd, hat.scd, snare.scd, snare_gated.scd,
│               clap.scd, perc.scd, rim.scd, cowbell.scd, tom.scd
├── bass/       acid.scd, reese.scd, reese_dnb.scd, reese_hard.scd, sub_boom.scd,
│               fm_bass.scd, hooverbass.scd, didgeridoo.scd
├── lead/       saw3.scd, lead.scd, square_lead.scd, fm_lead.scd, organ_lead.scd,
│               hard_lead.scd, supersaw.scd, stab.scd, pluck.scd, fm_bell.scd, rhodes.scd
├── pad/        pad.scd, warm_pad.scd, vocal_pad.scd, drone.scd
├── world/      koto.scd, erhu.scd, pipa.scd, gong.scd, handpan.scd, guzheng.scd, growl.scd
└── master/     master_lim.scd, master_comp.scd, master_sat.scd, vinyl.scd
```

**Convention par fichier** :

```supercollider
// synth/drums/kick.scd
(
SynthDef(\kick, {
    arg freq = 55, pitchAmt = 3.0, ...;
    ...
}).add;
)
```

Un seul bloc top-level, **uniquement** un `SynthDef.add`. Pas de variable `~xxx`, pas de helpers.

### `fx/` — ~30 FX en sous-dossiers par routage

```
fx/
├── _index.scd
├── bus/        # FX wet send, lus depuis ~fxBuses
│               reverb.scd, delay.scd, chorus.scd, phaser.scd, flanger.scd,
│               bitcrush.scd, tape.scd, shimmer.scd, dist.scd, send.scd
├── insert/     # FX en chaîne avant masterLim
│               vcf_moog.scd, vcf_ms20.scd, vcf_ladder.scd, vcf_formant.scd,
│               vcf_comb.scd, vcf_hpf.scd, vcf_bpf.scd, vcf_notch.scd,
│               ringmod.scd, freq_shift.scd, gran.scd, comb.scd, formant.scd,
│               auto_filter.scd, tremolo.scd, autopan.scd, stutter.scd,
│               resonator.scd, spring_rev.scd, plate.scd
└── trick/      # FX oneshot
                riser.scd, sweep.scd, impact.scd, crash.scd
```

### Auto-glob index

Chaque dossier (sauf `tracks/`) a un `_index.scd` qui scanne récursivement et charge :

```supercollider
// synth/_index.scd
(
PathName(thisProcess.nowExecutingPath.dirname).deepFiles
    .select { |f| f.extension == "scd"
            and: { f.fileName != "_index.scd" } }
    .sort   { |a, b| a.fullPath < b.fullPath }
    .do     { |f| f.fullPath.load };
)
```

`tracks/_index.scd` ne charge PAS les tracks au boot — elles sont lazy, on charge à la demande via `~jumpTo` ou Cmd+Enter manuel sur `_track.scd`.

### `melodies/` — 133 fichiers en sous-dossiers par genre

Mapping inverse depuis `~melodyBank` (palette/melodies/bank.scd actuel) → genre dominant pour chaque mélodie. Une mélodie présente dans plusieurs genres reste dans son genre principal (pas de duplication).

```
melodies/
├── _index.scd
├── acid/       m1.scd ... m12.scd          # ~mAcid1..~mAcid12
├── trance/     m1.scd ... m{N}.scd         # ~mTrance1..
├── detroit/    ...                          # ~mDetroit*
├── dnb/        ...                          # ~mDnb*
├── dub/        ...                          # ~mDub*
├── dubstep/    ...                          # ~mDubstep*
├── house/      ...                          # ~mHouse*
├── hardstyle/  ...                          # ~mHardstyle*
├── phonk/      ...                          # ~mPhonk*
├── synthwave/  ...                          # ~mSynthwave*
├── oriental/   ...                          # ~mOriental*
├── world/      ...                          # ~mWorld*
├── ambient/    ...                          # ~mAmbient*
└── industrial/ ...                          # ~mIndustrial*
```

**Convention par fichier mélodie** :

```supercollider
// melodies/acid/m1.scd
(
~mAcid1 = [36, 0, 36, 0, 39, 36, 41, 36,
           36, 0, 36, 39, 41, 0, 43, 39];
)
```

La longueur (32/64/96/128 pas) est détectée via `.size` à l'usage — pas de classification technique séparée.

### `patterns/` — 120+ fichiers en sous-dossiers

```
patterns/
├── _index.scd
├── kick/       techno.scd, gabber.scd, dub.scd, ...   # ~pKickTechno, ...
├── hat/        offbeat.scd, eighth.scd, sixteen.scd, ...
├── snare/      two4.scd, ghost.scd, ...
├── clap/       ...
├── perc/       ...
└── genre/      # patterns multi-instrument complets
    ├── _index.scd
    ├── acid/        house.scd, hard_techno.scd, ...
    ├── trance/      trance138.scd, psy_trance.scd, ...
    ├── dnb/         liquid.scd, neurofunk.scd, jungle.scd, ...
    ├── dubstep/     ...
    ├── house/       deep.scd, tech.scd, ...
    ├── hardstyle/   ...
    ├── phonk/       ...
    ├── industrial/  ...
    ├── breakcore/   ...
    ├── footwork/    ...
    ├── idm/         ...
    └── glitch_hop/  ...
```

**Pattern simple** (1 instrument) :

```supercollider
// patterns/kick/techno.scd
( ~pKickTechno = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; )
```

**Pattern multi-instrument** (`genre/`) :

```supercollider
// patterns/genre/acid/house.scd
(
~pAcidHouse = (
    kick:     [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0],
    hat:      [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0],
    snare:    [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    clap:     [0!16],
    perc:     [0!16],
    bpm:      125,
    bassline: [36, 0, 36, 0, 39, 36, 41, 36, 36, 0, 36, 39, 41, 0, 43, 39],
    style:    \acid_house
);
)
```

### `tracks/` — sous-dossier par track + sections autonomes

```
tracks/
├── _index.scd               # ne charge PAS les tracks au boot
├── A_acid_journey/
│   ├── _track.scd           # orchestrateur Routine
│   ├── 01_minimal.scd       # Cmd+Enter pour appliquer la section
│   ├── 02_acid_rave.scd
│   ├── 03_detroit.scd
│   ├── 04_hard_push.scd
│   ├── 05_supersaw_dub.scd
│   ├── 06_guzheng_acid.scd
│   ├── 07_outro.scd
│   └── README.md            # timeline, BPM, style — optionnel
├── B_deep_to_hard/
│   ├── _track.scd
│   └── ...
└── ... (W tracks, soit 23 dossiers)
```

**Section autonome** :

```supercollider
// tracks/A_acid_journey/02_acid_rave.scd
//   Section [A 2:00] : acid rave -- kick T1 + melody LEAD + variations
(
"[A 2:00] acid rave -- kick T1 + melody LEAD + variations".postln;

~bpm = 132; TempoClock.default.tempo = ~bpm/60;
~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
~kickDrive = 1.3; ~kickClick = 0.2;

~hatSteps    = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
~melodyInst  = \lead;
~melodyAttack = 0.012; ~melodyRelease = 0.25; ~melodyCutoff = 2400;
~melodyAmp   = 0.16;

~acidNotes  = [36,36,48,36,39,36,43,39, 36,41,36,39,43,36,36,41];
~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
~melodyNotes = ~mAcid1;     // nouvelle API par genre

~reload.value;

[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
)
```

**Section idempotente** : un Cmd+Enter applique tous les paramètres + reload, ne lance PAS de Routine, ne fait PAS de `.wait`.

**Orchestrateur `_track.scd`** :

```supercollider
// tracks/A_acid_journey/_track.scd
(
~track !? { ~track.stop };
~track = Routine({
    var dir = thisProcess.nowExecutingPath.dirname;
    (dir +/+ "01_minimal.scd").load;
    120.wait;
    (dir +/+ "02_acid_rave.scd").load;
    120.wait;
    (dir +/+ "03_detroit.scd").load;
    90.wait;
    // ...
    "[A] === fin ACID JOURNEY ===".postln;
    ~masterFadeOut.(8);
}).play;
)
```

### `audio/` — ce qui était `live/` sans les SynthDef

```
audio/
├── _index.scd
├── fx_bus.scd          # ~fxBuses + ~send + ~setFx + ~fxPreset + ~addFx +
│                       # ~lfo / ~lfoStop / ~tap (LFO sur params FX)
├── insert.scd          # ~vcfOn / ~vcfOff / ~vcfSweep / ~vcfPreset
├── tricks.scd          # ~drop, ~breakdown, ~buildup, ~stutter, ~glitch,
│                       # ~freeze, ~tapeStop, ~tapeReverse, ~jumpCut,
│                       # ~bitCrushNow, ~ringMod, ~freqShift, ~granFreeze,
│                       # ~scratch, ~repeat, ~swap, ~reverbTail, ~handsUp,
│                       # ~chokePerc, ~chokeLead
│                       # + ~trickRoutines, ~trickStop, ~trickStopAll
├── lfo.scd             # ~lfoTo, ~lfoSync, ~lfoStopVar, ~lfoStopAllVars,
│                       # ~lfos dict, ~setVar, ~getVar, ~envSweep, ~envs
├── mixer.scd           # ~setVol, ~mute, ~solo, ~mixPreset, ~saveMix,
│                       # ~masterVol, ~masterFade, ~masterFadeOut, ~xfade
├── scenes.scd          # ~saveScene, ~loadScene, ~listScenes, ~deleteScene
├── loops.scd           # ~loopOn, ~loopOff, ~loopChain, ~loopFade
├── chains.scd          # ~ch dict + ~chainRoutine + ~chStop + helpers
├── wrappers.scd        # ~mAcid, ~mTrance, ~pAcid, ~fx, ~synth (généré
│                       # dynamiquement depuis melodies/ patterns/ synth/ fx/)
└── panel.scd           # ex live_fx_panel — IDE-only
```

**`engine.scd`** ne contient plus de SynthDef. Il garde uniquement `~reload`, les Pdef (avec Pfunc déjà appliqué post-fix RAM), `~scBus`, `~melodyBoost`.

### `palette/` — banques compositionnelles

```
palette/
├── _index.scd
├── scales.scd                  # 16 ~scaleXxx + ~genMelody + ~mutate
├── harmonics/
│   ├── _index.scd
│   ├── helpers.scd             # ~genThirdHarmony, ~genCounterMelody, ...
│   └── presets.scd             # ~enableHarmony.(\third) -- 10 presets
├── chords_progressions.scd     # ~progDetroit, ~progTrance, ...
├── timbres.scd                 # 26 ~timbreXxx -- L1-L26
├── styles.scd                  # 5 ~styleXxx complets
├── fx_genre.scd                # combos FX par genre
├── fills.scd                   # ex palette/rhythm/fills.scd
├── sequences.scd               # ex palette/rhythm/sequences.scd
└── tweaks_template.scd
```

### `control/` (chemins jump.scd ajustés)

```
control/
├── _index.scd
├── midi.scd                    # MIDIClient.init + mapping
├── jump.scd                    # ~jumpTo charge tracks/<X>/NN_section.scd
└── playlist.scd
```

`~jumpTo.(\A, \acid_rave)` ne contient plus une closure inline. Il fait :

```supercollider
~jumpTo = { |trackLetter, slug|
    var dir = ~base ++ "tracks/" ++ ~trackDir.(trackLetter);
    var matches = PathName(dir).files
        .select { |f| f.fileName.contains(slug.asString) };
    if (matches.notEmpty) {
        ~track !? { ~track.stop; ~track = nil };
        matches.first.fullPath.load;   // applique la section
    } { "[JUMP] " ++ slug ++ " inexistante".postln };
};
```

## Nouvelle API live

Les wrappers actuels `~kk/~mm/~ff/~cc/~p` et tous les sous-wrappers (`~mShort, ~mGen, ~kPat, ~fxDrop, ~chIntro, ~pKit`...) sont **supprimés**. Nouvelle API par genre, plus orthogonale.

### Mélodies — `~mGenre.(N | nil | rnd)`

```supercollider
~mAcid.(1)              # applique ~mAcid1 -> ~melodyNotes + reload
~mAcid.()               # random dans le dossier acid/
~mTrance.(3)            # applique ~mTrance3
~mDnb.()                # random dnb
~mList.(\acid)          # liste les mélodies du genre acid
~mList.()               # liste tous les genres et leurs counts
~mNext.()               # mélodie suivante (dans le genre courant)
~mPrev.()               # précédente
~mInst.(\warmPad)       # change l'instrument melody
~mHarm.(\third)         # 10 presets harmonie (\off \third \fifth ...)
```

### Patterns — `~pGenre.(\name)`

```supercollider
~pAcid.(\house)         # applique ~pAcidHouse (kick + hat + snare + bpm)
~pAcid.()               # random dans patterns/genre/acid/
~pTrance.(\trance138)
~pDubstep.(\classic)
~pKick.(\techno)        # pattern kick seul
~pHat.(\offbeat)
~pSnare.(\two4)
~pList.(\acid)
```

### Synth — `~synth.(\group, \name)`

```supercollider
~synth.(\drums, \kick)        # info SynthDef
~melodyInst = \warmPad        # change l'instrument actif
~kickInst = \kickGabber       # change le kick (re-route Pdef)
~synthList.(\drums)           # liste tous les drums
```

### FX — `~fx.(\type, \name, ...args)`

```supercollider
~fx.(\bus, \rev, 0.4)              # ~send vers reverb wet 0.4
~fx.(\insert, \vcfMoog, 1500, 0.6) # active VCF Moog en chain
~fx.(\trick, \riser, 4)            # oneshot riser dur=4s

# Tricks scéniques (inchangés)
~drop.()
~breakdown.(8)
~buildup.(8)
~glitch.(2)
~stutter.(8, 1)
~freeze.()
~tapeStop.(2)
~tapeReverse.(4)
~jumpCut.(0.5)
```

### Chains — `~ch.(\name, ...args)`

```supercollider
~ch.(\intro)
~ch.(\drop)
~ch.(\breakdown)
~ch.(\buildup, 8)
~ch.(\intro2drop, 4, 4)
~ch.(\dropToBreak, 8)
~ch.(\outroFade, 12)
~chStop.()
```

### Mixer / Scenes / Jump (inchangés)

```supercollider
~setVol.(\kick, 0.8)
~mute.(\acid) ; ~solo.(\melody)
~mixPreset.(\drumsHeavy)
~masterVol.(0.7) ; ~masterFadeOut.(8)
~saveMix.(\verseA)
~saveScene.(\drop1) ; ~loadScene.(\drop1)
~jumpTo.(\A, \acid_rave)
```

### Génération dynamique des wrappers

`audio/wrappers.scd` introspect les dossiers `melodies/`, `patterns/`, `synth/`, `fx/` au boot pour générer les helpers `~mAcid`, `~pTrance`, etc. Ajouter un nouveau genre = créer un dossier + un fichier dedans, l'API est mise à jour automatiquement au prochain `~setupAll`.

## Plan de migration (7 phases)

Chaque phase = 1 commit propre, testé, pushé. Si une phase fail, rollback de ce commit sans casser les précédents.

| # | Phase | Risque | Tests E2E |
|---|---|---|---|
| 1 | **Extract SynthDef** : créer `synth/` et `fx/`, déplacer les 38+30 SynthDef. `engine.scd` perd ses SynthDef mais garde Pdef. Auto-glob `_index.scd`. | Bas | Tous doivent passer |
| 2 | **Renommer `live/` → `audio/`** + déplacer `palette/rhythm/{fills,sequences}.scd` → `palette/`. Ajuster `setup.scd`, `00_load.scd`, `_load.scd`, `web_bridge.scd`. | Moyen | Tous doivent passer |
| 3 | **Éclater mélodies** : `melodies/<genre>/m{N}.scd`. Mapping inverse depuis `~melodyBank`. Variables `~m{Genre}{N}`. Supprimer `palette/melodies/`. | Élevé | `e2e_05_melodies` réécrit |
| 4 | **Éclater patterns** : `patterns/<genre>/<name>.scd`. Variables `~p{Genre}{Name}`. Supprimer `palette/rhythm/{kicks,percussions,drum_kits,patterns_genre}.scd`. | Élevé | tests adaptés |
| 5 | **Éclater tracks** : 23 dossiers `tracks/<X>_<slug>/{_track.scd, NN_section.scd}`. Section files autonomes. `_track.scd` orchestrateur. | Élevé | `e2e_09_tracks` adapté + `e2e_10_timestamps` adapté |
| 6 | **Nouvelle API live** : `audio/wrappers.scd` génère `~mAcid/~pAcid/~fx/~synth` dynamiquement. Réécrit `01_live.scd` + `web_bridge.scd` + `web/public/control/app.js` (chips dynamiques via `/api/genres`). Supprime ancienne API. | Très élevé | `e2e_08_live` réécrit |
| 7 | **Nettoyage** : suppression `_archive/` legacy, mise à jour `CLAUDE.md`, `README.md`, skills, `tests/CLAUDE.md`. Commit final tag `v2.0`. | Bas | Tous doivent passer |

## Acceptance criteria

- `bash tests/run_all.sh` retourne 10/10 PASS
- `awk balance` P:0 B:0 sur tous les `.scd`
- Boot complet via `(~base ++ "00_load.scd").load` → `~check.value` reporte tout `[OK]`
- `01_live.scd` Cmd+Enter sur chaque bloc fonctionne (transport, mixer, mélodies, patterns, FX, tricks, chains, scenes, jump)
- Web surface : sliders/chips fonctionnent (genres dynamiques chargés depuis `/api/genres`)
- Track A `_track.scd` Cmd+Enter joue l'intégralité, ET chaque section individuelle Cmd+Enter applique ses params
- `~jumpTo.(\A, \acid_rave)` charge `tracks/A_acid_journey/02_acid_rave.scd` au runtime
- Aucune fuite RAM scsynth/sclang après 30 min de session
- Documentation : root CLAUDE.md + nested CLAUDE.md dans chaque nouveau dossier

## Risques identifiés et mitigation

| Risque | Mitigation |
|---|---|
| Mélodie présente dans plusieurs genres → mauvais classement | Mapping inverse depuis `~melodyBank` actuel + arbitre par genre dominant ; possibilité de la dupliquer manuellement après si dissonance |
| Web surface (`web/public/control/app.js`) hardcoded sur l'ancienne API | Phase 6 inclut endpoint `GET /api/genres` qui scanne `melodies/` et `patterns/` ; les chips JS sont rendues dynamiquement |
| Tests E2E qui hardcodent les anciens chemins (`palette/melodies/short.scd`) | Adapter chaque test E2E dans la phase qui change ses chemins. `e2e_05`, `e2e_09`, `e2e_10` impactés |
| `~jumpTo` actuel utilise des closures inline dans `control/jump.scd` | Phase 5 réécrit `~jumpTo` pour `.load` dynamique d'un fichier section |
| Boot lent à cause de 200+ `.load` séquentiels | Mesurer après phase 1. Si > 5s, batcher ou paralléliser via `Task` |
| Dépendances non triviales entre `synth/` et `palette/` (ex: scales lues par certains SynthDef) | Aucune actuellement (les SynthDef sont autonomes), mais à valider phase 1 |

## Notes complémentaires

- Le pattern `Pfunc { ~xxx }` introduit en commit `62e10b3` (fix RAM LFO+VCF) reste appliqué — la migration ne le touche pas
- Le pattern `~trickRoutines` introduit en commit `c4f17fd` reste appliqué dans `audio/tricks.scd`
- `~crossfadeFxRoutine` et `~chainRoutine` (commit `5f96d57`) restent appliqués dans `audio/fx_bus.scd` et `audio/chains.scd`
- L'auto-launch web (commit `afaa072`) reste dans `web_bridge.scd`

---

**Statut** : design approuvé section par section. Prochaine étape : génération du plan d'implémentation détaillé via la skill `superpowers:writing-plans`.
