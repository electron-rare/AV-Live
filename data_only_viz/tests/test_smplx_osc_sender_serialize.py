"""SMPLXTCPSender._serialize_persons produces the expected binary frame."""

import struct
import numpy as np

from data_only_viz.smplx_osc_sender import SMPLXTCPSender
from data_only_viz.state import SMPLXPerson

# Frame header: MAGIC(4) + n_persons(4) = 8 bytes before per-person data
_HEADER = 8
# Per-person: pid(4) + conf(4) + trans(12) + betas(40) + expr(40) + verts(125700)
_PER_PERSON = 4 + 4 + 12 + 40 + 40 + 10475 * 3 * 4


def _make_person(pid: int = 7) -> SMPLXPerson:
    rng = np.random.default_rng(seed=42)
    return SMPLXPerson(
        pid=pid,
        confidence=0.83,
        translation=np.array([0.1, 0.2, 0.3], dtype=np.float32),
        betas=rng.standard_normal(10).astype(np.float32),
        expression=rng.standard_normal(10).astype(np.float32),
        vertices_3d=rng.standard_normal((10475, 3)).astype(np.float32),
    )


def test_serialize_person_layout():
    p = _make_person()
    # _serialize_persons returns bytes starting with MAGIC + n_persons header
    payload = SMPLXTCPSender._serialize_persons([p])

    assert len(payload) == _HEADER + _PER_PERSON

    # Check MAGIC and n_persons header
    assert payload[:4] == b"SMPX"
    (n_persons,) = struct.unpack_from("<i", payload, 4)
    assert n_persons == 1

    # Parse per-person fields starting at offset 8
    base = _HEADER
    pid, conf = struct.unpack_from("<if", payload, base)
    assert pid == 7
    assert abs(conf - 0.83) < 1e-5

    # Reparse translation and compare
    trans = np.frombuffer(payload, dtype="<f4", count=3, offset=base + 8)
    np.testing.assert_allclose(trans, p.translation, rtol=0, atol=0)

    # Reparse vertices and compare
    verts = np.frombuffer(
        payload, dtype="<f4", count=10475 * 3, offset=base + 8 + 12 + 40 + 40
    ).reshape(10475, 3)
    np.testing.assert_allclose(verts, p.vertices_3d, rtol=0, atol=0)


def test_serialize_person_round_trip_handles_non_contiguous_input():
    """Vertex arrays that come from slicing / transpose must still serialize cleanly."""
    p = _make_person()
    # Force a Fortran-order copy, which is NOT C-contiguous:
    p.vertices_3d = np.asfortranarray(p.vertices_3d)
    assert not p.vertices_3d.flags["C_CONTIGUOUS"], "test setup invariant"

    payload = SMPLXTCPSender._serialize_persons([p])
    # Same byte layout as the contiguous case:
    base = 8  # MAGIC + n_persons
    per_person_offset = base + 4 + 4 + 12 + 40 + 40  # pid + conf + trans + betas + expr
    verts = np.frombuffer(
        payload, dtype="<f4", count=10475 * 3, offset=per_person_offset
    ).reshape(10475, 3)
    # The wire bytes must match the LOGICAL vertex data, not the storage order:
    np.testing.assert_allclose(verts, p.vertices_3d, rtol=0, atol=0)
