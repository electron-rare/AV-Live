// synth/bass/bass808_v13.scd  --  SynthDef \bass808_v13  // variation 808 bass sub long
(
SynthDef(\bass808_v13, {
    arg freq = 50, gate = 1,
        attack = 0.001, decay = 1.0, sustain = 0.0, release = 0.1,
        drive = 1.0, amp = 0.4, pan = 0,
        scBus = 0, scAmt = 0.6;
    var sig, env, duck;
    sig = SinOsc.ar(freq.clip(20, 200));
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
