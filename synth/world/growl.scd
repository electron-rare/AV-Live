// =====================================================================
//  synth/world/growl.scd  --  SynthDef \growl
//  Extracted from asia.scd during v2 reorganization.
// =====================================================================
(
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
)
