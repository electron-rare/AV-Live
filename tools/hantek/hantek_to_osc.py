#!/usr/bin/env python3
"""
Hantek 6022BL → OSC bridge.
Lit des blocs d'échantillons via sigrok-cli et envoie chunks OSC à SC.

Usage:
  ./hantek_to_osc.py [--rate 100k] [--samples 1024] [--host 127.0.0.1] [--port 57120]

Prérequis:
  - sigrok-cli installé (brew install sigrok-cli)
  - firmware fx2lafw chargé (lance OpenHantek une fois, OU sigrok-cli scanne 2x)
  - python-osc:  /usr/bin/python3 -m pip install --user python-osc
"""
import argparse, subprocess, sys, struct
from pythonosc.udp_client import SimpleUDPClient

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--rate", default="100k")
    p.add_argument("--samples", type=int, default=1024)
    p.add_argument("--driver", default="hantek-6xxx")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=57120)
    p.add_argument("--addr", default="/scope")
    args = p.parse_args()

    osc = SimpleUDPClient(args.host, args.port)

    cmd = [
        "sigrok-cli", "-d", args.driver,
        "--config", f"samplerate={args.rate}",
        "-O", "binary",
        "--continuous",
        "-C", "CH1,CH2",
    ]
    print(f"[bridge] {' '.join(cmd)} → {args.host}:{args.port}{args.addr}")
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, bufsize=0)

    chunk_bytes = args.samples * 4 * 2  # 2 channels float32
    try:
        while True:
            buf = proc.stdout.read(chunk_bytes)
            if not buf:
                break
            n = len(buf) // 8
            ch1 = struct.unpack(f"{n}f", b"".join(buf[i*8:i*8+4]   for i in range(n)))
            ch2 = struct.unpack(f"{n}f", b"".join(buf[i*8+4:i*8+8] for i in range(n)))
            # Send peak + RMS per channel (compact, SC-friendly)
            def pk(s): return max(abs(min(s)), abs(max(s)))
            def rms(s): return (sum(x*x for x in s)/len(s))**0.5
            osc.send_message(args.addr, [pk(ch1), rms(ch1), pk(ch2), rms(ch2)])
    except KeyboardInterrupt:
        pass
    finally:
        proc.terminate()

if __name__ == "__main__":
    main()
