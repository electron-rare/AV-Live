#!/usr/bin/env python3
"""
Hantek 6022BE/BL → OSC bridge (no sigrok-cli, no pyusb).
Uses libusb bundled in PulseView.app via ctypes.

Protocole post-firmware (fx2lafw hantek-6022be):
  VR 0xE0  CH1 voltage range  (0x01=5V, 0x02=2.5V, 0x05=1V, 0x0A=500mV)
  VR 0xE1  CH2 voltage range  (idem)
  VR 0xE2  sample rate index  (0x01=100kS/s, 0x08=1MS/s, 0x10=4MS/s, 0x18=24MS/s)
  VR 0xE3  trigger / start    (envoyer 0x01)
  VR 0xE4  num channels       (0x01=CH1 only, 0x02=CH1+CH2)
  Bulk IN  endpoint 0x86      payload: échantillons 8-bit non-signés, interleaved

Usage:
  ./hantek_osc_bridge.py [--rate 1M] [--host 127.0.0.1] [--port 57120]
"""
import ctypes, ctypes.util, sys, time, argparse, struct
from pythonosc.udp_client import SimpleUDPClient

LIBUSB_PATH = "/Applications/PulseView.app/Contents/Frameworks/libusb-1.0.0.dylib"

# Hantek post-firmware IDs
CANDIDATES = [
    (0x04b5, 0x602a),  # 6022BL programmé
    (0x04b5, 0x6022),  # 6022BE programmé
    (0x1d50, 0x608e),  # sigrok generic fx2lafw
]

RATES = {"100k":0x01, "200k":0x08, "500k":0x10, "1M":0x18,
         "4M":0x20, "8M":0x28, "16M":0x30, "24M":0x31, "30M":0x32, "48M":0x33}

# libusb ctypes setup
usb = ctypes.CDLL(LIBUSB_PATH)
usb.libusb_init.argtypes = [ctypes.c_void_p]
usb.libusb_open_device_with_vid_pid.restype = ctypes.c_void_p
usb.libusb_control_transfer.argtypes = [
    ctypes.c_void_p, ctypes.c_uint8, ctypes.c_uint8,
    ctypes.c_uint16, ctypes.c_uint16,
    ctypes.c_char_p, ctypes.c_uint16, ctypes.c_uint
]
usb.libusb_control_transfer.restype = ctypes.c_int
usb.libusb_bulk_transfer.argtypes = [
    ctypes.c_void_p, ctypes.c_uint8,
    ctypes.c_char_p, ctypes.c_int,
    ctypes.POINTER(ctypes.c_int), ctypes.c_uint
]
usb.libusb_bulk_transfer.restype = ctypes.c_int

HOST_TO_DEV = 0x40

def vendor(handle, req, val_byte):
    return usb.libusb_control_transfer(
        handle, HOST_TO_DEV, req, 0, 0,
        ctypes.c_char_p(bytes([val_byte])), 1, 1000
    )

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--rate", default="1M", choices=list(RATES))
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=57120)
    p.add_argument("--addr", default="/scope")
    p.add_argument("--chunk", type=int, default=4096)  # samples per OSC packet
    args = p.parse_args()

    if usb.libusb_init(None) != 0:
        sys.exit("libusb_init failed")

    handle = None
    for vid, pid in CANDIDATES:
        h = usb.libusb_open_device_with_vid_pid(None, vid, pid)
        if h:
            handle = h
            print(f"[bridge] device {vid:04x}:{pid:04x}")
            break
    if not handle:
        sys.exit("Hantek non trouvé. Lance OpenHantek une fois pour uploader le firmware.")

    r = usb.libusb_set_configuration(handle, 1)
    print(f"[bridge] set_config={r}", flush=True)
    r = usb.libusb_claim_interface(handle, 0)
    print(f"[bridge] claim_interface={r}", flush=True)
    if r < 0:
        sys.exit("claim_interface failed (try kill OpenHantek / replug)")

    # Configure: 5V range CH1+CH2, 2 channels, sample rate, then start
    print(f"[bridge] E0={vendor(handle, 0xE0, 0x01)}", flush=True)
    print(f"[bridge] E1={vendor(handle, 0xE1, 0x01)}", flush=True)
    print(f"[bridge] E4={vendor(handle, 0xE4, 0x02)}", flush=True)
    print(f"[bridge] E2={vendor(handle, 0xE2, RATES[args.rate])}", flush=True)
    print(f"[bridge] E3={vendor(handle, 0xE3, 0x01)}", flush=True)
    print(f"[bridge] streaming @ {args.rate}S/s → osc://{args.host}:{args.port}{args.addr}", flush=True)

    osc = SimpleUDPClient(args.host, args.port)
    buf = ctypes.create_string_buffer(args.chunk * 2)  # 2 ch * 1 byte
    transferred = ctypes.c_int(0)

    try:
        while True:
            r = usb.libusb_bulk_transfer(handle, 0x86, buf, len(buf),
                                         ctypes.byref(transferred), 200)
            if r != 0 or transferred.value == 0:
                continue
            data = buf.raw[:transferred.value]
            # interleaved CH1, CH2, CH1, CH2, ...
            n = len(data) // 2
            ch1 = [(data[i*2]   - 128) / 128.0 for i in range(n)]
            ch2 = [(data[i*2+1] - 128) / 128.0 for i in range(n)]
            pk1 = max(abs(min(ch1)), abs(max(ch1)))
            pk2 = max(abs(min(ch2)), abs(max(ch2)))
            rms1 = (sum(x*x for x in ch1)/n)**0.5
            rms2 = (sum(x*x for x in ch2)/n)**0.5
            osc.send_message(args.addr, [pk1, rms1, pk2, rms2])
    except KeyboardInterrupt:
        pass
    finally:
        vendor(handle, 0xE3, 0x00)  # stop
        usb.libusb_release_interface(handle, 0)
        usb.libusb_close(handle)
        usb.libusb_exit(None)

if __name__ == "__main__":
    main()
