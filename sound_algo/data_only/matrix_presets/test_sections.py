"""Section-shape checks: each morceau -> intro/live/outro; intro builds, outro
breaks down, live is the densest. Run: cd .../matrix_presets && uv run python test_sections.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_presets as G

ok = True
def check(c, m):
    global ok
    if not c: ok = False; print("FAIL:", m)

def grid_of(name, sec):
    m = G.MORCEAUX[name]
    g = G.blank(); m[sec](g)
    if m.get("extra"): m["extra"](g)
    G.apply_colors(g)
    if sec == "live":
        G.make_live_continuous(g)        # mirror the generator: live is a full loop
    return g

def active_in(g, lo, hi):  # count non-zero cells in bar range [lo, hi)
    return sum(1 for row in g for b in range(lo, hi) if row[b] != 0)

check(len(G.MORCEAUX) == 28, "28 morceaux, got %d" % len(G.MORCEAUX))
for name, m in G.MORCEAUX.items():
    for sec in ("intro", "live", "outro"):
        check(sec in m and callable(m[sec]), "%s missing %s arc" % (name, sec))
    intro, live, outro = grid_of(name, "intro"), grid_of(name, "live"), grid_of(name, "outro")
    check(active_in(intro, 48, 64) > active_in(intro, 0, 16), "%s intro not building" % name)
    check(active_in(outro, 0, 16) > active_in(outro, 48, 64), "%s outro not breaking down" % name)
    check(active_in(live, 0, 64) >= active_in(intro, 0, 64)
          and active_in(live, 0, 64) >= active_in(outro, 0, 64), "%s live not densest" % name)
    # live is a full continuous loop: every 16-bar block ~ the plateau (no intro
    # ramp at the start, no breakdown dip at the end).
    p022 = active_in(live, 0, 16); p3248 = active_in(live, 32, 48)
    p4864 = active_in(live, 48, 64)
    check(p3248 > 0 and abs(p022 - p3248) <= 0.15 * p3248,
          "%s live not full from start (%d vs plateau %d)" % (name, p022, p3248))
    check(p3248 > 0 and abs(p4864 - p3248) <= 0.15 * p3248,
          "%s live has a breakdown dip (%d vs plateau %d)" % (name, p4864, p3248))

print("TEST PASS" if ok else "TEST FAIL")
sys.exit(0 if ok else 1)
