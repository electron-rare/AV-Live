// synth/pad/drone_v10.scd  --  SynthDef \drone_v10  // variation drone drone slow
(
SynthDef(\drone_v10, {
    arg freq = 110, gate = 1, detune = 0.01,
        cutoff = 2500, rq = 0.8,
        attack = 1.0, decay = 0.5, sustain = 0.7, release = 3.0,
        drive = 1.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, lfo;
    lfo = SinOsc.kr(0.15).range(1 - detune, 1 + detune);
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
