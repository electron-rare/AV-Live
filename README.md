# AV-Live

> **Live coding audio-visual performance system** built around a SuperCollider sound engine, an openFrameworks oscilloscope visualizer driven by a real Hantek 6022BL USB scope, and a macOS menubar launcher that ties it all together.
>
> 15 scripted demoparties, 41 fullscreen visual backgrounds, 35 3D parametric meshes, 14 retro OS pixel-art tributes, 1099 SynthDefs across 345 tracks, all driven by FFT analysis of the actual audio physically passing through the scope probes.

```
                                  AV-LIVE
              ┌──────────────────────────────────────────┐
              │        AVLiveLauncher.app (menubar)      │
              └────┬───────────────┬──────────────┬──────┘
                   │               │              │
           ┌───────▼───────┐  ┌────▼─────┐  ┌────▼─────────────┐
           │ sclang +      │  │ node     │  │ oscope-of (oF)   │
           │ scsynth       │  │ web ui   │  │                  │
           │ sound_algo/   │  │ :3000    │  │ Hantek bulk USB  │
           │ 1099 SynthDef │  │          │  │ FFT 2048 audio   │
           │ 345 tracks    │  │          │  │ 41 backgrounds   │
           │ humanize+sig  │  │          │  │ 15 demoparties   │
           └───────┬───────┘  └────┬─────┘  └──────┬───────────┘
              :57121 OSC       :3000 HTTP     :57123 OSC in
                   │               │              │
                   └───────────────┴──────────────┘
```

## Features

### 🎵 Sound engine — `sound_algo/`
- **1099 SynthDefs** auto-loaded (acid_v1..v19, bass808_v1..v19, lead_v1..v19, kicks, drums, world, fx, master)
- **23 albums × 15 tracks = 345 tracks** ready to play
- **Subtle humanize** : timing ±3.5 ms, velocity ±10 %, micro-detune ±3 cents per note
- **Synth rotation** : cycles through 19 versions of each SynthDef every 8 notes
- **Auto layering** : 3 voice layers parallel to melody/harmony/acid
- **15 album signatures** with per-album palette, FX drives, layer config
- **OSC bridge** to oscope-of on :57123 (kick/snare/melody/lead/bass/bpm)
- **Web UI** on :3000 with live coding control surface

### 📺 Visualizer — `oscope-of/`
- **Hantek 6022BL** real USB oscilloscope capture (1-48 MS/s, 2 channels, 8-bit)
- **AudioAnalyzer** : downsamples Hantek to 48 kHz, FFT 2048 (~23 Hz/bin), bands bass/lowMid/mid/treble/kick/snare
- **41 backgrounds** : tunnel 3D, starfield, metaballs, voronoi, twister bars, plasma FBM, rotozoom, truchet kaleidoscope, SDF tunnel raymarched, KIFS fractal, fire, perspective grid, tunnel cubes, caustics, vortex, octahedron chrome, vector cubes, plus Möbius/Klein/trefoil/Lucy/helix/catenoid/Boys/penrose/sphere/icosahedron/dodecahedron/torus/twisted torus/lemniscate/hopf/Lorenz attractor/Enneper/hopf link/supershape/gear/cone/pyramid/rose3D/geosphere/DNA helix/sphere wave 3D
- **5 OS pixel-art shaders** : Workbench (Amiga), Mac OS Classic, Atari Fuji, Ocean Loader, Win95
- **14 OS logo PNGs** with demoscene FX (mirror reflection, ghost trail, RGB chroma, twister wobble, scanlines, glitch tear) : Win 1.0/3.11/95, Lotus 1-2-3, MS-DOS, Apple Rainbow, Amiga WB, NeXTSTEP, BeOS, OS/2 Warp, IRIX, ZX Spectrum, C64, Atari
- **10 scroller styles** : Classic, Wavy3D, Rainbow, Mirror, Glitch, Neon, Cascade, Chrome, Bouncy, Squashy
- **Demoscene FX** : sine scroller from `greetings.txt`, copper bars, logo bobs, starfield with motion blur
- **Post-FX shader chain** : ACES tone-map, bloom, chromatic aberration, hue rotation, scanlines, vignette, grain, pixelate, kaleido, feedback FBO, glitch displacement, all GLSL 150 GL 3.2 core

### 🎬 Demoparties — 15 narrative demos
Each demoparty is a multi-act scripted show with unique scroller text, background sequence, scroller style, and SuperCollider album track :

| Key | Demo | Acts | Album |
|-----|------|------|-------|
| `1`/`&` | AMIGA TRIBUTE | 6 | M chiptune_madness |
| `2`/`é` | C64 LOWLIFE | 5 | N phonk |
| `3`/`"` | ACID JOURNEY | 8 | A acid_journey |
| `4`/`'` | TUNNEL VISION | 5 | P industrial |
| `5`/`(` | FREQUENCIES | 7 | I liquid_dnb |
| `6`/`§` | GLITCH WORLD | 6 | V glitch_idm |
| `7`/`è` | AMBIENT VOID | 7 | J ambient_cinematic |
| `8`/`!` | RAVE | 7 | T hardcore_gabber |
| `9`/`ç` | MEMORY LANE | 8 | U vocal_trance |
| `0`/`à` | GREETINGS | 18 | W dub_techno |
| `F6` | FRACTAL DREAMS | 7 | O asian_cinematic |
| `F7` | INFERNO | 6 | E vietnam_hard |
| `F8` | OUTRUN | 6 | R synthwave |
| `F9` | CUBE STORM | 8 | Q neurofunk_dnb |
| `F10` | GRAND FINAL | 8 | L future_garage |

Each act lasts 12-55 s, transitions between acts trigger flash + glitch postfx + audio swap. Demos loop on their first act after the last.

### 🎛 Live FX control (Mac AZERTY FR friendly)
- `a z e r t y u i o p` — 10 background scenes (BoingBall, Tunnel, Metaballs, Voronoi, Twister, KIFS, Fire, Mode7, Octahedron, PlasmaC64)
- `s d f g h j k l m` + `w x c v b n , ;` — 17 FX parameters (speed, kick, roll, pan, curve, tile X/Z, dir lerp, bloom, chroma, kaleido, scanlines, pixelate, hue, grain, vignette, saturation)
- `↑ ↓` — adjust selected parameter (× 1.20 / × 0.83 multipliers, or ± 0.05 absolute)
- `:` — reset all FX
- `\` or `*` — toggle beat-sync (queue demo trigger to next kick)
- `q` / `Esc` — exit narrative, default to SphereWave 3D live background
- `Espace` — manual glitch pulse
- `F1`–`F5` — fullscreen / GUI / postFx / autoglitch / reload shaders

### 🌐 Real-world data feeds — `data_feeds/` + `web_realart/`
- **9 live sources** ingested by `data_feeds/bridge.py` and broadcast as OSC `/data/<source>/<sub>` to SC (`:57121`), oF (`:57123`) and the web bridge (`:57124`) :
  USGS quakes · NOAA SWPC (solar wind, Bz IMF, Kp, X-ray flares) · Mainsfrequenz.de · RTE eCO2mix · Blitzortung lightning · OpenSky ADS-B · Bluesky firehose · Bitcoin mempool · GitHub events · GCN astrophysics · YOLOv8 webcam pose
- **SC presets** `sound_algo/examples/16_data_feeds.scd` and `17_data_feeds_more.scd` map each source to synthesis : Schumann cavity drone (foudre), aurora additive pad (Bz/wind/Kp), Netzfrequenz pulse kick, RTE 8-op carbon FM, OpenSky granular swarm
- **Web standalone** `web_realart/` ports the visualizers and synths to the browser for `real.art.saillant.cc` :
  - **WebGPU + three.js TSL** globe with quake/strike/flight particles (auto-fallback WebGL2)
  - **Web Audio** ports of 5 SC SynthDef presets (cavity, mix, geo, aurora, pulse)
  - **Hydra** with 7 data-driven patches (aurora, quake, lightning, flightmap, gridpulse, solarwind, bskyrain)
  - All three layers share `feeds_client.js` (window.feeds) over one WebSocket

### 📡 Audio reactivity pipeline

```
Hantek probes → bulk USB → ScopeRing CH1/CH2 (1-48 MS/s, 8-bit)
                                ↓
                        AudioAnalyzer.update()
                                ↓
                    Downsample box-filter → 48 kHz mono
                                ↓
                  Hann window + FFT 2048 (23 Hz/bin)
                                ↓
        bands : bass(20-200) / lowMid(200-800) /
                mid(800-3200) / treble(3200-16000) /
                kick (transient bass) / snare (transient mid+treble)
                                ↓
                    drives every visualizer parameter
```

## Quick start

### macOS install

```bash
# 1. Clone
git clone https://github.com/electron-rare/AV-Live.git
cd AV-Live

# 2. Dependencies
brew install --cask supercollider
brew install libusb node
# openFrameworks 0.12 : https://openframeworks.cc/download/  (extract to ~/of)

# 3. Build the launcher (universal binary arm64+x86_64)
cd launcher && bash build.sh

# 4. Build oscope-of (one-time symlink for oF make)
ln -s "$PWD/../oscope-of" ~/of/apps/myApps/oscope-of
cd ~/of/apps/myApps/oscope-of
make OF_ROOT=$HOME/of -j4 Release

# 5. Run
open AV-Live/launcher/build/AVLiveLauncher.app
```

The launcher autostarts `sclang` + `oscope-of` + `node` (web UI) on launch. Open the menubar icon for status, logs, restart controls.

### Without Hantek hardware

oscope-of works without the scope plugged in. It falls back to synthesized signals from the OSC `/sync/*` metadata sent by `sound_algo`. You lose the audio-derived FFT but the demoscene visuals + narrative demos all still play.

## Demoparty mode

Press a digit (1-9, 0) or F-key (F6-F10) to launch a 1-3 minute scripted demoparty. Each one is a journey through audio + visual transitions, with greetings to the demoscene legends along the way (Fairlight, Razor 1911, ASD, Conspiracy, Farbrausch, TBL, Mercury, TPOLM, Loonies, Hokuto Force, IQ, Knighty, Smash, Gargaj…).

The `0` GREETINGS demo cycles through 18 acts including Boing Ball, plasma C64, dot tunnel, twister bars, copper bars, fractal KIFS, Möbius topology, then a parade of OS logos (Win 1.0, Lotus 1-2-3, Atari, Apple, OS/2 Warp, IRIX, ZX Spectrum), ending on a roll call of demoscene groups.

## Architecture details

| Component | Path | Tech |
|-----------|------|------|
| Sound engine | `sound_algo/` | SuperCollider 3.14+, ~12k LOC `.scd` |
| Sound web UI | `sound_algo/web/` | Node Express + WebSocket bridge OSC↔HTTP |
| Visualizer | `oscope-of/` | openFrameworks 0.12, GLSL 150, ~6k LOC C++ |
| Launcher | `launcher/` | SwiftUI universal app, sentinel-based restart |
| Audio FFT | `oscope-of/src/AudioAnalyzer.{h,cpp}` | downsample + Hann + FFT 2048 |
| 3D models | `oscope-of/bin/data/models/` | 35 PLY parametric meshes |
| Sprites | `oscope-of/bin/data/sprites/` | 14 PNG OS logos + 5 SVG sources |
| Shaders | `oscope-of/bin/data/shaders/` | 33 GLSL frag+vert shaders |

OSC ports : `scsynth :57110` · `sclang :57121` · `node web :57122` · `oscope-of :57123` · `http :3000`.

## License

GPL-3.0-or-later. See [`LICENSE`](LICENSE).

## Credits & homages

Built by **L'Électron Rare** (Clément Saillant). Greetings to all the live coders, the demoscene legends, the openFrameworks community, the SuperCollider community, the Saillans festival 2026 artists, and everyone keeping the phosphor alive.

The GREETINGS scroller in `oscope-of/bin/data/sprites/greetings.txt` is the soul of the project — edit it freely and make it yours.

```
*** Press 1-0 + F6-F10 to start a demoparty ***
*** Keep the scene alive — 1985 to ∞ ***
```
