// synth/pad/vocal_pad_v14.scd  --  SynthDef \vocal_pad_v14  // variation vocal_pad choir formant
(
SynthDef(\vocal_pad_v14, {
    arg freq = 330, gate = 1, detune = 0.014,
        formant1 = 900, formant2 = 2400,
        attack = 0.6, decay = 0.5, sustain = 0.7, release = 2.0,
        drive = 1.1, amp = 0.15, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, voices;
    voices = Mix.fill(4, { |i|
        Saw.ar(freq * (1 + ((i - 2) * detune * (i + 1) * 0.5)))
    }) * 0.18;
    sig = BPF.ar(voices, formant1, 0.4) + BPF.ar(voices, formant2, 0.5);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
