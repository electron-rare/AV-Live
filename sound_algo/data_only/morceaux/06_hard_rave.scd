// hoover/stabs + break dur + crash. main D -> stab+note ; main G hauteur ->
// transpose ; saut (accel) -> crash ; vitesse -> densite break.
(
SynthDef(\cc_rave_stab, { |out=0, freq=220, amp=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.25), doneAction: 2);
    var sig = Mix(Saw.ar(freq.clip(40, 880) * [1, 1.005, 1.5, 2])) * 0.2;
    sig = RLPF.ar(sig, 3000, 0.3) * env;
    Out.ar(out, Pan2.ar((sig * 1.5).tanh, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_rave_break, { |out=0, amp=0.25, pan=0, tone=2000|
    var env = EnvGen.kr(Env.perc(0.001, 0.12), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, tone.clip(400, 8000)) * env;
    sig = sig + (SinOsc.ar(160) * env * 0.4);
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_rave_crash, { |out=0, amp=0.3|
    var env = EnvGen.kr(Env.perc(0.001, 1.5), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 4000) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;

~concertAdd.((
    name: "Hard Rave", style: \hard,
    start: { |ctx| ctx[\last] = 0.0; ctx[\crashed] = 0; },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var accel = (pose[\kin][\accel] ? 0);
        ctx[\trans] = ((hf[\ly] ? 0.5) < 0.4).if({ 3 }, { 0 });   // left hand high -> +1 degree-third
        // saut : pic d'acceleration -> crash (anti-rebond)
        if(accel > 0.45) {
            if(ctx[\crashed] == 0) { Synth(\cc_rave_crash, [\amp, 0.3]); ctx[\crashed] = 1 };
        } { ctx[\crashed] = 0 };
        // stab au geste main D (vitesse main D)
        if(((hf[\rspeed] ? 0) > 0.18) and: { (thisThread.seconds - ctx[\last]) > 0.12 }) {
            var note = ~ccNote.([0, 4, 7].choose + (ctx[\trans] ? 0));
            ctx[\last] = thisThread.seconds;
            Synth(\cc_rave_stab, [\freq, note.midicps,
                \amp, (hf[\rspeed] ? 0).linlin(0.18, 0.6, 0.18, 0.4),
                \pan, ((hf[\rx] ? 0.5) * 2 - 1)]);
        };
    },
    tick: { |ctx, pose, beat|
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var speed = (pose[\kin][\speed] ? 0);
        var dens = speed.linlin(0, 0.6, 1, 4).round.clip(1, 4);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) {
                Synth(\cc_rave_break, [\amp, 0.3, \pan, 0, \tone, 1200]);   // beat fort
            };
            if(((beat % sixteenth) == 0) and: { dens >= 2 } and: { 0.5.coin }) {
                Synth(\cc_rave_break, [\amp, 0.18, \pan, 0.4.rand2, \tone, 3000]);
            };
        };
    },
    stop: { |ctx| },
));
"[morceau] Hard Rave loaded".postln;
)
