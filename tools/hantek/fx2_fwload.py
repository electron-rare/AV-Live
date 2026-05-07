#!/usr/bin/env python3
"""
Cypress FX2LP firmware loader using libusb1 via ctypes (no pyusb required).
Loads fx2lafw-hantek-6022bl.fw onto the Hantek 6022BL via vendor request 0xA0.
After upload, the device renumerates with VID:PID 1d50:608e.

Usage: ./fx2_fwload.py [firmware.fw]  (default: bundled in PulseView.app)
"""
import ctypes, ctypes.util, sys, time, os

LIBUSB_PATH = "/Applications/PulseView.app/Contents/Frameworks/libusb-1.0.0.dylib"
DEFAULT_FW  = "/Applications/PulseView.app/Contents/share/sigrok-firmware/fx2lafw-hantek-6022bl.fw"
VID_BOOT, PID_BOOT = 0x04b4, 0x6022   # Hantek 6022BL after re-initial unconfigured
VID_LV,   PID_LV   = 0x0925, 0x3881   # Lakeview default (unprogrammed FX2 with EEPROM)

usb = ctypes.CDLL(LIBUSB_PATH)
usb.libusb_init.argtypes = [ctypes.c_void_p]
usb.libusb_open_device_with_vid_pid.restype = ctypes.c_void_p
usb.libusb_control_transfer.argtypes = [
    ctypes.c_void_p, ctypes.c_uint8, ctypes.c_uint8,
    ctypes.c_uint16, ctypes.c_uint16,
    ctypes.c_char_p, ctypes.c_uint16, ctypes.c_uint
]
usb.libusb_control_transfer.restype = ctypes.c_int

CPUCS = 0xE600
A0 = 0xA0
HOST_TO_DEV = 0x40   # vendor, host→dev

def vendor_write(handle, addr, data):
    return usb.libusb_control_transfer(
        handle, HOST_TO_DEV, A0, addr, 0,
        ctypes.c_char_p(data), len(data), 1000
    )

def main():
    fw_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_FW
    if not os.path.isfile(fw_path):
        sys.exit(f"firmware not found: {fw_path}")

    fw = open(fw_path, "rb").read()
    print(f"[fx2load] firmware {fw_path} ({len(fw)} B)")

    if usb.libusb_init(None) != 0:
        sys.exit("libusb_init failed")

    handle = None
    for vid, pid in [(VID_LV, PID_LV), (VID_BOOT, PID_BOOT)]:
        h = usb.libusb_open_device_with_vid_pid(None, vid, pid)
        if h:
            handle = h
            print(f"[fx2load] opened {vid:04x}:{pid:04x}")
            break
    if not handle:
        sys.exit("device not found (VID:PID 0925:3881 ou 04b4:6022)")

    usb.libusb_detach_kernel_driver(handle, 0)
    if usb.libusb_claim_interface(handle, 0) != 0:
        print("[fx2load] warning: could not claim interface 0 (continuing)")

    # 1. Reset 8051
    print("[fx2load] reset CPU…")
    vendor_write(handle, CPUCS, b"\x01")
    time.sleep(0.05)

    # 2. Upload firmware in 4096-byte chunks
    chunk = 4096
    for i in range(0, len(fw), chunk):
        block = fw[i:i+chunk]
        n = vendor_write(handle, i, block)
        if n != len(block):
            sys.exit(f"upload failed at offset {i}: got {n}")
    print(f"[fx2load] uploaded {len(fw)} bytes")

    # 3. Release reset
    print("[fx2load] release CPU…")
    vendor_write(handle, CPUCS, b"\x00")
    time.sleep(0.5)

    usb.libusb_release_interface(handle, 0)
    usb.libusb_close(handle)
    usb.libusb_exit(None)
    print("[fx2load] OK — device should renumerate as 1d50:608e (sigrok) ou 04b5:6022 (hantek)")

if __name__ == "__main__":
    main()
