// =====================================================================
//  synth/lead/saw3.scd  --  SynthDef \saw3
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\saw3, {
        arg freq = 220, gate = 1,
            cutoff = 2200, rq = 0.4,
            attack = 0.005, decay = 0.12, sustain = 0.5, release = 0.25,
            drive = 1.4, amp = 0.16, pan = 0,
            scBus = 0, scAmt = 0.5;
        var sig, env, duck;
        sig = (Saw.ar(freq * 0.5)  * 0.35) +
              (Saw.ar(freq)        * 0.55) +
              (Saw.ar(freq * 2)    * 0.25);
        sig = RLPF.ar(sig, cutoff, rq);
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release),
                        gate, doneAction: 2);
        sig = (sig * drive).tanh / drive.sqrt;
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
    }).add;
)
