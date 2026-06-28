"""End-to-end build tests — verify the full .tosc file embeds Lua scripts."""
from gen import layout, schema


def _all_scripts(parsed):
    """Return a concatenated string of all script property values in the tree."""
    texts = [
        p.find("value").text
        for p in parsed.findall(".//property[@type='s']")
        if p.find("key") is not None and p.find("key").text == "script"
        and p.find("value") is not None
    ]
    return "\n".join(t for t in texts if t)


def test_scripts_embedded(tmp_path):
    root = layout.build()
    out = tmp_path / "full.tosc"
    schema.write_tosc(root, str(out))
    parsed = schema.read_tosc(str(out))
    joined = _all_scripts(parsed)
    assert 'sendOSC("/seq/rhythm/set"' in joined, "rhythm grid Lua not embedded"
    assert "/armed/" in joined, "pad Lua not embedded"
    assert "/sync/beat" in joined, "feedback Lua not embedded"
    assert 'sendOSC("/seq/melody/set"' in joined, "melody_faders Lua not embedded"
    assert "findByName" in joined, "preset_select Lua not embedded"


def test_schema_partial_helpers():
    """Verify the new typed-partial helpers produce correct element shapes."""
    ci = schema.consti(42)
    cf = schema.constf(3.14)
    vi = schema.vali()
    vf = schema.valf(60, 200)

    el_ci = ci.to_el()
    assert el_ci.find("conversion").text == "INTEGER"
    assert el_ci.find("value").text == "42"
    assert el_ci.find("type").text == "CONSTANT"

    el_cf = cf.to_el()
    assert el_cf.find("type").text == "CONSTANT"
    assert el_cf.find("conversion").text == "FLOAT"
    assert el_cf.find("value").text == "3.14"

    el_vi = vi.to_el()
    assert el_vi.find("conversion").text == "INTEGER"
    assert el_vi.find("value").text == "x"
    assert el_vi.find("type").text == "VALUE"

    el_vf = vf.to_el()
    assert el_vf.find("conversion").text == "FLOAT"
    assert el_vf.find("scaleMin").text == "60"
    assert el_vf.find("scaleMax").text == "200"


def test_build_writes_tosc_file(tmp_path):
    """build() produces a valid gzip-XML file that round-trips cleanly."""
    root = layout.build()
    out = tmp_path / "av-live-control.tosc"
    schema.write_tosc(root, str(out))
    parsed = schema.read_tosc(str(out))
    assert parsed is not None
    assert parsed.get("type") == "GROUP"
    name_el = parsed.find("properties/property[key='name']/value")
    assert name_el is not None and name_el.text == "av-live-control"
