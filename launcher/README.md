# AVLiveLauncher

macOS menubar launcher for AV-Live. Coordonne le lancement / arret de
toutes les briques (sclang, oscope-of, data_only_viz, data_feeds, web
UI, dashboard data-only, AV-Live-Body RealityKit) selon le **mode**
choisi au demarrage.

## Build

Requires Swift 6.0+ and Xcode Command Line Tools.

```sh
cd launcher
./build.sh                                    # universal arm64+x86_64
open build/AVLiveLauncher.app

# Build AV-Live-Body (RealityKit, app SwiftPM independante)
cd AV-Live-Body
swift build -c release
```

Le premier lancement affiche un `waveform.path.ecg` dans la menubar.
Clic = popover.

## Les 3 modes (picker au demarrage)

| Mode | Process lances | Use case |
|------|---------------|----------|
| **Full AV-Live** | SC + oscope-of + web UI `:3000` + data_feeds | Studio complet avec Hantek + Hydra |
| **Data-only** | SC + Metal Viz Python + data_feeds + web UI + dashboard `:3211` | Performance autonome sans Hantek, scenes data-driven |
| **Body Mesh** | SC + Multi-HMR headless + AVLiveBody (RealityKit) + data_feeds + dashboard | Mocap performatif, mesh SMPL-X 10 475 verts overlay cam |

Le picker peut etre desactive (`Ne plus afficher`) ; il revient au
dernier mode utilise. Le mode peut etre change a tout moment depuis le
menubar — `applyModeTransition` arrete proprement les process
incompatibles (ex: oF coupe en `.dataOnly`).

## AV-Live-Body — panneau de reglages live

L'app SwiftPM `launcher/AV-Live-Body/` ouvre une fenetre RealityKit
qui affiche la webcam built-in + le mesh SMPL-X recu en TCP `:57130`.
Touche **`S`** ou le bouton coin haut-droit ouvre un panel a 5
sections :

| Section | Reglages |
|---------|----------|
| Couches | toggles webcam / mesh / fil de fer / squelette |
| Webcam | opacite 0..1 |
| Maillage | metallique, rugosite |
| Lumieres | key / fill / rim (0..10 000) |
| Vue | FOV (20..120°), luminosite du fond |

Tous appliques en live dans `BodyView.updateNSView`. L'app est
lancable depuis n'importe quel mode via la row "AV-Live-Body" du
menubar.

## Configuration des chemins

Paths persistes dans `UserDefaults` (`~/Library/Preferences/cc.saillant.AVLiveLauncher.plist`) :

| Defaut | Override |
|--------|----------|
| `/Applications/SuperCollider.app/Contents/MacOS/sclang` | Paths… → sclang binary |
| `~/Documents/Projets/AV-Live/sound_algo/boot.scd` | Paths… → load file |
| `~/Documents/Projets/AV-Live/oscope-of/bin/oscope-of.app/.../oscope-of` | Paths… → oscope binary |
| `/opt/homebrew/bin/uv` (or `~/.local/bin/uv`) | Paths… → uv binary |
| `~/Documents/Projets/AV-Live/data_feeds` | Paths… → data_feeds directory |
| `~/Documents/Projets/AV-Live/data_only_viz` | Paths… → data_only_viz dir |

## Process spawnes — table de routage

```
sclang        : Process sclang + boot.scd (mode-dependent boot file)
oscope-of     : Process .app bundle (capture Hantek + visuals)
metalviz      : uv run python -m data_only_viz.main [--multi-hmr]
                                                    [--fullscreen]
web           : node sound_algo/web/server.js :3000  (control + Hydra)
dataweb       : node data_only_viz/web/server.js :3211 (dashboard data-only)
data_feeds    : uv run python bridge.py [-c config.data-only.toml]
body          : swift run AVLiveBody (RealityKit, :57130 TCP listener)
```

Chaque process a son terminationHandler avec restart sentinel
(`metalVizWantsRestart` etc.) — pas de zombies. Tous les stdouts sont
captures dans `LogView`.

## Ports OSC

| Port | Direction | Role |
|------|-----------|------|
| 57121 | UDP | sclang OSCdef IN (data_feeds + web control) |
| 57122 | UDP | sclang -> web sound_algo (BPM/sync) |
| 57123 | UDP | oscope-of OSC IN + web /control/viz* |
| 57124 | UDP | data_only_viz/web dashboard OSC IN (data_feeds) |
| 57125 | UDP | data_only_viz/web sync IN (SC -> web BPM/RMS) |
| 57130 | TCP | AVLiveBody (RealityKit) - SMPL-X vertices binaire |
