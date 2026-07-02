#!/usr/bin/env python3
"""Melodic composition engine for AV-Live matrix live variants.

Generates composed pattern sets: 7 style families x 8 melodic roles x 6 colours.
The 6 colours implement a harmonic arc:
  1 base:       seed motif at chord root 1
  2 variation:  chord root 2, rhythm rotated +2 steps
  3 ornament:   chord root 3, passing notes on alternate rests
  4 climax:     chord root 4 + octave lift (+7) + vel >= 0.90 + fill rests
  5 sparse:     chord root 1 (shift 0), first 2 active per 8-step half, vel x0.68
  6 resolution: chord root 1, anchor degrees only at beat positions 0/4/8/12

Chord progressions (6 per-colour root shifts in A-minor scale degrees):
  composed_techno:     i-VI-III-VII-i-i    [0,5,2,6,0,0]
  composed_psy:        i-i-iv-VII-i-i      [0,0,3,6,0,0]
  composed_trance:     i-VI-VII-i-VI-i     [0,5,6,0,5,0]
  composed_breaks:     i-III-VII-VI-i-i    [0,2,6,5,0,0]
  composed_electro:    i-iv-v-i-iv-i       [0,3,4,0,3,0]
  composed_industrial: i-II-i-II-i-i       [0,1,0,1,0,0]
  composed_ambient:    i-v-i-v-i-i         [0,4,0,4,0,0]

Call-response: melody/stab voices (response) rotated +4 steps vs arp/acid (call).
Mode approximation: all in natural minor A; phrygian via degree 1 emphasis;
dorian via degree 5 emphasis; pentatonic via [0,3,5,7,10] selection.
Determinism: all transforms are pure functions, no RNG.
"""

N = None  # rest sentinel
_MAX_DEG = 14  # max safe degree (prevents over-range after +7 climax lift)

# ---------------------------------------------------------------------------
# Chord root shifts per colour (indices 0-5 = colours 1-6)
# ---------------------------------------------------------------------------
STYLE_SHIFTS = {
    "composed_techno":     [0, 5, 2, 6, 0, 0],
    "composed_psy":        [0, 0, 3, 6, 0, 0],
    "composed_trance":     [0, 5, 6, 0, 5, 0],
    "composed_breaks":     [0, 2, 6, 5, 0, 0],
    "composed_electro":    [0, 3, 4, 0, 3, 0],
    "composed_industrial": [0, 1, 0, 1, 0, 0],
    "composed_ambient":    [0, 4, 0, 4, 0, 0],
}

# Anchor degrees for resolution colour (c6)
STYLE_ANCHORS = {
    "composed_techno":     [0, 4, 7],
    "composed_psy":        [0, 4, 7],
    "composed_trance":     [0, 4, 7],
    "composed_breaks":     [0, 3, 5, 7],
    "composed_electro":    [0, 3, 5, 7],
    "composed_industrial": [0, 1, 7],
    "composed_ambient":    [0, 4, 7],
}


def _e(d, v=0.78):
    return (int(d), round(float(v), 2))


# ---------------------------------------------------------------------------
# Base 16-step motifs per (style_key, role)
# Format: list of 16 entries: None or (degree:int, vel:float)
# All degrees in [0..14] natural minor A-relative.
# Call voices (arp, acid, lead): base starts at step 0.
# Response voices (melody, stab): rotated +4 steps automatically.
# ---------------------------------------------------------------------------
_BASE = {
    # -----------------------------------------------------------------------
    "composed_techno": {
        # Detroit/techno: three-note cell (root/min3/5th), syncopated 16ths
        "sub":    [_e(0,.90),N,N,N,_e(0,.60),N,N,N,_e(0,.90),N,N,N,_e(3,.80),N,N,N],
        "reese":  [_e(0,.85),N,_e(0,.60),N,_e(3,.75),N,_e(0,.60),N,
                   _e(5,.80),N,_e(0,.60),N,_e(7,.85),N,_e(3,.70),_e(2,.60)],
        "acid":   [_e(0,.90),_e(0,.55),_e(7,.80),_e(0,.55),_e(3,.70),N,_e(7,.85),_e(0,.55),
                   _e(0,.90),_e(0,.55),_e(5,.70),_e(3,.60),_e(0,.70),_e(7,.80),_e(2,.60),_e(0,.55)],
        "arp":    [_e(0,.70),_e(2,.60),_e(4,.72),_e(7,.78),_e(9,.82),_e(7,.70),_e(4,.66),_e(2,.60),
                   _e(0,.70),_e(4,.66),_e(7,.78),_e(9,.82),_e(11,.86),_e(9,.80),_e(7,.72),_e(4,.66)],
        "lead":   [_e(7,.90),N,N,_e(9,.85),N,N,_e(7,.80),N,_e(4,.82),N,_e(5,.82),N,_e(7,.88),N,N,N],
        "stab":   [N,N,_e(0,.80),N,N,N,_e(0,.70),N,N,N,_e(3,.80),N,N,N,_e(2,.70),N],
        "melody": [_e(0,.75),_e(3,.60),_e(5,.72),_e(7,.76),_e(5,.66),_e(3,.60),_e(2,.60),_e(0,.70),
                   _e(7,.76),_e(5,.72),_e(4,.66),_e(2,.60),_e(0,.70),_e(2,.60),_e(3,.60),_e(5,.66)],
        "bells":  [_e(7,.68),N,N,N,_e(4,.60),N,N,N,_e(5,.64),N,N,N,_e(2,.60),N,_e(0,.60),N],
    },
    # -----------------------------------------------------------------------
    "composed_psy": {
        # Hypnotic rolling feel, minor, 303-style repeating cell
        "sub":    [_e(0,.90),N,N,_e(0,.50),N,N,_e(0,.55),N,N,_e(3,.60),N,N,_e(0,.55),N,N,_e(2,.50)],
        "reese":  [_e(0,.85),N,N,_e(0,.50),N,N,_e(3,.55),N,N,_e(0,.50),N,N,_e(5,.55),N,N,_e(0,.50)],
        "acid":   [_e(0,.90),N,_e(0,.55),_e(7,.75),N,_e(3,.60),N,_e(0,.50),
                   _e(5,.75),N,_e(0,.55),_e(7,.80),N,_e(3,.60),_e(2,.60),N],
        "arp":    [_e(0,.70),N,_e(7,.60),N,_e(12,.65),N,_e(7,.60),N,
                   _e(0,.70),N,_e(7,.60),N,_e(12,.65),N,_e(7,.60),N],
        "lead":   [_e(0,.75),N,N,N,_e(3,.60),N,N,N,_e(7,.65),N,N,N,_e(5,.60),N,N,N],
        "stab":   [_e(0,.70),N,N,N,N,N,_e(0,.60),N,N,N,_e(3,.60),N,N,N,_e(0,.55),N],
        "melody": [N,N,N,N,_e(7,.60),N,N,N,N,N,N,N,_e(5,.50),N,N,N],
        "bells":  [_e(12,.60),N,N,N,N,N,N,N,N,N,_e(7,.45),N,N,N,N,N],
    },
    # -----------------------------------------------------------------------
    "composed_trance": {
        # Rolling 16ths, i-5-8 arp backbone, euphoric lead ascending
        "sub":    [_e(0,.88),_e(0,.60),_e(0,.60),_e(0,.60),_e(0,.85),_e(0,.60),_e(0,.60),_e(0,.60),
                   _e(3,.85),_e(3,.60),_e(3,.60),_e(3,.60),_e(2,.82),_e(2,.60),_e(7,.66),_e(7,.60)],
        "reese":  [_e(0,.82),N,_e(0,.58),_e(3,.70),N,_e(0,.58),_e(5,.72),N,
                   _e(0,.82),N,_e(0,.58),_e(7,.74),N,_e(3,.62),_e(2,.60),N],
        "acid":   [_e(0,.85),N,_e(0,.50),_e(7,.70),N,_e(3,.60),N,_e(0,.50),
                   _e(5,.70),N,_e(0,.50),_e(7,.75),N,_e(3,.60),_e(2,.60),N],
        "arp":    [_e(0,.70),_e(4,.65),_e(7,.75),_e(0,.70),_e(4,.65),_e(7,.75),_e(0,.70),_e(4,.65),
                   _e(7,.75),_e(9,.80),_e(7,.75),_e(4,.65),_e(0,.70),_e(4,.65),_e(7,.75),_e(9,.80)],
        "lead":   [_e(7,.90),N,N,_e(9,.85),N,N,_e(7,.80),N,_e(4,.82),N,_e(5,.82),N,_e(7,.88),N,N,N],
        "stab":   [N,N,_e(0,.80),N,_e(0,.70),N,N,N,N,_e(0,.70),N,N,N,N,_e(0,.80),N],
        "melody": [_e(0,.76),_e(3,.60),_e(5,.72),_e(7,.76),_e(5,.66),_e(3,.60),_e(2,.60),_e(0,.70),
                   _e(7,.76),_e(5,.72),_e(4,.66),_e(2,.60),_e(0,.70),_e(2,.60),_e(3,.60),_e(5,.66)],
        "bells":  [_e(0,.60),N,_e(4,.60),N,_e(7,.70),N,_e(9,.64),N,
                   _e(7,.60),N,_e(4,.56),N,_e(2,.56),N,_e(0,.60),N],
    },
    # -----------------------------------------------------------------------
    "composed_breaks": {
        # Syncopated DnB/breaks: minor pentatonic [0,3,5,7,10], rolling
        "sub":    [_e(0,.88),N,_e(0,.60),N,_e(3,.82),N,_e(0,.60),N,
                   _e(5,.82),N,_e(0,.60),N,_e(7,.86),N,_e(3,.72),_e(2,.60)],
        "reese":  [_e(0,.90),_e(0,.62),_e(5,.82),N,_e(3,.78),N,_e(7,.88),N,
                   _e(2,.72),N,_e(5,.82),_e(3,.72),_e(0,.72),N,_e(7,.82),N],
        "acid":   [_e(0,.85),_e(0,.60),_e(3,.80),_e(0,.60),_e(7,.90),_e(0,.60),_e(3,.80),_e(5,.70),
                   _e(0,.85),_e(0,.60),_e(3,.80),_e(0,.60),_e(10,.90),_e(7,.80),_e(5,.75),_e(3,.70)],
        "arp":    [_e(0,.70),_e(3,.60),_e(5,.70),_e(7,.75),_e(10,.80),_e(7,.70),_e(5,.66),_e(3,.60),
                   _e(0,.70),_e(5,.66),_e(7,.75),_e(10,.80),_e(12,.85),_e(10,.80),_e(7,.72),_e(5,.66)],
        "lead":   [_e(4,.80),N,_e(2,.70),_e(0,.76),N,_e(2,.70),_e(4,.82),N,
                   _e(7,.86),N,_e(5,.80),_e(4,.76),_e(2,.70),N,_e(0,.72),N],
        "stab":   [N,N,_e(0,.72),N,N,_e(0,.62),N,N,N,N,_e(3,.70),N,N,_e(3,.60),N,N],
        "melody": [_e(0,.76),_e(0,.60),_e(3,.74),N,_e(5,.80),N,_e(3,.70),_e(5,.74),
                   _e(7,.82),N,_e(5,.74),_e(3,.68),_e(2,.70),N,_e(0,.72),N],
        "bells":  [_e(7,.68),N,N,N,_e(4,.60),N,N,N,_e(5,.64),N,N,N,_e(2,.60),N,_e(0,.60),N],
    },
    # -----------------------------------------------------------------------
    "composed_electro": {
        # Funky syncopated: minor pentatonic, offbeat emphasis
        "sub":    [N,_e(0,.82),N,_e(0,.70),N,_e(0,.82),N,_e(0,.70),
                   N,_e(3,.82),N,_e(3,.70),N,_e(2,.82),N,_e(7,.70)],
        "reese":  [_e(0,.85),_e(0,.55),_e(5,.80),N,_e(3,.75),N,_e(7,.85),N,
                   _e(2,.70),N,_e(5,.80),_e(3,.70),_e(0,.70),N,_e(7,.80),N],
        "acid":   [_e(0,.88),_e(0,.60),_e(3,.82),N,_e(0,.72),_e(3,.76),_e(5,.82),N,
                   _e(0,.88),_e(0,.60),_e(3,.82),_e(2,.70),_e(0,.72),_e(7,.86),_e(5,.80),_e(3,.72)],
        "arp":    [_e(0,.70),_e(3,.65),_e(5,.72),_e(7,.78),_e(3,.72),_e(5,.68),_e(7,.74),_e(10,.78),
                   _e(0,.70),_e(5,.66),_e(7,.72),_e(10,.76),_e(7,.70),_e(5,.66),_e(3,.62),_e(0,.70)],
        "lead":   [_e(0,.88),_e(0,.60),_e(3,.82),N,_e(0,.72),_e(3,.76),_e(5,.82),N,
                   _e(0,.88),_e(0,.60),_e(3,.82),_e(2,.70),_e(0,.72),_e(7,.86),_e(5,.80),_e(3,.72)],
        "stab":   [N,_e(0,.70),N,_e(0,.70),N,_e(0,.65),N,_e(0,.65),
                   N,_e(3,.70),N,_e(3,.70),N,_e(2,.65),N,_e(0,.70)],
        "melody": [_e(0,.80),_e(0,.60),_e(3,.74),N,_e(5,.80),N,_e(3,.70),_e(5,.74),
                   _e(7,.82),N,_e(5,.74),_e(3,.68),_e(2,.70),N,_e(0,.72),N],
        "bells":  [_e(5,.65),N,N,N,_e(7,.60),N,N,N,N,N,_e(3,.60),N,N,N,_e(0,.60),N],
    },
    # -----------------------------------------------------------------------
    "composed_industrial": {
        # Driving phrygian-adjacent: root/degree-1/5th, dense, percussive
        "sub":    [_e(0,.92),_e(0,.70),_e(3,.85),_e(0,.60),_e(7,.90),_e(0,.60),_e(3,.80),_e(5,.70),
                   _e(0,.92),_e(0,.70),_e(3,.85),_e(0,.60),_e(10,.90),_e(7,.80),_e(5,.75),_e(3,.70)],
        "reese":  [_e(0,.90),_e(0,.62),_e(5,.82),N,_e(3,.78),N,_e(7,.88),N,
                   _e(2,.72),N,_e(5,.82),_e(3,.72),_e(0,.72),N,_e(7,.82),N],
        "acid":   [_e(0,.95),_e(0,.70),_e(3,.85),_e(0,.60),_e(7,.90),_e(0,.60),_e(3,.80),_e(5,.70),
                   _e(0,.95),_e(0,.70),_e(3,.85),_e(0,.60),_e(10,.90),_e(7,.80),_e(5,.75),_e(3,.70)],
        "arp":    [_e(0,.80),_e(1,.60),_e(0,.75),_e(7,.80),_e(0,.80),_e(1,.60),_e(0,.75),_e(7,.80),
                   _e(3,.80),_e(1,.60),_e(3,.75),_e(7,.80),_e(0,.80),_e(1,.60),_e(0,.75),_e(7,.80)],
        "lead":   [_e(0,.88),_e(0,.60),_e(3,.82),N,_e(0,.72),_e(3,.76),_e(5,.82),N,
                   _e(0,.88),_e(0,.60),_e(3,.82),_e(2,.70),_e(0,.72),_e(7,.86),_e(5,.80),_e(3,.72)],
        "stab":   [N,_e(0,.80),N,_e(0,.70),_e(0,.75),_e(0,.60),_e(3,.70),_e(0,.60),
                   _e(3,.80),_e(3,.65),_e(5,.70),_e(3,.60),_e(5,.75),_e(3,.65),_e(0,.80),_e(0,.70)],
        "melody": [_e(0,.85),_e(0,.60),_e(3,.80),_e(1,.65),_e(0,.72),_e(3,.76),_e(5,.80),_e(1,.65),
                   _e(0,.85),_e(0,.60),_e(3,.80),_e(2,.70),_e(0,.72),_e(7,.86),_e(5,.80),_e(1,.65)],
        "bells":  [_e(7,.70),N,N,N,N,N,_e(0,.65),N,N,N,_e(7,.70),N,N,N,_e(0,.65),N],
    },
    # -----------------------------------------------------------------------
    "composed_ambient": {
        # Very sparse, open: pentatonic [0,2,4,7,9], long-feel
        "sub":    [_e(0,.55),N,N,N,N,N,N,N,_e(3,.50),N,N,N,N,N,N,N],
        "reese":  [_e(0,.50),N,N,N,N,N,N,N,_e(7,.42),N,N,N,N,N,N,N],
        "acid":   [_e(0,.60),N,N,N,_e(7,.50),N,N,N,_e(3,.55),N,N,N,_e(5,.50),N,N,N],
        "arp":    [_e(0,.60),_e(2,.50),_e(4,.55),_e(2,.50),_e(0,.60),_e(4,.55),_e(7,.60),_e(4,.55),
                   _e(2,.55),_e(4,.50),_e(7,.60),_e(4,.50),_e(9,.60),_e(7,.55),_e(4,.50),_e(2,.50)],
        "lead":   [_e(7,.55),N,N,N,N,N,N,N,_e(5,.50),N,N,N,N,N,N,N],
        "stab":   [_e(0,.55),N,N,N,N,N,N,N,N,N,_e(0,.50),N,N,N,N,N],
        "melody": [N,N,N,N,_e(7,.50),N,N,N,N,N,N,N,N,N,N,N],
        "bells":  [_e(12,.55),N,N,N,N,N,N,N,N,N,_e(7,.45),N,N,N,N,N],
    },
}

# Response voices get a +4-step rotation (quarter-note offset = call-response)
_RESPONSE_VOICES = frozenset({"melody", "stab"})


# ---------------------------------------------------------------------------
# Transform functions (all pure/deterministic)
# ---------------------------------------------------------------------------

def _shift(motif, delta):
    """Shift all active degrees by delta scale steps; clamp to [0, _MAX_DEG]."""
    if delta == 0:
        return list(motif)
    return [None if s is None else (min(_MAX_DEG, max(0, s[0] + delta)), s[1])
            for s in motif]


def _rotate(motif, n):
    """Rotate motif right by n steps."""
    n = n % 16
    if n == 0:
        return list(motif)
    return list(motif[-n:]) + list(motif[:-n])


def _ornament(motif):
    """Add passing note (prev-degree, vel=0.50) on every other rest."""
    result = list(motif)
    prev_deg = 0
    prev_at = []
    for s in motif:
        if s is not None:
            prev_deg = s[0]
        prev_at.append(prev_deg)
    rests = [i for i in range(16) if result[i] is None]
    for i in rests[::2]:
        result[i] = (prev_at[i], 0.50)
    return result


def _climax(motif, shift):
    """Shift + octave lift (+7) for all positions; fill rests with prev+7."""
    base = _shift(motif, shift)
    prev_deg = 0
    result = []
    for s in base:
        if s is None:
            result.append((min(_MAX_DEG, prev_deg + 7), 0.88))
        else:
            d = min(_MAX_DEG, s[0] + 7)
            result.append((d, 0.92))
            prev_deg = s[0]
    return result


def _sparse(motif, shift=0):
    """Keep first 2 active notes per 8-step half; vel x0.68."""
    base = _shift(motif, shift)
    result = list(base)
    for start in (0, 8):
        actives = [i for i in range(start, start + 8) if result[i] is not None]
        for i in actives[2:]:
            result[i] = None
    if all(s is None for s in result):
        for i, s in enumerate(base):
            if s is not None:
                result[i] = s
                break
    return [None if s is None else (s[0], round(s[1] * 0.68, 2)) for s in result]


def _resolve(motif, anchors):
    """Resolution: snap to nearest anchor at beats 0,4,8,12 only, vel=0.70."""
    active = [s for s in motif if s is not None]
    if not active:
        active = [(0, 0.70)]
    beat_pos = [0, 4, 8, 12]
    result = [None] * 16
    for i, pos in enumerate(beat_pos):
        src_deg = active[i % len(active)][0]
        closest = min(anchors, key=lambda a: abs((a % 7) - (src_deg % 7)))
        result[pos] = (closest, 0.70)
    return result


def _make_6colours(base, shifts, anchors, is_response):
    """Generate 6 composition-stage patterns from a seed motif."""
    if is_response:
        base = _rotate(base, 4)
    c1 = _shift(base, 0)
    c2 = _rotate(_shift(base, shifts[1]), 2)
    c3 = _ornament(_shift(base, shifts[2]))
    c4 = _climax(base, shifts[3])
    c5 = _sparse(base, shifts[4])
    c6 = _resolve(base, anchors)
    return [c1, c2, c3, c4, c5, c6]


def _to_mel(pattern):
    """Normalise to (int, float) entries or None; 2dp vel."""
    return [None if s is None else (int(s[0]), round(float(s[1]), 2))
            for s in pattern]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
def build_composed_families():
    """Return {style_key: {role: [colour_1..6]}} for all 7 composed styles.
    Each colour is a list of 16 entries: None or (int, float).
    """
    out = {}
    for style_key, roles in _BASE.items():
        shifts = STYLE_SHIFTS[style_key]
        anchors = STYLE_ANCHORS[style_key]
        out[style_key] = {}
        for role, base in roles.items():
            is_resp = role in _RESPONSE_VOICES
            six = _make_6colours(list(base), shifts, anchors, is_resp)
            out[style_key][role] = [_to_mel(p) for p in six]
    return out
