# iPhone ↔ AV-Live — refonte technique SOTA 2026 (design)

Date: 2026-06-30
Statut: design validé, en attente de relecture utilisateur avant plan d'implémentation
Approche retenue: **C — fidélité maximale** (corps 3D + mains liftées en 3D)

## Contexte & problème

Le système capture un squelette corps + mains sur iPhone 16 Pro (iOS 26.5) et
le streame vers un Mac pour piloter une performance audio-visuelle (matrix
SuperCollider). L'utilisateur veut « vraiment la vision du squelette de pose
sur data_only_viz et dans le lien de données », et une refonte technique
« SOTA 2026 » sur quatre axes : **fidélité du squelette, latence/perf,
modernisation de la stack Apple, robustesse/maintenabilité**.

Signaux retenus pour la performance : **corps 3D + mains/doigts**.
Hors scope : visage/bouche, profondeur/mesh LiDAR.

### Diagnostic de l'existant (factuel)

Le **lien de données est déjà bon**. L'iPhone envoie sur TCP :7000 (usbmuxd,
filaire, pas de réseau) en frames AVLiveWire (header 19 o big-endian) :

- `skeleton` (tag 1) : 91 joints 3D world-space + validité, ~30 fps
- `skeleton2D` (tag 6) : 91 joints 2D projetés normalisés, ~30 fps
- `hands` (tag 4) : 21 pts × 2 mains (Vision), ~15 fps
- `video` (tag 2) : HEVC, keyframe / 30 frames

La dégradation est **côté consommation/rendu data_only_viz** :

- Les 91 joints sont décodés intacts dans `persons_arkit_joints`, **puis 76
  sont jetés** : `arkit_joint_map.py` (`ARKIT91_TO_MP33`) ne mappe que **15
  joints** dans le conteneur MediaPipe MP33.
- `renderer.py` ne connaît que MP33 (35 os MediaPipe) → seuls **14 segments**
  sont dessinés (le « 14 segs, 17 tris » observé). Aucun chemin vers
  `persons_arkit_joints`.
- Les index du mapping sont **non vérifiés** (`ARKIT_HEAD_IDX = 51` annoté
  « VERIFY LIVE »).
- Le log `body3d: n=1 (pose_world_landmarks)` est trompeur (la source est
  ARKit sous `--iphone-usb`, pas MediaPipe).
- Code mort : chemin OSC/UDP supprimé côté iOS mais doc périmée
  (`iphone-arbody/CLAUDE.md` montre encore un fanout OSC) ; tag `face` (5)
  défini mais jamais émis ; tag `meta` (3) réservé inutilisé.

À noter : l'armature 91 joints complète **est** rendue correctement ailleurs,
par `AVLiveBody` (Swift, `Skeleton3DRenderer.swift`), consommateur distinct du
même flux. Les deux consommateurs divergent.

### État de l'art Apple iOS 26 (recherche, sources datées)

- **Corps 3D** : ARKit `ARBodyTrackingConfiguration` / `ARSkeleton3D` (~91
  joints hiérarchiques world-space, A12+, 60 fps) reste le plus riche sur
  iPhone. Vision `VNDetectHumanBodyPose3DRequest` (iOS 17+) ne donne que 17
  joints → trop pauvre. Rien de matériellement nouveau en iOS 26 pour le body
  3D iPhone (surtout une API Vision Swift async).
- **Mains** : pas de finger tracking ARKit natif sur iPhone (visionOS only).
  Voie native = Vision `VNDetectHumanHandPoseRequest` (21 joints). iOS 26
  apporte un **nouveau modèle hand pose** plus petit/précis/basse latence —
  **mais les positions de joints ont bougé** (re-tuning des classifieurs
  requis). Holistic `detectsHands` (iOS 18) existe mais est **2D**.
- **Fusion corps+mains 3D** : pas d'unifié natif sur iPhone → **fusion
  manuelle obligatoire** (état de l'art).
- **Transport** : usbmuxd + TCP sur câble reste recommandé pour le live
  filaire ; `NWConnection` (Network framework) est l'API moderne ;
  peer-to-peer Wi-Fi à éviter (latence).
- **Concurrence** : `CVPixelBuffer` / `ARFrame` non `Sendable` → pipeline en
  `actor`, copie en structs `Sendable`, `AsyncStream` + `sending`, cible Swift
  6.2 « approachable concurrency ».

Conclusion : la stack de base (ARKit body + Vision hands + AVLiveWire/usbmux)
est la bonne ; la refonte **exploite le riche existant** et **modernise les
fondations**, elle ne remplace pas ARKit.

## Contrainte structurante

**Le lift 3D des mains par LiDAR n'est pas faisable.**
`ARBodyTrackingConfiguration` rejette `.sceneDepth` (crashe la session) ;
`.personSegmentationWithDepth` spamme « Portrait image not supported ». Le
TrueDepth est sur la caméra avant, l'ARBodyTracking sur l'arrière → pas
simultanés. La profondeur capteur n'est donc pas disponible pendant le body
tracking.

→ Le 3D des mains est obtenu par **lift géométrique / IK ancré sur le poignet
ARKit 3D** (cf. `HandLiftSolver`), sans LiDAR.

## Principe directeur

> Le téléphone est la **source de vérité 3D auto-descriptive** : il envoie
> l'armature complète (corps + mains liftées) + sa topologie, horodatée, dans
> un frame unifié. Les consommateurs (data_only_viz Python, AVLiveBody Swift)
> **dessinent ce qu'on leur décrit** — zéro index hardcodé, zéro
> reconstruction dégradée.

## Architecture & composants

### iPhone (`iphone-arbody/`, Swift 6.2)

```
ARSession (ARBodyTrackingConfiguration, caméra arrière)
   │ ARFrame @60fps  (MainActor : extrait UNIQUEMENT des valeurs Sendable)
   ▼
CaptureActor (actor, hors main thread)
   ├─ extrait 91 joints 3D + validité
   ├─ HandPoseService  (nouveau modèle Vision iOS 26)
   ├─ HandLiftSolver   (2D → 3D ancré poignet)
   └─ copie en structs Sendable
   │ PoseSnapshot (Sendable, 1 timestamp)
   ▼
PoseEncoder → AsyncStream<Frame>          TopologyProvider (1× au connect)
   ▼
WireServer (NWConnection, TCP :7000, usbmux)   [+ VideoEncoder optionnel]
```

Nouveaux composants : `CaptureActor` (isolation concurrence),
`HandPoseService`, `HandLiftSolver`, `TopologyProvider`, `PoseEncoder`.
`VideoEncoder` devient optionnel (`SEND_VIDEO`).

### Protocole partagé (`shared/AVLiveWire/`, v2)

- `FrameHeader` v2 : magic `AVL2`, octet **version** négocié.
- `PosePayload` (tag `pose`) : corps 91 + N mains, **un seul frame horodaté**.
- `TopologyPayload` (tag `topology`) : noms de joints + parentIndices corps &
  mains, émis 1× au connect (+ resend à chaque reconnexion).
- Tags `skeleton` / `skeleton2D` / `hands` / `face` dépréciés puis retirés.

### Mac

- `data_only_viz` : `IphonePoseSource` (décode v2 → état unifié) +
  `SkeletonRenderer` refondu (corps + mains 3D, topologie-driven, plus de
  MP33). Détection gestes (`hand_features.py`) consomme les joints **main 3D**.
- `AVLiveBody` (Swift) : aligné sur v2 (même `pose` + topologie).
- Suppressions : `arkit_joint_map.py`, chemin OSC mort, log trompeur.

## Flux de données & schéma v2

### Header v2 (20 octets, big-endian)

| Champ | Taille | Note |
|-------|--------|------|
| magic | 4 o | `AVL2` |
| version | 1 o | `2` (négociation explicite) |
| tag | 1 o | `pose=1`, `topology=2`, `video=3` |
| pid | 2 o (i16) | id corps, `-1` global |
| timestamp | 8 o (f64) | horloge ARFrame, partagé corps+mains |
| length | 4 o (u32) | longueur payload |

### `PosePayload` (tag `pose`), ~30 fps

```
u8   bodyJointCount            (= 91)
[91] float32 x,y,z             joints corps 3D world-space (m)
[91] u8 valid
u8   handCount                 (0..2)
 └─ par main:
     u8   chirality            (0=left, 1=right)
     u8   lifted               (1 = 3D résolu, 0 = fallback planaire)
     [21] float32 x,y,z        joints main, MÊME repère monde que le corps
     [21] u8 valid
```

### `TopologyPayload` (tag `topology`), 1× au connect

```
u16  bodyJointCount, puis bodyJointCount × [u8 nameLen + utf8 name]
[bodyJointCount] i16 parentIndex          (-1 = racine)
u16  handJointCount (=21), idem noms + parents (modèle Vision iOS 26)
```

Le renderer construit ses os depuis `parentIndex` : zéro index hardcodé. Si
l'ordre des joints change (nouveau modèle mains iOS 26), le rendu suit.

### Synchro & cadence

- Body @30 fps (throttle conservé) ; le dernier hand snapshot dispo est
  agrégé dans le frame body courant (timestamp partagé) → fin du désync
  15/30 fps.
- Vidéo : tag séparé, optionnelle (`SEND_VIDEO=0` par défaut pour la visu).

## HandLiftSolver (cœur de l'approche C)

Sur l'iPhone. Entrées : 21 joints 2D Vision + intrinsèques caméra `ARFrame` +
poignet ARKit 3D (déjà dans les 91 joints). Sortie : 21 joints main
world-space, même repère que le corps.

1. **Ancrage** : poignet de la main Vision forcé sur le poignet ARKit 3D
   (profondeur `d₀` connue, non ambiguë).
2. **Orientation initiale** : axe avant-bras ARKit (coude→poignet) + up caméra
   → repère de paume (lève l'ambiguïté dos/paume + roll).
3. **Back-projection** : chaque joint 2D → un rayon caméra (via intrinsèques).
4. **Résolution par contrainte de longueur d'os** : propagation de la chaîne
   cinématique, profondeur par joint choisie pour respecter les longueurs d'os
   anthropométriques (a priori main ~18 cm, proportions fixes). Ambiguïté à 2
   solutions → branche cohérente avec la frame précédente.
5. **Lissage** : One Euro sur les 21 joints 3D, anti-flip de branche.

### Précision (honnêteté)

Le 3D monoculaire d'une main est intrinsèquement ambigu en profondeur. Le lift
contraint par longueurs d'os donne un 3D **plausible et stable pour la
visualisation et les effets spatiaux**, pas de la métrologie. C'est le but de
l'approche C (fidélité visuelle).

### Gestes en 3D (décision utilisateur)

Les 8 slots pinch + fist sont calculés sur le **3D lifté** (pas le 2D) :

- Pinch = distance 3D métrique pouce↔doigt, **normalisée par la taille de main
  3D** → invariant à la rotation de la main. Fist = courbure 3D de la chaîne.
- **Re-tuning obligatoire** : `PINCH_RATIO_ON=0.45` / `OFF=0.65` deviennent des
  ratios 3D, à re-dériver sur device (re-tuning de toute façon imposé par le
  nouveau modèle mains iOS 26).
- **Robustesse** : seuils normalisés par taille de main (annule l'erreur
  d'échelle), hystérésis ON/OFF conservée, réfractaire conservé, lissage One
  Euro avant calcul du geste.
- **Fallback `lifted=0`** : 3D planaire à la profondeur du poignet → le pinch
  reste l'équivalent du 2D actuel ; les gestes continuent de marcher.
- **Calcul côté Mac** (`hand_features.py` + routing OSC matrix) sur les joints
  main 3D du frame. iPhone = capture+lift pur, Mac = sens+routing.

## Concurrence, latence & perf

### Pipeline iPhone en isolation stricte (Swift 6.2)

- `ARSessionDelegate` (MainActor) extrait uniquement des valeurs `Sendable`
  (transforms, intrinsèques) ; aucun `CVPixelBuffer`/`ARFrame` ne franchit une
  frontière d'isolation (supprime le `nonisolated(unsafe)` patch).
- `CaptureActor` sérialise l'état mutable (fps, compteurs, dernier hand) → fin
  des data races sans lock manuel.
- Structs `Sendable` (`BodySnapshot`, `HandSnapshot`, `PoseFrame`) copiées
  avant toute frontière. `CVPixelBuffer` → `VideoEncoder` uniquement, via
  `sending`.
- `AsyncStream` pour pousser au réseau (back-pressure naturelle).
- Build en strict concurrency (Swift 6.2 approachable concurrency).

### Budget latence (geste → son), chemin filaire

| Étage | ~ms |
|-------|-----|
| ARKit body + Vision hand (A18 Pro) | 16–20 |
| HandLiftSolver | < 2 |
| Encode frame v2 + usbmux TCP (câble) | 2–5 |
| Décode Mac + filtre pose + calcul geste | 5–8 |
| OSC → SuperCollider | ~2 |
| **Total estimé** | **~30–40 ms** |

### Leviers perf

- Vidéo off par défaut (`SEND_VIDEO=0`) : supprime encode HEVC + décode PyAV +
  bande passante.
- Frame `pose` unifié : 1 message / 30 fps au lieu de 3 flux désynchronisés.
- Throttle body 30 fps conservé (60 fps dispo si besoin futur).

## Gestion d'erreurs & dégradation

Principe : dégrader gracieusement, ne jamais crasher, toujours signaler
l'état.

- **Reconnexion** : back-off auto (iPhone `WireServer`, Mac `IphonePoseSource`).
  La topologie est renvoyée à chaque (re)connexion ; le Mac bufferise les
  `pose` jusqu'à réception de la topologie. Flux coupé → dernier squelette
  gelé avec indicateur « stale », pas de disparition brutale.
- **Perte de tracking** : aucun corps → « no body », modulation gelée sur
  dernière valeur ; joints partiels → flag `valid` par joint, os non dessiné,
  IK comble les trous courts ; main absente → gestes désarmés proprement ;
  main non liftée → `lifted=0`, 3D planaire, geste calculé, affichage distinct.
- **Mismatch version** : `AVL2` + octet version → un consommateur d'une autre
  version rejette explicitement avec log clair (pas de décodage silencieux
  faux). `StreamDemuxer` : resync magic, rejet `length > maxPayload`, compteur
  de frames corrompues exposé.
- **Garde-fous gestes** : hystérésis + réfractaire ; confiance < seuil sur N
  frames → geste forcé OFF ; armement sur front uniquement.
- **Observabilité** : frame de métriques léger (fps réel, % frames liftées,
  drops Vision, frames corrompues, latence aller) affichable dans data_only_viz
  / web control.

## Tests & validation

- **N1 — Unitaires déterministes** (`shared/AVLiveWire`) : round-trip
  encode/decode `PosePayload` + `TopologyPayload` ; robustesse `StreamDemuxer`
  (tronqué, magic partiel, frame géante, resync, rejet de version) ;
  `HandLiftSolver` (poignet synthétique + rayons + longueurs d'os → coïncidence
  poignet 3D, reprojection < ε px, stabilité de branche).
- **N2 — Index ARKit sur device** : mode debug logue les noms
  `ARSkeletonDefinition`, le renderer étiquette chaque joint → confirmation
  visuelle une fois pour toutes (tue le « VERIFY LIVE » ; la topologie
  auto-descriptive empêche la re-dérive).
- **N3 — Harnais comparatif gestes 2D→3D** : double détection 2D‖3D en
  parallèle sur le même flux device, log des divergences ; bascule quand 3D ≥
  2D en fiabilité et 0 faux positif ajouté (pinch lent/rapide, main
  tournée/de profil, fist) ; re-dérivation des seuils 3D ici. 2D reste source
  live tant que le critère n'est pas atteint (flag réversible).
- **N4 — Visuel bout-en-bout** : data_only_viz affiche l'armature 91 joints +
  mains 3D (vs 14 segments actuels). Capture d'écran : `screencapture` est
  bloqué (permission Enregistrement de l'écran absente) → soit accorder la
  permission, soit valider via métriques + logs structurés (à décider en
  implémentation).
- **Latence** : mesurée en continu via le timestamp partagé du frame.

## Phasage & migration

Le live garde un chemin fonctionnel à chaque étape ; chaque phase est livrable,
validée, réversible par flag. Valeur visible d'abord, risque ensuite.

| Phase | Contenu | Driver | Risque | Réversible |
|-------|---------|--------|--------|------------|
| 0. Protocole | AVLiveWire v2 (header versionné, `PosePayload`, `TopologyPayload`) + tests | robustesse | faible | n/a |
| 1. Squelette fidèle | iPhone émet la topologie ; data_only_viz nouveau renderer sur les 91 joints déjà décodés + mains, topologie-driven. **Gain visible : vrai squelette.** | fidélité | faible | flag (rendu MP33 en repli) |
| 2. iPhone modernisé | Refacto capture `actor` Swift 6.2 + Sendable, frame `pose` unifié horodaté, vidéo optionnelle | latence + Apple | moyen | dual-emit v1/v2 |
| 3. Mains 3D | `HandLiftSolver` → mains world-space dans le frame ; validation solver | fidélité | moyen | `lifted=0` repli planaire |
| 4. Gestes 3D | Harnais double-détection, re-tuning seuils, bascule quand 3D ≥ 2D | fidélité | moyen | flag (2D source tant que non validé) |
| 5. Hand model iOS 26 | Swap nouveau modèle Vision + re-tuning | Apple | faible | flag |
| 6. Nettoyage | Retrait tags v1/face, OSC mort, `arkit_joint_map` ; alignement AVLiveBody sur v2 ; mise à jour des CLAUDE.md périmés | robustesse | faible | — |

Point de bascule sûr : dès la fin de Phase 1, le besoin n°1 (vraie vision du
squelette dans data_only_viz) est livré, sans toucher l'iPhone en profondeur
ni risquer les gestes.

## Décisions ouvertes pour l'implémentation

- Permission « Enregistrement de l'écran » pour les captures de validation
  visuelle (N4) — à accorder ou contourner par métriques.
- Indices anatomiques ARKit exacts (poignet, avant-bras) à confirmer sur device
  en Phase N2 avant de câbler le `HandLiftSolver`.
- Re-vérifier en Phase 5 l'impact du nouveau modèle mains iOS 26 sur les noms /
  ordre de joints de la topologie.
