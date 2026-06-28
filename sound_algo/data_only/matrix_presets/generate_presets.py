#!/usr/bin/env python3
"""Generate matrix preset files (.matrix) for AV-Live — v2 (22 voices x 64 bars).

Each preset is written as a SuperCollider Event compileString that ~matLoadFile
reads:  ( 'grid': [ <22 rows of 64 ints> ], 'instruments': [ <22 syms> ] )
Cells are 0 (off) or 1-6 (variation colour). Instruments must be valid choices
for their voice (see ~matInstChoices) or they fall back to the default lp_ voice.

Arrangements are section-based across 64 bars so each preset is a real track
with intro / build / rise / drop / plateau / break / outro dynamics.
"""

# --- 22 voices, exact ~matVoices order ---
VOICES = ["kick", "hats", "clap", "perc", "sub", "acid", "arp", "lead",
          "stab", "pad", "ride", "rim", "tom", "reese", "bells", "sweep",
          "melody", "chord", "fx", "snare", "crash", "shaker"]
VI = {v: i for i, v in enumerate(VOICES)}
BARS = 64

# --- sections: code -> (start, length) over 64 bars ---
SECTIONS = {
    "I": (0, 8),    # intro
    "B": (8, 8),    # build
    "R": (16, 8),   # rise / montee
    "D": (24, 8),   # drop
    "P": (32, 16),  # plateau (main)
    "K": (48, 8),   # break
    "O": (56, 8),   # outro
}


def blank():
    return [[0] * BARS for _ in VOICES]


def fill(grid, voice, codes, color=1, step=1, off=0):
    """Set `voice` to `color` on every `step`-th bar of each section in `codes`."""
    vi = VI[voice]
    for c in codes:
        s, n = SECTIONS[c]
        for b in range(s, s + n):
            if (b - s) % step == off:
                grid[vi][b] = color


def hit(grid, voice, bars, color=1):
    """Single accent cells (e.g. a crash on the section downbeat)."""
    vi = VI[voice]
    for b in bars:
        if 0 <= b < BARS:
            grid[vi][b] = color


# Section downbeats (for crashes / fx) and the last bar of build/rise/break
DOWN = [SECTIONS[c][0] for c in "BRDPKO"]
RISE_ENDS = [SECTIONS["B"][0] + SECTIONS["B"][1] - 1,
             SECTIONS["R"][0] + SECTIONS["R"][1] - 1,
             SECTIONS["K"][0] + SECTIONS["K"][1] - 1]


# --- archetypes : fill a grid; return it ---
def arc_four_floor(g, accent_acid=False):
    fill(g, "kick", "BDPO", 1)
    fill(g, "hats", "BRDPO", 1)
    fill(g, "hats", "P", 2)
    fill(g, "clap", "DPO", 1)
    fill(g, "snare", "P", 1, step=4, off=2)
    fill(g, "perc", "RDP", 1)
    fill(g, "shaker", "RDPK", 1)
    fill(g, "sub", "BDPO", 1)
    fill(g, "ride", "P", 1)
    fill(g, "pad", "IBKO", 1)
    fill(g, "chord", "RDP", 1)
    if accent_acid:
        fill(g, "acid", "RDP", 1)
        fill(g, "acid", "P", 6, step=4, off=3)
    hit(g, "crash", DOWN, 1)
    hit(g, "fx", RISE_ENDS, 1)
    return g


def arc_rolling(g):
    fill(g, "kick", "BDPO", 1)
    fill(g, "hats", "IBRDPKO", 1, step=2, off=1)
    fill(g, "rim", "RDP", 1)
    fill(g, "sub", "BDPO", 1)
    fill(g, "reese", "DP", 1)
    fill(g, "pad", "IBKPO", 1)
    fill(g, "bells", "IK", 1)
    fill(g, "perc", "P", 1, step=2)
    fill(g, "shaker", "RDPK", 1)
    hit(g, "fx", RISE_ENDS, 1)
    hit(g, "crash", [SECTIONS["D"][0], SECTIONS["P"][0]], 1)
    return g


def arc_acid(g):
    fill(g, "kick", "BDPO", 1)
    fill(g, "hats", "BRDPO", 1)
    fill(g, "clap", "DP", 1)
    fill(g, "acid", "BRDP", 1)
    fill(g, "acid", "D", 6)
    fill(g, "acid", "P", 1)
    fill(g, "sub", "BDPO", 1)
    fill(g, "perc", "RDP", 1)
    fill(g, "pad", "IKO", 1)
    fill(g, "shaker", "RDP", 1)
    hit(g, "crash", DOWN, 1)
    hit(g, "fx", RISE_ENDS, 1)
    return g


def arc_breaks(g):
    fill(g, "kick", "BDPO", 1, step=4, off=0)
    fill(g, "snare", "BRDPO", 1, step=2, off=1)
    fill(g, "snare", "P", 6, step=4, off=3)
    fill(g, "shaker", "IBRDPKO", 1)
    fill(g, "perc", "RDP", 1, step=2)
    fill(g, "reese", "DP", 1)
    fill(g, "sub", "BDPKO", 1)
    fill(g, "pad", "IK", 1)
    fill(g, "stab", "DP", 1)
    fill(g, "rim", "P", 1, step=2, off=1)
    hit(g, "crash", [SECTIONS["D"][0], SECTIONS["P"][0]], 1)
    hit(g, "fx", RISE_ENDS, 1)
    return g


def arc_electro(g):
    fill(g, "kick", "BDPO", 1, step=2, off=0)
    fill(g, "hats", "BRDPO", 1, step=2, off=1)
    fill(g, "clap", "DP", 1)
    fill(g, "snare", "P", 1, step=4, off=2)
    fill(g, "perc", "RDP", 1)
    fill(g, "sub", "BDPO", 1)
    fill(g, "acid", "DP", 1)
    fill(g, "stab", "RDP", 1)
    fill(g, "melody", "P", 1)
    fill(g, "pad", "IKO", 1)
    fill(g, "shaker", "RDPK", 1)
    hit(g, "crash", DOWN, 1)
    hit(g, "fx", RISE_ENDS, 1)
    return g


def arc_trance(g):
    fill(g, "kick", "BDPO", 1)
    fill(g, "hats", "BRDPO", 1)
    fill(g, "hats", "P", 2)
    fill(g, "clap", "DPO", 1)
    fill(g, "sub", "BDPO", 1)
    fill(g, "reese", "DP", 1)
    fill(g, "pad", "IBRKPO", 1)
    fill(g, "chord", "RDP", 1)
    fill(g, "arp", "BRDP", 1)
    fill(g, "lead", "DP", 1)
    fill(g, "melody", "PK", 1)
    fill(g, "bells", "IK", 1)
    fill(g, "shaker", "RDP", 1)
    hit(g, "crash", DOWN, 1)
    hit(g, "fx", RISE_ENDS + [SECTIONS["R"][0]], 1)
    return g


def arc_ambient(g):
    fill(g, "pad", "IBRDPKO", 1)
    fill(g, "bells", "IRPK", 1)
    fill(g, "sub", "RDP", 1)
    fill(g, "sweep", "IBKO", 1)
    fill(g, "melody", "RP", 1)
    fill(g, "chord", "DP", 1)
    fill(g, "shaker", "DP", 1, step=2)
    fill(g, "kick", "DP", 1, step=4)
    hit(g, "fx", [0, SECTIONS["P"][0]], 1)
    return g


def arc_industrial(g):
    fill(g, "kick", "BDPO", 6)
    fill(g, "hats", "BRDPO", 1)
    fill(g, "clap", "DP", 1)
    fill(g, "snare", "P", 6, step=4, off=2)
    fill(g, "perc", "RDP", 6)
    fill(g, "tom", "RD", 1, step=2)
    fill(g, "sub", "BDPO", 1)
    fill(g, "reese", "DP", 1)
    fill(g, "stab", "DP", 1)
    fill(g, "sweep", "IBK", 1)
    fill(g, "shaker", "RDP", 1)
    hit(g, "crash", DOWN, 1)
    hit(g, "fx", RISE_ENDS, 1)
    return g


# --- instrument kits (valid per-voice choices only) ---
K_909 = {"kick": "tr909_kick", "hats": "tr909_hat", "clap": "tr909_clap",
         "ride": "tr909_ride", "snare": "lp_snare", "crash": "lp_crash",
         "shaker": "tr909_hat"}
K_808 = {"kick": "tr808_kick", "hats": "tr808_hat", "clap": "tr808_clap",
         "perc": "tr808_cowbell", "snare": "lp_snare", "crash": "lp_crash",
         "shaker": "tr808_hat"}
K_303 = {"acid": "tb303"}
K_SAW = {"lead": "supersaw", "chord": "juno", "arp": "supersaw", "melody": "supersaw"}
K_MOOG = {"sub": "minimoog", "reese": "minimoog", "lead": "ms20"}
K_SP = {"kick": "sp1200", "perc": "sp1200", "snare": "lp_snare", "shaker": "sp1200"}


def kit(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


# --- preset table : name -> (archetype_fn, instrument kit) ---
PRESETS = {
    # ---- 16 updated classics (now 22x64 w/ machines + section arcs) ----
    "techno_drive":     (arc_four_floor, kit(K_909, {"sub": "lp_sub", "chord": "juno"})),
    "acid_journey":     (arc_acid,       kit(K_909, K_303)),
    "trance_euphoria":  (arc_trance,     kit(K_909, K_SAW)),
    "psytrance_roll":   (arc_rolling,    kit(K_909, {"reese": "minimoog", "acid": "tb303"})),
    "detroit_soul":     (arc_four_floor, kit(K_909, {"chord": "juno", "stab": "juno", "pad": "juno"})),
    "industrial_grind": (arc_industrial, kit({"kick": "do_quake_sub", "perc": "do_strike", "tom": "do_strike", "stab": "ms20"})),
    "hardcore_punk":    (arc_industrial, kit(K_909, {"stab": "ms20", "reese": "ms20"})),
    "dub_techno":       (arc_rolling,    kit(K_909, {"chord": "juno", "pad": "juno", "sub": "lp_sub"})),
    "breakbeat":        (arc_breaks,     kit(K_909, {"snare": "tr909_clap", "reese": "minimoog"})),
    "minimal_hypno":    (arc_rolling,    kit(K_909, {"rim": "tr808_cowbell"})),
    "ambient_intro":    (arc_ambient,    kit({"pad": "juno", "bells": "dx7", "melody": "supersaw", "sweep": "lp_sweep"})),
    "peak_drop":        (arc_four_floor, kit(K_909, K_SAW, K_303)),
    "rave_stab":        (arc_four_floor, kit(K_909, {"stab": "supersaw", "chord": "juno"})),
    "tribal_perc":      (arc_breaks,     kit(K_808, {"tom": "lp_tom"})),
    "bass_science":     (arc_breaks,     kit(K_909, K_MOOG, {"snare": "tr909_clap"})),
    "melodic_builder":  (arc_trance,     kit(K_909, K_SAW, {"pad": "juno", "bells": "dx7"})),

    # ---- new : electro / EBM / synthwave ----
    "electro_808":      (arc_electro,    kit(K_808, {"acid": "tb303", "stab": "ms20", "melody": "dx7"})),
    "ebm_body":         (arc_electro,    kit(K_909, {"sub": "dx7", "reese": "ms20", "stab": "ms20", "melody": "ms20"})),
    "synthwave_drive":  (arc_trance,     kit({"kick": "tr808_kick", "hats": "tr808_hat", "clap": "tr808_clap"}, {"lead": "supersaw", "chord": "juno", "pad": "juno", "melody": "juno", "bells": "dx7"})),
    "electro_funk":     (arc_electro,    kit(K_808, {"stab": "sh101", "melody": "sh101"})),

    # ---- new : DnB / jungle / footwork ----
    "jungle_amen":      (arc_breaks,     kit(K_SP, {"snare": "lp_snare", "reese": "minimoog", "sub": "lp_sub"})),
    "dnb_roller":       (arc_breaks,     kit(K_909, {"snare": "tr909_clap", "reese": "ms20", "sub": "minimoog"})),
    "footwork_chop":    (arc_breaks,     kit(K_808, {"snare": "lp_snare", "sub": "tr808_kick"})),
    "neuro_reese":      (arc_breaks,     kit(K_SP, {"reese": "ms20", "sub": "minimoog", "stab": "ms20"})),

    # ---- new : melodic techno / progressive ----
    "melodic_deep":     (arc_trance,     kit(K_909, {"lead": "ms20", "chord": "juno", "pad": "juno", "arp": "supersaw", "sub": "minimoog"})),
    "progressive_lift": (arc_trance,     kit(K_909, K_SAW, {"reese": "minimoog", "melody": "supersaw"})),
    "hypnotic_arp":     (arc_rolling,    kit(K_909, {"arp": "supersaw", "chord": "juno", "reese": "minimoog"})),
    "schranz_drive":    (arc_industrial, kit(K_909, {"stab": "tb303", "acid": "tb303"})),
}


def to_sc(arc_fn, instkit):
    g = blank()
    arc_fn(g)
    insts = [instkit.get(v, "default") for v in VOICES]
    rows = ",\n".join("[" + ",".join(str(c) for c in row) + "]" for row in g)
    isyms = ", ".join("\\" + s for s in insts)
    return "(\n'grid': [\n%s\n],\n'instruments': [ %s ]\n)\n" % (rows, isyms)


def main():
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    for name, (arc_fn, instkit) in PRESETS.items():
        with open(os.path.join(here, name + ".matrix"), "w") as f:
            f.write(to_sc(arc_fn, instkit))
    print("wrote %d presets (22 voices x %d bars)" % (len(PRESETS), BARS))


if __name__ == "__main__":
    main()
