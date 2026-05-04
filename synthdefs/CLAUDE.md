# synthdefs/ — Instruments additionnels

Palettes exotiques : `asia.scd` (koto, erhu, gong, growl),
`extra.scd`, `authentic.scd`. Charges automatiquement par
`00_load.scd` apres `engine.scd`.

## Convention SynthDef

```supercollider
SynthDef(\nomInstrument, {
    arg freq = 220, gate = 1,
        attack = 0.001, decay = 0.04, sustain = 0.5, release = 0.6,
        amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;        // sidechain
    var sig, env, duck;
    sig = ...;                          // synthese
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release),
                    gate, doneAction: 2);   // OBLIGATOIRE si gate
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
```

## Regles

- `doneAction: 2` obligatoire si l'instrument utilise `gate`
  (sinon Synth zombie)
- Toujours `Pan2.ar(sig, pan)` pour stereo (pas `[sig, sig]`)
- `scBus`/`scAmt` exposes pour sidechain (kick -> instruments)
- `LeakDC.ar` apres feedback comb / waveshaping
- `clip(min, max)` sur freq/cutoff pour eviter blow-up
- Drive : `(sig * drive).tanh / drive.sqrt` (preserve le gain)

## Acces

Les nouveaux instruments deviennent disponibles via
`~melodyInst = \koto`, `~kickInst = ...`, etc. Ils doivent suivre
les memes args (freq, gate, amp) que les SynthDef du `engine.scd`
pour etre interchangeables dans les Pdef.

## Anti-patterns

- Ne pas oublier `doneAction: 2` -> Synths qui s'accumulent en RAM
- Ne pas utiliser `Out.ar` direct sans Pan -> mono qui casse le mixer
- Ne pas laisser un `freq` non-clip -> NaN/Inf au synthe
- Ne pas dupliquer un SynthDef existant dans `engine.scd`
- Ne pas ajouter d'arg sans valeur par defaut (Pdef plante)
