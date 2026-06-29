#!/usr/bin/env python3
"""Generate matrix preset files (.matrix) for AV-Live -- v3 (22 voices x 64 bars).

Each preset is a SuperCollider Event compileString that ~matLoadFile reads:
  ( 'grid':        [ <22 rows of 64 ints> ],
    'instruments': [ <22 syms> ],
    'colorDefs':   [ <22 entries: nil OR [6 color Events]> ] )

Grid cells are 0 (off) or 1-6 (variation colour, semantics below). Instruments
must be valid for their voice (~matInstChoices) or ~matLoadFile nils them back to
the base lp_ voice -- so this generator VALIDATES every kit at build time.

v3 deep refactor for style fidelity:
  1. instrument kits validated against ~matInstChoices (no silent fallbacks).
  2. per-style melodies via colorDefs[voice][color].steps (degree+vel, replaces
     the shared base lp_ riff). NB: step mode builds a standalone Pbind, so any
     voice carrying steps MUST also carry a concrete instrument -- enforced here.
  3. the 6 variation colours are actually used (build rolls, drop octave lifts,
     break half-time / octave-down) instead of a monochrome wall of colour 1.

Colour semantics (matrix.scd ~matDefaultColorDefs):
  1 base | 2 double-time | 3 octave+ | 4 half-time | 5 octave- | 6 accent roll
In STEP mode the stretch field is ignored (dur fixed to 1/16) so colours 2/4 only
matter for rhythmic (overlay) voices; melodic voices use 1/3/5/6 (octave+accent).
"""

# --- 22 voices, exact ~matVoices order ---
VOICES = ["kick", "hats", "clap", "perc", "sub", "acid", "arp", "lead",
          "stab", "pad", "ride", "rim", "tom", "reese", "bells", "sweep",
          "melody", "chord", "fx", "snare", "crash", "shaker"]
VI = {v: i for i, v in enumerate(VOICES)}
BARS = 64

# --- per-voice valid instrument choices (mirror of matrix.scd ~matInstChoices) ---
INST_CHOICES = {
    "kick":  ["lp_kick", "tr909_kick", "tr808_kick", "sp1200", "do_kick", "do_quake_sub"],
    "hats":  ["lp_hat", "tr909_hat", "tr808_hat", "sp1200", "do_hat"],
    "clap":  ["lp_clap", "tr909_clap", "tr808_clap", "sp1200", "lp_rim"],
    "perc":  ["lp_perc", "tr808_cowbell", "sp1200", "akai_s", "do_strike"],
    "sub":   ["lp_sub", "sh101", "minimoog", "system100", "lp_reese"],
    "acid":  ["lp_acid", "tb303", "ms20", "system100", "lp_pluck"],
    "arp":   ["lp_pluck", "tb303", "supersaw", "juno", "do_strike"],
    "lead":  ["lp_pluck", "ms20", "supersaw", "do_plane", "sh101"],
    "stab":  ["lp_pluck", "ms20", "supersaw", "tb303", "lp_acid"],
    "pad":   ["lp_pad", "juno", "supersaw", "ms20", "lp_reese"],
    "ride":  ["lp_ride", "tr909_ride", "lp_hat", "do_hat"],
    "rim":   ["lp_rim", "tr808_cowbell", "tr909_clap", "sp1200"],
    "tom":   ["lp_tom", "sp1200", "do_strike", "do_quake_sub"],
    "reese": ["lp_reese", "ms20", "minimoog", "system100", "supersaw"],
    "bells": ["lp_bells", "dx7", "akai_s", "do_plane"],
    "sweep": ["lp_sweep", "akai_s", "lp_pad", "lp_reese"],
    "melody": ["lp_pluck", "supersaw", "ms20", "sh101", "dx7"],
    "chord": ["lp_pad", "juno", "supersaw", "ms20"],
    "fx":    ["lp_fx", "akai_s", "lp_sweep"],
    "snare": ["lp_snare", "tr909_clap", "tr808_clap", "lp_clap"],
    "crash": ["lp_crash", "tr909_ride", "akai_s"],
    "shaker": ["lp_shaker", "tr909_hat", "tr808_hat"],
}
# default (base) instrument per voice = first valid choice; used when a voice
# carries a custom melody but the kit did not name an instrument for it.
DEFAULT_INST = {v: choices[0] for v, choices in INST_CHOICES.items()}

# voices eligible for custom step-melodies (monophonic). pad/chord/stab stay as
# overlay triads (the base lp_ Pdefs play [0,2,4] chords).
BASE_OCT = {"sub": -1, "reese": -1, "acid": 0, "arp": 1,
            "lead": 1, "melody": 1, "bells": 2}
MELODIC = set(BASE_OCT)
# octave delta carried by each colour (so a melody keeps its register AND the
# colour's transpose intent: 3 = up, 5 = down).
COLOR_OCT_DELTA = {1: 0, 2: 0, 3: 1, 4: 0, 5: -1, 6: 0}

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
DOWN = [SECTIONS[c][0] for c in "BRDPKO"]
RISE_ENDS = [SECTIONS["B"][0] + SECTIONS["B"][1] - 1,
             SECTIONS["R"][0] + SECTIONS["R"][1] - 1,
             SECTIONS["K"][0] + SECTIONS["K"][1] - 1]


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


def recolor(grid, voice, codes, color, step=1, off=0):
    """Recolour only the ON cells of `voice` within `codes` (keeps arrangement)."""
    vi = VI[voice]
    for c in codes:
        s, n = SECTIONS[c]
        for b in range(s, s + n):
            if (b - s) % step == off and grid[vi][b] > 0:
                grid[vi][b] = color


# === colour dynamics: turn a monochrome arrangement into a real arc ==========
def apply_colors(g):
    """Shared dynamics pass: build rolls, drop octave-lift, break half-time."""
    # rising energy: double-time hats + shaker through the rise
    recolor(g, "hats", ["R"], 2)
    recolor(g, "shaker", ["R"], 2)
    # plateau groove variation: double-time hats on the second half, every 2 bars
    s, n = SECTIONS["P"]
    for b in range(s + n // 2, s + n):
        if g[VI["hats"]][b] > 0 and (b % 2 == 1):
            g[VI["hats"]][b] = 2
    # accent-roll fills on the last 2 bars of build & rise
    for v in ["snare", "clap", "perc", "tom", "kick"]:
        for b in (RISE_ENDS[0], RISE_ENDS[1]):
            for bb in (b - 1, b):
                if 0 <= bb < BARS and g[VI[v]][bb] > 0:
                    g[VI[v]][bb] = 6
    # drop lift: octave-up melodic lead voices for the first half of the drop
    ds, dn = SECTIONS["D"]
    for v in ["lead", "acid", "arp"]:
        for b in range(ds, ds + dn // 2):
            if g[VI[v]][b] > 0:
                g[VI[v]][b] = 3
    # break identity (every preset gets a real breakdown):
    #  - deep sub holds under the break, octave-down (colour 5)
    #  - kick drops out for the first half, returns HALF-TIME (colour 4) to rebuild
    #  - any reese present also goes octave-down
    ks, kn = SECTIONS["K"]
    for b in range(ks, ks + kn):
        g[VI["sub"]][b] = 5                       # activate + recolour deep sub
    for b in range(ks, ks + kn // 2):
        g[VI["kick"]][b] = 0                      # silence kick for the breakdown
    for b in range(ks + kn // 2, ks + kn):
        g[VI["kick"]][b] = 4                      # half-time kick rebuild
    recolor(g, "reese", ["K"], 5)
    return g


# === melodic motif library (A-minor relative degrees; 7 = octave-up root) =====
# step = (degree, vel) or None (rest). 16 steps per bar (1/16 grid).
def _m(*steps):
    assert len(steps) == 16, "motif must be 16 steps"
    return list(steps)


N = None
ACID_TECHNO = _m((0, .95), (0, .55), (7, .8), (0, .55), (3, .7), N, (7, .85), (0, .5),
                 (0, .9), (0, .55), (5, .7), (3, .6), (0, .7), (7, .8), (2, .6), (0, .5))
ACID_PSY = _m((0, .9), N, (0, .55), (7, .75), N, (3, .6), N, (0, .5),
              (5, .75), N, (0, .55), (7, .8), N, (3, .6), (2, .6), N)
ACID_HARD = _m((0, .95), (0, .7), (3, .85), (0, .6), (7, .9), (0, .6), (3, .8), (5, .7),
               (0, .95), (0, .7), (3, .85), (0, .6), (10, .9), (7, .8), (5, .75), (3, .7))
ARP_TRANCE = _m((0, .7), (2, .6), (4, .72), (7, .78), (9, .82), (7, .7), (4, .66), (2, .6),
                (0, .7), (4, .66), (7, .78), (9, .82), (11, .86), (9, .8), (7, .72), (4, .66))
ARP_MINIMAL = _m((0, .72), (7, .5), (0, .6), (7, .5), (3, .66), (7, .5), (3, .6), (7, .5),
                 (0, .72), (7, .5), (0, .6), (7, .5), (2, .66), (7, .5), (2, .6), (7, .5))
ARP_HYPNO = _m((0, .7), (4, .6), (7, .72), (4, .6), (2, .68), (5, .6), (9, .74), (5, .6),
               (0, .7), (4, .6), (7, .72), (4, .6), (3, .68), (7, .6), (10, .74), (7, .6))
LEAD_ANTHEM = _m((7, .9), N, N, (9, .85), N, N, (7, .8), N,
                 (4, .82), N, (5, .82), N, (7, .88), N, N, N)
LEAD_DETROIT = _m((4, .8), N, (2, .7), (0, .76), N, (2, .7), (4, .82), N,
                  (7, .86), N, (5, .8), (4, .76), (2, .7), N, (0, .72), N)
LEAD_EBM = _m((0, .88), (0, .6), (3, .82), N, (0, .72), (3, .76), (5, .82), N,
              (0, .88), (0, .6), (3, .82), (2, .7), (0, .72), (7, .86), (5, .8), (3, .72))
LEAD_PROG = _m((0, .82), N, (4, .76), N, (7, .84), N, (4, .74), (2, .68),
               (0, .8), N, (5, .78), N, (9, .86), N, (7, .8), (4, .72))
REESE_DNB = _m((0, .88), N, (0, .6), N, (3, .82), N, (0, .6), N,
               (5, .82), N, (0, .6), N, (7, .86), N, (3, .72), (2, .6))
REESE_NEURO = _m((0, .9), (0, .62), (5, .82), N, (3, .78), N, (7, .88), N,
                 (2, .72), N, (5, .82), (3, .72), (0, .72), N, (7, .82), N)
REESE_ROLL = _m((0, .82), N, (0, .58), (3, .7), N, (0, .58), (5, .72), N,
                (0, .82), N, (0, .58), (7, .74), N, (3, .62), (2, .6), N)
BASS_TECHNO = _m((0, .92), N, (7, .6), N, (0, .85), N, (7, .6), N,
                 (0, .92), N, (7, .6), N, (3, .82), N, (7, .6), N)
BASS_HOUSE = _m(N, (0, .82), N, (0, .7), N, (0, .82), N, (0, .7),
                N, (3, .82), N, (3, .7), N, (2, .82), N, (7, .7))
BASS_DETROIT = _m((0, .9), N, N, (0, .6), (3, .82), N, N, (3, .6),
                  (5, .82), N, N, (5, .6), (2, .8), N, (7, .66), N)
BASS_OCTAVE = _m((0, .92), N, (7, .62), N, (0, .88), N, (7, .62), N,
                 (3, .85), N, (10, .62), N, (3, .85), N, (7, .62), N)
BASS_TRANCE = _m((0, .88), (0, .6), (0, .6), (0, .6), (0, .85), (0, .6), (0, .6), (0, .6),
                 (3, .85), (3, .6), (3, .6), (3, .6), (2, .82), (2, .6), (7, .66), (7, .6))
BASS_SUB_ROOT = _m((0, .92), N, N, N, N, N, N, N,
                   (0, .85), N, N, N, (3, .8), N, N, N)
BASS_DUB = _m((0, .9), N, N, N, (0, .55), N, N, N,
              N, N, (5, .78), N, N, N, N, N)
MELODY_HOUSE = _m((0, .76), (3, .6), (5, .72), (7, .76), (5, .66), (3, .6), (2, .6), (0, .7),
                  (7, .76), (5, .72), (4, .66), (2, .6), (0, .7), (2, .6), (3, .6), (5, .66))
MELODY_SYNTH = _m((0, .8), N, (3, .68), (5, .74), N, (7, .8), N, (5, .7),
                  (4, .76), N, (2, .66), (0, .72), N, (3, .66), N, (7, .76))
MELODY_AMBIENT = _m((7, .6), N, N, N, (5, .56), N, N, N,
                    (4, .58), N, N, N, (2, .54), N, (0, .56), N)
MELODY_FUNK = _m((0, .8), (0, .6), (3, .74), N, (5, .8), N, (3, .7), (5, .74),
                 (7, .82), N, (5, .74), (3, .68), (2, .7), N, (0, .72), N)
BELLS_SPARSE = _m((7, .68), N, N, N, (4, .6), N, N, N,
                  (5, .64), N, N, N, (2, .6), N, (0, .6), N)
BELLS_DX7 = _m((0, .6), N, (4, .6), N, (7, .7), N, (9, .64), N,
               (7, .6), N, (4, .56), N, (2, .56), N, (0, .6), N)


# === rhythmic archetypes : fill a grid; return it ===========================
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


# --- per-preset "extra" passes: activate a style's signature melodic voice ---
def ex_acid_roll(g):
    fill(g, "acid", "BRDP", 1)
    fill(g, "acid", "P", 6, step=4, off=3)


def ex_arp(g):
    fill(g, "arp", "BRDP", 1)
    fill(g, "arp", "P", 1)


def ex_lead(g):
    fill(g, "lead", "DP", 1)


def ex_tribal(g):
    fill(g, "tom", "RDP", 1, step=2, off=0)
    fill(g, "tom", "P", 1, step=2, off=1)
    fill(g, "perc", "BRDP", 1)


# --- instrument kits (valid per-voice choices only; validated below) ---
K_909 = {"kick": "tr909_kick", "hats": "tr909_hat", "clap": "tr909_clap",
         "ride": "tr909_ride", "snare": "lp_snare", "crash": "lp_crash",
         "shaker": "tr909_hat"}
K_808 = {"kick": "tr808_kick", "hats": "tr808_hat", "clap": "tr808_clap",
         "perc": "tr808_cowbell", "snare": "lp_snare", "crash": "lp_crash",
         "shaker": "tr808_hat"}
K_303 = {"acid": "tb303"}
K_SAW = {"lead": "supersaw", "chord": "juno", "arp": "supersaw", "melody": "supersaw"}
K_MOOG = {"sub": "minimoog", "reese": "minimoog", "lead": "ms20"}
K_SP = {"kick": "sp1200", "perc": "sp1200", "snare": "lp_snare"}  # fix: shaker sp1200 was invalid


def kit(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


# --- preset table : name -> (archetype_fn, kit, melodies, extra_fn|None) ---
def ff(accent_acid=False):
    return lambda g: arc_four_floor(g, accent_acid=accent_acid)


PRESETS = {
    # ---- four-on-the-floor : techno / house / detroit / rave -------------
    "techno_drive":     (arc_four_floor, kit(K_909, {"sub": "lp_sub", "chord": "juno"}),
                         {"sub": BASS_TECHNO}, None),
    "detroit_soul":     (arc_four_floor, kit(K_909, {"chord": "juno", "stab": "supersaw", "pad": "juno"}),
                         {"sub": BASS_DETROIT}, None),
    "peak_drop":        (ff(True), kit(K_909, K_SAW, K_303),
                         {"sub": BASS_OCTAVE, "acid": ACID_TECHNO}, ex_lead),
    "rave_stab":        (arc_four_floor, kit(K_909, {"stab": "supersaw", "chord": "juno"}),
                         {"sub": BASS_TECHNO}, None),
    "dub_techno":       (arc_rolling, kit(K_909, {"chord": "juno", "pad": "juno", "sub": "lp_sub"}),
                         {"sub": BASS_DUB, "reese": REESE_ROLL}, None),

    # ---- acid : 303 lines ------------------------------------------------
    "acid_journey":     (arc_acid, kit(K_909, K_303),
                         {"acid": ACID_TECHNO, "sub": BASS_TECHNO}, None),
    "schranz_drive":    (arc_industrial, kit(K_909, {"stab": "tb303", "acid": "tb303"}),
                         {"acid": ACID_HARD, "sub": BASS_OCTAVE, "reese": REESE_NEURO}, ex_acid_roll),

    # ---- trance / melodic / progressive ----------------------------------
    "trance_euphoria":  (arc_trance, kit(K_909, K_SAW),
                         {"arp": ARP_TRANCE, "lead": LEAD_ANTHEM, "sub": BASS_TRANCE,
                          "melody": MELODY_HOUSE, "bells": BELLS_DX7}, None),
    "melodic_builder":  (arc_trance, kit(K_909, K_SAW, {"pad": "juno", "bells": "dx7"}),
                         {"arp": ARP_TRANCE, "lead": LEAD_PROG, "sub": BASS_TRANCE,
                          "melody": MELODY_SYNTH, "bells": BELLS_DX7}, None),
    "melodic_deep":     (arc_trance, kit(K_909, {"lead": "ms20", "chord": "juno", "pad": "juno",
                                                 "arp": "supersaw", "sub": "minimoog"}),
                         {"arp": ARP_HYPNO, "lead": LEAD_DETROIT, "sub": BASS_DETROIT,
                          "reese": REESE_ROLL, "melody": MELODY_AMBIENT, "bells": BELLS_SPARSE}, None),
    "progressive_lift": (arc_trance, kit(K_909, K_SAW, {"reese": "minimoog", "melody": "supersaw"}),
                         {"arp": ARP_TRANCE, "lead": LEAD_PROG, "sub": BASS_TRANCE,
                          "reese": REESE_ROLL, "melody": MELODY_SYNTH, "bells": BELLS_DX7}, None),
    "hypnotic_arp":     (arc_rolling, kit(K_909, {"arp": "supersaw", "chord": "juno", "reese": "minimoog"}),
                         {"arp": ARP_HYPNO, "sub": BASS_SUB_ROOT, "reese": REESE_ROLL,
                          "bells": BELLS_SPARSE}, ex_arp),

    # ---- psy / rolling / minimal -----------------------------------------
    "psytrance_roll":   (arc_rolling, kit(K_909, {"reese": "minimoog", "acid": "tb303"}),
                         {"acid": ACID_PSY, "sub": BASS_TECHNO, "reese": REESE_ROLL,
                          "bells": BELLS_SPARSE}, ex_acid_roll),
    "minimal_hypno":    (arc_rolling, kit(K_909, {"rim": "tr808_cowbell"}),
                         {"sub": BASS_SUB_ROOT, "reese": REESE_ROLL, "bells": BELLS_SPARSE}, None),

    # ---- breaks / DnB / jungle / footwork --------------------------------
    "breakbeat":        (arc_breaks, kit(K_909, {"snare": "tr909_clap", "reese": "minimoog"}),
                         {"reese": REESE_DNB, "sub": BASS_SUB_ROOT}, None),
    "bass_science":     (arc_breaks, kit(K_909, K_MOOG, {"snare": "tr909_clap"}),
                         {"reese": REESE_NEURO, "sub": BASS_OCTAVE}, None),
    "jungle_amen":      (arc_breaks, kit(K_SP, {"snare": "lp_snare", "reese": "minimoog", "sub": "lp_sub"}),
                         {"reese": REESE_DNB, "sub": BASS_SUB_ROOT}, None),
    "dnb_roller":       (arc_breaks, kit(K_909, {"snare": "tr909_clap", "reese": "ms20", "sub": "minimoog"}),
                         {"reese": REESE_DNB, "sub": BASS_OCTAVE}, None),
    "footwork_chop":    (arc_breaks, kit(K_808, {"snare": "lp_snare", "sub": "minimoog"}),
                         {"reese": REESE_ROLL, "sub": BASS_TECHNO}, None),
    "neuro_reese":      (arc_breaks, kit(K_SP, {"reese": "ms20", "sub": "minimoog", "stab": "ms20"}),
                         {"reese": REESE_NEURO, "sub": BASS_OCTAVE}, None),
    "tribal_perc":      (arc_breaks, kit(K_808, {"tom": "lp_tom"}),
                         {"sub": BASS_SUB_ROOT, "reese": REESE_ROLL}, ex_tribal),

    # ---- electro / EBM / synthwave ---------------------------------------
    "electro_808":      (arc_electro, kit(K_808, {"acid": "tb303", "stab": "ms20", "melody": "dx7"}),
                         {"acid": ACID_TECHNO, "sub": BASS_OCTAVE, "melody": MELODY_SYNTH}, None),
    "ebm_body":         (arc_electro, kit(K_909, {"sub": "minimoog", "reese": "ms20",
                                                  "stab": "ms20", "melody": "ms20"}),
                         {"acid": LEAD_EBM, "sub": BASS_OCTAVE, "melody": MELODY_SYNTH}, None),
    "synthwave_drive":  (arc_trance, kit({"kick": "tr808_kick", "hats": "tr808_hat", "clap": "tr808_clap"},
                                         {"lead": "supersaw", "chord": "juno", "pad": "juno",
                                          "melody": "supersaw", "bells": "dx7"}),
                         {"arp": ARP_TRANCE, "lead": LEAD_ANTHEM, "sub": BASS_OCTAVE,
                          "melody": MELODY_SYNTH, "bells": BELLS_DX7}, None),
    "electro_funk":     (arc_electro, kit(K_808, {"stab": "ms20", "melody": "sh101"}),
                         {"acid": ACID_TECHNO, "sub": BASS_HOUSE, "melody": MELODY_FUNK}, None),

    # ---- industrial / hardcore -------------------------------------------
    "industrial_grind": (arc_industrial, kit({"kick": "do_quake_sub", "perc": "do_strike",
                                              "tom": "do_strike", "stab": "ms20"}),
                         {"sub": BASS_OCTAVE, "reese": REESE_NEURO}, None),
    "hardcore_punk":    (arc_industrial, kit(K_909, {"stab": "ms20", "reese": "ms20"}),
                         {"sub": BASS_OCTAVE, "reese": REESE_NEURO}, None),

    # ---- ambient ---------------------------------------------------------
    "ambient_intro":    (arc_ambient, kit({"pad": "juno", "bells": "dx7",
                                           "melody": "supersaw", "sweep": "lp_sweep"}),
                         {"bells": BELLS_SPARSE, "sub": BASS_SUB_ROOT, "melody": MELODY_AMBIENT}, None),
}


# === validation + emission ===================================================
def validate_kit(name, instkit, melodies):
    for v, inst in instkit.items():
        assert v in INST_CHOICES, "%s: unknown voice %r" % (name, v)
        assert inst in INST_CHOICES[v], \
            "%s: %r is not a valid instrument for voice %r (choices: %s)" % (
                name, inst, v, INST_CHOICES[v])
    for v in melodies:
        assert v in MELODIC, "%s: voice %r is not melodic (no step support)" % (name, v)


def emit_step(s):
    if s is None:
        return "nil"
    d, vel = s
    return "(degree:%d, vel:%.2f)" % (int(d), float(vel))


from patterns import patterns_for


# === per-voice mods/poses: demo bindings for a few presets ===================
# Default is [] for every voice.  Only a handful of presets carry demo bindings
# so generated presets exercise the feature without over-designing it.
#
# voiceMods:  voice -> [(source_id, target, depth)]
#   allowed targets: amp/pan/rev for all voices;
#                    cutoff only for perc/acid/arp/lead/stab/pad/reese/melody/chord
# voicePoses: voice -> [(poseId, action)]
#   action is "trigger" or "gate"

VOICE_MODS_DEMO = {
    "techno_drive": {
        "acid": [("bodyVitesse", "cutoff", 0.6)],  # body energy drives acid cutoff
        "lead": [("rHandY",      "rev",    0.4)],   # right hand height -> lead reverb
    },
}

VOICE_POSES_DEMO = {
    "techno_drive": {
        "kick": [("danse", "trigger")],             # danse action retriggers kick
    },
}


def emit_sc_mod_binding(source, target, depth):
    """One SC Event literal: (source: \\src, target: \\tgt, depth: 0.xx)"""
    return "(source: \\%s, target: \\%s, depth: %.2f)" % (source, target, depth)


def emit_sc_pose_binding(pose_id, action):
    """One SC Event literal: (poseId: \\id, action: \\act)"""
    return "(poseId: \\%s, action: \\%s)" % (pose_id, action)


def emit_voicemods(preset_name):
    """22-element list of SC sub-arrays, one per voice (default [])."""
    demos = VOICE_MODS_DEMO.get(preset_name, {})
    parts = []
    for voice in VOICES:
        bindings = demos.get(voice, [])
        if bindings:
            bstr = ", ".join(emit_sc_mod_binding(*b) for b in bindings)
            parts.append("[" + bstr + "]")
        else:
            parts.append("[]")
    return parts


def emit_voiceposes(preset_name):
    """22-element list of SC sub-arrays, one per voice (default [])."""
    demos = VOICE_POSES_DEMO.get(preset_name, {})
    parts = []
    for voice in VOICES:
        bindings = demos.get(voice, [])
        if bindings:
            bstr = ", ".join(emit_sc_pose_binding(*b) for b in bindings)
            parts.append("[" + bstr + "]")
        else:
            parts.append("[]")
    return parts


def emit_colordefs(preset_name):
    """22 entries, each [6 colour Events] = 6 distinct step-patterns per voice.

    Every (voice, colour) carries its own 16-step pattern from patterns.py,
    tinted by the preset's groove family. Melodic voices render at their natural
    octave; drums at octave 0 (the engine ignores pitch for non-pitched voices).
    """
    out = []
    for voice in VOICES:
        pats = patterns_for(voice, preset_name)
        if pats is None:
            out.append("nil")
            continue
        octv = BASE_OCT.get(voice, 0)
        cells = []
        for c in range(6):
            stepstr = "[" + ",".join(emit_step(s) for s in pats[c]) + "]"
            cells.append("(octave:%d, steps:%s)" % (octv, stepstr))
        out.append("[" + ", ".join(cells) + "]")
    return out


def to_sc(name, arc_fn, instkit, melodies, extra):
    # melodic voices carrying steps need a concrete instrument (step mode builds a
    # standalone Pbind with no base \instrument) -> default to the base lp_ synth.
    # all 6 colours of every voice now carry patterns -> every voice plays in
    # step mode, which builds a standalone Pbind with no base \instrument. So
    # every voice needs a concrete instrument (default to the base lp_ synth).
    instkit = dict(instkit)
    for v in VOICES:
        instkit.setdefault(v, DEFAULT_INST[v])
    validate_kit(name, instkit, melodies)

    g = blank()
    arc_fn(g)
    if extra is not None:
        extra(g)
    apply_colors(g)

    insts = [instkit.get(v, "default") for v in VOICES]
    rows = ",\n".join("[" + ",".join(str(c) for c in row) + "]" for row in g)
    isyms = ", ".join("\\" + s for s in insts)
    cds = ",\n".join(emit_colordefs(name))
    vms = ", ".join(emit_voicemods(name))
    vps = ", ".join(emit_voiceposes(name))
    return ("(\n'grid': [\n%s\n],\n'instruments': [ %s ],\n"
            "'colorDefs': [\n%s\n],\n"
            "'voiceMods': [ %s ],\n"
            "'voicePoses': [ %s ]\n)\n" % (rows, isyms, cds, vms, vps))


def main():
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    for name, (arc_fn, instkit, melodies, extra) in PRESETS.items():
        sc = to_sc(name, arc_fn, instkit, melodies, extra)
        with open(os.path.join(here, name + ".matrix"), "w") as f:
            f.write(sc)
    print("wrote %d presets (22 voices x %d bars, melodies + colour arcs)" % (len(PRESETS), BARS))


if __name__ == "__main__":
    main()
