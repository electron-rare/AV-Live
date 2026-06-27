#!/bin/zsh
# AV-Live Concert launcher.
# Boots the full iPhone-USB concert stack in one shot:
#   iPhone ARBodyTracker (camera + ARKit skeleton over USB)
#   -> data_only_viz pose pipeline (HEVC decode + MediaPipe + mirror + OSC)
#   -> SuperCollider engine (body-play boot: concert + 13 gestures + 11 morceaux)
#   -> switch to the \concert scene.
# Used as the executable of "AV-Live Concert.app" (double-click to start).
# Re-running restarts cleanly (it kills any prior stack first).
set -u

REPO="$HOME/Documents/Projets/AV-Live"
DEV="AC1CDE5F-DDC4-5B2C-80D7-9953D8ABA0AC"   # iPhone 16 Pro (xcrun devicectl list devices)
export PATH=/opt/homebrew/bin:$PATH
export MEDIAPIPE_DELEGATE=cpu
export POSE_FILTER=median+kalman+lookahead+ik+arkit_fuse
# CONCERT_MIRROR=0 in the environment disables the video mirror.

PY="$REPO/data_only_viz/.venv/bin/python"
SCLANG="/Applications/SuperCollider.app/Contents/MacOS/sclang"

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

# 2) SuperCollider engine (boots to body-play; loads concert + gestures + morceaux).
#    sclang needs a controlling TTY to boot scsynth reliably -> run boot_sc.command
#    in Terminal via `open` (proven; needs no Automation/TCC permission, unlike
#    `osascript tell Terminal`). Launched FIRST so the viz can end up frontmost.
open "$REPO/launcher/concert/boot_sc.command"
sleep 32

# 3) pose pipeline (iPhone USB HEVC -> MediaPipe -> mirror -> OSC). Launched LAST:
#    its window self-activates frontmost + KEY, so its keyboard handler captures
#    Space = next morceau. (The local NSEvent monitor only fires when this window
#    is key; the global monitor needs Input Monitoring permission. Keeping the viz
#    frontmost is the reliable path -- click it to refocus if Space stops working.)
nohup "$PY" -m data_only_viz.main --pose --iphone-usb > /tmp/concert_viz.log 2>&1 &
disown
sleep 11

# 4) switch to the concert scene
"$PY" -c "from pythonosc.udp_client import SimpleUDPClient; SimpleUDPClient('127.0.0.1',57121).send_message('/control/doScene','concert')"
sleep 1

notify "Concert lance. Espace = morceau suivant. Bras croises = morceau au hasard."
