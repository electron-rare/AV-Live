# oscope-of

Visualiseur openFrameworks C++ : capture Hantek 6022BL via libusb → FFT 2048 → 41 backgrounds + 14 OS pixel-art + 10 scrollers + chaîne post-FX GLSL.

## Build

```bash
cd oscope-of
make            # debug
make Release    # release
make RunRelease # lance bin/oscope-of (Release)
```

Dépendances oF dans `addons.make`. Cible macOS principale (Hantek via libusb bulk transfers).

## Architecture

| Composant | Fichier |
|-----------|---------|
| Capture USB Hantek (1-48 MS/s, 2 ch 8-bit) | `HantekDevice.{h,cpp}` |
| Downsampling + FFT 2048 bandes bass/mid/treble/kick/snare | `AudioAnalyzer.{h,cpp}`, `FFT.{h,cpp}` |
| Données scope partagées | `ScopeData.h` |
| 41 backgrounds + 5 OS shaders + 14 logos + scrollers | `visualizers/` |
| Chaîne post-FX (ACES, bloom, chroma, scanlines, glitch...) | `PostFx.{h,cpp}` |
| Demo FX (copper bars, sine scroller, bobs) | `DemoFx.{h,cpp}` |
| OSC reçu depuis sound_algo (`:57123`) + envoyé | `OscClient.{h,cpp}` |
| App lifecycle | `ofApp.{h,cpp}`, `main.cpp` |

## Conventions

- **GLSL 150 GL 3.2 core** uniquement — pas de GL 2.1 legacy. Shaders en `bin/data/shaders/`.
- Pas d'allocations dans `update()` / `draw()` — buffers FFT préalloués.
- Hantek bulk transfer : timeout court, fallback gracieux si scope absent (mode démo).
- Les 15 demoparties touchent un état global `currentDemo` dans `ofApp` — toujours mettre à jour les bindings clavier (`keyPressed`) AZERTY (`&é"'(§è!` → `1-8`).
- `greetings.txt` (sine scroller) chargé depuis `bin/data/` au startup — éviter relectures.

## Anti-patterns

- Ne pas appeler `glDrawArrays` sans bind VAO préalable (GL 3.2 core l'exige).
- Ne pas faire `new` dans la hot loop — utiliser `ofVbo` / `ofFbo` membres.
- Ne pas faire d'I/O fichier dans `draw()`.
- Ne pas committer `bin/oscope-of*` (binaires) ni `bin/data/*.mov` (gros).
- Ne pas ajouter de dépendance non-headless sans l'inscrire dans `addons.make`.
