#!/bin/zsh
# SuperCollider engine for the concert, run in Terminal (gives sclang the
# controlling TTY it needs to boot scsynth). Opened by launch_concert.sh via
# `open` (no Automation/TCC permission needed, unlike `osascript tell Terminal`).
cd ~/Documents/Projets/AV-Live/sound_algo/data_only
/Applications/SuperCollider.app/Contents/MacOS/sclang boot.scd 2>&1 | tee /tmp/sc_boot.log
