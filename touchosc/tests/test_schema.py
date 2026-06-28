from gen import schema


def test_roundtrip_minimal_fader(tmp_path):
    fader = schema.node(
        "FADER",
        props=[
            schema.prop("name", "vol", "s"),
            schema.frame(10, 20, 60, 200),
        ],
        messages=[
            schema.osc("/launch/vol", [schema.const("kick"), schema.val()]),
        ],
    )
    root = schema.node("GROUP", props=[schema.prop("name", "root", "s")],
                       children=[fader])
    out = tmp_path / "min.tosc"
    schema.write_tosc(root, str(out))
    parsed = schema.read_tosc(str(out))
    assert parsed.tag == "node"
    assert parsed.get("type") == "GROUP"
    child = parsed.find("children/node")
    assert child.get("type") == "FADER"
    # Partial fields are child elements in TouchOSC v3 (confirmed against a
    # real app re-save), so the address lives in <partial><value>, not an attr.
    addr = child.find("messages/osc/path/partial/value")
    assert addr.text == "/launch/vol"
