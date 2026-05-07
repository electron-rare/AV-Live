// synth/drums/snare_v6.scd  --  SynthDef \snare_v6  // variation snare standard
(
SynthDef(\snare_v6, {
    arg freq = 160, decay = 0.1, tone = 0.3, noise = 0.5,
        drive = 1.5, amp = 0.35, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, ampEnv, body, n;
    body = SinOsc.ar(freq) + SinOsc.ar(freq * 1.4);
    n = HPF.ar(WhiteNoise.ar, 800);
    sig = (body * tone) + (n * noise);
    ampEnv = EnvGen.kr(Env.perc(0.001, decay, curve: -4), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig * ampEnv) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
