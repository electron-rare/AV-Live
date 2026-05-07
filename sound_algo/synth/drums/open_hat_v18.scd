// synth/drums/open_hat_v18.scd  --  SynthDef \open_hat_v18  // variation open hat plus long
(
SynthDef(\open_hat_v18, {
    arg decay = 0.35, hpf = 6000, bpf = 9000, rq = 0.7,
        drive = 1.2, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, env, n;
    n = WhiteNoise.ar;
    n = HPF.ar(n, hpf);
    n = BPF.ar(n, bpf, rq);
    env = EnvGen.kr(Env.perc(0.001, decay, curve: -4), doneAction: 2);
    sig = (n * env * drive).tanh;
    sig = LeakDC.ar(sig) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
