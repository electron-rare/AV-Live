#!/usr/bin/env python3
"""Split palette/melodies/{short,long,xlong,epic}.scd in one file per melody,
then generate ~20x new idiomatic melodies per genre.

Convention finale (decision projet) : camelCase pour nouvelles vars
(~mAcid100, ~mlTrance100, ~mxlAmbient100, ~mepicCinematic100). Les vars
historiques ~m1..~m78 / ~ml1..~ml30 / ~mxl1..~mxl15 / ~mepic1..~mepic10
sont conservees telles quelles.
"""
from __future__ import annotations
import re
import shutil
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEL = ROOT / "palette" / "melodies"
MIG = ROOT / "_migrate"

SOURCES = {
    "short": (MEL / "short.scd", "m",       32),
    "long":  (MEL / "long.scd",  "ml",      64),
    "xlong": (MEL / "xlong.scd", "mxl",     96),
    "epic":  (MEL / "epic.scd",  "mepic",   128),
}

# ---------------------------------------------------------------------------
# 1. PARSE EXISTING FILES
# ---------------------------------------------------------------------------

VAR_RE = re.compile(
    r"~(m|ml|mxl|mepic)(\d+)\s*=\s*\[([^\]]+)\]\s*;",
    re.DOTALL,
)


def parse_source(path: Path) -> dict[str, list[int]]:
    text = path.read_text()
    found = {}
    for m in VAR_RE.finditer(text):
        prefix, num, body = m.group(1), m.group(2), m.group(3)
        ints = [int(x) for x in re.findall(r"-?\d+", body)]
        found[f"{prefix}{num}"] = ints
    return found


def write_one(path: Path, var: str, length_label: str, genre_hint: str, notes: list[int]) -> None:
    # Pretty-format : 8 ints par ligne, 4 lignes pour 32, 8 lignes pour 64, etc.
    chunks = [notes[i:i + 8] for i in range(0, len(notes), 8)]
    body_lines = []
    for ch in chunks:
        body_lines.append("    " + ", ".join(f"{n:>2}" for n in ch) + ",")
    if body_lines:
        # supprime virgule finale du dernier element
        body_lines[-1] = body_lines[-1].rstrip(",")
    content = (
        "// =====================================================================\n"
        f"//  ~{var}  --  {length_label} melody ({len(notes)} steps), genre: {genre_hint}\n"
        "// =====================================================================\n"
        "(\n"
        f"~{var} = [\n"
        + "\n".join(body_lines) + "\n"
        "];\n"
        ")\n"
    )
    path.write_text(content)


# ---------------------------------------------------------------------------
# 2. GENRE SPECS
# ---------------------------------------------------------------------------

# scales (intervals from root, semitones)
SCALES = {
    "minor":          [0, 2, 3, 5, 7, 8, 10],
    "natural_minor":  [0, 2, 3, 5, 7, 8, 10],
    "harmonic_minor": [0, 2, 3, 5, 7, 8, 11],
    "phrygian":       [0, 1, 3, 5, 7, 8, 10],
    "dorian":         [0, 2, 3, 5, 7, 9, 10],
    "mixolydian":     [0, 2, 4, 5, 7, 9, 10],
    "ionian":         [0, 2, 4, 5, 7, 9, 11],
    "lydian":         [0, 2, 4, 6, 7, 9, 11],
    "locrian":        [0, 1, 3, 5, 6, 8, 10],
    "major":          [0, 2, 4, 5, 7, 9, 11],
    "minor_pent":     [0, 3, 5, 7, 10],
    "major_pent":     [0, 2, 4, 7, 9],
    "blues":          [0, 3, 5, 6, 7, 10],
    "hirajoshi":      [0, 2, 3, 7, 8],     # E,F#,G,B,C (transpose root)
    "iwato":          [0, 1, 5, 6, 10],
    "hijaz":          [0, 1, 4, 5, 7, 8, 10],
    "altered":        [0, 1, 3, 4, 6, 8, 10],
    "diminished":     [0, 2, 3, 5, 6, 8, 9, 11],
    "chromatic":      list(range(12)),
}

# genre -> dict(roots, scales, range, density, motif, struct_weights)
GENRES = {
    "acid": dict(roots=[40, 42], scales=["phrygian", "minor"], lo=36, hi=60,
                 density=(0.6, 0.8), motif="acid"),
    "dub": dict(roots=[40, 36], scales=["minor_pent"], lo=36, hi=60,
                density=(0.3, 0.5), motif="dub"),
    "trance": dict(roots=[42, 45], scales=["minor", "harmonic_minor"], lo=60, hi=84,
                   density=(0.7, 0.9), motif="trance"),
    "detroit": dict(roots=[36, 41], scales=["dorian"], lo=48, hi=72,
                    density=(0.5, 0.7), motif="detroit"),
    "dnb": dict(roots=[40, 43], scales=["natural_minor"], lo=36, hi=72,
                density=(0.4, 0.6), motif="dnb"),
    "ambient": dict(roots=[60, 65], scales=["ionian", "lydian"], lo=60, hi=84,
                    density=(0.2, 0.4), motif="ambient"),
    "world": dict(roots=[50, 55], scales=["dorian", "mixolydian"], lo=60, hi=84,
                  density=(0.6, 0.8), motif="modal"),
    "retro": dict(roots=[60, 67], scales=["major", "lydian"], lo=60, hi=84,
                  density=(0.6, 0.8), motif="diatonic"),
    "dark": dict(roots=[40, 43], scales=["locrian", "harmonic_minor"], lo=36, hi=60,
                 density=(0.5, 0.7), motif="dark"),
    "asian": dict(roots=[52, 57], scales=["hirajoshi", "iwato"], lo=52, hi=76,
                  density=(0.5, 0.7), motif="asian"),
    "oriental": dict(roots=[50, 55], scales=["hijaz"], lo=50, hi=74,
                     density=(0.6, 0.8), motif="oriental"),
    "tribal": dict(roots=[45, 50], scales=["minor_pent"], lo=36, hi=60,
                   density=(0.7, 0.9), motif="tribal"),
    "industrial": dict(roots=[40, 43], scales=["chromatic", "minor"], lo=36, hi=60,
                       density=(0.7, 0.9), motif="industrial"),
    "synthwave": dict(roots=[57, 62], scales=["minor"], lo=48, hi=84,
                      density=(0.6, 0.8), motif="synthwave"),
    "chiptune": dict(roots=[60, 67], scales=["major", "mixolydian"], lo=60, hi=96,
                     density=(0.7, 0.9), motif="chiptune"),
    "phonk": dict(roots=[40, 45], scales=["minor_pent"], lo=36, hi=60,
                  density=(0.3, 0.5), motif="phonk"),
    "hardcore": dict(roots=[40, 41], scales=["locrian", "chromatic"], lo=36, hi=60,
                     density=(0.8, 1.0), motif="hardcore"),
    "pop": dict(roots=[60, 67], scales=["major"], lo=60, hi=84,
                density=(0.5, 0.7), motif="pop"),
    "jazz": dict(roots=[60, 65], scales=["dorian", "mixolydian", "altered"], lo=48, hi=84,
                 density=(0.6, 0.8), motif="jazz"),
    "blues": dict(roots=[45, 52], scales=["blues"], lo=45, hi=72,
                  density=(0.5, 0.7), motif="blues"),
    "hypnotic": dict(roots=[60], scales=["minor_pent"], lo=60, hi=72,
                     density=(0.3, 0.5), motif="hypnotic"),
    "pad": dict(roots=[60, 65], scales=["major", "dorian"], lo=60, hi=84,
                density=(0.2, 0.4), motif="pad"),
    "pluck": dict(roots=[60, 67], scales=["major_pent"], lo=60, hi=84,
                  density=(0.4, 0.6), motif="pluck"),
    "sub": dict(roots=[24, 28], scales=["minor_pent"], lo=24, hi=48,
                density=(0.3, 0.5), motif="sub"),
    "drone": dict(roots=[24, 29], scales=["minor_pent"], lo=24, hi=48,
                  density=(0.1, 0.3), motif="drone"),
    "tension": dict(roots=[40, 47], scales=["locrian", "diminished"], lo=36, hi=60,
                    density=(0.6, 0.8), motif="tension"),
    "chromatic": dict(roots=[60], scales=["chromatic"], lo=48, hi=84,
                      density=(0.7, 0.9), motif="chromatic"),
    "cinematic": dict(roots=[48, 53], scales=["minor", "harmonic_minor"], lo=36, hi=84,
                      density=(0.4, 0.7), motif="cinematic"),
}


def palette_for(root: int, scale: list[int], lo: int, hi: int) -> list[int]:
    pal = []
    for octv in range(-2, 4):
        for d in scale:
            n = root + d + 12 * octv
            if lo <= n <= hi:
                pal.append(n)
    return sorted(set(pal))


def is_strong_beat(i: int, length: int) -> bool:
    if length == 32:
        return i % 4 == 0
    if length == 64:
        return i % 4 == 0
    if length == 96:
        return i % 4 == 0
    return i % 4 == 0


def pick_note(rng: random.Random, pal: list[int], strong: bool, root: int) -> int:
    if not pal:
        return 0
    if strong and rng.random() < 0.55:
        # bias toward root + fifth
        candidates = [n for n in pal if (n - root) % 12 in (0, 7, 3, 4)]
        if candidates:
            return rng.choice(candidates)
    # bias to mid range : note proche de la mediane palette
    return rng.choice(pal)


def apply_motif(rng: random.Random, motif: str, notes: list[int], pal: list[int], root: int) -> list[int]:
    L = len(notes)
    if motif == "acid":
        # slides + octave jumps : add lowest+12 sometimes
        for i in range(0, L, 4):
            if rng.random() < 0.4 and notes[i] > 0:
                if i + 1 < L and notes[i + 1] == 0:
                    notes[i + 1] = max(min(notes[i] + 12, max(pal)), min(pal))
            if rng.random() < 0.25 and notes[i] > 0 and i + 2 < L:
                # ghost slide
                notes[i + 2] = notes[i] + rng.choice([-2, -1, 1, 2])
    elif motif == "trance":
        # arpege ascendant 4 notes consecutives
        for i in range(0, L - 3, 8):
            if rng.random() < 0.7:
                base_idx = pal.index(rng.choice(pal[: max(1, len(pal) // 2)])) if pal else 0
                for k in range(4):
                    if base_idx + k < len(pal):
                        notes[i + k] = pal[base_idx + k]
    elif motif == "ambient" or motif == "pad" or motif == "drone":
        # etire les notes : silence apres une note frappee
        for i in range(L):
            if notes[i] > 0 and rng.random() < 0.7:
                for j in range(1, rng.randint(2, 5)):
                    if i + j < L:
                        notes[i + j] = 0
    elif motif == "chiptune":
        # arpeges rapides 1-3-5
        for i in range(0, L - 2, 6):
            if rng.random() < 0.5 and pal:
                a = rng.choice(pal[: len(pal) // 2 or 1])
                # 1-3-5 over scale (find in palette)
                third = a + 4 if a + 4 in pal else (a + 3 if a + 3 in pal else a + 5)
                fifth = a + 7 if a + 7 in pal else a + 5
                notes[i] = a
                if i + 1 < L:
                    notes[i + 1] = third
                if i + 2 < L:
                    notes[i + 2] = fifth
    elif motif == "dub":
        # sub bass tenue + offbeat stab
        sub = root
        for i in range(L):
            notes[i] = 0
        for i in range(0, L, 8):
            notes[i] = sub
            if i + 4 < L and rng.random() < 0.6:
                notes[i + 4] = rng.choice(pal) if pal else 0
    elif motif == "tribal":
        # repetitions hypnotiques : pattern court repete
        if pal:
            cell = [rng.choice(pal) if rng.random() < 0.7 else 0 for _ in range(8)]
            for i in range(L):
                notes[i] = cell[i % 8]
    elif motif == "hypnotic":
        # 2-3 notes repetees
        if pal:
            cell = [rng.choice(pal) if rng.random() < 0.5 else 0 for _ in range(4)]
            for i in range(L):
                if rng.random() < 0.7:
                    notes[i] = cell[i % 4]
    elif motif == "sub":
        # sub bass espace
        for i in range(L):
            notes[i] = 0
        for i in range(0, L, 8):
            if rng.random() < 0.6 and pal:
                notes[i] = rng.choice([n for n in pal if n <= root + 12] or pal)
    elif motif == "hardcore":
        # tres dense : moins de 0
        for i in range(L):
            if notes[i] == 0 and rng.random() < 0.6 and pal:
                notes[i] = rng.choice(pal)
    elif motif == "industrial":
        # patterns mecaniques (repetition stricte 4-step)
        if pal:
            cell = [rng.choice(pal) if rng.random() < 0.8 else 0 for _ in range(4)]
            for i in range(L):
                notes[i] = cell[i % 4]
    elif motif == "asian" or motif == "oriental":
        # ornements descendants apres note forte
        for i in range(0, L - 2, 4):
            if notes[i] > 0 and rng.random() < 0.4 and pal:
                idx = pal.index(notes[i]) if notes[i] in pal else 0
                if idx > 0 and i + 1 < L:
                    notes[i + 1] = pal[idx - 1]
    elif motif == "phonk":
        # half-time : double les silences sur off-beats
        for i in range(L):
            if i % 2 == 1 and rng.random() < 0.7:
                notes[i] = 0
    elif motif == "cinematic":
        # crescendo : densifie progressivement
        for i in range(L):
            ratio = i / max(1, L - 1)
            if notes[i] == 0 and rng.random() < ratio * 0.5 and pal:
                notes[i] = rng.choice(pal)
    elif motif == "jazz":
        # chromatic approaches
        for i in range(0, L - 1):
            if notes[i] > 0 and notes[i + 1] > 0 and rng.random() < 0.2:
                if abs(notes[i] - notes[i + 1]) > 2:
                    notes[i] = notes[i + 1] - rng.choice([-1, 1])
    elif motif == "blues":
        # bend implicite : note repetee
        for i in range(0, L - 1):
            if notes[i] > 0 and rng.random() < 0.3 and i + 1 < L:
                notes[i + 1] = notes[i]
    return notes


def generate(rng: random.Random, genre: str, length: int) -> list[int]:
    spec = GENRES[genre]
    root = rng.choice(spec["roots"])
    scale_name = rng.choice(spec["scales"])
    scale = SCALES[scale_name]
    pal = palette_for(root, scale, spec["lo"], spec["hi"])
    if not pal:
        pal = [root]
    dlow, dhigh = spec["density"]
    density = rng.uniform(dlow, dhigh)
    notes = []
    for i in range(length):
        if rng.random() < density:
            notes.append(pick_note(rng, pal, is_strong_beat(i, length), root))
        else:
            notes.append(0)
    notes = apply_motif(rng, spec["motif"], notes, pal, root)

    # AABA / ABCA structuring pour longs formats
    if length >= 64:
        section_len = length // 4
        if rng.random() < 0.5:
            # AABA
            a = notes[:section_len]
            b = notes[section_len * 2:section_len * 3]
            notes = a + a + b + a
        # else garde la generation lineaire
    if length >= 96 and rng.random() < 0.4:
        # last section : variation
        section_len = length // 6
        last = notes[-section_len:]
        last = [(n + rng.choice([-2, -1, 0, 1, 2])) if n > 0 else 0 for n in last]
        notes = notes[:-section_len] + last

    # clamp
    out = []
    for n in notes:
        if n == 0:
            out.append(0)
        else:
            out.append(max(24, min(96, n)))
    # ensure exact length
    if len(out) < length:
        out += [0] * (length - len(out))
    return out[:length]


# ---------------------------------------------------------------------------
# 3. GENRE -> SIZE FROM melodyBank
# ---------------------------------------------------------------------------

# transcrit depuis bank.scd (entries originales par genre)
ORIGINAL_BANK = {
    "acid":       ["m29", "m30", "m70", "ml1", "mxl5", "mepic5"],
    "dub":        ["m65", "ml26"],
    "trance":     ["m8", "m24", "m28", "ml2", "mxl1", "mepic1", "mxl15", "mepic6", "ml15"],
    "detroit":    ["m3", "m23", "m69", "m71", "ml3", "ml18", "mxl2", "mepic3"],
    "dnb":        ["m63", "ml4", "ml22"],
    "ambient":    ["m33", "m34", "m72", "m73", "ml5", "mxl3"],
    "world":      ["m17", "m48", "m74", "ml9", "ml25", "mxl11", "mepic9"],
    "retro":      ["m61", "m75", "m77", "ml7", "ml13", "mxl6"],
    "dark":       ["m14", "m38", "m53", "ml8", "ml28", "mxl8", "mepic8"],
    "asian":      ["m17", "m40", "m48", "m74", "ml9", "ml25", "mxl11", "mepic9"],
    "oriental":   ["m15", "m20", "m39", "m41", "m44", "m60", "ml6", "ml17", "mxl4", "mxl14", "mepic4"],
    "tribal":     ["m45", "m46", "ml10", "mxl12"],
    "industrial": ["m67", "m68", "ml11", "ml24", "mxl9", "mepic7"],
    "synthwave":  ["m61", "ml7", "mxl6"],
    "chiptune":   ["m62", "ml20", "mxl13"],
    "phonk":      ["m66", "ml19"],
    "hardcore":   ["m67", "ml24", "mxl9", "mepic7"],
    "pop":        ["m35", "m36", "m49", "m50", "ml14", "mxl10"],
    "jazz":       ["m51", "m52", "ml16", "ml27"],
    "blues":      ["m16", "m47"],
    "hypnotic":   ["m2", "m11", "m27", "m54", "m55", "m56", "ml12", "mxl7"],
    "pad":        ["m33", "m34", "ml5", "mxl3"],
    "pluck":      ["m32"],
    "sub":        ["m5", "m31", "m37", "m63", "ml4"],
    "drone":      ["m37", "m38"],
    "tension":    ["m53", "m59", "ml28", "m58", "ml30"],
    "chromatic":  ["m57", "ml29"],
    "cinematic":  ["m73", "mxl3", "mepic2", "mepic10"],
}


def length_split(n: int) -> tuple[int, int, int, int]:
    """70% short, 20% long, 8% xlong, 2% epic; ensure at least 1 each."""
    s = max(1, round(n * 0.70))
    l = max(1, round(n * 0.20))
    x = max(1, round(n * 0.08))
    e = max(1, round(n * 0.02))
    return s, l, x, e


# ---------------------------------------------------------------------------
# 4. MAIN
# ---------------------------------------------------------------------------

def main() -> None:
    rng = random.Random(42)

    # 4.1 Backups (skip if exists)
    for name, (path, _, _) in SOURCES.items():
        bak = MIG / f"palette_melodies_{name}.scd.bak"
        if not bak.exists() and path.exists():
            shutil.copy2(path, bak)
            print(f"backup {bak.name}")

    # 4.2 Parse + create dirs + write per-melody files
    parsed: dict[str, dict[str, list[int]]] = {}
    for name, (path, prefix, length) in SOURCES.items():
        sub = MEL / name
        sub.mkdir(exist_ok=True)
        parsed[name] = parse_source(path)
        # write per-var files
        for var, notes in parsed[name].items():
            # detect genre hint via reverse lookup in ORIGINAL_BANK
            hint = "various"
            for g, vlist in ORIGINAL_BANK.items():
                if var in vlist:
                    hint = g
                    break
            out = sub / f"{var}.scd"
            write_one(out, var, name, hint, notes)
        print(f"{name}: {len(parsed[name])} fichiers individuels ecrits dans {sub}")

    # 4.3 Generate new melodies, count per genre per length-bucket
    new_bank: dict[str, list[str]] = {g: [] for g in ORIGINAL_BANK}
    stats = {}
    for genre, originals in ORIGINAL_BANK.items():
        target = max(1, len(originals)) * 20
        s, l, x, e = length_split(target)
        stats[genre] = dict(orig=len(originals), target=target, s=s, l=l, x=x, e=e)
        # camelCase: m + Genre + N (capitalize first letter only)
        g_cap = genre[0].upper() + genre[1:]
        # numbering starts at 100 for safety
        for i, length in [(s, 32), (l, 64), (x, 96), (e, 128)]:
            pass  # placeholder
        configs = [
            ("short", "m",     32, s),
            ("long",  "ml",    64, l),
            ("xlong", "mxl",   96, x),
            ("epic",  "mepic", 128, e),
        ]
        for sub_name, prefix, length, count in configs:
            sub = MEL / sub_name
            for n in range(count):
                var = f"{prefix}{g_cap}{100 + n}"
                notes = generate(rng, genre, length)
                out = sub / f"{var}.scd"
                write_one(out, var, sub_name, genre, notes)
                new_bank[genre].append(var)

    # 4.4 stats summary
    total_orig = sum(len(v) for v in parsed.values())
    total_new = sum(len(v) for v in new_bank.values())
    print(f"\n=== STATS ===")
    for g, st in stats.items():
        print(f"  {g:12s}: {st['orig']:3d} originales x 20 = {st['target']:3d} nouvelles "
              f"(s={st['s']} l={st['l']} x={st['x']} e={st['e']})")
    print(f"\nTotal original  : {total_orig}")
    print(f"Total nouvelles : {total_new}")
    print(f"Total fichiers  : {total_orig + total_new}")

    # 4.5 update bank.scd : append new vars to each genre
    bank_path = MEL / "bank.scd"
    bank_text = bank_path.read_text()
    # remplace la table ~melodyBank en ajoutant les nouvelles entries
    new_block_lines = ["~melodyBank = ("]
    items = list(ORIGINAL_BANK.items())
    for i, (g, originals) in enumerate(items):
        all_keys = originals + new_bank[g]
        keys_fmt = ", ".join(f"\\{k}" for k in all_keys)
        suffix = "," if i < len(items) - 1 else ""
        new_block_lines.append(f"    \\{g}: [{keys_fmt}]{suffix}")
    new_block_lines.append(");")
    new_block = "\n".join(new_block_lines)
    # split par ligne et trouve le bloc ~melodyBank = ( ... );
    # on cherche la ligne qui commence par ~melodyBank et on remplace
    # jusqu'a la ligne qui contient "); " seul (fin du dict)
    lines = bank_text.split("\n")
    start_idx = None
    end_idx = None
    for i, ln in enumerate(lines):
        if start_idx is None and ln.strip().startswith("~melodyBank"):
            start_idx = i
        elif start_idx is not None and ln.strip() == ");":
            end_idx = i
            break
    if start_idx is None or end_idx is None:
        raise RuntimeError("bloc ~melodyBank introuvable dans bank.scd")
    bank_text_new = "\n".join(
        lines[:start_idx] + [new_block] + lines[end_idx + 1:]
    )
    bank_path.write_text(bank_text_new)
    print(f"\nbank.scd mis a jour ({len(new_block)} chars dans le bloc melodyBank)")

    # 4.6 update index.scd : recursive load via PathName
    index_path = MEL / "index.scd"
    index_content = (
        "// =====================================================================\n"
        "//  palette/melodies/index.scd  --  loader recursif (post-split v2)\n"
        "//\n"
        "//  Charge :\n"
        "//    helpers.scd                (helpers melodiques)\n"
        "//    short/<*.scd>              ~m1..~m78 + ~m{Genre}100..\n"
        "//    long/<*.scd>               ~ml1..~ml30 + ~ml{Genre}100..\n"
        "//    xlong/<*.scd>              ~mxl1..~mxl15 + ~mxl{Genre}100..\n"
        "//    epic/<*.scd>               ~mepic1..~mepic10 + ~mepic{Genre}100..\n"
        "//    bank.scd                   ~melodyBank + selecteurs\n"
        "//    tracks.scd                 systeme multi-pistes\n"
        "//\n"
        "//  Un seul bloc top-level (compatible .load).\n"
        "// =====================================================================\n"
        "(\n"
        "var dir = thisProcess.nowExecutingPath.dirname;\n"
        "(dir +/+ \"helpers.scd\").load;\n"
        "[\"short\", \"long\", \"xlong\", \"epic\"].do { |sub|\n"
        "    PathName(dir +/+ sub).files.do { |f|\n"
        "        if (f.extension == \"scd\") { f.fullPath.load };\n"
        "    };\n"
        "};\n"
        "(dir +/+ \"bank.scd\").load;\n"
        "(dir +/+ \"tracks.scd\").load;\n"
        "\"=== melodies module loaded (recursive) ===\".postln;\n"
        ")\n"
    )
    index_path.write_text(index_content)
    print("index.scd mis a jour (loader recursif)")

    # 4.7 supprime les 4 sources monolithiques (backups deja faits)
    for name, (path, _, _) in SOURCES.items():
        if path.exists():
            path.unlink()
            print(f"supprime {path.name}")


if __name__ == "__main__":
    main()
