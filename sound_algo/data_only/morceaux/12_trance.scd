// Trance -- kick 4/4 + rolling offbeat bass (e-and-a 16ths) + supersaw pad chord (gate)
// + plucky lead arp + offbeat hat.
// Bras hauts (ry/ly faibles) -> ouvre filtre pad + lead ; vitesse corps -> densite arp.
// ~ccHarmony[\phrase] choisit la phrase lead ; [\pad] bright/dark -> base cutoff pad.
(
SynthDef(\cc_trance_kick, { |out=0, amp=0.55|
    var env  = EnvGen.kr(Env.perc(0.001, 0.35), doneAction: 2);
    var fenv = EnvGen.kr(Env([160, 42], [0.08], \exp));
    var sig  = SinOsc.ar(fenv) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_trance_bass, { |out=0, freq=55, amp=0.30|
    var env = EnvGen.kr(Env.perc(0.004, 0.11), doneAction: 2);
    var raw = Saw.ar(freq.clip(20, 280));
    var flt = LPF.ar(raw, (freq * 2.5).clip(80, 600));
    var sig = (flt * env * 1.6).tanh;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_trance_lead, { |out=0, freq=440, cutoff=2000, amp=0.25, pan=0|
    var env  = EnvGen.kr(Env.perc(0.003, 0.16), doneAction: 2);
    var fenv = EnvGen.kr(Env([cutoff * 2.5, cutoff], [0.06], \exp)).clip(80, 8000);
    var raw  = (Saw.ar(freq.clip(60, 2200)) + Saw.ar(freq.clip(60, 2200) * 1.007)) * 0.5;
    var sig  = RLPF.ar(raw, fenv, 0.2) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_trance_hat, { |out=0, amp=0.14, pan=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.10), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 8000) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_trance_pad, { |out=0, freq1=110, freq2=138, freq3=165, cutoff=1200, amp=0.0, gate=1|
    var detune = [1.0, 1.009, 0.991, 1.017, 0.983, 1.024, 0.976];
    var f1  = freq1.clip(40, 800);
    var f2  = freq2.clip(40, 800);
    var f3  = freq3.clip(40, 800);
    var raw = Mix.ar(Saw.ar(detune * f1) + Saw.ar(detune * f2) + Saw.ar(detune * f3)) * 0.03;
    var aeg = EnvGen.kr(Env.asr(2.0, 1, 3.0), gate, doneAction: 2);
    var sig = RLPF.ar(raw, cutoff.clip(150, 8000), 0.55) * aeg;
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(1.5));
}).add;

~concertAdd.((
    name: "Trance", style: \trance,
    start: { |ctx|
        var f1 = ~ccNote.(0, 0).midicps;
        var f2 = ~ccNote.(2, 0).midicps;
        var f3 = ~ccNote.(4, 0).midicps;
        ctx[\phrases] = [
            [0, 2, 4, 7],
            [0, 2, 3, 7],
            [0, 4, 3, 5],
            [0, 3, 5, 4]
        ];
        ctx[\pat]  = ctx[\phrases][0];
        ctx[\step] = 0;
        ctx[\cut]  = 1200.0;
        ctx[\dens] = 2;
        ctx[\pad]  = Synth(\cc_trance_pad, [\freq1, f1, \freq2, f2, \freq3, f3,
            \cutoff, 1200, \amp, 0.28]);
        ~concert[\clock] !? { |c| c.tempo = 138 / 60 };
    },
    update: { |ctx, pose|
        var hf      = pose[\hands];
        var hiAvg   = (1 - (((hf[\ry] ? 1) + (hf[\ly] ? 1)) * 0.5)).clip(0, 1);
        var pad     = (~ccHarmony[\pad] ? \dark);
        var baseCut = (pad == \bright).if({ 1800 }, { 700 });
        var tgt     = baseCut + (hiAvg * 4000);
        ctx[\cut] = (ctx[\cut] ? 1200) + ((tgt - (ctx[\cut] ? 1200)) * 0.08);
        ctx[\pad] !? { |p| p.set(\cutoff, ctx[\cut].clip(150, 8000)) };
        ctx[\dens] = ((pose[\kin][\speed] ? 0) > 0.3).if({ 1 }, { 2 });
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter   = (1.0  / ~ccCtlDur).round.max(1);
        ctx[\pat] = ctx[\phrases].wrapAt(~ccHarmony[\phrase] ? 0);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_trance_kick, [\amp, 0.55]) };
            if((beat % sixteenth == 0) and: { (beat % quarter) != 0 }) {
                Synth(\cc_trance_bass, [\freq, ~ccNote.(0, -1).midicps, \amp, 0.28]);
            };
            if((beat % (sixteenth * (ctx[\dens] ? 2))) == 0) {
                var deg = ctx[\pat].wrapAt(ctx[\step] ? 0);
                Synth(\cc_trance_lead, [\freq, ~ccNote.(deg, 0).midicps,
                    \cutoff, (ctx[\cut] ? 1800).clip(400, 6000),
                    \amp, 0.22, \pan, 0.4.rand2]);
                ctx[\step] = (ctx[\step] ? 0) + 1;
            };
            if((beat % quarter) == (quarter div: 2)) {
                Synth(\cc_trance_hat, [\amp, 0.14, \pan, 0.3.rand2]);
            };
        };
    },
    stop: { |ctx|
        ctx[\pad] !? { |s| s.set(\gate, 0) };
        ~concert[\clock] !? { |c| c.tempo = 126 / 60 };
    },
));
"[morceau] Trance loaded".postln;
)
