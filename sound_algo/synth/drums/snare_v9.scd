// synth/drums/snare_v9.scd  --  SynthDef \snare_v9  // variation snare standard
(
SynthDef(\snare_v9, {
    arg freq = 180, decay = 0.25, tone = 0.6, noise = 0.8,
        drive = 1.2, amp = 0.35, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, ampEnv, body, n;
    body = SinOsc.ar(freq) + SinOsc.ar(freq * 1.4);
    n = HPF.ar(WhiteNoise.ar, 2000);
    sig = (body * tone) + (n * noise);
    ampEnv = EnvGen.kr(Env.perc(0.001, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig * ampEnv) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
