// synth/drums/kick_v17.scd  --  SynthDef \kick_v17  // variation kick distordu / gabber
(
SynthDef(\kick_v17, {
    arg freq = 45, decay = 0.5, drive = 12.0,
        fold = 0.9, amp = 0.45, pan = 0,
        scBus = 0, scShape = 0.18;
    var pEnv, body, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * 4, freq], [0.04], -4));
    body = Pulse.ar(pEnv.clip(20, 800));
    sig = body.fold2(fold);
    sig = (sig * drive).tanh;
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = LeakDC.ar(sig * ampEnv) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
