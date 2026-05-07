// synth/drums/kick_gabber_v13.scd  --  SynthDef \kick_gabber_v13  // variation gabber stomp distordu
(
SynthDef(\kick_gabber_v13, {
    arg freq = 60, decay = 0.2, drive = 16,
        fold = 0.7, amp = 0.4, pan = 0,
        scBus = 0, scShape = 0.16;
    var pEnv, body, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * 4, freq], [0.04], -4));
    body = LFTri.ar(pEnv.clip(20, 800));
    sig = body.fold2(fold);
    sig = (sig * drive).tanh;
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = LeakDC.ar(sig * ampEnv) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
