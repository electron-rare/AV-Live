// synth/drums/snare_gated_v18.scd  --  SynthDef \snare_gated_v18  // variation snare gated punchy
(
SynthDef(\snare_gated_v18, {
    arg freq = 240, decay = 0.07, tone = 0.5, noise = 0.9,
        drive = 3.0, amp = 0.4, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, ampEnv, body, n;
    body = SinOsc.ar(freq) + SinOsc.ar(freq * 1.4);
    n = HPF.ar(WhiteNoise.ar, 2500);
    sig = (body * tone) + (n * noise);
    ampEnv = EnvGen.kr(Env.perc(0.001, decay, curve: -10), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig * ampEnv) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
