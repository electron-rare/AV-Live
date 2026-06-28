"""AV-Live TouchOSC layout generator.

Builds a three-page PAGER layout (LIVE / FX+HARM+CONCERT / SEQ) for the
AV-Live SuperCollider engine on macm1 (control port 57121).

All OSC addresses and arg types follow the authoritative mapping in:
  docs/superpowers/plans/2026-06-28-touchosc-control-surface.md (brief override).
"""
import os

from gen import schema as s

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CANVAS = (1194, 834)

PATTERNS = [
    "kick", "hats", "clap", "perc",
    "sub",  "acid", "arp",  "lead",
    "stab", "pad",  "ride", "rim",
    "tom",  "reese", "bells", "sweep",
]

SCALES = ["minor", "dorian", "phrygian", "penta"]

_LUA_DIR = os.path.join(os.path.dirname(__file__), "lua")


def _lua(name):
    """Load a Lua script by filename from the lua/ directory adjacent to this module."""
    with open(os.path.join(_LUA_DIR, name), encoding="utf-8") as fh:
        return fh.read()


# ---------------------------------------------------------------------------
# Primitive widget builders
# ---------------------------------------------------------------------------

def label(text, x, y, w, h):
    """A read-only LABEL node."""
    return s.node("LABEL", [s.prop("name", text, "s"), s.frame(x, y, w, h)])


def button(lbl, address, x, y, w, h, args=None):
    """A momentary/toggle BUTTON.  ``args`` is a list of Partial objects."""
    return s.node(
        "BUTTON",
        [s.prop("name", lbl, "s"), s.frame(x, y, w, h)],
        messages=[s.osc(address, args or [])],
    )


def vfader(address, args, x, y, w, h, recv_address=None, recv_args=None):
    """A vertical FADER.  Optional receive-only message for feedback."""
    msgs = [s.osc(address, args)]
    if recv_address is not None:
        msgs.append(s.osc(recv_address, recv_args or [s.val()],
                          send=0, receive=1, feedback=1))
    return s.node(
        "FADER",
        [s.prop("name", "", "s"), s.frame(x, y, w, h)],
        messages=msgs,
    )


# ---------------------------------------------------------------------------
# Pad cell (page 1)
# ---------------------------------------------------------------------------

def _pad_cell(name, x, y, w, h):
    """One pad cell: arm BUTTON + vol FADER + name LABEL, inside a GROUP.

    The GROUP carries pad.lua which reflects /armed/<name> back as color.
    The arm BUTTON sends /launch [const(name), vali()].
    The vol FADER sends /launch/vol [const(name), valf(0,1.5)].
    """
    btn_h = h - 26
    arm_btn = s.node(
        "BUTTON",
        [s.prop("name", name, "s"), s.frame(0, 0, w - 20, btn_h)],
        messages=[
            s.osc("/launch", [s.const(name), s.vali()]),
            s.osc(f"/armed/{name}", [s.val()], send=0, receive=1, feedback=1),
        ],
    )
    vol_fader = s.node(
        "FADER",
        [s.prop("name", f"vol_{name}", "s"), s.frame(w - 18, 0, 16, btn_h)],
        messages=[s.osc("/launch/vol", [s.const(name), s.valf(0, 1.5)])],
    )
    name_label = label(name, 0, btn_h + 2, w, 22)
    return s.node(
        "GROUP",
        [
            s.prop("name", f"pad_{name}", "s"),
            s.frame(x, y, w, h),
            s.script(_lua("pad.lua")),
        ],
        children=[arm_btn, vol_fader, name_label],
    )


# ---------------------------------------------------------------------------
# Page 1 — LIVE
# ---------------------------------------------------------------------------

def live_page():
    """Page 1: top bar (tempo, clear, VU, beat) + 4x4 pad grid."""
    page = s.node("GROUP", [s.prop("name", "LIVE", "s"), s.frame(0, 0, *CANVAS)])
    ch = page.find("children")

    # Top bar ----------------------------------------------------------------
    # Tempo fader: value 0..1 -> BPM 60..200
    ch.append(s.node(
        "FADER",
        [s.prop("name", "tempo", "s"), s.frame(10, 8, 300, 50)],
        messages=[s.osc("/launch/tempo", [s.valf(60, 200)])],
    ))
    ch.append(label("TEMPO", 10, 60, 100, 20))

    # Clear all
    ch.append(button("CLEAR ALL", "/launch/clear", 322, 8, 150, 50, args=[]))

    # Master VU fader (receive-only /sync/rms)
    ch.append(s.node(
        "FADER",
        [s.prop("name", "rms", "s"), s.frame(490, 8, 40, 72),
         s.script(_lua("feedback.lua"))],
        messages=[s.osc("/sync/rms", [s.val()], send=0, receive=1, feedback=1)],
    ))

    # Beat flash box (receive-only /sync/beat)
    ch.append(s.node(
        "BOX",
        [s.prop("name", "beat", "s"), s.frame(542, 8, 72, 72),
         s.script(_lua("feedback.lua"))],
        messages=[s.osc("/sync/beat", [s.val()], send=0, receive=1, feedback=1)],
    ))

    # 4x4 pad grid -----------------------------------------------------------
    gx, gy, pw, ph, gap = 10, 96, 283, 178, 10
    for i, name in enumerate(PATTERNS):
        col, row = i % 4, i // 4
        x = gx + col * (pw + gap)
        y = gy + row * (ph + gap)
        ch.append(_pad_cell(name, x, y, pw, ph))

    return page


# ---------------------------------------------------------------------------
# Page 2 — FX / HARMONIE / CONCERT
# ---------------------------------------------------------------------------

def fx_page():
    """Page 2: FX column, harmony column, concert column."""
    page = s.node(
        "GROUP",
        [s.prop("name", "FX-HARM-CONCERT", "s"), s.frame(0, 0, *CANVAS)],
    )
    ch = page.find("children")

    # FX column (x=10..440) --------------------------------------------------
    ch.append(label("FILTER", 10, 8, 80, 22))
    ch.append(s.node(
        "FADER",
        [s.prop("name", "filter", "s"), s.frame(10, 36, 80, 350)],
        messages=[s.osc("/control/fx/filter", [s.valf(0, 1)])],
    ))

    # One-shot buttons (vali() — engine ignores arg, just triggers)
    one_shots = [("STUTTER", "stutter"), ("CRASH", "crash"),
                 ("KICK",    "kick"),    ("SWELL",  "swell")]
    for i, (lbl, key) in enumerate(one_shots):
        ch.append(button(lbl, f"/control/fx/{key}",
                         100, 36 + i * 70, 160, 56, args=[s.vali()]))

    ch.append(button("BREAKDOWN IN",  "/control/fx/breakdown",
                     100, 316, 160, 56, args=[s.consti(1)]))
    ch.append(button("BREAKDOWN OUT", "/control/fx/breakdown",
                     100, 382, 160, 56, args=[s.consti(0)]))

    # Harmony column (x=290..780) --------------------------------------------
    ch.append(label("HARMONIE", 290, 8, 200, 22))

    ch.append(button("ROOT -", "/control/harmony/root",
                     290, 36, 145, 52, args=[s.consti(-2)]))
    ch.append(button("ROOT +", "/control/harmony/root",
                     445, 36, 145, 52, args=[s.consti(2)]))

    # Scale buttons: 2x2, each sends the string name (NOT index)
    scale_xy = [(290, 100), (445, 100), (290, 162), (445, 162)]
    for (sx, sy), scale_name in zip(scale_xy, SCALES):
        ch.append(button(scale_name.upper(), "/control/harmony/scale",
                         sx, sy, 145, 52, args=[s.const(scale_name)]))

    # Octave: three absolute buttons (0, 1, 2)
    for n in range(3):
        ch.append(button(f"OCT {n}", "/control/harmony/octave",
                         290 + n * 100, 234, 90, 52, args=[s.consti(n)]))

    # Phrase: four absolute buttons (0..3)
    for p in range(4):
        ch.append(button(f"PH {p}", "/control/harmony/phrase",
                         290 + p * 75, 306, 65, 52, args=[s.consti(p)]))

    # Concert column (x=620..900) --------------------------------------------
    ch.append(label("CONCERT", 620, 8, 200, 22))

    ch.append(button("MORCEAU >", "/control/concertNext",
                     620, 36, 260, 64, args=[]))
    ch.append(button("CONCERT", "/control/doScene",
                     620, 110, 260, 64, args=[s.const("concert")]))
    # body-play is /control/doScene "play" — NOT /control/bodyPlay
    ch.append(button("BODY-PLAY", "/control/doScene",
                     620, 184, 260, 64, args=[s.const("play")]))

    return page


# ---------------------------------------------------------------------------
# Page 3 — SEQUENCEURS
# ---------------------------------------------------------------------------

def seq_page():
    """Page 3: rhythm grid + melody faders + preset selectors + arm buttons.

    Per-voice VU strip deliberately omitted: the engine sums all voices to
    bus 0; per-voice live levels are not producible.  Master RMS VU on page 1
    is the only meter.  Do not add /sync/amp receivers here.
    """
    page = s.node(
        "GROUP",
        [
            s.prop("name", "SEQ", "s"),
            s.frame(0, 0, *CANVAS),
            s.script(_lua("preset_select.lua")),
        ],
        messages=[
            s.osc("/seq/rhythm/state", [s.val()], send=0, receive=1, feedback=1),
            s.osc("/seq/melody/state", [s.val()], send=0, receive=1, feedback=1),
        ],
    )
    ch = page.find("children")

    # Rhythm section (x=10..595) ---------------------------------------------
    ch.append(label("RYTHME", 10, 8, 120, 22))

    step = 74  # button width + gap
    for i in range(8):
        bx = 10 + i * step
        ch.append(button(f"R{i + 1}", "/seq/rhythm",
                         bx, 36, 66, 44, args=[s.consti(i)]))
        # Name label updated by preset_select.lua via /seq/rhythm/state
        nl = s.node(
            "LABEL",
            [s.prop("name", f"R{i + 1}", "s"), s.frame(bx, 86, 66, 22)],
        )
        ch.append(nl)

    # 3x16 rhythm grid
    rhythm_grid = s.node(
        "GRID",
        [
            s.prop("name", "rhythmgrid", "s"),
            s.frame(10, 114, 580, 162),
            s.prop("gridX", "16", "s"),
            s.prop("gridY", "3", "s"),
            s.script(_lua("rhythm_grid.lua")),
        ],
        messages=[
            # Nominal address for testability; Lua emits the real OSC.
            s.osc("/seq/rhythm/set", [], send=0, receive=0),
            s.osc("/seq/rhythm/state", [s.val()], send=0, receive=1, feedback=1),
        ],
    )
    ch.append(rhythm_grid)

    # Melody section (x=600..1185) -------------------------------------------
    ch.append(label("MELODIE", 600, 8, 120, 22))

    mstep = 74  # fader width + gap
    for i in range(8):
        fx = 600 + i * mstep
        ch.append(button(f"M{i + 1}", "/seq/melody",
                         fx, 36, 66, 44, args=[s.consti(i)]))
        # Melody step fader (melody_faders.lua emits /seq/melody/set)
        mel_fader = s.node(
            "FADER",
            [
                s.prop("name", f"m{i}", "s"),
                s.frame(fx, 86, 66, 200),
                s.script(_lua("melody_faders.lua")),
            ],
            messages=[
                # Nominal address so tests can find these 8 faders by address.
                s.osc("/seq/melody/set", [], send=0, receive=0),
            ],
        )
        ch.append(mel_fader)

    # ARM melody + rhythm buttons (below faders, y=296)
    ch.append(button("ARM MEL", "/launch",
                     600, 296, 130, 44, args=[s.const("melseq"), s.vali()]))
    ch.append(button("ARM RHY", "/launch",
                     738, 296, 130, 44, args=[s.const("rhythmseq"), s.vali()]))

    return page


# ---------------------------------------------------------------------------
# Pager + root
# ---------------------------------------------------------------------------

def pager(pages):
    """Wrap a list of page GROUP nodes in a PAGER."""
    return s.node(
        "PAGER",
        [s.prop("name", "pager", "s"), s.frame(0, 0, *CANVAS)],
        children=pages,
    )


def build():
    """Assemble and return the full root node (called by build_layout.py)."""
    root = s.node(
        "GROUP",
        [s.prop("name", "av-live-control", "s"), s.frame(0, 0, *CANVAS)],
        children=[pager([live_page(), fx_page(), seq_page()])],
    )
    return root
