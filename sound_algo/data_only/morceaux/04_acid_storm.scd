// 303 saturee + kick dur + bruit. controles acid + vitesse main D -> drive ;
// deux bras hauts -> screech/fill.
(
SynthDef(\cc_storm_303, { |out=0, freq=55, cutoff=800, res=0.4, drive=2, amp=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.004, 0.2), doneAction: 2);
    var fenv = EnvGen.kr(Env([cutoff * 3, cutoff], [0.1], \exp)).clip(80, 7000);
    var sig = Saw.ar(freq.clip(20, 440));
    sig = RLPF.ar(sig, fenv, res.clip(0.05, 0.9).linlin(0.05, 0.9, 0.5, 0.06));
    sig = (sig * env * drive.clip(1, 8)).tanh;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_storm_kick, { |out=0, amp=0.7|
    var env = EnvGen.kr(Env.perc(0.001, 0.28), doneAction: 2);
    var sig = SinOsc.ar(EnvGen.kr(Env([150, 48], [0.05], \exp))) * env;
    sig = (sig * 1.5).tanh;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_storm_screech, { |out=0, amp=0.2|
    var env = EnvGen.kr(Env.perc(0.01, 0.6), doneAction: 2);
    var sig = RHPF.ar(Saw.ar(LFNoise1.kr(8).exprange(800, 4000)), 3000, 0.1);
    Out.ar(out, Pan2.ar(sig * env, 0) * amp);
}).add;

~concertAdd.((
    name: "Acid Storm", style: \acid,
    start: { |ctx|
        // scale-DEGREE phrases (read via ~ccNote); picked by ~ccHarmony[\phrase]
        ctx[\phrases] = [
            [0, 7, 0, 2, 6, 0, 4, 3],
            [0, 0, 7, 5, 0, 3, 7, 2],
            [0, 7, 10, 4, 0, 7, 3, 5],
            [0, 5, 7, 0, 9, 7, 4, 2]
        ];
        ctx[\pat] = ctx[\phrases][0]; ctx[\step] = 0; ctx[\screeched] = 0;
    },
    update: { |ctx, pose|
        var hf = pose[\hands];
        ctx[\cut] = (1 - (hf[\ry] ? 1)).clip(0, 1).linexp(0, 1, 250, 5000);
        ctx[\res] = (hf[\ropen] ? 0.4).clip(0, 1);
        ctx[\drive] = (hf[\rspeed] ? 0).clip(0, 0.6).linlin(0, 0.6, 1.5, 6);
        // deux bras hauts (ry et ly tres petits) -> screech, une fois par montee
        if(((hf[\ry] ? 1) < 0.18) and: { (hf[\ly] ? 1) < 0.18 }) {
            if(ctx[\screeched] == 0) { Synth(\cc_storm_screech, [\amp, 0.18]); ctx[\screeched] = 1 };
        } { ctx[\screeched] = 0 };
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        ctx[\pat] = ctx[\phrases].wrapAt(~ccHarmony[\phrase] ? 0);   // melodic-phrase gesture
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_storm_kick, [\amp, 0.7]) };
            if((beat % sixteenth) == 0) {
                var note = ~ccNote.(ctx[\pat].wrapAt(ctx[\step]));
                Synth(\cc_storm_303, [\freq, note.midicps, \cutoff, (ctx[\cut] ? 800),
                    \res, (ctx[\res] ? 0.4), \drive, (ctx[\drive] ? 2), \amp, 0.26, \pan, 0.2.rand2]);
                ctx[\step] = ctx[\step] + 1;
            };
        };
    },
    stop: { |ctx| },
));
"[morceau] Acid Storm loaded".postln;
)
