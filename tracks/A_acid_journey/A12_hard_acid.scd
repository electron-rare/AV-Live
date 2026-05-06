// =====================================================================
//  A12_hard_acid.scd  --  Album A "Acid Journey", track 12/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A12 : "HARD ACID (Hardstyle)" 5 minutes ------------------
//   0:00 hard kick -> 1:00 303 brutal -> 2:30 hard lead -> 3:30 peak -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A12 0:00] hard kick -- distorted T4 punisher...".postln;
    ~bpm = 142;
    ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
    ~kickDrive = 3.5; ~kickClick = 0.30; ~kickAmp = 0.65;
    ~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,1]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.55;
    ~acidAmp = 0; ~melodyAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\off);
    60.wait;

    "[A12 1:00] 303 brutal -- harmonic minor evil...".postln;
    ~acidAmp = 0.34; ~acidCutoff = 1100; ~acidRq = 0.10; ~acidDrive = 3.5;
    ~acidNotes = [36,36,48,36, 39,36,47,36, 36,48,36,41, 39,36,43,36];
    ~acidSlides = [0,0,1,0, 0,1,0,0, 0,0,0,1, 0,0,0,1];
    ~reload.value;
    Pdef(\acidSeq).play;
    // 90s acid sweep
    18.do { |k|
        ~acidCutoff = 900 + (k * 25);
        if (0.30.coin) { ~acidRq = rrand(0.08, 0.14); };
        if (0.20.coin) {
            ~acidNotes = ~genMelody.(0.8, ~scaleHarmonicMin);
            ~acidSlides = ~genAcidSlides.(0.40);
        };
        ~reload.value;
        5.wait;
    };

    "[A12 2:30] hard lead -- screaming saw lead...".postln;
    ~melodyInst = \hard_lead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.15; ~melodyCutoff = 2400;
    ~melodyAmp = 0.18; ~melodyDrive = 3.5;
    ~melodyNotes = [60,0,68,0, 67,0,71,68, 65,0,68,0, 67,71,72,0,
                    71,0,68,67, 65,68,0,71, 0,72,71,68, 67,0,0,0];
    ~reload.value;
    Pdef(\melodySeq).play;
    ~vcfOn !? { ~vcfOn.(\moog, 1800, 0.55) };
    // 60s lead variations
    12.do { |k|
        if (0.30.coin) {
            ~melodyNotes = ~genMelody.(0.65, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.18.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-5, 5, 7].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[A12 3:30] peak -- everything maxed...".postln;
    ~bpm = 145;
    ~kickDrive = 4.0; ~acidCutoff = 1700; ~acidDrive = 4.0;
    ~melodyAmp = 0.22; ~melodyDrive = 4.0;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.18;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    60.wait;

    "[A12 4:30] outro -- hard cut...".postln;
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.65; ~hatAmp = x * 0.18; ~clapAmp = x * 0.55;
        ~melodyAmp = x * 0.22; ~acidAmp = x * 0.34;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \clapSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).stop };
    "[A12 5:00] === fin HARD ACID ===".postln;
}).play;
"=== TRACK A12 : HARD ACID 5 min lancee ===".postln;
)
