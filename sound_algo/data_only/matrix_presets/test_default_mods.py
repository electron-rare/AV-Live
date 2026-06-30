"""Standalone test for the default pose->instrument mapping scheme.
Run: cd sound_algo/data_only/matrix_presets && uv run python test_default_mods.py
Prints TEST PASS / TEST FAIL; exits non-zero on failure."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_presets import default_mods, default_poses, _MOD_TARGETS, VOICES

ok = True
def check(cond, msg):
    global ok
    if not cond:
        ok = False
        print("FAIL:", msg)

# lead voices: the 4 hand bindings
for v in ("acid", "arp", "lead", "stab"):
    tgts = [t for (_s, t, _d) in default_mods(v)]
    check(tgts == ["amp", "pitch", "cutoff", "res"], "%s lead bindings, got %s" % (v, tgts))

# bells: no cutoff; melody: no pitch
check([t for (_s, t, _d) in default_mods("bells")] == ["amp", "pitch", "res"], "bells")
check([t for (_s, t, _d) in default_mods("melody")] == ["amp", "cutoff", "res"], "melody")

# sub: res (not cutoff) + pitch + pan ; reese: cutoff+pitch+res+pan
check([t for (_s, t, _d) in default_mods("sub")] == ["res", "pitch", "pan"], "sub")
check([t for (_s, t, _d) in default_mods("reese")] == ["cutoff", "pitch", "res", "pan"], "reese")

# perc: cutoff+pitch+pan (no res) ; tom: pitch+amp+pan (no res/cutoff)
check([t for (_s, t, _d) in default_mods("perc")] == ["cutoff", "pitch", "pan"], "perc")
check([t for (_s, t, _d) in default_mods("tom")] == ["pitch", "amp", "pan"], "tom")

# drums: body rev+pan ; fx: danse rev + body amp
check(default_mods("kick") == [("bodyVitesse", "rev", 0.3), ("bodyX", "pan", 0.3)], "kick")
check([s for (s, _t, _d) in default_mods("fx")] == ["danse", "bodyVitesse"], "fx sources")

# ELIGIBILITY INVARIANT: every emitted binding's target is eligible for its voice
for v in VOICES:
    for (_s, t, _d) in default_mods(v):
        check(t in _MOD_TARGETS[v], "ineligible %s->%s on %s" % (_s, t, v))

# poses: no defaults (pose->voice triggers are opt-in)
check(default_poses("fx") == [], "fx no pose default")
check(default_poses("sweep") == [], "sweep no pose default")
check(default_poses("kick") == [], "kick no pose")

print("TEST PASS" if ok else "TEST FAIL")
sys.exit(0 if ok else 1)
