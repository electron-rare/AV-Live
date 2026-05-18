# oscope-sphere

Visualiseur openFrameworks C++ : capture Hantek 6022 (2 canaux) via
libusb -> FFT -> une sphere 3D stereo avec 3 couches composables.
Derive de `oscope-of` (couche capture reutilisee, demoparty jetee).

## Build

```bash
cd oscope-sphere
make            # debug
make Release    # release
make Run        # lance bin/oscope-sphere

./tests/run_tests.sh   # tests C++ purs (clang++, sans openFrameworks)
```

Cible macOS principale (Hantek via libusb). `config.make` detecte
libusb (pkg-config, puis brew, puis chemins par defaut).

## Architecture

| Composant | Fichier |
|-----------|---------|
| Capture USB Hantek 6022 (16 MS/s, 2 ch) | `HantekDevice.{h,cpp}` (copie) |
| Downsampling + FFT 2048 | `AudioAnalyzer.{h,cpp}`, `FFT.{h,cpp}` (copie) |
| Ring buffer SPSC CH1/CH2 | `ScopeData.h` (copie) |
| Spectrogramme roulant log-freq | `SpectrogramBuffer.{h,cpp}` |
| Signal de demo (pas de scope) | `DemoSignal.{h,cpp}` |
| Sphere : peau spectro + relief waveform + points | `SphereViz.{h,cpp}` |
| Anneaux waveform orbitaux | `OrbitRings.{h,cpp}` |
| Cycle de vie, camera, HUD | `ofApp.{h,cpp}`, `main.cpp` |
| Shaders sphere | `bin/data/shaders/sphere.{vert,frag}` |

## Convention canaux

La sphere est coupee a l'equateur : hemisphere Nord = CH1, Sud = CH2.
Cette convention tient sur les 3 couches.

## Couches (touches 1 / 2 / 3)

- A (`1`) : sphere — peau spectrogramme + deplacement waveform
- B (`2`) : deux anneaux waveform orbitaux (un par canal)
- C (`3`) : nuage de points
- `c` : cycle colormap (magma / viridis) ; `space` : fige le defilement

## Conventions

- GLSL 150 GL 3.2 core uniquement. Shaders dans `bin/data/shaders/`.
- Pas d'allocations dans `update()` / `draw()` — buffers preallouees.
- AudioAnalyzer mixe ses 2 arguments : `update(chX, chX)` isole chX.
  Deux analyzers, un par canal.
- 24/48 MS/s sont mono-canal sur le firmware OpenHantek6022 — la
  capture deux-canaux tourne donc a 16 MS/s.
- Scope absent -> mode demo automatique (signal synthetique).

## Anti-patterns

- Ne pas committer `bin/oscope-sphere*` (binaires).
- Ne pas faire d'I/O fichier ni de `new` dans la hot loop.
- Ne pas modifier les 4 fichiers copies de `oscope-of` — les
  resynchroniser depuis `oscope-of/src/` si besoin.
