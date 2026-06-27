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

# 2) SuperCollider engine (boots to body-play; loads concert + gestures + morceaux
#    + launchpad). sclang needs a controlling TTY to boot scsynth reliably -> run it
#    under `script` (gives a pseudo-TTY), detached via nohup. More reliable than
#    `open <Terminal .command>` (no Finder/Terminal race, no GUI-session quirks) and
#    needs no Automation/TCC permission. Log -> /tmp/sc_boot.log.
( cd "$REPO/sound_algo/data_only" && nohup script -q /tmp/sc_boot.log "$SCLANG" boot.scd >/dev/null 2>&1 & )
sleep 32

# 3) pose pipeline (iPhone USB HEVC -> MediaPipe -> mirror -> OSC). Launched LAST:
#    its window self-activates frontmost + KEY, so its keyboard handler captures
#    Space = next morceau. (The local NSEvent monitor only fires when this window
#    is key; the global monitor needs Input Monitoring permission. Keeping the viz
#    frontmost is the reliable path -- click it to refocus if Space stops working.)
nohup "$PY" -m data_only_viz.main --pose --iphone-usb > /tmp/concert_viz.log 2>&1 &
disown
sleep 11

# 4) floating "Morceau suivant" button panel (non-activating: keeps the viz the
#    key window so Space still works, while the button click changes morceau
#    regardless of focus).
nohup "$PY" "$REPO/launcher/concert/concert_control.py" > /tmp/concert_control.log 2>&1 &
disown
sleep 1

# 5) web OSC control surface server (browser launches patterns + controls concert).
#    Only if its deps are installed (cd web_realart && npm install once). Reachable
#    at http://supra-m1.local:4400/control/ from any LAN device.
if [ -d "$REPO/web_realart/node_modules" ]; then
    ( cd "$REPO/web_realart" && PATH=/opt/homebrew/bin:$PATH nohup node server.js > /tmp/websrv.log 2>&1 & )
fi

# 6) switch to the concert scene
"$PY" -c "from pythonosc.udp_client import SimpleUDPClient; SimpleUDPClient('127.0.0.1',57121).send_message('/control/doScene','concert')"
sleep 1

notify "Concert lance. Bouton/Espace = morceau. Control: supra-m1.local:4400/control/"
