// =====================================================================
//  synth/lead/supersaw.scd  --  SynthDef \supersaw
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\supersaw, {
    arg freq = 220, gate = 1, detune = 0.018, mix = 0.5,
        cutoff = 4500, rq = 0.5,
        attack = 0.005, decay = 0.15, sustain = 0.6, release = 0.4,
        drive = 1.2, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, voices, center, sides;
    // 7 voix detunees (style JP-8000 supersaw)
    voices = (-3..3).collect { |i|
        Saw.ar(freq * (1 + (i * detune)))
    };
    center = voices[3];
    sides = voices.removeAt(3);
    sig = (center * (1 - mix)) + (Mix(voices) * mix * 0.18);
    sig = LPF.ar(sig, cutoff);
    // Chorus stereo
    sig = [DelayC.ar(sig, 0.03, SinOsc.kr(0.4, 0).range(0.005, 0.018)),
           DelayC.ar(sig, 0.03, SinOsc.kr(0.5, pi).range(0.005, 0.018))];
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = Balance2.ar(sig[0], sig[1], pan);
    Out.ar(0, sig * env * amp * duck);
}).add;
)
