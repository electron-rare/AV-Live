# action-head — Classifier d'action temps réel au-dessus de Multi-HMR

> **Date** : 2026-05-13
> **Status** : design approuvé — **implémenté 2026-05-13 22:50**, 16/17 tasks, 39 tests verts. Task 16 (E2E gate) reste manuel (requiert capture + train réel).
> **Authors** : L'Electron Rare + Claude
> **Companion plans** :
> - `2026-05-13-multihmr-coreml-hybrid-backbone.md`
> - `2026-05-13-studio-train-deploy-m5.md`
>
> **Déviations notables vs design original** (cf. plan `2026-05-13-action-head.md` pour le détail) :
> - **Wiring worker** : standalone publisher thread `data_only_viz/action_head_pub.py` + 3 lignes dans `multi.py`, au lieu de modifier directement `multi_hmr_worker.py` (qui était en cours d'évolution par l'utilisateur en parallèle). Backend Multi-HMR sélectionné par env `MULTIHMR_BACKEND=pytorch|coreml`, pas par flag CLI.
> - **Source j3d** : approximée via 22 vertex anchors (`SMPLX_JOINT_ANCHOR_VERTS`) sur le mesh SMPL-X 10475-vert, partagés entre serve live (`action_head_pub.py`) et extraction offline (`scripts/extract_j3d_offline.py`) pour éviter le train/serve skew. Fallback MediaPipe 33→22 (`MEDIAPIPE_TO_22`) quand `persons_smplx` est vide. **Limitation** : ces 22 indices sont approximatifs ; pour des j3d SMPL-X corrects, brancher `J_regressor @ v3d` quand le module SMPL-X est dispo.
> - **Extract offline** : pas de refactor de `MultiHMRWorker`, on utilise `MultiHMRCoreMLBackend.infer()` directement (commit user `9e7a9f8`).
> - **Studio launch** : wrapper bash `data_only_viz/scripts/train_on_studio.sh` (Task 8.5) qui rsync + ssh + uv sync + train MPS + ckpt back. Validé end-to-end sur dataset smoke 160 windows × 3 epochs en ~4 s wallclock.

## TL;DR

Ajouter au pipeline `data_only_viz` une **tête de classification d'action** (debout/assise/danse) per-person, alimentée par les `j3d` SMPL-X de Multi-HMR. Architecture : ring buffer + GRU streaming 1-layer + MLP. Training sur Studio M3 Ultra (PyTorch MPS), inference M5 (eager PyTorch, <2 ms/person). Sortie : OSC enrichi `/pose/action` (label + softmax probas) et `/pose/kin` (vélocité, accélération, symétrie) vers `sound_algo` et `oscope-of`.

## Goals

- Classifier 3 classes (`debout`, `assise`, `danse`) per-personne, latence perçue ≤ 0.8 s.
- Sortie OSC continue exploitable musicalement (probas + kinetics scalaires, pas juste un label).
- Tête additionnelle gratuite (≤ 2 ms par person par frame M5).
- Pipeline training reproductible Studio → M5 (rsync checkpoint).

## Non-goals

- Forecasting de pose future. La "prédiction" demandée = classification d'action, pas seq2seq.
- Multi-person interactions (couple-dance, contact). Classifier indépendant per-personne.
- Action vocabulary > 3 classes au v1 (extension triviale en v2 : MLP output élargi).
- CoreML conversion du classifier (inutile, <1 ms eager).
- Deploy sur M1 (modèle trop petit pour le justifier).
- Résoudre le bottleneck backbone Multi-HMR (≥20 fps end-to-end). Le classifier est compatible avec n'importe quel backbone parmi les 4 voies de `studio-train-deploy-m5.md`.

## Decision summary

| Topic | Choix | Justification |
|---|---|---|
| Temporalité | **Train windowed (16 frames) + infer streaming (GRU 1-layer)** | Donne entrainement simple et latence zéro en prod. |
| Input | **j3d SMPL-X (22×3) seul** de Multi-HMR | Déjà produit gratuitement, plus riche que pose 2D. Apple Vision keypoints en v2 si confusion sous occlusion. |
| Source labels | **Hybride auto-label (règles) + review manuel** | Best ratio qualité/effort. Auto sur ~80 %, manuel sur ~20 % ambigus. |
| Sortie OSC | **Label + softmax probas + kinetics (speed/accel/sym)** | Continu, mappable musicalement. Vélocités sont des features pré-calculées du modèle, "rebroadcast gratuit". |
| Deploy target | **M5 only au v1** | Modèle <30 k params, M1 reservé v2 (extensions). |

## Architecture

```
camera (cv2 672x672)
        ↓
Multi-HMR hybrid worker (CoreML backbone + PyTorch head)
        ↓
[{pid, j3d (22,3), v3d, transl, score}, ...]   # per-frame, per-person
        ↓
ActionHead.step(pid, j3d) ─── per-pid ring buffer (deque maxlen=16)
        │                     per-pid GRU hidden state h_t (64-d)
        ↓
FeatureExtractor → vec(201) :
   [j3d(66) | vel(66) | accel(66) | hip_y, knee_angle, sym_score (3)]
        ↓
GRU(input=201, hidden=64) → MLP(64→32→3) → softmax → (label_idx, probs)
        ↓
+ kinetics calc (pur numpy, parallèle) : speed, accel_mag, symmetry
        ↓
pose_bridge.py → OSC :
   /pose/action <pid> <label_idx> <p_debout> <p_assise> <p_danse>
   /pose/kin    <pid> <speed> <accel> <symmetry>
        ↓
sound_algo :57121  +  oscope-of :57123
```

## Composants

| Module | Fichier | Rôle | Taille |
|---|---|---|---|
| `ActionHead` | `data_only_viz/action_head.py` | GRU 1-layer + MLP, streaming step(). Charge checkpoint `.pt`. | ~200 LOC, ~30 k params, <200 KB ckpt |
| `PerPersonBuffer` | dans `action_head.py` | `{pid → deque(maxlen=16)}` + lifecycle (purge via tracker hooks). | ~50 LOC |
| `FeatureExtractor` | dans `action_head.py` | Calcule j3d/vel/accel/hip-y/knee-angle/symmetry → 201D. | ~100 LOC, pur numpy |
| OSC sender | extension `pose_bridge.py` | 2 nouvelles addresses `/pose/action`, `/pose/kin`. | ~30 LOC |
| Capture | `data_only_viz/scripts/capture_actions.py` | Webcam → MP4 + timestamps. | ~100 LOC |
| Extract j3d offline | `data_only_viz/scripts/extract_j3d_offline.py` | Run Multi-HMR PyTorch full sur MP4 → jsonl. | ~150 LOC |
| Auto-labeler | `data_only_viz/training/autolabel.py` | Règles heuristiques j3d → labels. | ~150 LOC |
| Review TUI | `data_only_viz/training/review.py` | Console TUI pour corriger les ambigus. | ~200 LOC |
| Split | `data_only_viz/training/split.py` | 70/15/15 par session (anti-leakage). | ~50 LOC |
| Training | `data_only_viz/training/train_action_head.py` | PyTorch MPS Studio, 50 epochs AdamW. | ~250 LOC |
| Eval | `data_only_viz/training/eval.py` | Confusion matrix + latency micro-bench. | ~100 LOC |

## Interfaces

```python
# action_head.py
class ActionHead:
    def __init__(self, ckpt_path: Path | None = None,
                 device: str = "cpu") -> None: ...
    def step(self, pid: int, j3d: np.ndarray) -> tuple[str, np.ndarray, np.ndarray]:
        """
        j3d : (22, 3) float32
        returns (label, probs (3,), kin (3,)) ; label ∈ {"debout","assise","danse"}
        """
    def forget(self, pid: int) -> None: ...
```

**Note d'implémentation 2026-05-13** : la section ci-dessous décrit l'intention originale. L'implémentation réelle est dans `data_only_viz/action_head_pub.py` (publisher thread) — pas de modification de `multi_hmr_worker.py`. Voir l'en-tête du document pour les déviations.

Aucune modification de l'API publique de `multi_hmr_worker.py` n'est requise au-delà de :
- Construction d'une `ActionHead` au startup.
- Appel `.step()` après chaque détection.
- Appel `.forget()` synchronisé avec `tracker.purge()`.
- Extension `pose_bridge.send_pose_action()` et `.send_pose_kin()`.

## Data flow per frame

```
1. Camera 30 fps → Multi-HMR hybrid forward (∼130 ms M5)
2. persons = [{pid, j3d, ...}, ...]
3. Pour chaque person :
   a. buffers[pid].append(j3d)                  # O(1)
   b. si len(buffers[pid]) < 3 :
        send "/pose/action <pid> debout 1.0 0.0 0.0"
        send "/pose/kin <pid> 0 0 0"
        continue
   c. feat = FeatureExtractor.from_buffer(buffers[pid])
   d. h[pid], logits = gru(feat, h[pid])         # <0.5 ms M5
   e. probs = softmax(logits)
   f. label_idx = argmax(probs)
   g. kin = compute_kinetics(buffers[pid])
4. tracker.purge() → pour chaque pid retiré : ActionHead.forget(pid)
5. pose_bridge envoie en batch les 2 messages par person
```

**Coût additionnel sur le worker** : ≤ 2 ms M5 pour 5 personnes (mesure cible). Le budget hybrid Multi-HMR est ∼130 ms, donc le total reste à ~132 ms = **7.6 fps end-to-end**.

**Atteindre >20 fps end-to-end** nécessite de basculer sur la Voie 1 (distillation student) ou Voie 3 (SMPLer-X) du plan studio-train-deploy-m5. `action_head` est compatible avec n'importe lequel.

## Schéma OSC

```
/pose/action <pid:int32> <label_idx:int32> <p_debout:f32> <p_assise:f32> <p_danse:f32>
   label_idx : 0=debout, 1=assise, 2=danse
   p_*       : softmax (somme=1.0)

/pose/kin <pid:int32> <speed:f32> <accel:f32> <symmetry:f32>
   speed     : m/s, mean ‖vel‖ sur 22 joints (typique 0.0 debout → 0.8+ danse rapide)
   accel    : m/s², proxy explosivité
   symmetry  : -1..1, cos similarity gauche/droite des bras

/pose/enter <pid:int32>     # tracker, nouvelle personne
/pose/leave <pid:int32>     # tracker, purge buffer + hidden state
```

Réception côté `sound_algo` : 2 nouveaux `OSCdef` (`\poseAction`, `\poseKin`) dans `engine.scd` ou `live/`. Mapping artistique exemple :

```supercollider
~mapPoseToFx = {
    var avgDance = ~poseState.values.collect(_.probs[2]).mean ? 0;
    var avgSpeed = ~poseKin.values.collect(_.speed).mean ? 0;
    ~fxDrive.(avgDance * avgSpeed * 0.8);
    ~fxComp.(1 - avgDance);
};
```

## Pipeline training (Studio → M5)

```
1. CAPTURE (M5) — scripts/capture_actions.py
     3 sessions × 10-20 min webcam, mix toi + amis.
     Variétés : debout-immobile, assise-chaise, assise-sol,
     danse-lente, danse-rapide, transitions.
     Stocké hors git : ~/.cache/av-live-action/raw/*.mp4

2. EXTRACT j3d (M5 ou Studio) — Multi-HMR PyTorch full (qualité max)
     → jsonl 1 ligne/frame : {ts, pid, j3d (22,3), transl}

3. AUTO-LABEL (M5) — training/autolabel.py
     Règles (configurables) :
       hip_y > seuil ET knee_angle < 110°       → \assise
       hip_y debout ET speed < 0.05             → \debout
       speed > 0.3 OU accel > 1.0               → \danse
       sinon                                    → NONE (curation manuelle)

4. REVIEW (M5, ~½ jour pour ~3000 fenêtres) — training/review.py
     TUI textual : skeleton ASCII + graphe vélocité + label proposé.
     Touches 1/2/3 = corriger, ENTRÉE = valider, S = skip.
     Cible : valider 100 % des NONE + 20 % aléatoire des autres.

5. SPLIT — training/split.py
     Split par SESSION (pas par fenêtre) → évite leakage temporel.
     70 % train / 15 % val / 15 % test.

6. RSYNC vers Studio
     rsync ~/.cache/av-live-action/dataset/ studio:~/av-live-action/dataset/

7. TRAIN (Studio MPS, 30-60 min wallclock) — training/train_action_head.py
     PyTorch MPS, batch=128, lr=1e-3 AdamW, 50 epochs, early stop val acc.
     Loss = CE weighted (anti-imbalance).
     Augmentations online :
       - mirror gauche/droite (swap joints + flip x)
       - noise gaussien σ=0.01 m
       - time-stretch 0.9-1.1× sur fenêtre
       - rotation Y ±15° camera-relative
     Save best on val : ~/av-live-action/ckpt/action_head.pt

8. EVAL (Studio) — training/eval.py
     Confusion 3×3 + latency micro-bench.
     Pass : test acc ≥ 85 % ET confusion debout↔danse ≤ 5 %.

9. EXPORT M5
     rsync studio:~/av-live-action/ckpt/action_head.pt \
           ~/.cache/av-live-action/checkpoints/
```

## Dataset spec

| Classe | Cible windows | Notes |
|---|---|---|
| `debout` | 1 200 | inclut "debout-immobile" et "petits gestes mains" |
| `assise` | 800 | chaise + sol |
| `danse` | 1 500 | mix lent/rapide/symétrique/asymétrique |
| **Total** | **~3 500 fenêtres de 16 frames** | ~30 min vidéo source après dédup overlap |

Sliding 16-frame avec stride 4 (overlap 75 %) sur la vidéo → multiplie dataset effectif. Augmentations training multiplient encore par ~8×.

Format `dataset.jsonl` (1 ligne par window) :

```json
{"window_id": "sess03_pid1_w0042",
 "label": "danse",
 "j3d": [[[...22×3 floats...] × 16 frames]],
 "session": "sess03",
 "pid_local": 1,
 "auto_label_confidence": 0.78,
 "manually_validated": true}
```

## Error handling

| Scénario | Comportement |
|---|---|
| Buffer per-pid < 3 frames (warmup) | Emit `/pose/action <pid> debout 1.0 0.0 0.0` + `/pose/kin <pid> 0 0 0`, pas d'inférence GRU. |
| Multi-HMR drop une frame | Buffer figé, pas de fake append. Gap > 1 s → forget(pid) + warm restart. |
| Checkpoint absent au startup | Fallback `autolabel.py` rule-based. Worker ne se tait jamais. |
| NaN dans j3d (occlusion) | Skip step, garde buffer/hidden inchangés. >5 skips consécutifs → forget(pid). |
| pid disparaît du tracker | `ActionHead.forget(pid)` synchronisé. Pas de leak. |
| torch.compile crash MPS | Fallback eager (déjà <1 ms, pas critique). |

## Tests

```
tests/test_action_head.py
  test_feature_extractor_shapes()        # 201-dim feature
  test_buffer_warmup_emits_default()
  test_gru_step_latency()                # <2 ms M5 (perf gate)
  test_forget_releases_memory()
  test_nan_j3d_skip()
  test_synthetic_dance_classified()      # j3d sin(t) → danse argmax
  test_synthetic_static_classified()     # j3d constants → debout

tests/test_autolabel.py
  test_seated_rule_hip_low_knee_bent()
  test_dance_rule_speed_threshold()
  test_ambiguous_marked_NONE()

tests/test_training_smoke.py
  test_train_step_no_crash()             # 2 epochs smoke
  test_dataset_jsonl_roundtrip()
  test_augmentations_preserve_label()

tests/test_pose_bridge_osc.py
  test_action_message_format()           # 5 args, types
  test_kin_message_format()              # 4 args, types
```

E2E manuel (1× post-train) : run live worker + `nc -u -l 57121`, test "je m'assois" change label en <1 s.

## Success criteria

| Métrique | Cible v1 | Stretch |
|---|---|---|
| Test acc 3 classes | ≥ 85 % | ≥ 92 % |
| Confusion debout↔danse | ≤ 5 % | ≤ 2 % |
| Latence ActionHead.step() M5 | ≤ 2 ms/person | ≤ 1 ms |
| Overhead worker hybrid (5 personnes) | ≤ 10 ms additionnel | ≤ 5 ms |
| RAM additionnelle vs baseline | ≤ 100 MB | ≤ 50 MB |
| Latence label change perçue (live) | ≤ 0.8 s | ≤ 0.4 s |
| Stabilité label sur action constante 10 s | ≥ 9.5 s bonne classe | 10/10 |

## Abandon criteria

- Test acc < 75 % même après augmentations + review étendu → architecture trop simple, refonte (tiny temporal transformer 2 layers).
- Confusion debout↔danse > 15 % → j3d seul insuffisant ; pivot v2 avec Apple Vision keypoints concat.
- Latence per-frame > 5 ms M5 → bug, modèle trop petit pour ça.
- Dataset après review < 1 500 windows → effort capture insuffisant, recommencer.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Auto-labeler génère labels biaisés (le classifier apprend les règles, pas la danse) | High | Medium | Review manuel ≥ 20 % validés aléatoirement + 100 % NONE. |
| Dataset trop petit pour 50 epochs sans overfit | Medium | Medium | Augmentations × 8 effectif + early stop val acc. |
| j3d Multi-HMR jitter sous occlusion → classifier flicker | Medium | Medium | One Euro Filter `euro_filter.py` déjà en upstream ; smoothing softmax côté OSC en lissage temporel léger. |
| Hidden state GRU diverge sur action très longue | Low | Low | Reset h_t toutes les 60 s par pid en fallback (idempotent). |
| Latence label change > 0.8 s perçue | Low | Medium | Réduire window à 12 frames si besoin (peu impact acc). |

## Hors scope v1

- Forecasting pose future
- Multi-person interactions (couple-dance)
- Apple Vision keypoints concat (v2)
- Action vocabulary > 3 classes
- CoreML conversion du classifier
- Deploy sur M1

## Estimated total effort

- Capture + extract + auto-label + review : ~1.5 jour M5
- Training + eval Studio : ~½ jour wallclock (30-60 min compute)
- ActionHead + tests + intégration worker : ~1.5 jour M5
- E2E + tuning OSC mapping sound_algo : ~½ jour

**Total : ~4 jours focused work** (hors capture amis qui peut s'étaler).
