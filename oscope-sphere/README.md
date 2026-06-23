# oscope-sphere

A minimal openFrameworks visualiser: it captures both channels of a
Hantek 6022 oscilloscope and renders them as a single 3D sphere.

The sphere is split at the equator — **northern hemisphere = CH1,
southern hemisphere = CH2** — across three composable layers:

- **Layer A** — the sphere itself: its skin is a scrolling spectrogram
  (latitude = log frequency, longitude = time) and its geometry is
  displaced radially by the live waveform.
- **Layer B** — two waveform rings orbiting the sphere in perpendicular
  planes, one per channel.
- **Layer C** — the sphere rendered as a point cloud.

It reuses the capture and analysis layer of the sibling `oscope-of`
project.

## Build and run

```bash
cd oscope-sphere
make && make Run
```

Requires openFrameworks (GL 3.2 core) and libusb-1.0. Without a scope
connected the app runs in demo mode on a synthetic signal.

## Controls

| Key | Action |
|-----|--------|
| `1` / `2` / `3` | toggle layers A / B / C |
| `c` | cycle colormap (magma / viridis) |
| `space` | freeze the spectrogram scroll |
| mouse drag | orbit the camera |

## Tests

```bash
./tests/run_tests.sh
```

Runs the pure-C++ unit tests (FFT, per-channel split, spectrogram
buffer, demo signal) — no openFrameworks needed.

## Hardware note

24/48 MS/s are single-channel-only on the OpenHantek6022 firmware;
because both channels are used, capture runs at 16 MS/s. Only one
process may own the scope at a time — close OpenHantek6022 before
running this app.

## License

GPL-3.0, as part of the AV-Live monorepo.
