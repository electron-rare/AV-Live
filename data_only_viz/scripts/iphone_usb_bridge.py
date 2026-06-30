#!/usr/bin/env python3
"""iPhone ARBodyTracker USB skeleton -> OSC /body3d/kp bridge.

The ARBodyTracker iOS app serves its ARKit 91-joint skeleton over the
device's TCP :7000 in the AVLiveWire framing (it does NOT publish OSC).
AVLiveBody (Swift) consumes that over usbmuxd; data_only_viz instead
listens for OSC /body3d/kp on UDP :57128 and fuses it via the `arkit_fuse`
POSE_FILTER stage. This script is the missing link: it tunnels to the
device's :7000 through usbmuxd, demuxes the AVLiveWire stream, decodes the
skeleton frames, and republishes each valid joint as OSC.

Run it on the Mac the iPhone is plugged into, alongside:
    POSE_FILTER=median+kalman+lookahead+ik+arkit_fuse \
        python -m data_only_viz.main --pose

Wire formats (reverse-engineered from shared/AVLiveWire + avlivebody-mac):
- usbmux packet: 16-byte LE header (length=16+body, version=1, message=8,
  tag) + XML plist. ListDevices -> DeviceList[].DeviceID; Connect with
  PortNumber byte-swapped to big-endian, Number==0 means success.
- AVLiveWire frame header (19 B, big-endian): magic "AVL1", tag u8
  (skeleton=1), pid i16, timestamp f64, length u32.
- SkeletonPayload (1183 B): 91 joints * (x,y,z) big-endian f32 interleaved,
  then 91 validity bytes.
"""
from __future__ import annotations

import logging
import plistlib
import socket
import struct
import sys
import time

from pythonosc.udp_client import SimpleUDPClient

USBMUXD_PATH = "/var/run/usbmuxd"
DEVICE_PORT = 7000
OSC_HOST = "127.0.0.1"
OSC_PORT = 57128

MAGIC = b"AVL1"
HEADER_LEN = 19
TAG_SKELETON = 1
JOINT_COUNT = 91
SKEL_FLOAT_BYTES = JOINT_COUNT * 3 * 4          # 1092
SKEL_BYTES = SKEL_FLOAT_BYTES + JOINT_COUNT     # 1183
TAG_SKELETON2D = 6                               # wire: skeleton2D (face=5 taken)
SKEL2D_FLOAT_BYTES = JOINT_COUNT * 2 * 4        # 728
SKEL2D_BYTES = SKEL2D_FLOAT_BYTES + JOINT_COUNT # 819
MAX_PAYLOAD = 8 * 1024 * 1024

LOG = logging.getLogger("iphone_usb_bridge")


# --------------------------------------------------------------------------
# usbmux client
# --------------------------------------------------------------------------
def _recv_exact(sock: socket.socket, n: int) -> bytes | None:
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return bytes(buf)


def _usbmux_send(sock: socket.socket, plist: dict, tag: int) -> None:
    body = plistlib.dumps(plist, fmt=plistlib.FMT_XML)
    sock.sendall(struct.pack("<IIII", 16 + len(body), 1, 8, tag) + body)


def _usbmux_recv(sock: socket.socket) -> dict | None:
    head = _recv_exact(sock, 4)
    if head is None:
        return None
    (length,) = struct.unpack("<I", head)
    if length < 16:
        return None
    rest = _recv_exact(sock, length - 4)
    if rest is None:
        return None
    packet = head + rest                 # full `length` bytes
    return plistlib.loads(packet[16:])   # plist body after 16-byte header


def connect_device() -> socket.socket | None:
    """usbmux ListDevices + Connect to the first device's :7000.

    On success returns a socket whose stream is the tunneled device bytes.
    """
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(USBMUXD_PATH)
    except OSError as e:
        LOG.warning("no usbmuxd (%s)", e)
        return None
    try:
        _usbmux_send(sock, {"MessageType": "ListDevices"}, 1)
        reply = _usbmux_recv(sock)
        devices = [d.get("DeviceID") for d in (reply or {}).get("DeviceList", [])]
        devices = [d for d in devices if isinstance(d, int)]
        if not devices:
            LOG.warning("no iOS device attached")
            sock.close()
            return None
        device_id = devices[0]
        swapped = ((DEVICE_PORT << 8) | (DEVICE_PORT >> 8)) & 0xFFFF
        _usbmux_send(
            sock,
            {"MessageType": "Connect", "DeviceID": device_id,
             "PortNumber": swapped},
            2,
        )
        reply = _usbmux_recv(sock)
        if not reply or reply.get("Number") != 0:
            LOG.warning("Connect to :%d refused (%s)", DEVICE_PORT, reply)
            sock.close()
            return None
        LOG.info("connected to device %d port %d", device_id, DEVICE_PORT)
        return sock
    except OSError as e:
        LOG.warning("usbmux handshake failed: %s", e)
        sock.close()
        return None


# --------------------------------------------------------------------------
# AVLiveWire stream demux + skeleton decode
# --------------------------------------------------------------------------
def iter_frames(sock: socket.socket):
    """Yield (tag, pid, payload) for each complete AVLiveWire frame."""
    buf = bytearray()
    while True:
        chunk = sock.recv(65536)
        if not chunk:
            return
        buf += chunk
        while True:
            idx = buf.find(MAGIC)
            if idx < 0:
                if len(buf) > 3:          # keep a partial trailing magic
                    del buf[:-3]
                break
            if idx > 0:
                del buf[:idx]
            if len(buf) < HEADER_LEN:
                break
            tag = buf[4]
            (length,) = struct.unpack(">I", buf[15:19])
            if length > MAX_PAYLOAD:      # corrupt header, skip the magic
                del buf[:len(MAGIC)]
                continue
            total = HEADER_LEN + length
            if len(buf) < total:
                break
            (pid,) = struct.unpack(">h", buf[5:7])
            payload = bytes(buf[HEADER_LEN:total])
            del buf[:total]
            yield tag, pid, payload


def decode_skeleton(payload: bytes):
    """Return [(x, y, z, valid), ...] of length 91, or None if malformed."""
    if len(payload) != SKEL_BYTES:
        return None
    floats = struct.unpack(">" + "f" * (JOINT_COUNT * 3), payload[:SKEL_FLOAT_BYTES])
    valid = payload[SKEL_FLOAT_BYTES:]
    return [
        (floats[i * 3], floats[i * 3 + 1], floats[i * 3 + 2], valid[i] != 0)
        for i in range(JOINT_COUNT)
    ]


def decode_skeleton2D(payload: bytes):
    """Return [(x, y, valid), ...] of length 91 (normalized 0..1), or None.

    Wire layout: 91 × (x f32 BE, y f32 BE) = 728 bytes, then 91 validity bytes.
    Total: SKEL2D_BYTES = 819.
    """
    if len(payload) != SKEL2D_BYTES:
        return None
    floats = struct.unpack(">" + "f" * (JOINT_COUNT * 2), payload[:SKEL2D_FLOAT_BYTES])
    valid = payload[SKEL2D_FLOAT_BYTES:]
    return [(floats[i * 2], floats[i * 2 + 1], valid[i] != 0) for i in range(JOINT_COUNT)]


# --------------------------------------------------------------------------
# main loop
# --------------------------------------------------------------------------
def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s — %(message)s",
    )
    osc = SimpleUDPClient(OSC_HOST, OSC_PORT)
    LOG.info("iphone_usb_bridge: usbmuxd :%d -> OSC %s:%d",
             DEVICE_PORT, OSC_HOST, OSC_PORT)
    frames = 0
    last_log = time.monotonic()
    while True:
        sock = connect_device()
        if sock is None:
            time.sleep(1.0)
            continue
        try:
            for tag, pid, payload in iter_frames(sock):
                if tag != TAG_SKELETON:
                    continue
                joints = decode_skeleton(payload)
                if joints is None:
                    continue
                n = 0
                for i, (x, y, z, v) in enumerate(joints):
                    if v:
                        osc.send_message("/body3d/kp", [pid, i, x, y, z])
                        n += 1
                osc.send_message("/body3d/count", [1 if n else 0])
                frames += 1
                now = time.monotonic()
                if now - last_log > 3.0:
                    LOG.info("forwarding skeleton frames (last: pid=%d, %d/%d valid joints)",
                             pid, n, JOINT_COUNT)
                    last_log = now
        except (OSError, struct.error) as e:
            LOG.warning("stream error: %s — reconnecting", e)
        finally:
            try:
                sock.close()
            except OSError:
                pass
        time.sleep(1.0)


if __name__ == "__main__":
    sys.exit(main())
