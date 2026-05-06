// synth/bass/fm_bass_v2.scd  --  SynthDef \fm_bass_v2  // variation FM bass 2-op
(
SynthDef(\fm_bass_v2, {
    arg freq = 110, gate = 1, ratio = 1.0, modIndex = 100,
        attack = 0.003, decay = 0.3, sustain = 0.5, release = 0.2,
        drive = 1.5, amp = 0.3, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, mod, duck, f;
    f = freq.clip(20, 8000);
    mod = SinOsc.ar(f * ratio) * f * modIndex;
    sig = SinOsc.ar(f + mod);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
