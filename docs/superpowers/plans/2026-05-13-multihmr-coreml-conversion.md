# Multi-HMR → CoreML conversion (ANE-capable, fixed-K detection)

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` or
> `superpowers:executing-plans` to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** convert Multi-HMR ViT-S to a CoreML `.mlpackage` runnable on
M5 ANE+GPU, reaching ≥15 fps on M5 (target 20-30 fps) without thermal
throttle. Replace the current PyTorch MPS path (3.8 fps measured, thermal
drift to ~3 fps) in `data_only_viz/multi_hmr_worker.py`.

**Non-goals:**
- Convert ViT-L or ViT-B variants (S only — already smallest).
- Train a new model (we only do model surgery on inference path).
- Port the SMPL-X decoder; Multi-HMR already returns `v3d` directly.
- Multi-batch inference (B=1 fixed; we run real-time single camera).

**Architecture:** Multi-HMR forward decomposes into (a) DINOv2 ViT-S
backbone (672×672 → tokens), (b) per-token classification head, (c)
detection thresholding via `torch.where(scores >= det_thresh)`, (d)
per-detection regression heads producing `v3d`, `shape`, `expression`,
`transl`. Step (c) is the data-dependent op CoreML refuses. The fix:
replace `where()` with `topk(K=4)` returning the K highest-confidence
detections; pad/zero remaining slots; emit a score tensor so downstream
filtering can be done on the Swift side.

## Research summary (2026-05-13)

- **coremltools** (latest stable) supports `RangeDim` /
  `EnumeratedShapes` for input flexibility but explicitly excludes
  data-dependent output cardinality for ML Programs (apple.github.io
  flexible-inputs.html).
- Open issues #2189 (ExecuTorch dynamic index), #2040 (`index_put`),
  #1678 (traced `index_put`) confirm `nonzero`/`where` + indexing
  patterns still unsupported in 2024-2026.
- naver/multi-hmr repo has zero issues/PRs on CoreML, ANE, MLX, ONNX,
  or Apple Silicon → no prior art; we are first-mover.
- `torch.export` (PyTorch 2.5+) + `coremltools.convert` is the modern
  path, but inherits the same data-dependent restrictions.

## Probe result 2026-05-13 (Task 1 Step 3)

Ran `/tmp/coreml_probe.py` on a fresh coreml-probe-venv (torch 2.12,
coremltools 9.0, M5). **Conversion FAILED at MIL op 17/670** :

```
ERROR - converting 'int' op (located at: '50'):
only 0-dimensional arrays can be converted to Python scalars
```

Source : DINOv2's `interpolate_pos_encoding` in
`vision_transformer.py:186-212` uses `int(math.sqrt(N))`,
`float(w0+offset)/M` etc on tensor scalars — coremltools rejects
these as untraceable.

**Surgery required** (revised effort estimate):

1. Fork DINOv2's `vision_transformer.py`, hardcode `npatch=48*48=2304`
   for 672x672 input (no dynamic interpolation needed since input is
   fixed). Replace tensor-to-scalar conversions with Python constants
   computed once at module init.
2. Then re-attempt trace + convert.
3. Then surgery on Multi-HMR head (`torch.where` → `topk(K=4)`).

**Revised effort**: 2-3 days minimum (was estimated 1 day). The
single-day estimate was optimistic — backbone alone needs ~½ day of
surgery before head can even be touched.

### Task 2 + 3 attempted (2026-05-13, post-breakthrough)

**Task 2 — apply_topk validation : PASS**

`apply_topk(K=4)` validée comme drop-in pour `apply_threshold` :
cosine sim 1.000000 sur 4/4 détections (image example_data), MAE
2-4 mm = bruit float-reorder. Script : `scripts/probe_head_topk.py`.

**Task 3 — Full Multi-HMR convert : en cours, patches itératifs**

Tentative conversion full Multi-HMR avec :
- apply_threshold monkey-patched → apply_topk(K=4)
- backbone.encoder.interpolate_pos_encoding → buffer fige
- utils.camera.inverse_perspective_projection → closed-form K_inv

→ TracedMHMR.forward sanity OK, jit.trace OK, mais conversion
coremltools échoue successivement sur :
1. `upsample_bicubic2d` ✅ résolu par pos_embed fix
2. `aten::inverse` ✅ résolu par closed-form K_inv
3. `Types should have zero-rank ndarray input, got [0.]` ❌ encore

Pattern : chaque patch débloque la couche suivante. Estimation
restante : 1-2 jours pour couvrir tous les ops résiduels.

Script Task 3 : `scripts/coreml_full_probe.py` (laissé en place pour
reprise — point d'arrêt précis documenté).

### Probe v4 (2026-05-13) — BREAKTHROUGH

Avec **2 patches au lieu d'1**, la conversion DINOv2 ViT-S 672x672
**REUSSIT** et donne un **speedup massif** :

| Backend | Median (50 iter, M5) |
|---|---|
| **CoreML CPU_AND_GPU** | **25.1 ms** |
| CoreML ALL (avec ANE) | 157.3 ms (ANE *ralentit*) |
| CoreML CPU_AND_NE | 157.5 ms |
| CoreML CPU_ONLY | 120.5 ms |
| PyTorch MPS | 274.7 ms |

**Speedup CoreML GPU vs PyTorch MPS : 11.8×.**

Les 2 patches requis :

1. **Pre-calculer `interpolate_pos_encoding`** en buffer fige (v2).
2. **Patcher coremltools `_cast`** pour gerer `x.val` non-0d via
   `numpy.asarray().item()` ou fallback `mb.cast`. Le bug dans ops.py
   ligne 3048 plante `dtype(x.val)` quand val n'est pas scalaire (vient
   de l'arithmetique de shapes int() dans patch_embed).

Code reproductible : `data_only_viz/scripts/coreml_probe.py`
(committé). Le `.mlpackage` cible : `/tmp/dinov2_vits14_672.mlpackage`.

**Lecture clé** : le bottleneck Multi-HMR n'etait pas l'architecture
ou la precision — c'etait le **PyTorch MPS dispatch overhead**. CoreML
+ MPSGraph compile le graphe avec op fusion. L'ANE etait un **piege**
ici (probablement re-route fp32 vers GPU avec cout transit).

**Implication pour Multi-HMR full** : si le head benefice du meme
speedup, full Multi-HMR converti = 40-60 ms = **15-25 fps**. Cible
atteignable. Tasks 2-4 du plan restent valides ; le risque principal
deplace vers la chirurgie head (torch.where -> topk).

### Probe v2 (with pos_embed pre-computed as buffer) — historique

Patched `interpolate_pos_encoding` to return a frozen pre-computed
buffer. **Trace OK, but convert still FAILS at op 17/610** with same
error. Removing pos-embed surgery reduced ops 670 → 610 (~60 ops
gone), but a DEEPER tensor-to-Python-scalar conversion remains —
likely in DINOv2's attention or MLP block. Would need coremltools
verbose logging or per-op instrumentation to localize. Not done.

**Recommendation**: pursue only if thermal/ANE residency is the goal.
For pure speedup, Mac Studio M3 Ultra offload (separate plan
`2026-05-13-studio-offload.md`) gives 5-10× faster than Multi-HMR MPS
with ~½ day work and no model surgery. SOTA alternative survey
(`2026-05-13-modern-body-mesh-survey.md`) identifies Fast-SAM-3D-Body
(DINOv3 + MIT, Apr 2026) as a possible drop-in replacement worth
evaluating before sinking more time into CoreML surgery.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| ViT-S DINOv2 has CoreML-unsupported op (rare in 2026) | low | high | trace bare backbone first (Task 1) — fail fast |
| `transl` head uses `inverse_perspective_projection` w/ matmul on dyn shape | medium | medium | check trace; fallback compute in PyTorch on Python side |
| ANE doesn't accept 672×672 input (ANE prefers ≤512 in practice) | medium | medium | benchmark with `compute_units=.cpuAndGPU` first, then `.all`; if ANE rejects, GPU-only still beats MPS path |
| Numerical drift after K-fixed swap → false-positive detections | medium | low | Swift-side score gate (already exists via `det_thresh` arg path) |
| End-to-end perf doesn't beat MPS baseline | low | high | Phase A bench (headless dummy) is the gate — abandon before integration |

## Task 1: Bare backbone trace + convert sanity check

**Context:** before touching the detection head, prove that the
DINOv2-S backbone alone (the bulk of the compute) converts and runs.
This isolates the bottleneck risk.

- [ ] **Step 1: Extract backbone-only forward**

  Write a small wrapper module that loads the ViT-S checkpoint, takes
  the backbone (`model.backbone`), and runs only that on a
  `(1, 3, 672, 672)` input. Verify it matches the original forward's
  token output for the first 5 frames of a webcam stream (cosine sim
  > 0.999 on the token tensor).

  Output: `data_only_viz/_coreml_backbone_probe.py` + numerical proof.

- [ ] **Step 2: `torch.jit.trace` the wrapper**

  ```python
  example = torch.rand(1, 3, 672, 672)
  traced = torch.jit.trace(BackboneWrapper(model), example)
  ```

  Escalate if trace fails: identify the op (likely `unpatch` or fourier
  encoding). For unfixable ops, try `torch.export.export` instead
  (PyTorch 2.5+ path).

- [ ] **Step 3: `coremltools.convert` backbone**

  ```python
  import coremltools as ct
  mlmodel = ct.convert(
      traced,
      inputs=[ct.TensorType(shape=(1, 3, 672, 672), name="image")],
      compute_units=ct.ComputeUnit.ALL,
      minimum_deployment_target=ct.target.macOS15,
      convert_to="mlprogram",
  )
  mlmodel.save("/tmp/multihmr_backbone.mlpackage")
  ```

- [ ] **Step 4: Bench backbone alone**

  Time 20 iterations of `mlmodel.predict({"image": np.random.rand(...)})`.
  Compare to PyTorch MPS backbone-only timing (re-run profiler from
  Phase A but on backbone only). **Gate: CoreML backbone median latency
  ≤ 60% of MPS backbone latency, otherwise abandon plan.** Backbone
  alone on MPS is ~50 ms; CoreML target ≤30 ms.

- [ ] **Step 5: Commit probe**

  ```bash
  git add data_only_viz/_coreml_backbone_probe.py
  git commit -m "feat(data-only-viz): Multi-HMR backbone CoreML probe"
  ```

## Task 2: Replace `torch.where` with fixed-K `topk` in head

**Context:** Multi-HMR detection head emits a score map shape
`(1, 48, 48, 1)` (or similar) which is thresholded via `torch.where`
to extract K_dynamic candidate persons. Replace with `topk(K=4)`
returning the 4 highest-scoring tokens. K=4 matches the worker's
`num_persons=4` constructor default — same downstream budget.

- [ ] **Step 1: Locate `apply_threshold` callsite**

  Confirmed: `~/.cache/av-live-multihmr/multi-hmr/model.py:149` calls
  `apply_threshold(det_thresh, _scores)` returning a 4-tuple of
  index tensors used for `scores[idx[0], idx[3], idx[1], idx[2]]`
  gather at line 154-156.

- [ ] **Step 2: Write `apply_topk(K, _scores)` replacement**

  Reshape `_scores` from `(B, H, W, C)` to `(B, H*W*C)`, run
  `topk(K)`, then unravel indices back to 4 components matching the
  4-tuple signature.

  ```python
  def apply_topk(K, _scores):
      B, H, W, C = _scores.shape
      flat = _scores.reshape(B, -1)
      vals, idx_flat = torch.topk(flat, k=K, dim=1)
      # Unravel: idx_flat // (H*W*C)? No — already per-batch.
      hwc = H * W * C
      idx_b = torch.arange(B, device=_scores.device).unsqueeze(1).expand(-1, K).reshape(-1)
      idx_local = idx_flat.reshape(-1)
      idx_h = (idx_local // (W * C))
      idx_w = (idx_local // C) % W
      idx_c = idx_local % C
      return (idx_b, idx_h, idx_w, idx_c), vals.reshape(-1)
  ```

- [ ] **Step 3: Monkey-patch in a forked Model class**

  Don't edit upstream `~/.cache/...model.py` (re-`setup_multihmr.sh`
  wipes it). Instead, subclass `Model` in
  `data_only_viz/multi_hmr_coreml.py` and override the detection head.
  Inject the patched class via the same `sys.path` mechanism used in
  `multi_hmr_worker.py`.

- [ ] **Step 4: Verify numerical equivalence (top-K case)**

  When the original model emits exactly K detections with
  `det_thresh=0.3`, the new K=4 must return identical `v3d`. Use
  a recorded webcam frame with 1 person; compare `v3d` cosine sim
  > 0.9999.

- [ ] **Step 5: Commit head replacement**

## Task 3: Full model trace + CoreML conversion

- [ ] **Step 1: Wrap patched Model for tracing**

  The full model's forward returns a list-of-dicts (`humans`). Tracing
  refuses dict/list outputs. Wrap to return a fixed-shape tuple:
  `(v3d[K,10475,3], shape[K,10], expression[K,10], transl[K,3],
  scores[K])`.

- [ ] **Step 2: `torch.jit.trace` full model**

  Run on `(1, 3, 672, 672)` dummy. Catch and resolve trace warnings.
  Likely failures: `inverse_perspective_projection` matmul, fourier
  encoding (`torch.arange` inside forward). Move these to a
  pre-computed constant if they don't trace cleanly.

- [ ] **Step 3: `coremltools.convert` full model**

  Same convert pattern as Task 1 Step 3. Save to
  `~/.cache/av-live-multihmr/checkpoints/multiHMR_672_S.mlpackage`.

- [ ] **Step 4: Bench full CoreML model (headless)**

  20 iter, M5, `compute_units=ALL`. **Gate: median ≤80 ms (≥12.5 fps)
  otherwise revisit Task 1 budget assumptions.**

## Task 4: Worker integration

- [ ] **Step 1: Add CoreML backend in `multi_hmr_worker.py`**

  Add `--multi-hmr-backend coreml` flag (default `pytorch`). Load via
  `import coremltools` (already a transitive dep of macOS Python).
  Skip the entire PyTorch model setup path when coreml selected.

- [ ] **Step 2: Translate I/O**

  Input: `np.ndarray (1, 3, 672, 672) float32`. Output: 5 tensors
  packed back into the same `humans = [...]` list-of-dicts the rest
  of the worker expects. Filter on `scores >= det_thresh` in numpy.

- [ ] **Step 3: Camera-live bench**

  Re-run `/tmp/bench_multihmr_camera.py` against the coreml backend
  for 60 s (longer than the 30s previous run — catch thermal stability).
  Record: median latency, fps, thermal trend.

- [ ] **Step 4: Commit + README update**

## Task 5: ANE compute unit experiments

- [ ] **Step 1: A/B `.all` vs `.cpuAndGPU` vs `.cpuAndNeuralEngine`**

  ANE may reject ops or not accept the input size; need empirical
  fallback. Record which compute unit each layer ran on via
  `mlmodel.compute_unit_used_per_layer` (if available in 2026 API)
  or system-level `powermetrics`.

- [ ] **Step 2: If ANE-eligible: re-bench**

  Expected: 25-40 fps on ANE-resident inference (no thermal load
  on GPU at all). This is the home run.

## Success criteria

| Metric | Target | Stretch |
|---|---|---|
| Median latency on M5 (camera-live, 60s) | ≤ 65 ms | ≤ 35 ms |
| FPS sustained over 5 min (no thermal drift) | ≥ 15 | ≥ 25 |
| Mesh quality (v3d cosine sim vs PyTorch) | ≥ 0.999 | ≥ 0.9999 |
| Wall-time vs PyTorch MPS | ≥ 3× faster | ≥ 6× faster |

## Abandon criteria (cut losses fast)

- Task 1 Step 4 backbone-alone CoreML > 60% of MPS → abandon
- Task 2 numerical equiv check fails (top-K doesn't approximate
  top-thresholded) → abandon, propose ONNX Runtime path instead
- Task 3 trace fails on >2 ops requiring real model surgery →
  reframe as multi-week effort, not a perf optimization

## Fallback if abandoned

If CoreML proves infeasible within 1-day effort, fall back ranking:
1. Frame-skip + Swift interp 60 fps (already in progress, separate file)
2. Offload Multi-HMR inference to MacStudio M3 Ultra over Tailscale
   (worker becomes a TCP client to a remote endpoint)
3. SMPLer-X-S port (different model, claims 64 ms M5 — see
   `data_only_viz/smpler_x_scaffold.md`)
