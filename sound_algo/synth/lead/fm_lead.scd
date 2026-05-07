// =====================================================================
//  synth/lead/fm_lead.scd  --  SynthDef \fmLead
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fmLead, {
    arg freq = 440, gate = 1,
        modRatio = 2.0, modIndex = 3,
        cutoff = 6000, rq = 0.7,
        attack = 0.003, decay = 0.15, sustain = 0.6, release = 0.4,
        drive = 1.2, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, mod, idxEnv;
    // Index modulation qui decroit (caracteristique FM)
    idxEnv = EnvGen.kr(Env([modIndex, modIndex * 0.3], [0.3], -3));
    mod = SinOsc.ar(freq * modRatio) * freq * idxEnv * 0.001;
    sig = SinOsc.ar(freq + (mod * freq));
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
