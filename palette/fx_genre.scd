// =====================================================================
//  fx_genre.scd  -- FX signature par genre
//                   (combinaisons riser+impact+sweep+gong+scratch)
//
//  Chaque preset = une transition prete a l'emploi.
//  Cmd+Entree pour declencher.
// =====================================================================

// --- TRANCE BUILD-UP -- snare roll + riser long + impact ---------
(
Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 12000, \amp, 0.35]);
~snareFill.(32, 16, 0.2, 0.55);
fork {
    16.wait;
    Synth(\impact, [\freq, 35, \decay, 3, \amp, 0.7]);
    Synth(\crash, [\decay, 4, \amp, 0.4]);
};
"=== TRANCE BUILD 16s ===".postln;
)

// --- DUBSTEP DROP -- impact + crash + riser court -----------------
(
Synth(\riser, [\dur, 4, \startCutoff, 500, \endCutoff, 11000, \amp, 0.4]);
fork {
    4.wait;
    Synth(\impact, [\freq, 30, \decay, 3.5, \amp, 0.85]);
    Synth(\crash, [\decay, 3, \amp, 0.5]);
};
"=== DUBSTEP DROP 4s ===".postln;
)

// --- HARDCORE GABBER DROP -- impact massif + double crash --------
(
Synth(\impact, [\freq, 25, \decay, 4, \amp, 0.9]);
Synth(\crash, [\decay, 5, \amp, 0.6]);
fork { 0.5.wait; Synth(\crash, [\decay, 3, \amp, 0.4]); };
"=== HARDCORE DROP ===".postln;
)

// --- DnB BUILD -- snare roll accelerando + drop --------------------
(
~snareFill.(16, 4, 0.3, 0.6);
fork {
    4.wait;
    Synth(\impact, [\freq, 40, \decay, 2.5, \amp, 0.65]);
};
"=== DnB BUILD 4s ===".postln;
)

// --- ASIAN CINEMATIC FX -- gong cascade ---------------------------
(
[40, 50, 60, 70].do { |f, i|
    fork { (i * 0.8).wait; Synth(\gong, [\freq, f, \decay, 8 - (i * 0.5), \amp, 0.45]); };
};
"=== GONG CASCADE 3s ===".postln;
)

// --- DUB TECHNO ECHO -- clap dub avec delay ------------------------
(
fork {
    5.do { |i|
        Synth(\clap, [\amp, 0.4 - (i * 0.06), \decay, 0.3]);
        0.4.wait;
    };
};
"=== DUB ECHO CLAP ===".postln;
)

// --- DETROIT FILTER SWEEP DOWN ------------------------------------
( Synth(\sweep, [\dur, 8, \startCutoff, 12000, \endCutoff, 200, \amp, 0.35]); )

// --- INDUSTRIAL TENSION -- sweep slow + drone --------------------
(
Synth(\sweep, [\dur, 16, \startCutoff, 8000, \endCutoff, 100, \amp, 0.4]);
~vinyl !? { ~vinyl.free };
~vinyl = Synth(\vinyl, [\amp, 0.12]);
fork { 16.wait; ~vinyl !? { ~vinyl.free }; };
"=== INDUSTRIAL TENSION 16s ===".postln;
)

// --- GLITCH IDM -- scratch + impacts random --------------------
(
fork {
    8.do {
        if (0.6.coin) { Synth(\scratch, [\dur, rrand(0.1, 0.4), \freq, rrand(400, 2000), \sweepDir, [-1, 1].choose, \amp, 0.3]) };
        if (0.3.coin) { Synth(\impact, [\freq, rrand(40, 80), \decay, rrand(0.5, 1.5), \amp, 0.4]) };
        rrand(0.15, 0.5).wait;
    };
};
"=== GLITCH 8 hits 4s ===".postln;
)

// --- VOCAL TRANCE SWELL -- riser + crash + impact ----------------
(
Synth(\riser, [\dur, 12, \startCutoff, 600, \endCutoff, 13000, \amp, 0.4]);
fork {
    12.wait;
    Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.7]);
    Synth(\crash, [\decay, 5, \amp, 0.45]);
};
"=== VOCAL TRANCE SWELL 12s ===".postln;
)

// --- TRIBAL TOM ROLL DESCENDANT ----------------------------------
(
[180, 140, 110, 85, 70, 55, 40].do { |f, i|
    fork { (i * 0.12).wait; Synth(\taiko, [\freq, f, \decay, 0.6, \amp, 0.5]); };
};
"=== TRIBAL TOM ROLL ===".postln;
)

// --- DRONE DOOM -- gong tres profond + reverb infinie ------------
(
Synth(\gong, [\freq, 25, \decay, 30, \amp, 0.95]);
fork { 5.wait; Synth(\gong, [\freq, 30, \decay, 25, \amp, 0.7]); };
"=== DRONE DOOM gong massif 30s ===".postln;
)

// --- HARDSTYLE BUILD -- kick reverse + snare roll + impact -----
(
Synth(\sweep, [\dur, 4, \startCutoff, 200, \endCutoff, 8000, \amp, 0.45]);
fork {
    4.wait;
    Synth(\impact, [\freq, 30, \decay, 3.5, \amp, 0.85]);
    Synth(\kickGabber, [\amp, 0.7]);
};
"=== HARDSTYLE BUILD 4s ===".postln;
)

// --- PHONK -- vinyl + cowbell + 808 sub --------------------------
(
~vinyl !? { ~vinyl.free };
~vinyl = Synth(\vinyl, [\amp, 0.15]);
fork {
    4.do {
        Synth(\cowbell, [\freq, 800, \decay, 0.2, \amp, 0.4]);
        0.5.wait;
    };
    Synth(\kick808, [\freq, 35, \decay, 1.2, \amp, 0.7]);
};
"=== PHONK VINYL 2.5s ===".postln;
)

// --- FUTURE GARAGE -- vocal-like swell + sub ---------------------
(
Synth(\sweep, [\dur, 6, \startCutoff, 6000, \endCutoff, 800, \amp, 0.3]);
fork { 5.wait; Synth(\impact, [\freq, 40, \decay, 2.5, \amp, 0.55]); };
"=== FUTURE GARAGE SWELL 6s ===".postln;
)

// --- SCRATCH FX -- 4 scratches rapides ---------------------------
(
4.do { |i|
    fork {
        (i * 0.15).wait;
        Synth(\scratch, [\dur, 0.2, \freq, 800 + (i * 200), \sweepDir, [-1, 1].choose, \amp, 0.4]);
    };
};
"=== SCRATCH x4 ===".postln;
)

// --- GLITCH STUTTER -- impacts rapides ---------------------------
(
fork {
    16.do { |i|
        Synth(\impact, [\freq, rrand(35, 60), \decay, 0.15, \amp, 0.4]);
        rrand(0.06, 0.15).wait;
    };
};
"=== GLITCH STUTTER 2s ===".postln;
)

// --- ASIAN MELODIC FILL (guzheng arpege descendant) -------------
(
[79, 77, 75, 72, 70, 67, 65, 63, 60].do { |n, i|
    fork {
        (i * 0.15).wait;
        Synth(\guzheng, [\freq, n.midicps, \amp, 0.18, \release, 1.0]);
    };
};
"=== ASIAN GUZHENG FILL ===".postln;
)

// --- DROP CUT -- coupe tout brutalement + impact 2s plus tard ----
(
Routine({
    var oldKick = ~kickAmp; var oldHat = ~hatAmp; var oldClap = ~clapAmp;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~reload.value;
    Synth(\sweep, [\dur, 2, \startCutoff, 8000, \endCutoff, 200, \amp, 0.4]);
    2.wait;
    Synth(\impact, [\freq, 30, \decay, 3, \amp, 0.85]);
    Synth(\crash, [\decay, 3, \amp, 0.4]);
    ~kickAmp = oldKick; ~hatAmp = oldHat; ~clapAmp = oldClap; ~reload.value;
}).play;
"=== DROP CUT 2s ===".postln;
)

// --- VINYL ON / OFF ----------------------------------------------
(~vinyl !? { ~vinyl.free }; ~vinyl = Synth(\vinyl, [\amp, 0.10]); "vinyl ON".postln;)
(~vinyl !? { ~vinyl.free; ~vinyl = nil }; "vinyl OFF".postln;)
