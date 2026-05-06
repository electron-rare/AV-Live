// synth/drums/hat_v9.scd  --  SynthDef \hat_v9  // variation hat closed
(
SynthDef(\hat_v9, {
    arg decay = 0.06, hpf = 8000, bpf = 12000, rq = 0.4,
        drive = 1.4, amp = 0.2, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, env, n;
    n = WhiteNoise.ar;
    n = HPF.ar(n, hpf);
    n = BPF.ar(n, bpf, rq);
    env = EnvGen.kr(Env.perc(0.001, decay, curve: -3), doneAction: 2);
    sig = (n * env * drive).tanh;
    sig = LeakDC.ar(sig) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
