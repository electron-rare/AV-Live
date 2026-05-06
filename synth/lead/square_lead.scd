// =====================================================================
//  synth/lead/square_lead.scd  --  SynthDef \squareLead
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\squareLead, {
    arg freq = 440, gate = 1, pwmRate = 0.5, pwmDepth = 0.3,
        cutoff = 5000, rq = 0.6,
        attack = 0.005, decay = 0.1, sustain = 0.5, release = 0.25,
        drive = 1.4, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, pw;
    pw = SinOsc.kr(pwmRate).range(0.5 - pwmDepth, 0.5 + pwmDepth);
    sig = Pulse.ar(freq, pw);
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
