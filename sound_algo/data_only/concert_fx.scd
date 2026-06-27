// Master event-FX layer for the concert: reuses ~doFilter (engine.scd) for the
// master lowpass, adds a beat-repeat stutter before ~doMaster, and one-shot
// event synths (crash/kick/swell). Loaded after engine.scd.
(
SynthDef(\cc_master_stutter, { |out=0, rate=8, mix=0.0|
    var sig = In.ar(out, 2);
    var trig = Impulse.kr(rate);
    var held = Latch.ar(sig, trig);   // crude beat-repeat: hold sampled blocks
    var stut = (held * 0.6) + (sig * 0.4);
    ReplaceOut.ar(out, XFade2.ar(sig, stut, (mix * 2 - 1).clip(-1, 1)));
}).add;
SynthDef(\cc_ev_crash, { |out=0, amp=0.4|
    var env = EnvGen.kr(Env.perc(0.001, 1.6), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 4000) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_ev_kick, { |out=0, amp=0.9|
    var env = EnvGen.kr(Env.perc(0.001, 0.35), doneAction: 2);
    var fenv = EnvGen.kr(Env([200, 44], [0.06], \exp));
    Out.ar(out, Pan2.ar((SinOsc.ar(fenv) * env * 2).tanh, 0) * amp);
}).add;
SynthDef(\cc_ev_swell, { |out=0, revOut, amp=0.3|
    var env = EnvGen.kr(Env([0, 1, 0], [2.5, 2.5], \sin), doneAction: 2);
    var sig = Mix(Saw.ar([110, 110.3, 220] * 1.0)) * 0.15;
    sig = RLPF.ar(sig, XLine.kr(400, 3000, 2.5), 0.3) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
    revOut !? { Out.ar(revOut, Pan2.ar(sig, 0) * amp * 0.6) };
}).add;

s.sync;
~ccStutter = nil;
~ccMaster = (
    filterTo: { |cut=20000, time=0.3| ~doFilter !? { |f| f.set(\cutoff, cut.clip(120, 20000)) } },
    dip: { ~doFilter !? { |f|
        f.set(\cutoff, 300);
        AppClock.sched(0.18, { f.set(\cutoff, 20000); nil }); } },
    stutterOn: { |dur=0.6|
        ~doMaster !? { |m|
            ~ccStutter ?? { ~ccStutter = Synth.before(m, \cc_master_stutter, [\out, 0, \mix, 0]) };
            ~ccStutter.set(\mix, 0.9, \rate, 10);
            AppClock.sched(dur, { ~ccStutter !? { |st| st.set(\mix, 0) }; nil });
        };
    },
);
~ccFire = { |kind|
    switch(kind,
        \crash, { Synth(\cc_ev_crash, [\amp, 0.4]) },
        \kick,  { Synth(\cc_ev_kick,  [\amp, 0.9]) },
        \swell, { Synth(\cc_ev_swell, [\amp, 0.3, \revOut, (~doReverbBus !? { |b| b.index })]) },
    );
};
"[data-only/concert_fx] master event-FX ready".postln;
)
