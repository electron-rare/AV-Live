// synth/bass/bass808_v8.scd  --  SynthDef \bass808_v8  // variation 808 bass sub long
(
SynthDef(\bass808_v8, {
    arg freq = 50, gate = 1,
        attack = 0.002, decay = 1.0, sustain = 0.1, release = 1.0,
        drive = 2.0, amp = 0.4, pan = 0,
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
