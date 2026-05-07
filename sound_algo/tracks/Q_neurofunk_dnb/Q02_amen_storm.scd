// =====================================================================
//  Q02_amen_storm.scd  --  Album Q "Neurofunk DnB", track 2/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  Sub-track : "Amen Storm" 5 min (300s)
// =====================================================================

// --- TRACK Q02 : "AMEN STORM" 5 minutes -------------
//   0:00 intro -> 1:07 groove -> 2:28 drop -> 3:35 variations -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[Q02 0:00] intro / atmosphere...".postln;
    ~bpm = 175;
    ~kickFreq = 55; ~kickPitchAmt = 4.0; ~kickDecay = 0.18;
    ~kickDrive = 1.8; ~kickClick = 0.35;
    ~kickSteps = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~hatSteps  = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,0]; ~snareAmp = 0.55;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~percInst = \cowbell;
    ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.30;
    ~melodyInst = \reeseDnB;
    ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 800;
    ~melodyAmp = 0.168;
    ~melodyNotes = ~genMelody.(0.45, ~scaleMinorPent);
    ~acidNotes = [36,0,48,0,36,0,43,0, 36,0,41,0,39,0,36,0];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 800; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0.120;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dry) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\off);
    67.wait;

    "[Q02 1:07] build / groove...".postln;
    ~melodyAmp = 0.238;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinor);
    ~melodyCutoff = 1400;
    ~reload.value;
    20.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25);
            ~reload.value;
        };
        if (0.15.coin) {
            ~acidCutoff = rrand(500, 1800); ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.3); ~reload.value;
        };
        4.wait;
    };

    "[Q02 2:28] drop / climax...".postln;
    ~melodyAmp = 0.280;
    ~kickAmp = 0.600;
    ~melodyNotes = ~genMelody.(0.6, ~scaleMinor);
    ~melodyCutoff = 2000;
    ~acidAmp = 0.200;
    ~acidCutoff = 1500; ~acidDrive = 3.2;
    ~reload.value;
    13.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2);
            ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[Q02 3:35] variations / second wave...".postln;
    ~melodyInst = \reese;
    ~melodyAttack = 0.005; ~melodyRelease = 0.35;
    ~melodyAmp = 0.252;
    ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
    ~melodyCutoff = 1600;
    ~vcfOn !? { ~vcfOn.(\moog, 1200, 0.5) };
    ~reload.value;
    55.wait;

    "[Q02 4:30] outro -- fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.280;
        ~kickAmp = x * 0.550;
        ~hatAmp = x * 0.130;
        ~snareAmp = x * 0.550;
        ~clapAmp = x * 0.350;
        ~acidAmp = x * 0.200;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[Q02 5:00] === fin AMEN STORM ===".postln;
}).play;
"=== TRACK Q02 : AMEN STORM 5 min lancee ===".postln;
)
