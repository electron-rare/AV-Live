// =====================================================================
//  T08_dark_hardcore.scd  --  Album T "Hardcore Gabber", track 8/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  Sub-track : "Dark Hardcore" 6 min (360s)
// =====================================================================

// --- TRACK T08 : "DARK HARDCORE" 6 minutes -------------
//   0:00 intro -> 1:22 groove -> 3:01 drop -> 4:23 variations -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[T08 0:00] intro / atmosphere...".postln;
    ~bpm = 195;
    ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.18;
    ~kickDrive = 3.5; ~kickClick = 0.35;
    ~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~kickAmp = 0.55;
    ~hatSteps  = [0,1,1,1, 0,1,1,0, 0,1,1,1, 0,1,1,0]; ~hatAmp = 0.13;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.45;
    ~clapSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~clapAmp = 0.4;
    ~percInst = \rim;
    ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.30;
    ~melodyInst = \growl;
    ~melodyAttack = 0.01; ~melodyRelease = 0.3; ~melodyCutoff = 1200;
    ~melodyAmp = 0.132;
    ~melodyNotes = ~genMelody.(0.45, ~scaleHarmonicMin);
    ~acidNotes = [36,0,48,0,36,0,43,0, 36,0,41,0,39,0,36,0];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 800; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0.168;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    82.wait;

    "[T08 1:22] build / groove...".postln;
    ~melodyAmp = 0.187;
    ~melodyNotes = ~genMelody.(0.55, ~scalePhrygian);
    ~melodyCutoff = 1800;
    ~reload.value;
    24.do { |k|
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

    "[T08 3:01] drop / climax...".postln;
    ~melodyAmp = 0.220;
    ~kickAmp = 0.600;
    ~melodyNotes = ~genMelody.(0.6, ~scalePhrygian);
    ~melodyCutoff = 2400;
    ~acidAmp = 0.280;
    ~acidCutoff = 1500; ~acidDrive = 3.2;
    ~reload.value;
    16.do { |k|
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

    "[T08 4:23] variations / second wave...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4;
    ~melodyAmp = 0.198;
    ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
    ~melodyCutoff = 2000;
    ~vcfOn !? { ~vcfOn.(\moog, 1600, 0.5) };
    ~reload.value;
    67.wait;

    "[T08 5:30] outro -- fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.220;
        ~kickAmp = x * 0.550;
        ~hatAmp = x * 0.130;
        ~snareAmp = x * 0.450;
        ~clapAmp = x * 0.400;
        ~acidAmp = x * 0.280;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[T08 6:00] === fin DARK HARDCORE ===".postln;
}).play;
"=== TRACK T08 : DARK HARDCORE 6 min lancee ===".postln;
)
