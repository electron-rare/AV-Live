// synth/pad/drone_v9.scd  --  SynthDef \drone_v9  // variation drone drone slow
(
SynthDef(\drone_v9, {
    arg freq = 110, gate = 1, detune = 0.005,
        cutoff = 2000, rq = 0.7,
        attack = 0.5, decay = 1.5, sustain = 0.9, release = 2.0,
        drive = 1.4, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, lfo;
    lfo = SinOsc.kr(0.1).range(1 - detune, 1 + detune);
    sig = LFTri.ar(freq * lfo) +
          LFTri.ar(freq * 0.501 * lfo) * 0.5;
    sig = LPF.ar(sig, cutoff);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
