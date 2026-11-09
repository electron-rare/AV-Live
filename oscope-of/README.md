# oscope-of

openFrameworks visualizer for the [`sound_algo`](https://github.com/electron-rare/sound_algo) live-coding system, paired with a Hantek 6022BL USB oscilloscope.

Three stacked modes:

1. **Lissajous XY** — CH1=X, CH2=Y, CRT-phosphor persistence (green `#00FF7F`), Gaussian glow shader
2. **FFT spectrogram** — 1024 bins, horizontal scrolling, blue→violet→red palette
3. **sound_algo reactive layer** — hexagonal grid, HSV gradient, modulated by BPM/beat/`amp.*` received over OSC

## Requirements

- macOS Apple Silicon (M1/M2/M3/M5) — the tested target; Intel Macs work too after adjusting `config.make`
- [openFrameworks 0.12+](https://openframeworks.cc/download/) with the Xcode template
- Xcode Command Line Tools: `xcode-select --install`
- libusb-1.0: `brew install libusb`
- To load the Hantek firmware: `brew install fxload`, or build it from [OpenHantek6022](https://github.com/OpenHantek/OpenHantek6022)

## Installation

### Step 1 — Locate the project in AV-Live

The source is included in the AV-Live checkout. From the repository root:

```bash
cd oscope-of
```

Set `OF_ROOT` to the absolute path of your openFrameworks installation:

```bash
OF_ROOT="/absolute/path/to/openFrameworks"
```

### Step 2 — Regenerate the Xcode project

```bash
"$OF_ROOT/projectGenerator" -u "$PWD"
```

This creates `oscope-of.xcodeproj/` from `addons.make` and `config.make`.

### Step 3 — Load the Hantek firmware

The 6022BL is a Cypress FX2 with no persistent firmware: the OpenHantek6022 firmware must be uploaded every time the device is plugged in.

See the full guide: [docs/HANTEK_SETUP.md](docs/HANTEK_SETUP.md).

Quick summary:

```bash
# Clone and build the OpenHantek6022 firmware once.
git clone https://github.com/OpenHantek/OpenHantek6022.git
cd OpenHantek6022/openhantek/res/firmware/
# (follow the repository's build instructions to produce the .hex files)

# Load it on every plug-in (PID 0x6022 = no firmware yet):
fxload -t fx2lp -I firmware.hex -D /dev/bus/usb/<bus>/<dev>
# or through libusb-helper on macOS — see docs/HANTEK_SETUP.md
```

Once the firmware is loaded, the device re-enumerates as `0x04B5:0x602A` and `oscope-of` can claim it.

### Step 4 — Start sound_algo and its bridge

From your `sound_algo` tree:

```supercollider
// In SuperCollider
"web_bridge.scd".loadRelative;
~startBridge.value;
```

OSC topology: `sclang` listens on `127.0.0.1:57121` (commands from `oscope-of`), `Node↔SC` uses `:57122`, and `oscope-of` listens on `127.0.0.1:57123` for the `/sync/*` messages emitted by the bridge.

### Step 5 — Build and run

Open `oscope-of.xcodeproj` in Xcode, select the `oscope-of Release` scheme, ⌘+R.

Or from the CLI:

```bash
make OF_ROOT="$OF_ROOT" Release
make OF_ROOT="$OF_ROOT" RunRelease
```

## Modes and keyboard controls

| Key | Action |
|-----|--------|
| `1` | Lissajous mode (full-screen XY) |
| `2` | Spectrogram mode (full-screen FFT) |
| `3` | Reactive mode (sound_algo layer only) |
| `4` | Hybrid mode (default, all three stacked) |
| `f` | Toggle fullscreen |
| `g` | Toggle the ofxPanel GUI |
| `r` | Reload shaders (handy for live editing) |

## Configuration

`bin/data/settings.json`:

```json
{
  "scope":   { "sample_rate": 48000000, "gain_ch1": 0.5, "gain_ch2": 0.5, "buffer_size": 4096 },
  "osc":     { "listen_port": 57123, "send_host": "127.0.0.1", "send_port": 57121 },
  "display": { "fullscreen": false, "width": 1920, "height": 1080, "default_mode": "hybrid" }
}
```

## OSC protocol

See [docs/OSC_PROTOCOL.md](docs/OSC_PROTOCOL.md) for the full list of messages received from sound_algo and sent to SC.

## Troubleshooting

### "Hantek 6022BL found BUT firmware not loaded"

The device enumerates as `0x04B5:0x6022` instead of `0x602A`. Load the firmware (see step 3) and restart.

### "claim_interface failed: LIBUSB_ERROR_ACCESS"

macOS blocks direct USB access by default. Go to **System Settings → Privacy & Security → Input Monitoring** and allow the `oscope-of` binary. As a test only, you can run it as root: `sudo bin/oscope-of_debug`.

### No signal in Lissajous mode

- Check that the probes are connected to CH1 and CH2 and that DC/AC coupling suits your source
- Check the V/div values in the GUI (`CH1 V/div`, `CH2 V/div` sliders)
- The "Scope" status in the GUI must read "OK" with a sample count > 0

### Conflict with OpenHantek itself

If OpenHantek6022 is running at the same time, it claims the device and `oscope-of` cannot open it. Quit OpenHantek first.

### No OSC messages

Check in the GUI that the listen port is `57123` and that the `sound_algo` bridge has started (`~startBridge.value` in SC). Test with `oscchief` or `OSCdef.trace`.

## Architecture

```
src/
  main.cpp                       OF entry point, 1920x1080 window, MSAA 8x
  ofApp.h/.cpp                   Orchestrator, mode dispatch
  HantekDevice.h/.cpp            libusb wrapper, bulk-transfer thread
  OscClient.h/.cpp               ofxOsc receiver/sender for sound_algo
  ScopeData.h                    Lock-free SPSC ring buffer
  FFT.h/.cpp                     In-place radix-2 Cooley-Tukey
  visualizers/
    Visualizer.h                 Abstract interface
    LissajousVis.h/.cpp          XY scope with FBO trail
    SpectrogramVis.h/.cpp        Scrolling FFT
    ReactiveVis.h/.cpp           sound_algo layer (bg.frag shader)
bin/data/
  settings.json
  shaders/
    glow.vert/frag               9-tap Gaussian + threshold
    bloom.vert/frag               Single-pass bloom (reserved for later)
    bg.frag                       sound_algo reactive layer
docs/
  HANTEK_SETUP.md                Firmware guide + macOS USB permissions
  OSC_PROTOCOL.md                Reference of the OSC messages exchanged
```

## License

MIT — see the sound_algo project for the SuperCollider-side license.
