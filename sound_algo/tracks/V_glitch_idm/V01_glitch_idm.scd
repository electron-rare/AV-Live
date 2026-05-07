// =====================================================================
//  V01_glitch_idm.scd  --  Album V "Glitch IDM", track 1/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK V01 : "GLITCH IDM" 4 minutes ----------------------
//   0:00 intro -> 0:24 build -> 1:00 main -> 2:42 variations -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[V01 0:00] intro glitch_idm...".postln;
    ~bpm = 130;
    ~kickFreq = 60; ~kickPitchAmt = 4.0; ~kickDecay = 0.22; ~kickClick = 0.4;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \pluck;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [65,0,0,0,77,0,63,0,72,0,0,0,77,0,0,67,70,0,70,0,63,0,0,0,67,72,0,0,75,65,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,1];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    24.wait;

    "[V01 0:24] build kick + hat...".postln;
    ~kickSteps = [1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,1,0,1, 0,1,1,0]; ~hatAmp = 0.1;
    ~clapSteps = [0,0,1,0, 1,0,0,1, 0,1,0,0, 0,0,1,0]; ~clapAmp = 0.3;
    ~melodyAmp = 0.180;
    ~reload.value;
    36.wait;

    "[V01 1:00] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [0,70,65,70,70,0,63,75,0,0,0,65,72,0,0,0,70,75,63,70,0,0,77,60,0,0,77,72,0,0,75,0];
    ~acidAmp = 0.22;
    ~reload.value;
    102.wait;

    "[V01 2:42] variations + mutations...".postln;
    ~melodyNotes = [72,0,65,77,0,0,0,77,65,60,0,65,0,70,72,72,0,60,70,0,0,63,0,77,67,77,72,0,0,65,67,63];
    ~reload.value;
    12.do { |k|
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

    "[V01 3:30] outro -- fade...".postln;
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
    "[V01 4:00] === fin GLITCH IDM ===".postln;
}).play;
"=== TRACK V01 : GLITCH IDM 4 min lancee ===".postln;
)
