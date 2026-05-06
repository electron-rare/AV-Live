// =====================================================================
//  synth/lead/stab.scd  --  SynthDef \stab
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\stab, {
        arg freq = 220, gate = 1, sawAmt = 0.7,
            cutoff = 1500, rq = 0.3,
            attack = 0.001, decay = 0.04, sustain = 0.0, release = 0.06,
            drive = 2.8, amp = 0.18, pan = 0,
            scBus = 0, scAmt = 0.5;
        var sig, env, duck;
        sig = (Saw.ar(freq) * sawAmt) +
              (Pulse.ar(freq * 1.005, 0.3) * (1 - sawAmt));
        sig = RLPF.ar(sig, cutoff, rq);
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release, curve: -3),
                        gate, doneAction: 2);
        sig = (sig * drive).tanh / drive.sqrt;
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
    }).add;
)
