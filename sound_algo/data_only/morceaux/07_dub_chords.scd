// accord dub filtre + delay long + sub. main D -> trigger accord ;
// mains -> feedback delay + filtre ; aere, lent.
(
SynthDef(\cc_dub_chord, { |out=0, freq=110, cutoff=1200, amp=0.3, pan=0, fb=0.6|
    var env = EnvGen.kr(Env.perc(0.01, 0.5), doneAction: 2);
    var sig = Mix(Pulse.ar(freq.clip(40, 600) * [1, 1.19, 1.5], 0.3)) * 0.2;  // ~min triad
    sig = RLPF.ar(sig, cutoff.clip(200, 5000), 0.3) * env;
    sig = sig + CombL.ar(sig, 0.8, 0.66, fb.clip(0, 0.95).linlin(0, 0.95, 1, 6));
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_dub_sub, { |out=0, freq=55, amp=0.0, gate=1|
    var sig = SinOsc.ar(freq.clip(20, 120));
    sig = sig * EnvGen.kr(Env.asr(0.3, 1, 0.5), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.4));
}).add;
SynthDef(\cc_dub_kick, { |out=0, amp=0.5|
    var env = EnvGen.kr(Env.perc(0.001, 0.35), doneAction: 2);
    var sig = SinOsc.ar(EnvGen.kr(Env([100, 45], [0.08], \exp))) * env;
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp);
}).add;

~concertAdd.((
    name: "Dub Chords", style: \dub,
    start: { |ctx|
        ctx[\sub] = Synth(\cc_dub_sub, [\freq, 41.midicps * 0 + 55, \amp, 0.16]);
        ctx[\last] = 0.0; ctx[\root] = 50;
    },
    update: { |ctx, pose|
        var hf = pose[\hands];
        ctx[\cut] = (1 - (hf[\ly] ? 1)).clip(0, 1).linexp(0, 1, 400, 3000);
        ctx[\fb]  = (hf[\ropen] ? 0.5).clip(0, 1);
        if(((hf[\rspeed] ? 0) > 0.12) and: { (thisThread.seconds - ctx[\last]) > 0.4 }) {
            var note = ctx[\root] + [0, 3, 7, 10].choose;
            ctx[\last] = thisThread.seconds;
            Synth(\cc_dub_chord, [\freq, note.midicps, \cutoff, (ctx[\cut] ? 1200),
                \fb, (ctx[\fb] ? 0.6), \amp, 0.26, \pan, 0.3.rand2]);
        };
    },
    tick: { |ctx, pose, beat|
        var halfNote = (2.0 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody] and: { (beat % halfNote) == 0 }) { Synth(\cc_dub_kick, [\amp, 0.5]) };
    },
    stop: { |ctx| ctx[\sub] !? { |s| s.set(\gate, 0) } },
));
"[morceau] Dub Chords loaded".postln;
)
