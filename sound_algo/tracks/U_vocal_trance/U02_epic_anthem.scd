// =====================================================================
//  U02_epic_anthem.scd  --  Album U "Vocal Trance", track 2/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK U02 : "EPIC ANTHEM" 5 minutes ----------------------
//   0:00 intro -> 0:30 build -> 1:15 main -> 3:30 variations -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[U02 0:00] intro epic_anthem...".postln;
    ~bpm = 140;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.18;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.140;
    ~melodyNotes = [65,0,60,60,68,65,0,0,63,0,0,0,65,0,0,62,70,0,0,0,60,0,0,70,68,0,65,72,63,0,0,62];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    30.wait;

    "[U02 0:30] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~melodyAmp = 0.200;
    ~reload.value;
    45.wait;

    "[U02 1:15] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [62,60,0,0,0,72,70,0,60,0,72,72,67,60,60,0,72,63,62,0,62,0,62,0,60,70,0,68,0,68,70,67];
    ~acidAmp = 0.22;
    ~reload.value;
    135.wait;

    "[U02 3:30] variations + mutations...".postln;
    ~melodyNotes = [62,62,65,63,0,0,0,63,67,60,0,62,0,62,0,0,67,68,67,67,0,0,70,0,68,0,67,72,70,62,63,68];
    ~reload.value;
    15.do { |k|
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

    "[U02 4:30] outro -- fade...".postln;
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
    "[U02 5:00] === fin EPIC ANTHEM ===".postln;
}).play;
"=== TRACK U02 : EPIC ANTHEM 5 min lancee ===".postln;
)
