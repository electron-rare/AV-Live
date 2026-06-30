"""Every generated .matrix must carry the default globalActions mapping
(slots: LH open=fill, LH closed=drop, RH open=evolve, RH closed=breakdown).
Run: cd .../matrix_presets && uv run python test_global_actions.py"""
import sys, os, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_presets as G

EXPECT = r"'globalActions': [ \fill, \drop, \evolve, \breakdown ]"
ok = True

def check(c, m):
    global ok
    if not c: ok = False; print("FAIL:", m)

# to_sc emits the field
sample = G.to_sc("techno_drive_live", G.MORCEAUX["techno_drive"]["live"],
                 G.MORCEAUX["techno_drive"]["instkit"],
                 G.MORCEAUX["techno_drive"]["melodies"],
                 G.MORCEAUX["techno_drive"]["extra"])
check(EXPECT in sample, "to_sc output missing globalActions default")

# every emitted .matrix on disk carries it (run generate first)
here = os.path.dirname(os.path.abspath(__file__))
files = glob.glob(os.path.join(here, "*.matrix"))
check(len(files) >= 84, "expected >=84 .matrix files, got %d" % len(files))
missing = [os.path.basename(f) for f in files
           if EXPECT not in open(f, encoding="utf-8").read()]
check(not missing, "globalActions missing in: %s" % missing[:5])

EXPECT_SET = ("'globalSettings': ( 'openThresh': 0.65, 'closeThresh': 0.3, "
              "'transientBars': 1, 'breakdownKeep': [ \\kick, \\sub ] )")
check(EXPECT_SET in sample, "to_sc output missing globalSettings default")
missing_set = [os.path.basename(f) for f in files
               if EXPECT_SET not in open(f, encoding="utf-8").read()]
check(not missing_set, "globalSettings missing in: %s" % missing_set[:5])

print("GLOBALACT-PY PASS" if ok else "GLOBALACT-PY FAIL")
sys.exit(0 if ok else 1)
