// Psytrance -- kick sur le temps + rolling bass sur les 3 16es OFF-kick (e-and-a)
// + acid lead squelchy RLPF + zaps psy occasionnels.
// Vitesse corps -> resonance acid ; ropen -> taux de zaps.
// Definitoire : bass CLAIREMENT entre les kicks (interlock kick+bass = rolling).
(
SynthDef(\cc_psy_kick, { |out=0, amp=0.62|
    var env  = EnvGen.kr(Env.perc(0.001, 0.32), doneAction: 2);
    var fenv = EnvGen.kr(Env([150, 40], [0.08], \exp));
    var sig  = SinOsc.ar(fenv) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_psy_bass, { |out=0, freq=55, amp=0.32|
    var env = EnvGen.kr(Env.perc(0.003, 0.09), doneAction: 2);
    var raw = Saw.ar(freq.clip(20, 150)) + SinOsc.ar(freq.clip(20, 150));
    var flt = LPF.ar(raw * 0.5, (freq * 3).clip(100, 600));
    var sig = (flt * env).tanh;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_psy_acid, { |out=0, freq=110, cutoff=800, res=0.25, amp=0.28, pan=0|
    var env  = EnvGen.kr(Env.perc(0.005, 0.20), doneAction: 2);
    var fenv = EnvGen.kr(Env([cutoff * 2.0, cutoff * 0.7], [0.12], \exp)).clip(80, 5000);
    var sig  = Saw.ar(freq.clip(30, 880));
    var rq   = res.clip(0.05, 0.5).linlin(0.05, 0.5, 0.6, 0.05);
    var flt  = RLPF.ar(sig, fenv, rq);
    var out2 = (flt * env * 2.5).tanh;
    Out.ar(out, Pan2.ar(out2, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_psy_zap, { |out=0, freq=440, amp=0.18, pan=0|
    var env  = EnvGen.kr(Env.perc(0.001, 0.08), doneAction: 2);
    var fenv = EnvGen.kr(Env([freq * 4, freq * 0.5], [0.05], \exp)).clip(80, 8000);
    var sig  = (SinOsc.ar(fenv) + (HPF.ar(WhiteNoise.ar, 3000) * 0.3)) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;

~concertAdd.((
    name: "Psytrance", style: \psy,
    start: { |ctx|
        ctx[\phrases] = [
            [0, 0, 2, 0, 4, 0, 3, 0],
            [0, 3, 0, 5, 0, 2, 0, 4],
            [0, 0, 7, 0, 5, 0, 3, 0],
            [0, 2, 0, 4, 0, 5, 0, 7]
        ];
        ctx[\pat]     = ctx[\phrases][0];
        ctx[\step]    = 0;
        ctx[\cut]     = 800.0;
        ctx[\res]     = 0.25;
        ctx[\zapRate] = 16;
        ~concert[\clock] !? { |c| c.tempo = 145 / 60 };
    },
    update: { |ctx, pose|
        var hf    = pose[\hands];
        var speed = (pose[\kin][\speed] ? 0);
        ctx[\cut]     = speed.linexp(0, 0.7, 300, 3500).clip(200, 4000);
        ctx[\res]     = (hf[\ropen] ? 0.5).clip(0, 1).linlin(0, 1, 0.08, 0.45);
        ctx[\zapRate] = ((hf[\ropen] ? 0.5) > 0.65).if({ 8 }, { 24 });
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter   = (1.0  / ~ccCtlDur).round.max(1);
        ctx[\pat] = ctx[\phrases].wrapAt(~ccHarmony[\phrase] ? 0);
        if(pose[\hasBody]) {
            // Kick sur le temps (4/4)
            if((beat % quarter) == 0) { Synth(\cc_psy_kick, [\amp, 0.62]) };
            // Rolling bass : les 3 16es OFF-kick (interlock)
            if((beat % sixteenth == 0) and: { (beat % quarter) != 0 }) {
                Synth(\cc_psy_bass, [\freq, ~ccNote.(0, -1).midicps, \amp, 0.28]);
            };
            // Acid lead 16e
            if((beat % sixteenth) == 0) {
                var deg = ctx[\pat].wrapAt(ctx[\step] ? 0);
                Synth(\cc_psy_acid, [\freq, ~ccNote.(deg, 0).midicps,
                    \cutoff, (ctx[\cut] ? 800).clip(200, 4000),
                    \res,    (ctx[\res] ? 0.25).clip(0.05, 0.5),
                    \amp, 0.24, \pan, 0.25.rand2]);
                ctx[\step] = (ctx[\step] ? 0) + 1;
            };
            // Zap/blip psy occasionnel
            if((beat % (quarter * (ctx[\zapRate] ? 16))) == 0) {
                var deg = [0, 2, 4, 7].choose;
                Synth(\cc_psy_zap, [\freq, ~ccNote.(deg, 1).midicps,
                    \amp, 0.16, \pan, 0.5.rand2]);
            };
        };
    },
    stop: { |ctx|
        ~concert[\clock] !? { |c| c.tempo = 126 / 60 };
    },
));
"[morceau] Psytrance loaded".postln;
)
