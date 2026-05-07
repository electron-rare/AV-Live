// synth/bass/acid_v6.scd  --  SynthDef \acid_v6  // variation acid TB-303
(
SynthDef(\acid_v6, {
    arg freq = 110, gate = 1, accent = 0, slideTime = 0.01,
        cutoff = 1500, cutoffEnv = 5000, rq = 0.08,
        envDecay = 0.35, ampDecay = 0.2,
        drive = 4.0, amp = 0.32, pan = 0,
        scBus = 0, scAmt = 0.7;
    var f, sig, ampEnv, fEnv, fc, duck;
    f = Lag.kr(freq, slideTime);
    sig = Pulse.ar(f);
    fEnv = EnvGen.kr(Env.perc(0.001, envDecay * (1 - (accent * 0.4))),
                     gate, doneAction: 0);
    fc = (cutoff + (fEnv * cutoffEnv * (1 + accent))).clip(60, 14000);
    sig = RLPF.ar(sig, fc, rq);
    ampEnv = EnvGen.kr(
        Env.adsr(0.003, ampDecay, 0, 0.05, curve: -3),
        gate, doneAction: 2
    );
    sig = (sig * drive * (1 + (accent * 0.6))).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = sig * ampEnv * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
