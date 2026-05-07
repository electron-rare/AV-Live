// synth/world/growl_v15.scd  --  SynthDef \growl_v15  // variation growl drone formant
(
SynthDef(\growl_v15, {
    arg freq = 60, gate = 1, formantFreq = 600,
        attack = 0.2, decay = 0.3, sustain = 0.9, release = 1.5,
        drive = 2.5, amp = 0.28, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, body, lfo, f;
    f = freq.clip(40, 400);
    lfo = SinOsc.kr(12).range(0.95, 1.05);
    body = Saw.ar(f * lfo) + (Pulse.ar(f * 2 * lfo, 0.4) * 0.3);
    sig = BPF.ar(body, formantFreq, 0.3);
    sig = LPF.ar(sig, 1600);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
