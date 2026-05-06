// =====================================================================
//  synth/lead/fm_bell.scd  --  SynthDef \fmBell
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fmBell, {
        arg freq = 220, gate = 1,
            modRatio = 1.41, modIndex = 3,
            cutoff = 400,                  // cutoff de base (bas pour dubstep)
            wobbleRate = 4,                // Hz (4 = 1/8 a 120 BPM)
            wobbleDepth = 1800,            // amplitude du wobble en Hz
            wobbleShape = 0,               // 0 = LFTri (smooth), 1 = LFPulse (chop)
            rq = 0.25,                     // resonance forte (audible)
            subAmt = 0.45,                 // niveau du sub-bass octave -1
            detune = 0.006,                // detune entre 2 voix L/R
            attack = 0.005, decay = 0.3, sustain = 0.4, release = 0.4,
            drive = 3.5,                   // saturation lourde
            amp = 0.18, pan = 0,
            scBus = 0, scAmt = 0.4;
        var carL, carR, mod, wobble, sig, sub, env, duck, lfo;
        // LFO wobble (mix tri / pulse selon shape)
        lfo = SelectX.kr(wobbleShape, [
            LFTri.kr(wobbleRate),
            LFPulse.kr(wobbleRate, 0, 0.5, 2, -1)
        ]);
        wobble = (cutoff + (lfo.range(0, 1) * wobbleDepth)).clip(80, 12000);
        // FM avec carrieres detunees L/R
        mod = SinOsc.ar(freq * modRatio) * freq * modIndex * 0.5;
        carL = SinOsc.ar(freq * (1 - detune) + mod);
        carR = SinOsc.ar(freq * (1 + detune) + mod);
        // Sub-bass : octave -1 + octave -2 + harmonique 3 (epaisseur)
        // sub massif typique dubstep : sub fonda + sub-sub + harmonique
        sub = (SinOsc.ar(freq * 0.5) * 0.7) +
              (SinOsc.ar(freq * 0.25) * 0.5) +
              (SinOsc.ar(freq * 0.5, pi * 0.5) * 0.2);   // legere phase shift
        sub = sub * subAmt * 1.3;                        // boost interne
        sub = sub.tanh;                                  // soft clip pour rester contenu
        sig = [carL + sub, carR + sub];
        // RLPF resonant module par le wobble
        sig = RLPF.ar(sig, wobble, rq);
        // Saturation lourde (le coeur du son dubstep)
        sig = (sig * drive).tanh / drive.sqrt;
        // Compression "tape" pour faire rentrer le sub
        sig = (sig * 1.4).tanh;
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release),
                        gate, doneAction: 2);
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        sig = Balance2.ar(sig[0], sig[1], pan);
        Out.ar(0, sig * env * amp * duck);
    }).add;
)
