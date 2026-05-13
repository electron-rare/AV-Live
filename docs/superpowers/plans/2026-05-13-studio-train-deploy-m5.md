# Studio M3 Ultra comme rig d'entraînement, déploiement M5

> **Contrainte** : runtime sur M5 16 GB, **< 8 GB RAM utilisée** pour
> l'inférence body mesh. Studio M3 Ultra (512 GB, 80 cores GPU) sert
> uniquement à **entraîner, fine-tuner ou distiller**. Le checkpoint
> final est exporté et déployé sur M5.

## Pourquoi Studio pour le training ?

- 80 cores GPU + 512 GB RAM → batch sizes confortables, MLX ou
  PyTorch MPS sans contrainte mémoire.
- Pas de throttle thermique (refroidissement actif).
- Tailscale `100.116.92.12` accessible depuis grosmac M5 (clone repo,
  ssh, rsync checkpoints).
- Déjà utilisé pour 11 LoRA mascarade Qwen3-4B (cf CLAUDE.md home).

## Voies envisagées

### Voie 1 — Distillation Multi-HMR ViT-L → student léger

**Idée** : Multi-HMR ViT-L (304 MB checkpoint, ~317M params) sur
Studio comme **teacher**. Entraîner un student **<10M params**
(genre MobileViT-S ou ResNet50-light + tête SMPL-X) sur les v3d
produits par le teacher, sur un dataset d'images génériques (COCO,
BEDLAM si dispo, OpenImages).

**Coût** : 2-4 semaines (data prep + training).

**Risque** : qualité student typiquement 70-85% du teacher. Pour
AV-Live (artistique) c'est probablement OK ; pour mocap précis non.

### Voie 2 — Fine-tune Multi-HMR à résolution réduite (448 ou 384)

**Idée** : prendre Multi-HMR ViT-S, modifier `img_size=448`,
fine-tuner sur datasets originaux (BEDLAM, AGORA, UBody) sur Studio.

**Compute backbone** ∝ tokens² = (img_size/patch_size)². Passage
672 → 448 = (448/672)² = **44 % du compute backbone**. Le head SMPL-X
reste identique (taille fixe).

**Coût** : 1-2 semaines (dataset accès + training).

**Risque** : qualité dégradée sur petits sujets (loin de la caméra).
Tolérable si AV-Live tourne en setup contrôlé.

### Voie 3 — SMPLer-X-S adoption directe (pas de training)

**Idée** : porter SMPLer-X-S tel quel (claims 64 ms M5). Pas
d'entraînement nécessaire. Studio sert juste à valider sur datasets
si on veut benchmarker.

**Coût** : 2-3 jours port. Couvert dans
`2026-05-13-modern-body-mesh-survey.md` Eval 0.

**Risque** : faible (modèle publié et benché par les auteurs).

### Voie 4 — Apple Vision + petit head SMPL-X custom

**Idée** : utiliser Apple Vision pose 2D (ANE, ~5 ms claim) pour
détection + keypoints. Entraîner un petit transformer/MLP
keypoints-2D → SMPL-X params sur Studio. Inference M5 :
Vision (5 ms ANE) + head (estimé 10-20 ms MPS) = ~25 ms = 40 fps.

**Coût** : 2-3 semaines (dataset paired keypoints↔SMPL-X + training).

**Risque** : Apple Vision pose est 17 keypoints body, pas mains/visage.
Reconstruction SMPL-X depuis 17 keypoints sera moins précise que
depuis image directe.

## Recommandation par ordre

1. **D'abord Voie 3** (SMPLer-X-S adoption) — pas de training, gain
   immédiat si claim 64 ms M5 tient. Va dans le survey plan, **prio
   haute**.

2. Si SMPLer-X-S ne tient pas : **Voie 4** (Apple Vision + head
   custom) — ANE-friendly, ~25 ms cible, mais demande training
   custom.

3. Si Voie 4 trop fragile : **Voie 1** (distillation) — vrai effort
   research mais résultat sous contrôle.

4. **Voie 2** (fine-tune res réduite) à éviter : ROI faible, datasets
   compliqués.

## Tasks Voie 1 (distillation) si on s'engage

- [ ] **Setup Studio** : clone Multi-HMR repo, env PyTorch + MPS,
  vérifier load checkpoint ViT-L. (½ jour)
- [ ] **Dataset prep** : 100k-500k images (COCO + BEDLAM extracts +
  webcam captures AV-Live anonymisées). Pas de label requis ; on
  utilise le teacher pour pseudo-label. (1 semaine)
- [ ] **Architecture student** : MobileViT-S ou ResNet-S backbone +
  Multi-HMR head (réutilisable directement). Target ≤ 10M params.
  (½ jour)
- [ ] **Loss** : L2 sur v3d teacher↔student, + L1 sur shape/expr.
  (½ jour)
- [ ] **Training** : batch 16-32, AdamW, 50-200 epochs MPS Studio.
  (1-2 semaines wallclock)
- [ ] **Eval** : compare v3d sur AGORA val (PVE-3DPW) et qualité
  visuelle. (½ jour)
- [ ] **Export checkpoint** : rsync vers M5
  `~/.cache/av-live-multihmr/checkpoints/distilled_S.pt`.
- [ ] **Port worker** : new `data_only_viz/distilled_worker.py`,
  similar à `multi_hmr_worker.py` mais charge le student. (½ jour)
- [ ] **Bench M5** : analogue benches précédents. Target ≤ 100 ms
  (10 fps) avec < 4 GB RAM.

## Abandon criteria

- Distillation : si PVE-3DPW student > 1.5× teacher → abandon (qualité
  inacceptable).
- Voie 2 : abandon par défaut (déjà classée low-ROI).
- Voie 4 : si head custom ne reconstruit pas le mesh plausiblement
  depuis 17 keypoints en eval offline → abandon.

## Tooling

- **MLX-train possible** : Apple's MLX a un mode training fonctionnel
  sur Studio. Avantage : déploiement final M5 en MLX direct.
  Inconvénient : moins de tooling/exemples que PyTorch pour body mesh.
- **PyTorch MPS train** : éprouvé, plus de tooling, conversion finale
  vers MLX/CoreML pour M5 deploy = effort additionnel.
- Pour ce plan, recommandation initiale : **PyTorch MPS sur Studio
  pour train**, export en checkpoint .pt simple, run direct sur M5
  MPS pour l'inférence (Voie 1).
