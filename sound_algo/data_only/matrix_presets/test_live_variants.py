"""Validates the 112 live-variant files (*_live-[1-4].matrix).

Checks:
  1. Exactly 112 files exist (28 styles × 4 variants)
  2. All 28 styles have variant files 1-4
  3. globalActions field matches the 8-action mapping
  4. All instruments are legal for their voice
  5. Variants differ from each other (grid or instruments)
  6. Deterministic: regenerating produces identical bytes

Run: cd sound_algo/data_only/matrix_presets && uv run python test_live_variants.py
"""
import sys, os, glob, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_presets as G

here = os.path.dirname(os.path.abspath(__file__))

EXPECTED_ACTIONS = r"'globalActions': [ \fill, \doubleTime, \washReverb, \muteDrums, \breakdown, \halfTime, \next, \muteMelo ]"
EXPECTED_N_VARIANTS = 112

ok = True


def check(c, m):
    global ok
    if not c:
        ok = False
        print("FAIL:", m)


# 1. Exactly 112 files
variant_files = glob.glob(os.path.join(here, "*_live-[1-4].matrix"))
check(len(variant_files) == EXPECTED_N_VARIANTS,
      "expected %d variant files, got %d" % (EXPECTED_N_VARIANTS, len(variant_files)))

# 2. Every style has all 4 variants
for name in G.PRESETS:
    for v in range(1, 5):
        fp = os.path.join(here, "%s_live-%d.matrix" % (name, v))
        check(os.path.exists(fp), "missing %s_live-%d.matrix" % (name, v))

# 3. globalActions field
for fp in variant_files:
    content = open(fp, encoding="utf-8").read()
    check(EXPECTED_ACTIONS in content,
          "wrong globalActions in %s" % os.path.basename(fp))

# 4. All instruments legal per voice
for fp in sorted(variant_files):
    content = open(fp, encoding="utf-8").read()
    m = re.search(r"'instruments':\s*\[\s*(.*?)\s*\]", content)
    if m:
        syms = re.findall(r"\\(\w+)", m.group(1))
        for vi, sym in enumerate(syms):
            voice = G.VOICES[vi]
            check(sym in G.INST_CHOICES[voice],
                  "illegal instrument %r for voice %r in %s" % (sym, voice, os.path.basename(fp)))

# 5. Variants differ from each other
for name in G.PRESETS:
    fps = [os.path.join(here, "%s_live-%d.matrix" % (name, v)) for v in range(1, 5)]
    contents = [open(fp, encoding="utf-8").read() for fp in fps if os.path.exists(fp)]
    check(len(set(contents)) > 1, "all variants identical for %s" % name)

# 6. Deterministic
for name in list(G.PRESETS.keys())[:3]:
    m_data = G.MORCEAUX[name]
    for vi in range(1, 5):
        fp = os.path.join(here, "%s_live-%d.matrix" % (name, vi))
        if os.path.exists(fp):
            on_disk = open(fp, encoding="utf-8").read()
            regenerated = G.generate_live_variant_sc(name, vi, m_data)
            check(regenerated == on_disk,
                  "determinism fail for %s_live-%d" % (name, vi))

print("TEST PASS" if ok else "TEST FAIL")
sys.exit(0 if ok else 1)
