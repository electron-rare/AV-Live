# OSC Registry — sound_algo

Catalog of all OSC addresses handled (or emitted) by the SuperCollider engine.
Generated from grep of `OSCdef(` and `openUDPPort` in `sound_algo/**/*.scd`.

---

## Ports

| Port | Direction | Variable | Role |
|------|-----------|----------|------|
| **57120** | IN | (sclang default langPort) | Default SC language port. All `OSCdef` without an explicit `recvPort` listen here. Includes all `/pose/*`, `/data/*`, `/launch/*`, `/seq/*`, `/ctl/*`, `/scope`, `/control/fp` handlers. |
| **57121** | IN | `~webBridgeIn` | Web bridge listen port. Node.js server sends `/control/*` commands here. Opened with `thisProcess.openUDPPort(57121)` in `data_only/boot.scd` and implicitly via `web_bridge.scd`. |
| **57122** | OUT | `~webBridgeNode` | Node.js web server receive port. SC sends broadcast messages (steps, beat, RMS, amp) here. |
| **57123** | OUT | `~webBridgeRelays[0]` | oscope-of (openFrameworks) relay — SC forwards web bridge outbound messages here. |
| **1234** | OUT | `~vdmxAddr` (default) | VDMX receive port. SC sends `/av/*` analysis + clock messages here. Override with env `VDMX_OSC_PORT`. |
| **9000** | OUT | `~toscPort` | TouchOSC client port. `touchosc_feedback.scd` sends `/armed/*`, `/sync/rms`, `/sync/beat` to discovered client IPs at this port. |

---

## Registration patterns

Three patterns are used across the codebase; all result in idempotent behavior:

1. **`~feedDefPriv` (free-then-add)** — `control/data_feeds.scd` and `control/web_bridge.scd`
   define a helper that calls `OSCdef(key).free; OSCdef(key, fn, path)` before each
   registration. Re-loading always replaces existing responders.

2. **`~pd[\defs].add(OSCdef(...))` list** — `pd/bridge.scd` stores all OSCdefs in a list
   (`~pd[\defs]`). Calling `~pd[\stop].()` frees the whole list. Re-loading rebuilds it.

3. **Plain keyed `OSCdef(\key, ...)` (elsewhere)** — `OSCdef` in SC is keyed by symbol;
   re-evaluating the same key silently replaces the existing responder. Used in
   `data_only/launchpad.scd`, `data_only/scenes.scd`, `data_only/scene_concert.scd`,
   `control/vdmx_send.scd`, `control/finger_piano.scd`, `data_only/touchosc_feedback.scd`
   (capture sniffers). `OSCFunc` (not keyed) is only used in `touchosc_feedback.scd` for
   the RMS probe; it is guarded with `~toscRmsResp !? { ~toscRmsResp.free }` before
   re-creation.

---

## /control/* — engine control (LIVE + data-only)

Received on port **57121** via `~webBridgeAdd` (web_bridge.scd).
Also some paths from `data_only/launchpad.scd` and `data_only/engine.scd`
listen on the default port 57120.

### web_bridge.scd (port 57121, via `~webBridgeAdd`)

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/control/bpm` | web_bridge.scd:175 | Set BPM (`~setTempo`) |
| `/control/masterVol` | web_bridge.scd:182 | Set master volume |
| `/control/masterFadeOut` | web_bridge.scd:186 | Fade out master |
| `/control/teardown` | web_bridge.scd:190 | Stop everything (`~teardown`) |
| `/control/rebootServer` | web_bridge.scd:195 | Reboot scsynth |
| `/control/rebootWeb` | web_bridge.scd:207 | Restart Node.js web server |
| `/control/rebootSclang` | web_bridge.scd:241 | Quit and restart sclang |
| `/control/triggerSynth` | web_bridge.scd:217 | Trigger a one-shot Synth |
| `/control/snareFill` | web_bridge.scd:226 | Trigger snare fill |
| `/control/tomFill` | web_bridge.scd:230 | Trigger tom fill |
| `/control/randomTweak` | web_bridge.scd:234 | Apply random parameter tweak |
| `/control/setVol` | web_bridge.scd:254 | Set per-channel volume |
| `/control/mute` | web_bridge.scd:258 | Mute a channel |
| `/control/unmute` | web_bridge.scd:259 | Unmute a channel |
| `/control/solo` | web_bridge.scd:260 | Solo a channel |
| `/control/unsolo` | web_bridge.scd:261 | Clear solo |
| `/control/kk` | web_bridge.scd:264 | Set kick genre (`~kk`) |
| `/control/pKit` | web_bridge.scd:265 | Set percussion kit |
| `/control/pGenre` | web_bridge.scd:266 | Set pattern genre |
| `/control/ff` | web_bridge.scd:267 | Apply FX preset (`~ff`) |
| `/control/<chainName>` | web_bridge.scd:273 | Dynamic chain dispatch for live `~cc` chains |
| `/control/acidNotes` | web_bridge.scd:283 | Set acid bass note pattern |
| `/control/acidAccents` | web_bridge.scd:288 | Set acid accent pattern |
| `/control/acidSlides` | web_bridge.scd:293 | Set acid slide pattern |
| `/control/acidCutoff` | web_bridge.scd:298 | Set acid filter cutoff |
| `/control/acidRq` | web_bridge.scd:299 | Set acid filter resonance |
| `/control/acidDrive` | web_bridge.scd:300 | Set acid drive |
| `/control/acidAmp` | web_bridge.scd:301 | Set acid amplitude |
| `/control/acidRandom` | web_bridge.scd:302 | Randomize acid pattern |
| `/control/harmonyNotes` | web_bridge.scd:313 | Set harmony note array |
| `/control/harmonyAmp` | web_bridge.scd:318 | Set harmony amplitude |
| `/control/harmonyPreset` | web_bridge.scd:319 | Apply harmony preset |
| `/control/fxCut` | web_bridge.scd:326 | Set FX filter cutoff per channel |
| `/control/fxDrive` | web_bridge.scd:327 | Set FX drive per channel |
| `/control/fxRq` | web_bridge.scd:328 | Set FX resonance per channel |
| `/control/lfoTo` | web_bridge.scd:331 | Route LFO to a parameter |
| `/control/lfoStop` | web_bridge.scd:334 | Stop LFO on a parameter |
| `/control/lfoStopAll` | web_bridge.scd:335 | Stop all LFOs |
| `/control/drop` | web_bridge.scd:338 | Trigger drop |
| `/control/breakdown` | web_bridge.scd:339 | Trigger breakdown |
| `/control/buildup` | web_bridge.scd:340 | Trigger buildup |
| `/control/glitch` | web_bridge.scd:341 | Trigger glitch |
| `/control/stutter` | web_bridge.scd:342 | Trigger stutter |
| `/control/freeze` | web_bridge.scd:343 | Freeze audio |
| `/control/tapeStop` | web_bridge.scd:344 | Tape-stop effect |
| `/control/tapeReverse` | web_bridge.scd:345 | Tape-reverse effect |
| `/control/handsUp` | web_bridge.scd:346 | Hands-up filter sweep |
| `/control/jumpCut` | web_bridge.scd:347 | Jump-cut transition |
| `/control/bitCrushNow` | web_bridge.scd:348 | Apply bit crush |
| `/control/jumpTo` | web_bridge.scd:353 | Jump to a section (`~jumpTo`) |
| `/control/listSections` | web_bridge.scd:360 | Broadcast section list to web |
| `/control/listAlbums` | web_bridge.scd:375 | Broadcast album list |
| `/control/getSteps` | web_bridge.scd:394 | Broadcast current step state |
| `/control/playTrack` | web_bridge.scd:396 | Load and play a track file |
| `/control/playAlbum` | web_bridge.scd:403 | Play an album (playlist) |
| `/control/stopAlbum` | web_bridge.scd:410 | Stop album playback |
| `/control/setHumanize` | web_bridge.scd:418 | Set humanization level |
| `/control/setRotation` | web_bridge.scd:424 | Set pattern rotation |
| `/control/setLayer` | web_bridge.scd:429 | Set active layer |
| `/control/humanizeTiming` | web_bridge.scd:435 | Set timing humanization |
| `/control/humanizeVelocity` | web_bridge.scd:439 | Set velocity humanization |
| `/control/humanizeDetune` | web_bridge.scd:443 | Set detune humanization |
| `/control/layerSet` | web_bridge.scd:448 | Set layer configuration |
| `/control/chain` | web_bridge.scd:464 | Execute a chain transition |
| `/control/playPdef` | web_bridge.scd:481 | Start a named Pdef |
| `/control/stopPdef` | web_bridge.scd:484 | Stop a named Pdef |
| `/control/playAll` | web_bridge.scd:487 | Start all Pdefs |
| `/control/stopAll` | web_bridge.scd:493 | Stop all Pdefs |
| `/control/mApply` | web_bridge.scd:499 | Apply melody macro |
| `/control/mInst` | web_bridge.scd:504 | Set melody instrument |
| `/control/mAmp` | web_bridge.scd:505 | Set melody amplitude |
| `/control/mCut` | web_bridge.scd:506 | Set melody filter cutoff |
| `/control/mDrive` | web_bridge.scd:507 | Set melody drive |
| `/control/mOff` | web_bridge.scd:508 | Stop melody |
| `/control/mGen` | web_bridge.scd:509 | Generate melody variation |
| `/control/mNx` | web_bridge.scd:510 | Next melody |
| `/control/mPv` | web_bridge.scd:511 | Previous melody |
| `/control/sendFx` | web_bridge.scd:514 | Set send FX level |
| `/control/vcfOn` | web_bridge.scd:532 | Enable VCF filter |
| `/control/vcfOff` | web_bridge.scd:535 | Disable VCF filter |
| `/control/vcfFreq` | web_bridge.scd:536 | Set VCF frequency |
| `/control/vcfQ` | web_bridge.scd:537 | Set VCF Q |
| `/control/vcfSweep` | web_bridge.scd:538 | Trigger VCF sweep |
| `/control/vcfPreset` | web_bridge.scd:541 | Apply VCF preset |
| `/control/fxComp` | web_bridge.scd:544 | Set compressor parameters |
| `/control/fxSat` | web_bridge.scd:548 | Set saturation |
| `/control/saveScene` | web_bridge.scd:555 | Save current scene state |
| `/control/loadScene` | web_bridge.scd:559 | Load a saved scene |
| `/control/tap` | web_bridge.scd:565 | Tap tempo |
| `/control/ping` | web_bridge.scd:571 | Ping (returns pong) |
| `/control/listSynthdefs` | web_bridge.scd:578 | Broadcast SynthDef list |
| `/control/listMelodies` | web_bridge.scd:591 | Broadcast melody list |
| `/control/setMelody` | web_bridge.scd:604 | Set active melody by name |
| `/control/fp` | control/finger_piano.scd:154 | Finger-piano control (on/off/scale/inst/sens/octave/velsrc/mode...) |

### data_only mode (port 57120, plain OSCdef)

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/control/doScene` | data_only/scenes.scd:344 | Select data-only scene by name (data-only mode) |
| `/control/doMaster` | data_only/engine.scd:87 | Set master gain 0..2 (data-only engine) |
| `/control/dataScene` | live/data_only_program.scd:200 | Select data scene via hybrid mode |
| `/control/concertNext` | data_only/scene_concert.scd:189 | Advance to next concert track |
| `/control/concertSeq` | data_only/scene_concert.scd:192 | Toggle sequential vs random track order |
| `/control/harmony/root` | data_only/launchpad.scd:346 | Set harmony root note (data-only) |
| `/control/harmony/scale` | data_only/launchpad.scd:349 | Set harmony scale (data-only) |
| `/control/harmony/octave` | data_only/launchpad.scd:353 | Set harmony octave (data-only) |
| `/control/harmony/phrase` | data_only/launchpad.scd:354 | Set harmony phrase slot (data-only) |
| `/control/fx/filter` | data_only/launchpad.scd:355 | Apply resonant filter sweep (data-only) |
| `/control/fx/stutter` | data_only/launchpad.scd:358 | Trigger stutter (data-only) |
| `/control/fx/crash` | data_only/launchpad.scd:359 | Fire crash event (data-only) |
| `/control/fx/kick` | data_only/launchpad.scd:360 | Fire kick accent (data-only) |
| `/control/fx/swell` | data_only/launchpad.scd:361 | Fire swell effect (data-only) |
| `/control/fx/breakdown` | data_only/launchpad.scd:362 | Toggle breakdown filter (data-only) |

---

## /data/* — real-world data feeds

Received on port **57120** (default langPort) via `~feedDefPriv` (control/data_feeds.scd).
All definitions use the free-then-add pattern; safe to reload.

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/data/usgs/event` | data_feeds.scd:49 | Earthquake event (mag, lon, lat, depth, age_sec) |
| `/data/usgs/rate` | data_feeds.scd:56 | Earthquake rate (events/hour) |
| `/data/swpc/wind` | data_feeds.scd:64 | Solar wind (speed, density, temp) |
| `/data/swpc/bz` | data_feeds.scd:69 | Solar wind Bz component |
| `/data/swpc/kp` | data_feeds.scd:73 | Geomagnetic Kp index |
| `/data/swpc/xray` | data_feeds.scd:77 | Solar X-ray flux |
| `/data/netzfrequenz/freq` | data_feeds.scd:87 | European grid frequency (Hz) |
| `/data/netzfrequenz/dev` | data_feeds.scd:90 | Grid frequency deviation |
| `/data/netzfrequenz/time_dev` | data_feeds.scd:93 | Grid time deviation |
| `/data/rte_eco2mix/mix` | data_feeds.scd:100 | French electricity mix (RTE) |
| `/data/blitzortung/strike` | data_feeds.scd:116 | Lightning strike event |
| `/data/blitzortung/rate` | data_feeds.scd:120 | Lightning rate (strikes/min) |
| `/data/opensky/count` | data_feeds.scd:127 | Aircraft count over France |
| `/data/opensky/plane` | data_feeds.scd:130 | Individual aircraft event |
| `/data/bluesky/post` | data_feeds.scd:138 | Social post event (Bluesky) |
| `/data/bluesky/rate` | data_feeds.scd:142 | Bluesky post rate |
| `/data/mempool/tx` | data_feeds.scd:149 | Bitcoin mempool transaction |
| `/data/mempool/block` | data_feeds.scd:153 | Bitcoin block event |
| `/data/github/event` | data_feeds.scd:162 | GitHub public event |
| `/data/gcn/alert` | data_feeds.scd:170 | GCN gamma-ray burst alert |
| `/data/pose/count` | data_feeds.scd:192 | Person count from data bridge |
| `/data/pose/person` | data_feeds.scd:195 | Per-person pose summary |
| `/data/pose/skel` | data_feeds.scd:201 | Skeleton keypoints (data bridge) |
| `/data/pose/bone` | data_feeds.scd:223 | Bone vector (data bridge) |
| `/data/velib/total` | data_feeds.scd:271 | Velib bike total (Paris) |
| `/data/velib/flow` | data_feeds.scd:276 | Velib dock/undock flow |
| `/data/velib/density` | data_feeds.scd:279 | Velib station density |
| `/data/velib/hotspot` | data_feeds.scd:282 | Velib hotspot station |
| `/data/sytadin/flow` | data_feeds.scd:289 | Traffic flow (Sytadin) |
| `/data/sytadin/speed` | data_feeds.scd:293 | Traffic speed |
| `/data/sytadin/occupancy` | data_feeds.scd:297 | Road occupancy |
| `/data/sytadin/jam` | data_feeds.scd:301 | Traffic jam event |
| `/data/rivers/level` | data_feeds.scd:308 | River level (Seine/Marne) |
| `/data/rivers/avg` | data_feeds.scd:314 | River average level |
| `/data/rivers/alert` | data_feeds.scd:318 | River flood alert |
| `/data/idfm/disruption_n` | data_feeds.scd:326 | IDFM disruption count |
| `/data/idfm/disruption` | data_feeds.scd:329 | IDFM disruption event |
| `/data/ais/ship` | data_feeds.scd:339 | AIS vessel event |
| `/data/ais/cargo` | data_feeds.scd:343 | AIS cargo ship event |
| `/data/ais/count` | data_feeds.scd:346 | AIS vessel count |
| `/data/ais/rate` | data_feeds.scd:349 | AIS message rate |
| `/data/gbfs/sum/bikes_fr` | data_feeds.scd:356 | GBFS total bikes (France) |
| `/data/gbfs/sum/bikes_be` | data_feeds.scd:359 | GBFS total bikes (Belgium) |
| `/data/gbfs/sum/cities` | data_feeds.scd:362 | GBFS city count |
| `/data/eco2mix/mix` | data_feeds.scd:382 | Electricity mix (eco2mix) |
| `/data/eco2mix/co2` | data_feeds.scd:386 | CO2 intensity (gCO2/kWh) |
| `/data/eco2mix/load` | data_feeds.scd:389 | Electricity load |
| `/data/eco2mix/renew` | data_feeds.scd:392 | Renewable share |
| `/data/radioactivity/avg` | data_feeds.scd:399 | Radioactivity average |
| `/data/radioactivity/max` | data_feeds.scd:402 | Radioactivity maximum |
| `/data/radioactivity/min` | data_feeds.scd:405 | Radioactivity minimum |
| `/data/radioactivity/n` | data_feeds.scd:408 | Radioactivity station count |
| `/data/radioactivity/anomaly` | data_feeds.scd:411 | Radioactivity anomaly |
| `/data/fuel/avg` | data_feeds.scd:419 | Fuel price average |
| `/data/fuel/cheapest` | data_feeds.scd:423 | Cheapest fuel station |
| `/data/fuel/spread` | data_feeds.scd:427 | Fuel price spread |
| `/data/fuel/n` | data_feeds.scd:430 | Fuel station count |
| `/data/heartbeat` | data_feeds.scd:437 | Python feed watchdog heartbeat |

---

## /pose/* — live pose bridge (data_only_viz -> SC)

Received on port **57120** (default langPort).
Two overlapping sub-namespaces:
- `/pose/<key>` direct (data_feeds.scd lines 237–257): forwarded from `data_only_viz` via
  `~feedDefPriv`, stores into `~poseCount`, `~poseCenter`, `~poseWrist`, `~poseSkel`.
- `/pose/<key>` direct OSCdef (data_feeds.scd lines 470–547): raw pose responders writing
  into per-pid dictionaries (`~poseKin`, `~poseCenter`, `~poseSkel`, etc.).

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/pose/count` | data_feeds.scd:237 / :492 | Person count (two registrations via feedDefPriv + direct) |
| `/pose/center` | data_feeds.scd:240 / :536 | Person center position |
| `/pose/head` | data_feeds.scd:243 | Head position |
| `/pose/wrist` | data_feeds.scd:247 / :518 | Wrist positions (lx/ly/rx/ry) |
| `/pose/sho_span` | data_feeds.scd:254 / :542 | Shoulder span |
| `/pose/limb_span` | data_feeds.scd:257 | Limb span |
| `/pose/action` | data_feeds.scd:470 | High-level pose action (e.g. arms-crossed) |
| `/pose/kin` | data_feeds.scd:478 | Kinetic state (speed, energy) |
| `/pose/enter` | data_feeds.scd:487 | Person entered scene |
| `/pose/leave` | data_feeds.scd:493 | Person left scene |
| `/pose/hands` | data_feeds.scd:502 | Hand features (openness, speed, dist) |
| `/pose/skel` | data_feeds.scd:527 | Full skeleton keypoints |
| `/pose/finger` | control/finger_piano.scd:81 | Finger tip positions (finger piano) |
| `/pose/pinch` | control/finger_piano.scd:127 | Pinch gesture (finger piano trigger) |

---

## /seq/* — sequencer control (data-only mode)

Received on port **57120** (default langPort) via plain `OSCdef` in `data_only/launchpad.scd`.

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/seq/melody` | data_only/launchpad.scd:366 | Select melody preset by index |
| `/seq/rhythm` | data_only/launchpad.scd:372 | Select rhythm preset by index |
| `/seq/rhythm/set` | data_only/launchpad.scd:379 | Write kick/snare/hat pattern to current rhythm slot |
| `/seq/melody/set` | data_only/launchpad.scd:392 | Write degree array to current melody slot |

TouchOSC echo (state feedback sent by `touchosc_feedback.scd`):
- `/seq/rhythm/state` — echoed back to TouchOSC surface when `/seq/rhythm` received
- `/seq/melody/state` — echoed back to TouchOSC surface when `/seq/melody` received

---

## /launch/* — launchpad pad control (data-only mode)

Received on port **57120** (default langPort). Also sniffed by `touchosc_feedback.scd`
to discover the TouchOSC client IP.

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/launch` | data_only/launchpad.scd:330 | Arm/disarm a pad (name, 0/1) |
| `/launch/tempo` | data_only/launchpad.scd:333 | Set BPM (60–200) |
| `/launch/clear` | data_only/launchpad.scd:336 | Disarm all pads |
| `/launch/vol` | data_only/launchpad.scd:339 | Set pad volume (name, float 0..1.5) |
| `/launch/quant` | data_only/launchpad.scd:342 | Set launch quantize (beats, 0.125..64) |

---

## /av/* — SC to VDMX (OUTBOUND)

SC sends these messages to VDMX at `VDMX_OSC_HOST:VDMX_OSC_PORT` (default 127.0.0.1:1234).
Handled by `control/vdmx_send.scd`. Full contract: `vdmx_visual/docs/osc-namespace.md`.

| Address | Sent from | Purpose |
|---------|-----------|---------|
| `/av/amp` | vdmx_send.scd:56 | Master RMS amplitude |
| `/av/peak` | vdmx_send.scd:57 | Peak amplitude |
| `/av/band` | vdmx_send.scd:58 | Spectral bands (sub, low, mid, high) |
| `/av/centroid` | vdmx_send.scd:59 | Spectral centroid |
| `/av/flat` | vdmx_send.scd:60 | Spectral flatness |
| `/av/onset` | vdmx_send.scd:64 | Onset pulse (value 1) |
| `/av/phase` | vdmx_send.scd:77 | Bar phase (0..1, 60 Hz) |
| `/av/beat` | vdmx_send.scd:80 | Whole-beat counter |
| `/av/bar` | vdmx_send.scd:82 | Bar counter |
| `/av/bpm` | vdmx_send.scd:84 | Current BPM (float) |
| `/av/note` | vdmx_send.scd:98 | MIDI note event (note, vel, dur) |
| `/av/scene` | vdmx_send.scd:101 | Scene index change |

---

## /tweak/* — PureData bridge tweaks (LIVE mode)

Received on port **57120** (default langPort) via `~pd[\defs].add(OSCdef(...))` in `pd/bridge.scd`.
Freed atomically by `~pd[\stop].()`.

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/tweak/melodyCutoff` | pd/bridge.scd:100 | Set melody filter cutoff |
| `/tweak/acidCutoff` | pd/bridge.scd:101 | Set acid filter cutoff |
| `/tweak/bpm` | pd/bridge.scd:102 | Set BPM |
| `/tweak/melodyRq` | pd/bridge.scd:103 | Set melody filter resonance |
| `/tweak/acidRq` | pd/bridge.scd:104 | Set acid filter resonance |
| `/tweak/melodyDrive` | pd/bridge.scd:105 | Set melody drive |

---

## /vol/* — PureData bridge volumes (LIVE mode)

Received on port **57120** (default langPort) via `~pd[\defs]` in `pd/bridge.scd`.

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/vol/kick` | pd/bridge.scd:89 | Set kick volume |
| `/vol/hat` | pd/bridge.scd:90 | Set hat volume |
| `/vol/snare` | pd/bridge.scd:91 | Set snare volume |
| `/vol/clap` | pd/bridge.scd:92 | Set clap volume |
| `/vol/perc` | pd/bridge.scd:93 | Set perc volume |
| `/vol/acid` | pd/bridge.scd:94 | Set acid volume |
| `/vol/melody` | pd/bridge.scd:95 | Set melody volume |
| `/vol/harmony` | pd/bridge.scd:96 | Set harmony volume |
| `/vol/master` | pd/bridge.scd:97 | Set master volume |

---

## /ctl/* — VDMX to SC (inbound, port 57120)

Handled by `control/vdmx_send.scd` when VDMX bridge is active. Registered via plain keyed
`OSCdef`; freed by `~vdmxStop.()`.

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/ctl/bpm` | vdmx_send.scd:93 | Set tempo from VDMX |
| `/ctl/scene` | vdmx_send.scd:94 | Change scene from VDMX |

---

## PureData bridge — other paths (LIVE mode)

`pd/bridge.scd` via `~pd[\defs].add(OSCdef(...))`.

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/play` | pd/bridge.scd:50 | Start playback |
| `/stop` | pd/bridge.scd:58 | Stop playback |
| `/choke` | pd/bridge.scd:64 | Choke (cut) all voices |
| `/drop` | pd/bridge.scd:72 | Trigger drop transition |
| `/breakdown` | pd/bridge.scd:73 | Trigger breakdown |
| `/buildup` | pd/bridge.scd:74 | Trigger buildup |
| `/freeze` | pd/bridge.scd:75 | Freeze audio |
| `/glitch` | pd/bridge.scd:76 | Trigger glitch |
| `/stutter` | pd/bridge.scd:77 | Trigger stutter |
| `/tapeStop` | pd/bridge.scd:78 | Tape-stop effect |
| `/handsUp` | pd/bridge.scd:79 | Hands-up filter sweep |
| `/jumpCut` | pd/bridge.scd:80 | Jump-cut |
| `/tapeReverse` | pd/bridge.scd:81 | Tape reverse |
| `/fx/preset` | pd/bridge.scd:108 | Apply FX preset |
| `/fx/send` | pd/bridge.scd:113 | Set send FX level |
| `/fx/freeze` | pd/bridge.scd:117 | Freeze send FX |
| `/fx/setMix` | pd/bridge.scd:122 | Set FX mix |
| `/vcf/on` | pd/bridge.scd:132 | Enable VCF |
| `/vcf/off` | pd/bridge.scd:136 | Disable VCF |
| `/vcf/setFreq` | pd/bridge.scd:137 | Set VCF frequency |
| `/vcf/setQ` | pd/bridge.scd:138 | Set VCF Q |
| `/lfo/to` | pd/bridge.scd:141 | Route LFO |
| `/lfo/stop` | pd/bridge.scd:146 | Stop LFO |
| `/scene/save` | pd/bridge.scd:151 | Save scene |
| `/scene/load` | pd/bridge.scd:155 | Load scene |
| `/jump` | pd/bridge.scd:159 | Jump to section |
| `/melody` | pd/bridge.scd:163 | Set melody pattern |
| `/melody/genre` | pd/bridge.scd:167 | Set melody genre |
| `/mix/preset` | pd/bridge.scd:171 | Apply mixer preset |

---

## Other / internal

| Address | File:line | Purpose |
|---------|-----------|---------|
| `/scope` | control/hantek_receiver.scd:11 | Hantek 6022BL oscilloscope data (from openFrameworks) |
| `/hydra` | control/hydra_send.scd:22 | Internal: SendReply -> forward to Hydra SC bridge (RMS, centroid, flatness at 30 Hz) |
| `/sync/beat` | web_bridge.scd / touchosc_feedback.scd | Beat pulse broadcast (SC -> web / TouchOSC) |
| `/sync/rms` | touchosc_feedback.scd:125 | Master RMS broadcast (SC -> TouchOSC, 20 Hz) |
| `/sync/amp` | web_bridge.scd:643 | Per-channel amplitude params (SC -> web, 10 Hz) |
| `/armed/<name>` | touchosc_feedback.scd | Pad clip state (0=off/1=playing/2=queued-launch/3=queued-stop, SC -> TouchOSC) |
