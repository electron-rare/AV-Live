# Schéma OSC — data_feeds

Diffusion : UDP `127.0.0.1:57121` (SuperCollider) **et** `127.0.0.1:57123`
(openFrameworks). Tous les arguments sont des floats sauf mention contraire.

## Méta

| Route             | Args                | Description                          |
|-------------------|---------------------|--------------------------------------|
| `/data/heartbeat` | `uptime_sec`        | Émis toutes les 5 s par le pont      |

## Sismique — `usgs`

Source : <https://earthquake.usgs.gov/>

| Route               | Args                                | Notes                          |
|---------------------|-------------------------------------|--------------------------------|
| `/data/usgs/event`  | `mag lon lat depth_km age_sec`      | Un par séisme nouveau          |
| `/data/usgs/rate`   | `events_per_hour`                   | Fenêtre glissante 1 h          |

## Météo spatiale — `swpc`

Source : NOAA SWPC (DSCOVR, GOES, planetary index).

| Route             | Args                              | Notes                                  |
|-------------------|-----------------------------------|----------------------------------------|
| `/data/swpc/wind` | `speed_kms density_pcm3 temp_K`   | typique 300–800 km/s                   |
| `/data/swpc/bz`   | `Bz_nT Bt_nT`                     | Bz < 0 = orage géomag possible         |
| `/data/swpc/kp`   | `Kp a_index`                      | Kp ∈ [0..9]                            |
| `/data/swpc/xray` | `short_Wm2 long_Wm2 flare_norm`   | `flare_norm` 0..1 sur classes A→X      |

## Réseau électrique — `netzfrequenz`

Source : Mainsfrequenz.de WebSocket (mesure ~200 ms à Karlsruhe).

| Route                          | Args        | Notes                              |
|--------------------------------|-------------|------------------------------------|
| `/data/netzfrequenz/freq`      | `hz`        | typiquement 49.95 .. 50.05         |
| `/data/netzfrequenz/dev`       | `delta_hz`  | `hz - 50.0`                        |
| `/data/netzfrequenz/time_dev`  | `sec`       | Dérive intégrée (horloge synchrone)|

## Foudre — `blitzortung`

Source : LightningMaps WebSocket relay (réseau Blitzortung).

| Route                       | Args                          | Notes                |
|-----------------------------|-------------------------------|----------------------|
| `/data/blitzortung/strike`  | `lat lon age_sec multiplicity`| Un par impact        |
| `/data/blitzortung/rate`    | `strikes_per_min`             | Fenêtre 60 s         |

## Aviation — `opensky`

Source : OpenSky Network REST (anonyme : 15 s max).

| Route                  | Args                                                | Notes                  |
|------------------------|-----------------------------------------------------|------------------------|
| `/data/opensky/count`  | `n`                                                 | Aéronefs dans la bbox  |
| `/data/opensky/plane`  | `"icao24" lon lat alt_m vel_ms heading_deg`         | Un par avion par poll  |

Note : `icao24` est une string ; côté oF elle est hashée djb2 16 bits en float.

## Mix électrique France — `rte_eco2mix`

Source : RTE Open API (OAuth2 client_credentials, gratuit).

| Route             | Args                                                              |
|-------------------|-------------------------------------------------------------------|
| `/data/rte_eco2mix/mix` | `nuclear gas coal oil hydro wind solar bio` (MW)            |

Côté SC, `~feeds[\rte_renew_pct]` calcule `(hydro+wind+solar+bio)/total`.

## Social — `bluesky`

Source : Jetstream WebSocket (firehose posts publics).

| Route                | Args                       | Notes                                |
|----------------------|----------------------------|--------------------------------------|
| `/data/bluesky/post` | `text_len lang_hash`       | Echantillonné selon `sample_rate`    |
| `/data/bluesky/rate` | `posts_per_sec`            | Fenêtre 10 s                         |

## Bitcoin — `mempool`

Source : mempool.space WebSocket.

| Route                | Args                                  |
|----------------------|---------------------------------------|
| `/data/mempool/tx`   | `value_btc fee_sat_vb`                |
| `/data/mempool/block`| `height tx_count reward_btc`          |

## GitHub — `github`

Source : `/events` API publique (60 req/h sans token).

| Route                | Args                          |
|----------------------|-------------------------------|
| `/data/github/event` | `type_hash repo_hash`         |

## Pose / webcam — `pose`

Source : webcam locale (cv2.VideoCapture) + détection YOLOv8-pose
(17 keypoints COCO). Tourne dans `data_feeds/feeds/pose.py`.

**Attention** : sur macOS, **une seule application** peut ouvrir la
webcam à la fois. Si le worker pose tourne, désactiver
`localCapture` dans `WebcamVis` côté oF (et inversement).

| Route                | Args                                                          |
|----------------------|---------------------------------------------------------------|
| `/data/pose/count`   | `n` (nombre de personnes)                                     |
| `/data/pose/person`  | `idx cx cy w h conf` (bbox normalisée 0..1)                   |
| `/data/pose/skel`    | `idx avg_conf x0 y0 c0 ... x16 y16 c16` (53 args si emit_kp)  |
| `/data/pose/bone`    | `kp_a kp_b` (annoncé statiquement à la connexion, 16 paires)  |

Layout COCO (17 keypoints) :

```text
 0 nose          5 sho_l   6 sho_r
 1 eye_l 2 eye_r 7 elb_l   8 elb_r
 3 ear_l 4 ear_r 9 wri_l  10 wri_r
                11 hip_l  12 hip_r
                13 kne_l  14 kne_r
                15 ank_l  16 ank_r
```

Côté SC, helper de lecture :

```supercollider
~poseKp.(\wri_r);          // → (x:, y:, c:)  pour le sujet 0
~feeds[\pose_count];        // nombre de sujets
~feeds[\pose_persons][0];   // (cx:, cy:, w:, h:, conf:)
```

## GCN — `gcn`

Source : NASA GCN Classic over Kafka (auth).

| Route                | Args                                      |
|----------------------|-------------------------------------------|
| `/data/gcn/alert`    | `mission_hash ra_deg dec_deg err_arcmin`  |

## Conventions

- **Strings → hash** : tout argument string non-essentiel est encodé en
  hash djb2 16 bits (`0..65535`) pour rester compatible numérique côté
  SynthDef et shaders. Le pont Python et `OscClient` utilisent la même
  fonction.
- **Age** : pour les événements horodatés (USGS, Blitzortung), un
  `age_sec` est inclus pour permettre de filtrer les vieux événements
  qui arriveraient en burst après une coupure réseau.
- **Idempotence** : tous les `OSCdef` côté SC sont libérés et recréés
  à chaque chargement de `control/data_feeds.scd`.
