#!/usr/bin/env python3
"""Generate matrix preset .matrix files for the AV-Live matrix arranger.

Each preset is a 16-voice x 32-bar grid of colors 0-6, written as an SC-
interpretable nested-array literal (read by ~matLoadFile in matrix.scd).

These are NEW hand-authored arrangements *inspired by* the character of the 14
data_only concert morceaux (the morceaux themselves use a different instrument
set and have no bar structure, so they can't be transcribed -- see the matrix
analysis). They are editable starting points: load one, tweak, save your own.

Voice row order MUST match ~matVoices in matrix.scd:
  kick hats clap perc sub acid arp lead stab pad ride rim tom reese bells sweep
Colors: 0 off | 1 base | 2 double-time(denser) | 3 oct+ | 4 half-time(sparse)
        5 oct- | 6 accent. (3/5 are ~base until launchpad reads \\octave.)
Run:  python3 generate_presets.py   (writes *.matrix next to this script)
"""
import os

VOICES = ["kick", "hats", "clap", "perc", "sub", "acid", "arp", "lead",
          "stab", "pad", "ride", "rim", "tom", "reese", "bells", "sweep"]
VI = {n: i for i, n in enumerate(VOICES)}
BARS = 32
HERE = os.path.dirname(os.path.abspath(__file__))


def grid():
    return [[0] * BARS for _ in range(len(VOICES))]


def put(g, voice, a, b, color):
    """Fill voice rows bars a..b inclusive with color (clamped to grid)."""
    for bar in range(max(0, a), min(BARS - 1, b) + 1):
        g[VI[voice]][bar] = color


def build(segments):
    g = grid()
    for (voice, a, b, color) in segments:
        put(g, voice, a, b, color)
    return g


# --- 14 arrangements (intro / build / main / breakdown / drop shape) ----------
# Segment = (voice, startBar, endBar_inclusive, color)

PRESETS = {
    # 01 sparse hypnotic: half-time kick + sustained sub, minimal
    "hypno_drift": [
        ("kick", 0, 31, 4), ("sub", 0, 31, 1),
        ("perc", 16, 31, 4), ("pad", 8, 31, 1),
    ],
    # 02 driving roll: quarter kick, 16th stab(perc), shaker hats
    "hypno_roll": [
        ("kick", 0, 31, 1), ("perc", 4, 31, 2), ("hats", 8, 31, 2),
        ("sub", 8, 31, 1), ("stab", 16, 23, 1), ("perc", 24, 27, 4),
    ],
    # 03 acid line: kick + 16th acid + sub
    "acid_line": [
        ("kick", 0, 31, 1), ("sub", 0, 31, 1), ("acid", 4, 23, 2),
        ("hats", 8, 31, 2), ("acid", 24, 27, 4), ("acid", 28, 31, 2),
    ],
    # 04 acid storm: denser acid, sweep accents on drops
    "acid_storm": [
        ("kick", 0, 31, 1), ("sub", 0, 31, 1), ("acid", 0, 31, 2),
        ("hats", 8, 31, 2), ("clap", 16, 31, 1),
        ("sweep", 15, 15, 6), ("sweep", 31, 31, 6), ("acid", 24, 27, 4),
    ],
    # 05 hard pump: kick + perc 8th + sub rumble
    "hard_pump": [
        ("kick", 0, 31, 1), ("sub", 0, 31, 2), ("perc", 4, 31, 2),
        ("hats", 12, 31, 2), ("clap", 16, 31, 1), ("perc", 24, 27, 4),
    ],
    # 06 hard rave: break kick, stab hoover, sweep crash
    "hard_rave": [
        ("kick", 0, 31, 1), ("clap", 4, 31, 1), ("stab", 8, 23, 1),
        ("hats", 8, 31, 2), ("sweep", 15, 15, 6), ("sweep", 23, 23, 6),
        ("stab", 28, 31, 6),
    ],
    # 07 dub chords: very sparse, half kick + sub + pad chord stabs
    "dub_chords": [
        ("kick", 0, 31, 4), ("sub", 0, 31, 1), ("pad", 0, 31, 1),
        ("stab", 8, 31, 4), ("perc", 16, 31, 4),
    ],
    # 08 dub space: outro -- sub + occasional perc clicks
    "dub_space": [
        ("sub", 0, 31, 1), ("perc", 0, 31, 4), ("pad", 8, 31, 1),
        ("kick", 16, 31, 4),
    ],
    # 09 trance pluck: kick + sub + arp 16ths + lead
    "trance_pluck": [
        ("kick", 0, 31, 1), ("sub", 0, 31, 1), ("arp", 4, 31, 2),
        ("hats", 8, 31, 2), ("lead", 16, 23, 1), ("arp", 24, 27, 4),
        ("lead", 28, 31, 1),
    ],
    # 10 industrial: kick + half stab + perc + sub rumble
    "industrial": [
        ("kick", 0, 31, 1), ("sub", 0, 31, 2), ("stab", 4, 31, 4),
        ("perc", 8, 31, 2), ("hats", 12, 31, 2), ("clap", 16, 31, 1),
    ],
    # 11 detroit: kick + hats + sustained pad + stab
    "detroit": [
        ("kick", 0, 31, 1), ("pad", 0, 31, 1), ("hats", 4, 31, 2),
        ("sub", 8, 31, 1), ("stab", 16, 23, 1), ("stab", 28, 31, 1),
        ("hats", 24, 27, 4),
    ],
    # 12 trance: rich -- kick hats sub lead pad
    "trance": [
        ("kick", 0, 31, 1), ("pad", 0, 31, 1), ("sub", 4, 31, 1),
        ("hats", 8, 31, 2), ("lead", 16, 23, 2), ("arp", 16, 31, 2),
        ("lead", 24, 27, 4), ("lead", 28, 31, 2), ("clap", 16, 31, 1),
    ],
    # 13 psytrance: kick + rolling sub + acid + sweep zaps
    "psytrance": [
        ("kick", 0, 31, 1), ("sub", 0, 31, 2), ("acid", 4, 31, 2),
        ("hats", 8, 31, 2), ("sweep", 15, 15, 6), ("sweep", 31, 31, 6),
        ("acid", 24, 27, 4),
    ],
    # 14 punkcore: kick + clap snare + hats + stab chord + lead
    "punkcore": [
        ("kick", 0, 31, 1), ("clap", 0, 31, 1), ("hats", 4, 31, 2),
        ("stab", 8, 31, 2), ("lead", 16, 23, 2), ("sub", 8, 31, 1),
        ("lead", 28, 31, 6),
    ],
}


def to_sc_literal(g):
    rows = ",\n ".join("[" + ",".join(str(v) for v in row) + "]" for row in g)
    return "[\n " + rows + "\n]\n"


def main():
    for name, segs in PRESETS.items():
        g = build(segs)
        path = os.path.join(HERE, name + ".matrix")
        with open(path, "w") as f:
            f.write(to_sc_literal(g))
        print("wrote", path)
    print(len(PRESETS), "presets generated")


if __name__ == "__main__":
    main()
