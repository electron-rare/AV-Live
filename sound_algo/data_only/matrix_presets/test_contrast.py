"""Standalone test for the 6-colour contrast derivation.
Run: cd sound_algo/data_only/matrix_presets && uv run python test_contrast.py
Prints TEST PASS / TEST FAIL; exits non-zero on failure."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patterns import derive_drum_colors, derive_mel_colors, _rhythm, _mel

ok = True
def check(c, m):
    global ok
    if not c: ok = False; print("FAIL:", m)

def dens(p): return sum(1 for s in p if s is not None)

# --- drums ---
base = _rhythm("X...x...X...x...")          # 4 hits
c2, c3, c4, c5, c6 = derive_drum_colors(base)
check(all(len(c) == 16 for c in (c2,c3,c4,c5,c6)), "drum colours 16 steps")
check(dens(c2) >= dens(base), "busier >= base")
check(dens(c4) >= dens(base), "double >= base")
check(dens(c5) <= dens(base), "sparse <= base")
check(dens(c3) == dens(base), "broken keeps hit count")
check([i for i in range(16) if (c3[i] is not None) != (base[i] is not None)] != [], "broken displaces")
check(all(c6[i] is not None for i in range(12, 16)), "fill last 4 active")
# velocities legal
legal = {0.30, 0.50, 0.80, 1.0}
for c in (c2, c3, c4, c5, c6):
    check(all(s is None or s[1] in legal for s in c), "drum vel legal")
# determinism
check(derive_drum_colors(base) == derive_drum_colors(base), "drum deterministic")

# --- mel ---
mbase = _mel([(0,0.8),None,(3,0.6),None,(7,0.7),None,None,None,
              (5,0.6),None,(3,0.6),None,(0,0.8),None,None,None])
m2, m3, m4, m5, m6 = derive_mel_colors(mbase)
check(all(len(c) == 16 for c in (m2,m3,m4,m5,m6)), "mel colours 16 steps")
check(dens(m4) >= dens(mbase), "mel double >= base")
check(dens(m5) <= dens(mbase), "mel sparse <= base")
check(all((s is None) or (isinstance(s[0], int) and isinstance(s[1], float)) for s in m4), "mel step shape")
check(all(m6[i] is not None for i in range(12, 16)), "mel fill last 4 active")
check(derive_mel_colors(mbase) == derive_mel_colors(mbase), "mel deterministic")

print("TEST PASS" if ok else "TEST FAIL")
sys.exit(0 if ok else 1)
