// =====================================================================
//  synth/bass/hooverbass.scd  --  SynthDef \hooverbass
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\hooverbass, {
    arg freq = 110, gate = 1, detune = 0.012,
        cutoff = 3500, rq = 0.4,
        attack = 0.001, decay = 0.1, sustain = 0.7, release = 0.2,
        drive = 1.6, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, voices, pwm;
    pwm = LFTri.kr(0.3).range(0.3, 0.7);
    voices = [
        Saw.ar(freq * (1 - detune)) * 0.4,
        Saw.ar(freq * (1 + detune)) * 0.4,
        Pulse.ar(freq * 0.5, pwm) * 0.3,        // sub octave
        Pulse.ar(freq * 2 * (1 + (detune * 1.5)), pwm) * 0.2  // octave aigu
    ];
    sig = Mix(voices);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig) * env * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
