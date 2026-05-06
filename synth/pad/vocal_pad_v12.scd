// synth/pad/vocal_pad_v12.scd  --  SynthDef \vocal_pad_v12  // variation vocal_pad choir formant
(
SynthDef(\vocal_pad_v12, {
    arg freq = 330, gate = 1, detune = 0.022,
        formant1 = 700, formant2 = 2000,
        attack = 1.0, decay = 0.7, sustain = 0.8, release = 3.0,
        drive = 1.2, amp = 0.15, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, voices;
    voices = Mix.fill(5, { |i|
        Saw.ar(freq * (1 + ((i - 2) * detune * (i + 1) * 0.5)))
    }) * 0.18;
    sig = BPF.ar(voices, formant1, 0.4) + BPF.ar(voices, formant2, 0.5);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
