// =====================================================================
//  synth/bass/reese.scd  --  SynthDef \reese
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\reese, {
        arg freq = 55, gate = 1, detune = 0.012, cutoff = 800, rq = 0.4,
            attack = 0.005, decay = 0.1, sustain = 0.7, release = 0.2,
            drive = 2.5, amp = 0.35, pan = 0,
            scBus = 0, scAmt = 0.4;
        var sig, env, duck;
        sig = (Saw.ar(freq * (1 - detune)) * 0.5) +
              (Saw.ar(freq * (1 + detune)) * 0.5) +
              (Saw.ar(freq * 0.5) * 0.3);   // sub
        sig = RLPF.ar(sig, cutoff, rq);
        sig = (sig * drive).tanh / drive.sqrt;
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        sig = LeakDC.ar(sig) * env * amp * duck;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;
)
