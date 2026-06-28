# Matrix instrument selection — design

Date: 2026-06-28
Status: approved (brainstorming), pending implementation plan
Scope: `sound_algo/data_only/matrix.scd` + `web_realart/public/control/`
Companion spec: capture→effect per-voice modulation (the right-side menu) is a
separate spec — see `2026-06-28-matrix-capture-effect-design.md`. This spec is
the left-side instrument menu only.

## Goal

Let the performer change the timbre of each matrix voice by choosing, per voice,
an alternative SynthDef from a curated menu, and switch all voices at once with a
fixed named kit. The arrangement grid (cells/colors/playhead/glow) is unchanged;
only which synth each voice plays changes. Also: right-clicking a grid cell
resets it to off (a quick grid-editing convenience folded in here).

## Decisions (from brainstorming)

- Per-voice instrument swap, **curated** menus (only musically-compatible
  alternatives per voice), to avoid broken arg-mismatch combos.
- **Fixed** named kits defined here (Default / Deep / Industrial / Acid); one tap
  reassigns all voices, then per-voice menus still override. No user-saved kits in v1.
- Right-click a cell → reset that cell to color 0 (web-only).
- SC is the source of truth for instrument state and kits; the web is a surface.

## Available SynthDefs (data-only boot)

14 `lp_*` (launchpad.scd) + 10 `do_*` (synthdefs.scd) load in `data_only/boot.scd`.
Pitched voices compute `\freq` from harmony via Pfunc on `\degree`; swapping only
the `\instrument` key keeps that pattern, so compatible targets sound right and
incompatible ones sound odd but never crash. The curated menus below keep swaps
within compatible families.

## Architecture & data flow

```
Web <select> per voice ──/matrix/instrument <vi:i> <instSym:s>──┐
Web kit buttons       ──/matrix/kit <name:s>───────────────────┤
                                                                ▼
                                              matrix.scd OSCdefs
  /matrix/instrument → ~matInstruments[vi] = inst (or nil); force re-source bar
  /matrix/kit        → apply kit map to all 16 ~matInstruments;
                       echo /matrix/instrument vi inst ×16 (web <select> sync)
                                                                ▼
  ~matApplyBar → ~matVariation injects \instrument override into the overlay
                 Pbind of Pchain(overlay, base); nil → no override (base synth)
                                                                ▼
  /matrix/instrument feedback relayed (server.js "/matrix/" prefix) → web sync
```

Right-click-clear path (web-only, reuses existing OSC):
```
contextmenu on .mcell → preventDefault → matGrid[vi][bar]=0; saveMatState();
applyMatCellColor(cell,0); send("/matrix/cell", vi, bar, 0)
```

## Components

### SC (`sound_algo/data_only/matrix.scd`)

- `~matInstruments` — `Array.fill(~matVoices.size, nil)` (nil = voice default),
  nil-guarded/idempotent like the other matrix state.
- `~matInstChoices` — IdentityDictionary voice-name → array of valid SynthDef
  symbols (the curated table below). Used by SC only to validate incoming
  `/matrix/instrument` (reject a symbol not in the voice's choice list → ignore).
- `~matKits` — IdentityDictionary kit-name → (voice-name → SynthDef) map (only the
  voices that differ from default need an entry; others fall back to nil/default).
- `~matApplyInstrument.(vi, instOrNil)` — set `~matInstruments[vi]`, then force a
  re-source of that voice on the current bar (bypass the `~matLastColor` skip so
  the new synth takes effect at the next quant boundary), and echo
  `/matrix/instrument vi instString` via `~toscSend`.
- `~matApplyKit.(name)` — look up `~matKits[name]`; for each of the 16 voices set
  `~matInstruments[vi]` to the kit's symbol or nil; re-source playing voices; echo
  one `/matrix/instrument` per voice so the web reflects the kit.
- `~matVariation.(name, color, vi)` — extended to read `~matInstruments[vi]`; when
  non-nil, add `\instrument, inst` to the overlay Pbind (it is applied last in the
  Pchain, overriding the base's instrument). When nil, no `\instrument` key is
  added (base synth used). This is the same overlay the glow `\matGlow` key lives in.
- Two OSCdefs: `\mat_inst` on `/matrix/instrument` (args: vi:i, inst:s — empty
  string or `"default"` → nil) and `\mat_kit` on `/matrix/kit` (arg: name:s).

### Bridge (`web_realart/server.js`)

- No change. `/matrix/instrument` and `/matrix/kit` match the existing `/matrix/`
  feedback prefix and are relayed in both directions.

### Web (`web_realart/public/control/`)

- `index.html`: a kit selector (a small row of buttons: Default/Deep/Industrial/Acid)
  in the matrix transport area.
- `control.js`:
  - `MATRIX_INST_CHOICES` — JS mirror of the curated table (voice → option list)
    used to build a `<select>` per voice row in `renderMatrix` (in/next to the
    voice label cell). On `change`, `send("/matrix/instrument", vi, value)` and
    persist.
  - Kit buttons → `send("/matrix/kit", name)`.
  - WS handler for `/matrix/instrument <vi> <inst>`: update the row `<select>` and
    the persisted state (so kit echoes and cross-client changes reflect).
  - `contextmenu` listener on each `.mcell`: `preventDefault`, reset to 0, send.
  - Pure helper `kitMessages(kitName)` → array of `{vi, inst}` is NOT needed if
    kits are applied SC-side; the web only sends `/matrix/kit name`. (SC owns the
    kit map; the web kit buttons are dumb senders.) Keep the kit map in SC only —
    single source of truth.
  - Persistence: extend the matrix localStorage to also store the per-voice
    instrument selections and the last kit, restored on load and re-sent on connect
    (mirroring how `matGrid` is handled).

## Curated instrument table (16 voices)

| vi | voice | default | curated alternatives |
|----|-------|---------|----------------------|
| 0 | kick | lp_kick | do_kick, do_quake_sub |
| 1 | hats | lp_hat | do_hat |
| 2 | clap | lp_clap | lp_rim, do_hat |
| 3 | perc | lp_perc | do_strike, lp_tom |
| 4 | sub | lp_sub | lp_reese, do_body_drone, do_quake_sub |
| 5 | acid | lp_acid | lp_pluck, do_geo |
| 6 | arp | lp_pluck | do_strike, lp_bells |
| 7 | lead | lp_pluck | do_plane, do_strike, lp_bells |
| 8 | stab | lp_pluck | do_geo, lp_acid |
| 9 | pad | lp_pad | do_body_drone, do_drone, lp_reese |
| 10 | ride | lp_ride | lp_hat, do_hat |
| 11 | rim | lp_rim | lp_clap, do_hat |
| 12 | tom | lp_tom | do_strike, do_quake_sub |
| 13 | reese | lp_reese | lp_sub, do_body_drone, do_weather |
| 14 | bells | lp_bells | do_strike, do_plane |
| 15 | sweep | lp_sweep | do_body_gran, do_drone, do_weather |

The `<select>` lists "default" first (the voice's own synth) then the alternatives.

## Fixed kits

Maps below list only voices that differ from default; all others = default (nil).

- **Default**: (empty) — every voice on its own `lp_*`.
- **Deep**: kick→do_kick, sub→do_body_drone, reese→do_body_drone, pad→do_drone, sweep→do_drone.
- **Industrial**: kick→do_quake_sub, perc→do_strike, tom→do_strike, clap→lp_rim, stab→do_geo.
- **Acid**: lead→do_plane, arp→do_strike, sub→lp_reese, bells→do_plane.

Every instrument named in a kit also appears in that voice's curated choice list
(so applying a kit can never set an invalid instrument).

## Error handling / robustness

- `/matrix/instrument` with an instrument not in that voice's `~matInstChoices`
  (or `vi` out of range) → ignored on the SC side; empty string / "default" → nil.
- `/matrix/kit` with an unknown name → ignored.
- Re-source on swap is quantized (next `~matBeatsPerBar` boundary) like color
  changes — no abrupt synth restart mid-note beyond the existing behavior.
- nil-guarded, idempotent reload (matches the rest of matrix.scd).

## Testing

- **SC** (`data_only/test/test_matrix.scd`, existing headless harness, P:0 B:0):
  - `~matInstruments` initialized to 16 nils; `~matInstChoices`/`~matKits` defined.
  - `~matApplyInstrument.(5, \lp_pluck)` sets `~matInstruments[5]` and echoes
    `/matrix/instrument` (capture via the `~toscSend` stub, assert vi + symbol).
  - An invalid instrument for a voice is rejected (state unchanged).
  - `~matApplyKit.(\deep)` sets the expected voices and leaves others nil.
  - With `~matInstruments[vi]` set, consuming a `~matVariation` stream produces an
    event whose `\instrument` equals the override (extends the existing
    stream-consumption test).
- **Web**: no DOM harness; verify `<select>` population, change→OSC, kit buttons,
  and right-click-clear manually in the browser. (Kit logic lives in SC, already
  unit-covered there, so there is no web pure-helper to extract.)
- **Manual**: boot data-only, swap a voice's instrument and hear the timbre
  change at the next bar; apply each kit and confirm all `<select>`s update via
  echo; right-click a cell and confirm it clears.

## Out of scope

- Capture→effect per-voice modulation (the right-side menu) — separate spec.
- User-saved kits, arg-remapping layers between mismatched synths, live-mode
  (`00_load.scd`) timbres, new SynthDefs.
