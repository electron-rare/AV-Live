// kick dur sature + rumble + perc. vitesse -> intensite/disto kick + rumble ;
// main G -> highpass ; position cx -> couche perc.
(
SynthDef(\cc_pump_kick, { |out=0, amp=0.8, drive=2|
    var env = EnvGen.kr(Env.perc(0.001, 0.32), doneAction: 2);
    var fenv = EnvGen.kr(Env([180, 44], [0.06], \exp));
    var sig = SinOsc.ar(fenv) * env;
    sig = (sig * drive.clip(1, 6)).tanh;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_pump_rumble, { |out=0, amp=0.0, gate=1|
    var sig = BPF.ar(PinkNoise.ar, 60, 0.5) * 4;
    sig = sig + SinOsc.ar(40) * 0.3;
    sig = sig * EnvGen.kr(Env.asr(0.5, 1, 0.5), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp.lag(0.3));
}).add;
SynthDef(\cc_pump_perc, { |out=0, amp=0.2, pan=0, hp=2000|
    var env = EnvGen.kr(Env.perc(0.001, 0.09), doneAction: 2);
    var sig = HPF.ar(GrayNoise.ar, hp.clip(500, 9000)) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;

~concertAdd.((
    name: "Hard Pump", style: \hard,
    start: { |ctx| ctx[\rumble] = Synth(\cc_pump_rumble, [\amp, 0.0]); },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var speed = (pose[\kin][\speed] ? 0);
        ctx[\drive] = speed.linlin(0, 0.6, 1.5, 5);
        ctx[\hp] = (hf[\ly] ? 0.5).clip(0, 1).linexp(0, 1, 800, 6000);
        ctx[\rumble].set(\amp, speed.linlin(0, 0.6, 0.05, 0.22));
        ctx[\cx] = (pose[\center][\cx] ? 0.5);
    },
    tick: { |ctx, pose, beat|
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        var eighth = (0.5 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_pump_kick, [\amp, 0.8, \drive, (ctx[\drive] ? 2)]) };
            if((beat % eighth) == (eighth div: 2)) {
                Synth(\cc_pump_perc, [\amp, 0.18, \pan, ((ctx[\cx] ? 0.5) * 2 - 1), \hp, (ctx[\hp] ? 2000)]);
            };
        };
    },
    stop: { |ctx| ctx[\rumble] !? { |s| s.set(\gate, 0) } },
));
"[morceau] Hard Pump loaded".postln;
)
