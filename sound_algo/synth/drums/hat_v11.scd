// synth/drums/hat_v11.scd  --  SynthDef \hat_v11  // variation hat closed
(
SynthDef(\hat_v11, {
    arg decay = 0.1, hpf = 10000, bpf = 8000, rq = 0.6,
        drive = 1.2, amp = 0.2, pan = 0,
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
