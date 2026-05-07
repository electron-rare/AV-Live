// synth/drums/snare_v7.scd  --  SynthDef \snare_v7  // variation snare standard
(
SynthDef(\snare_v7, {
    arg freq = 280, decay = 0.15, tone = 0.4, noise = 0.6,
        drive = 2.0, amp = 0.35, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, ampEnv, body, n;
    body = SinOsc.ar(freq) + SinOsc.ar(freq * 1.4);
    n = HPF.ar(WhiteNoise.ar, 1000);
    sig = (body * tone) + (n * noise);
    ampEnv = EnvGen.kr(Env.perc(0.001, decay, curve: -5), doneAction: 2);
    sig = (sig * drive).softclip;
    sig = LeakDC.ar(sig * ampEnv) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
