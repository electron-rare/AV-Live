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

s.sync;

~lp = ~lp ? ();
~lp[\clock] = ~lp[\clock] ? TempoClock(126/60).permanent_(true);
~lp[\armed] = ~lp[\armed] ? Set.new;

Pdef(\lp_kick, Pbind(\instrument, \lp_kick, \dur, 1, \amp, 0.9));
Pdef(\lp_hats, Pbind(\instrument, \lp_hat, \dur, Pseq([Rest(0.5), 0.5], inf), \amp, 0.28));
Pdef(\lp_clap, Pbind(\instrument, \lp_clap, \dur, Pseq([Rest(1), 1], inf), \amp, 0.5));
Pdef(\lp_perc, Pbind(\instrument, \lp_perc, \dur, Pseq([0.75, 0.25, 0.5, 0.5], inf),
    \freq, Pseq([420, 640, 520], inf), \amp, 0.32));

~lpNote = { |deg, oct=0| (~ccNote.notNil).if({ ~ccNote.(deg, oct) }, { 45 + (oct*12) + ([0,2,3,5,7,8,10][deg % 7]) }) };
Pdef(\lp_sub, Pbind(\instrument, \lp_sub, \dur, 4, \freq, Pfunc { ~lpNote.(0, -1).midicps }, \amp, 0.22, \legato, 1));
Pdef(\lp_acid, Pbind(\instrument, \lp_acid, \dur, 0.25,
    \degree, Pseq([0,0,7,0,3,0,5,2], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 0).midicps },
    \cutoff, Pseq([500,900,1400,700], inf), \res, 0.32, \amp, 0.26, \pan, Pwhite(-0.2,0.2)));
Pdef(\lp_arp, Pbind(\instrument, \lp_pluck, \dur, 0.25,
    \degree, Pseq([0,2,4,7,4,2], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps }, \cutoff, 3000, \amp, 0.2, \pan, Pwhite(-0.3,0.3)));
Pdef(\lp_lead, Pbind(\instrument, \lp_pluck, \dur, Pseq([1, 0.5, 0.5, 2], inf),
    \degree, Pseq([7,5,4,0,2,4], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps }, \cutoff, 4000, \amp, 0.24));
Pdef(\lp_stab, Pbind(\instrument, \lp_pluck, \dur, Pseq([Rest(0.5), 0.5], inf),
    \freq, Pfunc { [0,2,4].collect { |d| ~lpNote.(d, 0).midicps } }, \cutoff, 2200, \amp, 0.2));
Pdef(\lp_pad, Pbind(\instrument, \lp_pad, \dur, 8,
    \freq, Pfunc { [0,2,4].collect { |d| ~lpNote.(d, 0).midicps } },
    \cutoff, Pfunc { ((~ccHarmony ? ()).at(\pad) == \bright).if({ 3200 }, { 1200 }) }, \amp, 0.3, \legato, 1));

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
