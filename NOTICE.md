# AV-Live Third-Party Notices

AV-Live includes or depends on the following third-party works,
which are licensed under their own terms.

## Body Mesh Recovery Models

### Multi-HMR (NAVER, 2025)

- **License**: NAVER Non-Commercial License
  (https://github.com/naver/multi-hmr/blob/main/LICENSE.txt)
- **Use**: Non-commercial only. Body mesh recovery from camera input.
- **Integration**: model checkpoint downloaded at runtime to
  `~/.cache/av-live-multihmr/`. No source code vendored.

### SMPLer-X (S-Lab, ECCV 2024)

- **License**: S-Lab License 1.0
  (`third_party/SMPLer-X/LICENSE` after submodule init)
- **Use**: Non-commercial only. Whole-body mesh recovery (SMPL-X).
- **Integration**: vendored as git submodule at
  `third_party/SMPLer-X` (fork `electron-rare/SMPLer-X`, kept in
  sync with `caizhongang/SMPLer-X` or its current upstream).
- **Modifications in fork**: minimal patches for ARM macOS Python
  3.14 inference (replace mmdet detector with Ultralytics YOLO,
  shim `mmcv.Config` via `mmcv-lite`).

## Implication

**AV-Live integrates non-commercial-only model code from Multi-HMR
and SMPLer-X.** Commercial deployment (paid performances, packaged
installations sold to clients) requires either :

1. Obtaining commercial licenses from NAVER and S-Lab respectively, OR
2. Replacing both integrations with MIT/Apache-licensed alternatives
   (see `docs/superpowers/plans/2026-05-13-modern-body-mesh-survey.md`
   for candidates like Fast-SAM-3D-Body which is MIT-licensed).

The AV-Live source code itself (sound_algo, oscope-of, launcher,
data_only_viz integration glue) is under GPL-3.0 (see root LICENSE).
