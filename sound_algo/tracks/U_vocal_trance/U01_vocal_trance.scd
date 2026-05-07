// =====================================================================
//  U01_vocal_trance.scd  --  Album U "Vocal Trance", track 1/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK U01 : "VOCAL TRANCE" 4 minutes ----------------------
//   0:00 intro -> 0:24 build -> 1:00 main -> 2:42 variations -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[U01 0:00] intro vocal_trance...".postln;
    ~bpm = 138;
    ~kickFreq = 52; ~kickPitchAmt = 2.8; ~kickDecay = 0.36; ~kickClick = 0.15;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \choir;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.140;
    ~melodyNotes = [62,67,63,0,62,0,62,60,65,0,0,0,72,0,0,63,70,0,68,70,62,0,0,0,60,0,0,0,70,67,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,1,0,0,0,1,0,1,1,0,0,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    24.wait;

    "[U01 0:24] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~melodyAmp = 0.200;
    ~reload.value;
    36.wait;

    "[U01 1:00] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [0,62,65,0,0,0,0,72,68,68,67,0,0,63,65,70,65,0,0,0,60,0,62,68,72,72,63,67,0,70,63,62];
    ~acidAmp = 0.22;
    ~reload.value;
    102.wait;

    "[U01 2:42] variations + mutations...".postln;
    ~melodyNotes = [0,0,63,0,62,72,60,0,67,0,67,72,67,0,0,62,0,65,63,60,72,68,0,0,60,62,72,0,0,63,72,0];
    ~reload.value;
    12.do { |k|
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

    "[U01 3:30] outro -- fade...".postln;
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
    "[U01 4:00] === fin VOCAL TRANCE ===".postln;
}).play;
"=== TRACK U01 : VOCAL TRANCE 4 min lancee ===".postln;
)
