"""AVLiveWire topology payload codec.

Mirror of the Swift `TopologyPayload` (shared/AVLiveWire). Layout
(big-endian): u16 jointCount; per joint [u8 nameLen + utf8 name];
then per joint i16 parent (-1 = root).
"""
from __future__ import annotations

import struct


def encode_topology(names: list[str], parents: list[int]) -> bytes:
    out = bytearray()
    out += struct.pack(">H", len(names))
    for nm in names:
        b = nm.encode("utf-8")[:255]
        out.append(len(b))
        out += b
    for p in parents:
        out += struct.pack(">h", p)
    return bytes(out)


def decode_topology(payload: bytes) -> tuple[list[str], list[int]] | None:
    """Return (joint_names, parents) or None if malformed."""
    if len(payload) < 2:
        return None
    n = struct.unpack(">H", payload[:2])[0]
    o = 2
    names: list[str] = []
    for _ in range(n):
        if o >= len(payload):
            return None
        ln = payload[o]
        o += 1
        if o + ln > len(payload):
            return None
        names.append(payload[o:o + ln].decode("utf-8", "replace"))
        o += ln
    if o + n * 2 > len(payload):
        return None
    parents = list(struct.unpack(">" + "h" * n, payload[o:o + n * 2]))
    return names, parents
