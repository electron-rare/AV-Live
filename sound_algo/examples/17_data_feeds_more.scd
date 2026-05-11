// =====================================================================
//  17_data_feeds_more.scd  --  Presets supplementaires data_feeds.
//
//  Suite de 16_data_feeds.scd. Quatre nouveaux mappings, autonomes,
//  a executer un par un dans l'IDE.
//
//  Prerequis :
//    [0] 01_live.scd bloc init
//    [1] cd data_feeds && uv run python bridge.py
//    [2] "sound_algo/control/data_feeds.scd".loadRelative
// =====================================================================

// ---------------------------------------------------------------------
// [1] PRESET D -- "Aurora"
//   Vent solaire + Bz IMF + Kp pilotent un drone spectral evolutif.
//   Bz negatif (couplage geomagnetique) -> pad descend en frequence.
//   Vitesse du vent -> decalage Doppler (legere desaccord chorus).
// ---------------------------------------------------------------------
(
SynthDef(\aurora_pad, { |out=0, freq=110, amp=0.3, detune=0.005, brillance=2000, ratio=1|
    var harm = freq * [1, ratio, 2, 2.01 * ratio, 3, 3.02 * ratio, 5];
    var amps = [1, 0.7, 0.5, 0.4, 0.3, 0.25, 0.15];
    var sig  = SinOsc.ar(harm * (1 + (LFNoise2.kr(0.2 ! 7) * detune)), 0, amps).sum;
    sig = sig + (Saw.ar(freq * 0.5) * 0.1);
    sig = LPF.ar(sig, brillance.lag(0.5).clip(120, 8000));
    sig = LeakDC.ar(sig).tanh * amp;
    Out.ar(out, Splay.ar([sig, DelayN.ar(sig, 0.04, 0.025)]));
}).add;

s.sync;

~aurora = Synth(\aurora_pad, [\freq, 55, \amp, 0.22]);

// Bz IMF : -20..+20 nT typique. Tres negatif = drone descend, brillance baisse.
~auroraBz = Routine({
    inf.do {
        var bz   = ~feedGet.(\swpc_bz, 0);
        var wind = ~feedGet.(\swpc_wind_speed, 400);
        var kp   = ~feedGet.(\swpc_kp, 2);
        // Bz tres negatif -> shift de freq vers le bas
        ~aurora.set(\freq, 55 * bz.linexp(-20, 20, 0.5, 1.4));
        // Vent solaire 250..900 km/s -> detune (Doppler)
        ~aurora.set(\detune, wind.linlin(250, 900, 0.002, 0.025));
        // Kp 0..9 -> brillance / ouverture LPF
        ~aurora.set(\brillance, kp.linexp(0, 9, 600, 8000));
        // amp legerement modulee par a-index
        ~aurora.set(\amp, ~feedGet.(\swpc_a, 5).linlin(0, 50, 0.18, 0.32));
        2.0.wait;
    };
}).play(AppClock);

"[aurora] up. arret : ~auroraStop.value".postln;
~auroraStop = {
    ~aurora.release(4);
    ~auroraBz.stop;
    "[aurora] off".postln;
};
)


// ---------------------------------------------------------------------
// [2] PRESET E -- "Pulse"
//   Battement principal genere par la frequence du reseau europeen.
//   50.0 Hz pile = pulse stable. Les ecarts pilotent un layer hat.
//   Bluesky firehose -> nuage de clicks granulaires (densite = post/s).
//   USGS -> sub-boom proportionnel au log(magnitude).
// ---------------------------------------------------------------------
(
SynthDef(\pulse_kick, { |out=0, freq=55, amp=0.7, dur=0.4, sweep=0.4|
    var env = EnvGen.kr(Env.perc(0.005, dur, 1, -4), doneAction: 2);
    var fenv = EnvGen.kr(Env([freq * (1 + sweep * 4), freq], [dur * 0.3], -8));
    var sig = SinOsc.ar(fenv) * env;
    sig = (sig * 1.4).tanh;
    Out.ar(out, Pan2.ar(sig * amp, 0));
}).add;

SynthDef(\pulse_hat, { |out=0, freq=8000, amp=0.3, dur=0.04, pan=0|
    var env = EnvGen.kr(Env.perc(0.001, dur), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, freq) * env * amp;
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

SynthDef(\pulse_click, { |out=0, freq=2000, amp=0.2, pan=0|
    var env = EnvGen.kr(Env.perc(0.0005, 0.02), doneAction: 2);
    var sig = (SinOsc.ar(freq) + WhiteNoise.ar(0.3)) * env * amp;
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

SynthDef(\pulse_sub, { |out=0, freq=35, amp=0.6, dur=2|
    var env = EnvGen.kr(Env([0, 1, 0.4, 0], [0.05, dur * 0.3, dur * 0.65], [-2, -2, -3]),
                        doneAction: 2);
    var sig = SinOsc.ar(freq) * env;
    sig = sig + (LFTri.ar(freq * 0.5) * env * 0.2);
    Out.ar(out, Pan2.ar(sig.tanh * amp, 0));
}).add;

s.sync;

// Routine principale : kick au tempo dicte par la frequence reseau (50 Hz +- dev)
~pulseClock = Routine({
    inf.do {
        var hz   = ~feedGet.(\netz_freq, 50.0);
        var dev  = ~feedGet.(\netz_dev, 0);
        // tempo musical : 50 Hz -> 125 BPM ; +0.05 Hz -> +1.25 BPM
        var bpm  = hz * 2.5;
        var beat = 60 / bpm;
        Synth(\pulse_kick, [\freq, 50 + (dev * 30), \amp, 0.7]);
        // double les hats si la grille est tres stable
        if(dev.abs < 0.02) {
            (beat / 2).wait;
            Synth(\pulse_hat, [\freq, 9000, \amp, 0.18, \pan, 0.3]);
            (beat / 2).wait;
        } {
            beat.wait;
        };
    };
}).play(AppClock);

// Bluesky : chaque post devient un click discret. On limite via rate.
~pulseBskySub = ~feedSub.(\social_rate_s, { |rate|
    // ~rate posts/sec : on echantillonne pour generer ~rate clicks/sec
    var n = rate.clip(0, 30).asInteger;
    n.do { |i|
        AppClock.sched(i * 0.03 + 1.0.rand, {
            Synth(\pulse_click, [
                \freq, exprand(800, 8000),
                \pan, 1.0.rand2,
                \amp, 0.06 + 0.1.rand
            ]); nil;
        });
    };
});

// USGS : sub-boom log-magnitude
~pulseQuakeSub = ~feedSub.(\usgs_last_mag, { |mag|
    Synth(\pulse_sub, [
        \freq, mag.linexp(2, 7.5, 30, 90),
        \dur,  mag.linlin(2, 7.5, 1.5, 5),
        \amp,  mag.linlin(2, 7.5, 0.4, 0.85),
    ]);
});

"[pulse] up. arret : ~pulseStop.value".postln;
~pulseStop = {
    ~pulseClock.stop;
    ~feedUnsub.(\social_rate_s, ~pulseBskySub);
    ~feedUnsub.(\usgs_last_mag, ~pulseQuakeSub);
    "[pulse] off".postln;
};
)


// ---------------------------------------------------------------------
// [3] PRESET F -- "Carbone"
//   eCO2mix RTE 8 filieres -> 8-operateur FM additif.
//   Chaque filiere pilote un partial : amplitude = part dans le mix.
//   Renouvelables (hydro, eolien, solaire, bio) -> partials harmoniques.
//   Fossiles (gaz, charbon, fioul) -> partials inharmoniques (bruit).
//   Nucleaire -> drone continu.
//
//   ATTENTION : eCO2mix necessite token RTE (cf. config.toml).
//   En l'absence de donnees, le synth tourne sur valeurs par defaut.
// ---------------------------------------------------------------------
(
SynthDef(\carbone_op, { |out=0, freq=110, amp=0.0, harm=1, fm=0, inharm=0|
    var f = freq * harm + (LFNoise2.kr(8) * inharm * freq);
    var car = SinOsc.ar(f, SinOsc.ar(f * 0.5, 0, fm * f * 0.3));
    car = car * amp.lag(1.0);
    Out.ar(out, Pan2.ar(car, harm.linlin(1, 8, -0.8, 0.8)));
}).add;

s.sync;

// 8 operateurs : nuc, gas, coal, oil, hydro, wind, solar, bio
~carboneOps = ();
~carboneOps[\nuclear] = Synth(\carbone_op, [\harm, 1, \inharm, 0,    \amp, 0.3]);
~carboneOps[\gas]     = Synth(\carbone_op, [\harm, 7, \inharm, 0.04, \amp, 0]);
~carboneOps[\coal]    = Synth(\carbone_op, [\harm, 9, \inharm, 0.06, \amp, 0]);
~carboneOps[\oil]     = Synth(\carbone_op, [\harm, 11, \inharm, 0.08, \amp, 0]);
~carboneOps[\hydro]   = Synth(\carbone_op, [\harm, 2, \inharm, 0,    \amp, 0]);
~carboneOps[\wind]    = Synth(\carbone_op, [\harm, 3, \inharm, 0,    \amp, 0]);
~carboneOps[\solar]   = Synth(\carbone_op, [\harm, 5, \inharm, 0,    \amp, 0]);
~carboneOps[\bio]     = Synth(\carbone_op, [\harm, 4, \inharm, 0,    \amp, 0]);

// FM globale : intensite carbone -> brillance FM
~carboneR = Routine({
    inf.do {
        var total  = ~feedGet.(\rte_total, 50000);
        var renew  = ~feedGet.(\rte_renew_pct, 0.25);
        var gPart  = if(total > 0) { ~feedGet.(\rte_gas, 0)  / total } { 0 };
        var cPart  = if(total > 0) { ~feedGet.(\rte_coal, 0) / total } { 0 };
        var oPart  = if(total > 0) { ~feedGet.(\rte_oil, 0)  / total } { 0 };
        var hPart  = if(total > 0) { ~feedGet.(\rte_hydro, 0)/ total } { 0 };
        var wPart  = if(total > 0) { ~feedGet.(\rte_wind, 0) / total } { 0 };
        var sPart  = if(total > 0) { ~feedGet.(\rte_solar, 0)/ total } { 0 };
        var bPart  = if(total > 0) { ~feedGet.(\rte_bio, 0)  / total } { 0 };
        ~carboneOps[\gas]    .set(\amp, gPart * 0.6, \fm, gPart * 1.5);
        ~carboneOps[\coal]   .set(\amp, cPart * 0.6, \fm, cPart * 2.0);
        ~carboneOps[\oil]    .set(\amp, oPart * 0.7, \fm, oPart * 2.5);
        ~carboneOps[\hydro]  .set(\amp, hPart * 0.4);
        ~carboneOps[\wind]   .set(\amp, wPart * 0.4);
        ~carboneOps[\solar]  .set(\amp, sPart * 0.5);
        ~carboneOps[\bio]    .set(\amp, bPart * 0.3);
        ~carboneOps[\nuclear].set(\amp, 0.3 * (1 - renew));
        5.0.wait;
    };
}).play(AppClock);

"[carbone] up. arret : ~carboneStop.value".postln;
~carboneStop = {
    ~carboneR.stop;
    ~carboneOps.do { |s| s.set(\amp, 0); AppClock.sched(2.0, { s.free; nil }); };
    ~carboneOps = ();
    "[carbone] off".postln;
};
)


// ---------------------------------------------------------------------
// [4] PRESET G -- "Skylane"
//   OpenSky ADS-B -> nuage granular continu.
//   Chaque avion = grain perpetuel : altitude = pitch, vitesse = densite,
//   cap = pan stereo. Le nombre d'avions visibles (count) controle un
//   filtre passe-bande global.
//   Les flares X-ray SWPC interrompent tout (silence dramatique 2 s).
// ---------------------------------------------------------------------
(
SynthDef(\sky_grain, { |out=0, freq=440, amp=0.0, density=10, pan=0, bright=2|
    var trig = Dust.kr(density.lag(0.5).clip(0.5, 50));
    var env  = EnvGen.kr(Env.perc(0.002, 0.08), trig);
    var sig  = (SinOsc.ar(freq) + (Saw.ar(freq * 1.005) * 0.3)) * env * amp;
    sig = LPF.ar(sig, freq * bright);
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

SynthDef(\sky_bus, { |out=0, in=0, freq=1500, q=0.3, amp=1|
    var sig = In.ar(in, 2);
    sig = BPF.ar(sig, freq.lag(0.5).clip(200, 8000), q);
    Out.ar(out, sig * amp * 1.4);
}).add;

s.sync;

// pool de grains. on en cree 6, et on les recycle au gre des donnees.
~skyGrains = 6.collect { |i| Synth(\sky_grain, [\freq, 440 + i * 73, \amp, 0]) };
~skyHead = 0;

~planeSub2 = ~feedSub.(\aviation_last, { |val|
    var lon = val[1], lat = val[2], alt = val[3], vel = val[4], head = val[5];
    var grain = ~skyGrains.wrapAt(~skyHead);
    var midi  = alt.linlin(0, 12000, 36, 84);
    grain.set(
        \freq,    midi.midicps,
        \amp,     vel.linlin(50, 300, 0.05, 0.18),
        \density, vel.linlin(50, 300, 1.5, 12),
        \pan,     head.linlin(0, 360, -1, 1),
        \bright,  alt.linlin(0, 12000, 1.5, 6),
    );
    ~skyHead = ~skyHead + 1;
});

// Filtre BPF global pilote par count (densite trafic)
~skyFilterR = Routine({
    inf.do {
        var n = ~feedGet.(\aviation_count, 5);
        // peu d'avions -> filtre serre haut. trafic -> ouvert grave.
        var f = n.linexp(0, 50, 4500, 350);
        var q = n.linlin(0, 50, 0.6, 0.15);
        ~skyGrains.do { |g| g.set(\bright, n.linlin(0, 50, 1.2, 5)) };
        2.0.wait;
    };
}).play(AppClock);

// Flare = silence dramatique 2 s
~flareSub2 = ~feedSub.(\swpc_flare_norm, { |val|
    if(val > 0.5) {
        ~skyGrains.do { |g| g.set(\amp, 0) };
        AppClock.sched(2.0, {
            ~skyGrains.do { |g| g.set(\amp, exprand(0.05, 0.18)) };
            nil
        });
        "*** sky flare blackout ***".postln;
    };
});

"[sky] up. arret : ~skyStop.value".postln;
~skyStop = {
    ~skyFilterR.stop;
    ~feedUnsub.(\aviation_last, ~planeSub2);
    ~feedUnsub.(\swpc_flare_norm, ~flareSub2);
    ~skyGrains.do { |g| g.set(\amp, 0); AppClock.sched(0.5, { g.free; nil }) };
    "[sky] off".postln;
};
)


// ---------------------------------------------------------------------
// [9] ARRET TOTAL
// ---------------------------------------------------------------------
(
~auroraStop  !? { ~auroraStop.value };
~pulseStop   !? { ~pulseStop.value };
~carboneStop !? { ~carboneStop.value };
~skyStop     !? { ~skyStop.value };
)
