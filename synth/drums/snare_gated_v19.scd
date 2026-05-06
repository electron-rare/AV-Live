// synth/drums/snare_gated_v19.scd  --  SynthDef \snare_gated_v19  // variation snare gated punchy
(
SynthDef(\snare_gated_v19, {
    arg freq = 200, decay = 0.09, tone = 0.4, noise = 0.7,
        drive = 4.0, amp = 0.4, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, ampEnv, body, n;
    body = SinOsc.ar(freq) + SinOsc.ar(freq * 1.4);
    n = HPF.ar(WhiteNoise.ar, 1500);
    sig = (body * tone) + (n * noise);
    ampEnv = EnvGen.kr(Env.perc(0.001, decay, curve: -6), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig * ampEnv) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
