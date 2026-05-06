// synth/lead/saw3_v7.scd  --  SynthDef \saw3_v7  // variation saw3 supersaw
(
SynthDef(\saw3_v7, {
    arg freq = 200, gate = 1, detune = 0.008, mix = 0.4,
        cutoff = 3000, rq = 0.6,
        attack = 0.005, decay = 0.1, sustain = 0.5, release = 0.3,
        drive = 1.4, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, voices, center, sides;
    voices = ((-2..2)).collect { |i|
        Saw.ar(freq * (1 + (i * detune)))
    };
    center = voices[2];
    sides = voices.removeAt(2);
    sig = (center * (1 - mix)) + (Mix(voices) * mix * 0.18);
    sig = LPF.ar(sig, cutoff);
    sig = [DelayC.ar(sig, 0.03, SinOsc.kr(0.4, 0).range(0.005, 0.018)),
           DelayC.ar(sig, 0.03, SinOsc.kr(0.5, pi).range(0.005, 0.018))];
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = [(sig[0] * drive).softclip / drive.sqrt, (sig[1] * drive).softclip / drive.sqrt];
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = Balance2.ar(sig[0], sig[1], pan);
    Out.ar(0, sig * env * amp * duck);
}).add;
)
