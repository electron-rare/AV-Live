// Launchpad: OSC-armable Pdef bank for the web control surface + the concert
// control OSC routes. Loaded LAST by boot (after concert_fx + scene_concert +
// morceaux + gestures), so ~ccNote/~ccHarmony/~ccMaster/~ccFire exist; all are
// nil-guarded so this file still loads alone in tests. Patterns play on
// ~lp[\clock] and route Out.ar(0) through the FX rack.
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

s.sync;

~lp = ~lp ? ();
~lp[\clock] = ~lp[\clock] ? TempoClock(126/60).permanent_(true);
~lp[\armed] = ~lp[\armed] ? Set.new;

Pdef(\lp_kick, Pbind(\instrument, \lp_kick, \dur, 1, \amp, 0.9));
Pdef(\lp_hats, Pbind(\instrument, \lp_hat, \dur, Pseq([Rest(0.5), 0.5], inf), \amp, 0.28));
Pdef(\lp_clap, Pbind(\instrument, \lp_clap, \dur, Pseq([Rest(1), 1], inf), \amp, 0.5));
Pdef(\lp_perc, Pbind(\instrument, \lp_perc, \dur, Pseq([0.75, 0.25, 0.5, 0.5], inf),
    \freq, Pseq([420, 640, 520], inf), \amp, 0.32));

~lpArm = { |name, on|
    var nm = name.asSymbol;
    var key = ("lp_" ++ name.asString).asSymbol;
    if(Pdef.all.includesKey(key)) {
        on.if({
            Pdef(key).play(~lp[\clock], quant: 1);
            ~lp[\armed].add(nm);
        }, {
            Pdef(key).stop;
            ~lp[\armed].remove(nm);
        });
    };
};

OSCdef(\lpLaunch, { |msg|
    ~lpArm.((msg[1] ? \nil).asString, (msg[2] ? 0) > 0);
}, '/launch');
OSCdef(\lpTempo, { |msg|
    ~lp[\clock].tempo = ((msg[1] ? 126).clip(60, 200)) / 60;
}, '/launch/tempo');
OSCdef(\lpClear, { |msg|
    ~lp[\armed].copy.do { |nm| ~lpArm.(nm, false) };
}, '/launch/clear');

"[data-only/launchpad] drums + arm/tempo/clear ready".postln;
)
