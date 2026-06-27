// Morceau 2 -- Hypno Roll (hypnotic). Boucle 16e roulante : stab mute + kick
// tight + shaker. vitesse -> densite/energie ; main G -> sweep filtre ;
// profondeur (recul) -> reverb send (via amp du stab, le FX rack reverbe).
(
SynthDef(\cc_roll_stab, { |out=0, freq=110, cutoff=800, amp=0.2, pan=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.18), doneAction: 2);
    var sig = Pulse.ar(freq.clip(40, 800) * [1, 1.5], 0.4).sum * 0.3;
    sig = RLPF.ar(sig, cutoff.clip(200, 5000), 0.3) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_roll_kick, { |out=0, amp=0.55|
    var env = EnvGen.kr(Env.perc(0.001, 0.25), doneAction: 2);
    var sig = SinOsc.ar(EnvGen.kr(Env([110, 48], [0.06], \exp))) * env;
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp);
}).add;
SynthDef(\cc_roll_shaker, { |out=0, amp=0.12, pan=0.3|
    var env = EnvGen.kr(Env.perc(0.001, 0.06), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 6000) * env;
    Out.ar(out, Pan2.ar(sig, pan) * amp);
}).add;

~concertAdd.((
    name: "Hypno Roll", style: \hypnotic,
    start: { |ctx| ctx[\cut] = 800; },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var loT = (1 - (hf[\ly] ? 1)).clip(0, 1).linexp(0, 1, 400, 4000);  // main G hauteur
        ctx[\cut] = ctx[\cut] + ((loT - ctx[\cut]) * 0.06);
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter   = (1.0  / ~ccCtlDur).round.max(1);
        var speed = (pose[\kin][\speed] ? 0);
        var dens = speed.linlin(0, 0.6, 1, 4).round.clip(1, 4);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_roll_kick, [\amp, 0.55]) };
            if((beat % sixteenth) == 0) {
                Synth(\cc_roll_stab, [\freq, 110, \cutoff, ctx[\cut],
                    \amp, 0.16, \pan, 0.2.rand2]);
                if(dens >= 2) { Synth(\cc_roll_shaker, [\amp, 0.10, \pan, 0.3.rand2]) };
            };
            if((dens >= 3) and: { (beat % (sixteenth * 2).max(1)) == (sixteenth) }) {
                Synth(\cc_roll_shaker, [\amp, 0.08, \pan, -0.3]);
            };
        };
    },
    stop: { |ctx| },   // percussif one-shot : rien a release
));
"[morceau] Hypno Roll loaded".postln;
)
