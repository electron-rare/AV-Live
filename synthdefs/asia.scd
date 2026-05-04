// =====================================================================
//  synthdefs_asia.scd  --  Palette exotique pour mélodies asiatiques
//                         (koto, erhu, gong, growl dubstep)
//
//  USAGE : evaluer ce bloc une fois apres engine.scd. Les nouveaux
//          SynthDef sont disponibles dans ~melodyInst (\koto, \erhu, ...)
//          et via Synth direct pour les FX (\gong, \growl).
// =====================================================================

(
// ----- Koto (corde asiatique pincee : Karplus-Strong + brillant) -----
//   son percussif, decay long, fondamentale + 2 harmoniques claires
SynthDef(\koto, {
    arg freq = 220, gate = 1, cutoff = 6000, rq = 0.5,
        attack = 0.001, decay = 0.04, sustain = 0.0, release = 0.6,
        drive = 1.2, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, exciter, ks, harm;
    exciter = WhiteNoise.ar(0.6) * EnvGen.kr(Env.perc(0.0005, 0.003));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, freq.reciprocal, 3.0));
    // Harmonique 2 (octave) ajoute pour brillance koto
    harm = LeakDC.ar(CombC.ar(exciter * 0.3, 0.05, (freq * 2).reciprocal, 1.5));
    sig = LPF.ar(ks + harm, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Erhu (violon chinois -- saw filtre + portamento + vibrato) ---
//   corde frottee, sustain naturel, vibrato lent
SynthDef(\erhu, {
    arg freq = 440, gate = 1,
        cutoff = 2500, rq = 0.4,
        vibratoRate = 5.5, vibratoDepth = 0.015,
        attack = 0.05, decay = 0.1, sustain = 0.6, release = 0.3,
        drive = 1.3, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, vibFreq;
    // Vibrato sinusoidal (apres petit delay pour entrer doucement)
    vibFreq = freq * (1 + (SinOsc.kr(vibratoRate,
        EnvGen.kr(Env([0, 0, 1], [0.1, 0.3])) * pi) * vibratoDepth));
    sig = (Saw.ar(vibFreq) * 0.6) + (Pulse.ar(vibFreq * 1.005, 0.4) * 0.4);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Pipa (luth chinois : pluck + decay rapide + bend) -------------
SynthDef(\pipa, {
    arg freq = 330, gate = 1, bendAmt = 0.04, bendTime = 0.08,
        cutoff = 4500, rq = 0.4,
        attack = 0.001, decay = 0.06, sustain = 0.0, release = 0.4,
        drive = 1.5, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, exciter, ks, bentFreq;
    // Petit bend de pitch initial (caracteristique pipa)
    bentFreq = freq * (1 + EnvGen.kr(Env([bendAmt, 0], [bendTime], -3)));
    exciter = WhiteNoise.ar(0.7) * EnvGen.kr(Env.perc(0.0005, 0.004));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, bentFreq.reciprocal, 1.8));
    sig = LPF.ar(ks, cutoff);
    sig = (sig * drive).tanh;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;

// ----- Gong (FX oneshot : metallique avec long decay + pitch drop) --
SynthDef(\gong, {
    arg freq = 80, decay = 4, amp = 0.5, pan = 0;
    var sig, env, partials, pitchEnv;
    // Pitch drop expo (caracteristique gong)
    pitchEnv = EnvGen.kr(Env([freq * 1.3, freq], [0.15], \exp));
    // Plusieurs partiels inharmoniques (gong : ratios non-entiers)
    partials = [1, 1.41, 1.93, 2.71, 3.42, 4.83];
    sig = Mix.fill(partials.size, { |i|
        SinOsc.ar(pitchEnv * partials[i]) *
            (1 / (i + 1)) *
            EnvGen.kr(Env.perc(0.005, decay * (1 - (i * 0.12)), 1, -3 - i));
    });
    sig = sig + (HPF.ar(WhiteNoise.ar, 4000) *
                 EnvGen.kr(Env.perc(0.001, 0.05)) * 0.3);
    env = EnvGen.kr(Env.linen(0.001, decay, 0.05), doneAction: 2);
    sig = (sig * 1.3).tanh;
    sig = LeakDC.ar(sig) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ----- Growl (hard dubstep -- saturation maitrisee) -----------------
//   Saws detunes + FM legere + sub charpente + RLPF wobble + tanh
//   simple normalise. Headroom protege le master limiter.
SynthDef(\growl, {
    arg freq = 55, gate = 1,
        modRatio = 0.5, modIndex = 4,
        wobbleRate = 4, wobbleDepth = 2500, wobbleShape = 0,
        cutoff = 250, rq = 0.25,
        subAmt = 0.7, detune = 0.012,
        attack = 0.005, decay = 0.2, sustain = 0.7, release = 0.3,
        drive = 3.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, sub, mod, carL, carR, wobble, lfo;
    lfo = SelectX.kr(wobbleShape, [
        LFTri.kr(wobbleRate),
        LFPulse.kr(wobbleRate, 0, 0.5, 2, -1)
    ]);
    wobble = (cutoff + (lfo.range(0, 1) * wobbleDepth)).clip(60, 10000);
    // FM modulee (modIndex 4 max -- pas trop violent)
    mod = SinOsc.ar(freq * modRatio) * freq * modIndex * 0.0008;
    carL = Saw.ar(freq * (1 - detune) + mod);
    carR = Saw.ar(freq * (1 + detune) + mod);
    // Sub charpente (2 oscillateurs, normalisees a 1)
    sub = ((SinOsc.ar(freq * 0.5) * 0.6) +
           (SinOsc.ar(freq * 0.25) * 0.4)) * subAmt;
    // Mix : carrieres a 0.4 chacune + sub a 0.5 = headroom
    sig = [(carL * 0.4) + (sub * 0.5), (carR * 0.4) + (sub * 0.5)];
    sig = RLPF.ar(sig, wobble, rq);
    // UN seul tanh + normalisation par sqrt(drive)
    sig = (sig * drive).tanh / drive.sqrt;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig) * env * amp * duck;
    sig = Balance2.ar(sig[0], sig[1], pan);
    Out.ar(0, sig);
}).add;

// ----- Reese aggressive (hard DnB / dubstep) ------------------------
//   Filtre passe-bande resonant + LFO sur depth + drive max
SynthDef(\reeseHard, {
    arg freq = 55, gate = 1, detune = 0.018,
        cutoff = 600, rq = 0.15,
        modRate = 0.3, modDepth = 400,        // LFO sur cutoff (slow sweep)
        attack = 0.005, decay = 0.1, sustain = 0.7, release = 0.2,
        drive = 4.0, amp = 0.3, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, fc;
    fc = (cutoff + (SinOsc.kr(modRate) * modDepth)).clip(80, 6000);
    sig = (Saw.ar(freq * (1 - detune)) * 0.4) +
          (Saw.ar(freq * (1 + detune)) * 0.4) +
          (Saw.ar(freq * 0.5) * 0.3) +
          (Pulse.ar(freq * 1.501, 0.5) * 0.2);
    sig = BPF.ar(sig, fc, rq) * 4;
    sig = LPF.ar(sig, 4000);
    sig = (sig * drive).tanh / drive.sqrt;
    sig = (sig * 1.3).tanh;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig) * env * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

"=== synthdefs_asia.scd : 6 nouveaux SynthDef charges ===".postln;
"   melodiques  : \\koto  \\erhu  \\pipa".postln;
"   FX oneshot  : \\gong".postln;
"   bass dubstep: \\growl  \\reeseHard".postln;
)
