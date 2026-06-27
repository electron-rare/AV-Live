// Detroit -- pad chord chaud detune (triade 0/2/4, gate) + stab cordes +
// kick clean + hat offbeat. Bras D (rspeed) -> trigger stab + note ;
// bras G hauteur (ly) -> filtre chord ; ~ccHarmony[\pad] -> bright/dark cutoff.
(
SynthDef(\cc_detro_pad, { |out=0, freq1=110, freq2=138, freq3=165, cutoff=800, amp=0.0, gate=1|
    var sig = Saw.ar(freq1.clip(40, 800))           + Saw.ar(freq1.clip(40, 800) * 1.006)
            + Saw.ar(freq2.clip(40, 800))           + Saw.ar(freq2.clip(40, 800) * 1.006)
            + Saw.ar(freq3.clip(40, 800))           + Saw.ar(freq3.clip(40, 800) * 1.006);
    sig = sig * 0.10;
    sig = RLPF.ar(sig, cutoff.clip(200, 6000), 0.5);
    sig = sig * EnvGen.kr(Env.asr(1.5, 1, 2), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(1.0));
}).add;
SynthDef(\cc_detro_stab, { |out=0, freq=220, amp=0.25, pan=0|
    var env = EnvGen.kr(Env.perc(0.01, 0.35), doneAction: 2);
    var vib = SinOsc.kr(5.0) * 3.0;
    var sig = (Saw.ar(freq.clip(60, 880) + vib) + Saw.ar((freq.clip(60, 880) + vib) * 1.008)) * 0.5;
    sig = RLPF.ar(sig, 3000, 0.5) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_detro_kick, { |out=0, amp=0.6|
    var env  = EnvGen.kr(Env.perc(0.001, 0.40), doneAction: 2);
    var fenv = EnvGen.kr(Env([140, 40], [0.10], \exp));
    var sig  = SinOsc.ar(fenv) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_detro_hat, { |out=0, amp=0.15, pan=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.06), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 7000) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;

~concertAdd.((
    name: "Detroit", style: \techno,
    start: { |ctx|
        var f1 = ~ccNote.(0, 0).midicps;
        var f2 = ~ccNote.(2, 0).midicps;
        var f3 = ~ccNote.(4, 0).midicps;
        ctx[\pad]      = Synth(\cc_detro_pad, [\freq1, f1, \freq2, f2, \freq3, f3,
            \cutoff, 800, \amp, 0.18]);
        ctx[\cut]      = 800.0;
        ctx[\lastStab] = 0.0;
    },
    update: { |ctx, pose|
        var hf     = pose[\hands];
        var pad    = (~ccHarmony[\pad] ? \dark);
        var base   = (pad == \bright).if({ 900 }, { 350 });
        var lyOpen = (1 - (hf[\ly] ? 1)).clip(0, 1);
        var tgt    = base + (lyOpen * 2500);
        var rsp    = (hf[\rspeed] ? 0);
        ctx[\cut]  = ctx[\cut] + ((tgt - ctx[\cut]) * 0.07);
        ctx[\pad].set(\cutoff, ctx[\cut].clip(200, 6000));
        if(rsp > 0.15) {
            if((thisThread.seconds - (ctx[\lastStab] ? 0)) > 0.15) {
                var stabNote = ~ccNote.([0, 2, 4, 7].wrapAt(~ccHarmony[\phrase] ? 0), 1);
                ctx[\lastStab] = thisThread.seconds;
                Synth(\cc_detro_stab, [\freq, stabNote.midicps,
                    \amp, 0.22, \pan, ((hf[\rx] ? 0.5) * 2 - 1)]);
            };
        };
    },
    tick: { |ctx, pose, beat|
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        var eighth  = (0.5 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_detro_kick, [\amp, 0.60]) };
            if((beat % eighth) == (eighth div: 2)) {
                Synth(\cc_detro_hat, [\amp, 0.18, \pan, 0.3.rand2]);
            };
        };
    },
    stop: { |ctx| ctx[\pad] !? { |s| s.set(\gate, 0) } },
));
"[morceau] Detroit loaded".postln;
)
