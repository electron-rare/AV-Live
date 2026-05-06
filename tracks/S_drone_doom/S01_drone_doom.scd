// =====================================================================
//  S01_drone_doom.scd  --  Album S "Drone Doom", track 1/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  Sub-track : "Drone Doom" 4 min (240s)
// =====================================================================

// --- TRACK S01 : "DRONE DOOM" 4 minutes -------------
//   0:00 intro -> 0:52 groove -> 1:55 drop -> 2:47 variations -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[S01 0:00] intro / atmosphere...".postln;
    ~bpm = 71;
    ~kickFreq = 40; ~kickPitchAmt = 2.0; ~kickDecay = 0.45;
    ~kickDrive = 1.0; ~kickClick = 0.05;
    ~kickSteps = (0!16); ~kickAmp = 0.4;
    ~hatSteps  = (0!16); ~hatAmp = 0.05;
    ~snareSteps = (0!16); ~snareAmp = 0.3;
    ~clapSteps = (0!16); ~clapAmp = 0.2;
    ~percInst = \cowbell;
    ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.30;
    ~melodyInst = \drone;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 1500;
    ~melodyAmp = 0.132;
    ~melodyNotes = ~genMelody.(0.45, ~scaleJapanese);
    ~acidNotes = [36,0,48,0,36,0,43,0, 36,0,41,0,39,0,36,0];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 800; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0.000;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\drone) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    52.wait;

    "[S01 0:52] build / groove...".postln;
    ~melodyAmp = 0.187;
    ~melodyNotes = ~genMelody.(0.55, ~scaleHijaz);
    ~melodyCutoff = 2100;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25);
            ~reload.value;
        };
        if (0.15.coin) {
            ~acidCutoff = rrand(500, 1800); ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.3); ~reload.value;
        };
        4.wait;
    };

    "[S01 1:55] drop / climax...".postln;
    ~melodyAmp = 0.220;
    ~kickAmp = 0.450;
    ~melodyNotes = ~genMelody.(0.6, ~scaleJapanese);
    ~melodyCutoff = 2700;
    ~acidAmp = 0.000;
    ~acidCutoff = 1500; ~acidDrive = 3.2;
    ~reload.value;
    10.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2);
            ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[S01 2:47] variations / second wave...".postln;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 1.0; ~melodyRelease = 2.6;
    ~melodyAmp = 0.198;
    ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
    ~melodyCutoff = 2300;
    ~vcfOn !? { ~vcfOn.(\moog, 1900, 0.5) };
    ~reload.value;
    43.wait;

    "[S01 3:30] outro -- fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.220;
        ~kickAmp = x * 0.400;
        ~hatAmp = x * 0.050;
        ~snareAmp = x * 0.300;
        ~clapAmp = x * 0.200;
        ~acidAmp = x * 0.000;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[S01 4:00] === fin DRONE DOOM ===".postln;
}).play;
"=== TRACK S01 : DRONE DOOM 4 min lancee ===".postln;
)
