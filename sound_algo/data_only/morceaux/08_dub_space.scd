// minimal : sub + clics + grande reverb. profondeur (recul) -> taille reverb
// (via amp des clics, le FX rack reverbe) ; mains -> triggers sparse. Outro.
(
SynthDef(\cc_space_sub, { |out=0, freq=48, amp=0.0, gate=1|
    var sig = SinOsc.ar(freq.clip(20, 90)) + (SinOsc.ar(freq * 2) * 0.1);
    sig = sig * EnvGen.kr(Env.asr(1, 1, 2), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.8));
}).add;
SynthDef(\cc_space_click, { |out=0, amp=0.2, pan=0|
    var env = EnvGen.kr(Env.perc(0.0005, 0.04), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 5000) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;

~concertAdd.((
    name: "Dub Space", style: \dub,
    start: { |ctx| ctx[\sub] = Synth(\cc_space_sub, [\freq, 48, \amp, 0.14]); ctx[\last] = 0.0; },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var depth = (pose[\center][\depth] ? 0.5);   // grand = proche ; recul = petit
        ctx[\space] = (1 - depth.clip(0, 1));         // recul -> plus d'espace -> clics plus forts (reverb)
        if(((hf[\rspeed] ? 0) > 0.10) and: { (thisThread.seconds - ctx[\last]) > 0.5 }) {
            ctx[\last] = thisThread.seconds;
            Synth(\cc_space_click, [\amp, 0.12 + ((ctx[\space] ? 0) * 0.25), \pan, 0.6.rand2]);
        };
    },
    tick: { |ctx, pose, beat|
        var twoBars = (8.0 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody] and: { (beat % twoBars) == 0 }) {
            Synth(\cc_space_click, [\amp, 0.10, \pan, 0]);
        };
    },
    stop: { |ctx| ctx[\sub] !? { |s| s.set(\gate, 0) } },
));
"[morceau] Dub Space loaded".postln;
)
