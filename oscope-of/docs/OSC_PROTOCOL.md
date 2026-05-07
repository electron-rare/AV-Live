# Protocole OSC entre oscope-of et sound_algo

Référence des messages OSC échangés entre les deux projets. Sert aussi de spec pour toute évolution du bridge `web_bridge.scd` côté sound_algo.

## Vue d'ensemble

```
                 +---------------------+
                 |   sclang (SC IDE)   |
                 +----------+----------+
                            | :57110 (réception SC interne)
                            |
                +-----------v-----------+        :3000 ws
                |   web_bridge.scd      | <----------------> browser (control panel)
                |  (Node + sclang OSC)  |
                +-----+-------------+---+
        :57121 |        |             | :57122
       (SC<-)  |        |             | (->SC, broadcast WS)
               v        v             v
                  +-----+--------------------+
                  |        oscope-of         |
                  |  ofxOscReceiver :57122   |
                  |  ofxOscSender   :57121   |
                  +--------------------------+
```

`oscope-of` :

- **Écoute** sur `127.0.0.1:57122` les `/sync/*`
- **Envoie** sur `127.0.0.1:57121` des `/control/*` interprétés par sound_algo

## Messages reçus (sound_algo → oscope-of)

### `/sync/bpm  <float>`

Tempo courant en BPM. Émis à chaque changement (`~bpm = X` dans une track ou via `~tempo.()`).

```
/sync/bpm 132.5
```

### `/sync/beat <int>`

Compteur de beats incrémenté à chaque pulsation par le clock SC. Reset à 0 sur `~jumpTo` ou changement de track.

```
/sync/beat 1247
```

### `/sync/amp <string voice> <float val>`

Amplitude RMS (0..1) de l'une des 8 voies. Mis à jour ~30 Hz par les RMS analyzers de sound_algo.

Voix possibles : `kick`, `hat`, `snare`, `clap`, `perc`, `melody`, `acid`, `harmony`.

```
/sync/amp "kick" 0.78
/sync/amp "melody" 0.22
```

### `/sync/rms <float master>`

RMS du bus master (post-FX). Utile pour le ducking visuel global.

```
/sync/rms 0.41
```

### `/sync/album <string>`

Nom de l'album courant (ex `acid_journey`, `vietnam_hard`).

### `/sync/melody <string>`

Nom de la mélodie active (ex `epic_long_001`, `short_modal_007`).

### `/sync/synthdef <string>`

SynthDef courante en mélodie (ex `\fmLead`, `\acidBass`).

## Messages envoyés (oscope-of → sound_algo)

oscope-of est un client OSC actif : il peut piloter sound_algo, mais cette feature est minoritaire dans l'usage par défaut (la GUI principale reste le browser web).

### `/control/kk <string>`

Joue un kick via le live API `~kk.<name>`.

```
/control/kk "tek"
```

### `/control/setMelody <string>`

Change la mélodie active.

```
/control/setMelody "epic_long_001"
```

### `/control/setAlbum <string>`

Change l'album / la track.

```
/control/setAlbum "acid_journey"
```

### `/control/<param> <float>`

Tout autre paramètre exposé par sound_algo via OSCdef. La nomenclature suit `~p.<param>.()` ou `~ff.<fxname>.<param>`.

## Notes d'implémentation

- Le bridge sound_algo broadcast les `/sync/*` à la fois en UDP direct (vers `oscope-of` et tout autre client OSC sur :57122) et en WebSocket (vers les browsers). oscope-of utilise UNIQUEMENT le canal UDP.
- Si vous lancez plusieurs visualizers en parallèle (par ex `oscope-of` + un autre client OF), augmenter le buffer UDP socket ou utiliser des ports distincts.
- Le `web_bridge.scd` côté sound_algo doit avoir oscope-of dans sa liste de subscribers UDP. Vérifier dans le bridge :

  ```supercollider
  ~oscRelays = [
      NetAddr("127.0.0.1", 57122),  // oscope-of
      // autres clients OSC...
  ];
  ```
