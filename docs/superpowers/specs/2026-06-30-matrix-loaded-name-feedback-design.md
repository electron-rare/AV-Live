# Matrix — autofill the name field on load (so SAUVER updates the loaded matrix)

**Date**: 2026-06-30
**Status**: design approved, pending plan
**Scope**: `sound_algo/data_only/matrix.scd` (engine feedback) + `web_realart/public/control/js/main.js` (handler). Follow-on to the save-persist + queued-load feature.

## Context

After loading a matrix (CHARGER or CHARGER SUIVANT), the `#matrix-name` input
stays whatever the user last typed, so clicking SAUVER saves under the wrong/empty
name instead of updating the matrix they just loaded. The user wants the name
field to track the **actually-loaded** matrix so SAUVER updates it in place.

## Design (approved)

- **Engine**: emit `/matrix/loaded <name>` at the *actual* load moment — NOT from
  the shared `~matLoad`/`~matLoadFile` (that would spam during the boot autoload).
  Emit from the three user-facing load points:
  1. the `/matrix/load` OSCdef (immediate CHARGER),
  2. the queued branch of `~matWrapStep` (the queued load firing at the wrap),
  3. the not-playing immediate fallback in the `/matrix/loadnext` OSCdef.
- **Web** (`main.js`): `on("/matrix/loaded", args)` sets
  `document.getElementById("matrix-name").value = String(args[0])`.

## Timing note

For CHARGER SUIVANT the name fills **when the swap happens** (at the wrap, via
`~matWrapStep`), not when armed — so SAUVER never saves the current grid under a
not-yet-loaded preset's name.

## Testing

- SC: no new unit (the emit is a one-liner on existing paths); covered by the
  live smoke. Existing `test_matnames.scd` + `validate_presets.scd` must still PASS.
- Web: `node --check main.js` + the existing `node --test test/*.test.mjs` suite
  unchanged (29 pass).
- Live smoke: CHARGER a preset → `#matrix-name` shows its name; arm SUIVANT →
  name updates only when it swaps at the wrap; SAUVER then overwrites that name.

## Out of scope

- Emitting `/matrix/loaded` from the boot autoload or TouchOSC-specific paths.
- Any change to SAUVER itself (it already saves under `#matrix-name`).
