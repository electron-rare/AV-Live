// synth/world/erhu_v16.scd  --  SynthDef \erhu_v16  // variation erhu flute
(
SynthDef(\erhu_v16, {
    arg freq = 440, gate = 1, breath = 0.2,
        cutoff = 3000, rq = 0.3,
        attack = 0.05, decay = 0.1, sustain = 0.6, release = 0.3,
        drive = 1.2, amp = 0.2, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, body, n, vib, f;
    f = freq.clip(80, 4000);
    vib = SinOsc.kr(7, 0, 0.005, 1);
    body = SinOsc.ar(f * vib) + (SinOsc.ar(f * 2 * vib) * 0.3);
    n = WhiteNoise.ar * breath;
    n = BPF.ar(n, f, 0.5);
    sig = body + n;
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
