#!/usr/bin/env python3
"""Pattern bank for AV-Live matrix presets — 6 distinct step patterns per voice,
tinted by the preset's groove family.

Each voice's 6 colours become 6 genuinely different 16-step patterns:
  - drums  -> rhythm strings (rest/ghost/soft/normal/accent), degree fixed to 0
  - melodic -> degree+velocity motifs (scale-relative, A-minor by ~lpNote)

A pattern = list of 16 entries, each None (rest) or (degree:int, vel:float).
For drums degree is always 0 (engine ignores pitch for non-pitched voices but
still gates note/rest on the entry). The 6 patterns per (voice, family) are
authored to be musically distinct (base / busier / broken / double / sparse /
fill), not mere octave shifts.

Families (groove flavour, chosen per preset):
  techno house detroit dub acid psy trance prog electro ebm breaks dnb jungle
  footwork industrial ambient
Unknown family falls back to 'default' for each role.
"""

# ---- rhythm DSL: one char per 16th step --------------------------------------
#   '.' rest   'o' ghost(.30)   '-' soft(.50)   'x' normal(.80)   'X' accent(1.0)
_VEL = {".": 0.0, "o": 0.30, "-": 0.50, "x": 0.80, "X": 1.0}


def _rhythm(s):
    """16-char rhythm string -> list of 16 (degree:0,vel) or None."""
    assert len(s) == 16, "rhythm must be 16 chars: %r" % s
    out = []
    for ch in s:
        v = _VEL[ch]
        out.append(None if v == 0.0 else (0, round(v, 2)))
    return out


def _mel(pairs):
    """list of (degree, vel) or None (len 16) -> normalised step list."""
    assert len(pairs) == 16, "melodic motif must be 16 steps"
    return [None if p is None else (int(p[0]), round(float(p[1]), 2)) for p in pairs]


_DRUM_VELS = (0.30, 0.50, 0.80, 1.0)


def _dhit(v):
    return None if v == 0.0 else (0, round(v, 2))


def derive_drum_colors(base):
    """Colours 2-6 from a 16-step drum base (None | (0, vel))."""
    n = len(base)
    busier = [base[i] if base[i] is not None else (_dhit(0.30) if i % 4 == 2 else None)
              for i in range(n)]
    broken = base[-1:] + base[:-1]                       # rotate right 1: same count, displaced
    double = [base[i] if base[i] is not None else (_dhit(0.80) if i % 2 == 0 else None)
              for i in range(n)]
    sparse = [base[i] if (base[i] is not None and ((base[i][1] >= 1.0) or i % 4 == 0)) else None
              for i in range(n)]
    fill = list(base)
    for k, v in enumerate((0.80, 0.80, 1.0, 1.0)):
        fill[n - 4 + k] = _dhit(v)
    return [busier, broken, double, sparse, fill]


def derive_mel_colors(base):
    """Colours 2-6 from a 16-step melodic base (None | (degree, vel))."""
    n = len(base)
    actives = [base[i][0] for i in range(n) if base[i] is not None]
    last_deg = actives[-1] if actives else 0

    def prev_deg(i):
        for j in range(i, -1, -1):
            if base[j] is not None:
                return base[j][0]
        return last_deg

    busier = [base[i] if base[i] is not None else ((prev_deg(i), 0.5) if i % 4 == 2 else None)
              for i in range(n)]
    broken = [((base[i][0] + 7, base[i][1]) if (base[i] is not None and i % 4 == 0) else base[i])
              for i in range(n)]
    double = [base[i] if base[i] is not None else ((prev_deg(i), 0.6) if i % 2 == 0 else None)
              for i in range(n)]
    sparse = [base[i] if (base[i] is not None and i % 4 == 0) else None for i in range(n)]
    fill = list(base)
    for k in range(4):
        fill[n - 4 + k] = (last_deg + k, round(0.6 + 0.1 * k, 2))
    return [busier, broken, double, sparse, fill]


N = None

# =============================================================================
# DRUM PATTERNS  — DRUMS[role][family] = [6 rhythm strings]
# 'default' is the fallback; families override the signature feel.
# =============================================================================
DRUMS = {
    "kick": {
        "default": ["X...x...X...x...", "X...x...X...x..x", "X.....x.X...x...",
                    "X.X.x.X.x.X.x.X.", "X.......X.......", "X...x...X...x.xx"],
        "breaks":  ["X.......x.......", "X.....x...X.....", "X....x..x...X...",
                    "X..x..x...X..x..", "X...........X...", "X.....x...X..xXx"],
        "dnb":     ["X.........x.....", "X.......x.X.....", "X....x....X.....",
                    "X..x......X...x.", "X...............", "X.........X..xXx"],
        "footwork":["X..X..x.X..X..x.", "X..X.X..X..X.X..", "X..X..X..X..X..X",
                    "X.XX..X.X.XX..X.", "X.....X.....X...", "X..X..X.X..XXXXX"],
        "electro": ["X...x.X.x...x...", "X..x..X.x..x..X.", "X...X...x.X.x...",
                    "X.x.X.x.X.x.X.x.", "X.......x.......", "X...x.X.x...xXXx"],
        "ebm":     ["X...X...X...X...", "X..oX..oX..oX..o", "X.X.X.X.X.X.X.X.",
                    "X...X...X...X..X", "X.......X.......", "X...X...X...XXXX"],
        "industrial":["X...X...X...X...", "XX..XX..XX..XX..", "X.X.X.X.X.X.X.X.",
                    "XXXXXXXXXXXXXXXX", "X.......X.......", "X...X...X...XXXX"],
        "ambient": ["X...............", "X.......x.......", "X...........x...",
                    "X.......X.......", "X...............", "x..............."],
    },
    "snare": {
        "default": ["....X.......X...", "....X...o...X...", "....X.......X..o",
                    "....X...x...X...", "............X...", "....X.......XoXX"],
        "breaks":  ["....X.....X.X...", "....X..x..X.....", "....X.....X...x.",
                    "..x.X...x.X.x...", "....X...........", "....X.....X.xXXX"],
        "dnb":     ["....X.........X.", "....X.......X...", "..o.X.....o.X...",
                    "....X...o.X...x.", "....X...........", "....X.......XXXX"],
        "footwork":["....X.......X...", "...XX....X.X....", "....X..X....X..X",
                    "..X.X...X.X.X...", "....X...........", "....X...X.XXXXXX"],
        "industrial":["....X.......X...", "....X...X...X...", "..X.X...X.X.X...",
                    "X.X.X.X.X.X.X.X.", "....X...........", "....X.......XXXX"],
    },
    "clap": {
        "default": ["....x.......x...", "....x.......x..o", "....x...o...x...",
                    "....x.......x.x.", "............x...", "....x.......x.xx"],
        "house":   ["....x.......x...", "....X.......X...", "...xx......xx...",
                    "....x...x...x...", "............X...", "....x.......xxXx"],
    },
    "hats": {
        "default": ["..x...x...x...x.", "x.x.x.x.x.x.x.x.", "..x...x...x...xX",
                    "xxxxxxxxxxxxxxxx", "..x.......x.....", "..x...x...x.xXxX"],
        "techno":  ["..x...x...x...x.", "..X...x...X...x.", "x.x.x.x.x.x.x.x.",
                    "..xX..xX..xX..xX", "..x.......x.....", "x.x.x.x.x.x.xXXX"],
        "breaks":  ["x.x.x.x.x.x.x.x.", "xoxoxoxoxoxoxoxo", "x.xXx.x.x.xXx.x.",
                    "xxxxxxxxxxxxxxxx", "x...x...x...x...", "x.x.x.x.x.xxXXXX"],
        "dnb":     ["xoxoxoxoxoxoxoxo", "x.x.x.x.x.x.x.x.", "..x...x...x...x.",
                    "xxxxxxxxxxxxxxxx", "..x...x...x...x.", "xoxoxoxoxoxxXXXX"],
        "electro": ["..x...x...x...x.", "..X.x.x...X.x.x.", "x.x.x.x.x.x.x.x.",
                    "xxxxxxxxxxxxxxxx", "..x.......x.....", "..x...x...xXxXxX"],
        "ambient": ["......x.........", "..o.......o.....", "............x...",
                    "..x.......x.....", "......o.........", "..o.......o...x."],
    },
    "ride": {
        "default": ["x...x...x...x...", "x.x.x.x.x.x.x.x.", "x...x...x...x..x",
                    "x.x.x.x.x.x.x.xX", "x.......x.......", "x...x...x...xXxX"],
    },
    "perc": {
        "default": ["..x.....x.x.....", "..x...x...x...x.", "...x..x...x..x..",
                    "x.x.x.x.x.x.x.x.", "......x.........", "..x...x..xxXxXx."],
        "tribal":  ["x.xx.x.xx.x.xx.x", "x.x.xx.xx.x.xx.x", "xx.x.xx.xx.x.xx.",
                    "xxxxxxxxxxxxxxxx", "x...x...x...x...", "x.xxXx.xxXx.xXXX"],
        "latin":   ["..x.x..x..x.x..x", "x..x..x.x..x..x.", "..xx..x...xx..x.",
                    "x.x.x.x.x.x.x.x.", "..x.....x.......", "..x.x..xXxXxXXX."],
    },
    "shaker": {
        "default": ["xoxoxoxoxoxoxoxo", "xxxxxxxxxxxxxxxx", "oxoxoxoxoxoxoxox",
                    "x.x.x.x.x.x.x.x.", "o.o.o.o.o.o.o.o.", "xoxoxoxoxoxxXXXX"],
    },
    "rim": {
        "default": ["..x.......x.....", "..x...x...x...x.", "....x.......x...",
                    "x.x.x.x.x.x.x.x.", "..x.............", "..x...x...x.xXxX"],
    },
    "tom": {
        "default": ["............x.x.", "x.....x.....x.x.", "........x...x...",
                    "x.x.x.x.x.x.x.x.", "............x...", "x.x.x.x.xXxXxXXX"],
        "tribal":  ["x..x.x.x..x.x.x.", "x.x..x.xx.x..x.x", "x...x.x.x...x.x.",
                    "xxxxxxxxxxxxxxxx", "x.......x.......", "x.x.xXx.xXxXxXXX"],
    },
    "crash": {
        "default": ["X...............", "X.............X.", "X.......o.......",
                    "X...............", "X...............", "X..............X"],
    },
    "fx": {
        "default": ["X...............", "X...............", "........X.......",
                    "X.......X.......", "X...............", "X..............X"],
    },
    "sweep": {
        "default": ["X...............", "X...............", "X.......X.......",
                    "X...............", "X...............", "X..............."],
    },
}

# =============================================================================
# MELODIC PATTERNS — MEL[role][family] = [6 motifs], motif = 16 (deg,vel)|None
# Degrees are scale-relative (A-minor via ~lpNote); 7 = octave-up root, etc.
# Authored distinct: base / busier / octave / arp / sparse / fill.
# =============================================================================
def _bass(d, vel=0.85):  # helper: single hit
    return (d, vel)


MEL = {
    "sub": {
        "default": [
            _mel([_bass(0),N,N,N,_bass(0,.6),N,N,N,_bass(0),N,N,N,_bass(3,.7),N,N,N]),
            _mel([_bass(0),N,_bass(0,.5),N,_bass(0,.7),N,_bass(0,.5),N,_bass(3,.7),N,_bass(3,.5),N,_bass(2,.7),N,_bass(7,.6),N]),
            _mel([_bass(0),N,_bass(7,.6),N,_bass(0),N,_bass(7,.6),N,_bass(3,.8),N,_bass(7,.6),N,_bass(3,.8),N,_bass(7,.6),N]),
            _mel([_bass(0,.8),_bass(0,.5),_bass(0,.8),_bass(0,.5)]*2 + [_bass(3,.8),_bass(3,.5)]*2 + [_bass(7,.7),_bass(7,.5)]*2),
            _mel([_bass(0,.9),N,N,N,N,N,N,N,_bass(3,.8),N,N,N,N,N,N,N]),
            _mel([_bass(0),N,N,_bass(0,.5),_bass(3,.7),N,N,_bass(3,.5),_bass(5,.7),N,N,_bass(5,.5),_bass(7,.8),N,_bass(2,.6),_bass(0,.6)]),
        ],
        "dub": [
            _mel([_bass(0,.85),N,N,N,N,N,N,N,N,N,_bass(5,.6),N,N,N,N,N]),
            _mel([_bass(0),N,N,N,_bass(0,.5),N,N,N,_bass(3,.7),N,N,N,N,N,N,N]),
            _mel([_bass(0),N,N,N,N,N,N,N,_bass(7,.6),N,N,N,N,N,N,N]),
            _mel([_bass(0,.8),N,N,N,_bass(0,.5),N,N,N,_bass(0,.8),N,N,N,_bass(3,.6),N,N,N]),
            _mel([_bass(0,.85),N,N,N,N,N,N,N,N,N,N,N,N,N,N,N]),
            _mel([_bass(0),N,N,N,_bass(3,.6),N,N,N,_bass(5,.6),N,N,N,_bass(2,.6),N,_bass(7,.5),N]),
        ],
    },
    "reese": {
        "default": [
            _mel([_bass(0),N,_bass(0,.6),N,_bass(3,.8),N,_bass(0,.6),N,_bass(5,.8),N,_bass(0,.6),N,_bass(7,.85),N,_bass(3,.7),_bass(2,.6)]),
            _mel([_bass(0,.85),_bass(0,.6),_bass(5,.8),N,_bass(3,.75),N,_bass(7,.85),N,_bass(2,.7),N,_bass(5,.8),_bass(3,.7),_bass(0,.7),N,_bass(7,.8),N]),
            _mel([_bass(0),N,N,N,_bass(7,.7),N,N,N,_bass(0),N,N,N,_bass(7,.7),N,N,N]),
            _mel([_bass(0,.8),_bass(0,.5)]*4 + [_bass(3,.8),_bass(3,.5)]*2 + [_bass(7,.7),_bass(5,.6),_bass(3,.6),_bass(2,.6)]),
            _mel([_bass(0,.85),N,N,N,N,N,N,N,_bass(5,.7),N,N,N,N,N,N,N]),
            _mel([_bass(0),N,_bass(0,.5),_bass(3,.7),N,_bass(0,.5),_bass(5,.7),N,_bass(0,.5),_bass(7,.75),N,_bass(3,.6),_bass(2,.6),_bass(5,.6),_bass(3,.6),_bass(0,.6)]),
        ],
    },
    "acid": {
        "default": [
            _mel([_bass(0,.9),_bass(0,.5),_bass(7,.8),_bass(0,.5),_bass(3,.7),N,_bass(7,.85),_bass(0,.5),_bass(0,.9),_bass(0,.5),_bass(5,.7),_bass(3,.6),_bass(0,.7),_bass(7,.8),_bass(2,.6),_bass(0,.5)]),
            _mel([_bass(0,.85),N,_bass(0,.5),_bass(7,.7),N,_bass(3,.6),N,_bass(0,.5),_bass(5,.7),N,_bass(0,.5),_bass(7,.75),N,_bass(3,.6),_bass(2,.6),N]),
            _mel([_bass(0,.9),_bass(7,.6),_bass(12,.8),_bass(7,.6)]*2 + [_bass(3,.8),_bass(10,.6),_bass(7,.7),_bass(3,.6),_bass(0,.8),_bass(7,.6),_bass(2,.6),_bass(0,.5)]),
            _mel([(d,v) for d,v in [(0,.9),(0,.6),(3,.7),(0,.6),(7,.8),(0,.6),(3,.7),(5,.6)]*2][:16]),
            _mel([_bass(0,.9),N,N,N,_bass(7,.7),N,N,N,_bass(3,.8),N,N,N,_bass(10,.7),N,N,N]),
            _mel([_bass(0,.95),_bass(0,.6),_bass(3,.8),_bass(0,.6),_bass(7,.9),_bass(0,.6),_bass(3,.8),_bass(5,.7),_bass(0,.95),_bass(7,.7),_bass(10,.8),_bass(7,.7),_bass(12,.9),_bass(7,.7),_bass(3,.7),_bass(0,.7)]),
        ],
        "psy": [
            _mel([_bass(0,.9),N,N,_bass(7,.7),N,N,_bass(3,.6),N,N,_bass(5,.7),N,N,_bass(7,.75),N,N,_bass(2,.6)]),
            _mel([_bass(0,.85),N,_bass(0,.5),N,_bass(7,.7),N,_bass(0,.5),N,_bass(3,.7),N,_bass(0,.5),N,_bass(10,.7),N,_bass(2,.6),N]),
            _mel([_bass(0,.9),_bass(0,.5),N,_bass(7,.7),_bass(0,.5),N,_bass(3,.6),N,_bass(0,.5),_bass(5,.7),N,_bass(0,.5),_bass(7,.75),N,_bass(0,.5),_bass(2,.6)]),
            _mel([_bass(0,.85),_bass(7,.6),_bass(0,.5),_bass(7,.6)]*4),
            _mel([_bass(0,.9),N,N,N,N,N,_bass(7,.7),N,N,N,N,N,_bass(3,.7),N,N,N]),
            _mel([_bass(0,.95),_bass(0,.6),_bass(7,.8),_bass(0,.6),_bass(10,.8),_bass(0,.6),_bass(7,.7),_bass(3,.6)]*2),
        ],
    },
    "arp": {
        "default": [
            _mel([_bass(0,.7),_bass(2,.6),_bass(4,.7),_bass(7,.75),_bass(9,.8),_bass(7,.7),_bass(4,.65),_bass(2,.6)]*2),
            _mel([_bass(0,.7),_bass(4,.65),_bass(7,.75),_bass(11,.8)]*4),
            _mel([_bass(7,.7),_bass(4,.6),_bass(2,.6),_bass(0,.65),_bass(2,.6),_bass(4,.6),_bass(7,.7),_bass(9,.75)]*2),
            _mel([_bass(0,.7),_bass(7,.6),_bass(0,.6),_bass(7,.6),_bass(3,.65),_bass(7,.6),_bass(3,.6),_bass(7,.6)]*2),
            _mel([_bass(0,.7),N,_bass(4,.6),N,_bass(7,.7),N,_bass(9,.7),N,_bass(7,.65),N,_bass(4,.6),N,_bass(2,.6),N,_bass(0,.6),N]),
            _mel([_bass(0,.75),_bass(2,.6),_bass(4,.7),_bass(7,.75),_bass(9,.8),_bass(11,.8),_bass(9,.75),_bass(7,.7),_bass(4,.65),_bass(7,.7),_bass(9,.75),_bass(11,.8),_bass(14,.85),_bass(11,.8),_bass(9,.75),_bass(7,.7)]),
        ],
    },
    "lead": {
        "default": [
            _mel([_bass(7,.9),N,N,_bass(9,.85),N,N,_bass(7,.8),N,_bass(4,.8),N,_bass(5,.8),N,_bass(7,.85),N,N,N]),
            _mel([_bass(0,.8),N,_bass(4,.7),N,_bass(7,.8),N,_bass(9,.8),N,_bass(7,.75),N,_bass(4,.7),N,_bass(2,.7),N,_bass(0,.7),N]),
            _mel([_bass(7,.85),_bass(9,.8),_bass(11,.85),_bass(9,.8)]*2 + [_bass(7,.8),_bass(4,.7),_bass(7,.8),_bass(9,.8),_bass(11,.85),_bass(14,.9),_bass(11,.8),_bass(9,.8)]),
            _mel([_bass(0,.8),N,N,N,_bass(7,.85),N,N,N,_bass(4,.8),N,N,N,_bass(9,.85),N,N,N]),
            _mel([_bass(7,.9),N,N,N,N,N,N,N,_bass(4,.8),N,N,N,N,N,N,N]),
            _mel([_bass(7,.9),_bass(9,.8),_bass(7,.8),_bass(4,.75),_bass(5,.8),_bass(7,.85),_bass(9,.85),_bass(11,.9),_bass(9,.85),_bass(7,.8),_bass(5,.75),_bass(4,.75),_bass(2,.75),_bass(4,.8),_bass(5,.8),_bass(7,.85)]),
        ],
    },
    "stab": {
        "default": [
            _mel([N,N,_bass(0,.8),N]*4),
            _mel([N,N,_bass(0,.8),N,N,N,_bass(0,.7),N,N,N,_bass(3,.8),N,N,N,_bass(2,.7),N]),
            _mel([_bass(0,.8),N,N,N,_bass(0,.8),N,N,N,_bass(3,.8),N,N,N,_bass(3,.8),N,N,N]),
            _mel([N,_bass(0,.7),N,_bass(0,.7)]*4),
            _mel([N,N,N,N,N,N,_bass(0,.8),N,N,N,N,N,N,N,N,N]),
            _mel([N,N,_bass(0,.8),_bass(0,.6),N,N,_bass(3,.8),_bass(3,.6),N,N,_bass(5,.8),_bass(5,.6),N,N,_bass(7,.85),_bass(2,.6)]),
        ],
    },
    "pad": {
        "default": [
            _mel([_bass(0,.6)]+[N]*15),
            _mel([_bass(0,.6),N,N,N,N,N,N,N,_bass(3,.55),N,N,N,N,N,N,N]),
            _mel([_bass(0,.6),N,N,N,_bass(3,.55),N,N,N,_bass(5,.55),N,N,N,_bass(2,.55),N,N,N]),
            _mel([_bass(7,.55)]+[N]*15),
            _mel([_bass(0,.5)]+[N]*15),
            _mel([_bass(0,.6),N,N,N,N,N,N,N,_bass(7,.55),N,N,N,N,N,N,N]),
        ],
    },
    "bells": {
        "default": [
            _mel([_bass(7,.7),N,N,N,_bass(4,.6),N,N,N,_bass(5,.65),N,N,N,_bass(2,.6),N,_bass(0,.6),N]),
            _mel([_bass(0,.6),N,_bass(4,.6),N,_bass(7,.7),N,_bass(9,.65),N,_bass(7,.6),N,_bass(4,.55),N,_bass(2,.55),N,_bass(0,.6),N]),
            _mel([_bass(7,.7),N,_bass(9,.65),N,_bass(11,.7),N,_bass(9,.65),N,_bass(7,.65),N,_bass(4,.6),N,_bass(7,.65),N,_bass(9,.65),N]),
            _mel([_bass(0,.6),N,N,N,N,N,N,N,_bass(7,.65),N,N,N,N,N,N,N]),
            _mel([_bass(7,.7),N,N,N,N,N,N,N,N,N,N,N,N,N,N,N]),
            _mel([_bass(7,.7),_bass(9,.65),_bass(11,.7),_bass(9,.65),_bass(7,.65),_bass(4,.6),_bass(7,.65),_bass(9,.7),_bass(11,.7),_bass(14,.75),_bass(11,.7),_bass(9,.65),_bass(7,.65),_bass(5,.6),_bass(4,.6),_bass(2,.6)]),
        ],
    },
    "melody": {
        "default": [
            _mel([_bass(0,.75),_bass(3,.6),_bass(5,.7),_bass(7,.75),_bass(5,.65),_bass(3,.6),_bass(2,.6),_bass(0,.7),_bass(7,.75),_bass(5,.7),_bass(4,.65),_bass(2,.6),_bass(0,.7),_bass(2,.6),_bass(3,.6),_bass(5,.65)]),
            _mel([_bass(0,.7),N,_bass(2,.6),_bass(4,.65),N,_bass(7,.75),N,_bass(5,.65),_bass(4,.7),N,_bass(2,.6),_bass(0,.65),N,_bass(3,.6),N,_bass(7,.7)]),
            _mel([_bass(7,.75),_bass(9,.7),_bass(11,.75),_bass(9,.7),_bass(7,.7),_bass(5,.65),_bass(4,.65),_bass(2,.6)]*2),
            _mel([_bass(0,.75),N,N,N,_bass(5,.7),N,N,N,_bass(7,.75),N,N,N,_bass(4,.7),N,N,N]),
            _mel([_bass(7,.75),N,N,N,N,N,_bass(4,.65),N,N,N,N,N,_bass(0,.7),N,N,N]),
            _mel([_bass(0,.8),_bass(3,.6),_bass(5,.7),_bass(7,.75),_bass(9,.8),_bass(7,.7),_bass(5,.65),_bass(4,.65),_bass(5,.7),_bass(7,.75),_bass(9,.8),_bass(11,.85),_bass(9,.8),_bass(7,.7),_bass(5,.65),_bass(0,.7)]),
        ],
    },
    "chord": {
        "default": [
            _mel([_bass(0,.6)]+[N]*7+[_bass(3,.6)]+[N]*7),
            _mel([_bass(0,.6),N,N,N,_bass(3,.6),N,N,N,_bass(5,.6),N,N,N,_bass(2,.6),N,N,N]),
            _mel([N,N,_bass(0,.65),N]*4),
            _mel([_bass(0,.6)]+[N]*15),
            _mel([_bass(5,.55)]+[N]*15),
            _mel([_bass(0,.6),N,N,N,_bass(2,.6),N,N,N,_bass(3,.6),N,N,N,_bass(5,.6),N,N,N]),
        ],
    },
}

# preset name -> (drum family, melodic family)
PRESET_FAMILY = {
    "techno_drive": ("techno", "default"), "detroit_soul": ("house", "default"),
    "peak_drop": ("techno", "default"), "rave_stab": ("techno", "default"),
    "dub_techno": ("techno", "dub"),
    "acid_journey": ("techno", "default"), "schranz_drive": ("industrial", "default"),
    "trance_euphoria": ("techno", "default"), "melodic_builder": ("techno", "default"),
    "melodic_deep": ("techno", "default"), "progressive_lift": ("techno", "default"),
    "hypnotic_arp": ("techno", "default"),
    "psytrance_roll": ("techno", "psy"), "minimal_hypno": ("techno", "default"),
    "breakbeat": ("breaks", "default"), "bass_science": ("breaks", "default"),
    "jungle_amen": ("breaks", "default"), "dnb_roller": ("dnb", "default"),
    "footwork_chop": ("footwork", "default"), "neuro_reese": ("dnb", "default"),
    "tribal_perc": ("breaks", "default"),
    "electro_808": ("electro", "default"), "ebm_body": ("ebm", "default"),
    "synthwave_drive": ("electro", "default"), "electro_funk": ("electro", "default"),
    "industrial_grind": ("industrial", "default"), "hardcore_punk": ("industrial", "default"),
    "ambient_intro": ("ambient", "default"),
}

DRUM_VOICES = {"kick", "hats", "clap", "snare", "perc", "shaker", "ride", "rim",
               "tom", "crash", "fx", "sweep"}


def _pick(bank, role, family):
    """Return the 6-pattern list for role, preferring family then 'default'."""
    rolebank = bank.get(role)
    if rolebank is None:
        return None
    return rolebank.get(family) or rolebank.get("default")


def patterns_for(voice, preset_name):
    """Return 6 step-patterns (one per colour 1-6) for `voice` in `preset_name`,
    or None if the voice has no bank (caller leaves it on overlay default)."""
    dfam, mfam = PRESET_FAMILY.get(preset_name, ("default", "default"))
    if voice in DRUM_VOICES:
        strs = _pick(DRUMS, voice, dfam)
        return None if strs is None else [_rhythm(s) for s in strs]
    return _pick(MEL, voice, mfam)
