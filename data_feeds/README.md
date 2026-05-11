# data_feeds — Pont flux temps réel → OSC

Worker Python asynchrone qui aspire des sources publiques (sismique,
géophysique, réseau électrique, foudre, aviation, social, blockchain…)
et les rebalance en OSC vers SuperCollider (`:57121`) et openFrameworks
(`:57123`). Le but : nourrir l'engine audio et le visualizer avec des
**signaux du monde réel**, sans bricoler du networking dans `sclang`.

## Architecture

```
                ┌────────────────────────────────┐
                │  data_feeds/bridge.py          │
                │  ├─ usgs        (HTTP 60 s)    │
                │  ├─ swpc        (HTTP 60 s)    │
                │  ├─ netzfrequenz(WebSocket)    │
                │  ├─ blitzortung (WebSocket)    │
                │  ├─ opensky     (HTTP 15 s)    │
                │  ├─ bluesky     (WebSocket)    │
                │  ├─ mempool     (WebSocket)    │
                │  ├─ rte_eco2mix (OAuth2)       │
                │  ├─ github      (HTTP 30 s)    │
                │  └─ gcn         (Kafka)        │
                └─────────────┬──────────────────┘
                              │ OSC broadcast
                ┌─────────────┴────────────┐
        UDP :57121                   UDP :57123
        ┌──▼────────────┐         ┌─────▼────────────┐
        │ SuperCollider │         │  openFrameworks  │
        │ ~feeds dict   │         │  OscClient.data()│
        └───────────────┘         └──────────────────┘
```

## Démarrage

```bash
cd data_feeds
uv sync                              # créé .venv et installe les deps
uv run python bridge.py -v           # -v = verbose
```

Côté SC :

```supercollider
"sound_algo/control/data_feeds.scd".loadRelative;   // installe les OSCdef
~feedDump.value;                                     // affiche l'état
```

Côté oF : automatique dès que `OscClient::update()` tourne (déjà appelé
chaque frame). Lecture :

```cpp
float kp = osc_.dataf("swpc", "kp", /*fallback*/ 2.0f);
std::vector<float> strike;
if (osc_.consumeDataPulse("blitzortung", "strike", strike)) {
    // strike = [lat, lon, age, mult]
}
```

## Schéma OSC

Toutes les routes sont préfixées `/data/<feed>/<sub>`. Voir
[`docs/DATA_FEEDS_OSC.md`](../docs/DATA_FEEDS_OSC.md) pour le schéma
complet.

| Feed           | Routes                                      | Cadence     |
|----------------|---------------------------------------------|-------------|
| `usgs`         | `event`, `rate`                             | 60 s        |
| `swpc`         | `wind`, `bz`, `kp`, `xray`                  | 60 s        |
| `netzfrequenz` | `freq`, `dev`, `time_dev`                   | ~200 ms     |
| `blitzortung`  | `strike`, `rate`                            | event-based |
| `opensky`      | `count`, `plane`                            | 15 s        |
| `bluesky`      | `post`, `rate`                              | event-based |
| `mempool`      | `tx`, `block`                               | event-based |
| `rte_eco2mix`  | `mix`                                       | 15 min      |
| `github`       | `event`                                     | 30 s        |
| `gcn`          | `alert`                                     | rare        |

## Configuration

Éditer `config.toml` :

- `osc.targets` : liste `{host, port}` à arroser (par défaut SC + oF).
- `feeds.<name>.enabled` : booléen.
- `feeds.<name>.poll_seconds` : période pour les feeds HTTP.
- `feeds.opensky.bbox` : `[lamin, lomin, lamax, lomax]` (Lyon par défaut).
- `feeds.bluesky.sample_rate` : 0..1, fraction des posts conservée.

Flux nécessitant des identifiants (désactivés par défaut) :

- `rte_eco2mix` : créer un client sur
  <https://data.rte-france.com/> puis renseigner `client_id` /
  `client_secret`.
- `gcn` : <https://gcn.nasa.gov/quickstart> + `uv add gcn-kafka`.

## Diagnostic

```bash
# Sniffer les paquets recus cote SC
uv run python -c "from pythonosc import osc_server, dispatcher; \
  d=dispatcher.Dispatcher(); d.set_default_handler(lambda a,*x: print(a,x)); \
  osc_server.BlockingOSCUDPServer(('127.0.0.1',57121),d).serve_forever()"
```

Côté SC, vérifier le heartbeat :

```supercollider
~feedAlive.value       // true si le pont émet depuis < 15 s
```

## Ajout d'un flux

1. Créer `data_feeds/feeds/<name>.py` exposant `async def run(ctx)`.
2. L'enregistrer dans `config.toml` avec `enabled = true`.
3. Ajouter les OSCdef correspondants dans
   `sound_algo/control/data_feeds.scd`.
4. Documenter le schéma OSC dans `docs/DATA_FEEDS_OSC.md`.
