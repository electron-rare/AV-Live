// =====================================================================
//  W15_dub_finale.scd  --  Album W "Dub Techno", track 15/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK W15 : "DUB FINALE" 6 minutes ----------------------
//   0:00 intro -> 0:36 build -> 1:30 main -> 4:18 variations -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[W15 0:00] intro dub_finale...".postln;
    ~bpm = 120;
    ~kickFreq = 50; ~kickPitchAmt = 2.2; ~kickDecay = 0.48; ~kickClick = 0.1;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [67,0,0,65,65,0,0,0,70,0,0,0,70,60,0,60,67,0,0,63,67,0,0,0,65,0,63,0,70,0,0,72];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,0,0,1,0,1,0,0,1,1,0,0,1,1,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    36.wait;

    "[W15 0:36] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~clapAmp = 0.0;
    ~melodyAmp = 0.180;
    ~reload.value;
    54.wait;

    "[W15 1:30] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [0,63,72,67,0,68,0,67,62,70,0,0,0,0,0,68,0,0,72,68,72,0,63,60,60,0,0,72,0,62,72,0];
    ~acidAmp = 0.22;
    ~reload.value;
    168.wait;

    "[W15 4:18] variations + mutations...".postln;
    ~melodyNotes = [70,0,63,0,0,0,68,0,65,0,0,0,0,67,0,72,0,72,0,0,65,0,62,0,72,65,0,63,63,0,65,0];
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

    "[W15 5:30] outro -- fade...".postln;
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
    "[W15 6:00] === fin DUB FINALE ===".postln;
}).play;
"=== TRACK W15 : DUB FINALE 6 min lancee ===".postln;
)
