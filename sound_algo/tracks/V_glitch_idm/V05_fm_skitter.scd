// =====================================================================
//  V05_fm_skitter.scd  --  Album V "Glitch IDM", track 5/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK V05 : "FM SKITTER" 8 minutes ----------------------
//   0:00 intro -> 0:48 build -> 2:00 main -> 5:54 variations -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[V05 0:00] intro fm_skitter...".postln;
    ~bpm = 135;
    ~kickFreq = 60; ~kickPitchAmt = 4.0; ~kickDecay = 0.22; ~kickClick = 0.4;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [72,63,0,0,63,62,0,0,63,0,0,0,62,70,0,0,72,0,70,63,63,0,0,0,62,0,0,67,69,0,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,0,0,0,0,1,0,0,0,1,0,0,1,1,1];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    48.wait;

    "[V05 0:48] build kick + hat...".postln;
    ~kickSteps = [1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,1,0,1, 0,1,1,0]; ~hatAmp = 0.1;
    ~clapSteps = [0,0,1,0, 1,0,0,1, 0,1,0,0, 0,0,1,0]; ~clapAmp = 0.3;
    ~melodyAmp = 0.180;
    ~reload.value;
    72.wait;

    "[V05 2:00] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [72,67,70,69,0,72,0,0,67,72,0,0,0,67,0,69,70,62,65,0,72,0,0,0,63,70,60,65,0,72,69,0];
    ~acidAmp = 0.22;
    ~reload.value;
    234.wait;

    "[V05 5:54] variations + mutations...".postln;
    ~melodyNotes = [72,62,0,72,63,0,69,67,0,0,70,65,0,65,70,60,63,60,67,0,0,70,0,65,70,60,69,67,62,69,0,67];
    ~reload.value;
    24.do { |k|
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

    "[V05 7:30] outro -- fade...".postln;
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
    "[V05 8:00] === fin FM SKITTER ===".postln;
}).play;
"=== TRACK V05 : FM SKITTER 8 min lancee ===".postln;
)
