# Modern body mesh recovery — survey & evaluation roadmap

> Survey des modèles publiés mai 2025 → mai 2026, et roadmap
> d'évaluation pour identifier un remplacement éventuel à Multi-HMR
> ViT-S sur AV-Live.

## Deployment constraint (2026-05-13)

**Cible** : M5 16 GB total, **inference < 8 GB RAM** utilisée. Pas
d'offload réseau. Studio M3 Ultra utilisable uniquement pour
**entraînement / distillation / conversion**, jamais en runtime.

Cette contrainte filtre brutalement le survey ci-dessous : tout
modèle dont l'empreinte runtime dépasse ~6 GB (laisse 2 GB pour OS
+ Swift app + camera) est éliminé.

## Survey 2025-2026

Recherche faite 2026-05-13 (GitHub topics + paperswithcode redirect HF).

| Modèle | Date | Backbone | Params | RAM estim | M5<8GB | Output | Speed claim | Statut |
|---|---|---|---|---|---|---|---|---|
| **Multi-HMR ViT-S** | Mar 2026 | DINOv2-S | 31.5M | ~600 MB | ✅ | SMPL-X | 228 ms M5 mesuré | **baseline** |
| **SMPLer-X-S** | scaffold | ViT-S | ~30M | ~500 MB | ✅ | SMPL-X | 64 ms M5 (claim) | **candidat #1** |
| **Fast-SAM-3D-Body** | Apr 2026 | DINOv3+SAM3 | ~600M | ~3-4 GB | ⚠️ tight | SMPL | 65 ms RTX5090 | candidat #2 si tient |
| **HSMR** (CVPR25) | Mar 2026 | n/a | n/a | n/a | n/a | squelette | "slow" | off-target |
| **SAM 3D Body** (Meta) | 2025 | SAM 3 | ~1B | ~6-8 GB | ❌ | SMPL | 650 ms RTX5090 | trop gros + lent |
| **NLF** (NeurIPS24) | Mai 2025 | TorchScript | n/a | n/a | ❌ MPS bug | SMPL | n/a | déjà testé, KO |
| **BLADE** (NVlabs) | Nov 2025 | inconnu | n/a | n/a | n/a | mesh proche | n/a | niche |
| **EgoHMR / RoHM / sam-body4d / PersPose** | divers | divers | n/a | n/a | n/a | off-target | n/a | écartés (egocentric / motion / video / low adoption) |

## Lecture

Avec la contrainte M5 <8 GB RAM :

- **SMPLer-X-S est le candidat #1 sur M5** : taille comparable à
  Multi-HMR ViT-S, claim 64 ms M5 (= 15 fps potentiel), même output
  SMPL-X que Multi-HMR (compat directe avec SMPLXTCPSender + SMPLX
  faces.bin Swift existant), scaffold déjà écrit dans
  `data_only_viz/smpler_x_scaffold.md`.
- **Fast-SAM-3D-Body** : ~3-4 GB RAM (DINOv3 + composantes SAM 3) =
  borderline 8 GB sur M5. À bencher en footprint réel avant
  d'investir le port.
- **SAM 3D Body** original : trop gros (~6-8 GB) + trop lent.
- **NLF** : bloqué MPS (CUDA-hardcode `aten::empty_strided`).
- **Off-target** : HSMR (squelette), EgoHMR (egocentric), RoHM,
  sam-body4d (video), PersPose, BLADE.

## Roadmap d'évaluation (priorisée pour contrainte M5)

### Eval 0 : SMPLer-X-S port (PRIORITÉ HAUTE)

**Pourquoi en premier** : scaffold déjà écrit, claim 64 ms M5
(potentiel 15 fps natif), même output SMPL-X (zero changement
AVLiveBody Swift), licence MIT.

**Coût** : 2-3 jours. **Gain attendu** : **4× speedup** (228 → 64 ms),
on-device, pas de Studio nécessaire.

- [ ] **T0.1 — Setup** : `bash data_only_viz/scripts/setup_smpler_x.sh`
  (à écrire) qui clone le repo + download checkpoint S.
- [ ] **T0.2 — Headless bench** : 20 iter sur dummy 256² (SMPLer-X
  utilise 256 par défaut). Gate ≤ 100 ms sinon recheck claim.
- [ ] **T0.3 — Camera bench** : analogue
  `/tmp/bench_multihmr_camera.py`. Gate persons/frame ≥ 2 avec 3 sujets.
- [ ] **T0.4 — RAM footprint** : `psutil` ou `top -pid $$` pendant le
  bench. Gate ≤ 4 GB worker.
- [ ] **T0.5 — Port worker** : `data_only_viz/smpler_x_worker.py`
  miroir de `multi_hmr_worker.py`. Reuse dédup, tracker, smplx_tcp.
- [ ] **T0.6 — A/B vs Multi-HMR ViT-S sur même séquence enregistrée**.
  Compare fps, qualité (vertice cosine sim), pids.

### Eval 1 : Fast-SAM-3D-Body sur Studio (fallback)

**Coût** : 1-2 jours. **Gain potentiel** : si tient ~80-150 ms M3
Ultra → 8-12 fps natif vs ~228 ms M5 local. Combiné avec offload
(plan `2026-05-13-studio-offload.md`) → 8-12 fps end-to-end.

**Tasks** :

- [ ] **T1.1 — Setup Fast-SAM-3D-Body sur Studio**

  ```bash
  ssh studio 'cd ~/Documents/Projets && git clone \
    https://github.com/yangtiming/Fast-SAM-3D-Body.git && \
    cd Fast-SAM-3D-Body && bash setup_env.sh'
  ```

  Auto-download du checkpoint depuis HF au premier run.

- [ ] **T1.2 — Bench raw inference Studio M3 Ultra**

  Adapter le demo script à 1 frame fixe (image test 672²). Time
  20 iter sur MPS. **Gate** : ≤ 150 ms médiane sinon abandon.

- [ ] **T1.3 — Bench multi-person quality vs Multi-HMR**

  Image test avec 3 personnes (récupérer une frame de la session
  AV-Live). Compare nombre détecté + plausibilité visuelle des
  vertices.

- [ ] **T1.4 — Si gate passe : port API**

  Adapter `multihmr_server.py` (du plan studio-offload) pour exposer
  un endpoint `/infer-sam3d` parallèle. Garder Multi-HMR aussi : le
  client M5 choisit via `--remote-model`.

### Eval 2 : SAM 3D Body raw (Meta, baseline avant Fast-SAM)

**Coût** : ½ jour si on a Fast-SAM déjà setup. **Utilité** : valider
que Fast-SAM-3D-Body donne vraiment 10× sur RTX5090 ; vérifier que
le ratio reste cohérent sur M3 Ultra MPS.

- [ ] **T2.1 — Bench SAM 3D Body sur Studio**
- [ ] **T2.2 — Comparer ratio Fast/Slow sur MPS vs CUDA claim**

### Eval 3 : SMPL → SMPL-X conversion (si Fast-SAM gagne mais SMPL only)

Si Fast-SAM-3D-Body marche bien mais ne retourne que SMPL (pas
SMPL-X), regarder s'il est utile/possible de convertir SMPL → SMPL-X
post-hoc (zero hands/face = baseline acceptable pour body-only AV-Live).

- [ ] **T3.1 — Vérifier si AVLiveBody Swift accepte SMPL (6890 verts)
      au lieu de SMPL-X (10475 verts)** : probable refactor de
      `smplx_faces.bin` topology + Swift LowLevelMesh capacity.
- [ ] **T3.2 — Compatibilité décision** : si SMPL OK → adopter ;
      sinon, garder Multi-HMR.

## Abandon criteria

- T1.2 (Fast-SAM-3D-Body bench Studio) > 150 ms → abandon plan, rester
  sur Multi-HMR.
- T1.3 (multi-person qual) qualité dégradée vs Multi-HMR → abandon.
- License Fast-SAM-3D-Body (MIT) confirmée + datasets entraînement
  compatibles AV-Live commercial use — déjà OK car MIT.

## Anti-pistes (post-survey)

- **Train un modèle from scratch** : rejeté. Multi-semaines, datasets
  non disponibles immédiatement, risque produit.
- **Fine-tune Multi-HMR à 448²** : rejeté pour l'instant. Compute
  backbone scale ∝ tokens² donne ~2× speedup théorique mais code
  changes Multi-HMR (img_size hardcodé), retraining datasets, et le
  bottleneck SMPL-X head reste indépendant de l'input size.
- **Distillation ViT-L → student** : multi-semaines, hors scope
  perf-tuning court terme.
