// =====================================================================
//  U13_ambient_vocal.scd  --  Album U "Vocal Trance", track 13/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK U13 : "AMBIENT VOCAL" 4 minutes ----------------------
//   0:00 intro -> 0:24 build -> 1:00 main -> 2:42 variations -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[U13 0:00] intro ambient_vocal...".postln;
    ~bpm = 130;
    ~kickFreq = 52; ~kickPitchAmt = 2.8; ~kickDecay = 0.36; ~kickClick = 0.15;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \drone;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.140;
    ~melodyNotes = [69,0,0,62,72,70,63,0,70,0,0,0,70,0,0,0,63,0,0,70,63,0,60,0,67,0,0,0,70,0,69,65];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,1,0,0,1,1,1,0,0,0,0,1,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    24.wait;

    "[U13 0:24] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~melodyAmp = 0.200;
    ~reload.value;
    36.wait;

    "[U13 1:00] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [0,0,70,60,62,60,60,60,65,60,67,69,69,63,0,70,60,63,70,60,0,0,0,0,70,67,72,65,63,0,0,70];
    ~acidAmp = 0.22;
    ~reload.value;
    102.wait;

    "[U13 2:42] variations + mutations...".postln;
    ~melodyNotes = [63,67,62,0,0,65,70,0,62,65,69,60,65,0,72,0,0,0,65,67,69,69,72,72,0,65,70,65,0,70,65,70];
    ~reload.value;
    12.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.55, [~scaleDorian, ~scaleMinorPent, ~scaleDorian].choose);
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

    "[U13 3:30] outro -- fade...".postln;
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
    "[U13 4:00] === fin AMBIENT VOCAL ===".postln;
}).play;
"=== TRACK U13 : AMBIENT VOCAL 4 min lancee ===".postln;
)
