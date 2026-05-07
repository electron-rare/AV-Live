# PD <-> SC bridge

Pure Data ↔ SuperCollider via OSC bidirectionnel.

## Installation

PD a été installé via `brew install --cask pd` (Pd-vanilla 0.56-2 dans `/Applications/Pd-0.56-2.app`).

## Architecture

```
   PureData                       SuperCollider
   ┌──────────┐    OSC :57120    ┌──────────┐
   │ bridge.pd│  ──────────────> │ sclang   │
   │  (GUI)   │  <────────────── │ engine   │
   └──────────┘    OSC :57121    └──────────┘
```

- **PD → SC** : envoie OSC sur `localhost:57120` (port standard sclang)
- **SC → PD** : envoie OSC sur `localhost:57121` (port `udpreceive` du patch)

## Workflow

### 1. Côté SC

```supercollider
// 1. Charge tout le projet
//    (00_load.scd > CHARGER TOUT)

// 2. Charge le bridge
("/Users/electron/Documents/Projets_Creatifs/sound_algo/pd/bridge.scd").load;
//    OU ouvre pd/bridge.scd, Cmd+Entree sur le bloc SETUP
```

### 2. Côté PD

Ouvre `pd/bridge.pd` dans Pure Data (Pd-0.56-2.app).

Le patch contient :
- **TRANSPORT** : boutons PLAY / STOP / CHOKE / DROP / BREAKDOWN / BUILDUP / FREEZE / GLITCH
- **FADERS_VOIX** : 8 sliders verticaux (kick / hat / snare / clap / perc / acid / melody / harmony) + master
- **TWEAKS_FILTRES** : sliders horizontaux (melody_cutoff / acid_cutoff / bpm)
- **FX_PRESETS** : boutons (dub / space / trance / industrial / cosmic / dry)

Les sliders et boutons envoient OSC vers SC au format `/<addr> <value>`.

### 3. Test

Clique sur **PLAY** dans le patch PD → tu dois entendre le beat lancé par SC.

## Messages OSC supportés (PD → SC)

| Adresse | Args | Action |
|---|---|---|
| `/play` | — | Lance les 8 Pdef sequencer |
| `/stop` | — | Stop les Pdef |
| `/choke` | — | Stop tracks + Pdef |
| `/drop` | — | `~drop.()` |
| `/breakdown` | — | `~breakdown.(8)` |
| `/buildup` | — | `~buildup.(8)` |
| `/freeze` | — | `~freeze.(4)` |
| `/glitch` | — | `~glitch.(2)` |
| `/stutter` | rate, dur | `~stutter.(rate, dur)` |
| `/vol/<voie>` | val | `~setVol.(\voie, val)` |
| `/vol/master` | val | `~masterVol.(val)` |
| `/tweak/melodyCutoff` | hz | `~melodyCutoff = hz` |
| `/tweak/acidCutoff` | hz | `~acidCutoff = hz` |
| `/tweak/bpm` | bpm | TempoClock |
| `/tweak/melodyRq` | val | `~melodyRq = val` |
| `/fx/preset` | name | `~fxPreset.(\name)` |
| `/fx/send` | voie, fx, amount | `~send.(\voie, \fx, amount)` |
| `/fx/freeze` | 0\|1 | freeze reverb |
| `/vcf/on` | type, freq, q | `~vcfOn.(\type, freq, q)` |
| `/vcf/off` | — | `~vcfOff.()` |
| `/lfo/to` | param, rate, depth, shape, center | `~lfoTo.(...)` |
| `/lfo/stop` | param | `~lfoStopVar.(\param)` |
| `/scene/save` | name | `~saveScene.(\name)` |
| `/scene/load` | name | `~loadScene.(\name)` |
| `/jump` | track, slug | `~jumpTo.(\track, \slug)` |
| `/melody` | name | `~useMelody.(\name)` |
| `/melody/genre` | genre | `~melodyByGenre.(\genre)` |
| `/preset` | name | `~mixPreset.(\name)` |

## Messages OSC envoyés (SC → PD)

| Adresse | Args | Description |
|---|---|---|
| `/sc/status` | 1 | heartbeat (1Hz) |
| `/sc/cpu` | float | CPU usage % |
| `/sc/synths` | int | nb de synths actifs |

## Audio

Ce bridge gère les **messages de contrôle** (OSC). Pour router l'audio entre PD et SC :

- **Option 1 — JACK** : `brew install jack` puis route `Pd → SC` via JACK
- **Option 2 — BlackHole** : `brew install --cask blackhole-2ch` (loopback virtuel macOS)
- **Option 3 — multi-out** : SC sort sur device A, PD lit device A en input

Aucune route audio n'est configurée par défaut — chaque app sort sur son propre device audio.

## Stop

```supercollider
~pdDisconnect.();   // libere les OSCdef + status loop
```

Et ferme le patch PD normalement (Cmd+Q).

## Ajouter un nouveau message

**Côté PD** : ajoute un objet `[msg send /mon/addresse $1]` connecté à un slider/bouton, le tout connecté à `[netsend -u -b]`.

**Côté SC** : ajoute un `OSCdef` dans `pd/bridge.scd` :
```supercollider
~pd[\defs].add(OSCdef(\pdMonAction, { |msg|
    ("recu : " ++ msg).postln;
    // ... action
}, '/mon/addresse'));
```

Re-évalue le bloc SETUP.
