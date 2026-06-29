"""Validity + contrast + wiring checks for the pattern bank.
Run: cd sound_algo/data_only/matrix_presets && uv run python test_families.py

Validity (6 valid colours, right shape) is UNIVERSAL — every family.
Contrast (>=4 distinct colours) is scoped to the families SP-C2 ADDS (NEW_FAMILIES);
pre-existing authored families are not held to the new convention."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patterns import DRUMS, MEL, PRESET_FAMILY, _rhythm, _mel, patterns_for

ok = True
def check(c, m):
    global ok
    if not c: ok = False; print("FAIL:", m)

# (voice, family) entries SP-C2 hand-authors (the family x voice matrix).
NEW_MEL = ({(v, "dub")     for v in ("reese", "pad", "chord", "bells", "melody")} |
           {(v, "psy")     for v in ("sub", "reese", "arp", "lead", "stab")} |
           {(v, "house")   for v in ("pad", "chord", "stab", "bells", "lead", "melody")} |
           {(v, "ambient") for v in ("pad", "bells", "melody", "sub", "reese")})
_DM = {"ride": ("techno", "house"), "shaker": ("techno", "house", "breaks"),
       "crash": ("techno", "breaks"), "rim": ("techno", "dnb"),
       "fx": ("techno", "ambient"), "sweep": ("trance", "ambient")}
NEW_DRUM = {(v, f) for v, fs in _DM.items() for f in fs}
NEW_DRUM |= {("perc", "breaks"), ("shaker", "breaks"),
             ("perc", "dnb"), ("ride", "dnb"), ("shaker", "dnb")}
NEW_FAMILIES = NEW_MEL | NEW_DRUM

_VELCH = set(". o - x X")
# --- validity (universal) ---
for v, fams in DRUMS.items():
    for fam, cols in fams.items():
        check(len(cols) == 6, "DRUMS[%s][%s] has %d cols" % (v, fam, len(cols)))
        for i, s in enumerate(cols):
            check(isinstance(s, str) and len(s) == 16 and set(s) <= _VELCH,
                  "DRUMS[%s][%s][%d] invalid: %r" % (v, fam, i, s))
for v, fams in MEL.items():
    for fam, cols in fams.items():
        check(len(cols) == 6, "MEL[%s][%s] has %d cols" % (v, fam, len(cols)))
        for i, m in enumerate(cols):
            check(isinstance(m, list) and len(m) == 16
                  and all(s is None or (isinstance(s[0], int) and isinstance(s[1], float)) for s in m),
                  "MEL[%s][%s][%d] invalid" % (v, fam, i))

# --- contrast (NEW families only): the 6 colours must not collapse ---
for v, fams in DRUMS.items():
    for fam, cols in fams.items():
        if (v, fam) in NEW_FAMILIES:
            check(len({c for c in cols}) >= 4, "DRUMS[%s][%s] <4 distinct colours" % (v, fam))
for v, fams in MEL.items():
    for fam, cols in fams.items():
        if (v, fam) in NEW_FAMILIES:
            check(len({tuple(c) for c in cols}) >= 4, "MEL[%s][%s] <4 distinct colours" % (v, fam))

# --- coverage: every NEW family that names an existing voice is actually present ---
for v, fam in NEW_MEL:
    check(v in MEL and fam in MEL[v], "missing MEL[%s][%s]" % (v, fam))
for v, fam in NEW_DRUM:
    check(v in DRUMS and fam in DRUMS[v], "missing DRUMS[%s][%s]" % (v, fam))

# --- wiring: PRESET_FAMILY resolves without crash ---
for pname, (dfam, mfam) in PRESET_FAMILY.items():
    for v in DRUMS:
        check(patterns_for(v, pname) is not None, "drum %s/%s" % (v, pname))
    for v in MEL:
        check(("default" in MEL[v]) or (mfam in MEL[v]), "mel %s/%s no default" % (v, pname))

print("TEST PASS" if ok else "TEST FAIL")
sys.exit(0 if ok else 1)
