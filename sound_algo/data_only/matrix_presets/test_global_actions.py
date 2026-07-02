"""Every generated .matrix must carry the default globalActions mapping
(8 actions: fill doubleTime washReverb muteDrums relanceEvolve halfTime next muteMelo).
Run: cd .../matrix_presets && uv run python test_global_actions.py"""
import sys, os, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_presets as G

EXPECT = r"'globalActions': [ \fill, \doubleTime, \washReverb, \muteDrums, \relanceEvolve, \halfTime, \next, \muteMelo ]"
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

EXPECT_SET = "'globalSettings': ( 'transientBars': 1, 'breakdownKeep': [ \\kick, \\sub ] )"
check(EXPECT_SET in sample, "to_sc output missing globalSettings default")
missing_set = [os.path.basename(f) for f in files
               if EXPECT_SET not in open(f, encoding="utf-8").read()]
check(not missing_set, "globalSettings missing in: %s" % missing_set[:5])

EXPECT_PHMS = "'pinchHoldMs': 300"
check(EXPECT_PHMS in sample, "to_sc output missing pinchHoldMs")
missing_phms = [os.path.basename(f) for f in files
                if EXPECT_PHMS not in open(f, encoding="utf-8").read()]
check(not missing_phms, "pinchHoldMs missing in: %s" % missing_phms[:5])

EXPECT_FTH = "'fistThresh': 0.15"
check(EXPECT_FTH in sample, "to_sc output missing fistThresh")
missing_fth = [os.path.basename(f) for f in files
               if EXPECT_FTH not in open(f, encoding="utf-8").read()]
check(not missing_fth, "fistThresh missing in: %s" % missing_fth[:5])

print("GLOBALACT-PY PASS" if ok else "GLOBALACT-PY FAIL")
sys.exit(0 if ok else 1)
