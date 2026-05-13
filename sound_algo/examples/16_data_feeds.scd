// =====================================================================
//  16_data_feeds.scd  --  Pilotage musical par flux temps reel.
//
//  NOTE : les SynthDefs de ce fichier sont prefixees \\ex_ pour cohabiter
//  sans collision avec les \\dop_ definies dans live/data_only_program.scd
//  (boot "production"). Modifier ici = pedagogie ; le live tape sur \\dop_.
//
//  Prerequis :
//    [0] Bloc d'init de 01_live.scd (engine + setupAll + wrappers)
//    [1] Pont Python lance :
//          cd data_feeds && uv run python bridge.py
//    [2] OSCdef installes :
//          ("control/data_feeds.scd").loadRelative
//
//  Trois presets ci-dessous, autonomes, a executer un par un dans l'IDE.
// =====================================================================

// ---------------------------------------------------------------------
// [0] Sanity-check : afficher l'etat des flux
// ---------------------------------------------------------------------
(
"sound_algo/control/data_feeds.scd".loadRelative;
fork {
    "[16] verification du pont...".postln;
    5.do { ~feedDump.value; 2.wait };
};
)


// ---------------------------------------------------------------------
// [1] PRESET A -- "Cavity"
//   Schumann (drone harmonique) x Netzfrequenz (modulation FM subtile)
//   x Blitzortung (percussions spatialisees).
//   Trois echelles temporelles, trois ordres de grandeur en frequence.
// ---------------------------------------------------------------------
(
SynthDef(\ex_cavity_drone, { |out=0, freq=7.83, amp=0.25, fm=0, pan=0|
    var sig, harm = freq * [1, 2, 3, 4, 5];
    var amps = [1, 0.5, 0.33, 0.25, 0.2];
    sig = SinOsc.ar(harm + fm.lag(0.05), 0, amps).sum;
    sig = sig + (LFTri.ar(freq * 0.5) * 0.1);
    sig = LeakDC.ar(sig);
    sig = sig.tanh * amp;
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

SynthDef(\ex_strike_grain, { |out=0, freq=400, amp=0.5, pan=0, dur=0.4|
    var env = EnvGen.kr(Env.perc(0.001, dur), doneAction: 2);
    var sig = WhiteNoise.ar * env;
    sig = BPF.ar(sig, freq, 0.05) * 6;
    sig = sig + (SinOsc.ar(freq, 0, env * 0.5));
    Out.ar(out, Pan2.ar(sig.tanh * amp, pan));
}).add;

// laisse le serveur compiler
s.sync;

~cavity = Synth(\ex_cavity_drone, [\freq, 7.83, \amp, 0.22]);

// Mod FM par derive de la frequence reseau (dev ~ +-0.05 Hz typique)
~cavityFm = Routine({
    inf.do {
        var dev = ~feedGet.(\netz_dev, 0);
        ~cavity.set(\fm, dev * 80);   // amplification non-lineaire
        0.1.wait;
    };
}).play(AppClock);

// Foudre = grain percussif spatialise
~strikeSub = ~feedSub.(\lightning_last, { |val|
    var lat = val[0], lon = val[1], age = val[2], mult = val[3];
    if(age < 30) {
        var pan  = lon.linlin(-180, 180, -1, 1);
        var freq = lat.linlin(-90, 90, 200, 3000);
        Synth(\ex_strike_grain, [
            \freq, freq, \pan, pan,
            \amp, mult.linlin(1, 10, 0.4, 0.9),
            \dur, mult.linlin(1, 10, 0.2, 0.8),
        ]);
    };
});

"[cavity] up. arret : ~cavityStop.value".postln;
~cavityStop = {
    ~cavity.release(2);
    ~cavityFm.stop;
    ~feedUnsub.(\lightning_last, ~strikeSub);
    "[cavity] off".postln;
};
)


// ---------------------------------------------------------------------
// [2] PRESET B -- "Mix"
//   eCO2mix (RTE) regle la couleur harmonique : plus de renouvelable
//   eclaire le filtre, plus de fossile l'assombrit.
//   OpenSky donne des impulsions melodiques (avions au-dessus de Lyon).
// ---------------------------------------------------------------------
(
SynthDef(\ex_mix_pad, { |out=0, freq=110, amp=0.3, cutoff=800, q=0.3, pan=0|
    var sig = Mix(Saw.ar(freq * [1, 1.005, 0.503, 2.01]));
    sig = RLPF.ar(sig, cutoff.lag(0.5).clip(80, 8000), q);
    sig = sig * amp;
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

SynthDef(\ex_plane_blip, { |out=0, freq=600, amp=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.01, 0.6), doneAction: 2);
    var sig = SinOsc.ar(freq * [1, 2.01], 0, [0.7, 0.3]).sum;
    sig = sig + (Pulse.ar(freq * 0.501) * env * 0.2);
    sig = (sig * env).tanh * amp;
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

s.sync;

~mixPad = Synth(\ex_mix_pad, [\freq, 55, \amp, 0.18]);

~mixCutoffR = Routine({
    inf.do {
        var pct = ~feedGet.(\rte_renew_pct, 0.25);
        ~mixPad.set(\cutoff, pct.linexp(0.0, 0.5, 200, 5000));
        ~mixPad.set(\q, pct.linlin(0.0, 0.5, 0.5, 0.15));
        2.0.wait;
    };
}).play(AppClock);

// chaque update OpenSky -> on tire 1 a 3 blips selon la densite
~planeSub = ~feedSub.(\aviation_last, { |val|
    var icao = val[0], lon = val[1], lat = val[2], alt = val[3], vel = val[4];
    var pan = lon.linlin(4.6, 5.2, -1, 1);
    // altitude -> note ; vitesse -> brillance
    var midinote = alt.linlin(0, 12000, 36, 84).clip(24, 96);
    Synth(\ex_plane_blip, [
        \freq, midinote.midicps,
        \pan, pan,
        \amp, vel.linlin(50, 300, 0.1, 0.35),
    ]);
});

"[mix] up. arret : ~mixStop.value".postln;
~mixStop = {
    ~mixPad.release(3);
    ~mixCutoffR.stop;
    ~feedUnsub.(\aviation_last, ~planeSub);
    "[mix] off".postln;
};
)


// ---------------------------------------------------------------------
// [3] PRESET C -- "Geomagnetic"
//   Kp (geomagnetisme) ouvre/ferme un filtre passe-bande.
//   X-ray flares declenchent un drop dramatique.
//   USGS earthquakes -> sub-bass ponctuel proportionnel a la magnitude.
// ---------------------------------------------------------------------
(
SynthDef(\ex_geo_bus, { |out=0, freq=200, amp=0.4, bw=0.4|
    var sig = Mix(Saw.ar([55, 110, 165]));
    sig = BPF.ar(sig, freq.lag(0.3).clip(80, 6000), bw.lag(0.3).clip(0.05, 1));
    sig = sig * 1.5;
    Out.ar(out, Splay.ar([sig, DelayN.ar(sig, 0.05, 0.03)]) * amp);
}).add;

SynthDef(\ex_quake_sub, { |out=0, freq=40, amp=0.7, dur=2|
    var env = EnvGen.kr(Env.perc(0.05, dur, 1, -2), doneAction: 2);
    var sig = SinOsc.ar(freq) * env;
    sig = sig + (LFTri.ar(freq * 0.5) * env * 0.3);
    sig = sig.tanh * amp;
    Out.ar(out, Pan2.ar(sig, 0));
}).add;

s.sync;

~geo = Synth(\ex_geo_bus, [\amp, 0.25]);

~geoKpR = Routine({
    inf.do {
        var kp = ~feedGet.(\swpc_kp, 2);
        // Kp 0..9 -> ouvre 200..3000 Hz
        ~geo.set(\freq, kp.linexp(0, 9, 200, 3000));
        ~geo.set(\bw,   kp.linlin(0, 9, 0.5, 0.05));
        5.0.wait;
    };
}).play(AppClock);

~flareSub = ~feedSub.(\swpc_flare_norm, { |val|
    if(val > 0.5) {
        // X-class flare : choc
        ~geo.set(\amp, 0.6);
        AppClock.sched(3.0, { ~geo.set(\amp, 0.25); nil });
        "*** flare ***".postln;
    };
});

~quakeSub = ~feedSub.(\usgs_last_mag, { |val|
    Synth(\ex_quake_sub, [
        \freq, val.linexp(2, 7, 30, 120),
        \dur,  val.linlin(2, 7, 1, 5),
        \amp,  val.linlin(2, 7, 0.4, 0.9),
    ]);
});

"[geo] up. arret : ~geoStop.value".postln;
~geoStop = {
    ~geo.release(2);
    ~geoKpR.stop;
    ~feedUnsub.(\swpc_flare_norm, ~flareSub);
    ~feedUnsub.(\usgs_last_mag, ~quakeSub);
    "[geo] off".postln;
};
)


// ---------------------------------------------------------------------
// [4] PRESET D -- "Body"
//   Corps detecte (YOLOv8-pose) pilote 4 synths :
//     - poignet droit  -> filtre passe-bas (X hor) + amp (Y vert)
//     - poignet gauche -> pitch d'un drone
//     - hauteur des epaules -> seuil de granulateur
//     - confiance moyenne -> reverb wet
// ---------------------------------------------------------------------
(
SynthDef(\ex_body_drone, { |out=0, freq=80, amp=0.25, cutoff=800, q=0.4, pan=0|
    var sig = Saw.ar(freq * [1, 1.005, 0.503]);
    sig = RLPF.ar(sig, cutoff.lag(0.05).clip(80, 8000), q);
    sig = sig.sum * amp;
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

SynthDef(\ex_body_gran, { |out=0, dens=10, rate=1.0, amp=0.3|
    var trig = Impulse.kr(dens);
    var grain = SinOsc.ar(
        TRand.kr(200, 1200, trig) * rate.lag(0.1),
        0,
        EnvGen.kr(Env.perc(0.005, 0.05), trig)
    );
    Out.ar(out, Pan2.ar(grain * amp, TRand.kr(-1, 1, trig)));
}).add;

s.sync;

~bodyDrone = Synth(\ex_body_drone, [\amp, 0.2]);
~bodyGran  = Synth(\ex_body_gran,  [\amp, 0.15]);

~bodyR = Routine({
    inf.do {
        var wr = ~poseKp.(\wri_r);
        var wl = ~poseKp.(\wri_l);
        var sl = ~poseKp.(\sho_l), sR = ~poseKp.(\sho_r);
        var avg, shoY;
        if(wr.notNil and: { wr.c > 0.3 }) {
            ~bodyDrone.set(\cutoff, wr.x.linexp(0, 1, 200, 6000));
            ~bodyDrone.set(\amp, (1 - wr.y).linlin(0, 1, 0.05, 0.5));
        };
        if(wl.notNil and: { wl.c > 0.3 }) {
            ~bodyDrone.set(\freq, wl.y.linexp(0, 1, 220, 55));
        };
        if(sl.notNil and: { sR.notNil }) {
            shoY = (sl.y + sR.y) * 0.5;
            ~bodyGran.set(\dens, (1 - shoY).linexp(0, 1, 2, 80));
            ~bodyGran.set(\rate, (1 - shoY).linlin(0, 1, 0.5, 2.5));
        };
        avg = ~feedGet.(\pose_count, 0);
        if(avg < 1) {
            // personne -> on baisse tout
            ~bodyDrone.set(\amp, 0.0);
            ~bodyGran.set(\amp, 0.0);
        } {
            ~bodyGran.set(\amp, 0.15);
        };
        0.05.wait;
    };
}).play(AppClock);

"[body] up. arret : ~bodyStop.value".postln;
~bodyStop = {
    ~bodyDrone.release(2);
    ~bodyGran.release(1);
    ~bodyR.stop;
    "[body] off".postln;
};
)


// ---------------------------------------------------------------------
// [9] ARRET TOTAL
// ---------------------------------------------------------------------
(
~cavityStop !? { ~cavityStop.value };
~mixStop    !? { ~mixStop.value };
~geoStop    !? { ~geoStop.value };
~bodyStop   !? { ~bodyStop.value };
)
