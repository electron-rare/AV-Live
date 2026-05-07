// =====================================================================
//  W05_cavern_chord.scd  --  Album W "Dub Techno", track 5/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK W05 : "CAVERN CHORD" 8 minutes ----------------------
//   0:00 intro -> 0:48 build -> 2:00 main -> 5:54 variations -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[W05 0:00] intro cavern_chord...".postln;
    ~bpm = 124;
    ~kickFreq = 50; ~kickPitchAmt = 2.2; ~kickDecay = 0.48; ~kickClick = 0.1;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [63,0,62,63,72,0,0,0,60,63,60,0,62,0,62,0,62,65,65,0,70,0,0,0,63,0,0,60,63,0,63,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [1,0,0,1,0,0,0,1,0,0,0,1,0,0,1,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    48.wait;

    "[W05 0:48] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~clapAmp = 0.0;
    ~melodyAmp = 0.180;
    ~reload.value;
    72.wait;

    "[W05 2:00] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [68,72,60,70,0,72,60,62,0,67,72,0,67,70,63,60,72,62,67,60,65,62,65,65,65,63,0,0,63,60,68,70];
    ~acidAmp = 0.22;
    ~reload.value;
    234.wait;

    "[W05 5:54] variations + mutations...".postln;
    ~melodyNotes = [72,60,0,60,62,65,0,68,68,62,62,70,0,65,72,70,72,68,65,67,63,60,62,0,63,0,67,63,65,72,0,72];
    ~reload.value;
    24.do { |k|
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

    "[W05 7:30] outro -- fade...".postln;
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
    "[W05 8:00] === fin CAVERN CHORD ===".postln;
}).play;
"=== TRACK W05 : CAVERN CHORD 8 min lancee ===".postln;
)
