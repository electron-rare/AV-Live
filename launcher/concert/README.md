# AV-Live Concert.app (matrix mode)

One double-click boots the matrix arranger on macm1. (The app keeps its
"Concert" name but now launches the matrix, not the body-play concert.)

## What it does

`launch_concert.sh` (the app's executable) runs the boot sequence:

1. Launches the **iPhone ARBodyTracker** app (camera + ARKit skeleton over USB).
2. Boots **SuperCollider** in **`MATRIX_ONLY`** (`sound_algo/data_only/boot.scd`):
   the concert/body-play scene is disabled, only the matrix arranger + the
   launchpad voices are loaded.
3. Starts the **pose pipeline** (`data_only_viz --pose --iphone-usb`): emits
   `/pose/hands`, `/pose/center`, `/pose/sho_span` → matrix **capture-modulation**
   sources (hands/body → matrix params), and shows a live pose visual.
4. Starts the **web control surface** (`web_realart`, `:4400`).
5. Loads a matrix preset (`MATRIX_PRESET`, default `techno_drive`) and starts the
   playhead.

Re-running restarts cleanly (it kills any prior stack first).

## Build / install

On macm1 (where the stack runs):

```sh
cd ~/Documents/Projets/AV-Live/launcher/concert
./build_concert_app.sh                 # -> ~/Desktop/AV-Live Concert.app
```

Then double-click **AV-Live Concert.app** on the Desktop. A notification confirms
each stage; sound comes up after ~45 s.

## Live controls (once running)

The matrix is driven from the **web control surface** —
`http://supra-m1.local:4400/control/`, **MATRICE** tab — from any LAN device:

- the 16×32 grid (per-voice patterns, 7 colors incl. real octave up/down),
- the per-instrument **mixer**, the **timeline** (loop region + seek),
- preset load/save, per-voice **instrument** selection + **capture-modulation**
  (hands/body → amp/cutoff/pan).

`MATRIX_PRESET="" open "AV-Live Concert.app"` starts from an empty grid.

## Notes

- The iPhone device UDID (`DEV`) is hardcoded in `launch_concert.sh` — update it if
  the phone changes (`xcrun devicectl list devices`). Without an iPhone the matrix
  still plays; only the pose-driven capture-modulation stays idle.
- Logs: `/tmp/concert_viz.log` (pose) and `/tmp/sc_boot.log` (SuperCollider).
