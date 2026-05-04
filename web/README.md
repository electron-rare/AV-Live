# sound-algo-web

Pont HTTP + WebSocket + OSC entre le navigateur et SuperCollider pour
piloter `sound_algo` à distance et générer des visuels Hydra synchronisés
au son.

## Architecture

```
 navigateur (control / hydra)
       │
       │  WebSocket  ws://localhost:3000/ws
       ▼
   server.js  (Node.js)
       │
       │  OSC UDP  → 127.0.0.1:57121  (vers SC)
       │  OSC UDP  ← 127.0.0.1:57122  (depuis SC)
       ▼
   sclang  (web_bridge.scd)
```

## Installation

```bash
cd web
npm install
```

## Lancement

**Terminal 1** (Node bridge) :

```bash
cd web
npm start
```

Le bridge écoute sur `http://localhost:3000`.

**Terminal 2** (SuperCollider) :

1. Charger `01_live.scd` bloc `[0]` (engine + setupAll + wrappers).
2. Cmd+Entrée sur le bloc unique de `web_bridge.scd` (à la racine du projet).

**Navigateur** : http://localhost:3000/

- `/control` : surface de contrôle (mixer, BPM, FX, tricks, kicks, patterns, step sequencer)
- `/hydra` : canvas Hydra synchronisé audio (BPM + amplitude RMS par voie)

## Configuration

Variables d'environnement (optionnelles) :

| Variable | Défaut | Rôle |
|---|---|---|
| `HTTP_PORT` | `3000` | Port HTTP du serveur |
| `SC_HOST` | `127.0.0.1` | Adresse de SuperCollider |
| `SC_PORT_OUT` | `57121` | Port d'écoute de SC |
| `SC_PORT_IN` | `57122` | Port d'écoute du bridge |

Exemple :

```bash
HTTP_PORT=8080 SC_HOST=192.168.0.10 npm start
```

## Surface de contrôle

| Section | Contrôles |
|---|---|
| Transport | BPM, master volume, fade out, teardown |
| Mixer | 8 voies (kick/hat/snare/clap/perc/acid/melody/harmony) avec vol/mute/solo |
| Kicks | 18 presets `~kk` (techno, gabber, dub, dubstep, ...) |
| Patterns | 13 kits + 15 genres rythmiques |
| Step sequencer | 5 voies × 16 pas, `Send to SC` envoie tous les patterns |
| FX par voie | Cutoff / Drive / RQ pour melody, acid, kick, hat |
| LFO | Cible (`~melodyCutoff`, `~acidCutoff`, ...) + rate + depth |
| Tricks | Drop, breakdown, buildup, glitch, stutter, freeze, tape stop, etc. |
| FX preset | 10 combos `~ff` (dub, space, trance, dubstep, ...) |

## Hydra (visuels)

Le canvas est synchronisé au son via 3 messages WebSocket :

- `/sync/bpm` : nouveau BPM (sur changement)
- `/sync/beat` : un message par beat (incrémente `window.beat`)
- `/sync/amp` : amplitude par voie (`window.amp.kick`, `.hat`, etc.)

Tous tes patches Hydra peuvent référencer `window.bpm`, `window.beat`,
`window.amp.kick`, etc. pour réagir au son.

6 presets fournis : `default`, `oscWobble`, `kaleido`, `grid`, `warp`, `pixel`.
Cmd+Entrée (ou Ctrl+Enter) pour évaluer ton code dans l'éditeur.

## Format des messages WebSocket

```json
// Navigateur → server.js → SC
{ "address": "/control/setVol", "args": ["kick", 0.8] }
{ "address": "/control/bpm", "args": [128] }

// SC → server.js → navigateur
{ "address": "/sync/bpm", "args": [128] }
{ "address": "/sync/amp", "args": ["kick", 0.5] }
```

Le serveur convertit automatiquement entre JSON (côté WebSocket) et OSC
typé (côté UDP) en mappant : `int → "i"`, `float → "f"`, `string → "s"`.

## Arrêter

- Bridge Node : `Ctrl+C` dans le terminal
- Bridge SC : `~webBridgeStop.value`
