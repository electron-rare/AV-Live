// =====================================================================
//  data_only/synthdefs.scd  --  Banque de SynthDefs du patch data-only.
//
//  Toutes les SynthDefs sont prefixees \do_* et envoient en stereo sur
//  out=0 par defaut, avec un envoi optionnel vers ~doReverbBus via le
//  parametre `rev` (0..1).
// =====================================================================
(
SynthDef(\do_drone, { |out=0, freq=7.83, amp=0.22, fm=0, pan=0, rev=0.3|
    var harm = freq * [1, 2, 3, 4, 5];
    var amps = [1, 0.5, 0.33, 0.25, 0.2];
    var sig = SinOsc.ar(harm + fm.lag(0.05), 0, amps).sum;
    sig = sig + (LFTri.ar(freq * 0.5) * 0.1);
    sig = LeakDC.ar(sig).tanh * amp;
    sig = Pan2.ar(sig, pan);
    Out.ar(out, sig);
    Out.ar(~doReverbBus, sig * rev);
}).add;

SynthDef(\do_strike, { |out=0, freq=400, amp=0.5, pan=0, dur=0.4, rev=0.6|
    var env = EnvGen.kr(Env.perc(0.001, dur), doneAction: 2);
    var sig = WhiteNoise.ar * env;
    sig = BPF.ar(sig, freq, 0.05) * 6;
    sig = sig + (SinOsc.ar(freq, 0, env * 0.5));
    sig = Pan2.ar(sig.tanh * amp, pan);
    Out.ar(out, sig);
    Out.ar(~doReverbBus, sig * rev);
}).add;

SynthDef(\do_geo, { |out=0, freq=200, amp=0.25, bw=0.4, rev=0.5|
    var sig = Mix(Saw.ar([55, 110, 165]));
    sig = BPF.ar(sig, freq.lag(0.3).clip(80, 6000), bw.lag(0.3).clip(0.05, 1));
    sig = sig * 1.5;
    sig = Splay.ar([sig, DelayN.ar(sig, 0.05, 0.03)]) * amp;
    Out.ar(out, sig);
    Out.ar(~doReverbBus, sig * rev);
}).add;

SynthDef(\do_quake_sub, { |out=0, freq=40, amp=0.7, dur=2, rev=0.2|
    var env = EnvGen.kr(Env.perc(0.05, dur, 1, -2), doneAction: 2);
    var sig = SinOsc.ar(freq) * env;
    sig = sig + (LFTri.ar(freq * 0.5) * env * 0.3);
    sig = Pan2.ar(sig.tanh * amp, 0);
    Out.ar(out, sig);
    Out.ar(~doReverbBus, sig * rev);
}).add;

SynthDef(\do_body_drone, { |out=0, freq=80, amp=0.25, cutoff=800, q=0.4, pan=0, rev=0.35|
    var sig = Saw.ar(freq * [1, 1.005, 0.503]);
    sig = RLPF.ar(sig, cutoff.lag(0.05).clip(80, 8000), q);
    sig = Pan2.ar(sig.sum * amp, pan);
    Out.ar(out, sig);
    Out.ar(~doReverbBus, sig * rev);
}).add;

SynthDef(\do_body_gran, { |out=0, dens=10, rate=1.0, amp=0.3, rev=0.5|
    var trig = Impulse.kr(dens);
    var grain = SinOsc.ar(
        TRand.kr(200, 1200, trig) * rate.lag(0.1),
        0,
        EnvGen.kr(Env.perc(0.005, 0.05), trig)
    );
    var sig = Pan2.ar(grain * amp, TRand.kr(-1, 1, trig));
    Out.ar(out, sig);
    Out.ar(~doReverbBus, sig * rev);
}).add;

// -- NOUVEAUX SynthDefs (specifiques aux scenes etendues) ----------

// "weather" : drone solaire avec phase modulation
SynthDef(\do_weather, { |out=0, freq=110, amp=0.3, mod=1.0, pan=0, rev=0.55|
    var carrier = freq;
    var modf    = freq * (mod.lag(0.5).clip(0.5, 4));
    var idx     = mod * 4;
    var sig = SinOsc.ar(carrier + (SinOsc.ar(modf) * modf * idx));
    sig = sig + (Saw.ar(carrier * 0.5) * 0.2);
    sig = Pan2.ar(sig.tanh * amp, pan);
    Out.ar(out, sig);
    Out.ar(~doReverbBus, sig * rev);
}).add;

// "flight" : voix FM polyphonique courte pour chaque avion detecte
SynthDef(\do_plane, { |out=0, freq=600, amp=0.18, pan=0, modIdx=2, dur=1.5, rev=0.7|
    var env = EnvGen.kr(Env.perc(0.05, dur, 1, -3), doneAction: 2);
    var modf = freq * 1.41;
    var sig = SinOsc.ar(freq + (SinOsc.ar(modf, 0, modf * modIdx)));
    sig = sig + (Pulse.ar(freq * 0.501) * env * 0.15);
    sig = Pan2.ar((sig * env).tanh * amp, pan);
    Out.ar(out, sig);
    Out.ar(~doReverbBus, sig * rev);
}).add;

// "pulse" : kick subsonique declenche par les pics d'activite sociale
SynthDef(\do_kick, { |out=0, amp=0.55|
    var env = EnvGen.kr(Env.perc(0.001, 0.4, 1, -4), doneAction: 2);
    var pitch = EnvGen.kr(Env([180, 50, 38], [0.01, 0.2], -4));
    var sig = SinOsc.ar(pitch) * env;
    sig = sig.tanh * amp;
    Out.ar(out, Pan2.ar(sig, 0));
}).add;

// "pulse" : hat metallique pour les events GitHub
SynthDef(\do_hat, { |out=0, amp=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.002, 0.08), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar * env, 6000);
    Out.ar(out, Pan2.ar(sig * amp, pan));
}).add;

"[data-only/synthdefs] 10 SynthDefs added (\\do_*)".postln;
)
