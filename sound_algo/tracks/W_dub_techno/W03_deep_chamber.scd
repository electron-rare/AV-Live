// =====================================================================
//  W03_deep_chamber.scd  --  Album W "Dub Techno", track 3/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK W03 : "DEEP CHAMBER" 6 minutes ----------------------
//   0:00 intro -> 0:36 build -> 1:30 main -> 4:18 variations -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[W03 0:00] intro deep_chamber...".postln;
    ~bpm = 118;
    ~kickFreq = 50; ~kickPitchAmt = 2.2; ~kickDecay = 0.48; ~kickClick = 0.1;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [72,0,65,0,60,0,0,0,67,0,0,69,67,0,0,0,70,0,0,0,60,0,0,0,67,60,69,67,60,70,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,1,0,0,0,0,0,0,0,0,1,1,1,0,1,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    36.wait;

    "[W03 0:36] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~clapAmp = 0.0;
    ~melodyAmp = 0.180;
    ~reload.value;
    54.wait;

    "[W03 1:30] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [70,63,65,69,0,63,62,63,0,70,0,63,70,0,0,0,0,72,72,65,60,65,0,69,60,69,72,0,67,62,62,62];
    ~acidAmp = 0.22;
    ~reload.value;
    168.wait;

    "[W03 4:18] variations + mutations...".postln;
    ~melodyNotes = [0,67,69,60,72,69,67,60,0,67,0,60,63,67,0,67,63,67,67,67,62,63,0,63,65,60,62,0,63,0,0,70];
    ~reload.value;
    18.do { |k|
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

    "[W03 5:30] outro -- fade...".postln;
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
    "[W03 6:00] === fin DEEP CHAMBER ===".postln;
}).play;
"=== TRACK W03 : DEEP CHAMBER 6 min lancee ===".postln;
)
