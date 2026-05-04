// =====================================================================
//  authentic.scd  --  Instruments authentiques par genre (deep recherche)
//
//  Couvre : kick gabber overdrive 909, reese DnB FM, supersaw trance,
//  Rhodes Detroit, hooverbass, vocal chop, taiko, tabla, didgeridoo,
//  guzheng (harpe chinoise), DX7 epiano, pad Juno-106, Linn-style snare,
//  cowbell Memphis 808, sub 808 trap, vocal pad
//
//  USAGE : Cmd+Entree apres engine.scd. Tous compatibles ~melodyInst.
// =====================================================================

(

// ----- Kick gabber (909 overdriven cliped, occupe le spectre) -----
SynthDef(\kickGabber, {
    arg freq = 50, decay = 0.32, drive = 6.0, click = 0.4,
        amp = 0.55, pan = 0,
        scBus = 0, scShape = 0.18;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * 4, freq], [0.04], -3));
    body = SinOsc.ar(pEnv) + (Saw.ar(pEnv) * 0.3);
    sub = SinOsc.ar(freq * 0.5);
    clickSig = HPF.ar(WhiteNoise.ar, 4000) *
               EnvGen.kr(Env.perc(0.0005, 0.005));
    sig = body + (sub * 0.4) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.001, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).clip(-1, 1);                   // hard clip gabber
    sig = (sig * 1.4).tanh;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ----- Reese bass DnB (FM brutal + mod chaos) ---------------------
SynthDef(\reeseDnB, {
    arg freq = 55, gate = 1, detune = 0.018,
        cutoff = 800, rq = 0.2,
        modRate1 = 0.25, modDepth1 = 600,
        modRate2 = 0.7, modDepth2 = 250,
        attack = 0.005, decay = 0.1, sustain = 0.7, release = 0.2,
        drive = 4.0, amp = 0.30, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, fc, sub;
    fc = (cutoff + (SinOsc.kr(modRate1) * modDepth1)
                + (SinOsc.kr(modRate2) * modDepth2)).clip(80, 8000);
    sig = (Saw.ar(freq * (1 - detune)) * 0.4) +
          (Saw.ar(freq * (1 + detune)) * 0.4) +
          (Saw.ar(freq * (1 + (detune * 2.7))) * 0.3);
    sub = SinOsc.ar(freq * 0.5) * 0.5;
    sig = BPF.ar(sig, fc, rq) * 4 + sub;
    sig = LPF.ar(sig, 4500);
    sig = (sig * drive).tanh / drive.sqrt;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig) * env * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ----- Supersaw Trance (12 voix detunees + chorus + LP) ---------
SynthDef(\supersaw, {
    arg freq = 220, gate = 1, detune = 0.018, mix = 0.5,
        cutoff = 4500, rq = 0.5,
        attack = 0.005, decay = 0.15, sustain = 0.6, release = 0.4,
        drive = 1.2, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, voices, center, sides;
    // 7 voix detunees (style JP-8000 supersaw)
    voices = (-3..3).collect { |i|
        Saw.ar(freq * (1 + (i * detune)))
    };
    center = voices[3];
    sides = voices.removeAt(3);
    sig = (center * (1 - mix)) + (Mix(voices) * mix * 0.18);
    sig = LPF.ar(sig, cutoff);
    // Chorus stereo
    sig = [DelayC.ar(sig, 0.03, SinOsc.kr(0.4, 0).range(0.005, 0.018)),
           DelayC.ar(sig, 0.03, SinOsc.kr(0.5, pi).range(0.005, 0.018))];
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = Balance2.ar(sig[0], sig[1], pan);
    Out.ar(0, sig * env * amp * duck);
}).add;

// ----- Rhodes Detroit (DX7 e-piano simulation) -------------------
SynthDef(\rhodes, {
    arg freq = 440, gate = 1,
        modRatio = 14, modIndex = 0.4,        // Rhodes : 14:1 ratio
        cutoff = 4000, rq = 0.6,
        attack = 0.002, decay = 0.2, sustain = 0.0, release = 0.8,
        drive = 1.1, amp = 0.20, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, mod, idxEnv, chorus;
    idxEnv = EnvGen.kr(Env([modIndex * 2, 0], [0.4], -3));
    mod = SinOsc.ar(freq * modRatio) * freq * idxEnv;
    sig = SinOsc.ar(freq + (mod * 0.5));
    sig = LPF.ar(sig, cutoff);
    chorus = DelayC.ar(sig, 0.02, SinOsc.kr(0.7).range(0.002, 0.012));
    sig = sig + (chorus * 0.4);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release, curve: -4),
                    gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Hooverbass Gabber/Trance (Roland Alpha Juno PWM detuned) -
SynthDef(\hooverbass, {
    arg freq = 110, gate = 1, detune = 0.012,
        cutoff = 3500, rq = 0.4,
        attack = 0.001, decay = 0.1, sustain = 0.7, release = 0.2,
        drive = 1.6, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, voices, pwm;
    pwm = LFTri.kr(0.3).range(0.3, 0.7);
    voices = [
        Saw.ar(freq * (1 - detune)) * 0.4,
        Saw.ar(freq * (1 + detune)) * 0.4,
        Pulse.ar(freq * 0.5, pwm) * 0.3,        // sub octave
        Pulse.ar(freq * 2 * (1 + (detune * 1.5)), pwm) * 0.2  // octave aigu
    ];
    sig = Mix(voices);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig) * env * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ----- Vocal pad (formants vocaux + chorus + reverb-like) -------
SynthDef(\vocalPad, {
    arg freq = 220, gate = 1,
        // Formants pour voyelle "ah" : 700/1220/2600
        f1 = 700, f2 = 1220, f3 = 2600,
        attack = 0.4, decay = 0.3, sustain = 0.7, release = 1.5,
        drive = 1.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, src, vib;
    vib = freq * (1 + (SinOsc.kr(4.5).range(-1, 1) *
        EnvGen.kr(Env([0, 0, 0.012], [0.3, 0.5]))));
    src = (Saw.ar(vib) * 0.5) + (SinOsc.ar(vib * 0.5) * 0.4);
    sig = (BPF.ar(src, f1, 0.12) * 1.0) +
          (BPF.ar(src, f2, 0.18) * 0.6) +
          (BPF.ar(src, f3, 0.30) * 0.3);
    // Faux chorus stereo
    sig = [DelayC.ar(sig, 0.04, SinOsc.kr(0.5, 0).range(0.008, 0.025)),
           DelayC.ar(sig, 0.04, SinOsc.kr(0.55, pi).range(0.008, 0.025))];
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = Balance2.ar(sig[0], sig[1], pan);
    Out.ar(0, sig * env * amp * duck);
}).add;

// ----- Taiko (Japanese big drum -- thick body + skin attack) ----
SynthDef(\taiko, {
    arg freq = 70, decay = 0.6, drive = 1.4, amp = 0.5, pan = 0;
    var pEnv, body, skin, env, sig;
    pEnv = EnvGen.kr(Env([freq * 1.5, freq], [0.04], -3));
    body = SinOsc.ar(pEnv) + (Saw.ar(pEnv) * 0.15);
    skin = HPF.ar(WhiteNoise.ar, 800) *
           EnvGen.kr(Env.perc(0.001, 0.04));
    sig = body + (skin * 0.4);
    env = EnvGen.kr(Env.perc(0.003, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ----- Tabla (Indian drum -- pitched + slap) -------------------
SynthDef(\tabla, {
    arg freq = 220, decay = 0.18, drive = 1.3, amp = 0.4, pan = 0;
    var pEnv, body, slap, env, sig;
    pEnv = EnvGen.kr(Env([freq * 3, freq], [0.02], -4));
    body = SinOsc.ar(pEnv) + (SinOsc.ar(pEnv * 1.5) * 0.2);
    slap = HPF.ar(WhiteNoise.ar, 2500) *
           EnvGen.kr(Env.perc(0.001, 0.012));
    sig = body + (slap * 0.5);
    env = EnvGen.kr(Env.perc(0.002, decay, curve: -4), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ----- Didgeridoo (drone aborigene avec growl harmonique) ------
SynthDef(\didgeridoo, {
    arg freq = 60, gate = 1,
        growlRate = 4, growlDepth = 0.15,
        attack = 0.5, decay = 0.3, sustain = 0.85, release = 1.0,
        drive = 1.5, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, growl, harmonics;
    growl = SinOsc.kr(growlRate * (1 + LFNoise2.kr(0.5).range(-0.15, 0.15)))
            .range(1 - growlDepth, 1 + growlDepth);
    harmonics = (Saw.ar(freq * growl) * 0.4) +
                (Pulse.ar(freq * 2 * growl, 0.3) * 0.2) +
                (Pulse.ar(freq * 3 * growl, 0.4) * 0.15) +
                (SinOsc.ar(freq * 0.5) * 0.5);
    sig = LPF.ar(harmonics, 1200);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig) * env * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ----- Guzheng (harpe chinoise -- corde + decay long + bend) ---
SynthDef(\guzheng, {
    arg freq = 220, gate = 1,
        bendAmt = 0.025, bendTime = 0.3,
        cutoff = 5500, rq = 0.4,
        attack = 0.001, decay = 0.05, sustain = 0.0, release = 1.5,
        drive = 1.1, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, exciter, ks, harm, bentFreq;
    // Bend caracteristique guzheng (slide vers la note finale)
    bentFreq = freq * (1 + EnvGen.kr(Env([bendAmt, 0], [bendTime], -2)));
    exciter = WhiteNoise.ar(0.6) * EnvGen.kr(Env.perc(0.0005, 0.003));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, bentFreq.reciprocal, 4.0));
    // Harmonique octave + 5te (caractere chinois)
    harm = LeakDC.ar(CombC.ar(exciter * 0.25, 0.05, (bentFreq * 1.5).reciprocal, 2.0));
    sig = LPF.ar(ks + harm, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Shakuhachi (flute japonaise avec breath + bend) ---------
SynthDef(\shakuhachi, {
    arg freq = 440, gate = 1,
        breathAmt = 0.25, vibratoRate = 4.5, vibratoDepth = 0.018,
        cutoff = 3000, rq = 0.5,
        attack = 0.12, decay = 0.1, sustain = 0.7, release = 0.4,
        drive = 1.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, vibFreq, breath, body, bendEnv;
    bendEnv = EnvGen.kr(Env([0.97, 1.0], [0.08], -2));   // attack bend (style shakuhachi)
    vibFreq = freq * bendEnv * (1 + (SinOsc.kr(vibratoRate,
        EnvGen.kr(Env([0, 0, 1], [0.3, 0.4])) * pi) * vibratoDepth));
    body = SinOsc.ar(vibFreq) +
           (SinOsc.ar(vibFreq * 2) * 0.18) +
           (SinOsc.ar(vibFreq * 3) * 0.06);
    breath = HPF.ar(WhiteNoise.ar, 2000) * breathAmt *
             EnvGen.kr(Env([0.4, 1, 0.5], [0.05, 0.5]));
    sig = body + breath;
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Kick 808 trap (sub long avec pitch slide) ---------------
SynthDef(\kick808, {
    arg freq = 50, glide = 0.04, decay = 0.7,
        drive = 1.4, amp = 0.6, pan = 0,
        scBus = 0, scShape = 0.18;
    var pEnv, body, click, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * 5, freq], [0.025], \exp));
    body = SinOsc.ar(pEnv);
    click = HPF.ar(WhiteNoise.ar, 1500) *
            EnvGen.kr(Env.perc(0.0005, 0.003));
    ampEnv = EnvGen.kr(Env.perc(0.003, decay, curve: -3), doneAction: 2);
    sig = body + (click * 0.15);
    sig = (sig * drive).tanh;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ----- Snare gated reverb 80s (LinnDrum + Lexicon 224) ----------
SynthDef(\snareGated, {
    arg freq = 200, decay = 0.2, gateTime = 0.15,
        amp = 0.5, pan = 0;
    var tone, noise, env, gate, sig;
    tone = SinOsc.ar(freq) * EnvGen.kr(Env.perc(0.001, 0.04));
    noise = HPF.ar(WhiteNoise.ar, 1200) *
            EnvGen.kr(Env.perc(0.001, decay));
    sig = (tone * 0.4) + (noise * 0.6);
    // Gated reverb : signal + reverb tronque par envelope gate
    sig = sig + (CombC.ar(sig, 0.05, 0.04, 0.3) *
                 EnvGen.kr(Env([0, 1, 1, 0], [0.001, gateTime, 0.005])));
    env = EnvGen.kr(Env.linen(0.001, gateTime, 0.005), doneAction: 2);
    sig = (sig * 1.4).tanh;
    sig = LeakDC.ar(sig) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ----- Vinyl scratch / glitch FX ------------------------------
SynthDef(\scratch, {
    arg dur = 0.5, freq = 800, sweepDir = 1, amp = 0.3, pan = 0;
    var sig, env, sweepFreq;
    sweepFreq = Select.kr(sweepDir > 0, [
        Line.kr(freq * 2, freq * 0.5, dur),
        Line.kr(freq * 0.5, freq * 2, dur)
    ]);
    sig = (SinOsc.ar(sweepFreq) * 0.5) +
          (HPF.ar(WhiteNoise.ar, sweepFreq * 0.8) * 0.3);
    sig = sig * LFPulse.kr(20).range(0.3, 1);   // stutter
    env = EnvGen.kr(Env.linen(0.005, dur, 0.02), doneAction: 2);
    Out.ar(0, Pan2.ar(sig * env * amp, pan));
}).add;

"=== authentic.scd : 14 nouveaux SynthDef ===".postln;
"  drums    : \\kickGabber  \\kick808  \\snareGated  \\taiko  \\tabla".postln;
"  basses   : \\reeseDnB  \\hooverbass".postln;
"  leads    : \\supersaw  \\rhodes".postln;
"  pads/voc : \\vocalPad".postln;
"  world    : \\didgeridoo  \\guzheng  \\shakuhachi".postln;
"  fx       : \\scratch".postln;
)
