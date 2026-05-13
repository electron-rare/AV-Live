# Patch SuperCollider `data_only/`

Patch SC **autonome** dédié au mode "Data-only" du launcher AV-Live.
Pilote la musique entièrement à partir des flux temps réel publiés par
le pont `data_feeds/` (sismique, météo spatiale, fréquence réseau,
foudre, aviation, social, pose YOLO).

**Distinct du système live principal** : ne charge ni `live/_load.scd`,
ni la palette de 1099 SynthDefs. Boot léger (~2 s) sur un engine
minimaliste.

## Architecture

```text
data_only/
├── boot.scd        Entry point auto-exécutable (sclang ./boot.scd)
├── engine.scd      scsynth boot + FX rack (reverb + comp + limiter)
├── synthdefs.scd   10 SynthDefs préfixées \do_*
├── scenes.scd      9 scènes + sélecteur ~doScene
└── README.md       (vous êtes ici)
```

## Bibliothèque de scènes

| Scene     | Pilotée par                              | Caractère                |
|-----------|------------------------------------------|--------------------------|
| `cavity`  | Schumann 7.83 Hz × Netzfrequenz × Foudre | drone + percussion       |
| `geo`     | Kp × X-ray flares × USGS magnitude       | filtre + sub-bass impacts|
| `body`    | pose YOLO (poignets + épaules)           | corps interactif         |
| `weather` | Vent solaire + Bz IMF                    | drone FM + reverb mod    |
| `flight`  | OpenSky planes Lyon                      | voix FM polyphoniques    |
| `pulse`   | Bluesky rate + lightning + GitHub        | rythme percussif         |
| `quiet`   | Schumann seul                            | transition, fade long    |
| `all`     | cavity + geo + body                      | défaut (audio modéré)    |
| `full`    | toutes empilées                          | densité max              |
| `stop`    | —                                        | coupe tout               |

## Pilotage

### En SC

```supercollider
~doScene.(\all);          // démarre la composite
~doScene.(\weather);      // bascule sur weather
~doScene.(\stop);         // coupe
```

### Par OSC (depuis n'importe où)

```bash
# Scène
oscsend 127.0.0.1 57121 /control/doScene s flight

# Master gain
oscsend 127.0.0.1 57121 /control/doMaster f 0.8
```

### Depuis le launcher

Le panel **Data-only** du popover menubar expose 10 boutons de scène.
Ils envoient `/control/doScene <name>` à sclang.

## Lancement standalone

```bash
sclang /chemin/AV-Live/sound_algo/data_only/boot.scd
```

`boot.scd` :

1. Détecte si `oscope-of` tourne, sinon le lance via `unixCmd`
2. `Server.local.bootSync` (scsynth, 2 ch, mem 64 MB)
3. Charge `engine.scd` → FX rack actif
4. Charge `synthdefs.scd` → 10 SynthDefs
5. Charge `../control/data_feeds.scd` → OSCdef `/data/*`
6. Charge `scenes.scd` → 9 scènes
7. Démarre `~doScene.(\all)`

Affiche `=== AV-Live DATA-ONLY PATCH READY ===` quand prêt.

## Dépendances runtime

- **Pont Python** `data_feeds/bridge.py` actif (sinon `~feeds` reste vide)
- **oscope-of** binaire compilé (le boot le lance si trouvé, sinon
  continue sans visualizer)

## Hot-reload

Pour modifier une scène live sans redémarrer le serveur :

```supercollider
(~base ++ "scenes.scd").load;   // recharge la bibliothèque
~doScene.(\quiet);              // applique la nouvelle version
```

Les `OSCdef` et listeners sont idempotents — on peut recharger
`scenes.scd` n fois sans accumuler.

## Master FX

`engine.scd` installe un rack permanent :

- `\do_reverb` (FreeVerb2 sur bus 2 ch)
- `\do_master` (Compander douceur + Limiter ceiling 0.95)

Chaque SynthDef respecte un paramètre `rev` (0..1) pour son envoi vers
le bus reverb. Pas besoin d'aux global manuel.
