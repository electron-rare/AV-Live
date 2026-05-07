// =====================================================================
//  V09_clicks_cuts.scd  --  Album V "Glitch IDM", track 9/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK V09 : "CLICKS CUTS" 7 minutes ----------------------
//   0:00 intro -> 0:42 build -> 1:45 main -> 5:06 variations -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[V09 0:00] intro clicks_cuts...".postln;
    ~bpm = 118;
    ~kickFreq = 60; ~kickPitchAmt = 4.0; ~kickDecay = 0.22; ~kickClick = 0.4;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \fmBell;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [70,0,0,0,60,0,60,0,62,0,0,0,62,0,0,0,67,0,0,0,70,0,0,0,65,70,0,0,67,0,68,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,1,0,0,0,0,0,0,0,0,1,1,1,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\off);
    42.wait;

    "[V09 0:42] build kick + hat...".postln;
    ~kickSteps = [1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,1,0,1, 0,1,1,0]; ~hatAmp = 0.1;
    ~clapSteps = [0,0,1,0, 1,0,0,1, 0,1,0,0, 0,0,1,0]; ~clapAmp = 0.3;
    ~melodyAmp = 0.180;
    ~reload.value;
    63.wait;

    "[V09 1:45] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [63,60,70,62,68,63,65,67,63,0,60,0,0,0,62,62,65,0,68,65,62,0,72,67,0,68,0,0,68,65,0,67];
    ~acidAmp = 0.22;
    ~reload.value;
    201.wait;

    "[V09 5:06] variations + mutations...".postln;
    ~melodyNotes = [0,68,0,68,0,62,62,0,0,65,62,0,0,0,70,0,60,72,0,70,67,62,60,0,0,0,63,0,63,63,0,68];
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

    "[V09 6:30] outro -- fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.180;
        ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.1;
        ~clapAmp = x * 0.3;
        ~acidAmp = x * 0.22;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[V09 7:00] === fin CLICKS CUTS ===".postln;
}).play;
"=== TRACK V09 : CLICKS CUTS 7 min lancee ===".postln;
)
