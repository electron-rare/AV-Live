# oscope-of

Visualizer openFrameworks pour le système de live coding [`sound_algo`](https://github.com/electron-rare/sound_algo) couplé à un oscilloscope USB Hantek 6022BL.

Trois modes superposés :

1. **Lissajous XY** — CH1=X, CH2=Y, persistance type CRT phosphor (vert `#00FF7F`), shader glow gaussien
2. **Spectrogramme FFT** — 1024 bins, scrolling horizontal, palette bleu→violet→rouge
3. **Layer réactif sound_algo** — grille hexagonale, gradient HSV, modulé par BPM/beat/`amp.*` reçus en OSC

## Pré-requis

- macOS Apple Silicon (M1/M2/M3/M5) — testé en cible, fonctionne aussi sur Intel macs avec ajustement de `config.make`
- [openFrameworks 0.12+](https://openframeworks.cc/download/) avec template Xcode
- Xcode Command Line Tools : `xcode-select --install`
- libusb-1.0 : `brew install libusb`
- Pour charger le firmware Hantek : `brew install fxload` ou compilation depuis [OpenHantek6022](https://github.com/OpenHantek/OpenHantek6022)

## Installation

### Étape 1 — Cloner dans l'arbre openFrameworks

Le projet doit vivre dans `<OF_ROOT>/apps/myApps/oscope-of` pour que le Makefile générique fonctionne :

```bash
cd <OF_ROOT>/apps/myApps/
git clone git@github.com:electron-rare/oscope-of.git
cd oscope-of
```

Si vous le placez ailleurs, ajustez `OF_ROOT` dans `config.make`.

### Étape 2 — Régénérer le projet Xcode

```bash
<OF_ROOT>/projectGenerator -u apps/myApps/oscope-of
```

Cela crée `oscope-of.xcodeproj/` à partir des fichiers `addons.make` et `config.make`.

### Étape 3 — Charger le firmware Hantek

Le 6022BL est un Cypress FX2 sans firmware persistant : il faut uploader le firmware OpenHantek6022 à chaque branchement USB.

Voir le guide complet : [docs/HANTEK_SETUP.md](docs/HANTEK_SETUP.md).

Résumé express :

```bash
# Cloner et builder le firmware OpenHantek6022 une seule fois.
git clone https://github.com/OpenHantek/OpenHantek6022.git
cd OpenHantek6022/openhantek/res/firmware/
# (lire les instructions de build du repo pour produire les .hex)

# Charger à chaque branchement (PID 0x6022 = sans firmware) :
fxload -t fx2lp -I firmware.hex -D /dev/bus/usb/<bus>/<dev>
# ou via libusb-helper sur macOS — voir docs/HANTEK_SETUP.md
```

Une fois le firmware chargé, le device réénumère en `0x04B5:0x602A` et `oscope-of` peut le claim.

### Étape 4 — Lancer sound_algo et son bridge

Depuis votre arbre `sound_algo` :

```supercollider
// Dans SuperCollider
"web_bridge.scd".loadRelative;
~startBridge.value;
```

Topologie OSC : `sclang` écoute `127.0.0.1:57121` (commandes depuis `oscope-of`), `Node↔SC` utilise `:57122`, `oscope-of` écoute `127.0.0.1:57123` les `/sync/*` émis par le bridge.

### Étape 5 — Build et run

Ouvrir `oscope-of.xcodeproj` dans Xcode, sélectionner la scheme `oscope-of Release`, ⌘+R.

Ou en CLI :

```bash
make Release
make RunRelease
```

## Modes et contrôles clavier

| Touche | Action |
|--------|--------|
| `1`    | Mode Lissajous (plein écran XY) |
| `2`    | Mode Spectrogram (plein écran FFT) |
| `3`    | Mode Reactive (layer sound_algo seul) |
| `4`    | Mode Hybrid (défaut, les 3 superposés) |
| `f`    | Toggle fullscreen |
| `g`    | Toggle GUI ofxPanel |
| `r`    | Reload shaders (utile pour l'édition live) |

## Configuration

`bin/data/settings.json` :

```json
{
  "scope":   { "sample_rate": 48000000, "gain_ch1": 0.5, "gain_ch2": 0.5, "buffer_size": 4096 },
  "osc":     { "listen_port": 57123, "send_host": "127.0.0.1", "send_port": 57121 },
  "display": { "fullscreen": false, "width": 1920, "height": 1080, "default_mode": "hybrid" }
}
```

## Protocole OSC

Voir [docs/OSC_PROTOCOL.md](docs/OSC_PROTOCOL.md) pour la liste complète des messages reçus depuis sound_algo et envoyés vers SC.

## Troubleshooting

### "Hantek 6022BL trouvé MAIS firmware non chargé"

Le device énumère en `0x04B5:0x6022` au lieu de `0x602A`. Charger le firmware (voir étape 3) puis relancer.

### "claim_interface failed: LIBUSB_ERROR_ACCESS"

macOS bloque l'accès USB direct par défaut. Aller dans **Réglages Système → Confidentialité et sécurité → Surveillance des entrées** et autoriser le binaire `oscope-of`. Sinon, lancer en root pour test : `sudo bin/oscope-of_debug`.

### Aucun signal en Lissajous

- Vérifier que les sondes sont branchées sur CH1 et CH2 et que le couplage DC/AC est compatible avec votre source
- Vérifier les V/div dans la GUI (slider `CH1 V/div`, `CH2 V/div`)
- Le statut "Scope" dans la GUI doit afficher "OK" et un nombre de samples > 0

### Conflit avec OpenHantek lui-même

Si OpenHantek6022 est lancé en parallèle, il claim le device et `oscope-of` ne pourra pas l'ouvrir. Quitter OpenHantek avant.

### Pas de messages OSC

Vérifier dans la GUI que le port d'écoute est bien `57123`, et que `sound_algo`'s bridge a démarré (`~startBridge.value` dans SC). Tester avec `oscchief` ou `OSCdef.trace`.

## Architecture

```
src/
  main.cpp                       Entry point OF, fenêtre 1920x1080 MSAA 8x
  ofApp.h/.cpp                   Orchestrateur, dispatch des modes
  HantekDevice.h/.cpp            libusb wrapper, thread bulk-transfer
  OscClient.h/.cpp               ofxOsc receiver/sender pour sound_algo
  ScopeData.h                    Ringbuffer SPSC lock-free
  FFT.h/.cpp                     Cooley-Tukey radix-2 in-place
  visualizers/
    Visualizer.h                 Interface abstraite
    LissajousVis.h/.cpp          XY scope avec FBO trail
    SpectrogramVis.h/.cpp        FFT scrolling
    ReactiveVis.h/.cpp           Layer sound_algo (shader bg.frag)
bin/data/
  settings.json
  shaders/
    glow.vert/frag               9-tap Gaussian + threshold
    bloom.vert/frag               Bloom single-pass (réservé futur)
    bg.frag                       Layer réactif sound_algo
docs/
  HANTEK_SETUP.md                Guide firmware + permissions USB macOS
  OSC_PROTOCOL.md                Référence des messages OSC échangés
```

## Licence

MIT — voir le projet sound_algo pour la licence côté SuperCollider.
