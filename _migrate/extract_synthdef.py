"""
Extract SynthDef(\name, { ... }).add; blocks from .scd source files
and route them into synth/ or fx/ subdirectories per classify().
"""
import re, sys
from pathlib import Path

CAMEL_TO_SNAKE = re.compile(r'(?<!^)(?=[A-Z])')

def to_snake(name: str) -> str:
    return CAMEL_TO_SNAKE.sub('_', name).lower()

def classify(name):
    # Master / utility
    if name in {'masterLim','masterComp','masterSat','vinyl'}: return 'synth/master'
    # Trick (FX oneshot) — includes master-bus trick FX
    if name in {'riser','sweep','impact','crash','scratch',
                'fxMasterPitch','fxMasterRing','fxMasterFreqShift',
                'fxMasterBitcrush','fxMasterGran'}: return 'fx/trick'
    # Drums
    if name in {'kick','kickGabber','hat','openHat','snare','snareGated',
                'clap','perc','rim','cowbell','tom','kick808'}: return 'synth/drums'
    # Bass
    if name in {'acid','reese','reeseDnB','reeseHard','subBoom','fmBass',
                'hooverbass','didgeridoo','bass808'}: return 'synth/bass'
    # Pad
    if name in {'pad','warmPad','vocalPad','drone','choir','strings'}: return 'synth/pad'
    # World
    if name in {'koto','erhu','pipa','gong','handpan','guzheng','growl',
                'taiko','tabla','shakuhachi'}: return 'synth/world'
    # Lead
    if name in {'saw3','lead','squareLead','fmLead','organLead','hardLead',
                'supersaw','stab','pluck','fmBell','rhodes','flute'}: return 'synth/lead'
    return None

# Source-driven fallback
SOURCE_FALLBACK = {
    'live/fx_bus.scd': 'fx/bus',
    'live/live.scd': 'fx/insert',
    'synthdefs/asia.scd': 'synth/world',
}

def find_synthdefs(src: str):
    results = []
    i = 0
    n = len(src)
    while i < n:
        m = re.search(r'SynthDef\(\\(\w+),', src[i:])
        if not m:
            break
        name = m.group(1)
        start = i + m.start()
        depth = 0
        j = start
        in_string = False
        in_block_comment = False
        in_line_comment = False
        found = False
        while j < n:
            ch = src[j]
            ch2 = src[j:j+2]
            if in_line_comment:
                if ch == '\n': in_line_comment = False
            elif in_block_comment:
                if ch2 == '*/': in_block_comment = False; j += 1
            elif in_string:
                if ch == '"' and src[j-1] != '\\': in_string = False
            elif ch2 == '//': in_line_comment = True; j += 1
            elif ch2 == '/*': in_block_comment = True; j += 1
            elif ch == '"': in_string = True
            elif ch == '{': depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    rest = src[j+1:j+30]
                    add_m = re.match(r'\s*\)\.add\s*;', rest)
                    if add_m:
                        end = j + 1 + add_m.end()
                        block = src[start:end]
                        results.append((name, block))
                        i = end
                        found = True
                        break
            j += 1
        if not found:
            break
    return results


def route(source_files):
    base = Path(".")
    for src_path in source_files:
        src = Path(src_path).read_text()
        blocks = find_synthdefs(src)
        print(f"-- {src_path}: {len(blocks)} SynthDef")
        for name, block in blocks:
            target = classify(name)
            if target is None:
                # Source-driven fallback
                target = SOURCE_FALLBACK.get(src_path)
            if target is None:
                print(f"  [FAIL] no route for \\{name} from {src_path}")
                sys.exit(1)
            target_dir = base / target
            target_dir.mkdir(parents=True, exist_ok=True)
            out = target_dir / f"{to_snake(name)}.scd"
            wrapped = (
                f"// =====================================================================\n"
                f"//  {target}/{out.name}  --  SynthDef \\{name}\n"
                f"//  Extracted from {Path(src_path).name} during v2 reorganization.\n"
                f"// =====================================================================\n"
                f"(\n{block}\n)\n"
            )
            out.write_text(wrapped)
            print(f"  \\{name:25s} -> {out}")


def strip(path):
    src = Path(path).read_text()
    blocks = find_synthdefs(src)
    if not blocks:
        return
    for name, block in reversed(blocks):
        idx = src.find(block)
        if idx >= 0:
            src = src[:idx] + src[idx + len(block):]
    Path(path).write_text(src)
    print(f"  stripped {len(blocks)} SynthDef from {path}")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "route":
        route(sys.argv[2:])
    elif cmd == "strip":
        for p in sys.argv[2:]:
            strip(p)
    else:
        print("Usage: extract_synthdef.py {route|strip} <files...>")
        sys.exit(1)
