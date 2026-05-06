// synth/drums/hat_v19.scd  --  SynthDef \hat_v19  // variation hat closed
(
SynthDef(\hat_v19, {
    arg decay = 0.04, hpf = 6000, bpf = 10000, rq = 0.6,
        drive = 1.0, amp = 0.2, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, env, n;
    n = WhiteNoise.ar;
    n = HPF.ar(n, hpf);
    n = BPF.ar(n, bpf, rq);
    env = EnvGen.kr(Env.perc(0.001, decay, curve: -5), doneAction: 2);
    sig = (n * env * drive).tanh;
    sig = LeakDC.ar(sig) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
