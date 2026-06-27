// Morceau 1 -- Hypno Drift (hypnotic). Drone filtre + sub pulse + kick sparse.
// mains hautes -> ouvre le filtre ; cx -> pan ; kick lent quand corps present.
(
SynthDef(\cc_drift_drone, { |out=0, freq=55, cutoff=300, amp=0.0, pan=0, gate=1|
    var sig = Mix(Saw.ar(freq * [1, 1.003, 0.5])) * 0.25;
    sig = RLPF.ar(sig, cutoff.clip(100, 6000), 0.4);
    sig = sig * EnvGen.kr(Env.asr(3, 1, 4), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp.lag(1.0));
}).add;
SynthDef(\cc_drift_sub, { |out=0, freq=55, amp=0.0, gate=1|
    var sig = SinOsc.ar(freq.clip(20, 200)) * LFPulse.kr(0.5, 0, 0.35);
    sig = sig * EnvGen.kr(Env.asr(0.5, 1, 1), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.5));
}).add;
SynthDef(\cc_drift_kick, { |out=0, amp=0.5|
    var env = EnvGen.kr(Env.perc(0.001, 0.4), doneAction: 2);
    var fenv = EnvGen.kr(Env([120, 45], [0.08], \exp));
    var sig = SinOsc.ar(fenv) * env;
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp);
}).add;

~concertAdd.((
    name: "Hypno Drift", style: \hypnotic,
    start: { |ctx|
        ctx[\drone] = Synth(\cc_drift_drone, [\freq, 55, \cutoff, 300, \amp, 0.22]);
        ctx[\sub]   = Synth(\cc_drift_sub,   [\freq, 55, \amp, 0.18]);
        ctx[\cut]   = 300; ctx[\pan] = 0;
    },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var ctr = pose[\center];
        var hi = (1 - (((hf[\ry] ? 1) + (hf[\ly] ? 1)) * 0.5)).clip(0, 1);
        var tgt = hi.linexp(0, 1, 250, 4500);
        var panT = ((ctr[\cx] ? 0.5) * 2 - 1).clip(-1, 1);
        ctx[\cut] = ctx[\cut] + ((tgt - ctx[\cut]) * 0.05);
        ctx[\pan] = ctx[\pan] + ((panT - ctx[\pan]) * 0.05);
        ctx[\drone].set(\cutoff, ctx[\cut], \pan, ctx[\pan]);
    },
    tick: { |ctx, pose, beat|
        if(((beat % (0.5 / ~ccCtlDur).round.max(1)) == 0) and: { pose[\hasBody] }) {
            Synth(\cc_drift_kick, [\amp, 0.5]);
        };
    },
    stop: { |ctx|
        ctx[\drone] !? { |s| s.set(\gate, 0) };
        ctx[\sub]   !? { |s| s.set(\gate, 0) };
    },
));
"[morceau] Hypno Drift loaded".postln;
)
