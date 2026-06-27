// Trance Pluck -- arpege 16e plucky hypnotique + sub gate + kick soft.
// Bras hauts (ry/ly) -> ouvre le filtre pluck ; vitesse corps -> densite arp
// (16e a haute vitesse, 8e a basse vitesse). ~ccHarmony[\phrase] choisit la phrase.
(
SynthDef(\cc_pluck_pluck, { |out=0, freq=440, cutoff=2000, amp=0.3, pan=0|
    var env  = EnvGen.kr(Env.perc(0.002, 0.18), doneAction: 2);
    var fenv = EnvGen.kr(Env([cutoff * 3.0, cutoff], [0.05], \exp)).clip(80, 8000);
    var sig  = (Saw.ar(freq.clip(50, 1200)) + Saw.ar(freq.clip(50, 1200) * 1.007)) * 0.5;
    sig = RLPF.ar(sig, fenv, 0.25);
    sig = sig * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_pluck_sub, { |out=0, freq=55, amp=0.0, gate=1|
    var sig = SinOsc.ar(freq.clip(20, 100));
    sig = sig * EnvGen.kr(Env.asr(0.3, 1, 0.5), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.3));
}).add;
SynthDef(\cc_pluck_kick, { |out=0, amp=0.5|
    var env  = EnvGen.kr(Env.perc(0.001, 0.28), doneAction: 2);
    var fenv = EnvGen.kr(Env([150, 45], [0.07], \exp));
    var sig  = SinOsc.ar(fenv) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;

~concertAdd.((
    name: "Trance Pluck", style: \trance,
    start: { |ctx|
        ctx[\phrases] = [
            [0, 2, 3, 5],
            [0, 2, 4, 7],
            [0, 3, 5, 7],
            [0, 2, 3, 7]
        ];
        ctx[\pat]  = ctx[\phrases][0];
        ctx[\step] = 0;
        ctx[\cut]  = 1800;
        ctx[\dens] = 2;
        ctx[\sub]  = Synth(\cc_pluck_sub, [\freq, ~ccNote.(0, -1).midicps, \amp, 0.20]);
    },
    update: { |ctx, pose|
        var hf     = pose[\hands];
        var hiAvg  = (1 - (((hf[\ry] ? 1) + (hf[\ly] ? 1)) * 0.5)).clip(0, 1);
        ctx[\cut]  = hiAvg.linexp(0, 1, 400, 5000);
        ctx[\dens] = ((pose[\kin][\speed] ? 0) > 0.3).if({ 1 }, { 2 });
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter   = (1.0  / ~ccCtlDur).round.max(1);
        ctx[\pat] = ctx[\phrases].wrapAt(~ccHarmony[\phrase] ? 0);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_pluck_kick, [\amp, 0.55]) };
            if((beat % sixteenth) == 0) {
                if(((ctx[\step] ? 0) % (ctx[\dens] ? 2)) == 0) {
                    var deg  = ctx[\pat].wrapAt(ctx[\step] ? 0);
                    var note = ~ccNote.(deg, 0);
                    Synth(\cc_pluck_pluck, [\freq, note.midicps,
                        \cutoff, (ctx[\cut] ? 1800).clip(200, 6000),
                        \amp, 0.28, \pan, 0.3.rand2]);
                };
                ctx[\step] = (ctx[\step] ? 0) + 1;
            };
        };
    },
    stop: { |ctx| ctx[\sub] !? { |s| s.set(\gate, 0) } },
));
"[morceau] Trance Pluck loaded".postln;
)
