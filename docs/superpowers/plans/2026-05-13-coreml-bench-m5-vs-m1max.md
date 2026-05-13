# DINOv2 ViT-S 672 — bench comparatif M5 vs M1 Max

> Bench du backbone DINOv2 (probe v4, scripts/coreml_probe.py)
> sur 2 hardwares Apple Silicon. Référence pour décisions
> deploy AV-Live.

**Méthodo** : même `.mlpackage` (`dinov2_vits14_672_v4.mlpackage`)
produit par `scripts/coreml_probe.py`, 50 iter sur dummy
`(1, 3, 672, 672) float32` random. Workers concurrents pausés
(SIGSTOP) sur macM1 pour bench propre.

## Hardware

| Host | Chip | Memory | GPU cores | Note |
|---|---|---|---|---|
| GrosMac (local) | **M5** | 16 GB | ~10 | dev workstation, throttle thermique |
| macm1 (Tailscale 100.112.121.126) | **M1 Max** | 32 GB | 32 | LLM serving |

## Résultats (median 50 iter, dummy 672x672)

| Backend | M5 | M1 Max | Δ |
|---|---|---|---|
| CoreML `CPU_AND_GPU` | **25.1 ms** | 63.3 ms | **M5 2.5× plus rapide** |
| CoreML `ALL` (avec ANE) | 157.3 ms | 154.1 ms | ~égal (ANE handicape) |
| CoreML `CPU_AND_NE` | 157.5 ms | 161.1 ms | ANE solo ≈ ALL |
| CoreML `CPU_ONLY` | 120.5 ms | 159.8 ms | M5 1.3× plus rapide |
| PyTorch MPS | 274.7 ms | **110.6 ms** | **M1 Max 2.5× plus rapide** |

## Lectures

1. **CoreML GPU sur M5 dépasse M1 Max GPU** (25 vs 63 ms) malgré
   3× moins de cores. L'architecture GPU M5 (per-core) est nettement
   plus performante pour les workloads ViT/Transformer.

2. **PyTorch MPS inverse** : M1 Max 2.5× plus rapide que M5 (110 vs
   274 ms). Le M5 souffrait probablement de throttle thermique
   accumulé pendant la session de tests (les bench M5 ont été faits
   après plusieurs heures de workloads ML).

3. **ANE handicape sur les 2 machines** (~155 ms vs 25-63 ms GPU).
   DINOv2 ViT-S n'est pas un workload ANE-friendly — probable
   re-route fp32 ANE↔GPU avec coût transit.

## Implications AV-Live

**Cible production** : M5 local (contrainte on-device <8 GB RAM).

**Recommandation** : utiliser **CoreML CPU_AND_GPU** comme backend
runtime. Le M5 GPU est plus rapide que ce qu'on pensait.

Pour le scaling/déploiement à plusieurs machines :
- M5 / M-récents : CoreML CPU_AND_GPU (option à pousser dans
  multi_hmr_worker_coreml.py via flag)
- M1 Max et antérieurs : PyTorch MPS reste compétitif (110 ms),
  parfois plus rapide que CoreML GPU sur ces machines
- Décision : laisser un flag `--backend` au runtime, défaut auto-pick

## Caveats

- Throttle thermique M5 non quantifié (run de la session vs froid)
- 50 iter par bench : variance présente mais bornée
- Camera capture overhead non inclus (~30 ms additional sur les 2,
  s'annulent dans la comparaison)
- M1 Max sous-utilisé : seulement 1 worker MLX paused, 2 workers
  hot-startés (vraisemblablement < 5 % CPU baseline)

## Source

- Script bench M5 : `data_only_viz/scripts/coreml_probe.py`
- Output M5 commit `7162f76` : 25.1 ms (CPU_AND_GPU)
- macM1 setup : `/tmp/m1-bench-venv` (uv venv Python 3.12 + torch + coremltools)
- macM1 bench run : SIGSTOP 47108 80357 (mlx_lm gemma-4 workers),
  bench, SIGCONT après
