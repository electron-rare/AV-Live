# web_realart -- AV-Live data_feeds (deploiement public)

Standalone deployable sur `real.art.saillant.cc` (cloudflared).

Ne depend ni de SuperCollider ni d'openFrameworks : **portage web pur**
des visualizers oF (WebGL via three.js + WebGPU TSL) et des SynthDefs SC
(Web Audio API), tous deux pilotes par les memes flux que les presets
locaux `sound_algo/examples/16_data_feeds.scd` et
`sound_algo/examples/17_data_feeds_more.scd`.

## Architecture

```
data_feeds/bridge.py  --OSC UDP :57124--> web_realart/server.js
                                                |
                                                +-- HTTP :4400 (express)
                                                +-- WS  :/ws (snapshot replay)
                                                          |
                              +---------------------------+---------------------------+
                              v                           v                           v
                    public/webgl/   (3D)        public/audio/  (synth)       public/hydra/  (DSL)
                    three.js + WebGPU TSL       Web Audio API portage SC     hydra-synth
                    globe + particules data     5 presets SC portes          7 patches feeds
                              \                         |                           /
                               +----------- /feeds_client.js (window.feeds) --------+
```

## Lancer en local

```bash
# 1. data_feeds bridge -- ajoute deja la cible 127.0.0.1:57124 (cf data_feeds/config.toml)
cd ../data_feeds && uv run python bridge.py &

# 2. server web
cd web_realart
npm install
npm start

# Ouvrir
open http://localhost:4400/
```

Routes :
- `/`           -- landing
- `/webgl/`     -- globe three.js + WebGPU TSL (fallback WebGL2)
- `/audio/`     -- 5 presets Web Audio (cavity, mix, geo, aurora, pulse)
- `/hydra/`     -- 7 patches Hydra (aurora, quake, lightning, flightmap, gridpulse, solarwind, bskyrain)
- `/api/health` -- statut JSON

## Deploiement `real.art.saillant.cc`

### Option A -- Docker + cloudflared (recommandee)

```bash
docker build -t av-live-realart .
docker run -d --name realart \
  --restart unless-stopped \
  -p 4400:4400 \
  -p 57124:57124/udp \
  av-live-realart
```

Sur la machine cible (electron-server ou VM), ajouter une ingress
au tunnel cloudflared existant (cf
`~/.claude/projects/.../reference_cloudflared_tunnel_saillant.md`) :

```yaml
# /etc/cloudflared/config.yml
ingress:
  - hostname: real.art.saillant.cc
    service: http://localhost:4400
  # ... existing ingresses ...
```

Puis route DNS via API Cloudflare :

```bash
cloudflared tunnel route dns 2c6b04a3-... real.art.saillant.cc
systemctl restart cloudflared
```

### Option B -- Sans Docker (node direct)

```bash
npm install
HTTP_PORT=4400 DATA_PORT_IN=57124 node server.js
```

Mettre derriere systemd :

```ini
# /etc/systemd/system/av-live-realart.service
[Unit]
Description=AV-Live realart web bridge
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/av-live-realart
ExecStart=/usr/bin/node server.js
Environment=HTTP_PORT=4400 DATA_PORT_IN=57124
Restart=always

[Install]
WantedBy=multi-user.target
```

### Bridge data_feeds distant

Si `bridge.py` tourne sur une autre machine que celle qui sert
`real.art`, ajouter dans `data_feeds/config.toml` :

```toml
[osc]
targets = [
    { host = "100.x.y.z", port = 57124 },  # IP Tailscale du serveur web
    # ... les autres targets locaux ...
]
```

ATTENTION : OSC est UDP, sans auth ni chiffrement. **Toujours passer
par Tailscale ou WireGuard** entre le bridge et le serveur web public.
Ne jamais exposer le port 57124 sur Internet.

## Ce qui est porte

| oF / SC source | Web | Note |
|---|---|---|
| `oscope-of/.../ParticleVis` (positions) | `webgl/app.js` Points TSL | Geometrie + materiel TSL |
| `oscope-of/.../ShaderVis` (aurore-like) | `webgl/app.js` BG node | TSL `mx_fractal_noise_float` |
| `oscope-of/.../MeshVis` (sphere wireframe) | `webgl/app.js` LineSegments | three.js standard |
| `cavity_drone` SC | `audio/app.js` startCavity | additif sin sur 7.83x8 Hz |
| `aurora_pad` SC | `audio/app.js` startAurora | 7 partials + LPF Kp |
| `pulse_kick/sub/click` SC | `audio/app.js` startPulse | tempo netz + bsky/usgs |
| `mix_pad/plane_blip` SC | `audio/app.js` startMix | RLPF par renew_pct |
| `geo_bus/quake_sub` SC | `audio/app.js` startGeo | BPF par Kp + flare boost |

Limitations connues :
- Web Audio n'a pas d'equivalent direct de `Splay.ar`, on simplifie en stereo.
- Les SC `tanh` sont rendus via `WaveShaperNode` (curve precalculee).
- `Routine` SC -> `setInterval` JS (drift faible mais acceptable a 1-5 s).
- Pas de FFT analyse cote synth (Hydra : `detectAudio: false` deliberement).
