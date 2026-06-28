"""Layout structure tests — assert pages, addresses, and widget counts."""
from gen import layout, schema


def _addrs(el):
    """Return the set of OSC path address strings found anywhere under ``el``."""
    return {
        p.find("value").text
        for p in el.findall(".//messages/osc/path/partial")
        if p.find("value") is not None
    }


def _addr_list(el):
    return [
        p.find("value").text
        for p in el.findall(".//messages/osc/path/partial")
        if p.find("value") is not None
    ]


# ---------------------------------------------------------------------------
# Root / pager
# ---------------------------------------------------------------------------

def test_root_has_pager_with_three_pages(tmp_path):
    root = layout.build()
    out = tmp_path / "full.tosc"
    schema.write_tosc(root, str(out))
    parsed = schema.read_tosc(str(out))
    pager = parsed.find(".//node[@type='PAGER']")
    assert pager is not None, "PAGER node not found"
    pages = pager.findall("children/node[@type='GROUP']")
    assert len(pages) == 3, f"expected 3 pages, got {len(pages)}"


def test_sixteen_patterns():
    assert layout.PATTERNS == [
        "kick", "hats", "clap", "perc",
        "sub", "acid", "arp", "lead",
        "stab", "pad", "ride", "rim",
        "tom", "reese", "bells", "sweep",
    ]


# ---------------------------------------------------------------------------
# Page 1 — LIVE
# ---------------------------------------------------------------------------

def test_live_page_has_16_launch_buttons():
    page = layout.live_page()
    buttons = page.findall(".//node[@type='BUTTON']")
    launch = [
        b for b in buttons
        if b.find("messages/osc/path/partial/value") is not None
        and b.find("messages/osc/path/partial/value").text == "/launch"
    ]
    assert len(launch) == 16, f"expected 16 /launch buttons, got {len(launch)}"


def test_live_page_has_16_vol_faders():
    page = layout.live_page()
    faders = page.findall(".//node[@type='FADER']")
    vol = [
        f for f in faders
        if f.find("messages/osc/path/partial/value") is not None
        and f.find("messages/osc/path/partial/value").text == "/launch/vol"
    ]
    assert len(vol) == 16, f"expected 16 /launch/vol faders, got {len(vol)}"


def test_live_page_has_tempo_and_clear():
    page = layout.live_page()
    addrs = _addrs(page)
    assert "/launch/tempo" in addrs
    assert "/launch/clear" in addrs


def test_live_page_has_rms_receive():
    page = layout.live_page()
    addrs = _addrs(page)
    assert "/sync/rms" in addrs
    assert "/sync/beat" in addrs


# ---------------------------------------------------------------------------
# Page 2 — FX / HARMONIE / CONCERT
# ---------------------------------------------------------------------------

def test_fx_page_addresses():
    page = layout.fx_page()
    addrs = _addrs(page)
    required = [
        "/control/fx/filter",
        "/control/fx/stutter",
        "/control/fx/crash",
        "/control/fx/kick",
        "/control/fx/swell",
        "/control/fx/breakdown",
        "/control/harmony/root",
        "/control/harmony/scale",
        "/control/harmony/octave",
        "/control/harmony/phrase",
        "/control/concertNext",
        "/control/doScene",
    ]
    for a in required:
        assert a in addrs, f"missing address {a}"


def test_fx_page_body_play_uses_doScene():
    """body-play must be /control/doScene, NOT /control/bodyPlay."""
    page = layout.fx_page()
    addrs = _addrs(page)
    assert "/control/doScene" in addrs
    assert "/control/bodyPlay" not in addrs


def test_fx_page_harmony_scale_sends_string_name():
    """Scale buttons must send string names (minor/dorian/phrygian/penta),
    not integer indices."""
    page = layout.fx_page()
    # Find all argument partials on /control/harmony/scale messages
    scale_args = []
    for osc_el in page.findall(".//messages/osc"):
        path_val = osc_el.find("path/partial/value")
        if path_val is not None and path_val.text == "/control/harmony/scale":
            for part in osc_el.findall("arguments/partial"):
                conv = part.find("conversion")
                val = part.find("value")
                if conv is not None and val is not None:
                    scale_args.append((conv.text, val.text))
    assert len(scale_args) == 4, f"expected 4 scale arg partials, got {len(scale_args)}"
    for conv, val in scale_args:
        assert conv == "STRING", f"scale arg must be STRING, got {conv}"
        assert val in layout.SCALES, f"scale arg '{val}' not in SCALES"


def test_fx_page_harmony_octave_absolute():
    """Octave buttons must send absolute values 0, 1, 2 (not relative)."""
    page = layout.fx_page()
    octave_args = []
    for osc_el in page.findall(".//messages/osc"):
        path_val = osc_el.find("path/partial/value")
        if path_val is not None and path_val.text == "/control/harmony/octave":
            for part in osc_el.findall("arguments/partial"):
                conv = part.find("conversion")
                val = part.find("value")
                if conv is not None and val is not None:
                    octave_args.append((conv.text, val.text))
    assert len(octave_args) == 3, f"expected 3 octave buttons, got {len(octave_args)}"
    vals = {v for _, v in octave_args}
    assert vals == {"0", "1", "2"}, f"expected octave values 0,1,2, got {vals}"


def test_fx_page_breakdown_constant_integer():
    """breakdown buttons must send CONSTANT/INTEGER args with values {0, 1}."""
    page = layout.fx_page()
    breakdown_args = []
    for osc_el in page.findall(".//messages/osc"):
        path_val = osc_el.find("path/partial/value")
        if path_val is not None and path_val.text == "/control/fx/breakdown":
            for part in osc_el.findall("arguments/partial"):
                typ = part.find("type")
                conv = part.find("conversion")
                val = part.find("value")
                if typ is not None and conv is not None and val is not None:
                    breakdown_args.append((typ.text, conv.text, val.text))
    assert len(breakdown_args) == 2, f"expected 2 breakdown arg partials, got {len(breakdown_args)}"
    for typ, conv, _ in breakdown_args:
        assert typ == "CONSTANT", f"breakdown arg type must be CONSTANT, got {typ}"
        assert conv == "INTEGER", f"breakdown arg conversion must be INTEGER, got {conv}"
    vals = {v for _, _, v in breakdown_args}
    assert vals == {"0", "1"}, f"expected breakdown values {{0,1}}, got {vals}"


def test_fx_page_harmony_root_constant_integer():
    """root buttons must send CONSTANT/INTEGER args with values {-2, 2}."""
    page = layout.fx_page()
    root_args = []
    for osc_el in page.findall(".//messages/osc"):
        path_val = osc_el.find("path/partial/value")
        if path_val is not None and path_val.text == "/control/harmony/root":
            for part in osc_el.findall("arguments/partial"):
                typ = part.find("type")
                conv = part.find("conversion")
                val = part.find("value")
                if typ is not None and conv is not None and val is not None:
                    root_args.append((typ.text, conv.text, val.text))
    assert len(root_args) == 2, f"expected 2 root arg partials, got {len(root_args)}"
    for typ, conv, _ in root_args:
        assert typ == "CONSTANT", f"root arg type must be CONSTANT, got {typ}"
        assert conv == "INTEGER", f"root arg conversion must be INTEGER, got {conv}"
    vals = {v for _, _, v in root_args}
    assert vals == {"-2", "2"}, f"expected root values {{-2,2}}, got {vals}"


# ---------------------------------------------------------------------------
# Page 3 — SEQ
# ---------------------------------------------------------------------------

def test_seq_page_grid_and_faders():
    page = layout.seq_page()
    assert page.find(".//node[@type='GRID']") is not None, "GRID node not found"
    addrs = _addr_list(page)
    assert "/seq/rhythm" in addrs
    assert "/seq/melody" in addrs
    assert "/seq/rhythm/set" in addrs
    assert "/seq/melody/set" in addrs
    # 8 melody step faders identified by their nominal /seq/melody/set address
    mel = [
        f for f in page.findall(".//node[@type='FADER']")
        if f.find("messages/osc/path/partial/value") is not None
        and f.find("messages/osc/path/partial/value").text == "/seq/melody/set"
    ]
    assert len(mel) == 8, f"expected 8 melody step faders, got {len(mel)}"


def test_seq_page_arm_buttons():
    """ARM MEL and ARM RHY both send to /launch (with melseq/rhythmseq name)."""
    page = layout.seq_page()
    buttons = page.findall(".//node[@type='BUTTON']")
    arm = [
        b for b in buttons
        if b.find("messages/osc/path/partial/value") is not None
        and b.find("messages/osc/path/partial/value").text == "/launch"
    ]
    assert len(arm) == 2, f"expected 2 ARM buttons on seq page, got {len(arm)}"


def test_seq_page_rhythm_presets_use_consti():
    """Rhythm preset buttons must send INTEGER index (not float/string)."""
    page = layout.seq_page()
    rhythm_indices = []
    for osc_el in page.findall(".//messages/osc"):
        path_val = osc_el.find("path/partial/value")
        if path_val is not None and path_val.text == "/seq/rhythm":
            for part in osc_el.findall("arguments/partial"):
                conv = part.find("conversion")
                if conv is not None and conv.text == "INTEGER":
                    rhythm_indices.append(part.find("value").text)
    assert len(rhythm_indices) == 8, f"expected 8 rhythm preset buttons, got {len(rhythm_indices)}"


def test_seq_page_no_sync_amp():
    """Per-voice VU strip is deliberately omitted; /sync/amp must not appear."""
    page = layout.seq_page()
    addrs = _addrs(page)
    assert "/sync/amp" not in addrs, "/sync/amp found — per-voice VU was supposed to be omitted"
