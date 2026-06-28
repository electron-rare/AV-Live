// Launchpad: OSC-armable Pdef bank for the web control surface + the concert
// control OSC routes. Loaded LAST by boot (after concert_fx + scene_concert +
// morceaux + gestures), so ~ccNote/~ccHarmony/~ccMaster/~ccFire exist; all are
// nil-guarded so this file still loads alone in tests. Patterns play on
// ~lpClock.value (concert clock when running, else ~lp[\clock]) and route
// Out.ar(0) through the FX rack.
(
SynthDef(\lp_kick, { |out=0, amp=0.9|
    var env = EnvGen.kr(Env.perc(0.001, 0.32), doneAction: 2);
    var fenv = EnvGen.kr(Env([180, 45], [0.06], \exp));
    Out.ar(out, Pan2.ar((SinOsc.ar(fenv) * env * 2).tanh, 0) * amp);
}).add;
SynthDef(\lp_hat, { |out=0, amp=0.3|
    var env = EnvGen.kr(Env.perc(0.001, 0.045), doneAction: 2);
    Out.ar(out, Pan2.ar(HPF.ar(WhiteNoise.ar, 8000) * env, 0) * amp);
}).add;
SynthDef(\lp_clap, { |out=0, amp=0.5|
    var env = EnvGen.kr(Env.perc(0.004, 0.18), doneAction: 2);
    Out.ar(out, Pan2.ar(BPF.ar(WhiteNoise.ar, 1500, 0.6) * env, 0) * amp);
}).add;
SynthDef(\lp_perc, { |out=0, amp=0.4, freq=420|
    var env = EnvGen.kr(Env.perc(0.001, 0.12), doneAction: 2);
    Out.ar(out, Pan2.ar(RLPF.ar(Saw.ar(freq.clip(80,2000)), (freq*3).clip(200,8000), 0.3) * env, 0.3) * amp);
}).add;

SynthDef(\lp_sub, { |out=0, freq=55, amp=0.0, gate=1|
    var sig = SinOsc.ar(freq.clip(20, 120)) * 0.9 + (Saw.ar(freq.clip(20,120)) * 0.1);
    sig = sig * EnvGen.kr(Env.asr(0.05, 1, 0.3), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.1));
}).add;
SynthDef(\lp_acid, { |out=0, freq=110, amp=0.3, cutoff=800, res=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.22), doneAction: 2);
    var sig = Saw.ar(freq.clip(30, 1200));
    sig = RLPF.ar(sig, (cutoff * (1 + (env*2))).clip(80, 6000), res.clip(0.05, 0.9));
    Out.ar(out, Pan2.ar(sig.tanh * env, pan.clip(-1,1)) * amp);
}).add;
SynthDef(\lp_pluck, { |out=0, freq=220, amp=0.3, cutoff=2500, pan=0|
    var env = EnvGen.kr(Env.perc(0.002, 0.25), doneAction: 2);
    var sig = RLPF.ar(Saw.ar(freq.clip(40,2000) * [1, 1.005]), cutoff.clip(200,8000), 0.4);
    Out.ar(out, Pan2.ar(Mix(sig) * env, pan.clip(-1,1)) * amp);
}).add;
SynthDef(\lp_pad, { |out=0, freq=220, amp=0.0, cutoff=1500, gate=1|
    var sig = Mix(Saw.ar(freq.clip(40,1000) * [0.99, 1.0, 1.008, 2.0]));
    sig = RLPF.ar(sig, cutoff.clip(200,6000), 0.4);
    sig = sig * EnvGen.kr(Env.asr(1.5, 1, 2.0), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.5) * 0.25);
}).add;

// --- new drums ---
SynthDef(\lp_ride, { |out=0, amp=0.25|
    var env   = EnvGen.kr(Env.perc(0.001, 0.42), doneAction: 2);
    var noise = HPF.ar(WhiteNoise.ar, 7000) * env;
    var ring  = Ringz.ar(Impulse.ar(0), 3100, 0.08) * 0.35;
    Out.ar(out, Pan2.ar((noise + ring) * amp, 0));
}).add;
SynthDef(\lp_rim, { |out=0, amp=0.35|
    var env = EnvGen.kr(Env.perc(0.001, 0.055), doneAction: 2);
    var sig = (BPF.ar(WhiteNoise.ar, 2000, 0.8) + (SinOsc.ar(400) * 0.4)).tanh;
    Out.ar(out, Pan2.ar(sig * env * amp, 0));
}).add;
SynthDef(\lp_tom, { |out=0, amp=0.4, freq=160|
    var fenv = EnvGen.kr(Env([freq, freq * 0.5], [0.07], \exp));
    var env  = EnvGen.kr(Env.perc(0.003, 0.26), doneAction: 2);
    Out.ar(out, Pan2.ar(SinOsc.ar(fenv.clip(30, 600)) * env * amp, 0));
}).add;

// --- new pitched / textural ---
SynthDef(\lp_reese, { |out=0, freq=55, amp=0.0, gate=1|
    var move = LFNoise2.kr(0.4).range(0.88, 1.12);
    var sig  = Mix(Saw.ar(freq.clip(20, 200) * [0.999, 1.0, 1.013]));
    sig = RLPF.ar(sig, (freq.clip(20, 200) * 5 * move).clip(80, 3000), 0.35);
    sig = sig * EnvGen.kr(Env.asr(0.05, 1, 0.2), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.1));
}).add;
SynthDef(\lp_bells, { |out=0, freq=440, amp=0.3|
    var env = EnvGen.kr(Env.perc(0.001, 1.8, curve: -4), doneAction: 2);
    var f   = freq.clip(200, 4000);
    var sig = (SinOsc.ar(f)       * 0.55) +
              (SinOsc.ar(f * 2.0) * 0.28) +
              (SinOsc.ar(f * 3.0) * 0.12) +
              (SinOsc.ar(f * 4.1) * 0.05);
    Out.ar(out, Pan2.ar(sig * env * amp, 0));
}).add;
SynthDef(\lp_sweep, { |out=0, amp=0.0, gate=1|
    var env    = EnvGen.kr(Env.asr(3.0, 1, 2.0), gate, doneAction: 2);
    var cutoff = EnvGen.kr(Env([200, 6000], [10.0], \exp));
    var sig    = RLPF.ar(WhiteNoise.ar, cutoff.clip(80, 14000), 0.12);
    Out.ar(out, Pan2.ar(sig * env * amp.lag(0.5) * 0.6, 0));
}).add;

s.sync;

~lp = ~lp ? ();
~lp[\clock] = ~lp[\clock] ? TempoClock(126/60).permanent_(true);
~lp[\armed] = ~lp[\armed] ? Set.new;
~lp[\vol]       = ~lp[\vol]       ? IdentityDictionary.new;
~lp[\quant]     = ~lp[\quant]     ? 4;
~lp[\clipState] = ~lp[\clipState] ? IdentityDictionary.new;
~lp[\clipGen]   = ~lp[\clipGen]   ? IdentityDictionary.new;

// melody sequences: 8 varied riffs/arps/phrases, minor/phrygian feel
// wrapAt allows different lengths to loop cleanly over 16 16th-note steps
~lp[\melodies] = ~lp[\melodies] ? [
    [0, 2, 3, 5, 7, 5, 3, 2],
    [0, 3, 7, 3, 0, -2],
    [0, 0, 7, 0, 3, 5, 2, 0, 3, 5, 7, 3],
    [7, 5, 3, 2, 0, -2, 0, 2],
    [0, 2, 3, 5, 7, 10, 7, 5, 3, 0, 2, 3, 5, 3, 2, 0],
    [0, 3, 7],
    [0, 7, 5, 3, 7, 0],
    [2, 0, -2, 0, 3, 2, 0, -2, 5, 3, 2, 0],
];
~lp[\melSel]  = ~lp[\melSel]  ? 0;

// rhythm patterns: 16-step strings (1=hit, 0=rest) for kick / snare / hat
~lp[\rhythms] = ~lp[\rhythms] ? [
    (name: "4floor",     k: "1000100010001000", s: "0000100000001000", h: "0010101010101010"),
    (name: "breakbeat",  k: "1000101010001000", s: "0000100100001001", h: "0101010101010101"),
    (name: "halftime",   k: "1000000010000000", s: "0000000000001000", h: "0010001001000010"),
    (name: "psyroll",    k: "1001100110011001", s: "0000100000001000", h: "1111111111111111"),
    (name: "garage",     k: "1000001010000010", s: "0000100000001000", h: "0101101001011010"),
    (name: "tribal",     k: "1010100010101000", s: "0000101000001010", h: "1010101010101010"),
    (name: "industrial", k: "1100110011001100", s: "0011001100110011", h: "0101010101010101"),
    (name: "jungle",     k: "1000100110001001", s: "0000100100001001", h: "1011101110111011"),
];
~lp[\rhySel]  = ~lp[\rhySel]  ? 0;

// clock-sync helper: use concert clock when concert is running
~lpClock = {
    (~concert.notNil and: {
        (~concert[\running] == true) and: { ~concert[\clock].notNil }
    }).if({ ~concert[\clock] }, { ~lp[\clock] })
};

// per-pattern volume (default 0.8, max 1.5)
~lpVol = { |nm| (~lp[\vol][nm] ? 0.8).clip(0, 1.5) };

// note helper (nil-guards ~ccNote)
~lpNote = { |deg, oct=0|
    ~ccNote.notNil.if({ ~ccNote.(deg, oct) }, { ~noteFor.(deg, \minor, 45, oct) })
};

// --- 10 original Pdefs (all \amp wrapped with ~lpVol) ---
Pdef(\lp_kick, Pbind(\instrument, \lp_kick, \dur, 1,
    \amp, Pfunc { 0.9 * ~lpVol.(\kick) }));
Pdef(\lp_hats, Pbind(\instrument, \lp_hat, \dur, Pseq([Rest(0.5), 0.5], inf),
    \amp, Pfunc { 0.28 * ~lpVol.(\hats) }));
Pdef(\lp_clap, Pbind(\instrument, \lp_clap, \dur, Pseq([Rest(1), 1], inf),
    \amp, Pfunc { 0.5 * ~lpVol.(\clap) }));
Pdef(\lp_perc, Pbind(\instrument, \lp_perc,
    \dur, Pseq([0.75, 0.25, 0.5, 0.5], inf),
    \freq, Pseq([420, 640, 520], inf),
    \amp, Pfunc { 0.32 * ~lpVol.(\perc) }));

Pdef(\lp_sub, Pbind(\instrument, \lp_sub, \dur, 4,
    \freq, Pfunc { ~lpNote.(0, -1).midicps },
    \amp, Pfunc { 0.22 * ~lpVol.(\sub) }, \legato, 1));
Pdef(\lp_acid, Pbind(\instrument, \lp_acid, \dur, 0.25,
    \degree, Pseq([0,0,7,0,3,0,5,2], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 0).midicps },
    \cutoff, Pseq([500,900,1400,700], inf), \res, 0.32,
    \amp, Pfunc { 0.26 * ~lpVol.(\acid) }, \pan, Pwhite(-0.2,0.2)));
Pdef(\lp_arp, Pbind(\instrument, \lp_pluck, \dur, 0.25,
    \degree, Pseq([0,2,4,7,4,2], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps },
    \cutoff, 3000, \amp, Pfunc { 0.2 * ~lpVol.(\arp) }, \pan, Pwhite(-0.3,0.3)));
Pdef(\lp_lead, Pbind(\instrument, \lp_pluck, \dur, Pseq([1, 0.5, 0.5, 2], inf),
    \degree, Pseq([7,5,4,0,2,4], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps },
    \cutoff, 4000, \amp, Pfunc { 0.24 * ~lpVol.(\lead) }));
Pdef(\lp_stab, Pbind(\instrument, \lp_pluck, \dur, Pseq([Rest(0.5), 0.5], inf),
    \freq, Pfunc { [0,2,4].collect { |d| ~lpNote.(d, 0).midicps } },
    \cutoff, 2200, \amp, Pfunc { 0.2 * ~lpVol.(\stab) }));
Pdef(\lp_pad, Pbind(\instrument, \lp_pad, \dur, 8,
    \freq, Pfunc { [0,2,4].collect { |d| ~lpNote.(d, 0).midicps } },
    \cutoff, Pfunc { ((~ccHarmony ? ()).at(\pad) == \bright).if({ 3200 }, { 1200 }) },
    \amp, Pfunc { 0.3 * ~lpVol.(\pad) }, \legato, 1));

// --- 6 new Pdefs ---
Pdef(\lp_ride, Pbind(\instrument, \lp_ride,
    \dur, Pseq([0.5, 0.5, 0.5, Rest(0.5)], inf),
    \amp, Pfunc { 0.25 * ~lpVol.(\ride) }));
Pdef(\lp_rim, Pbind(\instrument, \lp_rim,
    \dur, Pseq([Rest(1), 0.5, Rest(0.5), Rest(1), 0.5, Rest(0.5)], inf),
    \amp, Pfunc { 0.35 * ~lpVol.(\rim) }));
Pdef(\lp_tom, Pbind(\instrument, \lp_tom,
    \dur, Pseq([Rest(1.5), 0.5, Rest(1), 1], inf),
    \freq, Pseq([180, 120, 160], inf),
    \amp, Pfunc { 0.4 * ~lpVol.(\tom) }));
Pdef(\lp_reese, Pbind(\instrument, \lp_reese, \dur, 8,
    \freq, Pfunc { ~lpNote.(0, -1).midicps },
    \amp, Pfunc { 0.3 * ~lpVol.(\reese) }, \legato, 1));
Pdef(\lp_bells, Pbind(\instrument, \lp_bells,
    \dur, Pseq([2, 1.5, 2.5, 2], inf),
    \degree, Pseq([0, 2, 4, 7], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 2).midicps },
    \amp, Pfunc { 0.22 * ~lpVol.(\bells) }));
Pdef(\lp_sweep, Pbind(\instrument, \lp_sweep, \dur, 8,
    \amp, Pfunc { 0.25 * ~lpVol.(\sweep) }, \legato, 1));

// --- melody sequencer: single Pdef, armed via normal /launch path ---
// reuses \lp_pluck; selects from ~lp[\melodies][~lp[\melSel]] via wrapAt
Pdef(\lp_melseq, Pbind(
    \instrument, \lp_pluck,
    \stepIdx, Pseq((0..15), inf),
    \degree, Pfunc { |e|
        var mel = ~lp[\melodies];
        var sel = ~lp[\melSel] ? 0;
        (mel.notNil and: { mel.size > 0 }).if({
            mel[sel.clip(0, mel.size - 1)].wrapAt(e[\stepIdx])
        }, { 0 })
    },
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps },
    \dur, 0.25,
    \cutoff, 3500,
    \amp, Pfunc { 0.22 * ~lpVol.(\melseq) },
    \pan, Pwhite(-0.25, 0.25)
));

// --- rhythm sub-Pdefs: 3 voices armed together via rhythmseq special-case in ~lpArm ---
// \type \rest = true rest (no synth), \type \note = hit
Pdef(\lp_rsk, Pbind(
    \instrument, \lp_kick,
    \stepIdx, Pseq((0..15), inf),
    \dur, 0.25,
    \type, Pfunc { |e|
        var pat = ~lp[\rhythms];
        var sel = ~lp[\rhySel] ? 0;
        var row;
        (pat.notNil and: { pat.size > 0 }).if({
            row = pat[sel.clip(0, pat.size - 1)].at(\k);
            (row.notNil and: { row.at(e[\stepIdx]) == $1 }).if({ \note }, { \rest })
        }, { \rest })
    },
    \amp, Pfunc { 0.9 * ~lpVol.(\rhythmseq) }
));
Pdef(\lp_rss, Pbind(
    \instrument, \lp_clap,
    \stepIdx, Pseq((0..15), inf),
    \dur, 0.25,
    \type, Pfunc { |e|
        var pat = ~lp[\rhythms];
        var sel = ~lp[\rhySel] ? 0;
        var row;
        (pat.notNil and: { pat.size > 0 }).if({
            row = pat[sel.clip(0, pat.size - 1)].at(\s);
            (row.notNil and: { row.at(e[\stepIdx]) == $1 }).if({ \note }, { \rest })
        }, { \rest })
    },
    \amp, Pfunc { 0.5 * ~lpVol.(\rhythmseq) }
));
Pdef(\lp_rsh, Pbind(
    \instrument, \lp_hat,
    \stepIdx, Pseq((0..15), inf),
    \dur, 0.25,
    \type, Pfunc { |e|
        var pat = ~lp[\rhythms];
        var sel = ~lp[\rhySel] ? 0;
        var row;
        (pat.notNil and: { pat.size > 0 }).if({
            row = pat[sel.clip(0, pat.size - 1)].at(\h);
            (row.notNil and: { row.at(e[\stepIdx]) == $1 }).if({ \note }, { \rest })
        }, { \rest })
    },
    \amp, Pfunc { 0.28 * ~lpVol.(\rhythmseq) }
));

// arm / disarm a pattern by bare name (e.g. "kick" -> Pdef(\lp_kick))
// "rhythmseq" special-cases: arms/disarms \lp_rsk, \lp_rss, \lp_rsh together
// 4-state machine per clip: 0=off, 1=playing, 2=queued-launch, 3=queued-stop
// Launch and stop are quantized to ~lp[\quant] beats on the TempoClock.
// A generation counter per clip cancels superseded pending callbacks.
~lpArm = { |name, on|
    var nm, keys, clock, q, s, gen, isRhythm;
    nm       = name.asSymbol;
    isRhythm = (name.asString == "rhythmseq");
    keys     = isRhythm.if(
        { [\lp_rsk, \lp_rss, \lp_rsh] },
        { [("lp_" ++ name.asString).asSymbol] }
    );
    (isRhythm or: { Pdef.all.includesKey(keys[0]) }).if({
        clock = ~lp[\clock] ? (~lpClock.value ? TempoClock.default);
        q     = ~lp[\quant] ? 4;
        s     = ~lp[\clipState][nm] ? 0;
        on.if({
            // launch tap
            (s == 0).if({
                gen = (~lp[\clipGen][nm] ? 0) + 1; ~lp[\clipGen][nm] = gen;
                ~lp[\clipState][nm] = 2;
                ~lp[\armed].add(nm);
                keys.do { |k| Pdef(k).play(clock, quant: q) };
                clock.schedAbs(clock.nextTimeOnGrid(q), {
                    (~lp[\clipGen][nm] == gen).if({ ~lp[\clipState][nm] = 1 });
                    nil
                });
            });
            (s == 3).if({
                gen = (~lp[\clipGen][nm] ? 0) + 1; ~lp[\clipGen][nm] = gen;
                // queued-stop cancelled: clip still playing, revert to 1
                ~lp[\clipState][nm] = 1;
                ~lp[\armed].add(nm);
            });
            // s == 1 or s == 2: no-op (pending closure preserved)
        }, {
            // stop tap
            (s == 1).if({
                gen = (~lp[\clipGen][nm] ? 0) + 1; ~lp[\clipGen][nm] = gen;
                ~lp[\clipState][nm] = 3;
                ~lp[\armed].remove(nm);
                clock.schedAbs(clock.nextTimeOnGrid(q), {
                    (~lp[\clipGen][nm] == gen).if({
                        keys.do { |k| Pdef(k).stop };
                        ~lp[\clipState][nm] = 0;
                    });
                    nil
                });
            });
            (s == 2).if({
                gen = (~lp[\clipGen][nm] ? 0) + 1; ~lp[\clipGen][nm] = gen;
                // queued-launch cancelled: stop before it fires
                keys.do { |k| Pdef(k).stop };
                ~lp[\clipState][nm] = 0;
                ~lp[\armed].remove(nm);
            });
            // s == 0 or s == 3: no-op (pending closure preserved)
        });
    });
};

OSCdef(\lpLaunch, { |msg|
    ~lpArm.((msg[1] ? \nil).asString, (msg[2] ? 0) > 0);
}, '/launch');
OSCdef(\lpTempo, { |msg|
    var t = ((msg[1] ? 126).clip(60, 200)) / 60;
    ~lp[\clock].tempo = t;
    ~concert !? { ~concert[\clock] !? { |c| c.tempo = t } };
}, '/launch/tempo');
OSCdef(\lpClear, { |msg|
    ~lp[\armed].copy.do { |nm| ~lpArm.(nm, false) };
}, '/launch/clear');
OSCdef(\lpVol, { |msg|
    ~lp[\vol][(msg[1] ? \nil).asSymbol] = (msg[2] ? 0.8).clip(0, 1.5);
}, '/launch/vol');
OSCdef(\lpQuant, { |msg|
    ~lp[\quant] = (msg[1] ? 4).asFloat.clip(0.125, 64);
}, '/launch/quant');

OSCdef(\ctlHarmRoot, { |msg|
    ~ccHarmony !? { ~ccHarmony[\root] = (~ccHarmony[\root] + (msg[1] ? 0)).clip(33, 57) };
}, '/control/harmony/root');
OSCdef(\ctlHarmScale, { |msg|
    var nm = (msg[1] ? \minor).asSymbol;
    (~ccHarmony.notNil and: { (~ccScales ? ()).includesKey(nm) }).if({ ~ccHarmony[\scale] = nm });
}, '/control/harmony/scale');
OSCdef(\ctlHarmOct, { |msg| ~ccHarmony !? { ~ccHarmony[\octave] = (msg[1] ? 0).asInteger.clip(0, 2) } }, '/control/harmony/octave');
OSCdef(\ctlHarmPhrase, { |msg| ~ccHarmony !? { ~ccHarmony[\phrase] = (msg[1] ? 0).asInteger.clip(0, 3) } }, '/control/harmony/phrase');
OSCdef(\ctlFxFilter, { |msg|
    ~ccMaster !? { ~ccMaster[\filterTo].((msg[1] ? 1).clip(0,1).linexp(0, 1, 120, 20000), 0.2) };
}, '/control/fx/filter');
OSCdef(\ctlFxStutter, { |msg| ~ccMaster !? { ~ccMaster[\stutterOn].(0.9) } }, '/control/fx/stutter');
OSCdef(\ctlFxCrash, { |msg| ~ccFire !? { ~ccFire.(\crash) } }, '/control/fx/crash');
OSCdef(\ctlFxKick, { |msg| ~ccFire !? { ~ccFire.(\kick) } }, '/control/fx/kick');
OSCdef(\ctlFxSwell, { |msg| ~ccFire !? { ~ccFire.(\swell) } }, '/control/fx/swell');
OSCdef(\ctlFxBreak, { |msg|
    ~ccMaster !? { ((msg[1] ? 0) > 0).if({ ~ccMaster[\filterTo].(450, 1.0) }, { ~ccMaster[\filterTo].(20000, 1.5) }) };
}, '/control/fx/breakdown');

OSCdef(\seqMelody, { |msg|
    ~lp.notNil.if({
        var n = (msg[1] ? 0).asInteger;
        ~lp[\melSel] = n.clip(0, ~lp[\melodies].notNil.if({ ~lp[\melodies].size - 1 }, { 0 }));
    });
}, '/seq/melody');
OSCdef(\seqRhythm, { |msg|
    ~lp.notNil.if({
        var n = (msg[1] ? 0).asInteger;
        ~lp[\rhySel] = n.clip(0, ~lp[\rhythms].notNil.if({ ~lp[\rhythms].size - 1 }, { 0 }));
    });
}, '/seq/rhythm');

OSCdef(\seqRhythmSet, { |msg|
    var sel;
    ~lp.notNil.if({
        sel = (~lp[\rhySel] ? 0).clip(0, (~lp[\rhythms].notNil.if({ ~lp[\rhythms].size - 1 }, { 0 })));
        ~lp[\rhythms][sel] = (
            name: (~lp[\rhythms][sel][\name] ? "edit"),
            k: msg[1].asString,
            s: msg[2].asString,
            h: msg[3].asString
        );
    });
}, '/seq/rhythm/set');

OSCdef(\seqMelodySet, { |msg|
    var sel, degs;
    ~lp.notNil.if({
        sel = (~lp[\melSel] ? 0).clip(0, (~lp[\melodies].notNil.if({ ~lp[\melodies].size - 1 }, { 0 })));
        (msg.size > 1).if({
            degs = (1..(msg.size - 1)).collect { |i| msg[i].asInteger };
            ~lp[\melodies][sel] = degs;
        });
    });
}, '/seq/melody/set');

"[data-only/launchpad] 16 patterns + 2 sequencers (melseq+rhythmseq) + clock-sync + vol faders ready".postln;
)
