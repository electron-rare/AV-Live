# AV-Live Concert.app

One double-click boots the whole iPhone-USB concert on macm1.

## What it does

`launch_concert.sh` (the app's executable) runs the full boot sequence:

1. Launches the **iPhone ARBodyTracker** app (camera + ARKit skeleton over USB).
2. Starts the **pose pipeline** (`data_only_viz --pose --iphone-usb`: HEVC decode,
   MediaPipe, horizontal mirror, OSC out).
3. Boots **SuperCollider** (`sound_algo/data_only/boot.scd` → body-play: the
   concert engine, 13 body gestures, 11 morceaux).
4. Switches to the **`\concert`** scene.

Re-running restarts cleanly (it kills any prior stack first).

## Build / install

On macm1 (where the stack runs):

```sh
cd ~/Documents/Projets/AV-Live/launcher/concert
./build_concert_app.sh                 # -> ~/Desktop/AV-Live Concert.app
```

Then double-click **AV-Live Concert.app** on the Desktop. A notification confirms
each stage; the Metal window + sound come up after ~45 s.

## Live controls (once running)

- **Space** — next morceau (random)
- **Bras croisés** (wrists) — jump to a random morceau
- **Body gestures** — jump/stomp/squat/spin/T-pose (FX), step/lean/tilt (harmony),
  arm-raise/head (melody)
- `/control/concertChain 1` — hands-free auto-chain; `/control/concertSeq 1` —
  sequential instead of random; `CONCERT_MIRROR=0` — disable the video mirror

## Notes

- The iPhone device UDID (`DEV`) is hardcoded in `launch_concert.sh` — update it if
  the phone changes (`xcrun devicectl list devices`).
- Logs: `/tmp/concert_viz.log` (pose) and `/tmp/sc_boot.log` (SuperCollider).
