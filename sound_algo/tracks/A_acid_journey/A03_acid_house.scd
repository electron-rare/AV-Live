// =====================================================================
//  A03_acid_house.scd  --  Album A "Acid Journey", track 3/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A03 : "ACID HOUSE (Chicago)" 6 minutes -------------------
//   0:00 four-on-floor -> 1:30 303 squelch -> 3:00 rhodes chord -> 4:30 climax -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A03 0:00] four-on-floor -- house kick + open hat shuffle...".postln;
    ~bpm = 122;
    ~kickFreq = 50; ~kickPitchAmt = 2.5; ~kickDecay = 0.4;
    ~kickDrive = 1.2; ~kickClick = 0.18; ~kickAmp = 0.55;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,1]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~acidAmp = 0; ~acidCutoff = 700; ~acidRq = 0.18; ~acidDrive = 2.0;
    ~melodyInst = \pluck; ~melodyAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\off);
    90.wait;

    "[A03 1:30] 303 squelch -- pure acid bass...".postln;
    ~acidAmp = 0.32; ~acidCutoff = 850;
    ~acidNotes = [36,48,36,36, 39,36,43,36, 41,36,48,36, 39,36,36,43];
    ~acidSlides = [0,1,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1];
    ~reload.value;
    Pdef(\acidSeq).play;
    // 90s mutation 303 progressive
    18.do { |k|
        ~acidCutoff = 600 + (k * 35);
        if (0.35.coin) { ~acidRq = rrand(0.10, 0.25) };
        if (0.20.coin) { ~acidSlides = ~genAcidSlides.(0.35); };
        if (0.15.coin) { ~acidNotes = ~genMelody.(0.7, ~scaleAcid); };
        ~reload.value;
        5.wait;
    };

    "[A03 3:00] rhodes chord -- jazzy vibe...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.01; ~melodyRelease = 1.2; ~melodyCutoff = 2200;
    ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 65,0,0,0, 70,0,0,0,
                    63,0,0,0, 69,0,0,0, 67,0,0,0, 0,0,0,0];
    ~enableHarmony.(\third);
    ~reload.value;
    Pdef(\melodySeq).play; Pdef(\harmonySeq).play;
    // 90s avec mutations rhodes
    18.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.45, ~scaleDorian);
            ~reload.value;
        };
        if (0.18.coin) { ~melodyCutoff = rrand(1600, 2800); ~reload.value };
        if (0.10.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-3, -5, 5, 7].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[A03 4:30] climax -- 303 + rhodes + clap drive...".postln;
    ~bpm = 124;
    ~acidCutoff = 1200; ~acidDrive = 2.6;
    ~melodyAmp = 0.18; ~kickAmp = 0.6;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.12;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    60.wait;

    "[A03 5:30] outro -- rhodes seul s'eteint...".postln;
    [\kickSeq, \hatSeq, \clapSeq].do { |k| Pdef(k).stop };
    ~acidAmp = 0;
    ~enableHarmony.(\off);
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.18;
        ~melodyCutoff = 400 + (x * 1800);
        ~reload.value;
        1.wait;
    };
    [\acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    "[A03 6:00] === fin ACID HOUSE ===".postln;
}).play;
"=== TRACK A03 : ACID HOUSE 6 min lancee ===".postln;
)
