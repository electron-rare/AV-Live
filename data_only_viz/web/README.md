# data_only_viz/web — Dashboard data-only

Pont **bidirectionnel** Express + WebSocket pour le mode Data-only
(et Body Mesh) d'AV-Live. Sert 3 pages temps reel et fait le bridge
entre :

- les 20 feeds Python (`data_feeds/bridge.py`) sur OSC `:57124`
- le navigateur via WebSocket
- SuperCollider (`sclang`) sur OSC `:57121` (out) et `:57125` (sync in)
- openFrameworks (`oscope-of`) sur OSC `:57123` pour les `vizMode`

## Architecture

```text
   data_feeds bridge.py
        |  OSC :57124
        v
   server.js (Express :3211 + WS)  <----- SC sync :57125 (/sync/*)
        |
        +---> dashboard.html  (cards + sparklines SVG vanilla)
        +---> map.html        (Leaflet dark + markers temps reel)
        +---> control.html    (sliders + scenes + viz modes + XY pad)
                       |
                       v WS -> OSC out
                       :57121 SC  (/control/* /scene/play /xy/*)
                       :57123 oF  (/control/vizMode)
```

## Demarrage

```sh
cd data_only_viz/web
npm install        # une fois
HTTP_PORT=3211 node server.js
# ou via le launcher : mode dataOnly ou bodyMesh -> "Dashboard data-only"
```

URLs :

- `http://127.0.0.1:3211/dashboard.html`
- `http://127.0.0.1:3211/map.html`
- `http://127.0.0.1:3211/control.html`

## Pages

### `/dashboard.html`

Grille responsive de 18 cards live, une par source de donnees.
Chaque card affiche :

- valeur courante (numerique formate)
- ligne sub (contexte : unite, timestamp, info secondaire)
- sparkline SVG vanilla 100x30, dernieres 64-128 valeurs
- classe `.alert` / `.warn` / `.green` selon seuils (ex: Kp >= 6
  alert, PM2.5 > 35 alert, tone GDELT < -5 alert)

Cards couvertes : usgs, swpc (kp/wind/bz/xray), blitzortung,
opensky, bluesky, openmeteo, openaq, iss (pos + pass),
volcano, social_buzz (reddit/hn/pulse), netzfrequenz, gdelt,
wikimedia (rate + edits), tides + moon, atc, pose, mempool,
github, rte_eco2mix (mix + co2).

### `/map.html`

Leaflet dark fullscreen (CartoDB) avec :

- markers ephemeres (TTL 60 s) : seismes (pink), foudre (jaune),
  avions (vert), volcans (orange), GDELT events (purple)
- 1 marker ISS persistant (bleu, contour blanc) qui suit la
  position temps reel
- HUD coin haut-gauche : statut connexion + compteur d'events
  + liens vers dashboard et control

### `/control.html`

Surface de controle 3 colonnes :

| Colonne | Contenu | Endpoint OSC |
|---------|---------|--------------|
| Synthes & mix | 7 sliders : master_gain, cutoff, reso, reverb_mix, delay_time, delay_feedback, tempo | `/control/<name>` -> SC :57121 |
| Scenes audio + retour SC | 10 boutons scenes (cavity/geo/body/weather/flight/pulse/quiet/all/full/stop) + labels BPM/Beat/RMS/Voies retournes par SC | `/scene/play <name>` -> SC :57121 |
| Modes visuels + XY pad | 9 boutons (storm/tunnel/plasma/kaleido/voronoi/metaballs/stars/bars/hands3d) + XY pad pour FX | `/control/vizMode <idx>` -> oF :57123<br/>`/xy/{x,y} <f>` -> SC :57121 |

Les sliders envoient sur drag (input event). Les boutons scenes
et viz toggle visuellement actif. Le XY pad envoie sur
pointerdown/pointermove (Y inverse pour avoir up=1).

## Variables d'environnement

```sh
HTTP_PORT=3211      # port HTTP + WS
OSC_DATA_IN=57124   # feeds IN
OSC_SYNC_IN=57125   # SC sync IN
SC_HOST=127.0.0.1
SC_PORT_OUT=57121   # /control/* /scene/* /xy/*
OF_PORT_OUT=57123   # /control/vizMode
```

## Protocole WebSocket

Tous les messages WS sont du JSON :

```js
// server -> browser (feed) :
{ t: 1715600000000, kind: "feed", feed: "usgs", sub: "event",
  args: [lat, lon, mag] }

// server -> browser (SC sync) :
{ t: 1715600000000, kind: "sync", sub: "bpm", args: [120.0] }

// browser -> server (control) :
{ path: "/control/master_gain", args: [0.8] }
{ path: "/scene/play", args: ["body"] }
{ path: "/xy/x", args: [0.42] }
{ path: "/control/vizMode", args: [3] }
```

Le serveur replay les ~100 derniers events a chaque nouvelle
connexion WS (ring buffer 500 entrees).

## Cote SC : `sound_algo/control/web_bridge.scd`

Charge automatiquement par `boot.data-only.scd` apres
`data_feeds.scd`. Installe les OSCdef `/control/*` `/scene/play`
`/xy/*` sur :57121, et pousse `/sync/bpm|beat|rms|voices` vers
`NetAddr("127.0.0.1", 57125)` a 4 Hz via une `Routine` `AppClock`.

Variable d'env `~webState` partagee pour debug REPL :

```supercollider
~webState.postln;        // -> ( masterGain: 0.8, cutoff: 1200, ... )
```
