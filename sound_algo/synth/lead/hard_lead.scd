// =====================================================================
//  synth/lead/hard_lead.scd  --  SynthDef \hardLead
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\hardLead, {
    arg freq = 440, gate = 1, syncRatio = 1.5,
        cutoff = 5500, rq = 0.4,
        attack = 0.002, decay = 0.08, sustain = 0.6, release = 0.25,
        drive = 1.8, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck;
    // Sync : oscillateur slave reset par master
    sig = SyncSaw.ar(freq, freq * syncRatio);
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
