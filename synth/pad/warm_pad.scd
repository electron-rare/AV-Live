// =====================================================================
//  synth/pad/warm_pad.scd  --  SynthDef \warmPad
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
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
)
