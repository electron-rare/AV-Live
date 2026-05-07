// =====================================================================
//  synth/bass/acid.scd  --  SynthDef \acid
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\acid, {
        arg freq = 110, gate = 1, accent = 0, slideTime = 0.005,
            cutoff = 800, cutoffEnv = 3500, rq = 0.15,
            envDecay = 0.35, ampDecay = 0.28,
            drive = 2.5, amp = 0.32, pan = 0,
            scBus = 0, scAmt = 0.7;
        var f, sig, ampEnv, fEnv, fc, duck;
        f = Lag.kr(freq, slideTime);
        sig = Saw.ar(f);
        fEnv = EnvGen.kr(Env.perc(0.001, envDecay * (1 - (accent * 0.4))),
                         gate, doneAction: 0);
        fc = (cutoff + (fEnv * cutoffEnv * (1 + accent))).clip(60, 14000);
        sig = RLPF.ar(sig, fc, rq);
        // ADSR avec sustain=0 : la note "perc" naturelle, mais le
        // release de 50ms permet le retrigger PmonoArtic sans free.
        // doneAction:2 libere le Synth quand release atteint 0 -> safe.
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
