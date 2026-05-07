// synth/world/didgeridoo_world_v6.scd  --  SynthDef \didgeridoo_world_v6  // variation didgeridoo_world drone formant
(
SynthDef(\didgeridoo_world_v6, {
    arg freq = 70, gate = 1, formantFreq = 200,
        attack = 0.2, decay = 0.5, sustain = 0.9, release = 1.5,
        drive = 2.5, amp = 0.28, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, body, lfo, f;
    f = freq.clip(40, 400);
    lfo = SinOsc.kr(3).range(0.95, 1.05);
    body = Saw.ar(f * lfo) + (Pulse.ar(f * 2 * lfo, 0.4) * 0.3);
    sig = BPF.ar(body, formantFreq, 0.3);
    sig = LPF.ar(sig, 1200);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
