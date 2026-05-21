# ICP LiDAR ↔ SMPL-X Dense Fusion

Refines Multi-HMR SMPL-X meshes using live iPhone LiDAR via point-to-plane ICP.

## Env vars

| Var | Default | Effect |
|-----|---------|--------|
| `ICP_FUSION` | `0` | `1` enables LiDAR receiver + FusionWorker |
| `ICP_LIDAR_HOST` | _(required when on)_ | iPhone ARBodyTracker IP on the LAN |
| `ICP_LIDAR_PORT` | `5500` | TCP port the iOS app publishes ARMesh on |
| `ICP_LIDAR_EXTRINSIC` | `~/.config/av-live/lidar_extrinsic.json` | Path to persisted extrinsic JSON |

## Relation to ARKit joint fusion

ICP LiDAR fusion is **mesh-level** and complementary to the existing **joint-level** ARKit fusion (`iphone_osc_listener.py` + `pose_filter.py::ArkitFuse` + `multi_hmr_worker.arkit_pelvis_z_override`). The two run independently:

- **ARKit joints** (OSC :57128) — sparse (14 mapped joints), 60 Hz, fast, used to override MediaPipe pose joint slots and lock Multi-HMR pelvis Z.
- **ICP LiDAR mesh** (TCP :5500) — dense (~thousand points), 5–10 Hz, used to register Multi-HMR SMPL-X vertices onto the real-world geometry captured by the iPhone LiDAR.

They can be enabled together or separately. ICP runs only when `ICP_FUSION=1`.

## Calibration

1. Launch the iPhone ARBodyTracker app and note its LAN IP.
2. From `data_only_viz/`:
   ```bash
   uv run --extra lidar python -m data_only_viz.scripts.calibrate_lidar \
     --lidar-host <iPhone IP> --lidar-port 5500 --webcam-index 0
   ```
3. The script asks for 4 stances (front / left / right / back). Hold still each time and press ENTER.
4. The estimated extrinsic is written to `ICP_LIDAR_EXTRINSIC` (or the default path). Re-run any time the camera or iPhone moves.

> NOTE — as of the initial ICP MVP (Task 9), `multi_hmr_worker.predict_once` is a stub raising `NotImplementedError`. The calibration CLI runs the LiDAR reader and 4-stance loop scaffold but cannot capture the webcam pelvis side until a follow-up wires `predict_once` to the existing inference path. Track this in the next planning round.

## Runtime

```bash
ICP_FUSION=1 ICP_LIDAR_HOST=192.168.0.42 \
  uv run --extra lidar python -m data_only_viz.main
```

## Architecture (summary)

```
iPhone ARBodyTracker app
  ├── OSC  :57128  /body3d/kp        → IphoneOSCListener (ARKit joint fusion)
  └── TCP  :5500   ARMeshAnchors      → LidarTCPReader  (ICP mesh fusion)
                                                       ↓
                                       FusionWorker.run_once(state)
                                                       ↓
                                       state.persons_smplx[*].vertices_3d
                                       (replaced in place when ICP accepts)
```

ICP fusion runs in its own daemon thread (`IcpFusionThread`, target 8 Hz). It is opt-in (off by default) and a no-op if the LiDAR stream is absent.

## Troubleshooting

- **`open3d` missing** → `cd data_only_viz && uv sync --extra lidar`
- **No LiDAR frames** → check that the iPhone app is publishing on the expected port and that nothing else is bound to it. `nc -l 5500` from the Mac should not succeed while the app runs.
- **ICP always rejected (`fitness < 0.30`)** → the extrinsic is likely stale; re-run calibration. Verify the iPhone is facing the same scene as the webcam.
- **Mesh appears scaled wrong** → SMPL-X is in metres; the iPhone publishes metres. If you see a factor-1000 mismatch the iOS encoder is sending millimetres — patch the iOS app, not this code.
- **Bench shows `latency_ms_p95 > 100`** → reduce `IcpConfig.voxel_size_m` (e.g. 0.03 m) or `max_iterations` (e.g. 20).
- **Python `cp314` wheel failure on `uv sync --extra lidar`** → open3d does not ship cp313+ wheels yet. Use Python 3.12 (`uv venv --python 3.12`).

## Implementation note (Task 6 deviation)

`register_mesh_to_lidar` uses a two-stage coarse-to-fine ICP internally: a warm-start pass at `max(0.25 m, 5× threshold)` correspondence, then a strict pass at `IcpConfig.max_correspondence_m` (default 0.05 m). The accept/reject gate (`fitness ≥ 0.30`, `rmse ≤ 0.05 m`) is evaluated **only on the strict pass** so the contract is preserved. The warm-start makes ICP converge reliably when Multi-HMR's initial mesh sits more than 5 cm off the LiDAR surface (typical with a fresh calibration or pose change).
