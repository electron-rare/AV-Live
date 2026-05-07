// =====================================================================
//  U09_tech_trance_vocal.scd  --  Album U "Vocal Trance", track 9/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK U09 : "TECH TRANCE VOCAL" 7 minutes ----------------------
//   0:00 intro -> 0:42 build -> 1:45 main -> 5:06 variations -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[U09 0:00] intro tech_trance_vocal...".postln;
    ~bpm = 140;
    ~kickFreq = 52; ~kickPitchAmt = 2.8; ~kickDecay = 0.36; ~kickClick = 0.15;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.140;
    ~melodyNotes = [62,0,0,0,63,0,0,0,62,0,0,0,68,0,0,0,72,63,67,0,62,0,0,0,60,0,0,0,70,63,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    42.wait;

    "[U09 0:42] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~melodyAmp = 0.200;
    ~reload.value;
    63.wait;

    "[U09 1:45] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [0,72,68,0,72,72,65,72,0,72,67,0,70,0,0,0,67,72,0,62,0,62,63,63,0,65,0,0,0,70,65,62];
    ~acidAmp = 0.22;
    ~reload.value;
    201.wait;

    "[U09 5:06] variations + mutations...".postln;
    ~melodyNotes = [60,62,0,63,67,0,63,0,60,0,65,0,70,67,62,70,72,72,60,65,0,60,65,63,0,68,60,72,70,0,60,62];
    ~reload.value;
    21.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.55, [~scaleMinor, ~scaleMinorPent, ~scaleDorian].choose);
        };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2);
        };
        if (0.15.coin) {
            ~melodyCutoff = rrand(1500, 5500);
        };
        if (0.10.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.25);
        };
        ~reload.value;
        4.wait;
    };

    "[U09 6:30] outro -- fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.200;
        ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.15;
        ~clapAmp = x * 0.32;
        ~acidAmp = x * 0.22;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[U09 7:00] === fin TECH TRANCE VOCAL ===".postln;
}).play;
"=== TRACK U09 : TECH TRANCE VOCAL 7 min lancee ===".postln;
)
