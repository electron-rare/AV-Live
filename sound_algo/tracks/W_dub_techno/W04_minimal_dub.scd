// =====================================================================
//  W04_minimal_dub.scd  --  Album W "Dub Techno", track 4/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK W04 : "MINIMAL DUB" 7 minutes ----------------------
//   0:00 intro -> 0:42 build -> 1:45 main -> 5:06 variations -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[W04 0:00] intro minimal_dub...".postln;
    ~bpm = 120;
    ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.45; ~kickClick = 0.08;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \stab;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [70,0,0,0,70,72,0,0,60,68,0,0,67,0,0,70,72,0,0,0,65,0,0,0,68,0,0,0,60,0,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [1,1,0,0,1,1,0,0,0,0,0,0,1,0,0,1];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    42.wait;

    "[W04 0:42] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~clapAmp = 0.0;
    ~melodyAmp = 0.180;
    ~reload.value;
    63.wait;

    "[W04 1:45] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [67,60,62,65,0,62,63,63,0,0,72,0,72,0,70,0,0,0,62,60,68,0,67,62,65,63,62,70,62,0,0,62];
    ~acidAmp = 0.22;
    ~reload.value;
    201.wait;

    "[W04 5:06] variations + mutations...".postln;
    ~melodyNotes = [67,0,72,60,0,0,68,0,72,70,0,0,0,60,72,68,67,62,68,72,0,65,60,0,0,70,0,68,72,0,65,65];
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

    "[W04 6:30] outro -- fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.180;
        ~kickAmp = x * 0.45;
        ~hatAmp = x * 0.06;
        ~clapAmp = x * 0.0;
        ~acidAmp = x * 0.22;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[W04 7:00] === fin MINIMAL DUB ===".postln;
}).play;
"=== TRACK W04 : MINIMAL DUB 7 min lancee ===".postln;
)
