// synth/bass/sub_boom_v16.scd  --  SynthDef \sub_boom_v16  // variation sub boom long
(
SynthDef(\sub_boom_v16, {
    arg freq = 30, gate = 1,
        attack = 0.005, decay = 3.0, sustain = 0.1, release = 0.5,
        drive = 1.0, amp = 0.4, pan = 0,
        scBus = 0, scAmt = 0.6;
    var sig, env, duck;
    sig = LFTri.ar(freq.clip(20, 200));
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
