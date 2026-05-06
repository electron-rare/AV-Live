// synth/pad/drone_v11.scd  --  SynthDef \drone_v11  // variation drone drone slow
(
SynthDef(\drone_v11, {
    arg freq = 110, gate = 1, detune = 0.015,
        cutoff = 800, rq = 0.4,
        attack = 1.5, decay = 1.0, sustain = 0.8, release = 4.0,
        drive = 1.2, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, lfo;
    lfo = SinOsc.kr(0.2).range(1 - detune, 1 + detune);
    sig = Pulse.ar(freq * lfo) +
          Pulse.ar(freq * 0.501 * lfo) * 0.5;
    sig = LPF.ar(sig, cutoff);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
