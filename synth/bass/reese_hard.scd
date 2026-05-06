// =====================================================================
//  synth/bass/reese_hard.scd  --  SynthDef \reeseHard
//  Extracted from asia.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\reeseHard, {
    arg freq = 55, gate = 1, detune = 0.018,
        cutoff = 600, rq = 0.15,
        modRate = 0.3, modDepth = 400,        // LFO sur cutoff (slow sweep)
        attack = 0.005, decay = 0.1, sustain = 0.7, release = 0.2,
        drive = 4.0, amp = 0.3, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, fc;
    fc = (cutoff + (SinOsc.kr(modRate) * modDepth)).clip(80, 6000);
    sig = (Saw.ar(freq * (1 - detune)) * 0.4) +
          (Saw.ar(freq * (1 + detune)) * 0.4) +
          (Saw.ar(freq * 0.5) * 0.3) +
          (Pulse.ar(freq * 1.501, 0.5) * 0.2);
    sig = BPF.ar(sig, fc, rq) * 4;
    sig = LPF.ar(sig, 4000);
    sig = (sig * drive).tanh / drive.sqrt;
    sig = (sig * 1.3).tanh;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig) * env * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
