#!/bin/zsh
# AV-Live Matrix launcher (runs the matrix arranger, not the concert).
# Boots the matrix stack in one shot:
#   iPhone ARBodyTracker (camera + ARKit skeleton over USB)
#   -> data_only_viz pose pipeline (feeds /pose/* for matrix capture-modulation)
#   -> SuperCollider engine in MATRIX_ONLY (concert disabled, matrix arranger)
#   -> web control surface, then load a preset and start the matrix playing.
# Used as the executable of "AV-Live Concert.app" (double-click to start).
# Re-running restarts cleanly (it kills any prior stack first).
set -u

REPO="$HOME/Documents/Projets/AV-Live"
DEV="AC1CDE5F-DDC4-5B2C-80D7-9953D8ABA0AC"   # iPhone 16 Pro (xcrun devicectl list devices)
export PATH=/opt/homebrew/bin:$PATH
# MediaPipe delegate: CPU by default. The GPU (Metal) delegate is faster but
# CRASHES under sustained load -- gpu_buffer_storage_cv_pixel_buffer.cc fatal
# CVPixelBuffer alloc failure (-6662) in Image::ConvertToGpu() -- on M1 Max too,
# not just M5. The original choppiness it was meant to fix was CPU STARVATION
# (baby-brain + model servers hogging the box); those are now stopped, so the CPU
# delegate has headroom and stays fluid AND stable. Override with
# MEDIAPIPE_DELEGATE=gpu only for short sessions where you accept the crash risk.
export MEDIAPIPE_DELEGATE="${MEDIAPIPE_DELEGATE:-cpu}"
# Finger pinches drive the matrix global actions (8 slots). Enabling the pinch
# detector also enables the air-piano finger-strike detector, inert unless a
# voice has a finger binding (none by default).
export FINGER_PIANO="${FINGER_PIANO:-1}"
export POSE_FILTER=median+kalman+lookahead+ik+arkit_fuse
# CONCERT_MIRROR=0 in the environment disables the video mirror.

PY="$REPO/data_only_viz/.venv/bin/python"
SCLANG="/Applications/SuperCollider.app/Contents/MacOS/sclang"
# matrix preset auto-loaded on boot (a sound_algo/.../matrix_presets/*.matrix name
# without extension); set MATRIX_PRESET="" to start from an empty grid.
MATRIX_PRESET="${MATRIX_PRESET:-techno_drive_live}"

notify() { osascript -e "display notification \"$1\" with title \"AV-Live Concert\"" 2>/dev/null; }

cd "$REPO" || { notify "repo introuvable"; exit 1; }

# 0) clean any prior run
pkill -9 -f "data_only_viz.main" 2>/dev/null
pkill -9 -f sclang 2>/dev/null
pkill -9 -f scsynth 2>/dev/null
lsof -ti UDP:57121 2>/dev/null | xargs kill -9 2>/dev/null
lsof -ti UDP:57123 2>/dev/null | xargs kill -9 2>/dev/null
sleep 2

notify "Demarrage..."

# 1) iPhone ARBodyTracker (camera + skeleton over USB)
xcrun devicectl device process launch --device "$DEV" cc.saillant.ARBodyTracker >/dev/null 2>&1
sleep 3

# 2) SuperCollider engine in MATRIX_ONLY (concert/body-play disabled; loads the
#    matrix arranger + the launchpad voices). sclang needs a controlling TTY to
#    boot scsynth reliably -> run it under `script` (gives a pseudo-TTY), detached
#    via nohup. needs no Automation/TCC permission. Log -> /tmp/sc_boot.log.
( cd "$REPO/sound_algo/data_only" && MATRIX_ONLY=1 nohup script -q /tmp/sc_boot.log "$SCLANG" boot.scd >/dev/null 2>&1 & )
sleep 32

# 3) pose pipeline (iPhone USB HEVC -> MediaPipe -> OSC). Emits /pose/hands,
#    /pose/center and /pose/sho_span -> matrix capture-modulation sources, and
#    shows a live visual of the tracked pose.
nohup "$PY" -m data_only_viz.main --pose --iphone-usb > /tmp/concert_viz.log 2>&1 &
disown
sleep 11

# 4) (matrix mode: no "morceau" button — the matrix is driven from the web control
#    surface below; the floating concert panel is intentionally not started.)

# 5) web OSC control surface server (browser drives the matrix + patterns).
#    Only if its deps are installed (cd web_realart && npm install once). Reachable
#    at http://supra-m1.local:4400/control/ from any LAN device.
if [ -d "$REPO/web_realart/node_modules" ]; then
    ( cd "$REPO/web_realart" && PATH=/opt/homebrew/bin:$PATH nohup node server.js > /tmp/websrv.log 2>&1 & )
fi

# 6) load a matrix preset and start the playhead (the matrix equivalent of
#    switching to a scene). Skipped if MATRIX_PRESET is empty.
if [ -n "$MATRIX_PRESET" ]; then
    "$PY" -c "from pythonosc.udp_client import SimpleUDPClient; SimpleUDPClient('127.0.0.1',57121).send_message('/matrix/load','$MATRIX_PRESET')"
    sleep 1
fi
"$PY" -c "from pythonosc.udp_client import SimpleUDPClient; SimpleUDPClient('127.0.0.1',57121).send_message('/matrix/play',[])"
sleep 1

notify "Matrice lancee ($MATRIX_PRESET). Control: supra-m1.local:4400/control/ (onglet MATRICE)"
