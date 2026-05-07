// synth/bass/sub_boom_v7.scd  --  SynthDef \sub_boom_v7  // variation sub boom long
(
SynthDef(\sub_boom_v7, {
    arg freq = 35, gate = 1,
        attack = 0.005, decay = 2.0, sustain = 0.0, release = 0.5,
        drive = 1.0, amp = 0.4, pan = 0,
        scBus = 0, scAmt = 0.6;
    var sig, env, duck;
    sig = SinOsc.ar(freq.clip(20, 200));
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
