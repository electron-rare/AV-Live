// synth/lead/hard_lead_v15.scd  --  SynthDef \hard_lead_v15  // variation hard_lead supersaw
(
SynthDef(\hard_lead_v15, {
    arg freq = 330, gate = 1, detune = 0.016, mix = 0.7,
        cutoff = 5000, rq = 0.6,
        attack = 0.02, decay = 0.2, sustain = 0.7, release = 0.5,
        drive = 1.4, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, voices, center, sides;
    voices = ((-4..4)).collect { |i|
        Saw.ar(freq * (1 + (i * detune)))
    };
    center = voices[4];
    sides = voices.removeAt(4);
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
