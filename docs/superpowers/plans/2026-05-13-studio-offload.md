# Multi-HMR offload sur Mac Studio M3 Ultra

> **STATUT (2026-05-13) : PLAN DEFERRED.** Le user a impose la
> contrainte « doit tourner sur le M5 avec < 8 GB RAM » → tout
> offload reseau est exclu. Ce plan reste documente pour reference
> au cas ou la contrainte serait levee.

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` or `superpowers:subagent-driven-development`.
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** déplacer l'inférence Multi-HMR ViT-S de M5 (3.8 fps, thermal
throttle, 228 ms/frame) vers Mac Studio M3 Ultra
(`studio` Tailscale `100.116.92.12`, 80 cores GPU, 512 GB RAM, pas de
throttle). M5 garde caméra + capture + rendu. Cible : **≥ 15 fps
soutenu sans drift thermique**.

**Non-goals:**
- Toucher au modèle Multi-HMR (zero model surgery).
- Convertir en CoreML ou MLX (autres plans).
- Streaming vidéo bi-directionnel (juste pose data uplink).
- Multi-tenant Studio (1 client à la fois pour ce plan).

**Architecture:**

```
M5 (laptop)                          Studio (M3 Ultra)
─────────────                        ─────────────────
camera (AVCapture)                   FastAPI :9301 /infer
   |                                    ^
   v                                    | POST jpeg bytes (~50 KB)
encoder cv2.imencode JPEG q=80          v
   |                                  decode + Multi-HMR ViT-S MPS
   |  POST /infer (HTTP keep-alive)      |
   |--------------------------------->   |
   |                                     v
   |  <--- pose JSON (compact) ----    {humans: [{v3d, transl, ...}]}
   v
SMPLXTCPSender -> AVLiveBody :57130 (local TCP, inchangé)
   |
   v
RealityKit render 60 fps avec interp
```

**Pourquoi pas TCP nu / OSC ?** HTTP/1.1 keep-alive ≃ overhead 1-2 ms
sur Tailscale local LAN, et bénéficie de FastAPI gratuit (logging,
validation Pydantic, /docs, /health). Si la latence devient critique,
upgrade en WebSocket ou gRPC en T+1.

**Pourquoi JPEG q=80 plutôt que raw float32 ?** 672×672×3 float32 =
5.4 MB par frame. JPEG q=80 = ~50 KB (100× plus petit). Latence
transfert sur Tailscale LAN (~1 Gbps) : 5.4 MB → 50 ms, 50 KB → 0.5 ms.
Perte qualité JPEG q=80 sur 672² = imperceptible pour body pose.

## Tasks

### Task 1: Studio side — FastAPI server `multihmr_server.py`

- [ ] **Step 1: Inventaire env Studio**

  ```bash
  ssh studio 'ls -la ~/Documents/Projets/AV-Live 2>/dev/null \
    || echo "AV-Live absent"; which uv; python3 -V'
  ```

  Si le repo n'est pas sur Studio : `git clone` + `uv sync --extra
  multihmr` + `bash data_only_viz/scripts/setup_multihmr.sh`. Studio a
  déjà SMPL-X license (cf reference dans CLAUDE.md home), récupérer
  `SMPLX_NEUTRAL.npz` depuis MacStudio existing cache si possible.

- [ ] **Step 2: Écrire `data_only_viz/multihmr_server.py`**

  FastAPI app exposant `POST /infer` qui :
  1. Reçoit `multipart/form-data` avec field `image` (JPEG bytes).
  2. Décode JPEG → ndarray BGR (cv2.imdecode).
  3. Resize / center-crop à 672² si nécessaire.
  4. Lance inférence Multi-HMR (modèle chargé au startup).
  5. Renvoie JSON :
     ```json
     {
       "humans": [
         {
           "v3d": [[x,y,z], ...],          // 10475 vertices SMPL-X
           "transl": [x,y,z],
           "shape": [10 floats],
           "expression": [10 floats],
           "score": 0.87
         }
       ],
       "inference_ms": 65.3
     }
     ```
  6. Lifespan : load model en MPS au startup, log "ready on :9301".

  Reuse 90% du code de `multi_hmr_worker.py` (loading, model call,
  dedup) — factoriser dans un module commun `multi_hmr_core.py` que
  worker et serveur importent tous deux. Évite la divergence.

- [ ] **Step 3: systemd service `multihmr.service` sur Studio**

  Studio tourne d'autres workers MLX (cf CLAUDE.md home, plists
  `:9301-9327`). Choisir un port libre, par défaut `:9311`. Création
  d'une plist launchd (Studio est macOS, pas Linux) :

  ```xml
  <!-- ~/Library/LaunchAgents/com.avlive.multihmr.plist -->
  <plist version="1.0"><dict>
    <key>Label</key><string>com.avlive.multihmr</string>
    <key>ProgramArguments</key><array>
      <string>/Users/clems/.local/bin/uv</string>
      <string>run</string><string>--project</string>
      <string>/Users/clems/AV-Live/data_only_viz</string>
      <string>--extra</string><string>multihmr</string>
      <string>uvicorn</string>
      <string>data_only_viz.multihmr_server:app</string>
      <string>--host</string><string>0.0.0.0</string>
      <string>--port</string><string>9311</string>
    </array>
    <key>KeepAlive</key><true/>
    <key>RunAtLoad</key><true/>
    <key>StandardErrorPath</key>
    <string>/Users/clems/Library/Logs/avlive-multihmr.log</string>
  </dict></plist>
  ```

- [ ] **Step 4: Smoke test depuis M5**

  ```bash
  curl -X POST http://100.116.92.12:9311/infer \
    -F "image=@/tmp/test_person.jpg" -w "%{time_total}\n"
  ```

  Attendre : 200 OK, JSON valide, time_total < 100 ms (target).

### Task 2: Side M5 — backend remote dans `multi_hmr_worker.py`

- [ ] **Step 1: Ajouter backend `remote` à `MultiHMRWorker`**

  Constructor param `backend: Literal["local", "remote"] = "local"`.
  Si `remote`, ne charge pas le modèle local, ouvre une session
  `requests` keep-alive (ou `httpx.AsyncClient`) vers Studio.

  Dans la boucle `_run` :
  - Encode `frame_bgr` en JPEG q=80 via `cv2.imencode`.
  - POST `/infer` avec timeout 1 s.
  - Parse JSON → reconstruct list[dict] avec `v3d` en numpy.
  - Le reste du pipeline (dédup, tracker, smplx_tcp) inchangé.

- [ ] **Step 2: CLI flag `--remote URL`**

  ```bash
  uv run -m data_only_viz.main --multi-hmr \
    --remote http://100.116.92.12:9311
  ```

  `--remote` impose `backend="remote"` + bypass `is_available()`
  local check (pas besoin du checkpoint local).

- [ ] **Step 3: Retry + fallback**

  Si /infer échoue (timeout, 5xx) 3 fois consécutives : log
  WARNING + fallback `backend="local"` automatiquement (si modèle
  local disponible) ou émet une frame vide. Pas de crash.

### Task 3: Bench end-to-end

- [ ] **Step 1: 30 s caméra live, 3 personnes**

  Reuse le harness e2e fait plus tôt. Captures :
  - médiane latence inférence (depuis logs serveur `inference_ms`)
  - médiane latence end-to-end (POST round-trip M5 side)
  - persons/frame moyenne
  - dist pids (objectif < 5 pids pour 3 vraies personnes)

- [ ] **Step 2: Comparer à baseline local M5**

  | Métrique | M5 local (commit 278ed55) | M5 remote → Studio |
  |---|---|---|
  | inference ms | 228 | ? |
  | end-to-end ms | 228 | inference + JPEG enc + HTTP RTT |
  | fps sustained 5 min | 3.4 → 2.9 (throttle) | ? (pas de throttle) |
  | persons/frame | 2.0 | ? |

  **Gate de succès** : end-to-end médian ≤ 100 ms (10 fps) ET
  pas de drift sur 5 min.

### Task 4: Doc + commit

- [ ] **Step 1: README update**

  Ajouter section "Remote inference" dans
  `data_only_viz/MULTIHMR_README.md` : prérequis, command, ports.

- [ ] **Step 2: Commit**

  ```
  feat(data-only-viz): Multi-HMR remote inference (Studio)
  ```

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Tailscale latency variable | medium | medium | HTTP keep-alive ; mesurer p95/p99 |
| Studio MPS thermals (rare) | low | medium | Studio M3 Ultra a 80 cores, headroom large |
| JPEG q=80 dégrade détection | low | low | A/B q=95 vs q=80 dans bench |
| Multi-HMR cache absent Studio | high (1re fois) | low (setup script) | Step 1 du Task 1 le résout |
| Port :9311 occupé | low | low | choisir port libre via netstat |

## Success criteria

- end-to-end ≤ 100 ms p50, ≤ 200 ms p95
- fps sustained 5 min ≥ 10 fps (vs M5 local qui drift à 2.9)
- aucune perte d'ID due à la latence réseau
- code Studio = same `multi_hmr_core.py` que local (pas de fork)

## Stretch

- Si latence < 70 ms : essayer Studio + Tower en load balancer
  (2 backends, round-robin) → ~ 20 fps possible.
- WebSocket streaming (frame in, pose out) → ~5 ms overhead vs HTTP.
- gRPC + protobuf → encore moins overhead mais plus de code.
