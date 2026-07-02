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


def _dhit(v):
    return None if v == 0.0 else (0, round(v, 2))


def derive_drum_colors(base):
    """Colours 2-6 from a 16-step drum base (None | (0, vel)).
    Transforms operate on the base's own rest/hit lists (alignment-independent):
    busier adds ghost on every other rest of THIS base; sparse keeps the
    strongest half of THIS base's hits — never empty, always < base when >=2 hits.
    broken=rotation, double=even-rest fill, fill=end-roll are unchanged.
    """
    n = len(base)
    rests = [i for i in range(n) if base[i] is None]
    hits  = [i for i in range(n) if base[i] is not None]
    # busier: ghost (0.30) on every other rest of THIS base (adds >=1 when any rest exists)
    busier = list(base)
    for i in rests[::2]:
        busier[i] = _dhit(0.30)
    # broken: rotate right 1 step (same hit count, displaced)
    broken = base[-1:] + base[:-1]
    # double: fill even-position rests with soft hit (unchanged)
    double = [base[i] if base[i] is not None else (_dhit(0.80) if i % 2 == 0 else None)
              for i in range(n)]
    # sparse: keep the STRONGEST half of hits (by vel desc, then position);
    # never empty, always <= base; strictly < base when >=2 hits
    keep = (set(sorted(hits, key=lambda i: (-base[i][1], i))[:max(1, (len(hits) + 1) // 2)])
            if hits else set())
    sparse = [base[i] if i in keep else None for i in range(n)]
    # fill: end-roll (last 4 steps forced active, unchanged)
    fill = list(base)
    for k, v in enumerate((0.80, 0.80, 1.0, 1.0)):
        fill[n - 4 + k] = _dhit(v)
    return [busier, broken, double, sparse, fill]


def derive_mel_colors(base):
    """Colours 2-6 from a 16-step melodic base (None | (degree, vel)).
    Transforms operate on the base's own rest/active lists (alignment-independent):
    busier adds a passing note on every other rest of THIS base; broken
    octave-displaces (+7) every other active note of THIS base; sparse keeps
    the first half of THIS base's active notes — never empty, always < base
    when >=2 notes. double=even-rest fill, fill=ascending run are unchanged.
    """
    n = len(base)
    actives = [i for i in range(n) if base[i] is not None]
    last_deg = base[actives[-1]][0] if actives else 0
    rests = [i for i in range(n) if base[i] is None]

    def prev_deg(i):
        for j in range(i, -1, -1):
            if base[j] is not None:
                return base[j][0]
        return last_deg

    # busier: passing note on every other rest of THIS base (alignment-independent)
    busier = list(base)
    for i in rests[::2]:
        busier[i] = (prev_deg(i), 0.5)
    # broken: octave-displace (+7) every other active note (alignment-independent;
    # displaces >=1 note when any note exists)
    broken = list(base)
    for i in actives[::2]:
        broken[i] = (base[i][0] + 7, base[i][1])
    # double: fill even-position rests with passing note (unchanged)
    double = [base[i] if base[i] is not None else ((prev_deg(i), 0.6) if i % 2 == 0 else None)
              for i in range(n)]
    # sparse: keep the FIRST HALF of active notes (deterministic; never empty,
    # strictly < base when >=2 notes)
    keep = set(actives[:max(1, (len(actives) + 1) // 2)]) if actives else set()
    sparse = [base[i] if i in keep else None for i in range(n)]
    # fill: ascending run on last 4 steps (unchanged)
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

# === SP-C2 hand-authored style families (6 colours each, following the colour-role
# convention base/busier/broken/double/sparse/fill, velocity-humanized). Existing
# families and every `default` stay untouched; these are pure additions. ===

# -- dub mel: deep, sparse, off-beat skank stabs, long rests (A-minor degrees) --
MEL["reese"]["dub"] = [
    _mel([(0,.85),N,N,N,(0,.5),N,N,N,(3,.6),N,N,N,(0,.5),N,N,N]),
    _mel([(0,.85),N,(0,.4),N,(0,.6),N,(3,.45),N,(3,.6),N,(0,.4),N,(0,.55),N,(3,.45),N]),
    _mel([N,N,(0,.7),N,N,(0,.5),N,N,(3,.6),N,N,(0,.45),N,N,(5,.55),N]),
    _mel([(0,.8),N,(0,.5),N,(3,.6),N,(3,.5),N,(5,.6),N,(5,.5),N,(3,.6),N,(0,.5),N]),
    _mel([(0,.7),N,N,N,N,N,N,N,(3,.5),N,N,N,N,N,N,N]),
    _mel([(0,.8),N,(0,.5),(3,.5),(3,.6),(5,.5),(5,.6),(7,.6),(7,.7),N,(5,.5),N,(3,.6),(3,.5),(0,.7),(0,.6)]),
]
MEL["pad"]["dub"] = [
    _mel([(0,.55),N,N,N,N,N,N,N,(3,.5),N,N,N,N,N,N,N]),
    _mel([(0,.55),N,N,N,(7,.45),N,N,N,(3,.5),N,N,N,(7,.45),N,N,N]),
    _mel([N,N,N,(0,.55),N,N,N,(7,.45),N,N,N,(5,.5),N,N,N,(3,.45)]),
    _mel([(0,.55),N,(7,.4),N,(3,.5),N,(10,.4),N,(5,.5),N,(12,.4),N,(7,.5),N,(3,.4),N]),
    _mel([(0,.5),N,N,N,N,N,N,N,N,N,N,N,N,N,N,N]),
    _mel([(0,.55),N,N,N,(3,.5),N,N,N,(5,.55),N,N,N,(7,.6),N,(10,.5),(12,.6)]),
]
MEL["chord"]["dub"] = [
    _mel([N,N,(0,.6),N,N,N,(0,.5),N,N,N,(3,.55),N,N,N,(0,.5),N]),
    _mel([N,N,(0,.6),N,N,(3,.45),(0,.5),N,N,N,(3,.55),N,N,(5,.45),(0,.5),N]),
    _mel([N,(0,.6),N,N,(3,.5),N,N,(5,.45),N,(3,.55),N,N,(7,.5),N,N,(0,.45)]),
    _mel([(0,.6),N,(0,.4),(3,.5),N,(0,.4),(5,.55),N,(0,.4),(7,.5),N,(0,.4),(3,.55),N,(0,.4),(5,.5)]),
    _mel([N,N,(0,.55),N,N,N,N,N,N,N,(3,.5),N,N,N,N,N]),
    _mel([N,N,(0,.6),N,(3,.5),N,(5,.55),N,(7,.6),N,(5,.5),(3,.55),(0,.6),(3,.5),(5,.55),(7,.6)]),
]
MEL["bells"]["dub"] = [
    _mel([(12,.6),N,N,N,N,N,N,N,N,N,(7,.45),N,N,N,N,N]),
    _mel([(12,.6),N,N,N,(7,.4),N,N,N,(10,.5),N,N,N,(7,.4),N,N,N]),
    _mel([N,N,N,(12,.55),N,N,(7,.4),N,N,N,(10,.5),N,N,(5,.4),N,N]),
    _mel([(12,.6),N,(7,.4),N,(10,.5),N,(5,.4),N,(12,.55),N,(7,.4),N,(8,.5),N,(3,.4),N]),
    _mel([(12,.55),N,N,N,N,N,N,N,N,N,N,N,N,N,N,N]),
    _mel([(12,.6),N,(10,.5),N,(7,.5),N,(5,.5),N,(7,.55),N,(10,.5),N,(12,.6),(10,.5),(7,.5),(12,.65)]),
]
MEL["melody"]["dub"] = [
    _mel([N,N,N,N,(7,.6),N,N,N,N,N,N,N,(5,.5),N,N,N]),
    _mel([N,N,(7,.5),N,(7,.6),N,N,(5,.45),N,N,(3,.5),N,(5,.55),N,N,N]),
    _mel([N,(7,.55),N,N,(5,.5),N,N,(3,.45),N,(7,.5),N,N,(10,.5),N,N,(5,.45)]),
    _mel([(7,.6),N,(5,.45),N,(3,.5),N,(5,.45),N,(7,.55),N,(10,.45),N,(7,.5),N,(5,.45),N]),
    _mel([N,N,N,N,(7,.5),N,N,N,N,N,N,N,N,N,N,N]),
    _mel([(7,.6),N,(10,.5),N,(12,.55),N,(10,.5),(7,.5),(5,.55),N,(7,.5),N,(10,.55),(7,.5),(5,.55),(3,.6)]),
]

# -- psy mel: rolling 16th basslines, fast tight arps, minor --
MEL["sub"]["psy"] = [
    _mel([_bass(0,.9),N,N,_bass(0,.5),N,N,_bass(0,.55),N,N,_bass(3,.6),N,N,_bass(0,.55),N,N,_bass(2,.5)]),
    _mel([_bass(0,.9),N,_bass(0,.45),_bass(0,.55),N,_bass(0,.45),_bass(3,.6),N,_bass(0,.45),_bass(0,.55),N,_bass(0,.45),_bass(5,.6),N,_bass(0,.45),_bass(2,.5)]),
    _mel([_bass(0,.85),N,N,_bass(7,.5),N,_bass(0,.45),N,N,_bass(3,.6),N,_bass(0,.45),N,_bass(5,.55),N,N,_bass(2,.5)]),
    _mel([_bass(0,.9),_bass(0,.5),_bass(0,.6),_bass(0,.5)]*4),
    _mel([_bass(0,.85),N,N,N,N,N,_bass(0,.55),N,N,N,N,N,_bass(3,.55),N,N,N]),
    _mel([_bass(0,.9),_bass(0,.5),_bass(3,.6),_bass(0,.5),_bass(5,.6),_bass(0,.5),_bass(7,.6),_bass(0,.5),_bass(8,.6),_bass(0,.5),_bass(7,.6),_bass(5,.55),_bass(3,.6),_bass(2,.55),_bass(0,.7),_bass(0,.55)]),
]
MEL["reese"]["psy"] = [
    _mel([(0,.85),N,N,(0,.5),N,N,(3,.55),N,N,(0,.5),N,N,(5,.55),N,N,(0,.5)]),
    _mel([(0,.85),(0,.45),N,(0,.5),(3,.55),N,(0,.45),(3,.5),N,(0,.45),(5,.55),N,(0,.45),(5,.5),N,(0,.5)]),
    _mel([(0,.8),N,(7,.5),N,(0,.45),N,(3,.55),(0,.45),N,(5,.55),N,(0,.45),(7,.5),N,(0,.45),(2,.5)]),
    _mel([(0,.85),(0,.5),(3,.55),(0,.5),(5,.55),(0,.5),(7,.55),(0,.5),(8,.55),(0,.5),(7,.55),(0,.5),(5,.55),(0,.5),(3,.55),(0,.5)]),
    _mel([(0,.8),N,N,N,(0,.5),N,N,N,(3,.55),N,N,N,(0,.5),N,N,N]),
    _mel([(0,.85),(0,.5),(3,.6),(5,.55),(7,.6),(5,.55),(3,.6),(0,.5),(2,.55),(3,.6),(5,.55),(7,.6),(8,.6),(7,.55),(3,.6),(0,.7)]),
]
MEL["arp"]["psy"] = [
    _mel([(0,.7),N,(7,.6),N,(12,.65),N,(7,.6),N,(0,.7),N,(7,.6),N,(12,.65),N,(7,.6),N]),
    _mel([(0,.7),(3,.55),(7,.6),(10,.55),(12,.65),(10,.55),(7,.6),(3,.55),(0,.7),(3,.55),(7,.6),(10,.55),(12,.65),(10,.55),(7,.6),(3,.55)]),
    _mel([(0,.7),N,(12,.6),(7,.55),N,(10,.6),(3,.55),N,(0,.65),(7,.6),N,(12,.6),(5,.55),N,(7,.6),(3,.55)]),
    _mel([(0,.7),(12,.6),(7,.6),(12,.6),(3,.65),(12,.6),(7,.6),(12,.6),(5,.65),(12,.6),(7,.6),(12,.6),(8,.65),(12,.6),(7,.6),(12,.6)]),
    _mel([(0,.65),N,N,N,(7,.6),N,N,N,(12,.6),N,N,N,(7,.6),N,N,N]),
    _mel([(0,.7),(7,.6),(12,.65),(14,.6),(15,.7),(14,.6),(12,.65),(7,.6),(10,.65),(12,.6),(14,.65),(15,.6),(17,.7),(15,.6),(12,.65),(0,.75)]),
]
MEL["lead"]["psy"] = [
    _mel([(0,.75),N,N,N,(3,.6),N,N,N,(7,.65),N,N,N,(5,.6),N,N,N]),
    _mel([(0,.75),N,(3,.55),N,(7,.6),N,(5,.55),N,(8,.6),N,(7,.55),N,(5,.6),N,(3,.55),N]),
    _mel([N,(0,.7),N,(7,.55),N,N,(3,.6),N,(5,.55),N,N,(7,.6),N,(8,.55),N,(5,.6)]),
    _mel([(0,.7),(7,.55),(3,.6),(7,.55),(5,.6),(7,.55),(8,.6),(7,.55),(10,.6),(7,.55),(8,.6),(7,.55),(5,.6),(3,.55),(2,.6),(0,.6)]),
    _mel([(0,.7),N,N,N,N,N,N,N,(7,.6),N,N,N,N,N,N,N]),
    _mel([(0,.75),(3,.6),(5,.6),(7,.65),(8,.6),(10,.65),(12,.7),(10,.6),(8,.65),(7,.6),(5,.65),(3,.6),(2,.6),(0,.65),(0,.55),(12,.75)]),
]
MEL["stab"]["psy"] = [
    _mel([(0,.7),N,N,N,N,N,(0,.6),N,N,N,(3,.6),N,N,N,(0,.55),N]),
    _mel([(0,.7),N,(0,.5),N,N,(3,.55),(0,.5),N,N,N,(3,.6),N,(5,.55),N,(0,.55),N]),
    _mel([N,N,(0,.65),N,(3,.55),N,N,(5,.5),N,(0,.55),N,N,(7,.55),N,(0,.5),N]),
    _mel([(0,.65),(0,.45),N,(3,.55),(0,.45),N,(5,.55),(0,.45),N,(7,.55),(0,.45),N,(3,.55),(0,.45),(0,.55),N]),
    _mel([N,N,N,N,N,N,(0,.6),N,N,N,N,N,N,N,(3,.55),N]),
    _mel([(0,.7),N,(3,.55),N,(5,.6),N,(7,.55),N,(8,.6),(7,.55),(5,.6),(3,.55),(0,.6),(3,.55),(5,.6),(7,.65)]),
]

# -- house mel: chord stabs on off-beats, syncopated, soulful --
MEL["pad"]["house"] = [
    _mel([N,N,(0,.55),N,N,N,(3,.5),N,N,N,(5,.55),N,N,N,(3,.5),N]),
    _mel([N,N,(0,.55),N,(7,.45),N,(3,.5),N,(10,.45),N,(5,.55),N,(7,.45),N,(3,.5),N]),
    _mel([N,(0,.55),N,N,(3,.5),N,(5,.45),N,N,(7,.5),N,(5,.45),N,(3,.5),N,(0,.45)]),
    _mel([(0,.55),(7,.4),(3,.5),(10,.4),(5,.55),(12,.4),(3,.5),(10,.4),(5,.55),(12,.4),(7,.5),(14,.4),(5,.55),(12,.4),(3,.5),(10,.4)]),
    _mel([N,N,(0,.5),N,N,N,N,N,N,N,(5,.5),N,N,N,N,N]),
    _mel([N,N,(0,.55),N,(3,.5),N,(5,.55),N,(7,.5),N,(5,.55),(3,.5),(0,.55),(3,.5),(5,.55),(7,.6)]),
]
MEL["chord"]["house"] = [
    _mel([N,N,(0,.6),N,(0,.55),N,N,N,(5,.6),N,(5,.55),N,N,N,(3,.55),N]),
    _mel([N,(0,.45),(0,.6),N,(0,.55),N,(3,.5),N,(5,.55),(5,.45),(5,.6),N,(3,.55),N,(0,.5),N]),
    _mel([N,N,(0,.6),(3,.5),N,(5,.55),N,N,(7,.55),N,(5,.5),N,(3,.55),N,(0,.5),N]),
    _mel([(0,.6),N,(0,.45),(3,.55),N,(0,.45),(5,.6),N,(0,.45),(7,.55),N,(0,.45),(5,.6),N,(0,.45),(3,.55)]),
    _mel([N,N,(0,.55),N,N,N,N,N,(5,.55),N,N,N,N,N,N,N]),
    _mel([N,N,(0,.6),N,(3,.55),N,(5,.6),N,(7,.6),(5,.55),(3,.6),N,(0,.6),(3,.55),(5,.6),(7,.65)]),
]
MEL["stab"]["house"] = [
    _mel([N,N,(0,.65),N,N,N,(0,.6),N,N,N,(5,.65),N,N,N,(3,.6),N]),
    _mel([N,(0,.5),(0,.65),N,(3,.55),N,(0,.6),N,(5,.55),N,(5,.65),N,(3,.6),N,(0,.55),N]),
    _mel([N,N,(0,.65),(3,.5),N,(5,.6),N,N,(7,.6),N,(5,.5),N,(3,.6),N,(0,.55),(0,.5)]),
    _mel([(0,.6),N,(3,.55),(5,.6),N,(3,.55),(7,.6),N,(5,.55),(8,.6),N,(5,.55),(7,.6),N,(3,.55),(0,.6)]),
    _mel([N,N,(0,.6),N,N,N,N,N,N,N,(5,.6),N,N,N,N,N]),
    _mel([N,N,(0,.65),N,(3,.6),N,(5,.65),N,(7,.65),(8,.6),(7,.65),(5,.6),(3,.65),(2,.6),(0,.65),(7,.7)]),
]
MEL["bells"]["house"] = [
    _mel([(12,.6),N,N,N,(7,.55),N,N,N,(10,.6),N,N,N,(12,.6),N,N,N]),
    _mel([(12,.6),N,(7,.5),N,(7,.55),N,(10,.5),N,(10,.6),N,(12,.5),N,(12,.6),N,(15,.55),N]),
    _mel([N,(12,.6),N,(7,.5),N,N,(10,.55),N,(12,.6),N,N,(15,.5),N,(12,.55),N,(10,.5)]),
    _mel([(12,.6),(7,.45),(10,.55),(12,.45),(15,.6),(12,.45),(10,.55),(7,.45),(12,.6),(15,.45),(17,.55),(15,.45),(12,.6),(10,.45),(7,.55),(12,.5)]),
    _mel([(12,.55),N,N,N,N,N,N,N,(10,.55),N,N,N,N,N,N,N]),
    _mel([(12,.6),N,(10,.55),N,(7,.55),N,(10,.6),N,(12,.6),(15,.55),(12,.6),(10,.55),(7,.6),(10,.55),(12,.6),(17,.65)]),
]
MEL["lead"]["house"] = [
    _mel([N,N,(7,.65),N,N,N,(5,.6),N,N,N,(3,.6),N,N,N,(5,.6),N]),
    _mel([N,(7,.5),(7,.65),N,(10,.55),N,(5,.6),N,(8,.55),N,(3,.6),N,(5,.55),N,(7,.6),N]),
    _mel([N,N,(7,.65),(10,.5),N,(12,.6),N,N,(10,.6),N,(7,.5),N,(5,.6),N,(3,.55),N]),
    _mel([(7,.6),(5,.5),(3,.6),(5,.5),(7,.6),(10,.5),(12,.6),(10,.5),(8,.6),(7,.5),(5,.6),(3,.5),(2,.6),(0,.5),(3,.6),(5,.5)]),
    _mel([N,N,(7,.6),N,N,N,N,N,N,N,(5,.6),N,N,N,N,N]),
    _mel([(7,.65),N,(10,.6),N,(12,.65),N,(10,.6),(8,.6),(7,.65),(5,.6),(3,.65),(5,.6),(7,.65),(10,.6),(12,.65),(15,.7)]),
]
MEL["melody"]["house"] = [
    _mel([(7,.6),N,N,N,(10,.55),N,N,N,(7,.6),N,N,N,(5,.55),N,N,N]),
    _mel([(7,.6),N,(10,.5),N,(10,.6),N,(12,.5),N,(7,.6),N,(5,.5),N,(5,.6),N,(3,.5),N]),
    _mel([N,(7,.6),N,(10,.5),N,N,(12,.55),N,(10,.6),N,N,(7,.5),N,(5,.55),N,(3,.5)]),
    _mel([(7,.6),(10,.5),(12,.6),(10,.5),(7,.6),(5,.5),(3,.6),(5,.5),(7,.6),(10,.5),(12,.6),(14,.5),(15,.6),(14,.5),(12,.6),(10,.5)]),
    _mel([(7,.55),N,N,N,N,N,N,N,(10,.55),N,N,N,N,N,N,N]),
    _mel([(7,.6),N,(10,.55),N,(12,.6),N,(15,.6),N,(12,.6),(10,.55),(7,.6),(5,.55),(3,.6),(5,.55),(7,.6),(12,.65)]),
]

# -- ambient mel: very sparse, long-feel, few notes, wide --
MEL["pad"]["ambient"] = [
    _mel([(0,.45),N,N,N,N,N,N,N,(7,.4),N,N,N,N,N,N,N]),
    _mel([(0,.45),N,N,N,(7,.4),N,N,N,(3,.45),N,N,N,(10,.4),N,N,N]),
    _mel([N,N,N,N,(0,.45),N,N,N,N,N,N,N,(5,.4),N,N,N]),
    _mel([(0,.45),N,N,N,(3,.42),N,N,N,(5,.44),N,N,N,(7,.42),N,N,N]),
    _mel([(0,.4),N,N,N,N,N,N,N,N,N,N,N,N,N,N,N]),
    _mel([(0,.45),N,N,N,(3,.42),N,N,N,(7,.45),N,N,N,(10,.42),N,(12,.45),N]),
]
MEL["bells"]["ambient"] = [
    _mel([(12,.5),N,N,N,N,N,N,N,N,N,N,N,(7,.4),N,N,N]),
    _mel([(12,.5),N,N,N,N,N,(7,.4),N,N,N,N,N,(10,.45),N,N,N]),
    _mel([N,N,N,N,(12,.5),N,N,N,N,N,N,(7,.4),N,N,N,N]),
    _mel([(12,.5),N,N,(7,.4),N,N,(10,.45),N,N,(5,.4),N,N,(12,.45),N,N,N]),
    _mel([(12,.45),N,N,N,N,N,N,N,N,N,N,N,N,N,N,N]),
    _mel([(12,.5),N,N,N,(10,.4),N,N,N,(7,.45),N,N,N,(10,.4),N,(12,.5),N]),
]
MEL["melody"]["ambient"] = [
    _mel([N,N,N,N,(7,.45),N,N,N,N,N,N,N,N,N,N,N]),
    _mel([(7,.45),N,N,N,N,N,(5,.4),N,N,N,N,N,(3,.42),N,N,N]),
    _mel([N,N,N,(7,.45),N,N,N,N,(10,.4),N,N,N,N,N,(5,.4),N]),
    _mel([(7,.45),N,N,(10,.4),N,N,(12,.42),N,N,(10,.4),N,N,(7,.42),N,N,N]),
    _mel([N,N,N,N,N,N,N,N,(7,.42),N,N,N,N,N,N,N]),
    _mel([(7,.45),N,N,N,(10,.4),N,N,N,(12,.45),N,N,N,(10,.4),N,(7,.45),N]),
]
MEL["sub"]["ambient"] = [
    _mel([_bass(0,.55),N,N,N,N,N,N,N,N,N,N,N,N,N,N,N]),
    _mel([_bass(0,.55),N,N,N,N,N,N,N,_bass(3,.5),N,N,N,N,N,N,N]),
    _mel([N,N,N,N,_bass(0,.55),N,N,N,N,N,N,N,N,N,N,N]),
    _mel([_bass(0,.55),N,N,N,N,N,N,N,_bass(5,.5),N,N,N,_bass(3,.5),N,N,N]),
    _mel([_bass(0,.5),N,N,N,N,N,N,N,N,N,N,N,N,N,N,N]),
    _mel([_bass(0,.55),N,N,N,_bass(3,.5),N,N,N,_bass(5,.5),N,N,N,_bass(7,.55),N,N,N]),
]
MEL["reese"]["ambient"] = [
    _mel([(0,.5),N,N,N,N,N,N,N,(7,.42),N,N,N,N,N,N,N]),
    _mel([(0,.5),N,N,N,(7,.4),N,N,N,(3,.45),N,N,N,(5,.4),N,N,N]),
    _mel([N,N,N,N,(0,.5),N,N,N,N,N,N,N,(7,.4),N,N,N]),
    _mel([(0,.5),N,N,(3,.4),N,N,(5,.42),N,N,(7,.4),N,N,(5,.42),N,N,N]),
    _mel([(0,.45),N,N,N,N,N,N,N,N,N,N,N,N,N,N,N]),
    _mel([(0,.5),N,N,N,(3,.42),N,N,N,(5,.45),N,N,N,(7,.42),N,(10,.45),N]),
]

# -- drum style families for the percu voices + style completions --
DRUMS["ride"]["techno"] = ["x.x.x.x.x.x.x.x.", "xXx.xXx.xXx.xXx.", "x..x.x.x..x.x.x.",
                           "xxxxxxxxxxxxxxxx", "x...x...x...x...", "x.x.x.x.x.x.xXXX"]
DRUMS["ride"]["house"]  = ["..x...x...x...x.", "..X.o.X.o.X.o.X.", "..x...x.x...x..x",
                           ".x.x.x.x.x.x.x.x", "..x.......x.....", "..x...x...x.xXXX"]
DRUMS["ride"]["dnb"]    = ["x.x.x.xxx.x.x.xx", "xXxxxXxxxXxxxXxx", "x.xx.x.xx.xx.x.x",
                           "xxxxxxxxxxxxxxxx", "x...x...x...x...", "x.xxx.xxx.xxxXXX"]
DRUMS["shaker"]["techno"] = ["oxoxoxoxoxoxoxox", "oXoxoXoxoXoxoXox", "ox.xoxo.ox.xoxo.",
                             "xxxxxxxxxxxxxxxx", "o.o.o.o.o.o.o.o.", "oxoxoxoxoxoxoXXX"]
DRUMS["shaker"]["house"]  = ["o-x-o-x-o-x-o-x-", "o-X-o-x-o-X-o-x-", "o.x-o.x-o.x-o.x-",
                             "oxxxoxxxoxxxoxxx", "o---o---o---o---", "o-x-o-x-o-x-oXXX"]
DRUMS["shaker"]["breaks"] = ["x.o.xxo.x.o.xxo.", "xXo.xxo.xXo.xxo.", "x.oxx.o.x.oxx.o.",
                             "xoxoxoxoxoxoxoxo", "x...x...x...x...", "x.o.xxo.x.o.xXXX"]
DRUMS["shaker"]["dnb"]    = ["xoxoxoxoxoxoxoxo", "xXxoxXxoxXxoxXxo", "xo.xxoxo.xoxxo.x",
                             "xxxxxxxxxxxxxxxx", "x...x...x...x...", "xoxoxoxoxoxoXXXX"]
DRUMS["crash"]["techno"]  = ["X.......X.......", "X...o...X...o...", "..X.......X.....",
                             "X...X...X...X...", "X...............", "X.......X...xXXX"]
DRUMS["crash"]["breaks"]  = ["X.......-.......", "X...-...X...-...", "..X...-...X.....",
                             "X...X...X...X...", "X...............", "X.......-...xXXX"]
DRUMS["rim"]["techno"]  = ["....x.......x...", "..o.x...o.o.x...", "...x..x...x.x...",
                           "x.x.x.x.x.x.x.x.", "....x...........", "....x.......xoXX"]
DRUMS["rim"]["dnb"]     = ["....x......x.x..", "..o.x..o.ox.x.o.", ".x..x.x..x.x..x.",
                           "oxoxoxoxoxoxoxox", "....x...........", "....x..x.x.oxXXX"]
DRUMS["fx"]["techno"]   = ["X.......o.......", "X...o...o...o...", "....X.......o...",
                           "X...X...X...X...", "X...............", "o.o.o.o.oxoxoXXX"]
DRUMS["fx"]["ambient"]  = ["X...............", "X.............o.", "........X.......",
                           "X.......o.......", "o...............", "o...o...o..oo.XX"]
DRUMS["sweep"]["trance"]  = ["o.....-.....x...", "o...-...-...x...", "..o.....-...x...",
                             "o.-.x.o.-.x.o.-.", "o...............", "o...-...x..xXXXX"]
DRUMS["sweep"]["ambient"] = ["o...............", "o.......-.......", "....o...........",
                             "o.......o.......", "o...............", "o...-...x..-.oXX"]
DRUMS["perc"]["breaks"] = ["..x...x...x.x...", "..X.o.x...X.x.o.", ".x..x..x.x..x.x.",
                           "x.x.x.x.x.x.x.x.", "..x..........x..", "..x...x...x.xXXX"]
DRUMS["perc"]["dnb"]    = ["..x...x.x.x...x.", "..X.o.x.x.X.o.x.", ".x.x..x.x..x.x.x",
                           "xoxoxoxoxoxoxoxo", "..x..........x..", "..x...x.x.xoxXXX"]

# preset name -> (drum family, melodic family)
PRESET_FAMILY = {
    "techno_drive": ("techno", "default"), "detroit_soul": ("house", "house"),
    "peak_drop": ("techno", "default"), "rave_stab": ("techno", "house"),
    "dub_techno": ("techno", "dub"),
    "acid_journey": ("techno", "default"), "schranz_drive": ("industrial", "default"),
    "trance_euphoria": ("techno", "house"), "melodic_builder": ("techno", "house"),
    "melodic_deep": ("techno", "dub"), "progressive_lift": ("techno", "house"),
    "hypnotic_arp": ("techno", "psy"),
    "psytrance_roll": ("techno", "psy"), "minimal_hypno": ("techno", "psy"),
    "breakbeat": ("breaks", "default"), "bass_science": ("breaks", "default"),
    "jungle_amen": ("breaks", "default"), "dnb_roller": ("dnb", "default"),
    "footwork_chop": ("footwork", "default"), "neuro_reese": ("dnb", "default"),
    "tribal_perc": ("breaks", "default"),
    "electro_808": ("electro", "house"), "ebm_body": ("ebm", "house"),
    "synthwave_drive": ("electro", "house"), "electro_funk": ("electro", "house"),
    "industrial_grind": ("industrial", "default"), "hardcore_punk": ("industrial", "default"),
    "ambient_intro": ("ambient", "ambient"),
}

DRUM_VOICES = {"kick", "hats", "clap", "snare", "perc", "shaker", "ride", "rim",
               "tom", "crash", "fx", "sweep"}


def patterns_for(voice, preset_name):
    """Return 6 step-patterns (one per colour 1-6) for `voice` in `preset_name`,
    or None if the voice has no bank. The `default` family's colours 2-6 are
    derived from colour 1 for a consistent base/busier/broken/double/sparse/fill
    contrast; authored style families pass through unchanged."""
    base = preset_name
    for _sfx in ("_intro", "_live", "_outro"):
        if base.endswith(_sfx):
            base = base[:-len(_sfx)]
            break
    dfam, mfam = PRESET_FAMILY.get(base, ("default", "default"))
    if voice in DRUM_VOICES:
        rolebank = DRUMS.get(voice)
        if rolebank is None:
            return None
        fam = dfam if dfam in rolebank else "default"
        cols = [_rhythm(s) for s in rolebank[fam]]
        if fam == "default":
            cols = [cols[0]] + derive_drum_colors(cols[0])
        return cols
    rolebank = MEL.get(voice)
    if rolebank is None:
        return None
    fam = mfam if mfam in rolebank else "default"
    cols = rolebank[fam]
    if fam == "default":
        cols = [cols[0]] + derive_mel_colors(cols[0])
    return cols


# === Composed families: melodic composition engine (7 styles x 8 roles x 6 colours) ===
# New MEL[role]["composed_<style>"] entries alongside hand-authored families.
# patterns_for() picks them up by family name; no existing entries are modified.
from composition import build_composed_families as _build_cf
for _ck, _rd in _build_cf().items():
    for _role, _six in _rd.items():
        MEL.setdefault(_role, {})
        MEL[_role][_ck] = _six
del _build_cf, _ck, _rd, _role, _six
