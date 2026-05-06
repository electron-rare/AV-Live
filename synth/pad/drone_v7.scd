// synth/pad/drone_v7.scd  --  SynthDef \drone_v7  // variation drone drone slow
(
SynthDef(\drone_v7, {
    arg freq = 110, gate = 1, detune = 0.015,
        cutoff = 1200, rq = 0.5,
        attack = 1.5, decay = 0.5, sustain = 0.7, release = 4.0,
        drive = 1.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, lfo;
    lfo = SinOsc.kr(0.2).range(1 - detune, 1 + detune);
    sig = Saw.ar(freq * lfo) +
          Saw.ar(freq * 0.501 * lfo) * 0.5;
    sig = LPF.ar(sig, cutoff);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip / drive.sqrt;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
