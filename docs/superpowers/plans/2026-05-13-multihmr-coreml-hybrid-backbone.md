# Multi-HMR hybrid : CoreML backbone + PyTorch head

> Approche pragmatique pour livrer le speedup CoreML en prod **sans
> attendre Task 3 de `2026-05-13-multihmr-coreml-conversion.md`** (qui
> est un projet multi-jour de cascade de patches).
>
> **REQUIRED SUB-SKILL** : `superpowers:executing-plans` ou
> `superpowers:subagent-driven-development`.

**Goal:** intercepter `model.backbone(x)` dans le pipeline Multi-HMR
existant et router vers un `.mlpackage` CoreML (DINOv2 ViT-S 672).
Le reste de la forward (head, SMPL-X decoder, regression nets) reste
en PyTorch MPS. Capture **30-50 %** du speedup CoreML sans toucher au
head.

**Non-goals :**
- Convertir le head (cf plan T3 standalone).
- Modifier l'API du worker (intégration drop-in via flag CLI).
- Toucher AVLiveBody Swift (zéro changement).

**Architecture cible :**

```
camera (cv2 672x672)
    |
    v
Multi-HMR.forward(x)   ← un seul appel public
    |
    +-- backbone(x)        → INTERCEPTÉ → CoreML predict → patch tokens
    |   (1, 3, 672, 672)                                  (1, 2304, 384)
    |
    +-- detection + head + regression    [PyTorch MPS unchanged]
    |
    v
SMPL-X v3d + transl + scores + shape + expr  [list of dicts inchangé]
```

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Output CoreML ≠ output PyTorch (numerical drift) | medium | high | cosine sim ≥ 0.999 check Task 1 Step 4 |
| Round-trip MPS↔CoreML (CPU) costs > backbone savings | medium | high | bench Task 2 ; si net négatif, abandon |
| CoreML inference n'accepte que numpy ndarray, pas torch tensor | high | low | conversion explicite tensor↔numpy |
| Le probe v4 .mlpackage retourne cls_token, pas patch tokens — il faut RE-CONVERTIR | high | medium | Task 1 le résout |
| Memory M5 < 8 GB avec backbone CoreML + PyTorch head loaded | low | medium | bench memory peak ; .mlpackage = ~84 MB sur disque |

## Tasks

### Task 1 — Re-convertir DINOv2 wrapper qui retourne patch tokens (½ h)

Le `.mlpackage` actuel (probe v4) appelle `DINOv2.__call__` qui renvoie
le cls_token (shape `(1, 384)`). Multi-HMR utilise
`get_intermediate_layers(x)[0]` qui renvoie les patch tokens
`(1, 2304, 384)`. Donc on doit produire un .mlpackage différent.

- [ ] **Step 1.1 — Wrapper avec get_intermediate_layers**

  ```python
  class DinoIntermediateWrapper(nn.Module):
      def __init__(self, dinov2_model):
          super().__init__()
          self.m = dinov2_model
      def forward(self, x):
          return self.m.get_intermediate_layers(x)[0]  # (1, 2304, 384)
  ```

  Appliquer le pos_embed fix (probe v4) + _cast patch coremltools.
  Trace + convert. Save à
  `~/.cache/av-live-multihmr/checkpoints/dinov2_vits14_672_intermediate.mlpackage`.

- [ ] **Step 1.2 — Bench standalone**

  Comparer PyTorch MPS `model.backbone(x)` vs CoreML wrapper. Attendu :
  speedup similaire au probe v4 (~10×).

- [ ] **Step 1.3 — Numerical equivalence**

  Sur une image example_data, comparer torch output vs CoreML output.
  Cosine sim sur la sortie aplatie ≥ 0.999. Si moins : drift, abandon
  ou investigation precision fp16/fp32.

### Task 2 — Hybrid worker `multi_hmr_worker_coreml.py` (1 h)

- [ ] **Step 2.1 — Fork du worker**

  Copier `multi_hmr_worker.py` → `multi_hmr_worker_coreml.py`.
  Modifier le constructor pour charger en plus le .mlpackage.

- [ ] **Step 2.2 — Monkey-patch backbone.forward**

  Dans `_run` après le `model.eval()` :

  ```python
  import coremltools as ct
  ml_bb = ct.models.MLModel(str(MLPACKAGE_PATH),
                            compute_units=ct.ComputeUnit.CPU_AND_GPU)

  def _coreml_backbone_forward(self, x):
      # x : torch.Tensor (1, 3, 672, 672) MPS
      x_np = x.detach().cpu().numpy().astype(np.float32)
      out = ml_bb.predict({"image": x_np})
      # output key dépend de l'export — probablement 'var_NNNN' ou
      # le nom donné au TensorType. Verifier au Task 1.
      key = list(out.keys())[0]
      y_np = out[key]
      return torch.from_numpy(y_np).to(x.device)

  model.backbone.forward = types.MethodType(_coreml_backbone_forward,
                                             model.backbone)
  ```

  Le reste de Multi-HMR.forward consomme `z = self.backbone(x)`
  comme tensor MPS — pas de changement downstream.

- [ ] **Step 2.3 — Bench end-to-end**

  Reuse `/tmp/bench_multihmr_camera.py`. Mesurer :
  - latence forward Multi-HMR (warning + heartbeat)
  - fps soutenu 30 s
  - persons/frame avec 3 sujets
  - RAM peak (`psutil`)

  **Gate** : ≥ 6 fps soutenu (≥ 1.8× current 3.4 fps baseline) ET
  RAM ≤ 3 GB.

### Task 3 — Intégration `main.py` CLI flag (15 min)

- [ ] **Step 3.1 — Flag `--multi-hmr-coreml-backbone`**

  Mutuellement exclusif avec `--multi-hmr` standard. Spawn
  `MultiHMRWorkerCoreML` au lieu de `MultiHMRWorker`.

- [ ] **Step 3.2 — Heartbeat tag**

  Log différencie : `hb (coreml): %.1f fps` pour suivre les régressions
  en debug.

### Task 4 — Validation visuelle + commit (30 min)

- [ ] **Step 4.1 — Lancement live**

  AVLiveBody + worker hybride 1 minute. Comparer le mesh visuel
  contre la baseline. Pas de pop, pas de jitter accru.

- [ ] **Step 4.2 — Commits propres**

  - `feat(data-only-viz): CoreML backbone hybrid worker`
  - `feat(data-only-viz): CLI --multi-hmr-coreml-backbone`

## Success criteria

| Métrique | Cible | Stretch |
|---|---|---|
| Forward Multi-HMR end-to-end M5 | ≤ 130 ms (≥ 7.5 fps) | ≤ 80 ms (≥ 12 fps) |
| Speedup vs baseline 274 ms PyTorch | ≥ 2× | ≥ 3× |
| Numerical drift sur v3d vs full PyTorch | cosine ≥ 0.999 | cosine ≥ 0.9999 |
| RAM peak | ≤ 3 GB | ≤ 2 GB |
| Pids distincts 30 s (3 sujets) | ≤ 5 | ≤ 4 |

## Abandon criteria

- Step 1.3 cosine < 0.99 → drift inacceptable, investiguer fp16 ou
  abandon hybrid pour full conversion.
- Step 2.3 latence net pire que baseline → round-trip MPS↔CPU↔CoreML
  domine ; abandon hybrid, viser full conversion (T3 plan).

## Estimated total

~2.5 h focused work. Beaucoup plus pragmatique que T3 multi-jour.

## Decision tree post-hybrid

```
hybrid speedup ≥ 2× ET drift OK ?
  oui → ship + use comme baseline future, attendre coremltools mature
        avant T3 full convert
  non → si drift KO : full conversion T3 obligatoire
        si latence KO : voir si CoreML CPU_AND_NE meilleur ici,
                        sinon abandon CoreML temporairement
```
