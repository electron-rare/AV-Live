// =====================================================================
//  U10_epic_orchestral.scd  --  Album U "Vocal Trance", track 10/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK U10 : "EPIC ORCHESTRAL" 8 minutes ----------------------
//   0:00 intro -> 0:48 build -> 2:00 main -> 5:54 variations -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[U10 0:00] intro epic_orchestral...".postln;
    ~bpm = 138;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.18;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \strings;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.140;
    ~melodyNotes = [67,65,0,0,67,0,0,0,67,65,0,0,60,0,0,68,71,0,0,0,71,0,72,0,67,0,0,63,67,0,67,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cinematic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    48.wait;

    "[U10 0:48] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~melodyAmp = 0.200;
    ~reload.value;
    72.wait;

    "[U10 2:00] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [71,72,60,0,0,71,60,71,63,0,72,62,68,60,72,0,62,68,67,62,63,71,0,67,0,67,0,0,63,0,72,0];
    ~acidAmp = 0.22;
    ~reload.value;
    234.wait;

    "[U10 5:54] variations + mutations...".postln;
    ~melodyNotes = [0,0,0,0,0,67,0,0,0,0,68,62,0,0,72,68,63,62,71,0,0,71,0,68,72,68,63,0,60,0,67,68];
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.55, [~scaleHarmonicMin, ~scaleMinorPent, ~scaleDorian].choose);
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

    "[U10 7:30] outro -- fade...".postln;
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
    "[U10 8:00] === fin EPIC ORCHESTRAL ===".postln;
}).play;
"=== TRACK U10 : EPIC ORCHESTRAL 8 min lancee ===".postln;
)
