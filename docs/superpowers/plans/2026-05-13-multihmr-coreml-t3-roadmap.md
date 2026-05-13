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

## Blocker actif

```
ValueError: Length of the reps (0) must be at least 1, and equal to
the rank of the input x (1)
```

Localisation : `tensor_operation.py:677` `tile` op type_inference.
Source torch op probable : `.repeat()` ou `.expand()` avec arg
constant qui devient empty.

**Investigation à faire** :

- [ ] **Step A1 — Localiser le node torch problématique**

  Patcher `convert_single_node` pour print node.kind() + node.name()
  juste avant l'erreur. Identifier la torch op exacte (aten::repeat,
  aten::expand, etc) et son contexte.

- [ ] **Step A2 — Tracer arrière au code source**

  Une fois le node identifié, retrouver la ligne dans Multi-HMR
  (model.py, blocks/, utils/) qui produit ce repeat/expand. Probables
  candidats :
  - `model.py:178` : `points.reshape(1, -1, 2).repeat(bs, 1, 1)`
  - `model.py:447` : `.repeat(self.nrot, 1, 1)`
  - `model.py:540` : `x.expand(bs, num_ppl, -1)`
  - `blocks/smpl_layer.py:88-101` : multiple `.repeat(bs, 1)`

- [ ] **Step A3 — Patch ciblé**

  Soit :
  - Réécrire l'op avec un broadcast explicite plutôt que repeat
  - Soit patcher `tile` type_inference pour accepter `reps=[]` (no-op)
  - Soit pré-compute le tensor répété en buffer module-level (comme
    pos_embed)

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
