#!/usr/bin/env python3
"""Generate creative matrix preset .matrix files for the AV-Live matrix arranger.

Each preset is a 16-voice x 32-bar grid of colors 0-6, written as an
SC-interpretable nested-array literal (read by ~matLoadFile in matrix.scd).

These are hand-authored full-kit arrangements with a real 32-bar song shape:
sections (intro / build / drop / break / final) that bring voices in and out,
change density via the colour, and drop fills/accents. All 16 voices are used
across the set; the percussive/textural voices (ride, rim, tom, reese, bells,
sweep) are featured, not left empty.

Voice row order MUST match ~matVoices in matrix.scd:
  0 kick  1 hats  2 clap  3 perc  4 sub   5 acid  6 arp   7 lead
  8 stab  9 pad   10 ride 11 rim  12 tom  13 reese 14 bells 15 sweep
Colours: 0 off | 1 base | 2 double-time (denser) | 3 oct+ | 4 half-time (sparse)
         5 oct- | 6 accent.  (3/5 read ~base until launchpad reads \\octave;
         used on melodic voices to mark octave intent.)
Run:  python3 generate_presets.py
"""
import os

VOICES = ["kick", "hats", "clap", "perc", "sub", "acid", "arp", "lead",
          "stab", "pad", "ride", "rim", "tom", "reese", "bells", "sweep"]
VI = {n: i for i, n in enumerate(VOICES)}
BARS = 32
HERE = os.path.dirname(os.path.abspath(__file__))


def S(a, b, **voices):
    """A section: bars a..b inclusive, each named voice set to its colour."""
    return (a, b, voices)


def build(sections, fills=None):
    g = [[0] * BARS for _ in range(len(VOICES))]
    for (a, b, voices) in sections:
        for name, color in voices.items():
            for bar in range(max(0, a), min(BARS - 1, b) + 1):
                g[VI[name]][bar] = color
    for (name, bar, color) in (fills or []):
        if 0 <= bar < BARS:
            g[VI[name]][bar] = color
    return g


# Section windows used as a loose template (you can override per preset):
#   A 0-7 intro | B 8-15 build | C 16-23 drop | D 24-27 break | E 28-31 final

PRESETS = {}

# 1. Four-on-floor techno, ride-driven, acid stabs on the drop
PRESETS["techno_drive"] = build([
    S(0, 7,   kick=1, sub=1, hats=4),
    S(8, 15,  kick=1, sub=1, hats=2, ride=1, perc=2),
    S(16, 23, kick=1, sub=1, hats=2, ride=1, perc=2, clap=1, stab=1, acid=2),
    S(24, 27, hats=4, pad=1, ride=1),
    S(28, 31, kick=1, sub=1, hats=2, clap=1, acid=2, stab=6, ride=1),
], [("sweep", 7, 6), ("sweep", 15, 6), ("sweep", 27, 6), ("tom", 23, 6)])

# 2. Acid journey on a reese bass, lead octave leaps
PRESETS["acid_journey"] = build([
    S(0, 7,   kick=1, sub=1, acid=1),
    S(8, 15,  kick=1, reese=2, acid=2, hats=2, rim=2),
    S(16, 23, kick=1, reese=2, acid=2, hats=2, ride=1, clap=1, lead=3),
    S(24, 27, acid=4, pad=1, bells=3),
    S(28, 31, kick=1, reese=2, acid=2, hats=2, clap=1, lead=6),
], [("sweep", 7, 6), ("sweep", 15, 6), ("sweep", 23, 6), ("tom", 31, 6)])

# 3. Euphoric trance: supersaw pad + arp + bell motif, big lead on final
PRESETS["trance_euphoria"] = build([
    S(0, 7,   sub=1, pad=1, arp=1, bells=5),
    S(8, 15,  kick=1, sub=1, pad=1, arp=2, hats=2, bells=3),
    S(16, 23, kick=1, sub=1, pad=1, arp=2, hats=2, ride=1, clap=1, lead=2),
    S(24, 27, pad=1, bells=3, arp=1),
    S(28, 31, kick=1, sub=1, pad=1, arp=2, hats=2, lead=6, clap=1),
], [("sweep", 7, 6), ("sweep", 15, 6), ("sweep", 27, 6)])

# 4. Rolling psytrance: triplet-feel sub, 16th acid, tom rolls
PRESETS["psytrance_roll"] = build([
    S(0, 7,   kick=1, sub=2),
    S(8, 15,  kick=1, sub=2, acid=2, hats=2),
    S(16, 23, kick=1, sub=2, acid=2, hats=2, ride=2, perc=2, reese=2),
    S(24, 27, sub=2, acid=4, bells=3),
    S(28, 31, kick=1, sub=2, acid=2, hats=2, perc=2, lead=6),
], [("sweep", 15, 6), ("sweep", 31, 6), ("tom", 22, 6), ("tom", 23, 6)])

# 5. Detroit soul: warm pad, stabs, bell counter-melody, rim shuffle
PRESETS["detroit_soul"] = build([
    S(0, 7,   kick=1, pad=1, sub=1),
    S(8, 15,  kick=1, pad=1, sub=1, hats=2, rim=2),
    S(16, 23, kick=1, pad=1, sub=1, hats=2, ride=1, clap=1, stab=1, bells=3),
    S(24, 27, pad=1, bells=3, hats=4),
    S(28, 31, kick=1, pad=1, sub=1, hats=2, clap=1, stab=6, rim=2),
], [("sweep", 15, 6), ("tom", 31, 6)])

# 6. Industrial grind: reese rumble, metallic stabs, tom-heavy fills
PRESETS["industrial_grind"] = build([
    S(0, 7,   kick=1, reese=1, stab=4),
    S(8, 15,  kick=1, reese=2, stab=4, perc=2, hats=2, rim=2),
    S(16, 23, kick=1, reese=2, stab=2, perc=2, hats=2, tom=2, clap=1, ride=1),
    S(24, 27, reese=1, tom=4, sweep=6),
    S(28, 31, kick=1, reese=2, stab=2, perc=2, clap=1, tom=6),
], [("tom", 14, 6), ("tom", 15, 6), ("sweep", 23, 6)])

# 7. Hardcore punk: driving, snare(clap+rim) backbeat, power-chord stab, lead
PRESETS["hardcore_punk"] = build([
    S(0, 7,   kick=2, sub=1),
    S(8, 15,  kick=2, sub=1, hats=2, clap=1, rim=1),
    S(16, 23, kick=2, sub=1, hats=2, clap=1, rim=1, stab=2, lead=2, ride=2),
    S(24, 27, kick=4, stab=4, sweep=6),
    S(28, 31, kick=2, sub=1, hats=2, clap=1, stab=2, lead=6, tom=6),
], [("tom", 30, 6), ("tom", 31, 6)])

# 8. Dub techno: very sparse, deep sub, spacey stabs/bells, brushed perc
PRESETS["dub_techno"] = build([
    S(0, 7,   kick=4, sub=1, pad=1),
    S(8, 15,  kick=4, sub=1, pad=1, perc=4, rim=4),
    S(16, 23, kick=1, sub=1, pad=1, perc=4, hats=4, stab=4, bells=3),
    S(24, 31, sub=1, pad=1, bells=3, sweep=6),
], [("sweep", 23, 6), ("rim", 31, 6)])

# 9. Breakbeat: syncopated kick variations, ride/perc/tom groove
PRESETS["breakbeat"] = build([
    S(0, 7,   kick=1, sub=1, hats=2),
    S(8, 15,  kick=2, sub=1, hats=2, ride=2, perc=2, clap=1),
    S(16, 23, kick=2, sub=1, hats=2, ride=2, perc=2, clap=1, rim=2, acid=2, tom=2),
    S(24, 27, kick=4, perc=4, sweep=6),
    S(28, 31, kick=2, sub=1, hats=2, perc=2, clap=1, tom=6),
], [("tom", 15, 6), ("tom", 23, 6)])

# 10. Minimal hypno: hypnotic, very few elements, slow evolution
PRESETS["minimal_hypno"] = build([
    S(0, 15,  kick=1, sub=1, rim=2),
    S(8, 23,  perc=2),
    S(16, 31, kick=1, sub=1, rim=2, hats=4, pad=1),
    S(24, 27, kick=4),
], [("bells", 16, 3), ("bells", 24, 3), ("sweep", 23, 6)])

# 11. Ambient intro: no drums, pads/bells/arp/sub wash + riser (opener)
PRESETS["ambient_intro"] = build([
    S(0, 31,  pad=1, sub=1),
    S(8, 23,  bells=3, arp=1),
    S(16, 31, reese=1),
    S(24, 31, sweep=6),
], [("bells", 0, 5), ("bells", 8, 3), ("bells", 16, 5), ("sweep", 31, 6)])

# 12. Peak drop: full kit, everything at the drop -- max energy reference
PRESETS["peak_drop"] = build([
    S(0, 7,   kick=1, sub=1, hats=2, sweep=6),
    S(8, 15,  kick=1, sub=1, hats=2, ride=1, perc=2, clap=1, stab=1),
    S(16, 23, kick=1, sub=1, hats=2, ride=2, perc=2, clap=1, stab=2,
              acid=2, lead=2, arp=2, pad=1, rim=2, tom=2, bells=3, reese=2),
    S(24, 27, pad=1, bells=3, sweep=6, hats=4),
    S(28, 31, kick=1, sub=1, hats=2, ride=2, clap=1, stab=2, acid=2,
              lead=6, tom=6, reese=2),
], [("sweep", 15, 6), ("tom", 23, 6)])

# 13. Rave stab: classic hoover stabs, bells, big claps
PRESETS["rave_stab"] = build([
    S(0, 7,   kick=1, sub=1, stab=4),
    S(8, 15,  kick=1, sub=1, stab=2, hats=2, clap=1),
    S(16, 23, kick=1, sub=1, stab=2, hats=2, clap=1, ride=1, bells=3, sweep=6),
    S(24, 27, stab=4, bells=3),
    S(28, 31, kick=1, sub=1, stab=6, hats=2, clap=1, bells=5),
], [("sweep", 7, 6), ("sweep", 23, 6)])

# 14. Tribal perc: percussion workout -- perc/tom/rim/ride lead, sparse kick
PRESETS["tribal_perc"] = build([
    S(0, 7,   kick=1, perc=2, rim=2),
    S(8, 15,  kick=1, perc=2, rim=2, tom=2, ride=2),
    S(16, 23, kick=1, perc=2, rim=2, tom=2, ride=2, hats=2, sub=1, clap=1),
    S(24, 27, perc=4, tom=4, sweep=6),
    S(28, 31, kick=1, perc=2, rim=2, tom=6, ride=2, clap=1),
], [("tom", 14, 6), ("tom", 15, 6), ("tom", 22, 6), ("tom", 23, 6)])

# 15. Bass science: sub + reese interplay, neuro-ish, sparse top
PRESETS["bass_science"] = build([
    S(0, 7,   kick=1, sub=1),
    S(8, 15,  kick=1, sub=2, reese=2, hats=4),
    S(16, 23, kick=1, sub=2, reese=2, hats=2, perc=2, acid=2, rim=2),
    S(24, 27, reese=4, sub=1, sweep=6),
    S(28, 31, kick=1, sub=2, reese=2, hats=2, perc=2, tom=6),
], [("sweep", 15, 6), ("tom", 23, 6)])

# 16. Melodic builder: arp + lead + bells over pad, long build to a lead peak
PRESETS["melodic_builder"] = build([
    S(0, 7,   pad=1, sub=1, arp=1),
    S(8, 15,  kick=1, pad=1, sub=1, arp=2, hats=2, bells=3),
    S(16, 23, kick=1, pad=1, sub=1, arp=2, hats=2, ride=1, lead=2, stab=1),
    S(24, 27, pad=1, bells=5, arp=1),
    S(28, 31, kick=1, pad=1, sub=1, arp=2, hats=2, lead=6, clap=1, bells=3),
], [("sweep", 7, 6), ("sweep", 15, 6), ("sweep", 27, 6)])


def to_sc_literal(g):
    rows = ",\n ".join("[" + ",".join(str(v) for v in row) + "]" for row in g)
    return "[\n " + rows + "\n]\n"


def main():
    used = set()
    for name, g in PRESETS.items():
        for vi, row in enumerate(g):
            if any(row):
                used.add(VOICES[vi])
        with open(os.path.join(HERE, name + ".matrix"), "w") as f:
            f.write(to_sc_literal(g))
        print("wrote", name + ".matrix")
    print(len(PRESETS), "presets;", len(used), "/ 16 voices used:", sorted(used))
    missing = [v for v in VOICES if v not in used]
    if missing:
        print("WARNING unused voices:", missing)


if __name__ == "__main__":
    main()
