# Hantek 6022BL helper tools

Standalone Python scripts that handle the parts of the Hantek 6022BL USB
oscilloscope workflow that don't belong in the C++ visualizer
(`oscope-of/src/HantekDevice`).

| Script | Role |
|---|---|
| `fx2_fwload.py` | One-shot firmware uploader. The Hantek arrives as a bare Cypress FX2LP and needs `fx2lafw-hantek-6022bl.fw` pushed via vendor request 0xA0. After upload the device renumerates with VID:PID 1d50:608e. Uses libusb via ctypes (no `pyusb` dep). |
| `hantek_to_osc.py` | Alternative scope reader using `sigrok-cli` (instead of the C++ libusb path in oscope-of). Streams CH1/CH2 chunks as float32 over OSC to `127.0.0.1:57120 /scope`. |
| `hantek_osc_bridge.py` | Variant of the above. Same end goal, different parsing strategy. |

## Prerequisites (macOS)

1. **PulseView.app** (ships libusb + the firmware blob)
   ```sh
   brew install --cask pulseview
   ```
2. **sigrok-cli** (only needed for the Python scope readers)
   ```sh
   brew install sigrok-cli
   ```
3. **python-osc** (only needed for the Python scope readers)
   ```sh
   /usr/bin/python3 -m pip install --user python-osc
   ```

## Workflow

### Once per session : load the firmware
```sh
./fx2_fwload.py
```
This must run before either oscope-of's C++ driver or sigrok-cli can talk to
the scope.

### Then either :
- **C++ path (default)** — start `oscope-of` (or the launcher) and the C++
  `HantekDevice` will open the scope directly via libusb.
- **Python path (fallback / debugging)** — start `./hantek_to_osc.py` and
  open `sound_algo/control/hantek_receiver.scd` in sclang to receive
  `~hPk1 / ~hRms1 / ~hPk2 / ~hRms2` updated at 50 Hz.

The two paths are mutually exclusive — only one process can hold the USB
device at a time.
