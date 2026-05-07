// =====================================================================
//  V06_ambient_idm.scd  --  Album V "Glitch IDM", track 6/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK V06 : "AMBIENT IDM" 6 minutes ----------------------
//   0:00 intro -> 0:36 build -> 1:30 main -> 4:18 variations -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[V06 0:00] intro ambient_idm...".postln;
    ~bpm = 110;
    ~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.3;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [60,0,0,0,68,0,72,0,68,0,0,0,63,0,0,0,63,0,0,0,65,0,0,0,68,0,0,0,62,0,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    36.wait;

    "[V06 0:36] build kick + hat...".postln;
    ~kickSteps = [1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,1,0,1, 0,1,1,0]; ~hatAmp = 0.1;
    ~clapSteps = [0,0,1,0, 1,0,0,1, 0,1,0,0, 0,0,1,0]; ~clapAmp = 0.3;
    ~melodyAmp = 0.180;
    ~reload.value;
    54.wait;

    "[V06 1:30] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [0,65,70,70,63,65,72,63,0,63,60,67,63,63,62,70,70,72,60,68,0,0,0,60,0,65,68,62,67,60,67,68];
    ~acidAmp = 0.22;
    ~reload.value;
    168.wait;

    "[V06 4:18] variations + mutations...".postln;
    ~melodyNotes = [63,72,65,70,65,0,60,63,60,67,0,60,0,0,62,70,67,63,60,62,0,63,62,62,62,65,0,0,0,70,60,65];
    ~reload.value;
    18.do { |k|
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

    "[V06 5:30] outro -- fade...".postln;
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
    "[V06 6:00] === fin AMBIENT IDM ===".postln;
}).play;
"=== TRACK V06 : AMBIENT IDM 6 min lancee ===".postln;
)
