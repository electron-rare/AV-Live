// synth/drums/hat_v18.scd  --  SynthDef \hat_v18  // variation hat closed
(
SynthDef(\hat_v18, {
    arg decay = 0.07, hpf = 5000, bpf = 13000, rq = 0.5,
        drive = 1.4, amp = 0.2, pan = 0,
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
