# CoreML Task 3 cascade — roadmap détaillée pour reprise

> Sous-plan dérivé de `2026-05-13-multihmr-coreml-conversion.md`.
> Documente l'état exact de la cascade de patches Task 3 pour reprise
> en session dédiée multi-jour.
>
> **REQUIRED SUB-SKILL** : `superpowers:executing-plans`.

## Contexte

Tentative full Multi-HMR → CoreML mlprogram a fait apparaître une
cascade d'op-level issues. Chaque patch unlocking le suivant. Session
du 2026-05-13 a atteint **5 patches cumulés** avec une 6e couche
identifiée.

Le fix vrai est probablement 8-15 patches au total, ~1-2 jours focused.

## Patches déjà appliqués (script `data_only_viz/scripts/coreml_full_probe.py`)

| # | Patch | Cible | Status |
|---|---|---|---|
| 1 | `apply_threshold` → `apply_topk(K=4)` | `model.py` module-level monkey-patch | ✅ done |
| 2 | `backbone.encoder.interpolate_pos_encoding` → buffer fige | dynamic interpolation supprimee | ✅ done |
| 3 | `utils.camera.inverse_perspective_projection` → closed-form K_inv | bypass `torch.inverse(K)` | ✅ done |
| 4 | `coremltools.ops._cast` patch | val non-0d → `.item()` ou fallback `mb.cast` | ✅ done |
| 5 | `Operation._auto_val` patch | coerce ndarray 1-d size-1 → 0-d | ✅ done |
| 6 | `tile` op type_inference no-op si reps=[] | torch.repeat/expand avec arg vide | ✅ done |
| 7 | `aten::new_ones` converter | manquait, ajoute via _maybe_register | ✅ done |
| 8 | `concat` type_inference auto-promote 0d → 1d | mix de scalars et 1d tensors | ✅ done |
| 9 | `clamp_min` / `clamp_max` override avec promote_input_dtypes | assert dtype original sans promotion | ✅ done |
| 10 | `diagonal` general (offset=0 dim1=1 dim2=2 sur rank-3) | roma.rotmat_to_rotvec utilise .diagonal | ✅ done |

## Blocker actif (post-10-patches)

```
ValueError: Invalid target shape in `reshape` op ([1, 51, 3] to [204, 3, 1]).
```

**Pas une op manquante** — c'est une **incohérence model-side**.
Le facteur **204/51 = 4** = `K=num_persons` post-topk. Quelque chose
dans la forward attend N variable et est sized incorrectement quand
N=4 fixe via topk.

Tracage à faire :
- Identifier quel module produit ce reshape (le name de l'op peut
  pointer vers la couche)
- Examiner ce qui passe de (1, 51, 3) à (4*51, 3, 1) — probable
  broadcast cross-attention sur K detected persons

**Investigation à faire** :

- [ ] **Step B1 — Identifier le module source**

  Logger node.name() avant reshape failure. Probablement quelque part
  dans `HPH` (cross-attention head) ou `x_attention_head` cf
  `model.py:281`.

- [ ] **Step B2 — Comprendre la shape attendue**

  Lire le code à l'endroit identifié. Comprendre si :
  - C'est un broadcast `(1, N, D) → (K, N, D)` qui devrait se faire
    via `expand` mais le JIT a traduit en reshape
  - Ou c'est une incompatibilité torch.cat / advanced indexing avec
    K=4 idx vs N=51 features

- [ ] **Step B3 — Patcher au niveau source**

  Soit (a) reformuler le forward via `.expand()` explicite, soit (b)
  remplacer par advanced indexing avec K=4 explicite, soit (c)
  wrapper le sub-module et pre-compute.

## Cascade probable restante (estimée)

Basée sur les patterns vus dans coremltools issues GitHub et la
complexité de Multi-HMR :

| # | Type d'op probable | Estimation effort |
|---|---|---|
| 6 | `tile/repeat` empty reps (actif) | 30 min |
| 7 | `aten::scatter` ou `index_put` non implémenté | 1-2 h |
| 8 | dynamic shape sur sortie head (transl decoder) | 1-2 h |
| 9 | `roma.rotmat_to_rotvec` (lib externe avec ops obscures) | 1 h |
| 10 | SMPL-X layer dans `blocks/smpl_layer.py` (matmul + slicing) | 1-2 h |
| 11+ | inconnues résiduelles | 2-4 h |

**Total estimé** : 6-12 heures focused = **1-2 jours session dédiée**.

## Workflow recommandé

```
boucle :
  1. run probe → capture erreur
  2. localiser dans coremltools/torch
  3. trouver le code source PyTorch responsable
  4. patcher (monkey-patch, buffer, ou wrapper)
  5. relancer → étape 1 ou converge
```

À chaque convergence partielle :
- Commit le patch (1 fichier `scripts/coreml_full_probe.py` evolue)
- Mettre à jour cette roadmap avec patch #N done

## Validation finale (quand cascade terminée)

- [ ] **Convert OK** → `.mlpackage` produit, < 200 MB
- [ ] **Bench M5** :
  - `compute_units=CPU_AND_GPU` : cible ≤ 80 ms (≥ 12 fps)
  - `compute_units=ALL` : vérifier si ANE aide ou pas (probable pas)
- [ ] **Numerical equivalence** : v3d sur 5 frames test vs PyTorch,
      cosine ≥ 0.999 par frame
- [ ] **Integration** : worker `multi_hmr_worker_coreml.py`, flag CLI

## Décision : faut-il s'engager ?

**Pour** :
- Speedup attendu **10×+** (probe v4 confirmé pour backbone seul)
- Bouge le bottleneck du runtime au build (compile une fois, run vite)
- Pas de degradation qualité (cosine 1.0 sur head topk validé)

**Contre** :
- 1-2 jours wallclock, possibles surprises
- Le hybrid backbone-only (plan séparé) peut donner 2-3× sans cette
  cascade
- coremltools 9.0 + torch 2.12 est une combo récente, beaucoup de
  edge cases pas encore couverts par les mainteneurs

**Recommandation** : tenter le **hybrid backbone-only** d'abord (½ j).
Si gain insuffisant, alors engager les 1-2 jours pour T3 complet.
