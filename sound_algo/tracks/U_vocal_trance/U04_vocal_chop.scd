// =====================================================================
//  U04_vocal_chop.scd  --  Album U "Vocal Trance", track 4/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK U04 : "VOCAL CHOP" 7 minutes ----------------------
//   0:00 intro -> 0:42 build -> 1:45 main -> 5:06 variations -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[U04 0:00] intro vocal_chop...".postln;
    ~bpm = 140;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.18;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.140;
    ~melodyNotes = [77,75,0,0,75,0,0,0,60,0,0,0,63,0,77,70,75,0,0,0,75,0,0,0,63,0,0,72,67,0,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,0,0,0,0,1,0,0,0,1,1,1,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    42.wait;

    "[U04 0:42] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~melodyAmp = 0.200;
    ~reload.value;
    63.wait;

    "[U04 1:45] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [0,0,60,67,63,67,70,0,63,0,70,60,0,75,67,67,70,0,63,0,60,75,0,72,75,0,72,77,0,70,77,70];
    ~acidAmp = 0.22;
    ~reload.value;
    201.wait;

    "[U04 5:06] variations + mutations...".postln;
    ~melodyNotes = [67,0,77,77,75,77,0,67,70,70,67,75,67,0,77,60,67,67,72,72,72,77,70,67,65,77,70,0,0,72,60,0];
    ~reload.value;
    21.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.55, [~scaleMinorPent, ~scaleMinorPent, ~scaleDorian].choose);
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

    "[U04 6:30] outro -- fade...".postln;
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
    "[U04 7:00] === fin VOCAL CHOP ===".postln;
}).play;
"=== TRACK U04 : VOCAL CHOP 7 min lancee ===".postln;
)
