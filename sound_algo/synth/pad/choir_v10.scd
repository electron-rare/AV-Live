// synth/pad/choir_v10.scd  --  SynthDef \choir_v10  // variation choir choir formant
(
SynthDef(\choir_v10, {
    arg freq = 220, gate = 1, detune = 0.014,
        formant1 = 1000, formant2 = 2600,
        attack = 0.6, decay = 0.3, sustain = 0.6, release = 2.0,
        drive = 1.0, amp = 0.15, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, voices;
    voices = Mix.fill(3, { |i|
        Saw.ar(freq * (1 + ((i - 2) * detune * (i + 1) * 0.5)))
    }) * 0.18;
    sig = BPF.ar(voices, formant1, 0.4) + BPF.ar(voices, formant2, 0.5);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
