// =====================================================================
//  V07_drill_n_bass.scd  --  Album V "Glitch IDM", track 7/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK V07 : "DRILL N BASS" 5 minutes ----------------------
//   0:00 intro -> 0:30 build -> 1:15 main -> 3:30 variations -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[V07 0:00] intro drill_n_bass...".postln;
    ~bpm = 165;
    ~kickFreq = 60; ~kickPitchAmt = 4.0; ~kickDecay = 0.22; ~kickClick = 0.4;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \pluck;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [67,0,63,0,67,0,0,0,62,60,63,0,63,0,0,0,67,0,68,70,70,0,0,0,72,0,0,0,62,60,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,1,1,0,0,0,0,1,0,1,1,0,0,1,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    30.wait;

    "[V07 0:30] build kick + hat...".postln;
    ~kickSteps = [1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,1,0,1, 0,1,1,0]; ~hatAmp = 0.1;
    ~clapSteps = [0,0,1,0, 1,0,0,1, 0,1,0,0, 0,0,1,0]; ~clapAmp = 0.3;
    ~melodyAmp = 0.180;
    ~reload.value;
    45.wait;

    "[V07 1:15] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [72,0,0,70,0,63,72,70,62,68,65,0,0,62,65,70,60,63,72,0,0,72,68,0,65,70,65,72,0,72,62,0];
    ~acidAmp = 0.22;
    ~reload.value;
    135.wait;

    "[V07 3:30] variations + mutations...".postln;
    ~melodyNotes = [0,70,60,0,0,0,65,0,68,60,0,0,72,0,72,65,68,0,0,68,0,63,70,65,70,65,0,70,62,0,63,0];
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

    "[V07 4:30] outro -- fade...".postln;
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
    "[V07 5:00] === fin DRILL N BASS ===".postln;
}).play;
"=== TRACK V07 : DRILL N BASS 5 min lancee ===".postln;
)
