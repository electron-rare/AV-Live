// Industrial -- stab metallique distordu (saw/pulse + BPF reso + tanh) +
// rafale bruit + kick dur + rumble gate. Vitesse corps -> drive + amp rumble ;
// ecart bras D (ropen) -> quantite bruit sur l'offbeat ; pitch stab -> ~ccNote.
(
SynthDef(\cc_indust_stab, { |out=0, freq=220, drive=2.5, amp=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.003, 0.20), doneAction: 2);
    var sig = (Saw.ar(freq.clip(40, 880)) + (Pulse.ar(freq.clip(40, 880) * 0.5, 0.4) * 0.5)) * 0.4;
    sig = BPF.ar(sig, (freq.clip(40, 880) * 2.0).clip(80, 8000), 0.4) * 3.0;
    sig = (sig * drive.clip(1.0, 6.0)).tanh;
    sig = sig * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_indust_noise, { |out=0, amp=0.2, pan=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.08), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 4000) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_indust_kick, { |out=0, amp=0.7|
    var env  = EnvGen.kr(Env.perc(0.001, 0.30), doneAction: 2);
    var fenv = EnvGen.kr(Env([160, 40], [0.06], \exp));
    var sig  = (SinOsc.ar(fenv) * env * 3.0).tanh;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_indust_rumble, { |out=0, amp=0.0, gate=1|
    var sig = (BPF.ar(PinkNoise.ar, 55, 0.4) * 5.0) + (SinOsc.ar(38) * 0.3);
    sig = sig.tanh;
    sig = sig * EnvGen.kr(Env.asr(0.4, 1, 0.4), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.3));
}).add;

~concertAdd.((
    name: "Industrial", style: \industrial,
    start: { |ctx|
        ctx[\rumble]   = Synth(\cc_indust_rumble, [\amp, 0.0]);
        ctx[\drive]    = 2.0;
        ctx[\noiseAmt] = 0.0;
        ctx[\stabDeg]  = 0;
    },
    update: { |ctx, pose|
        var hf    = pose[\hands];
        var speed = (pose[\kin][\speed] ? 0);
        ctx[\drive]    = speed.linlin(0, 0.6, 1.5, 5.5);
        ctx[\noiseAmt] = (hf[\ropen] ? 0.5);
        ctx[\stabDeg]  = [0, 0, 3, 5].wrapAt(~ccHarmony[\phrase] ? 0);
        ctx[\rumble].set(\amp, speed.linlin(0, 0.6, 0.0, 0.28));
    },
    tick: { |ctx, pose, beat|
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        var half    = (2.0 / ~ccCtlDur).round.max(1);
        var eighth  = (0.5 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) {
                Synth(\cc_indust_kick, [\amp, 0.70]);
            };
            if((beat % half) == 0) {
                var note = ~ccNote.(ctx[\stabDeg] ? 0, 0);
                Synth(\cc_indust_stab, [\freq, note.midicps,
                    \drive, (ctx[\drive] ? 2.0).clip(1.0, 6.0),
                    \amp, 0.32, \pan, 0.2.rand2]);
            };
            if(((beat % eighth) == (eighth div: 2)) and: { (ctx[\noiseAmt] ? 0) > 0.3 }) {
                Synth(\cc_indust_noise, [\amp, (ctx[\noiseAmt] ? 0) * 0.40, \pan, 0.5.rand2]);
            };
        };
    },
    stop: { |ctx| ctx[\rumble] !? { |s| s.set(\gate, 0) } },
));
"[morceau] Industrial loaded".postln;
)
