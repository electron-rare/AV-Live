// Punkcore -- drums punk rapides (kick + snare backbeat + hats 8es) +
// power chords root+quinte en croche + riff lead agressif.
// Vitesse corps -> drive distorsion + densite lead ; ropen -> ouverture filtre chord.
// Passe dans le rack FX maitre ; niveaux maittrises, le limiteur tient les pics.
(
SynthDef(\cc_punk_kick, { |out=0, amp=0.65|
    var env  = EnvGen.kr(Env.perc(0.001, 0.22), doneAction: 2);
    var fenv = EnvGen.kr(Env([130, 42], [0.06], \exp));
    var sig  = SinOsc.ar(fenv) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_punk_snare, { |out=0, amp=0.42|
    var env   = EnvGen.kr(Env.perc(0.002, 0.14), doneAction: 2);
    var body  = SinOsc.ar(200) * EnvGen.kr(Env.perc(0.001, 0.08)) * 0.4;
    var noise = HPF.ar(WhiteNoise.ar, 1200) * env;
    var sig   = (body + noise).clip2(0.8);
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_punk_hat, { |out=0, amp=0.16, pan=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.04), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 8000) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_punk_chord, { |out=0, freqR=110, freqF=165, cutoff=2500, drive=2.0, amp=0.35, pan=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.20), doneAction: 2);
    var r1  = Saw.ar(freqR.clip(40, 400));
    var r2  = Saw.ar(freqR.clip(40, 400) * 1.009);
    var f1  = Saw.ar(freqF.clip(60, 600));
    var f2  = Saw.ar(freqF.clip(60, 600) * 1.009);
    var raw = (r1 + r2 + f1 + f2) * 0.22;
    var flt = RLPF.ar(raw, cutoff.clip(200, 5000), 0.45);
    var sig = (flt * drive.clip(0.5, 6)).clip2(0.8) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_punk_lead, { |out=0, freq=440, amp=0.22, pan=0|
    var env = EnvGen.kr(Env.perc(0.003, 0.12), doneAction: 2);
    var raw = (Saw.ar(freq.clip(60, 2000)) + Saw.ar(freq.clip(60, 2000) * 1.007)) * 0.5;
    var flt = HPF.ar(raw, 300);
    var sig = (flt * 1.8).clip2(0.7) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;

~concertAdd.((
    name: "Punkcore", style: \punk,
    start: { |ctx|
        ctx[\phrases] = [
            [0, 0, 2, 0],
            [0, 0, 3, 2],
            [0, 2, 0, 3],
            [0, 3, 2, 0]
        ];
        ctx[\pat]  = ctx[\phrases][0];
        ctx[\step] = 0;
        ctx[\drv]  = 2.0;
        ctx[\cut]  = 2500.0;
        ctx[\dens] = 2;
        ~concert[\clock] !? { |c| c.tempo = 156 / 60 };
    },
    update: { |ctx, pose|
        var hf    = pose[\hands];
        var speed = (pose[\kin][\speed] ? 0);
        ctx[\drv]  = speed.linlin(0, 0.7, 1.2, 4.5).clip(0.8, 5.0);
        ctx[\cut]  = (1 - (hf[\ropen] ? 0.5)).clip(0, 1).linexp(0, 1, 600, 5000);
        ctx[\dens] = (speed > 0.4).if({ 1 }, { 2 });
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter   = (1.0  / ~ccCtlDur).round.max(1);
        var eighth    = (0.5  / ~ccCtlDur).round.max(1);
        ctx[\pat] = ctx[\phrases].wrapAt(~ccHarmony[\phrase] ? 0);
        if(pose[\hasBody]) {
            // Kick sur chaque temps
            if((beat % quarter) == 0) { Synth(\cc_punk_kick, [\amp, 0.65]) };
            // Snare backbeat : temps 2 et 4 (toutes les 2 noires, decale d'une noire)
            if((beat % (quarter * 2)) == quarter) { Synth(\cc_punk_snare, [\amp, 0.42]) };
            // Hats 8es rapides
            if((beat % eighth) == 0) { Synth(\cc_punk_hat, [\amp, 0.16, \pan, 0.2.rand2]) };
            // Power chord en croche (root+quinte)
            if((beat % eighth) == 0) {
                var rootMidi = ~ccNote.(0, 0);
                Synth(\cc_punk_chord, [
                    \freqR, rootMidi.midicps,
                    \freqF, (rootMidi + 7).midicps,
                    \cutoff, (ctx[\cut] ? 2500).clip(500, 5000),
                    \drive,  (ctx[\drv]  ? 2.0),
                    \amp, 0.30, \pan, 0]);
            };
            // Riff lead
            if((beat % (sixteenth * (ctx[\dens] ? 2))) == 0) {
                var deg = ctx[\pat].wrapAt(ctx[\step] ? 0);
                Synth(\cc_punk_lead, [\freq, ~ccNote.(deg, 1).midicps,
                    \amp, 0.18, \pan, 0.4.rand2]);
                ctx[\step] = (ctx[\step] ? 0) + 1;
            };
        };
    },
    stop: { |ctx|
        ~concert[\clock] !? { |c| c.tempo = 126 / 60 };
    },
));
"[morceau] Punkcore loaded".postln;
)
