// =====================================================================
//  synthdefs_extra.scd  --  Palette etendue : leads, pads, bass, world
//
//  Tous compatibles ~melodyInst (freq/gate/cutoff/attack/release/drive/
//  amp/pan/scBus/scAmt). Ajoutent du caractere a la palette de base.
//
//  USAGE : Cmd+Entree sur le bloc apres engine.scd. Puis utiliser via
//          (~melodyInst = \squareLead; ~reload.value;)
// =====================================================================

(

// ----- Square Lead (chiptune / 8-bit avec PWM) ---------------------
SynthDef(\squareLead, {
    arg freq = 440, gate = 1, pwmRate = 0.5, pwmDepth = 0.3,
        cutoff = 5000, rq = 0.6,
        attack = 0.005, decay = 0.1, sustain = 0.5, release = 0.25,
        drive = 1.4, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, pw;
    pw = SinOsc.kr(pwmRate).range(0.5 - pwmDepth, 0.5 + pwmDepth);
    sig = Pulse.ar(freq, pw);
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- FM Lead (style Yamaha DX, 2 operateurs) ----------------------
SynthDef(\fmLead, {
    arg freq = 440, gate = 1,
        modRatio = 2.0, modIndex = 3,
        cutoff = 6000, rq = 0.7,
        attack = 0.003, decay = 0.15, sustain = 0.6, release = 0.4,
        drive = 1.2, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, mod, idxEnv;
    // Index modulation qui decroit (caracteristique FM)
    idxEnv = EnvGen.kr(Env([modIndex, modIndex * 0.3], [0.3], -3));
    mod = SinOsc.ar(freq * modRatio) * freq * idxEnv * 0.001;
    sig = SinOsc.ar(freq + (mod * freq));
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Organ Lead (drawbar orgue Hammond-like) ---------------------
SynthDef(\organLead, {
    arg freq = 440, gate = 1,
        cutoff = 4500, rq = 0.5,
        attack = 0.005, decay = 0.05, sustain = 0.85, release = 0.15,
        drive = 1.3, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, drawbars;
    // 6 drawbars : sub, fund, octave, 12th, 15th, 17th
    drawbars = [0.5, 1, 2, 3, 4, 5];
    sig = Mix.fill(drawbars.size, { |i|
        SinOsc.ar(freq * drawbars[i]) * (1 / (i + 1));
    }) * 0.6;
    sig = LPF.ar(sig, cutoff);
    sig = sig + (sig * SinOsc.kr(6.5, 0).range(0.7, 1));   // leslie tremolo leger
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Hard Lead (saw avec hard sync, brillant) ---------------------
SynthDef(\hardLead, {
    arg freq = 440, gate = 1, syncRatio = 1.5,
        cutoff = 5500, rq = 0.4,
        attack = 0.002, decay = 0.08, sustain = 0.6, release = 0.25,
        drive = 1.8, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck;
    // Sync : oscillateur slave reset par master
    sig = SyncSaw.ar(freq, freq * syncRatio);
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Warm Pad (super-saw 7 voix + LPF doux + chorus stereo) -------
SynthDef(\warmPad, {
    arg freq = 220, gate = 1, detune = 0.014,
        cutoff = 1800, rq = 0.7,
        attack = 0.6, decay = 0.4, sustain = 0.8, release = 2.0,
        drive = 1.0, amp = 0.14, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, oscs, chorusL, chorusR;
    // 7 oscillateurs detunes
    oscs = Mix.fill(7, { |i|
        Saw.ar(freq * (1 + ((i - 3) * detune)))
    }) * 0.18;
    oscs = LPF.ar(oscs, cutoff);
    // Chorus stereo profond
    chorusL = DelayC.ar(oscs, 0.05, SinOsc.kr(0.3, 0).range(0.005, 0.025));
    chorusR = DelayC.ar(oscs, 0.05, SinOsc.kr(0.4, pi).range(0.005, 0.025));
    sig = [oscs + (chorusL * 0.5), oscs + (chorusR * 0.5)];
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = Balance2.ar(sig[0], sig[1], pan);
    Out.ar(0, sig * env * amp * duck);
}).add;

// ----- Strings (ensemble orchestral, 5 voix detunees stochastiquement) ---
SynthDef(\strings, {
    arg freq = 440, gate = 1, detune = 0.008,
        cutoff = 3500, rq = 0.6,
        attack = 0.3, decay = 0.2, sustain = 0.85, release = 1.2,
        drive = 1.1, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, voices;
    voices = Mix.fill(5, { |i|
        var f = freq * (1 + (LFNoise2.kr(0.3 + (i * 0.1)) * detune));
        Saw.ar(f) + (Pulse.ar(f * 1.005, 0.4) * 0.3);
    }) * 0.15;
    voices = RLPF.ar(voices, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (voices * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Choir (voix synthetique via formants vocaux) -----------------
SynthDef(\choir, {
    arg freq = 220, gate = 1,
        formant1 = 800, formant2 = 1150, formant3 = 2900,
        attack = 0.4, decay = 0.3, sustain = 0.7, release = 1.5,
        drive = 1.0, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, src, vib;
    // Vibrato lent humain
    vib = freq * (1 + (SinOsc.kr(5, 0,
        EnvGen.kr(Env([0, 0, 0.015], [0.5, 0.5]))).abs));
    // Source : saw filtree + sub
    src = Saw.ar(vib) + (SinOsc.ar(vib * 0.5) * 0.4);
    // 3 formants vocaux (a, e, o)
    sig = (BPF.ar(src, formant1, 0.15) * 1.0) +
          (BPF.ar(src, formant2, 0.20) * 0.5) +
          (BPF.ar(src, formant3, 0.30) * 0.25);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- FM Bass (techno classic, ratio 2:1) --------------------------
SynthDef(\fmBass, {
    arg freq = 55, gate = 1, modRatio = 2, modIndex = 5,
        cutoff = 1800, rq = 0.5,
        attack = 0.003, decay = 0.15, sustain = 0.6, release = 0.2,
        drive = 1.6, amp = 0.32, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, duck, mod, idxEnv;
    idxEnv = EnvGen.kr(Env([modIndex, 0], [0.2], -3));
    mod = SinOsc.ar(freq * modRatio) * freq * idxEnv * 0.001;
    sig = SinOsc.ar(freq + (mod * freq * 0.8)) +
          (Saw.ar(freq) * 0.3);
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Sub Boom (sub-bass 808 amplified avec saturation tape) ------
SynthDef(\subBoom, {
    arg freq = 50, gate = 1, glide = 0.04,
        attack = 0.005, decay = 0.4, sustain = 0.85, release = 0.6,
        drive = 1.4, amp = 0.4, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, duck, f;
    f = Lag.kr(freq, glide);
    // Sub fondamental + octave -1 + harmonique 2 leger
    sig = (SinOsc.ar(f) * 0.8) +
          (SinOsc.ar(f * 0.5) * 0.5) +
          (SinOsc.ar(f * 2) * 0.15);
    sig = (sig * drive).tanh;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Handpan (steel drum, decay long + harmoniques pures) --------
SynthDef(\handpan, {
    arg freq = 220, gate = 1,
        cutoff = 5000, rq = 0.6,
        attack = 0.001, decay = 0.05, sustain = 0.0, release = 1.5,
        drive = 1.1, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, partials;
    // 4 partiels harmoniques (octaves + quintes)
    partials = [1, 2, 3, 4];
    sig = Mix.fill(partials.size, { |i|
        SinOsc.ar(freq * partials[i]) *
            (1 / ((i * 1.5) + 1)) *
            EnvGen.kr(Env.perc(0.001, release * (1 - (i * 0.15)), 1, -4));
    });
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Flute (bambou avec souffle + vibrato) -----------------------
SynthDef(\flute, {
    arg freq = 440, gate = 1,
        breathAmt = 0.15, vibratoRate = 5, vibratoDepth = 0.012,
        cutoff = 3500, rq = 0.6,
        attack = 0.08, decay = 0.1, sustain = 0.7, release = 0.3,
        drive = 1.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, vibFreq, breath, body;
    vibFreq = freq * (1 + (SinOsc.kr(vibratoRate,
        EnvGen.kr(Env([0, 0, 1], [0.15, 0.4])) * pi) * vibratoDepth));
    body = SinOsc.ar(vibFreq) +
           (SinOsc.ar(vibFreq * 2) * 0.15) +
           (SinOsc.ar(vibFreq * 3) * 0.05);
    breath = HPF.ar(WhiteNoise.ar, 2000) * breathAmt *
             EnvGen.kr(Env([0, 1, 0.6], [0.05, 0.5]));
    sig = body + breath;
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Drone (note longue avec modulation lente, pour ambiances) ---
SynthDef(\drone, {
    arg freq = 110, gate = 1, detune = 0.01,
        cutoff = 1800, rq = 0.4, modRate = 0.15, modDepth = 600,
        attack = 1.5, decay = 0.5, sustain = 0.85, release = 3.0,
        drive = 1.1, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, fc, voices;
    fc = (cutoff + (LFNoise2.kr(modRate) * modDepth)).clip(60, 8000);
    voices = (Saw.ar(freq * (1 - detune)) * 0.4) +
             (Saw.ar(freq * (1 + detune)) * 0.4) +
             (SinOsc.ar(freq * 0.5) * 0.3);   // sub
    sig = RLPF.ar(voices, fc, rq);
    sig = sig + (DelayC.ar(sig, 0.05,
        SinOsc.kr(0.2, 0).range(0.01, 0.04)) * 0.3);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

"=== synthdefs_extra.scd : 12 nouveaux SynthDef charges ===".postln;
"   leads     : \\squareLead  \\fmLead  \\organLead  \\hardLead".postln;
"   pads      : \\warmPad  \\strings  \\choir".postln;
"   bass      : \\fmBass  \\subBoom".postln;
"   world     : \\handpan  \\flute".postln;
"   ambient   : \\drone".postln;
)
