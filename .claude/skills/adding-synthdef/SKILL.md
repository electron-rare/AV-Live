---
name: adding-synthdef
description: Use when the user asks to "add a SynthDef", "create a new instrument", "ajouter un instrument", or names a synthesis technique to package (FM, granular, Karplus-Strong, formant, etc.). Generates a SynthDef in `synthdefs/asia.scd`, `synthdefs/extra.scd`, or `synthdefs/authentic.scd` following the rigid 32-SynthDef convention of sound_algo: standard arg signature (freq/gate/ADSR/amp/pan/scBus/scAmt), `EnvGen.kr(..., doneAction: 2)`, `Pan2.ar` final, `LeakDC.ar` after feedback, `clip` on freq, `tanh` saturation pattern. Forgetting `doneAction: 2` creates Synth zombies that accumulate in RAM until the server crashes.
---

# Adding a SynthDef

## Where to put it

| File | Theme |
| --- | --- |
| `synthdefs/asia.scd` | World/exotic timbres (koto, erhu, gong, growl) |
| `synthdefs/extra.scd` | Misc additions |
| `synthdefs/authentic.scd` | Vintage/authentic emulations |
| `engine.scd` | DO NOT add here -- it's the core, kept stable |

## Standard arg signature

Every SynthDef MUST accept these args (with defaults) :

```supercollider
arg freq = 220, gate = 1, cutoff = 6000, rq = 0.5,
    attack = 0.001, decay = 0.04, sustain = 0.0, release = 0.6,
    drive = 1.2, amp = 0.22, pan = 0,
    scBus = 0, scAmt = 0.4;
```

This way the SynthDef is a drop-in replacement in `~melodyInst`, `~kickInst`, etc.

## Template

```supercollider
SynthDef(\<instName>, {
    arg freq = 220, gate = 1, cutoff = 6000, rq = 0.5,
        attack = 0.001, decay = 0.04, sustain = 0.0, release = 0.6,
        drive = 1.2, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck;

    // --- 1. Synthesis core (oscillator / noise / sample / ...) -------
    sig = ...;

    // --- 2. Filter (LPF/RLPF/HPF/...) --------------------------------
    sig = LPF.ar(sig, freq.clip(40, 18000));

    // --- 3. Drive / saturation (preserve gain) -----------------------
    sig = (sig * drive).tanh / drive.sqrt;

    // --- 4. Leak DC if any feedback / waveshaping --------------------
    sig = LeakDC.ar(sig);

    // --- 5. Envelope with doneAction:2 (free node when env ends) ----
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release),
                    gate, doneAction: 2);

    // --- 6. Sidechain duck (kick -> instrument) ---------------------
    duck = 1 - (In.kr(scBus, 1) * scAmt);

    // --- 7. Output : Pan2 stereo ------------------------------------
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
```

## Mandatory invariants

| Rule | Reason |
| --- | --- |
| `doneAction: 2` on EnvGen.kr | Without it, Synth zombies pile up forever |
| `Pan2.ar(sig, pan)` | Mono `[sig, sig]` breaks the mixer's stereo bus |
| `freq.clip(min, max)` | Unclamped freq -> NaN/Inf at filter |
| `(sig * drive).tanh / drive.sqrt` | Preserves perceived loudness across drive |
| `LeakDC.ar` after feedback | Comb/Karplus need it or DC offset accumulates |
| `In.kr(scBus, 1) * scAmt` | Standard sidechain bus pattern |
| Defaults on EVERY arg | Pdef breaks if any arg is missing |

## Synthesis recipes

```supercollider
// Karplus-Strong (plucked string)
exciter = WhiteNoise.ar(0.6) * EnvGen.kr(Env.perc(0.0005, 0.003));
sig = LeakDC.ar(CombC.ar(exciter, 0.05, freq.reciprocal, 3.0));

// FM bell
mod = SinOsc.ar(freq * 1.4) * 200 * EnvGen.kr(Env.perc(0.001, 0.5));
sig = SinOsc.ar(freq + mod);

// Granular pad
sig = GrainSin.ar(2, Impulse.kr(20), 0.1, freq, pan);

// Formant vowel
sig = Formant.ar(freq, formantFreq, bw);
```

## After creation

1. Run `validating-scd-files` on the synthdefs file (P:0 B:0, TLB:1).
2. Test SynthDef compilation : `tests/e2e_04_synthdef_compile.scd` should
   still pass.
3. Add the new symbol to the README's instrument list if user-facing.

## Anti-patterns

- **No `doneAction: 2`** -> Synth zombies, RAM leak, eventual crash.
- **`Out.ar(0, sig)`** -> mono, breaks panning + stereo mixer.
- **Hardcoded `0.5` for amp** -> not user-controllable.
- **Missing default value for an arg** -> Pdef crashes when scheduling.
- **Duplicating an existing SynthDef name** -> silently overwrites.
- **`SinOsc.ar(freq)` without clip** -> NaN if freq <= 0 from a modulator.
