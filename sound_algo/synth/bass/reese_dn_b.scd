// =====================================================================
//  synth/bass/reese_dn_b.scd  --  SynthDef \reeseDnB
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\reeseDnB, {
    arg freq = 55, gate = 1, detune = 0.018,
        cutoff = 800, rq = 0.2,
        modRate1 = 0.25, modDepth1 = 600,
        modRate2 = 0.7, modDepth2 = 250,
        attack = 0.005, decay = 0.1, sustain = 0.7, release = 0.2,
        drive = 4.0, amp = 0.30, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, fc, sub;
    fc = (cutoff + (SinOsc.kr(modRate1) * modDepth1)
                + (SinOsc.kr(modRate2) * modDepth2)).clip(80, 8000);
    sig = (Saw.ar(freq * (1 - detune)) * 0.4) +
          (Saw.ar(freq * (1 + detune)) * 0.4) +
          (Saw.ar(freq * (1 + (detune * 2.7))) * 0.3);
    sub = SinOsc.ar(freq * 0.5) * 0.5;
    sig = BPF.ar(sig, fc, rq) * 4 + sub;
    sig = LPF.ar(sig, 4500);
    sig = (sig * drive).tanh / drive.sqrt;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig) * env * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
