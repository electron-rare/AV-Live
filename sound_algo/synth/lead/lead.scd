// =====================================================================
//  synth/lead/lead.scd  --  SynthDef \lead
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\lead, {
        arg freq = 220, gate = 1, sawAmt = 0.6, pulseWidth = 0.4,
            cutoff = 2500, rq = 0.5,
            attack = 0.01, decay = 0.15, sustain = 0.4, release = 0.3,
            detune = 0.005, drive = 1.2, amp = 0.18, pan = 0,
            scBus = 0, scAmt = 0.5;
        var oscL, oscR, sig, ampEnv, duck;
        oscL = (Saw.ar(freq * (1 - detune)) * sawAmt) +
               (Pulse.ar(freq * (1 - detune), pulseWidth) * (1 - sawAmt));
        oscR = (Saw.ar(freq * (1 + detune)) * sawAmt) +
               (Pulse.ar(freq * (1 + detune), pulseWidth) * (1 - sawAmt));
        oscL = DelayC.ar(oscL, 0.02, SinOsc.kr(0.6, 0).range(0.001, 0.004));
        oscR = DelayC.ar(oscR, 0.02, SinOsc.kr(0.6, pi).range(0.001, 0.004));
        sig = RLPF.ar([oscL, oscR], cutoff, rq);
        ampEnv = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
        sig = (sig * drive).tanh / drive.sqrt;
        sig = Balance2.ar(sig[0], sig[1], pan);
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        Out.ar(0, sig * ampEnv * amp * duck);
    }).add;
)
