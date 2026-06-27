// 303 resonante + slide + kick. main D hauteur -> cutoff, ouverture -> reso,
// main G -> octave/accent, vitesse -> tempo (set sur ~concert[\clock]).
(
SynthDef(\cc_acid_303, { |out=0, freq=55, cutoff=600, res=0.3, amp=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.22), doneAction: 2);
    var fenv = EnvGen.kr(Env([cutoff * 2.5, cutoff], [0.12], \exp)).clip(80, 6000);
    var sig = Saw.ar(freq.clip(20, 440) * SinOsc.kr(0).range(1, 1));
    sig = RLPF.ar(sig, fenv, res.clip(0.05, 0.9).linlin(0.05, 0.9, 0.6, 0.08));
    sig = (sig * env * 2).tanh;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_acid_kick, { |out=0, amp=0.6|
    var env = EnvGen.kr(Env.perc(0.001, 0.3), doneAction: 2);
    var sig = SinOsc.ar(EnvGen.kr(Env([130, 45], [0.07], \exp))) * env;
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp);
}).add;

~concertAdd.((
    name: "Acid Line", style: \acid,
    start: { |ctx|
        // scale-DEGREE phrases (read via ~ccNote); picked by ~ccHarmony[\phrase]
        ctx[\phrases] = [
            [0, 0, 7, 0, 2, 0, 4, 0],
            [0, 3, 0, 7, 5, 0, 2, 0],
            [0, 7, 3, 10, 0, 5, 2, 0],
            [0, 0, 0, 5, 7, 7, 4, 2]
        ];
        ctx[\pat] = ctx[\phrases][0];
        ctx[\step] = 0;
    },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var speed = (pose[\kin][\speed] ? 0);
        ctx[\cut] = (1 - (hf[\ry] ? 1)).clip(0, 1).linexp(0, 1, 200, 4000);
        ctx[\res] = (hf[\ropen] ? 0.3).clip(0, 1);
        ctx[\oct] = ((hf[\ly] ? 0.5) < 0.4).if({ 1 }, { 0 });   // octave up
        ~concert[\clock] !? { |c| c.tempo = speed.linlin(0, 0.6, 124, 140).clip(124, 140) / 60 };
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        ctx[\pat] = ctx[\phrases].wrapAt(~ccHarmony[\phrase] ? 0);   // melodic-phrase gesture
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_acid_kick, [\amp, 0.6]) };
            if((beat % sixteenth) == 0) {
                var deg = ctx[\pat].wrapAt(ctx[\step]);
                var note = ~ccNote.(deg, (ctx[\oct] ? 0));
                Synth(\cc_acid_303, [\freq, note.midicps,
                    \cutoff, (ctx[\cut] ? 600), \res, (ctx[\res] ? 0.3),
                    \amp, 0.28, \pan, 0.15.rand2]);
                ctx[\step] = ctx[\step] + 1;
            };
        };
    },
    stop: { |ctx| ~concert[\clock] !? { |c| c.tempo = 126/60 } },
));
"[morceau] Acid Line loaded".postln;
)
